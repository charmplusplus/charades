#!/usr/bin/env python3
"""Job VA (charades results/vlsi.md §249; design §247): VLSI at 1-16 nodes
without diagnostics, VS3's layout and arms, against VS3 (§239), which ran with
--blocked-time, --ctl-log, --commit-digest, --copy-stats and --pe-stats on every
Charades arm. Timing arms: E W 5,000, E W 2,500, L W 2,500, the controller.
Check arms at E W 5,000: O (the old diagnostics), G (--commit-digest), R
(--report-interval=1000000); they are kept out of every timing comparison.
Usage: vscale249_summary.py <VA job dir> <VS3 job dir>"""
import csv, glob, os, statistics as st, sys
NEW, OLD = sys.argv[1], sys.argv[2]
NODES = [1, 2, 4, 8, 16]; REPS = ['r1', 'r2', 'r3']
TIME = [('E', 'w5000'), ('E', 'w2500'), ('L', 'w2500'), ('E', 'mb0')]
FIXED = TIME[:3]; CHECK = [('O', 'w5000'), ('G', 'w5000'), ('R', 'w5000')]
DW = ['2500', '5000', '10000']
nm = lambda a: f"{a[0]} {'W ' + a[1][1:] if a[1].startswith('w') else 'controller'}"
med = lambda x: st.median([v for v in x if v is not None]) if [v for v in x if v is not None] else None
def rng(x, d=3):
    x = [v for v in x if v is not None]
    if not x: return '—'
    lo, hi = f'{min(x):.{d}f}', f'{max(x):.{d}f}'
    return lo if lo == hi else f'{lo}–{hi}'
def crow(D, N, rep, a):
    f = os.path.join(D, f'n{N}', rep, f'{a[0]}_{a[1]}.csv')
    if not os.path.exists(f): return None
    r = list(csv.DictReader(open(f)))
    return r[0] if len(r) == 1 and r[0]['status'] == 'ok' else None
def crate(D, N, rep, a):
    r = crow(D, N, rep, a); return float(r['event_rate']) / 1e6 if r else None
def dv(D):
    return [dict(t.split('=', 1) for t in l.split() if '=' in t) for l in open(os.path.join(D, 'deva.txt'))]
DVN, DVO = dv(NEW), dv(OLD)
def drate(rows, N, rep, w):
    x = [float(k['M_ev_s']) for k in rows if k['nodes'] == str(N) and k['rep'] == rep[1:] and k['window'] == w and k['status'] == 'ok' and k.get('M_ev_s')]
    return x[0] if x else None

print('# Counts and digests (digests from the O and G arms only)')
for N in NODES:
    c, g, bad = set(), set(), []
    for rep in REPS:
        for a in TIME + CHECK:
            r = crow(NEW, N, rep, a)
            if not r: bad.append(f'{rep} {nm(a)}'); continue
            c.add(r['committed'])
            if a[0] in 'OG': g.add(r['digest'])
    dc = {k['committed'] for k in DVN if k['nodes'] == str(N) and k['status'] == 'ok'}
    og = {crow(OLD, N, rep, a)['digest'] for rep in REPS for a in TIME if crow(OLD, N, rep, a)}
    bad += [f"dv W{k['window']} r{k['rep']} {k['status']}" for k in DVN if k['nodes'] == str(N) and k['status'] != 'ok']
    print(f"n{N:2}: Charades {sorted(c)}, digests {sorted(g)} (VS3: {sorted(og)}); Devastator {sorted(dc)} -> "
          f"{'same count' if c == dc and len(c) == 1 else 'DIFFER'}{', same digest as VS3' if g == og else ', DIGEST DIFFERS FROM VS3'}" + (f'  NOT OK: {bad}' if bad else ''))

print('\n# Rates (M committed ev/s, median of 3; higher is better); VS3 in brackets')
print('| nodes | ' + ' | '.join(f'Charades {nm(a)}' for a in TIME) + ' | ' + ' | '.join(f'Devastator W {w}' for w in DW) + ' |')
print('|---|' + '---|' * (len(TIME) + len(DW)))
for N in NODES:
    print(f'| {N} | ' + ' | '.join(f'{med([crate(NEW, N, r, a) for r in REPS]):.2f} ({med([crate(OLD, N, r, a) for r in REPS]):.2f})' for a in TIME) + ' | '
          + ' | '.join(f'{med([drate(DVN, N, r, w) for r in REPS]):.2f} ({med([drate(DVO, N, r, w) for r in REPS]):.2f})' for w in DW) + ' |')

def best(D, rows, N):
    cb = med([max(x for x in [crate(D, N, r, a) for a in FIXED] if x) for r in REPS])
    cm = {a: med([crate(D, N, r, a) for r in REPS]) for a in FIXED}
    dm = {w: med([drate(rows, N, r, w) for r in REPS]) for w in DW}
    bw = max(dm, key=dm.get)
    return dict(cfix=max(cm.values()), cfa=max(cm, key=cm.get), ctl=med([crate(D, N, r, TIME[3]) for r in REPS]), dev=dm[bw], dw=bw)
print('\n# Each engine at its best (medians); Charades ÷ Devastator, higher is better; VS3 in brackets')
print('| nodes | Charades best fixed | Charades controller | Devastator best | C fixed ÷ D | C controller ÷ D | controller ÷ best fixed, per rep | C fixed ÷ VS3 | C controller ÷ VS3 | D ÷ VS3 |')
print('|---|---|---|---|---|---|---|---|---|---|')
bn = {}
for N in NODES:
    n, o = best(NEW, DVN, N), best(OLD, DVO, N); bn[N] = n
    per = []
    for r in REPS:
        fx = [x for x in [crate(NEW, N, r, a) for a in FIXED] if x]; c = crate(NEW, N, r, TIME[3])
        if fx and c: per.append(c / max(fx))
    print(f"| {N} | {nm(n['cfa'])} {n['cfix']:.1f} | {n['ctl']:.1f} | W {n['dw']} {n['dev']:.1f} | {n['cfix'] / n['dev']:.2f} ({o['cfix'] / o['dev']:.2f}) | "
          f"{n['ctl'] / n['dev']:.2f} ({o['ctl'] / o['dev']:.2f}) | {rng(per)} | {n['cfix'] / o['cfix']:.3f} | {n['ctl'] / o['ctl']:.3f} | {n['dev'] / o['dev']:.3f} |")
print('per-node rate 16 ÷ 1: Charades best fixed %.3f, controller %.3f, Devastator %.3f' % (
    bn[16]['cfix'] / 16 / bn[1]['cfix'], bn[16]['ctl'] / 16 / bn[1]['ctl'], bn[16]['dev'] / 16 / bn[1]['dev']))

print('\n# Check arms ÷ E W 5,000, paired per rep (median, range); higher means the flags cost less')
for a, what in zip(CHECK, ['old diagnostics', '--commit-digest', 'no GVT progress print']):
    out = []
    for N in NODES:
        x = [crate(NEW, N, r, a) / crate(NEW, N, r, TIME[0]) for r in REPS if crate(NEW, N, r, a) and crate(NEW, N, r, TIME[0])]
        out.append(f'{N}: {med(x):.3f} ({rng(x)})')
    print(f'  {a[0]} ({what}): ' + '  '.join(out))

print('\n# Spread between reps (max ÷ min), Charades timing arms and Devastator\'s best W')
for N in NODES:
    s = [f"{nm(a)} {max(v) / min(v):.3f}" for a in TIME for v in [[x for x in [crate(NEW, N, r, a) for r in REPS] if x]] if v]
    d = [x for x in [drate(DVN, N, r, bn[N]['dw']) for r in REPS] if x]
    print(f'  n{N}: ' + ', '.join(s) + f", Devastator W {bn[N]['dw']} {max(d) / min(d):.3f}")
