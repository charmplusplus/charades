#!/usr/bin/env python3
"""Job F4 (charades RESULTS.md section 227): each window policy ÷ the best fixed
W of the same engine and rep, on seven workloads at 4 and 16 nodes.
Charades: fixed W grid, the frozen controller (mb:0), Devastator's rule in
Charades (hill:<bucket>). Devastator: fixed W grid, its own window (adaptive).
Rates are M committed ev/s (higher is better).

Usage: f4_summary.py <job dir>   (e.g. ~/charades-data/f4/f4227/j3684492)
"""
import csv, glob, os, re, statistics as st, sys
from collections import defaultdict

D = sys.argv[1]
WLS = ['phases', 'la10', 'g100', 'g2000', 'uni', 'tr', 'df']
NAME = {'phases': 'phase-changing PHOLD', 'la10': 'lookahead 10, σ 500', 'g100': 'σ 100', 'g2000': 'σ 2,000',
        'uni': 'uniform', 'tr': 'traffic', 'df': 'dragonfly'}
PHOLD = WLS[:5]
CAPD = 120.0

ch = []   # Charades rows
for f in glob.glob(os.path.join(D, 'n*', '*_r[12].csv')):
    N = int(os.path.basename(os.path.dirname(f))[1:])
    wl, rep = re.match(r'(\w+?)_r(\d)\.csv', os.path.basename(f)).groups()
    for r in csv.DictReader(open(f)):
        r.update(N=N, wl=wl, rep=int(rep))
        r['rate'] = float(r['event_rate']) / 1e6 if r['status'] == 'ok' else None
        ch.append(r)
dv = []
for line in open(os.path.join(D, 'deva.txt')):
    kv = dict(t.split('=', 1) for t in line.split() if '=' in t)
    kv['N'], kv['rep'] = int(kv['nodes']), int(kv['rep'])
    kv['rate'] = float(kv['M_ev_s']) if kv['status'] == 'ok' and kv.get('M_ev_s') else None
    dv.append(kv)

def fmt(x, d=2):
    return '—' if x is None else f'{x:.{d}f}'

print('# Counts and digests (one value per workload and node count is right)')
for N in (4, 16):
    for wl in WLS:
        cc = {r['committed'] for r in ch if r['N'] == N and r['wl'] == wl and r['status'] == 'ok'}
        dg = {r['digest'] for r in ch if r['N'] == N and r['wl'] == wl and r['status'] == 'ok' and r.get('digest')}
        dc = {r['committed'] for r in dv if r['N'] == N and r['wl'] == wl and r['status'] == 'ok'}
        bad = [f"C {r['arm']} r{r['rep']} {r['status']}" for r in ch if r['N'] == N and r['wl'] == wl and r['status'] != 'ok'] \
            + [f"D {r['window']} r{r['rep']} {r['status']}" for r in dv if r['N'] == N and r['wl'] == wl and r['status'] != 'ok']
        same = 'same' if cc == dc and len(cc) == 1 else 'DIFFER'
        print(f"n{N:2} {wl:6} Charades counts {sorted(cc)} digests {len(dg)}; Devastator counts {sorted(dc)} -> {same}"
              + (f"; not ok: {', '.join(bad)}" if bad else ''))

def crate(N, wl, arm, rep):
    xs = [r['rate'] for r in ch if r['N'] == N and r['wl'] == wl and r['arm'] == arm and r['rep'] == rep]
    return xs[0] if xs else None
def drate(N, wl, w, rep):
    xs = [r['rate'] for r in dv if r['N'] == N and r['wl'] == wl and r['window'] == w and r['rep'] == rep]
    return xs[0] if xs else None

worst = defaultdict(list)    # policy -> [(ratio, cell)]
single = defaultdict(dict)   # W -> {(N, wl): (rep ratios)}
for N in (4, 16):
    print(f'\n## {N} nodes')
    print('| workload | Charades best fixed W (M ev/s), rep 1 / rep 2 | controller ÷ best (mean W) | hill climb ÷ best (mean W, final W) | other fixed W ÷ best | Devastator best fixed W (M ev/s) | its own window ÷ its best (mean window, efficiency) | Charades best ÷ Devastator best |')
    print('|---|---|---|---|---|---|---|---|')
    for wl in WLS:
        fixed = sorted({r['arm'] for r in ch if r['N'] == N and r['wl'] == wl and r['arm'].startswith('w:')}, key=lambda a: int(a[2:]))
        hill = sorted({r['arm'] for r in ch if r['N'] == N and r['wl'] == wl and r['arm'].startswith('hill:')})
        cells, cbest, others = [], [], defaultdict(list)
        ctl, hl, mw, hw = [], [], [], []
        for rep in (1, 2):
            rates = {a: crate(N, wl, a, rep) for a in fixed}
            ok = {a: x for a, x in rates.items() if x}
            if not ok: continue
            ba = max(ok, key=ok.get); b = ok[ba]; cbest.append((ba, b))
            for a in fixed:
                if a != ba and rates[a]: others[a].append(rates[a] / b)
            m = crate(N, wl, 'mb:0', rep)
            if m: ctl.append(m / b); worst['controller'].append((m / b, f'{wl} n{N} r{rep}'))
            for a in hill:
                h = crate(N, wl, a, rep)
                if h: hl.append(h / b); worst['hill climb'].append((h / b, f'{wl} n{N} r{rep}'))
            for W in ('w:100', 'w:300'):
                if wl in PHOLD and rates.get(W): single[W].setdefault((N, wl), []).append(rates[W] / b)
        mw = [r['mean_window'] for r in ch if r['N'] == N and r['wl'] == wl and r['arm'] == 'mb:0' and r['status'] == 'ok']
        hrs = [r for r in ch if r['N'] == N and r['wl'] == wl and r['arm'].startswith('hill:') and r['status'] == 'ok']
        hw = [f"{float(r['mean_window']):.0f}, {r['final_window']}" for r in hrs]
        hbad = [r['status'] for r in ch if r['N'] == N and r['wl'] == wl and r['arm'].startswith('hill:') and r['status'] != 'ok']
        # Devastator
        dws = sorted({r['window'] for r in dv if r['N'] == N and r['wl'] == wl and r['window'] != 'adaptive'}, key=int)
        dbest, ad, adw = [], [], []
        for rep in (1, 2):
            rates = {w: drate(N, wl, w, rep) for w in dws}
            ok = {w: x for w, x in rates.items() if x}
            if not ok: continue
            bw = max(ok, key=ok.get); b = ok[bw]; dbest.append((bw, b))
            arows = [r for r in dv if r['N'] == N and r['wl'] == wl and r['window'] == 'adaptive' and r['rep'] == rep]
            if arows:
                a = arows[0]
                if a['rate']:
                    ad.append(f"{a['rate'] / b:.2f}"); adw.append(f"{float(a['window_mean'] or 0):.0f}, {a['efficiency']}")
                    worst['Devastator window'].append((a['rate'] / b, f'{wl} n{N} r{rep}'))
                else:
                    # did not finish within the cap: its rate is below committed / cap
                    cnt = next(int(r['committed']) for r in dv if r['N'] == N and r['wl'] == wl and r['status'] == 'ok')
                    ub = cnt / CAPD / 1e6 / b
                    ad.append(f"< {ub:.2f} ({a['status']})"); worst['Devastator window'].append((ub, f'{wl} n{N} r{rep} (< , {a["status"]})'))
        skipped = not any(r for r in dv if r['N'] == N and r['wl'] == wl and r['window'] == 'adaptive')
        x = lambda v: ' / '.join(f'{u:.2f}' for u in v) if v else '—'
        cb = ' / '.join(f"{a[2:]} ({x_:.1f})" for a, x_ in cbest)
        db = ' / '.join(f"{w} ({x_:.1f})" for w, x_ in dbest)
        oth = '; '.join(f"W {a[2:]}: {x(v)}" for a, v in others.items())
        cross = x([c[1] / d[1] for c, d in zip(cbest, dbest)])
        print(f"| {NAME[wl]} | {cb} | {x(ctl)} ({', '.join(f'{float(v):.0f}' for v in mw)}) | {x(hl)}{' ' + ','.join(hbad) if hbad else ''} ({'; '.join(hw)}) | {oth} | {db} | "
              + (f"not run (4-node runs did not finish)" if skipped else f"{' / '.join(ad)} ({'; '.join(adw)})") + f" | {cross} |")

print('\n## Worst case per policy (lowest rep over every cell; Devastator windows that did not finish give an upper bound)')
for p, v in worst.items():
    v.sort()
    print(f"  {p}: {v[0][0]:.2f} ({v[0][1]}); range {v[0][0]:.2f}–{v[-1][0]:.2f} over {len(v)} rep-cells")
print('\n## One fixed W for all five PHOLD workloads: W ÷ the best fixed W (rep 1 / rep 2)')
for W, d in single.items():
    lo = min(min(v) for v in d.values())
    print(f"  {W}: " + '; '.join(f"{wl} n{N} {'/'.join(f'{u:.2f}' for u in v)}" for (N, wl), v in sorted(d.items())) + f"  | worst {lo:.2f}")

print("\n## Devastator's rule in Charades: efficiency (%), mean W, final W per rep")
for N in (4, 16):
    for wl in WLS:
        h = sorted([r for r in ch if r['N'] == N and r['wl'] == wl and r['arm'].startswith('hill')], key=lambda r: r['rep'])
        print(f"  n{N:2} {wl:6} " + ' | '.join(f"r{r['rep']} eff {float(r['efficiency']):.1f} mean W {float(r['mean_window']):.0f} final {r['final_window']}" for r in h))
print("\n## Charades' controller ÷ Devastator's own window, and ÷ Devastator's best fixed W (same rep; rep 1 / rep 2; higher is better for Charades)")
for N in (4, 16):
    for wl in WLS:
        out = []
        for rep in (1, 2):
            c = crate(N, wl, 'mb:0', rep)
            a = drate(N, wl, 'adaptive', rep)
            b = [r['rate'] for r in dv if r['N'] == N and r['wl'] == wl and r['window'] != 'adaptive' and r['rep'] == rep and r['rate']]
            out.append(f"{fmt(c / a if c and a else None)} / {fmt(c / max(b) if c and b else None)}")
        print(f"  n{N:2} {wl:6} " + '   '.join(out))
