#!/usr/bin/env python3
"""Job V5 (charades RESULTS.md section 206). Part A, VLSI b19 x N at 1 and 4
nodes: Charades R (1 x 46, eager fossils, batch 16, W 5,000), L (1 x 46, lazy
fossils, batch 32, W 2,500 / 5,000 / 10,000), Lc (L's settings, the frozen
controller, buckets of 5,000 ps), I / S / N (2 x 23 over +ipc / Charm++
--enable-shmem / LCI, L's settings, W 5,000); Devastator d2 (2 x 23) and d1
(1 x 46). Part B, six workloads at 2 x 23 over LCI: eager (e) and lazy (l)
fossils at two W and the controller (mb), +ipc with lazy fossils (i) and the
paper's tree (p) at the first W. Rates are M committed ev/s, median of the
reps (higher is better). Prints F1-F9's quantities and the default rule.
Usage: v5gap206_summary.py <job dir>"""
import csv, glob, os, re, statistics as st, sys
d = sys.argv[1]
CYC = 5000

def med(xs):
    xs = [x for x in xs if x is not None]
    return st.median(xs) if xs else None
def stat(f, key):
    if not f or not os.path.exists(f): return None
    for line in open(f):
        if key in line: return float(line.split()[-1])
    return None

rows = []
for f in glob.glob(f'{d}/n*/[AB]_*_r[12].csv'):
    n = int(f.split('/n')[-1].split('/')[0]); tag = os.path.basename(f)[:-4]
    head, rep = tag.rsplit('_r', 1)
    part, rest = head.split('_', 1)
    for r in csv.DictReader(open(f)):
        arm = r['arm']
        if r['status'] != 'ok':
            print('FAILED charades', n, tag, arm, r['status']); continue
        ex = float(r['exec_s']); c = int(r['committed'])
        a = arm.replace(':0', '').replace('w:', 'W')
        logs = glob.glob(f"{d}/n{n}/{tag}/ctl_sweep/logs/*_{arm.replace(':', '')}.out") or \
               glob.glob(f"{d}/n{n}/{tag}/ctl_sweep/logs/*.out")
        rows.append(dict(eng='C', part=part, n=n, x=rest, arm=a, rep=int(rep), rate=c / ex / 1e6, committed=c,
                         digest=r.get('digest'), ms=1e3 * ex / CYC, eff=float(r['efficiency']),
                         blk=float(r.get('blocked_pct') or 0), mw=r.get('mean_window') or r.get('window_mean'),
                         log=logs[0] if len(logs) == 1 else None))
p = f'{d}/deva.txt'
for line in (open(p) if os.path.exists(p) else []):
    r = dict(x.split('=', 1) for x in line.split() if '=' in x)
    if r.get('status') != 'ok' or not r.get('M_ev_s'):
        print('FAILED devastator', r.get('nodes'), r.get('arm'), r.get('window'), 'rep', r.get('rep'), r.get('status')); continue
    c = int(r['committed']); rate = float(r['M_ev_s'])
    rows.append(dict(eng='D', part='A', n=int(r['nodes']), x=r['arm'], arm=f"W{r['window']}", rep=int(r['rep']), rate=rate,
                     committed=c, digest=None, ms=1e3 * c / (rate * 1e6) / CYC,
                     eff=100.0 * c / max(1, int(r['executed'] or 0)), blk=None, mw=None, log=None, det=r.get('deterministic')))

def sel(**k): return [r for r in rows if all(r[a] == b for a, b in k.items())]
def m(key='rate', **k): return med([r[key] for r in sel(**k)])
def ratio(a, b): return f'{a / b:.3f}' if a and b else '  -  '

print('==== Part A: VLSI b19 x N')
for n in (1, 4):
    rs = sel(part='A', n=n)
    if not rs: continue
    cnt = sorted({r['committed'] for r in rs}); dg = sorted({r['digest'] for r in rs if r['eng'] == 'C'})
    det = sorted({r.get('det') for r in rs if r['eng'] == 'D'})
    print(f"\n--- {n} node(s): counts {cnt}{' <-- DIFFER' if len(cnt) > 1 else ''}; Charades digests {dg}; Devastator deterministic {det}")
    ref = m(part='A', n=n, x='L', arm='W5000')
    print(f"   {'arm':22} {'M ev/s':>7} {'÷ L W5000':>9} {'ms/cycle':>8} {'eff%':>6} {'blk%':>5} {'shm msgs':>11}  reps")
    keys = sorted({(r['eng'], r['x'], r['arm']) for r in rs}, key=lambda k: -m(part='A', n=n, eng=k[0], x=k[1], arm=k[2]))
    for eng, x, a in keys:
        ar = sorted(sel(part='A', n=n, eng=eng, x=x, arm=a), key=lambda r: r['rep'])
        rt = med([r['rate'] for r in ar])
        shm = med([stat(r['log'], 'Shared-Memory Messages Received') for r in ar]) if eng == 'C' else None
        blk = med([r['blk'] for r in ar]) if eng == 'C' else None
        print(f"   {('Charades ' if eng == 'C' else 'Devastator ') + x + ' ' + a:22} {rt:7.2f} {ratio(rt, ref):>9} "
              f"{med([r['ms'] for r in ar]):8.3f} {med([r['eff'] for r in ar]):6.2f} "
              f"{'%5.1f' % blk if blk is not None else '     '} {'%11.0f' % shm if shm else '':>11}  {'/'.join('%.2f' % r['rate'] for r in ar)}")
    g = lambda x, a, eng='C': m(part='A', n=n, eng=eng, x=x, arm=a)
    cb = max(((x, a) for e, x, a in keys if e == 'C'), key=lambda k: g(*k))
    db = max(((x, a) for e, x, a in keys if e == 'D'), key=lambda k: g(*k, eng='D'), default=None)
    print(f"-- F2/F3: Charades' best {cb} {g(*cb):.2f}; Devastator's best {db} {g(*db, eng='D') if db else 0:.2f}; "
          f"Charades ÷ Devastator {ratio(g(*cb), g(*db, eng='D') if db else None)}")
    print(f"-- F3: L W5000 ÷ R W5000 {ratio(g('L', 'W5000'), g('R', 'W5000'))}; Charades' best W at 1 x 46 lazy: "
          f"{max(('W2500', 'W5000', 'W10000'), key=lambda a: g('L', a) or 0)}")
    print(f"-- F4: I ÷ L {ratio(g('I', 'W5000'), ref)}, S ÷ I {ratio(g('S', 'W5000'), g('I', 'W5000'))}, N ÷ L {ratio(g('N', 'W5000'), ref)}")
    bestL = max(g('L', a) or 0 for a in ('W2500', 'W5000', 'W10000'))
    lc = sel(part='A', n=n, x='Lc')
    print(f"-- F5: controller ÷ best fixed W (L) {ratio(g('Lc', 'mb'), bestL)}; per rep "
          + ', '.join(f"{r['rate'] / bestL:.3f}" for r in sorted(lc, key=lambda r: r['rep'])))
    d1 = max((g('d1', a, 'D') or 0 for a in ('W2500', 'W5000', 'W10000')), default=0)
    d2 = max((g('d2', a, 'D') or 0 for a in ('W2500', 'W5000', 'W10000')), default=0)
    if d1: print(f"-- F9: Devastator 1 x 46 best ÷ 2 x 23 best {d1 / d2:.3f}")

print('\n==== Part B: lazy fossils elsewhere (2 x 23 over LCI)')
W1 = dict(phases='W100', g100='W300', g2000='W300', uni='W300', traffic='W500', df='W10000')
W2 = dict(phases='W150', g100='W500', g2000='W500', uni='W500', traffic='W750', df='W20000')
worst = []
for n in (1, 4):
    if not sel(part='B', n=n): continue
    print(f"\n--- {n} node(s)  (l ÷ e per arm; best = better of the two W)")
    print(f"   {'workload':8} {'count':>14} {'e W1':>7} {'e W2':>7} {'e mb':>7} {'l W1':>7} {'l W2':>7} {'l mb':>7}"
          f" {'l÷e W1':>7} {'l÷e W2':>7} {'l÷e mb':>7} {'l÷e best':>8} {'i÷l W1':>7} {'e÷p W1':>7}")
    for w in ('phases', 'g100', 'g2000', 'uni', 'traffic', 'df'):
        def v(g, a): return m(part='B', n=n, x=f'{w}_{g}', arm=a)
        cnt = sorted({r['committed'] for r in rows if r['part'] == 'B' and r['n'] == n and r['x'].startswith(w + '_')})
        e1, e2, em = v('e', W1[w]), v('e', W2[w]), v('e', 'mb')
        l1, l2, lm = v('l', W1[w]), v('l', W2[w]), v('l', 'mb')
        i1, p1 = v('i', W1[w]), v('p', W1[w])
        be, bl = max(e1 or 0, e2 or 0), max(l1 or 0, l2 or 0)
        f = lambda x: f'{x:7.2f}' if x else '      -'
        print(f"   {w:8} {('/'.join(map(str, cnt)) if len(cnt) > 1 else str(cnt[0]) if cnt else '-'):>14}"
              f" {f(e1)} {f(e2)} {f(em)} {f(l1)} {f(l2)} {f(lm)} {ratio(l1, e1):>7} {ratio(l2, e2):>7} {ratio(lm, em):>7}"
              f" {ratio(bl, be):>8} {ratio(i1, l1):>7} {ratio(e1, p1):>7}")
        for x, y, what in ((bl, be, 'best W'), (lm, em, 'controller')):
            if x and y: worst.append((x / y, n, w, what))
        dg = sorted({r['digest'] for r in rows if r['part'] == 'B' and r['n'] == n and r['x'].startswith(w + '_') and r['digest']})
        if len(dg) > 1: print(f"      {w}: digests DIFFER {dg}")
if worst:
    lo = min(worst)
    print(f"\n-- F6 / default rule: lowest lazy ÷ eager {lo[0]:.3f} ({lo[2]}, {lo[1]} node(s), {lo[3]}); "
          f"{'lazy fossils become the default' if lo[0] >= 0.98 else 'lazy fossils stay a per-model setting'}")
