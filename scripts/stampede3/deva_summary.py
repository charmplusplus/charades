#!/usr/bin/env python3
"""Devastator runs from run_phold.sh's results.txt (full_rerun.sh labels
<tag>_s<sigma>_w<window>_rep<n>): per workload, each arm's median committed
events/s (M) and ÷ the best fixed window (higher is better), median
efficiency, and the adaptive window's geometric-mean window.

Usage: deva_summary.py results.txt [more ...]
"""
import re
import statistics
import sys
from collections import defaultdict

runs = defaultdict(list)
bad = defaultdict(int)
for path in sys.argv[1:]:
    for line in open(path):
        kv = dict(x.split('=', 1) for x in line.split() if '=' in x)
        m = re.match(r'(.+)_s([\d.]+)_w(\w+)_rep\d+$', kv.get('label', ''))
        if not m:
            continue
        wl = '%s σ %s' % (m[1], m[2]) if m[2] != '0' else '%s uniform' % m[1]
        if kv.get('status') != 'ok' or 'committed_per_s' not in kv:
            bad[(wl, m[3])] += 1
            continue
        runs[(wl, m[3])].append(kv)

med = statistics.median
for wl in sorted({k[0] for k in runs} | {k[0] for k in bad}):
    arms = sorted({k[1] for k in list(runs) + list(bad) if k[0] == wl},
                  key=lambda a: (a != 'adaptive', int(a) if a.isdigit() else 0))
    rate = {a: med(float(r['committed_per_s']) / 1e6 for r in runs[(wl, a)])
            for a in arms if runs.get((wl, a))}
    fixed = {a: v for a, v in rate.items() if a != 'adaptive'}
    if not fixed:
        continue
    bw = max(fixed, key=fixed.get)
    print('\n%s: best fixed W %s = %.1f M ev/s' % (wl, bw, fixed[bw]))
    print('  %-9s %9s %8s %9s %10s %4s' % ('arm', 'M ev/s', '÷ best', 'eff %', 'geo W', 'n/x'))
    for a in arms:
        rs = runs.get((wl, a), [])
        if not rs:
            print('  %-9s %9s %8s %9s %10s %d/%d' % (a, '-', '-', '-', '-', 0, bad[(wl, a)]))
            continue
        geo = med(float(r['window_geomean']) for r in rs) if a == 'adaptive' else float(a)
        print('  %-9s %9.1f %8.2f %9.1f %10.3g %d/%d' % (
            a, rate[a], rate[a] / fixed[bw], 100 * med(float(r['efficiency']) for r in rs),
            geo, len(rs), bad[(wl, a)]))
