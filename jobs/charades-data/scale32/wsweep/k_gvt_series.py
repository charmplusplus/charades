#!/usr/bin/env python3
"""Job K: wall time per printed GVT step (the GVT progress lines), per run.
Median step, p90, p99, and the time above 2x the median (stall time)."""
import glob, re, os, statistics as st, sys, collections
d = sys.argv[1]
R = collections.defaultdict(list)
for f in glob.glob(f'{d}/n*/*_r[123]/ctl_sweep/logs/*.out'):
    n = int(f.split('/n')[1].split('/')[0]); wl = f.split('/')[-4].split('_')[0]
    rep = int(f.split('/')[-4][-1])
    arm = re.search(r'_(w\d+|q[\d.]+)\.out$', f).group(1)
    g, t = [], []
    for line in open(f):
        m = re.match(r'GVT\s+\d+:\s+(\d+) \(.*\), [\d.]+ MB, ([\d.]+) s', line)
        if m: g.append(int(m.group(1))); t.append(float(m.group(2)))
    if len(t) < 100: continue
    dg = [g[i+1]-g[i] for i in range(len(g)-1)]
    dt = [(t[i+1]-t[i]) / max(1, dg[i]) * 1e6 for i in range(len(t)-1)]  # us per GVT unit
    dts = sorted(dt); med = st.median(dt)
    stall = sum((t[i+1]-t[i]) for i in range(len(t)-1) if dt[i] > 2 * med)
    R[(wl, n, arm)].append((rep, med, dts[int(.9*len(dts))], dts[int(.99*len(dts))], stall, t[-1], st.median(dg)))
order = ['w250', 'w300', 'w400', 'w500', 'w600', 'q0.001']
for wl in ('g100', 'g2000', 'uni'):
    for n in (16, 32):
        print(f'\n== {wl} {n} nodes: per rep  (us per GVT unit: median / p90 / p99;  s in steps > 2x median;  run s)')
        for a in order:
            v = sorted(R[(wl, n, a)])
            print(f'{a:7}', '  '.join(f'r{r}: {m:5.2f}/{p9:5.2f}/{p99:6.2f} {s:4.2f}s {T:4.2f}s' for r, m, p9, p99, s, T, dgm in v), f' step {v[0][6]}')
