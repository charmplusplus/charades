#!/usr/bin/env python3
"""Job L64 (charades results/aggregation.md section 271, results in 272): WPs
512 against PP 512 local 1 with padded counters (pad 1) on uniform at 64
nodes, under the controller and at W 400. M committed ev/s, medians of 5 reps;
ratios named, higher is better. A run without count waves ran on the engine
defaults (section 263) and is dropped. Usage: l64_272.py <job dir>"""
import csv, glob, os, re, statistics as st, sys, collections
J = sys.argv[1]
P64_COUNT = '11581457663'
P64 = {('wps:512', 'mb:0'): 980.0, ('wps:512', 'w:400'): 998.9}
P64_DIRECT_BEST = 540.6
SETTINGS = ['wps:512', 'pp:512:l1:p1']
NAME = {'wps:512': 'WPs 512', 'pp:512:l1:p1': 'local 1 pad 1'}
ARMS = ['mb:0', 'w:400']
ANAME = {'mb:0': 'controller', 'w:400': 'W 400'}
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

runs = collections.defaultdict(list); dropped = []; counts = set(); bad = []
for f in sorted(glob.glob(os.path.join(J, 'n64', '*.csv'))):
    tag = os.path.basename(f)[:-4]
    if tag.startswith('warm'): continue
    for r in csv.DictReader(open(f)):
        if r['status'] != 'ok': bad.append((tag, r['arm'], r['status'])); continue
        if not (r.get('count_waves') or '0').strip('0.'): dropped.append((tag, r['arm'])); continue
        wl, agg, arm = r['workload'], r['agg'], r['arm']
        label = 'r%s_n64_%s_%s_b8_m8_%s' % (r['rep'], wl.replace(':', '_'), agg.replace(':', ''), arm.replace(':', ''))
        lp = os.path.join(J, 'n64', tag, 'ctl_sweep', 'logs', label + '.out')
        ls = logstats(lp) if os.path.exists(lp) else {}
        if not ls: bad.append((tag, arm, 'no log ' + label)); continue
        want = 1 if ':p1' in agg else 0
        if ls['pad'] != want: bad.append((tag, arm, 'log says pad %d' % ls['pad']))
        rep = int(tag.rsplit('_r', 1)[1]); com = int(r['committed'])
        runs[(agg, arm)].append(dict(rep=rep, rate=float(r['event_rate']) / 1e6, epm=float(r['agg_events_per_msg'] or 0),
            eff=float(r['efficiency']), rb=int(r['rolled_back']) / com, mw=float(r['mean_window'] or 0),
            exec_s=float(r['exec_s']), wall_s=float(r['wall_s']), hshare=int(r['htram_events']) / com,
            **{k: ls.get(k, 0) for k in LOGKEYS}))
        counts.add(r['committed'])

med = lambda v, k: st.median(x[k] for x in v)
sp = lambda v: max(x['rate'] for x in v) / min(x['rate'] for x in v)
print('runs kept: %d; dropped without count waves: %d; failed/stalled/missing log/pad mismatch: %d' % (sum(map(len, runs.values())), len(dropped), len(bad)))
for b in bad + dropped: print('  ', b)
print('\n# Count: %s [P64 %s] %s' % (sorted(counts), P64_COUNT, 'SAME' if counts == {P64_COUNT} else 'DIFFER'))

print('\n# Rates (M committed ev/s, median of 5; spread = fastest / slowest rep), events per message, PE time per committed event (2,944 / rate, µs), efficiency %, controller mean W; P64 median and this / P64')
R = {}
for a in SETTINGS:
    for arm in ARMS:
        v = runs[(a, arm)]; R[(a, arm)] = med(v, 'rate')
        p = P64.get((a, arm))
        print('  %-14s %-10s %7.1f  %.2f  ev/msg %6.1f  PE %.3f  eff %.3f  rb/com %.5f  W %5.0f%s' % (
            NAME[a], ANAME[arm], R[(a, arm)], sp(v), med(v, 'epm'), 2944 / R[(a, arm)], med(v, 'eff'), med(v, 'rb'), med(v, 'mw'),
            '  P64 %.1f  ratio %.3f' % (p, R[(a, arm)] / p) if p else ''))

print('\n# Ratios (medians; higher is better for the first named)')
for arm in ARMS:
    print('  %-10s local 1 pad 1 / WPs 512 %.3f' % (ANAME[arm], R[('pp:512:l1:p1', arm)] / R[('wps:512', arm)]))
for a in SETTINGS:
    print('  %-14s controller / W 400 %.3f' % (NAME[a], R[(a, 'mb:0')] / R[(a, 'w:400')]))
print('  paired by rep (local 1 / WPs 512, same rep, minutes apart):')
for arm in ARMS:
    l = {x['rep']: x['rate'] for x in runs[('pp:512:l1:p1', arm)]}; w = {x['rep']: x['rate'] for x in runs[('wps:512', arm)]}
    pr = [l[k] / w[k] for k in sorted(l) if k in w]
    print('    %-10s %s  median %.3f' % (ANAME[arm], ' '.join('%.3f' % x for x in pr), st.median(pr)))
best_l1 = max(R[('pp:512:l1:p1', a)] for a in ARMS)
best_w = max(R[('wps:512', a)] for a in ARMS)
print('  bundling across jobs: local 1 better arm %.1f / P64 best direct %.1f = %.2f; WPs better arm %.1f / %.1f = %.2f (P64: 1.85)' % (
    best_l1, P64_DIRECT_BEST, best_l1 / P64_DIRECT_BEST, best_w, P64_DIRECT_BEST, best_w / P64_DIRECT_BEST))

print('\n# Message triggers (share of htram messages, medians); messages per event through htram; htram events per committed event')
for a in SETTINGS:
    for arm in ARMS:
        v = runs[(a, arm)]
        sh = lambda k: st.median(x[k] / x['msgs'] for x in v if x['msgs'])
        print('  %-14s %-10s msgs/event %.4f  GVT %.3f  urgent %.4f  full %.4f  idle %.4f  bypass/msgs %.4f  htram/committed %.4f' % (
            NAME[a], ANAME[arm], st.median(x['msgs'] / x['items'] for x in v if x['items']), sh('gvt'), sh('urgent'), sh('full'), sh('idle'), sh('bypass'), med(v, 'hshare')))

print('\n# Per rep (M ev/s, by rep 1-5; wall s in brackets)')
for a in SETTINGS:
    for arm in ARMS:
        v = sorted(runs[(a, arm)], key=lambda x: x['rep'])
        print('  %-14s %-10s %s' % (NAME[a], ANAME[arm], ' '.join('%7.1f [%4.1f]' % (x['rate'], x['wall_s']) for x in v)))
