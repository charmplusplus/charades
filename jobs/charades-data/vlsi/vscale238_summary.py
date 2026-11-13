#!/usr/bin/env python3
"""Job VS3 (charades RESULTS.md section 238): the paper's VLSI row with eager
commits at W 5,000, the widened controller and Devastator in one allocation.

Usage: vscale238_summary.py <job dir>   (e.g. ~/charades-data/vlsi/vscale238/j3688291)
"""
import csv, glob, os, re, statistics as st, sys

D = sys.argv[1]
CYC = 5000
NODES = [1, 2, 4, 8, 16]
CH = [('E', 'w5000'), ('E', 'w2500'), ('L', 'w2500'), ('E', 'mb0')]
FIXED = CH[:3]
DW = ['2500', '5000', '10000']
REPS = ['r1', 'r2', 'r3']
CORE = 28  # rank 13 under +pemap 2-46:2,3-47:2


def nm(a):
    return f"{a[0]} {'W ' + a[1][1:] if a[1].startswith('w') else 'controller'}"


def crow(N, rep, a):
    f = os.path.join(D, f'n{N}', rep, f'{a[0]}_{a[1]}.csv')
    if not os.path.exists(f):
        return None
    r = list(csv.DictReader(open(f)))
    return r[0] if len(r) == 1 and r[0]['status'] == 'ok' else None


def crate(N, rep, a):
    r = crow(N, rep, a)
    return float(r['event_rate']) / 1e6 if r else None


dv = []
for line in open(os.path.join(D, 'deva.txt')):
    kv = dict(t.split('=', 1) for t in line.split() if '=' in t)
    dv.append(kv)


def drate(N, rep, w):
    xs = [float(k['M_ev_s']) for k in dv if k['nodes'] == str(N) and k['rep'] == rep[1:] and k['window'] == w and k['status'] == 'ok' and k.get('M_ev_s')]
    return xs[0] if xs else None


def rng(x, d=3):
    x = [v for v in x if v is not None]
    if not x:
        return '—'
    lo, hi = min(x), max(x)
    return f'{lo:.{d}f}' if f'{lo:.{d}f}' == f'{hi:.{d}f}' else f'{lo:.{d}f}–{hi:.{d}f}'


def med(x):
    x = [v for v in x if v is not None]
    return st.median(x) if x else None


print('# Counts and digests')
for N in NODES:
    c, g = set(), set()
    for rep in REPS:
        for a in CH:
            r = crow(N, rep, a)
            if r: c.add(r['committed']); g.add(r['digest'])
    dc = {k['committed'] for k in dv if k['nodes'] == str(N) and k['status'] == 'ok'}
    dd = {k['deterministic'] for k in dv if k['nodes'] == str(N)}
    bad = [f'{rep} {nm(a)}' for rep in REPS for a in CH if not crow(N, rep, a)] + \
          [f"dv W{k['window']} r{k['rep']} {k['status']}" for k in dv if k['nodes'] == str(N) and k['status'] != 'ok']
    print(f'n{N:2}: Charades {sorted(c)} {sorted(g)}; Devastator {sorted(dc)} deterministic {sorted(dd)} -> {"same" if c == dc and len(c) == 1 else "DIFFER"}' + (f'  NOT OK: {bad}' if bad else ''))

print('\n# Rates (M committed ev/s, median of 3; higher is better)')
print('| nodes | ' + ' | '.join(f'Charades {nm(a)}' for a in CH) + ' | ' + ' | '.join(f'Devastator W {w}' for w in DW) + ' |')
print('|---|' + '---|' * (len(CH) + len(DW)))
for N in NODES:
    print(f'| {N} | ' + ' | '.join(f'{med([crate(N, r, a) for r in REPS]):.2f}' for a in CH) + ' | '
          + ' | '.join(f'{med([drate(N, r, w) for r in REPS]):.2f}' for w in DW) + ' |')

print('\n# Each engine at its best fixed arm, per rep; Charades ÷ Devastator (higher is better)')
print('| nodes | Charades best fixed (arm, M ev/s), r1 / r2 / r3 | Devastator best (W, M ev/s), r1 / r2 / r3 | Charades ÷ Devastator per rep | ratio of medians | controller ÷ Charades best fixed, per rep | E W 5,000 ÷ L W 2,500 | E W 2,500 ÷ L W 2,500 | per-node rate ÷ 4 nodes, Charades / Devastator |')
print('|---|---|---|---|---|---|---|---|---|')
bests = {}
for N in NODES:
    cb, db, ratio, ctl, e5, e2 = [], [], [], [], [], []
    for rep in REPS:
        cr = {a: crate(N, rep, a) for a in FIXED}
        cr = {a: x for a, x in cr.items() if x}
        dr = {w: drate(N, rep, w) for w in DW}
        dr = {w: x for w, x in dr.items() if x}
        if cr:
            ba = max(cr, key=cr.get); cb.append((ba, cr[ba]))
            c = crate(N, rep, CH[3])
            if c: ctl.append(c / cr[ba])
        if dr:
            bw = max(dr, key=dr.get); db.append((bw, dr[bw]))
        if cr and dr: ratio.append(cb[-1][1] / db[-1][1])
        l = crate(N, rep, ('L', 'w2500'))
        if l and crate(N, rep, ('E', 'w5000')): e5.append(crate(N, rep, ('E', 'w5000')) / l)
        if l and crate(N, rep, ('E', 'w2500')): e2.append(crate(N, rep, ('E', 'w2500')) / l)
    bests[N] = (med([x for _, x in cb]), med([x for _, x in db]))
    print(f"| {N} | {' / '.join(f'{nm(a)} {x:.1f}' for a, x in cb)} | {' / '.join(f'{w} {x:.1f}' for w, x in db)} | {rng(ratio)} | "
          f"{bests[N][0] / bests[N][1]:.3f} | {rng(ctl)} | {rng(e5)} | {rng(e2)} | "
          f"{(bests[N][0] / N) / (bests[4][0] / 4) if 4 in bests and N >= 4 else float('nan'):.3f} / {(bests[N][1] / N) / (bests[4][1] / 4) if 4 in bests and N >= 4 else float('nan'):.3f} |")

print('\n# The controller (eager, buckets of 2,500, reach 2): time-weighted mean W, trials kept, trials past the delay range, least 0.99 quantile')
for N in NODES:
    out = []
    for rep in REPS:
        lg = glob.glob(os.path.join(D, f'n{N}', rep, 'E_mb0', 'ctl_sweep', 'logs', '*.out'))
        if not lg:
            continue
        t = open(lg[0]).read()
        g = lambda k: (re.search(re.escape(k) + r'\s+(\S+)', t) or [None, '?'])[1]
        kept = re.search(r'Trials kept\s+(\d+) of (\d+)', t)
        out.append(f"{rep}: mean W {g('Time-weighted mean window')}, final {g('Final window')}, kept {kept.group(1)}/{kept.group(2) if kept else '?'}, past {g('Trials past it (reach buckets)')}, p99 {g('Least 0.99 quantile of delay')}")
    print(f'  n{N}: ' + '; '.join(out))


def snapread(f):
    lines = open(f).read().splitlines()
    cpu = {}
    irq_hdr, irq = None, {}
    for l in lines:
        p = l.split()
        if not p:
            continue
        if re.match(r'cpu\d+$', p[0]):
            cpu[int(p[0][3:])] = [int(x) for x in p[1:8]]  # user nice system idle iowait irq softirq
        elif p[0] == 'CPU0':
            irq_hdr = p
        elif irq_hdr and p[0].endswith(':'):
            vals = []
            for x in p[1:1 + len(irq_hdr)]:
                if x.isdigit(): vals.append(int(x))
                else: break
            if len(vals) == len(irq_hdr):
                irq[p[0][:-1] + ' ' + ' '.join(p[1 + len(irq_hdr):])[:40]] = vals
    return cpu, irq_hdr, irq


print(f'\n# Slow reps and core {CORE} on copy 2\'s node (4-16 nodes; whole ctl_sweep call; jiffies of 10 ms)')
print('| nodes | arm | rep | run time (s) ÷ arm median | PE 105 working ms/cycle | core 28 user / system / irq / softirq / idle | core 28 interrupts | top interrupts on core 28 |')
print('|---|---|---|---|---|---|---|---|')
for N in [4, 8, 16]:
    for a in CH:
        ts = {rep: float(crow(N, rep, a)['exec_s']) for rep in REPS if crow(N, rep, a)}
        m = med(list(ts.values()))
        for rep in REPS:
            base = os.path.join(D, f'n{N}', rep, f'{a[0]}_{a[1]}')
            if not (os.path.exists(base + '.snap0') and os.path.exists(base + '.snap1')) or rep not in ts:
                continue
            c0, h0, i0 = snapread(base + '.snap0'); c1, h1, i1 = snapread(base + '.snap1')
            d = [y - x for x, y in zip(c0[CORE], c1[CORE])]
            col = h0.index(f'CPU{CORE}') if h0 and f'CPU{CORE}' in h0 else None
            tot, top = 0, []
            if col is not None:
                for k in i1:
                    if k in i0:
                        dd = i1[k][col] - i0[k][col]; tot += dd
                        if dd: top.append((dd, k))
            top.sort(reverse=True)
            pf = os.path.join(base, 'ctl_sweep', 'pe_stats.csv')
            wk = '—'
            if os.path.exists(pf):
                for r in csv.DictReader(open(pf)):
                    if int(float(r['pe'])) == 105 and N >= 3:
                        wk = f"{1e3 * (float(r['total_s']) - float(r['blocked_s'])) / CYC:.3f}"
            print(f"| {N} | {nm(a)} | {rep} | {ts[rep] / m:.3f} | {wk} | {d[0]} / {d[2]} / {d[5]} / {d[6]} / {d[3]} | {tot} | {'; '.join(f'{v} {k}' for v, k in top[:3])} |")
