#!/usr/bin/env python3
"""Job VC (charades RESULTS.md section 235): VLSI's commit setting and its
controller row. Settings L (lazy, VS2), E (eager), R1 (--fossil-rounds=1),
F (--fossil-finish=1); fixed W 2,500 (L) and 5,000 (all) with buckets of
2,500 ps; the controller (mb:0) with buckets of 2,500 (L) and 5,000 (E, R1, F).

Usage: vcommit235_summary.py <job dir>   (e.g. ~/charades-data/vlsi/vcommit235/j3686688)
"""
import csv, os, statistics as st, sys

D = sys.argv[1]
CYC = 5000
ARMS = [('L', 'w2500', 2500), ('L', 'w5000', 2500), ('E', 'w5000', 2500), ('R1', 'w5000', 2500),
        ('F', 'w5000', 2500), ('L', 'mb0', 2500), ('E', 'mb0', 5000), ('R1', 'mb0', 5000), ('F', 'mb0', 5000)]
FIXED = ARMS[:5]
REPS = ['r1', 'r2', 'r3']
NODES = [1, 2, 4, 8, 16]


def name(a):
    s, k, b = a
    return f"{s} {'W ' + k[1:] if k.startswith('w') else 'controller'}, b{b}"


def row(N, rep, a):
    f = os.path.join(D, f'n{N}', rep, f'{a[0]}_{a[1]}_b{a[2]}.csv')
    if not os.path.exists(f):
        return None
    r = list(csv.DictReader(open(f)))
    return r[0] if len(r) == 1 and r[0]['status'] == 'ok' else None


def pes(N, rep, a):
    f = os.path.join(D, f'n{N}', rep, f'{a[0]}_{a[1]}_b{a[2]}', 'ctl_sweep', 'pe_stats.csv')
    if not os.path.exists(f):
        return []
    return [{k: float(v) for k, v in r.items()} for r in csv.DictReader(open(f))]


def rng(x, d=3):
    x = [v for v in x if v is not None]
    if not x:
        return '—'
    lo, hi = min(x), max(x)
    return f'{lo:.{d}f}' if f'{lo:.{d}f}' == f'{hi:.{d}f}' else f'{lo:.{d}f}–{hi:.{d}f}'


print('# Counts and digests')
for N in NODES:
    c, g, bad = set(), set(), []
    for rep in REPS:
        for a in ARMS:
            r = row(N, rep, a)
            if r is None:
                bad.append(f'{rep} {name(a)}'); continue
            c.add(r['committed']); g.add(r['digest'])
    print(f'n{N:2}: counts {sorted(c)} digests {sorted(g)}' + (f'  NOT OK: {bad}' if bad else ''))

print('\n# Speed ÷ the best fixed arm of the same rep (higher is better; range over 3 reps), and run time (s, median)')
print('| arm | ' + ' | '.join(f'{N} node{"s" if N > 1 else ""}' for N in NODES) + ' |')
print('|---|' + '---|' * len(NODES))
best_names = {}
for a in ARMS:
    cells = []
    for N in NODES:
        rs, ts = [], []
        for rep in REPS:
            r = row(N, rep, a)
            fx = [(float(row(N, rep, f)['exec_s']), f) for f in FIXED if row(N, rep, f)]
            if not r or not fx:
                continue
            b, bf = min(fx)
            best_names.setdefault(N, []).append(name(bf))
            rs.append(b / float(r['exec_s'])); ts.append(float(r['exec_s']))
        cells.append(f'{rng(rs)} ({st.median(ts):.2f})' if ts else '—')
    print(f'| {name(a)} | ' + ' | '.join(cells) + ' |')
print('best fixed arm per rep: ' + '; '.join(f'n{N}: ' + ', '.join(sorted(set(v))) for N, v in best_names.items()))

print('\n# Speed ÷ L at W 2,500 (VS2\'s setting from 4 nodes up) and ÷ L at W 5,000 (VS2\'s best at 1-2 nodes), same rep')
for a in ARMS:
    out = []
    for N in NODES:
        r1, r2 = [], []
        for rep in REPS:
            r, l25, l50 = row(N, rep, a), row(N, rep, ARMS[0]), row(N, rep, ARMS[1])
            if r and l25: r1.append(float(l25['exec_s']) / float(r['exec_s']))
            if r and l50: r2.append(float(l50['exec_s']) / float(r['exec_s']))
        out.append(f'n{N} {rng(r1)} / {rng(r2)}')
    print(f'  {name(a):24} ' + '; '.join(out))

print('\n# Rolled back (M, median), least-blocked PE waiting share (%), its working time (ms per cycle), controller mean W')
for N in NODES:
    print(f'n{N}:')
    for a in ARMS:
        rb, wt, wk, mw, pe = [], [], [], [], []
        for rep in REPS:
            r = row(N, rep, a)
            if not r:
                continue
            rb.append(float(r['rolled_back']) / 1e6)
            mw.append(float(r['mean_window']))
            p = pes(N, rep, a)
            if p:
                lb = min(p, key=lambda q: q['blocked_s'] / q['total_s'])
                wt.append(100 * lb['blocked_s'] / lb['total_s'])
                wk.append(1e3 * (lb['total_s'] - lb['blocked_s']) / CYC)
                pe.append(int(lb['pe']))
        print(f'   {name(a):24} rb {st.median(rb):6.1f}  wait {rng(wt, 1):>10}  work {rng(wk, 3):>12}  meanW {rng(mw, 0):>10}  pe {sorted(set(pe))}')
