#!/usr/bin/env python3
"""Job PF1 (charades results/aggregation.md section 279): local 1 at 1 node.
Part A: M committed ev/s at W 300, medians of 5 reps, ratios to PP 512 (higher
is better for the first named). Part B: perf cycles:u profiles of task 0 (one
process, 23 PEs); each symbol's share of samples times the setting's PE time
per committed event (46 PEs / part A's rate) gives µs per committed event; the
difference local 1 - PP 512 per group is the closure test (PF-5).
Usage: pf_prof.py <job dir>"""
import csv, glob, os, re, statistics as st, sys, collections
J = sys.argv[1]
COUNT = '180941384'; F1_WPS_W300 = 46.9
SETS = ['wps:512', 'pp:512', 'pp:512::p1', 'pp:512:l4:p1', 'pp:512:l1:p1']
NAME = {'wps:512': 'WPs 512', 'pp:512': 'PP 512', 'pp:512::p1': 'PP 512 pad 1', 'pp:512:l4:p1': 'local 4 pad 1', 'pp:512:l1:p1': 'local 1 pad 1'}
TAG = lambda a: a.replace('::', ':l16:').replace(':', '_')
PRED = {'pp:512:l1:p1': (0.68, 0.80, 'PF-2'), 'pp:512::p1': (0.97, 1.03, 'PF-3'), 'pp:512:l4:p1': (0.90, 9.99, 'PF-4')}

# ---- part A
runs = collections.defaultdict(list); counts = set(); bad = []
for a in SETS:
    for f in glob.glob(os.path.join(J, 'n1', 'uni_%s_r*.csv' % TAG(a))):
        for r in csv.DictReader(open(f)):
            if r['status'] != 'ok' or not (r.get('count_waves') or '0').strip('0.'): bad.append((f, r['status'])); continue
            counts.add(r['committed'])
            runs[a].append(dict(rep=int(f.rsplit('_r', 1)[1][:-4]), rate=float(r['event_rate']) / 1e6, epm=float(r['agg_events_per_msg'] or 0),
                                eff=float(r['efficiency']), gvts=int(r['gvts']), ex=float(r['exec_s'])))
med = lambda v, k='rate': st.median(x[k] for x in v)
print('part A: runs kept %d, failed or without count waves %d; counts %s (F1 %s) %s' % (sum(map(len, runs.values())), len(bad), sorted(counts), COUNT,
      'SAME' if counts == {COUNT} else 'DIFFER'))
R = {a: med(v) for a, v in runs.items()}
print('\n# Rates at W 300 (M committed ev/s, median of 5; spread fastest / slowest), events per htram message, lowest efficiency %, GVT rounds per s')
for a in SETS:
    v = runs.get(a)
    if not v: continue
    print('  %-14s %6.1f  %.2f  ev/msg %6.1f  eff %.3f  GVT/s %5.0f%s' % (NAME[a], R[a], max(x['rate'] for x in v) / min(x['rate'] for x in v),
          med(v, 'epm'), min(x['eff'] for x in v), st.median(x['gvts'] / x['ex'] for x in v),
          '   / F1 %.1f = %.3f (PF-1 ±5%%)' % (F1_WPS_W300, R[a] / F1_WPS_W300) if a == 'wps:512' else ''))
print('\n# Ratios to PP 512 (medians, and paired by rep)')
pp = {x['rep']: x['rate'] for x in runs.get('pp:512', [])}
for a in SETS:
    if a == 'pp:512' or a not in R: continue
    pr = [x['rate'] / pp[x['rep']] for x in runs[a] if x['rep'] in pp]
    lo, hi, name = PRED.get(a, (None, None, ''))
    print('  %-14s / PP 512 %.3f  paired %s median %.3f%s' % (NAME[a], R[a] / R['pp:512'], ' '.join('%.3f' % x for x in pr), st.median(pr),
          '  [%s %.2f-%.2f: %s]' % (name, lo, hi, 'yes' if lo <= st.median(pr) <= hi else 'NO') if name else ''))

# ---- part B
GROUPS = [  # first match wins
    ('htram send path', r'HTram::(copyLocalToNodeBuf|copyToNodeBuf|insert|ship|flush|send|reserve|tflush|renew|sendUrgent|flushTo)|agg_send|Aggregator::send'),
    ('htram receive', r'HTramRecv::|HTram::(drain|receive|deliver)|Aggregator::deliver|pushToInputBuffer'),
    ('scheduler and polling', r'Csd|CmiGetNonLocal|CmiDeliver|scheduler|Scheduler|moodycamel|try_dequeue|CqsDequeue|CmiPoll|PumpMsgs|LrtsAdvance|CmiNotifyIdle|idle'),
    ('LCI / PSM2 progress', r'lci|LCI|psm|hfi_|ips_|comm_backend|Lci'),
    ('engine and model', r'LPChare|PHold|tw_|Event|event_|LP<|BucketGVT|Controller|remote_event|avl|Heap|Pending|GVT|execute|forward|rollback|commit'),
    ('locks', r'pthread_spin|pthread_mutex|__lll_lock|spin_lock'),
    ('memory', r'memmove|memcpy|memset|malloc|free|CmiAlloc|CmiFree|operator new|operator delete|_int_|mempool'),
]
def parse(f):
    out = []; total = None
    for line in open(f, errors='replace'):
        m = re.match(r'# Samples: ([\d.]+)([KM]?)', line)
        if m: total = int(float(m.group(1)) * {'': 1, 'K': 1e3, 'M': 1e6}[m.group(2)])
        m = re.match(r'\s+([\d.]+)%\s+(\d+)\s+\[\.\]\s+(.*?)\s*$', line) or re.match(r'\s+([\d.]+)%\s+\[\.\]\s+(.*?)\s*$', line)
        if m:
            g = m.groups(); out.append((float(g[0]), g[-1].split('  ')[0].strip()))
    return out, total
def group(sym):
    for g, pat in GROUPS:
        if re.search(pat, sym): return g
    return 'other'
prof = {}
for a in ['wps:512', 'pp:512', 'pp:512:l4:p1', 'pp:512:l1:p1']:
    d = os.path.join(J, 'perf', 'prof_' + TAG(a)); f = os.path.join(d, 'report_symbol.txt')
    if not os.path.exists(f): print('no profile for', a); continue
    syms, total = parse(f)
    t = 46.0 / R[a] if a in R else float('nan')   # µs of PE time per committed event
    g = collections.Counter()
    for pct, s in syms: g[group(s)] += pct
    g['below 0.2% each'] = 100 - sum(p for p, _ in syms)
    prof[a] = dict(syms=syms, groups=g, t=t, total=total)
print('\n# Profiles: share of task 0\'s user cycles (%%) and µs per committed event (share x 46 PEs / part A rate)')
heads = [x[0] for x in GROUPS] + ['other', 'below 0.2% each']   # GROUPS includes locks
print('  %-24s' % 'group' + ''.join('%22s' % NAME[a] for a in prof))
for h in heads:
    print('  %-24s' % h + ''.join('%11.1f%% %7.3f µs' % (p['groups'][h], p['groups'][h] / 100 * p['t']) for p in prof.values()))
print('  %-24s' % 'total (µs per event)' + ''.join('%22.3f' % p['t'] for p in prof.values()) + '   samples: ' + ' '.join(str(p['total']) for p in prof.values()))
if 'pp:512' in prof and 'pp:512:l1:p1' in prof:
    A, Bp = prof['pp:512:l1:p1'], prof['pp:512']
    dt = A['t'] - Bp['t']
    print('\n# Closure (PF-5): local 1 pad 1 - PP 512, µs per committed event; total %.3f' % dt)
    for h in heads:
        d = A['groups'][h] / 100 * A['t'] - Bp['groups'][h] / 100 * Bp['t']
        print('  %-24s %+7.3f  (%5.1f%% of the difference)' % (h, d, 100 * d / dt if dt else 0))
    print('\n# Symbols with the largest difference (µs per committed event, local 1 pad 1 - PP 512)')
    sa = collections.Counter({s: p / 100 * A['t'] for p, s in A['syms']}); sb = collections.Counter({s: p / 100 * Bp['t'] for p, s in Bp['syms']})
    for s in sorted(set(sa) | set(sb), key=lambda s: -abs(sa[s] - sb[s]))[:15]:
        print('  %+7.3f  %6.3f vs %6.3f  [%s] %s' % (sa[s] - sb[s], sa[s], sb[s], group(s), s[:90]))
# annotation: share of each annotated function's samples on lock-prefixed (atomic) instructions
print('\n# Annotations: share of the function\'s samples on lock-prefixed instructions (atomics) plus the instruction after each (skid), and the 5 hottest lines')
for a in prof:
    for f in sorted(glob.glob(os.path.join(J, 'perf', 'prof_' + TAG(a), 'annotate_*.txt'))):
        rows = []
        for line in open(f, errors='replace'):
            m = re.match(r'\s+([\d.]+)\s*:\s+[0-9a-f]+:\s+(.*)$', line)
            if m: rows.append((float(m.group(1)), m.group(2).strip()))
        if not rows: continue
        tot = sum(p for p, _ in rows)
        # a sample usually lands on the instruction after the one that stalled (skid): count each lock-prefixed
        # instruction with the one after it
        lock = sum(p + (rows[i + 1][0] if i + 1 < len(rows) else 0) for i, (p, ins) in enumerate(rows) if ins.startswith('lock'))
        print('  %-14s %-24s lock + next %5.1f%% of %5.1f%%' % (NAME[a], os.path.basename(f)[9:-4], 100 * lock / tot if tot else 0, tot))
        for p, ins in sorted(rows, reverse=True)[:5]: print('       %5.1f%%  %s' % (p, ins[:80]))
