#!/usr/bin/env python3
"""Job N (RESULTS.md section 182): the measured rule bracketed (mb:0) and not (m:0)
and the quantile rule (q:0.001) against fixed windows, per workload at 16 and
4 nodes. Rate (M committed ev/s), efficiency, blocked share, mean and final W,
and each arm / the best fixed W of the same rep (higher is better)."""
import csv, glob, os, re, statistics as st, sys
d = sys.argv[1]
rows = []
for f in glob.glob(f'{d}/n*/*_r[12].csv'):
    n = int(f.split('/n')[-1].split('/')[0]); tag = os.path.basename(f)[:-4]
    kind, rep = tag.rsplit('_r', 1)
    for r in csv.DictReader(open(f)):
        r.update(n=n, kind=kind, rp=int(rep)); rows.append(r)
def rate(r): return float(r['committed']) / float(r['exec_s']) / 1e6
def mlog(n, kind, rep, arm):
    fs = glob.glob(f"{d}/n{n}/{kind}_r{rep}/ctl_sweep/logs/*_{arm.replace(':', '')}.out")
    if not fs: return ''
    t = open(fs[0]).read()
    k = re.search(r'Trials kept\s+(\d+) of (\d+)', t); s = re.search(r'Final step\s+([\d.]+)', t)
    return f"{k.group(1)}/{k.group(2)} step {s.group(1)}" if k and s else ''
KINDS = ('phases', 'la10', 'g100', 'g2000', 'uni', 'traffic', 'df')
worst = {}
for n in (16, 4):
    for kind in KINDS:
        rs = [r for r in rows if r['n'] == n and r['kind'] == kind]
        if not rs: continue
        best = {}
        for k in (1, 2):
            fx = {r['arm']: rate(r) for r in rs if r['rp'] == k and r['arm'].startswith('w')}
            best[k] = max(fx.values())
        fixed_arms = sorted({r['arm'] for r in rs if r['arm'].startswith('w')}, key=lambda a: float(a.split(':')[1]))
        best_arm = max(fixed_arms, key=lambda a: st.median(rate(r) for r in rs if r['arm'] == a))
        print(f'\n== {n} nodes, {kind}; best fixed W by median: {best_arm}')
        print(f"{'arm':8} {'M ev/s':>8} {'eff%':>6} {'blk%':>5} {'meanW':>7} {'finalW':>7}  {'÷best (r1/r2)':>13}  trials")
        for a in fixed_arms + ['q:0.001', 'm:0', 'mb:0']:
            ar = sorted([r for r in rs if r['arm'] == a], key=lambda r: r['rp'])
            if not ar: continue
            m = lambda f: st.median(f(r) for r in ar)
            ratios = [rate(r) / best[r['rp']] for r in ar]
            worst.setdefault(a.split(':')[0], []).append((min(ratios), n, kind))
            print(f"{a:8} {m(rate):8.1f} {m(lambda r: float(r['efficiency'])):6.2f} {m(lambda r: float(r['blocked_pct'] or 0)):5.1f} "
                  f"{m(lambda r: float(r['mean_window'] or 0)):7.0f} {m(lambda r: float(r['final_window'] or 0)):7.0f}  "
                  f"{'/'.join(f'{x:.2f}' for x in ratios):>13}  {' | '.join(mlog(n, kind, r['rp'], a) for r in ar) if a.startswith('m') else ''}")
print('\n== worst ratio to the best fixed W of the same rep')
for a, v in worst.items():
    v.sort()
    print(a, ' '.join(f'{x:.2f}({n}n {k})' for x, n, k in v[:6]))
