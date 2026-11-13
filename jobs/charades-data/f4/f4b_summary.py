#!/usr/bin/env python3
"""Job F4b (charades results/controller.md section 250): F4 rerun without
diagnostics. Each window policy ÷ the best fixed W of the same engine and rep,
on seven workloads at 4 and 16 nodes, against F4 (section 230) and F4R
(section 232; phase-changing PHOLD at 16 nodes).
Charades timing arms: fixed W grid, the frozen controller (mb:0), Devastator's
rule in Charades (hill:<bucket>). Check arm "old" (files <wl>_old_r<rep>.csv):
the controller with F4's --blocked-time=1 --ctl-log=1 --commit-digest=1; it is
kept out of every timing comparison. Devastator: fixed W grid and its own
window (adaptive, capped at 120 s). Rates are M committed ev/s (higher is better).
Usage: f4b_summary.py <F4b job dir> <F4 job dir> <F4R job dir>"""
import csv, glob, os, re, statistics as st, sys
from collections import defaultdict
NEW, F4, F4R = sys.argv[1], sys.argv[2], sys.argv[3]
WLS = ['phases', 'la10', 'g100', 'g2000', 'uni', 'tr', 'df']
NAME = {'phases': 'phase-changing PHOLD', 'la10': 'lookahead 10, σ 500', 'g100': 'σ 100', 'g2000': 'σ 2,000',
        'uni': 'uniform', 'tr': 'traffic', 'df': 'dragonfly'}
PHOLD = WLS[:5]; CAPD = 120.0

def load(D, only=None):
    ch, old = [], []
    for f in glob.glob(os.path.join(D, 'n*', '*_r[0-9].csv')):
        N = int(os.path.basename(os.path.dirname(f))[1:])
        m = re.match(r'(\w+?)(_old)?_r(\d)\.csv', os.path.basename(f))
        if not m or m.group(1) == 'warm': continue
        wl, isold, rep = m.group(1), m.group(2), int(m.group(3))
        if only and (N, wl) not in only: continue
        for r in csv.DictReader(open(f)):
            r.update(N=N, wl=wl, rep=rep)
            r['rate'] = float(r['event_rate']) / 1e6 if r['status'] == 'ok' else None
            (old if isold else ch).append(r)
    dv = []
    p = os.path.join(D, 'deva.txt')
    for line in (open(p) if os.path.exists(p) else []):
        kv = dict(t.split('=', 1) for t in line.split() if '=' in t)
        kv['N'], kv['rep'] = int(kv['nodes']), int(kv['rep'])
        kv['rate'] = float(kv['M_ev_s']) if kv['status'] == 'ok' and kv.get('M_ev_s') else None
        dv.append(kv)
    return ch, old, dv
ch, old, dv = load(NEW)
o4, _, d4 = load(F4)
# F4R replaces F4's phase-changing PHOLD cell at 16 nodes
o4 = [r for r in o4 if not (r['N'] == 16 and r['wl'] == 'phases')] + load(F4R, {(16, 'phases')})[0]
REPS = sorted({r['rep'] for r in ch})
med = lambda x: st.median(x) if x else None
def rng(x, d=2):
    if not x: return '—'
    lo, hi = f'{min(x):.{d}f}', f'{max(x):.{d}f}'
    return lo if lo == hi else f'{lo}–{hi}'
fmt = lambda x, d=2: '—' if x is None else f'{x:.{d}f}'

def cr(rows, N, wl, arm, rep):
    x = [r['rate'] for r in rows if r['N'] == N and r['wl'] == wl and r['arm'] == arm and r['rep'] == rep]
    return x[0] if x else None
def dr(rows, N, wl, w, rep):
    x = [r['rate'] for r in rows if r['N'] == N and r['wl'] == wl and r['window'] == w and r['rep'] == rep]
    return x[0] if x else None
def fixed(rows, N, wl):
    return sorted({r['arm'] for r in rows if r['N'] == N and r['wl'] == wl and r['arm'].startswith('w:')}, key=lambda a: int(a[2:]))
def dfixed(rows, N, wl):
    return sorted({r['window'] for r in rows if r['N'] == N and r['wl'] == wl and r['window'] != 'adaptive'}, key=int)
def cbest(rows, N, wl, rep):
    ok = {a: cr(rows, N, wl, a, rep) for a in fixed(rows, N, wl)}
    ok = {a: x for a, x in ok.items() if x}
    return (max(ok, key=ok.get), max(ok.values())) if ok else (None, None)
def dbest(rows, N, wl, rep):
    ok = {w: dr(rows, N, wl, w, rep) for w in dfixed(rows, N, wl)}
    ok = {w: x for w, x in ok.items() if x}
    return (max(ok, key=ok.get), max(ok.values())) if ok else (None, None)
def policy(rows, N, wl, pick):   # per-rep ratios of a Charades policy to the rep's best fixed W
    out = []
    for rep in sorted({r['rep'] for r in rows}):
        b = cbest(rows, N, wl, rep)[1]
        arms = [r['arm'] for r in rows if r['N'] == N and r['wl'] == wl and r['rep'] == rep and pick(r['arm'])]
        x = cr(rows, N, wl, arms[0], rep) if arms else None
        if b and x: out.append(x / b)
    return out

print('# Counts and digests (one count per cell in both engines; digests from the old arm, against F4\'s)')
for N in (4, 16):
    for wl in WLS:
        cc = {r['committed'] for r in ch + old if r['N'] == N and r['wl'] == wl and r['status'] == 'ok'}
        dc = {r['committed'] for r in dv if r['N'] == N and r['wl'] == wl and r['status'] == 'ok'}
        dg = {r['digest'] for r in old if r['N'] == N and r['wl'] == wl and r['status'] == 'ok' and r.get('digest')}
        dg4 = {r['digest'] for r in o4 if r['N'] == N and r['wl'] == wl and r['status'] == 'ok' and r.get('digest')}
        c4 = {r['committed'] for r in o4 if r['N'] == N and r['wl'] == wl and r['status'] == 'ok'}
        bad = [f"C {r['arm']} r{r['rep']} {r['status']}" for r in ch + old if r['N'] == N and r['wl'] == wl and r['status'] != 'ok'] \
            + [f"D {r['window']} r{r['rep']} {r['status']}" for r in dv if r['N'] == N and r['wl'] == wl and r['status'] != 'ok']
        print(f"n{N:2} {wl:6} counts C {sorted(cc)} D {sorted(dc)} -> {'one' if cc == dc and len(cc) == 1 else 'DIFFER'}"
              f"{', as F4' if cc == c4 else ', NOT F4: ' + str(sorted(c4))}; digests {len(dg)}"
              f"{' = F4' if dg == dg4 and len(dg) == 1 else ' DIFFER FROM F4 ' + str([d[:10] for d in dg4])}" + (f"; not ok: {', '.join(bad)}" if bad else ''))

print('\n# Disturbed reps: fixed-W runs above 1.03 count waves per GVT advance (F4: W 25 on lookahead 10 at 1.33 throughout)')
dist = [f"n{r['N']} {r['wl']} {r['arm']} r{r['rep']} {float(r['count_waves']) / float(r['gvts']):.3f}" for r in ch
        if r['arm'].startswith('w:') and r['status'] == 'ok' and float(r['count_waves']) / float(r['gvts']) > 1.03]
print('  ' + ('; '.join(dist) if dist else 'none'))
print('\n# Trials past the reach (section 237; 0 = the same decisions as without it), every controller run')
tp = defaultdict(list)
for f in glob.glob(os.path.join(NEW, 'n*', '*_r[0-9]', 'ctl_sweep', 'logs', '*_mb0.out')):
    m = re.search(r'Trials past it \(reach buckets\)\s+(\d+)', open(f, errors='replace').read())
    tp[m.group(1) if m else 'missing'].append(os.path.basename(f))
print('  ' + ', '.join(f'{k}: {len(v)} runs' for k, v in tp.items()) + (f"  e.g. {tp[[k for k in tp if k != '0'][0]][:3]}" if [k for k in tp if k != '0'] else ''))

worst = defaultdict(list); single = defaultdict(dict)
cross = []
for N in (4, 16):
    print(f'\n## {N} nodes: each policy ÷ the best fixed W of the same engine and rep (median, range over reps; F4 in brackets, mean of its reps)')
    print('| workload | Charades best fixed W (median M ev/s; ÷ F4) | controller (mean W) | Devastator\'s rule in Charades | Devastator best fixed W (median M ev/s; ÷ F4) | Devastator\'s own window | Charades best ÷ Devastator best (medians; ÷ its fastest rep) [F4] |')
    print('|---|---|---|---|---|---|---|')
    for wl in WLS:
        bs = [cbest(ch, N, wl, r) for r in REPS]; bs4 = [cbest(o4, N, wl, r) for r in sorted({r['rep'] for r in o4})]
        cb = med([b for _, b in bs if b]); cb4 = st.mean([b for _, b in bs4 if b])
        ctl = policy(ch, N, wl, lambda a: a == 'mb:0'); ctl4 = policy(o4, N, wl, lambda a: a == 'mb:0')
        hil = policy(ch, N, wl, lambda a: a.startswith('hill:')); hil4 = policy(o4, N, wl, lambda a: a.startswith('hill:'))
        for x, rep in zip(ctl, REPS): worst['controller'].append((x, f'{wl} n{N} r{rep}'))
        for x, rep in zip(hil, REPS): worst["Devastator's rule in Charades"].append((x, f'{wl} n{N} r{rep}'))
        mw = [float(r['mean_window']) for r in ch if r['N'] == N and r['wl'] == wl and r['arm'] == 'mb:0' and r['status'] == 'ok']
        hbad = [f"r{r['rep']} {r['status']}" for r in ch if r['N'] == N and r['wl'] == wl and r['arm'].startswith('hill:') and r['status'] != 'ok']
        if wl in PHOLD:
            for W in ('w:100', 'w:300'):
                v = [cr(ch, N, wl, W, rep) / cbest(ch, N, wl, rep)[1] for rep in REPS if cr(ch, N, wl, W, rep) and cbest(ch, N, wl, rep)[1]]
                if v: single[W][(N, wl)] = v
        dbs = [dbest(dv, N, wl, r) for r in REPS]; dbs4 = [dbest(d4, N, wl, r) for r in (1, 2)]
        db = med([b for _, b in dbs if b]); db4 = st.mean([b for _, b in dbs4 if b]); dfast = max([b for _, b in dbs if b])
        ad, adtxt = [], []
        for rep in REPS:
            b = dbest(dv, N, wl, rep)[1]
            a = [r for r in dv if r['N'] == N and r['wl'] == wl and r['window'] == 'adaptive' and r['rep'] == rep]
            if not a: continue
            if a[0]['rate'] and b: ad.append(a[0]['rate'] / b); worst["Devastator's own window"].append((a[0]['rate'] / b, f'{wl} n{N} r{rep}'))
            elif b:
                cnt = int(next(r['committed'] for r in dv if r['N'] == N and r['wl'] == wl and r['status'] == 'ok'))
                ub = cnt / CAPD / 1e6 / b; adtxt.append(f'r{rep} < {ub:.2f} ({a[0]["status"]})')
                worst["Devastator's own window"].append((ub, f'{wl} n{N} r{rep} (<, {a[0]["status"]})'))
        ownd = (f"{fmt(med(ad))} ({rng(ad)})" if ad else '') + ('; ' if ad and adtxt else '') + '; '.join(adtxt)
        if not ad and not adtxt: ownd = 'skipped (capped before)'
        cw = '/'.join(sorted({a[2:] for a, _ in bs if a}, key=int))
        dw = '/'.join(sorted({w for w, _ in dbs if w}, key=int))
        x = cb / db; x4 = cb4 / db4; cross.append((x, x / x4, f'{wl} n{N}'))
        print(f"| {NAME[wl]} | {cw} ({cb:.1f}; {cb / cb4:.3f}) | {fmt(med(ctl))} ({rng(ctl)}) [{fmt(st.mean(ctl4)) if ctl4 else '—'}] ({', '.join(f'{v:.0f}' for v in mw)}) | "
              f"{fmt(med(hil))} ({rng(hil)}){' ' + ','.join(hbad) if hbad else ''} [{fmt(st.mean(hil4)) if hil4 else '—'}] | {dw} ({db:.1f}; {db / db4:.3f}) | {ownd} | {x:.2f} ({cb / dfast:.2f}) [{x4:.2f}] |")

print('\n## Worst case per policy (lowest rep-cell; Devastator windows that did not finish give an upper bound)')
for p, v in worst.items():
    v.sort(); print(f"  {p}: {v[0][0]:.2f} ({v[0][1]}); range {v[0][0]:.2f}–{v[-1][0]:.2f} over {len(v)} rep-cells")
for W, d in single.items():
    lo = min(min(v) for v in d.values()); at = min(d, key=lambda k: min(d[k]))
    print(f"  one fixed {W} for all five PHOLD workloads: worst {lo:.2f} (n{at[0]} {at[1]})")
print('\n## Charades ÷ Devastator, each at its best fixed W: F4b ÷ F4 per cell: ' + rng([c[1] for c in cross], 3) + f"; range {rng([c[0] for c in cross])}")

print('\n## The old flags: old arm ÷ the controller, paired per rep (median, range; higher = the flags cost less)')
for N in (4, 16):
    out = []
    for wl in WLS:
        v = [o['rate'] / cr(ch, N, wl, 'mb:0', o['rep']) for o in old if o['N'] == N and o['wl'] == wl and o['rate'] and cr(ch, N, wl, 'mb:0', o['rep'])]
        out.append(f"{wl} {fmt(med(v), 3)} ({rng(v, 3)})")
    print(f'  n{N}: ' + '; '.join(out))

print("\n## Devastator's rule in Charades: efficiency (%), mean W, final W per rep")
for N in (4, 16):
    for wl in WLS:
        h = sorted([r for r in ch if r['N'] == N and r['wl'] == wl and r['arm'].startswith('hill') and r['status'] == 'ok'], key=lambda r: r['rep'])
        print(f"  n{N:2} {wl:6} " + ' | '.join(f"r{r['rep']} eff {float(r['efficiency']):.1f} mean W {float(r['mean_window']):.0f} final {r['final_window']}" for r in h))
print('\n## Spread between reps (max ÷ min): Charades best fixed W rate, controller; Devastator best fixed W rate')
for N in (4, 16):
    out = []
    for wl in WLS:
        c = [b for _, b in (cbest(ch, N, wl, r) for r in REPS) if b]; m = [x for x in (cr(ch, N, wl, 'mb:0', r) for r in REPS) if x]
        d = [b for _, b in (dbest(dv, N, wl, r) for r in REPS) if b]
        out.append(f"{wl} {max(c) / min(c):.3f}/{max(m) / min(m):.3f}/{max(d) / min(d):.3f}")
    print(f'  n{N}: ' + '; '.join(out))
