#!/usr/bin/env python3
"""Job VS (charades RESULTS.md section 212): VLSI b19 x N at 1-32 nodes in
Charades (1 x 46, lazy fossils, batch 32, buckets of 2,500 ps: the frozen
controller mb, W 2,500, W 5,000), Devastator (d2 = 2 x 23, d1 = 1 x 46; W 2,500
/ 5,000 / 10,000) and ROSS (b8 m2500, b8 m5000, b2 m5000). Rates are M
committed ev/s, median of the reps (higher is better). Prints S1-S7's
quantities.
Usage: vscale212_summary.py <job dir> [<job dir> ...]   (a_j..., big_j...)"""
import csv, glob, os, statistics as st, sys

def med(xs):
    xs = [x for x in xs if x is not None]
    return st.median(xs) if xs else None

rows, bad = [], []
for d in sys.argv[1:]:
    for f in glob.glob(f'{d}/n*/C_r*.csv'):
        n = int(f.split('/n')[-1].split('/')[0]); rep = int(f.rsplit('_r', 1)[1][:-4])
        for r in csv.DictReader(open(f)):
            arm = r['arm'].replace(':0', '').replace('w:', 'W')
            if r['status'] != 'ok':
                bad.append(f'charades n{n} {arm} r{rep} {r["status"]}'); continue
            ex = float(r['exec_s']); c = int(r['committed'])
            rows.append(dict(eng='C', n=n, arm=arm, rep=rep, rate=c / ex / 1e6, committed=c,
                             digest=r.get('digest'), blk=float(r.get('blocked_pct') or 0),
                             eff=float(r['efficiency'])))
    for line in open(f'{d}/deva.txt') if os.path.exists(f'{d}/deva.txt') else []:
        r = dict(x.split('=', 1) for x in line.split() if '=' in x)
        if r.get('status') != 'ok' or not r.get('M_ev_s'):
            bad.append(f"devastator n{r.get('nodes')} {r.get('arm')} W{r.get('window')} r{r.get('rep')} {r.get('status')}"); continue
        rows.append(dict(eng='D', n=int(r['nodes']), arm=f"{r['arm']} W{r['window']}", rep=int(r['rep']),
                         rate=float(r['M_ev_s']), committed=int(r['committed']), digest=None, blk=None,
                         eff=100.0 * int(r['committed']) / max(1, int(r['executed'] or 0)), det=r.get('deterministic')))
    for line in open(f'{d}/ross.txt') if os.path.exists(f'{d}/ross.txt') else []:
        r = dict(x.split('=', 1) for x in line.split() if '=' in x)
        if r.get('status') != 'ok' or not r.get('M_ev_s'):
            bad.append(f"ross n{r.get('nodes')} {r.get('arm')} r{r.get('rep')} {r.get('status')}"); continue
        rows.append(dict(eng='R', n=int(r['nodes']), arm=r['arm'], rep=int(r['rep']), rate=float(r['M_ev_s']),
                         committed=int(r['committed']), digest=None, blk=None, eff=float(r.get('efficiency') or 0)))

def sel(**k): return [r for r in rows if all(r[a] == b for a, b in k.items())]
def m(**k): return med([r['rate'] for r in sel(**k)])
def best(eng, n, pref=''):
    arms = sorted({r['arm'] for r in sel(eng=eng, n=n) if r['arm'].startswith(pref)})
    return max(((a, m(eng=eng, n=n, arm=a)) for a in arms), key=lambda x: x[1], default=(None, None))
def ratio(a, b): return f'{a / b:.3f}' if a and b else '  -  '

for b in bad: print('FAILED', b)
NS = sorted({r['n'] for r in rows})
print('==== S1: counts and digests')
for n in NS:
    cnt = sorted({r['committed'] for r in sel(n=n)}); dg = sorted({r['digest'] for r in sel(eng='C', n=n) if r['digest']})
    det = sorted({r.get('det') for r in sel(eng='D', n=n)})
    print(f"  {n:2} nodes: counts {cnt}{' <-- DIFFER' if len(cnt) > 1 else ''}; Charades digests {len(dg)}; Devastator deterministic {det}")

print('\n==== per arm (M ev/s: median, reps; max/min of the reps)')
for n in NS:
    print(f'--- {n} node(s)')
    for eng in 'CDR':
        for a in sorted({r['arm'] for r in sel(eng=eng, n=n)}, key=lambda a: -m(eng=eng, n=n, arm=a)):
            rs = sorted(sel(eng=eng, n=n, arm=a), key=lambda r: r['rep'])
            x = [r['rate'] for r in rs]
            blk = med([r['blk'] for r in rs]) if eng == 'C' else None
            print(f"   {dict(C='Charades', D='Devastator', R='ROSS')[eng]:10} {a:14} {med(x):8.2f}  "
                  f"{'/'.join('%.2f' % v for v in x):40} spread {max(x) / min(x):5.2f}"
                  + (f"  blocked {blk:4.1f}%" if blk is not None else ''))

print('\n==== S2, S3, S4, S7 (higher is better)')
print(f"  {'nodes':>5} {'C best':>16} {'D best':>18} {'R best':>16} {'C÷D':>6} {'C÷R':>6} {'D d1÷d2':>8} {'mb÷W2500':>9} {'mb÷best W':>10}")
pern = {}
for n in NS:
    cb, db, rb = best('C', n), best('D', n), best('R', n)
    d1, d2 = best('D', n, 'd1'), best('D', n, 'd2')
    mb = m(eng='C', n=n, arm='mb'); w25 = m(eng='C', n=n, arm='W2500')
    cw = max(((a, m(eng='C', n=n, arm=a)) for a in ('W2500', 'W5000') if m(eng='C', n=n, arm=a)), key=lambda x: x[1], default=(None, None))
    pern[n] = (cb[1], db[1], rb[1])
    print(f"  {n:5} {str(cb[0]) + ' %.2f' % (cb[1] or 0):>16} {str(db[0]) + ' %.2f' % (db[1] or 0):>18} "
          f"{str(rb[0]) + ' %.2f' % (rb[1] or 0):>16} {ratio(cb[1], db[1]):>6} {ratio(cb[1], rb[1]):>6} "
          f"{ratio(d1[1], d2[1]):>8} {ratio(mb, w25):>9} {ratio(mb, cw[1]):>10}  (Charades best fixed W {cw[0]})")

print('\n==== S6: per-node rate ÷ at 1 node (each engine at its best; 1.0 is perfect)')
if 1 in pern:
    for n in NS:
        print(f"  {n:2} nodes: " + '  '.join(f"{e} {pern[n][i] / n / pern[1][i]:.3f}" if pern[n][i] and pern[1][i] else f"{e}  -  "
                                           for i, e in enumerate(('Charades', 'Devastator', 'ROSS'))))
if 4 in pern and 32 in pern:
    print('  4 -> 32 per node: ' + '  '.join(f"{e} {pern[32][i] / 8 / pern[4][i]:.3f}" for i, e in enumerate(('Charades', 'Devastator', 'ROSS')) if pern[32][i] and pern[4][i]))
