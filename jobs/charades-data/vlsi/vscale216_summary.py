#!/usr/bin/env python3
"""Job VS2 (charades RESULTS.md section 216): VLSI b19 x N at 1-32 nodes with
round 3. Charades C3 (charades-r3) and, in big2, C (the old tree); Devastator
d2 (and d1 in big2); ROSS in big2. Also the old tree's cells from job a, the
cycle split from the --gvt-trace=1 run (C3gt), and the layout check (L_*).
Rates are M committed ev/s, median of the reps (higher is better).
Usage: vscale216_summary.py --old <job a dir> <a2 dir> [<big2 dir>]"""
import csv, glob, os, statistics as st, sys

args = sys.argv[1:]
old = None
if args and args[0] == '--old':
    old, args = args[1], args[2:]

def med(xs):
    xs = [x for x in xs if x is not None]
    return st.median(xs) if xs else None

rows, bad = [], []
def charades(d, pat, eng, src):
    for f in glob.glob(f'{d}/n*/{pat}_r*.csv'):
        n = int(f.split('/n')[-1].split('/')[0]); rep = int(f.rsplit('_r', 1)[1][:-4])
        for r in csv.DictReader(open(f)):
            arm = r['arm'].replace(':0', '').replace('w:', 'W')
            if r['status'] != 'ok':
                bad.append(f'{eng} n{n} {arm} r{rep} {r["status"]} ({src})'); continue
            c = int(r['committed'])
            rows.append(dict(eng=eng, n=n, arm=arm, rep=rep, rate=c / float(r['exec_s']) / 1e6, committed=c,
                             digest=r.get('digest'), blk=float(r.get('blocked_pct') or 0), src=src))
def others(d, src):
    for name, eng in (('deva.txt', 'D'), ('ross.txt', 'R')):
        for line in open(f'{d}/{name}') if os.path.exists(f'{d}/{name}') else []:
            r = dict(x.split('=', 1) for x in line.split() if '=' in x)
            arm = f"{r.get('arm')} W{r.get('window')}" if eng == 'D' else r.get('arm')
            if r.get('status') != 'ok' or not r.get('M_ev_s'):
                bad.append(f"{eng} n{r.get('nodes')} {arm} r{r.get('rep')} {r.get('status')} ({src})"); continue
            rows.append(dict(eng=eng, n=int(r['nodes']), arm=arm, rep=int(r['rep']), rate=float(r['M_ev_s']),
                             committed=int(r['committed']), digest=None, blk=None, src=src, det=r.get('deterministic')))
for d in args:
    charades(d, 'C3', 'C3', 'new'); charades(d, 'C', 'C', 'new'); others(d, 'new')
if old:
    charades(old, 'C', 'Ca', 'a'); others(old, 'a')

def sel(**k): return [r for r in rows if all(r[a] == b for a, b in k.items())]
def m(**k): return med([r['rate'] for r in sel(**k)])
def best(**k):
    arms = sorted({r['arm'] for r in sel(**k)})
    return max(((a, m(arm=a, **k)) for a in arms), key=lambda x: x[1], default=(None, None))
def ratio(a, b): return f'{a / b:.3f}' if a and b else '  -  '

for b in bad: print('FAILED', b)
NS = sorted({r['n'] for r in rows if r['src'] == 'new'})
print('==== Q1: counts and digests (this job, and job a)')
for n in NS:
    cnt = sorted({r['committed'] for r in sel(n=n)})
    dg = {e: sorted({r['digest'] for r in sel(eng=e, n=n) if r['digest']}) for e in ('C3', 'C', 'Ca')}
    print(f"  {n:2} nodes: counts {cnt}{' <-- DIFFER' if len(cnt) > 1 else ''}; digests "
          + '; '.join(f'{e} {v}' for e, v in dg.items() if v))

print('\n==== per arm (M ev/s: median, reps; max/min)')
for n in NS:
    print(f'--- {n} node(s)')
    for eng in ('C3', 'C', 'D', 'R'):
        for a in sorted({r['arm'] for r in sel(eng=eng, n=n, src='new')}, key=lambda a: -m(eng=eng, n=n, arm=a, src='new')):
            rs = sorted(sel(eng=eng, n=n, arm=a, src='new'), key=lambda r: r['rep']); x = [r['rate'] for r in rs]
            blk = med([r['blk'] for r in rs]) if eng.startswith('C') else None
            print(f"   {eng:3} {a:12} {med(x):8.2f}  {'/'.join('%.2f' % v for v in x):44} spread {max(x) / min(x):5.2f}"
                  + (f"  blocked {blk:4.1f}%" if blk is not None else ''))

print('\n==== Q2, Q3 (higher is better; ms per clock cycle of each best, lower is better)')
print(f"  {'nodes':>5} {'C3 best':>16} {'old best':>16} {'D best (this job)':>20} {'C3÷old':>7} {'C3÷D':>6} {'mb÷W2500':>9} {'ms/cycle C3 / old / D':>24}")
pern = {}
for n in NS:
    c3 = best(eng='C3', n=n, src='new')
    co = best(eng='C', n=n, src='new') if sel(eng='C', n=n) else best(eng='Ca', n=n)
    dd = best(eng='D', n=n, src='new')
    cnt = med([r['committed'] for r in sel(n=n)])
    ms = lambda r: f'{cnt / (r * 1e6) / 5000 * 1e3:.3f}' if r else '-'
    pern[n] = (c3[1], co[1], dd[1])
    print(f"  {n:5} {str(c3[0]) + ' %.2f' % (c3[1] or 0):>16} {str(co[0]) + ' %.2f' % (co[1] or 0):>16} "
          f"{str(dd[0]) + ' %.2f' % (dd[1] or 0):>20} {ratio(c3[1], co[1]):>7} {ratio(c3[1], dd[1]):>6} "
          f"{ratio(m(eng='C3', n=n, arm='mb'), m(eng='C3', n=n, arm='W2500')):>9} {ms(c3[1]) + ' / ' + ms(co[1]) + ' / ' + ms(dd[1]):>24}")

print('\n==== per rep, same allocation (engines interleaved in each rep): C3 best ÷ D best; C3 controller ÷ C3 W 2,500; C3 W 5,000 ÷ D W 10,000')
for n in NS:
    reps = sorted({r['rep'] for r in sel(eng='C3', n=n, src='new')})
    out = []
    for rep in reps:
        c = {r['arm']: r['rate'] for r in sel(eng='C3', n=n, rep=rep, src='new')}
        d = {r['arm']: r['rate'] for r in sel(eng='D', n=n, rep=rep, src='new') if r['arm'].startswith('d2')}
        if c and d:
            out.append((max(c.values()) / max(d.values()), c.get('mb', 0) / c['W2500'] if 'W2500' in c else 0,
                        c['W5000'] / d['d2 W10000'] if 'W5000' in c and 'd2 W10000' in d else 0))
    if out:
        print(f"  {n:2} nodes: " + '  '.join(f'r{i + 1} {a:.3f} {b:.3f} {c:.3f}' for i, (a, b, c) in enumerate(out))
              + f"  | medians {med([o[0] for o in out]):.3f} {med([o[1] for o in out]):.3f} {med([o[2] for o in out]):.3f}")

print('\n==== Q4: per-node rate ÷ at the first node count (C3 / old / Devastator)')
if NS:
    b = NS[0]
    for n in NS:
        print(f"  {n:2} nodes: " + '  '.join(f"{pern[n][i] / n * b / pern[b][i]:.3f}" if pern[n][i] and pern[b][i] else '-' for i in range(3)))
    if 4 in pern:
        for n in [x for x in NS if x > 4]:
            print(f"  4 -> {n}: " + '  '.join(f"{pern[n][i] / n * 4 / pern[4][i]:.3f}" if pern[n][i] and pern[4][i] else '-' for i in range(3)))

print('\n==== Q5: each cycle split by the count waves (C3, W 2,500, --gvt-trace=1; buckets 1000-4000)')
for d in args:
    for f in sorted(glob.glob(f'{d}/n*/C3gt/ctl_sweep/logs/*.gvt_trace.csv')):
        n = int(f.split(f'{d}/n')[1].split('/')[0])
        w = [r for r in csv.DictReader(open(f))]
        w = [r for r in w if 1000 <= int(r['bucket']) <= 4000]
        if len(w) < 2: print(f'  {n:2} nodes: too few waves'); continue
        w.sort(key=lambda r: float(r['result_s']))
        T = float(w[-1]['result_s']) - float(w[0]['result_s']); B = int(w[-1]['bucket']) - int(w[0]['bucket'])
        fly = sum(float(r['result_s']) - float(r['start_s']) for r in w[1:])
        nv = sum(r['valid'] == '1' for r in w)
        print(f"  {n:2} nodes: {T / B * 1e3:.3f} ms per cycle; waves {len(w)} ({nv} valid) = {len(w) / B:.2f} per cycle; "
              f"wave in flight {fly / B * 1e3:.3f} ms per cycle ({100 * fly / T:.1f}%), between waves {(T - fly) / B * 1e3:.3f} ms")

print('\n==== Q6: layout, round 3 at 1 x 46 ÷ 2 x 23 (M ev/s, median of 2; higher favours one process)')
for d in args:
    for n in (1, 4):
        for wl in ('g100', 'uni', 'traffic', 'df'):
            v = {}
            for p in (1, 2):
                xs, cnts = [], set()
                for f in glob.glob(f'{d}/n{n}/L_{wl}_p{p}_r*.csv'):
                    for r in csv.DictReader(open(f)):
                        if r['status'] == 'ok':
                            xs.append(int(r['committed']) / float(r['exec_s']) / 1e6); cnts.add(int(r['committed']))
                        else:
                            print(f'  FAILED layout n{n} {wl} p{p} {r["status"]}')
                v[p] = (med(xs), xs, cnts)
            if v[1][0] or v[2][0]:
                c = sorted(v[1][2] | v[2][2])
                print(f"  {n} node(s) {wl:8} 1x46 {v[1][0] or 0:7.2f} ({'/'.join('%.2f' % x for x in v[1][1])})  "
                      f"2x23 {v[2][0] or 0:7.2f} ({'/'.join('%.2f' % x for x in v[2][1])})  ratio {ratio(v[1][0], v[2][0])}"
                      f"  counts {c}{' <-- DIFFER' if len(c) > 1 else ''}")
