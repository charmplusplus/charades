#!/usr/bin/env python3
"""Jobs L16/L32 (RESULTS.md section 174): per workload, node count and arm:
rate (M committed ev/s, median of 3), blocked share of PE time (mean over PEs;
least and most PE), mean spell (us), busy PE time per committed event
(us) = (1 - blocked) x PEs / rate, blocked PE time per committed event (us),
max events held on a PE, and the arm / W 300 paired by rep."""
import csv, glob, os, statistics as st, sys
d = sys.argv[1]
rows = []
for f in glob.glob(f'{d}/n*/*_r[123].csv'):
    n = int(f.split('/n')[-1].split('/')[0]); wl = os.path.basename(f).split('_')[0]; rep = int(f[-5])
    for r in csv.DictReader(open(f)):
        if r['status'] != 'ok': print('not ok:', f, r['arm'], r['status']); continue
        r.update(n=n, wl=wl, rp=rep); rows.append(r)
def get(wl, n, a, k):
    for r in rows:
        if r['wl'] == wl and r['n'] == n and r['arm'] == a and r['rp'] == k: return r
def rate(r): return float(r['committed']) / float(r['exec_s']) / 1e6
arms = ['w:250', 'w:300', 'w:400', 'w:500', 'w:600', 'q:0.001']
ns = sorted({r['n'] for r in rows})
for wl in ('g100', 'g2000', 'uni'):
    for n in ns:
        print(f'\n== {wl}, {n} nodes ({n*46} PEs)')
        print(f"{'arm':8} {'M ev/s':>7} {'blk%':>6} {'least':>6} {'most':>6} {'spell us':>8} {'busy us/ev':>10} {'blk us/ev':>9} {'maxev':>6} {'meanW':>6}  ÷W300 by rep")
        for a in arms:
            rs = [get(wl, n, a, k) for k in (1, 2, 3)]
            rs = [r for r in rs if r]
            if not rs: continue
            m = lambda f: st.median(f(r) for r in rs)
            pes = n * 46
            busy = m(lambda r: (1 - float(r['blocked_pct']) / 100) * pes / rate(r))
            blk = m(lambda r: float(r['blocked_pct']) / 100 * pes / rate(r))
            pair = []
            for k in (1, 2, 3):
                x, y = get(wl, n, a, k), get(wl, n, 'w:300', k)
                pair.append(f'{rate(x)/rate(y):.2f}' if x and y else '-')
            print(f"{a:8} {m(rate):7.1f} {m(lambda r: float(r['blocked_pct'])):6.1f} {m(lambda r: float(r['blocked_min_pct'])):6.1f} {m(lambda r: float(r['blocked_max_pct'])):6.1f} {m(lambda r: float(r['spell_us'])):8.1f} {busy:10.3f} {blk:9.3f} {m(lambda r: float(r['max_events'])):6.0f} {m(lambda r: float(r['mean_window'])):6.0f}  {'/'.join(pair)}")
