#!/usr/bin/env python3
"""Job V32b (charades results/vlsi.md section 254; design sections 240, 247):
VLSI at 32 nodes (5 reps) and at 16 nodes on each half of the 32-node
allocation (A and B, 3 reps each), without diagnostics. Charades timing arms:
E W 5,000, E W 2,500, L W 2,500, the controller (E mb0); check arm O (the old
diagnostics at E W 5,000, kept out of timing comparisons). Devastator 2 x 23
at W 2,500 / 5,000 / 10,000. Against VA's 16-node cell (section 249) for C9 and
job big2 at 32 nodes (section 226) for C8.
Usage: vscale32_summary.py <V32b dir> <VA dir> <big2 dir>"""
import csv, glob, os, re, statistics as st, sys
NEW, VA, BIG2 = sys.argv[1:4]
TIME = [('E', 'w5000'), ('E', 'w2500'), ('L', 'w2500'), ('E', 'mb0')]; FIXED = TIME[:3]
nm = lambda a: f"{a[0]} {'W ' + a[1][1:] if a[1].startswith('w') else 'controller'}"
med = lambda x: st.median([v for v in x if v is not None]) if [v for v in x if v is not None] else None
def crow(D, N, rep, a):
    f = os.path.join(D, f'n{N}', rep, f'{a[0]}_{a[1]}.csv')
    if not os.path.exists(f): return None
    r = list(csv.DictReader(open(f)))
    return r[0] if len(r) == 1 and r[0]['status'] == 'ok' else None
crate = lambda D, N, rep, a: float(crow(D, N, rep, a)['event_rate']) / 1e6 if crow(D, N, rep, a) else None
def dv(D): return [dict(t.split('=', 1) for t in l.split() if '=' in t) for l in open(os.path.join(D, 'deva.txt'))]
def drate(rows, N, rep, w):
    x = [float(k['M_ev_s']) for k in rows if k['nodes'] == str(N) and k['rep'] == rep and k['window'] == w and k['status'] == 'ok' and k.get('M_ev_s')]
    return x[0] if x else None
DN, DVA = dv(NEW), dv(VA)
R32 = [f'r{i}' for i in range(1, 6)]; RA = ['r1A', 'r2A', 'r3A']; RB = ['r1B', 'r2B', 'r3B']; RVA = ['r1', 'r2', 'r3']
DW = ['2500', '5000', '10000']

print('# Counts and digests')
for N, reps in ((16, RA + RB), (32, R32)):
    c = {crow(NEW, N, r, a)['committed'] for r in reps for a in TIME + [('O', 'w5000')] if crow(NEW, N, r, a)}
    g = {crow(NEW, N, r, ('O', 'w5000'))['digest'] for r in reps if crow(NEW, N, r, ('O', 'w5000'))}
    miss = [f'{r} {nm(a)}' for r in reps for a in TIME + [('O', 'w5000')] if not crow(NEW, N, r, a)]
    dc = {k['committed'] for k in DN if k['nodes'] == str(N) and k['status'] == 'ok'}
    dbad = [f"dv W{k['window']} {k['rep']} {k['status']}" for k in DN if k['nodes'] == str(N) and k['status'] != 'ok']
    print(f'n{N}: Charades {sorted(c)} digests {sorted(g)}; Devastator {sorted(dc)} -> {"same" if c == dc and len(c) == 1 else "DIFFER"}' + (f'  NOT OK: {miss + dbad}' if miss or dbad else ''))
va16 = {crow(VA, 16, r, ('G', 'w5000'))['digest'] for r in RVA if crow(VA, 16, r, ('G', 'w5000'))}
print(f"VA's 16-node digests: {sorted(va16)}")

def best(D, rows, N, reps):
    cm = {a: med([crate(D, N, r, a) for r in reps]) for a in FIXED}
    dm = {w: med([drate(rows, N, r[1:], w) for r in reps]) for w in DW}
    bw = max(dm, key=dm.get)
    return dict(cm=cm, cfix=max(cm.values()), cfa=max(cm, key=cm.get), ctl=med([crate(D, N, r, TIME[3]) for r in reps]), dm=dm, dev=dm[bw], dw=bw,
                dfast=max(x for x in [drate(rows, N, r[1:], bw) for r in reps] if x))
print('\n# Each engine at its best (medians; M committed ev/s); Charades ÷ Devastator, higher is better')
print('| cell | Charades E W5000 / E W2500 / L W2500 / controller | Devastator W2500 / W5000 / W10000 | C best fixed ÷ D best | C controller ÷ D best | ÷ D fastest rep (C best fixed) | controller ÷ best fixed, per rep |')
print('|---|---|---|---|---|---|---|')
cells = {}
for lab, D, rows, N, reps in (('32 nodes', NEW, DN, 32, R32), ('16, half A', NEW, DN, 16, RA), ('16, half B', NEW, DN, 16, RB), ("16, VA's allocation", VA, DVA, 16, RVA)):
    b = best(D, rows, N, reps); cells[lab] = b
    per = []
    for r in reps:
        fx = [x for x in [crate(D, N, r, a) for a in FIXED] if x]; c = crate(D, N, r, TIME[3])
        if fx and c: per.append(c / max(fx))
    print(f"| {lab} | {' / '.join(f'{b['cm'][a]:.1f}' for a in FIXED)} / {b['ctl']:.1f} | {' / '.join(f'{b['dm'][w]:.1f}' for w in DW)} | "
          f"{b['cfix'] / b['dev']:.2f} ({nm(b['cfa'])}; D W {b['dw']}) | {b['ctl'] / b['dev']:.2f} | {b['cfix'] / b['dfast']:.2f} | {min(per):.3f}–{max(per):.3f} |")

print('\n# C9: each half ÷ VA\'s 16-node cell (medians), per arm; Devastator best')
for h in ('16, half A', '16, half B'):
    va = cells["16, VA's allocation"]
    print(f"  {h}: " + ', '.join(f"{nm(a)} {cells[h]['cm'][a] / va['cm'][a]:.3f}" for a in FIXED)
          + f", controller {cells[h]['ctl'] / va['ctl']:.3f}, Devastator best {cells[h]['dev'] / va['dev']:.3f}")

print('\n# Spread between reps (max ÷ min)')
for lab, D, rows, N, reps in (('32', NEW, DN, 32, R32), ('16A', NEW, DN, 16, RA), ('16B', NEW, DN, 16, RB)):
    out = []
    for a in TIME:
        v = [x for x in [crate(D, N, r, a) for r in reps] if x]; out.append(f"{nm(a)} {' '.join(f'{x:.0f}' for x in v)} ({max(v) / min(v):.3f})")
    for w in DW:
        v = [x for x in [drate(rows, N, r[1:], w) for r in reps] if x]; out.append(f"D W{w} {' '.join(f'{x:.0f}' for x in v)} ({max(v) / min(v):.3f})")
    print(f'  n{lab}: ' + ' | '.join(out))
print('\n# O (old diagnostics) ÷ E W 5,000, paired per rep')
for N, reps in ((16, RA + RB), (32, R32)):
    x = [crate(NEW, N, r, ('O', 'w5000')) / crate(NEW, N, r, TIME[0]) for r in reps if crate(NEW, N, r, ('O', 'w5000')) and crate(NEW, N, r, TIME[0])]
    print(f'  n{N}: median {med(x):.3f}, range {min(x):.3f}–{max(x):.3f}')
print('\n# per-node rate 32 ÷ 16 (VA\'s allocation; half A; half B): ' + '; '.join(
    f"{k}: C best fixed {cells['32 nodes']['cfix'] / 2 / cells[k]['cfix']:.3f}, controller {cells['32 nodes']['ctl'] / 2 / cells[k]['ctl']:.3f}, D {cells['32 nodes']['dev'] / 2 / cells[k]['dev']:.3f}"
    for k in ("16, VA's allocation", '16, half A', '16, half B')))
# big2 (section 226): its best Charades arm and Devastator best at 32 nodes, medians
b2c = {}
for f in glob.glob(os.path.join(BIG2, 'n32', '*_r[0-9].csv')):
    for r in csv.DictReader(open(f)):
        if r['status'] == 'ok': b2c.setdefault((os.path.basename(f).rsplit('_r', 1)[0], r['arm']), []).append(float(r['event_rate']) / 1e6)
b2d = {}
for k in dv(BIG2):
    if k['nodes'] == '32' and k.get('layout') == 'p64w23' and k['status'] == 'ok' and k.get('M_ev_s'): b2d.setdefault(k['window'], []).append(float(k['M_ev_s']))   # 2 x 23, as here
bc = ('C3', 'w:2500')   # section 226's paper arm: round 3, 1 x 46, lazy commits at W 2,500 (its best)
bd = max(b2d, key=lambda w: st.median(b2d[w]))
print(f"\n# big2 (section 226), 32 nodes: Charades best {bc} {st.median(b2c[bc]):.1f}, Devastator W {bd} {st.median(b2d[bd]):.1f} -> {st.median(b2c[bc]) / st.median(b2d[bd]):.2f}; "
      f"V32b ÷ big2: Charades best fixed {cells['32 nodes']['cfix'] / st.median(b2c[bc]):.3f}, Devastator {cells['32 nodes']['dev'] / st.median(b2d[bd]):.3f}")
