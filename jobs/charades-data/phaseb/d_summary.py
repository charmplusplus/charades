#!/usr/bin/env python3
"""Job D (RESULTS.md section 178): dragonfly W sweep and controller variants at
1 and 4 nodes. Rate (M committed ev/s), efficiency, blocked share, and for the
controller arms the time-weighted mean W and W over the last 20% of rounds
(from --ctl-log), each arm / the best fixed W paired by rep."""
import csv, glob, os, re, statistics as st, sys
d = sys.argv[1]
rows = []
for f in glob.glob(f'{d}/n*/*_r[123].csv'):
    n = int(f.split('/n')[-1].split('/')[0]); tag = os.path.basename(f)[:-4]
    kind, rep = tag.rsplit('_r', 1)
    for r in csv.DictReader(open(f)):
        r.update(n=n, kind=kind, rp=int(rep)); rows.append(r)
def rate(r): return float(r['committed']) / float(r['exec_s']) / 1e6
def ctl_tail(n, kind, rep, arm):
    pat = f"{d}/n{n}/{kind}_r{rep}/ctl_sweep/logs/*_{arm.replace(':', '')}.out"
    fs = glob.glob(pat)
    if not fs: return None, None
    ws = [int(m.group(1)) for m in re.finditer(r'^CTL round \d+ gvt \d+ window (\d+)', open(fs[0]).read(), re.M)]
    if not ws: return None, None
    tail = ws[int(0.8 * len(ws)):]
    return st.median(tail), len(ws)
for n in (1, 4):
    fixed = {}
    for k in (1, 2, 3):
        fx = [r for r in rows if r['n'] == n and r['kind'] == 'fixed' and r['rp'] == k]
        fixed[k] = {r['arm']: rate(r) for r in fx}
    best_arm = max(fixed[1], key=lambda a: st.median(fixed[k].get(a, 0) for k in (1, 2, 3)))
    print(f'\n== {n} node(s); best fixed W by median: {best_arm}')
    print(f"{'kind':8} {'arm':8} {'M ev/s':>7} {'eff%':>6} {'blk%':>6} {'meanW':>7} {'W last20%':>9}  ÷ best fixed W (reps)")
    for kind in ('fixed', 'ctl', 'ctla', 'pp', 'direct'):
        arms = sorted({r['arm'] for r in rows if r['n'] == n and r['kind'] == kind}, key=lambda a: (a[0], float(a.split(':')[1])))
        for a in arms:
            rs = [r for r in rows if r['n'] == n and r['kind'] == kind and r['arm'] == a]
            m = lambda f: st.median(f(r) for r in rs)
            pair = '/'.join(f"{rate(r) / fixed[r['rp']][best_arm]:.2f}" for r in sorted(rs, key=lambda r: r['rp']))
            tails = [ctl_tail(n, kind, r['rp'], a)[0] for r in rs] if a.startswith('q') else []
            tails = [t for t in tails if t]
            mw = m(lambda r: float(r['mean_window'] or 0))
            print(f"{kind:8} {a:8} {m(rate):7.1f} {m(lambda r: float(r['efficiency'])):6.2f} {m(lambda r: float(r['blocked_pct'] or 0)):6.1f} {mw:7.0f} {(st.median(tails) if tails else float('nan')):9.0f}  {pair}")
