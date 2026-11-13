#!/usr/bin/env python3
"""Per PHOLD workload and node count: the controller's median rate (M committed ev/s)
for each htram setting the paper jobs ran (F1a/F1b 1-16, R8 8, F1-32, P64, UL small
for local 1 pad 1), and which is higher."""
import csv, glob, os, re, statistics as st, collections
D = os.path.expanduser('~/charades-data')
JOBS = [('F1a', D+'/f1/scale240/a_j3689004', None), ('F1b', D+'/f1/scale240/b_j3689513', None),
        ('R8', D+'/f1/r8_260/j3695259', {8}), ('F1-32', D+'/f1/scale240/big_j3688916', {32}),
        ('P64', D+'/s64_262/p_j3696079', {64}), ('UL', D+'/f1/ul277/small_j3711818', None)]
WL = {'g100': 'σ 100', 'g500': 'σ 500', 'g1000': 'σ 1,000', 'g1000x': 'σ 1,000', 'g2000': 'σ 2,000', 'g4000': 'σ 4,000',
      'uni': 'uniform', 'l10g500': 'lookahead 10, σ 500', 'l10g2000': 'lookahead 10, σ 2,000'}
r = collections.defaultdict(list)
for name, d, only in JOBS:
    for f in glob.glob(d + '/n*/*.csv'):
        N = int(os.path.basename(os.path.dirname(f))[1:])
        if only and N not in only: continue
        if N == 8 and name != 'R8': continue   # the paper's 8-node column is R8's (section 261)
        b = os.path.basename(f)
        if name == 'UL':
            m = re.match(r'uni_pp_512_l1_p1_r\d+\.csv$', b)
            if not m: continue
            wl = 'uni'
        else:
            m = re.match(r'(g\d+x?|uni|l10g\d+)_(pp\d+|wps\d+)_r\d\.csv$', b)
            if not m: continue
            wl = m.group(1)
        for row in csv.DictReader(open(f)):
            if row['status'] != 'ok' or row['arm'] != 'mb:0': continue
            if not (row.get('count_waves') or '0').strip('0.'): continue
            agg = row['agg']
            if name == 'UL' and agg != 'pp:512:l1:p1': continue
            r[(WL[wl], N, agg)].append((float(row['event_rate']) / 1e6, name))
order = list(dict.fromkeys(WL.values()))
for w in order:
    for N in [1, 2, 4, 8, 16, 32, 64]:
        c = {a: (st.median(x for x, _ in v), len(v), sorted({j for _, j in v})) for (ww, n, a), v in r.items() if ww == w and n == N}
        if not c: continue
        best = max(c, key=lambda a: c[a][0])
        print('%-22s %2d  best %-14s  %s' % (w, N, best, '  '.join('%s %.1f (n%d %s)' % (a, m, k, '/'.join(j)) for a, (m, k, j) in sorted(c.items()))))
