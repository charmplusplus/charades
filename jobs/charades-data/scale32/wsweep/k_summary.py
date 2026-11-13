#!/usr/bin/env python3
"""Job K (RESULTS.md section 167): best fixed W per workload at 16 and 32 nodes,
GVT lag against W, controller / best, events per message. Rates in M ev/s
(committed / exec_s), ratios paired by rep."""
import csv, glob, os, statistics as st, sys
d = sys.argv[1] if len(sys.argv) > 1 else '.'
rows = []
for n in (16, 32):
    for f in sorted(glob.glob(f'{d}/n{n}/*_r[123].csv')):
        wl = os.path.basename(f).split('_')[0]
        rep = int(f[-5])
        for r in csv.DictReader(open(f)):
            r['wl'] = wl; r['rep'] = rep; r['n'] = n
            rows.append(r)
arms = ['w:250', 'w:300', 'w:400', 'w:500', 'w:600', 'q:0.001']
def get(wl, n, arm, rep):
    for r in rows:
        if r['wl'] == wl and r['n'] == n and r['arm'] == arm and r['rep'] == rep and r['status'] == 'ok':
            return r
def rate(r): return float(r['committed']) / float(r['exec_s']) / 1e6
for wl in ('g100', 'g2000', 'uni'):
    for n in (16, 32):
        print(f'\n== {wl} at {n} nodes')
        print(f"{'arm':8} {'rate r1,r2,r3 (M ev/s)':30} {'median':>7} {'/W300':>6} {'lag':>6} {'W-lag':>6} {'ev/msg':>6} {'eff%':>6} {'meanW':>6} {'rb/1e6':>7}")
        med = {}
        for a in arms:
            rs = [get(wl, n, a, k) for k in (1, 2, 3)]
            if not all(rs): print(a, 'missing'); continue
            v = [rate(r) for r in rs]
            med[a] = st.median(v)
            w300 = [rate(get(wl, n, 'w:300', k)) for k in (1, 2, 3)]
            ratio = st.median([x / y for x, y in zip(v, w300)])
            lag = st.median([float(r['gvt_lag']) for r in rs])
            mw = st.median([float(r['mean_window']) for r in rs])
            epm = st.median([float(r['agg_events_per_msg']) for r in rs])
            eff = st.median([float(r['efficiency']) for r in rs])
            rb = st.median([float(r['rolled_back']) / float(r['committed']) * 1e6 for r in rs])
            print(f"{a:8} {', '.join(f'{x:6.1f}' for x in v):30} {med[a]:7.1f} {ratio:6.3f} {lag:6.0f} {mw - lag:6.0f} {epm:6.1f} {eff:6.2f} {mw:6.0f} {rb:7.1f}")
        fixed = [a for a in arms if a.startswith('w:')]
        best = max(fixed, key=lambda a: med.get(a, 0))
        # paired controller / best fixed
        c = [rate(get(wl, n, 'q:0.001', k)) / rate(get(wl, n, best, k)) for k in (1, 2, 3)]
        b3 = [rate(get(wl, n, best, k)) / rate(get(wl, n, 'w:300', k)) for k in (1, 2, 3)]
        print(f'best fixed {best}; controller / best per rep {", ".join(f"{x:.3f}" for x in c)} (median {st.median(c):.3f}); best / W300 per rep {", ".join(f"{x:.3f}" for x in b3)}')
