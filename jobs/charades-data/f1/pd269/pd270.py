#!/usr/bin/env python3
"""Job PD16 (charades results/aggregation.md section 269, results in 270): PP's
shared counters packed (pad 0), one destination per cache line in each array
(pad 1) or one line per destination (pad 2), at local 16 and local 1, against
WPs 512, 16 nodes, W 400. M committed ev/s, medians of 5 reps; ratios named,
higher is better. A run without count waves ran on the engine defaults
(section 263) and is dropped. Usage: pd270.py <job dir>"""
import csv, glob, os, re, statistics as st, sys, collections
J = sys.argv[1]
F1_COUNTS = {'steady:100:1000:1.0': '2895361579', 'gauss:100:1000:4000': '2895358752'}
WL = {'steady:100:1000:1.0': 'uniform', 'gauss:100:1000:4000': 'σ 4,000'}
SETTINGS = ['wps:512', 'pp:512', 'pp:512::p1', 'pp:512::p2', 'pp:512:l1', 'pp:512:l1:p1', 'pp:512:l1:p2']
NAME = {'wps:512': 'WPs 512', 'pp:512': 'PP 512 pad 0', 'pp:512::p1': 'PP 512 pad 1', 'pp:512::p2': 'PP 512 pad 2',
        'pp:512:l1': 'local 1 pad 0', 'pp:512:l1:p1': 'local 1 pad 1', 'pp:512:l1:p2': 'local 1 pad 2'}
PL16 = {('steady:100:1000:1.0', 'wps:512'): 381.5, ('steady:100:1000:1.0', 'pp:512'): 336.7,
        ('steady:100:1000:1.0', 'pp:512:l1'): 303.4, ('gauss:100:1000:4000', 'pp:512'): 542.4,
        ('gauss:100:1000:4000', 'pp:512:l1'): 276.6}
PADLINE = {1: '--agg-pp-pad=1', 2: '--agg-pp-pad=2'}
LOGKEYS = {'gvt': 'htram Messages: GVT Update', 'urgent': 'htram Messages: Urgent Event',
           'full': 'htram Messages: Buffer Full', 'idle': 'htram Messages: Idle Flush',
           'msgs': 'htram Messages  ', 'bypass': 'htram PP Local Bypasses', 'items': 'Events Through htram'}

def logstats(path):
    out = {}; pad = 0
    for line in open(path, errors='replace'):
        m = re.search(r'\(--agg-pp-pad=(\d)\)', line)
        if m and line.startswith('Aggregation:'): pad = int(m.group(1))
        for k, key in LOGKEYS.items():
            if k not in out and line.strip().startswith(key.strip()) and (k != 'msgs' or line.strip().split()[2].isdigit()):
                try: out[k] = float(line.split()[-1])
                except ValueError: pass
    out['pad'] = pad
    return out

runs = collections.defaultdict(list); dropped = []; counts = collections.defaultdict(set); bad = []
for f in sorted(glob.glob(os.path.join(J, 'n16', '*.csv'))):
    tag = os.path.basename(f)[:-4]
    if tag.startswith('warm') or tag.startswith('prof'): continue
    for r in csv.DictReader(open(f)):
        if r['status'] != 'ok': bad.append((tag, r['arm'], r['status'])); continue
        if not (r.get('count_waves') or '0').strip('0.'): dropped.append((tag, r['arm'])); continue
        wl, agg, arm = r['workload'], r['agg'], r['arm']
        label = 'r%s_n16_%s_%s_b8_m8_%s' % (r['rep'], wl.replace(':', '_'), agg.replace(':', ''), arm.replace(':', ''))
        lp = os.path.join(J, 'n16', tag, 'ctl_sweep', 'logs', label + '.out')
        ls = logstats(lp) if os.path.exists(lp) else {}
        if not ls: bad.append((tag, arm, 'no log ' + label)); continue
        want = int(agg.split(':p')[1]) if ':p' in agg else 0
        if ls['pad'] != want: bad.append((tag, arm, 'log says pad %d, setting %s' % (ls['pad'], agg)))
        rep = int(tag.rsplit('_r', 1)[1]); com = int(r['committed'])
        runs[(wl, agg)].append(dict(rep=rep, rate=float(r['event_rate']) / 1e6, epm=float(r['agg_events_per_msg'] or 0),
            eff=float(r['efficiency']), rb=int(r['rolled_back']) / com, exec_s=float(r['exec_s']),
            remote=int(r['remote_sends']), **{k: ls.get(k, 0) for k in LOGKEYS}))
        counts[wl].add(r['committed'])

med = lambda v, k: st.median(x[k] for x in v)
sp = lambda v: max(x['rate'] for x in v) / min(x['rate'] for x in v)
print('runs kept: %d; dropped without count waves: %d; failed/stalled/missing log/pad mismatch: %d' % (sum(map(len, runs.values())), len(dropped), len(bad)))
for b in bad + dropped: print('  ', b)
print('\n# Counts (one per workload; F1-16 in brackets)')
for wl in WL: print('  %-9s %s [%s] %s' % (WL[wl], sorted(counts[wl]), F1_COUNTS[wl], 'SAME' if counts[wl] == {F1_COUNTS[wl]} else 'DIFFER'))

print('\n# Rates (M committed ev/s, median of 5; spread = fastest / slowest rep), events per htram message, efficiency %, PL16 median and this / PL16')
R = {}
for wl in WL:
    for a in SETTINGS:
        v = runs.get((wl, a))
        if not v: continue
        R[(wl, a)] = med(v, 'rate')
        pl = PL16.get((wl, a))
        print('  %-9s %-15s %7.1f  %.2f  ev/msg %6.1f  eff %.3f  rb/com %.5f%s' % (WL[wl], NAME[a], R[(wl, a)], sp(v), med(v, 'epm'), med(v, 'eff'), med(v, 'rb'),
              '  PL16 %.1f  ratio %.3f' % (pl, R[(wl, a)] / pl) if pl else ''))

print('\n# Ratios (medians; higher is better for the first named)')
for wl in WL:
    g = lambda a: R.get((wl, a))
    out = []
    for p in ['pp:512::p1', 'pp:512::p2']:
        if g(p): out.append('%s / PP 512 pad 0 %.3f' % (NAME[p], g(p) / g('pp:512')))
    for p in ['pp:512:l1:p1', 'pp:512:l1:p2']:
        out.append('%s / local 1 pad 0 %.3f' % (NAME[p], g(p) / g('pp:512:l1')))
    out.append('local 1 pad 2 / pad 1 %.3f' % (g('pp:512:l1:p2') / g('pp:512:l1:p1')))
    best = max(['pp:512:l1', 'pp:512:l1:p1', 'pp:512:l1:p2'], key=g)
    out.append('best local 1 (%s) / PP 512 pad 0 %.3f' % (NAME[best], g(best) / g('pp:512')))
    if g('wps:512'):
        out.append('best local 1 / WPs 512 %.3f' % (g(best) / g('wps:512')))
        out.append('best padded local 1 / WPs 512 %.3f' % (max(g('pp:512:l1:p1'), g('pp:512:l1:p2')) / g('wps:512')))
        out.append('PP 512 pad 0 / WPs 512 %.3f' % (g('pp:512') / g('wps:512')))
    print('  %s:\n    %s' % (WL[wl], '\n    '.join(out)))

print('\n# Message triggers (share of htram messages, medians); messages per event; bypass per message')
for wl in WL:
    for a in SETTINGS:
        v = runs.get((wl, a))
        if not v: continue
        sh = lambda k: st.median(x[k] / x['msgs'] for x in v if x['msgs'])
        print('  %-9s %-15s msgs/event %.4f  GVT %.3f  urgent %.4f  full %.4f  idle %.4f  bypass/msgs %.4f' % (
            WL[wl], NAME[a], st.median(x['msgs'] / x['items'] for x in v if x['items']), sh('gvt'), sh('urgent'), sh('full'), sh('idle'), sh('bypass')))

print('\n# PE time per event sent to another process (µs; 736 PEs x execution time / events through htram), and difference from the packed layout')
for wl in WL:
    for a in SETTINGS:
        v = runs.get((wl, a))
        if not v: continue
        t = st.median(736 * x['exec_s'] / x['items'] * 1e6 for x in v if x['items'])
        print('  %-9s %-15s %.3f' % (WL[wl], NAME[a], t))

print('\n# Per rep (M ev/s, by rep 1-5)')
for wl in WL:
    for a in SETTINGS:
        v = runs.get((wl, a))
        if v: print('  %-9s %-15s %s' % (WL[wl], NAME[a], ' '.join('%7.1f' % x['rate'] for x in sorted(v, key=lambda x: x['rep']))))
