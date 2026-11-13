#!/usr/bin/env python3
"""Job PL16 (charades results/aggregation.md section 267, results in 268): PP's
local buffer size (--agg-pp-local) against F1's htram settings at 16 nodes.
M committed ev/s, medians of 5 reps; ratios named, higher is better. A run
without count waves ran on the engine defaults (section 263) and is dropped.
Usage: pl268.py <job dir>"""
import csv, glob, os, re, statistics as st, sys, collections
J = sys.argv[1]
F1_COUNTS = {'steady:100:1000:1.0': '2895361579', 'gauss:100:1000:2000': '2895361550',
             'gauss:100:1000:4000': '2895358752'}
WL = {'steady:100:1000:1.0': 'uniform', 'gauss:100:1000:2000': 'σ 2,000', 'gauss:100:1000:4000': 'σ 4,000'}
SETTINGS = ['wps:512', 'pp:512', 'pp:512:l4', 'pp:512:l1']
NAME = {'wps:512': 'WPs 512', 'pp:512': 'PP 512', 'pp:512:l4': 'PP 512 local 4', 'pp:512:l1': 'PP 512 local 1'}
LOGKEYS = {'gvt': 'htram Messages: GVT Update', 'urgent': 'htram Messages: Urgent Event',
           'full': 'htram Messages: Buffer Full', 'idle': 'htram Messages: Idle Flush',
           'msgs': 'htram Messages  ', 'bypass': 'htram PP Local Bypasses', 'items': 'Events Through htram',
           'held': 'Held Stragglers (late or held by htram)'}

def logstats(path):
    out = {}
    for line in open(path, errors='replace'):
        for k, key in LOGKEYS.items():
            if k not in out and line.strip().startswith(key.strip()) and (k != 'msgs' or line.strip().split()[2].isdigit()):
                try: out[k] = float(line.split()[-1])
                except ValueError: pass
    return out

runs = collections.defaultdict(list); dropped = []; counts = collections.defaultdict(set); bad = []
for f in sorted(glob.glob(os.path.join(J, 'n16', '*.csv'))):
    tag = os.path.basename(f)[:-4]
    if tag.startswith('warm'): continue
    for r in csv.DictReader(open(f)):
        if r['status'] != 'ok': bad.append((tag, r['arm'], r['status'])); continue
        if not (r.get('count_waves') or '0').strip('0.'): dropped.append((tag, r['arm'])); continue
        wl, agg, arm = r['workload'], r['agg'], r['arm']
        label = 'r%s_n16_%s_%s_b8_m8_%s' % (r['rep'], wl.replace(':', '_'), agg.replace(':', ''), arm.replace(':', ''))
        lp = os.path.join(J, 'n16', tag, 'ctl_sweep', 'logs', label + '.out')
        ls = logstats(lp) if os.path.exists(lp) else {}
        if not ls: bad.append((tag, arm, 'no log ' + label))
        rep = int(tag.rsplit('_r', 1)[1])
        com = int(r['committed'])
        runs[(wl, agg, arm)].append(dict(rep=rep, rate=float(r['event_rate']) / 1e6, epm=float(r['agg_events_per_msg'] or 0),
            eff=float(r['efficiency']), late=float(r['late_stragglers'] or 0) / com, heldpc=ls.get('held', 0) / com,
            mw=float(r['mean_window'] or 0), rb=int(r['rolled_back']) / com, **{k: ls.get(k, 0) for k in LOGKEYS}))
        counts[wl].add(r['committed'])

med = lambda v, k: st.median(x[k] for x in v)
print('runs kept: %d; dropped without count waves: %d; failed/stalled/missing log: %d' % (sum(map(len, runs.values())), len(dropped), len(bad)))
for b in bad + dropped: print('  ', b)
print('\n# Counts (one per workload; F1-16 in brackets)')
for wl in WL: print('  %-9s %s [%s] %s' % (WL[wl], sorted(counts[wl]), F1_COUNTS[wl], 'SAME' if counts[wl] == {F1_COUNTS[wl]} else 'DIFFER'))

print('\n# Rates (M committed ev/s, median of 5; spread = fastest / slowest rep) and events per htram message')
print('%-9s %-15s | %-26s | %-26s | %s' % ('workload', 'htram', 'W 400: rate spread ev/msg', 'controller: rate spread ev/msg', 'ctl / W400, ctl mean W'))
R = {}
for wl in WL:
    for a in SETTINGS:
        if (wl, a, 'w:400') not in runs: continue
        w, c = runs[(wl, a, 'w:400')], runs[(wl, a, 'mb:0')]
        R[(wl, a)] = (med(w, 'rate'), med(c, 'rate'))
        sp = lambda v: max(x['rate'] for x in v) / min(x['rate'] for x in v)
        print('%-9s %-15s | %7.1f  %.2f  %6.1f      | %7.1f  %.2f  %6.1f          | %.3f, W %.0f' % (
            WL[wl], NAME[a], med(w, 'rate'), sp(w), med(w, 'epm'), med(c, 'rate'), sp(c), med(c, 'epm'), med(c, 'rate') / med(w, 'rate'), med(c, 'mw')))

print('\n# Ratios (medians; higher is better for the first named)')
for wl in WL:
    base = 'wps:512' if (wl, 'wps:512') in R else None
    for i, arm in enumerate(['W 400', 'controller']):
        parts = []
        for a in ['pp:512:l1', 'pp:512:l4']:
            parts.append('%s / PP 512 %.3f' % (NAME[a].replace('PP 512 ', ''), R[(wl, a)][i] / R[(wl, 'pp:512')][i]))
            if base: parts.append('%s / WPs 512 %.3f' % (NAME[a].replace('PP 512 ', ''), R[(wl, a)][i] / R[(wl, base)][i]))
        parts.append('local 4 / local 1 %.3f' % (R[(wl, 'pp:512:l4')][i] / R[(wl, 'pp:512:l1')][i]))
        if base: parts.append('PP 512 / WPs 512 %.3f' % (R[(wl, 'pp:512')][i] / R[(wl, base)][i]))
        print('  %-9s %-10s %s' % (WL[wl], arm, '; '.join(parts)))

print('\n# Message triggers, W 400 (share of htram messages, medians; bypass = events a PE sent alone because the shared buffer was busy or its local buffer full)')
for wl in WL:
    for a in SETTINGS:
        v = runs.get((wl, a, 'w:400'))
        if not v: continue
        sh = lambda k: st.median(x[k] / x['msgs'] for x in v if x['msgs'])
        print('  %-9s %-15s msgs/event %.4f  GVT %.3f  urgent %.4f  full %.4f  idle %.4f  bypass/msgs %.4f' % (
            WL[wl], NAME[a], st.median(x['msgs'] / x['items'] for x in v if x['items']), sh('gvt'), sh('urgent'), sh('full'), sh('idle'), sh('bypass')))

print('\n# Rollbacks, W 400 and controller (medians): efficiency %, rolled back per committed, late stragglers per committed, held stragglers per committed')
for wl in WL:
    for a in SETTINGS:
        for arm in ['w:400', 'mb:0']:
            v = runs.get((wl, a, arm))
            if not v: continue
            print('  %-9s %-15s %-5s eff %.3f  rb %.5f  late %.2e  held %.2e' % (WL[wl], NAME[a], arm, med(v, 'eff'), med(v, 'rb'), med(v, 'late'), med(v, 'heldpc')))

print('\n# Per rep, W 400 (M ev/s, by rep 1-5)')
for wl in WL:
    for a in SETTINGS:
        v = runs.get((wl, a, 'w:400'))
        if v: print('  %-9s %-15s %s' % (WL[wl], NAME[a], ' '.join('%7.1f' % x['rate'] for x in sorted(v, key=lambda x: x['rep']))))
