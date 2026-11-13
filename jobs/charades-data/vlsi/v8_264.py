#!/usr/bin/env python3
"""Job V8 (charades results/phold.md section 262, results in 264): VLSI's
8-node column rerun with node 0 (the batch host) idle, against job VA's
8-node cell (vlsi.md section 249), which ran on nodes 0-7 beside three other
streams. Definitions as VA (vscale249_summary.py): Charades best fixed = the
fixed arm with the highest median, the controller its own median; Devastator
= its best W by median. M committed ev/s; ratios Charades / Devastator, higher
is better; 'V8 / VA' compares one engine across the two jobs.
Usage: v8_264.py <V8 job dir> <VA job dir>"""
import csv, os, statistics as st, sys
NEW, OLD = sys.argv[1], sys.argv[2]
N = 8; RN = ['r1', 'r2', 'r3', 'r4', 'r5']; RO = ['r1', 'r2', 'r3']
TIME = [('E', 'w5000'), ('E', 'w2500'), ('L', 'w2500'), ('E', 'mb0')]
FIXED = TIME[:3]; DW = ['2500', '5000', '10000']
nm = lambda a: f"{a[0]} {'W ' + a[1][1:] if a[1].startswith('w') else 'controller'}"
med = lambda x: st.median([v for v in x if v is not None]) if [v for v in x if v is not None] else None
def crow(D, rep, a):
    f = os.path.join(D, f'n{N}', rep, f'{a[0]}_{a[1]}.csv')
    if not os.path.exists(f): return None
    r = list(csv.DictReader(open(f)))
    return r[0] if len(r) == 1 and r[0]['status'] == 'ok' else None
def crate(D, rep, a):
    r = crow(D, rep, a); return float(r['event_rate']) / 1e6 if r else None
def dv(D):
    return [dict(t.split('=', 1) for t in l.split() if '=' in t) for l in open(os.path.join(D, 'deva.txt'))]
DN, DO = dv(NEW), dv(OLD)
def drate(rows, rep, w):
    x = [float(k['M_ev_s']) for k in rows if k['nodes'] == str(N) and k['rep'] == rep[1:] and k['window'] == w and k['status'] == 'ok' and k.get('M_ev_s')]
    return x[0] if x else None

print('# Counts (V8-1)')
c, bad = set(), []
for rep in RN:
    for a in TIME:
        r = crow(NEW, rep, a)
        if not r: bad.append(f'{rep} {nm(a)}'); continue
        c.add(r['committed'])
dc = {k['committed'] for k in DN if k['nodes'] == str(N) and k['status'] == 'ok' and k['rep'] != 'warm'}
bad += [f"dv W{k['window']} r{k['rep']} {k['status']}" for k in DN if k['nodes'] == str(N) and k['status'] != 'ok']
vc = {crow(OLD, rep, a)['committed'] for rep in RO for a in TIME if crow(OLD, rep, a)}
print(f'Charades {sorted(c)}; Devastator {sorted(dc)}; VA {sorted(vc)} -> ' +
      ('one count, equal to VA' if c == dc == vc and len(c) == 1 else 'DIFFER') + (f'  NOT OK: {bad}' if bad else ''))
for rep in RN:   # a defaulted run (section 263) would have no count waves
    for a in TIME:
        r = crow(NEW, rep, a)
        if r and not (r.get('count_waves') or '0').strip('0.'):
            print(f'  NO COUNT WAVES: {rep} {nm(a)}')

print('\n# Rates per arm (M committed ev/s, median; V8 5 reps, VA 3 in brackets); V8 / VA')
for a in TIME:
    n, o = med([crate(NEW, r, a) for r in RN]), med([crate(OLD, r, a) for r in RO])
    print(f'  Charades {nm(a):14} {n:7.2f} ({o:7.2f})  {n / o:.3f}   reps ' + ' '.join(f'{crate(NEW, r, a):.1f}' for r in RN if crate(NEW, r, a)))
for w in DW:
    n, o = med([drate(DN, r, w) for r in RN]), med([drate(DO, r, w) for r in RO])
    print(f'  Devastator W {w:6}   {n:7.2f} ({o:7.2f})  {n / o:.3f}   reps ' + ' '.join(f'{drate(DN, r, w):.1f}' for r in RN if drate(DN, r, w)))

def best(D, rows, reps):
    cm = {a: med([crate(D, r, a) for r in reps]) for a in FIXED}
    dm = {w: med([drate(rows, r, w) for r in reps]) for w in DW}
    bw = max(dm, key=dm.get); ca = max(cm, key=cm.get)
    return dict(cfix=cm[ca], cfa=ca, ctl=med([crate(D, r, TIME[3]) for r in reps]), dev=dm[bw], dw=bw)
n, o = best(NEW, DN, RN), best(OLD, DO, RO)
print('\n# Each engine at its best (V8-2, V8-3); VA in brackets')
print(f"  Charades best fixed {nm(n['cfa'])} {n['cfix']:.1f} ({nm(o['cfa'])} {o['cfix']:.1f}); controller {n['ctl']:.1f} ({o['ctl']:.1f}); "
      f"Devastator W {n['dw']} {n['dev']:.1f} (W {o['dw']} {o['dev']:.1f})")
print(f"  V8 / VA: Charades controller {n['ctl'] / o['ctl']:.3f}, best fixed {n['cfix'] / o['cfix']:.3f}; Devastator best {n['dev'] / o['dev']:.3f}")
print(f"  Charades / Devastator: controller {n['ctl'] / n['dev']:.3f} ({o['ctl'] / o['dev']:.3f}); best fixed {n['cfix'] / n['dev']:.3f} ({o['cfix'] / o['dev']:.3f})")
fast = max(x for x in [drate(DN, r, w) for r in RN for w in DW] if x)
print(f"  against Devastator's fastest rep ({fast:.1f}): controller {n['ctl'] / fast:.3f}, best fixed {n['cfix'] / fast:.3f}")

print('\n# Controller / best fixed arm of the same rep (V8-4)')
per = []
for r in RN:
    fx = [x for x in [crate(NEW, r, a) for a in FIXED] if x]; c = crate(NEW, r, TIME[3])
    if fx and c: per.append(c / max(fx))
print('  per rep ' + ' '.join(f'{x:.3f}' for x in per) + f'; median {med(per):.3f}')
ws = [crow(NEW, r, TIME[3]) for r in RN]
print('  controller mean W per rep: ' + ' '.join(f"{float(w['mean_window']):.0f}" for w in ws if w and w.get('mean_window')))

print('\n# Spread between reps (max / min)')
for a in TIME:
    v = [x for x in [crate(NEW, r, a) for r in RN] if x]
    print(f'  Charades {nm(a)} {max(v) / min(v):.3f}')
for w in DW:
    v = [x for x in [drate(DN, r, w) for r in RN] if x]
    print(f'  Devastator W {w} {max(v) / min(v):.3f}')
