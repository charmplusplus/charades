#!/usr/bin/env python3
"""charades results/aggregation.md section 284: uniform's row in the front page's
PHOLD table and bundling table with local 1 pad 1 at 16 nodes (job UL small,
3711818, section 278) and 64 nodes (job L64b, 3708796, section 276; user decision
2026-11-13). Every other cell, and Devastator and ROSS everywhere, as before (F1,
R8, F1-32, P64). M committed ev/s, medians of reps; ratios Charades / other,
higher is better for Charades; per-node rate = rate per node / rate per node at
the smaller count (1.0 is perfect)."""
import csv, glob, os, re, statistics as st
here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, 'f1_240_summary.py')).read().split('argv = sys.argv[1:]')[0]
exec(src)   # load(), cells()
D = os.path.expanduser('~/charades-data')
SETS = [([D + '/f1/scale240/a_j3689004', D + '/f1/scale240/b_j3689513'], {1, 2, 4, 16}),
        ([D + '/f1/r8_260/j3695259'], {8}), ([D + '/f1/scale240/big_j3688916'], {32}), ([D + '/s64_262/p_j3696079'], {64})]
old = {}
for dirs, Ns in SETS:
    ch, dv, ro, _ = load(dirs)
    f = lambda d: {k: v for k, v in d.items() if k[0] == 'uni' and k[1] in Ns}
    c = cells(f(ch), f(dv), f(ro))
    for N in Ns: old[N] = c[('uni', N)]
    if 64 in Ns: dfast64 = max(x for x, _ in dv[('uni', 64, c[('uni', 64)]['dw'])])

def l1(d, N, arm):   # local 1 pad 1 controller or fixed-W median at N nodes from a job directory
    xs = [float(r['event_rate']) / 1e6 for f in glob.glob(d + '/n%d/uni_pp_512_l1_p1_r*.csv' % N) for r in csv.DictReader(open(f))
          if r['status'] == 'ok' and r['arm'] == arm and r['agg'] == 'pp:512:l1:p1']
    return st.median(xs), len(xs)
L16, n16 = l1(D + '/f1/ul277/small_j3711818', 16, 'mb:0')
L64, n64 = l1(D + '/f1/l64/b_j3708796', 64, 'mb:0')
L64w, _ = l1(D + '/f1/l64/b_j3708796', 64, 'w:400')
DIRECT64 = 540.6   # P64's best direct sends, W 300 (section 265)
new = {N: old[N]['ctl'] for N in old}; new[16], new[64] = L16, L64
print('local 1 pad 1 controller: 16 nodes %.1f (%d reps, UL), 64 nodes %.1f (%d reps, L64b); 64 nodes W 400 %.1f' % (L16, n16, L64, n64, L64w))
Ns = sorted(old)
print('\n%-26s %s' % ('', '  '.join('%7d' % N for N in Ns)))
print('%-26s %s' % ('Charades, old', '  '.join('%7.1f' % old[N]['ctl'] for N in Ns)))
print('%-26s %s' % ('Charades, new', '  '.join('%7.1f' % new[N] for N in Ns)))
print('%-26s %s' % ('Devastator', '  '.join('%7.1f' % old[N]['dev'] for N in Ns)))
print('%-26s %s' % ('ROSS', '  '.join('%7.1f' % old[N]['ross'] for N in Ns)))
print('%-26s %s' % ('C / D, old', '  '.join('%7.2f' % (old[N]['ctl'] / old[N]['dev']) for N in Ns)))
print('%-26s %s' % ('C / D, new', '  '.join('%7.2f' % (new[N] / old[N]['dev']) for N in Ns)))
print('%-26s %s' % ('C / R, new', '  '.join('%7.2f' % (new[N] / old[N]['ross']) for N in Ns)))
cr = [new[N] / old[N]['ross'] for N in Ns]
print('C / R range, new: %.2f-%.2f (old %.2f-%.2f)' % (min(cr), max(cr), min(old[N]['ctl'] / old[N]['ross'] for N in Ns), max(old[N]['ctl'] / old[N]['ross'] for N in Ns)))
print('C / D at 64 against Devastator\'s fastest rep (%.1f): new %.2f (old %.2f)' % (dfast64, new[64] / dfast64, old[64]['ctl'] / dfast64))
pn = lambda a, b, k: (new[b] if k == 'ctl' else old[b][k]) / (b // a) / (new[a] if k == 'ctl' else old[a][k])
for a, b in [(16, 32), (32, 64), (1, 64)]:
    print('per-node %d->%d: Charades %.3f (old %.3f) / Devastator %.3f / ROSS %.3f' % (a, b, pn(a, b, 'ctl'),
          old[b]['ctl'] / (b // a) / old[a]['ctl'], pn(a, b, 'dev'), pn(a, b, 'ross')))
print('\nbundling at 64 nodes (best htram fixed W / best direct fixed W, P64 direct %.1f): local 1 W 400 %.2f; WPs 512 (P64) 1.85' % (DIRECT64, L64w / DIRECT64))
print('controller / best direct fixed W at 64 nodes: local 1 %.2f; WPs 512 (P64) %.2f' % (L64 / DIRECT64, old[64]['ctl'] / DIRECT64))
