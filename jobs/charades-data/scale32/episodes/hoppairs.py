#!/usr/bin/env python3
"""Job E, tree runs: for waves whose reduction is >= 2x the median, the slowest hop's
(sender node -> receiver node, kind) pairs, tallied; and for each pair, how often its
hops are slow (>= 100 µs beyond the pair's fastest) over all waves.
Usage: hoppairs.py <run ctl_sweep dir> <job .out>"""
import csv, glob, os, re, sys, statistics as st
from collections import Counter, defaultdict
cs, jo = sys.argv[1], sys.argv[2]
for l in open(jo):
    mm = re.search(r'nodes (c\S+(?: c\S+)+)', l)
    if mm: NL = mm.group(1).split(); break
nd = lambda p: NL[p // 2][1:]
files = sorted(glob.glob(os.path.join(cs, 'gvt_waves_*.csv')), key=lambda f: int(re.search(r'_(\d+)\.csv', f).group(1)))
P = [list(csv.DictReader(open(f))) for f in files]
m = min(len(p) for p in P)
red = [min(float(p[i]['result_s']) - float(p[i]['handled_s']) for p in P) for i in range(m)]
H = defaultdict(list); mins = {}; allh = defaultdict(list)
for f in glob.glob(os.path.join(cs, 'gvt_hops_*.csv')):
    p = int(re.search(r'_(\d+)\.csv', f).group(1))
    for x in csv.DictReader(open(f)):
        k = int(x['kind'])
        if k not in (0, 1): continue
        q, dt = int(x['peer']), float(x['recv_s']) - float(x['sent_s'])
        H[int(x['wave'])].append((p, q, k, dt)); allh[(q, p, k)].append(dt)
        mins[(p, q, k)] = min(mins.get((p, q, k), 9e9), dt)
med = st.median(red[len(red) // 10:])
pairs = Counter()
for i in range(1, m):
    if red[i] < 2 * med or i not in H: continue
    e, p, q, k = max(((dt - mins[(p, q, k)], p, q, k) for p, q, k, dt in H[i]))
    pairs[(q, p, k)] += 1
tot = sum(pairs.values())
print(cs.split('/')[-2], '- slowest hop of stretched waves, by pair (sender proc/node -> receiver proc/node):')
for (q, p, k), c in pairs.most_common(10):
    v = allh[(q, p, k)]; mn = min(v)
    print('  %2d %s -> %2d %s %-4s %5d (%4.1f%%) | this pair over all waves: median %5.1f µs beyond fastest, >= 100 µs beyond in %.2f%% of %d' % (
        q, nd(q), p, nd(p), 'up' if k == 0 else 'down', c, 100 * c / tot, 1e6 * (st.median(v) - mn), 100 * sum(x - mn >= 1e-4 for x in v) / len(v), len(v)))
# per pair, share of hops >= 100 µs slow, all pairs ranked
rk = []
for (q, p, k), v in allh.items():
    mn = min(v); rk.append((sum(x - mn >= 1e-4 for x in v) / len(v), q, p, k))
rk.sort(reverse=True)
print('  pairs ranked by share of hops >= 100 µs beyond their fastest (top 8; all-pairs median %.3f%%):' % (100 * st.median([r[0] for r in rk])))
for s, q, p, k in rk[:8]:
    print('    %2d %s -> %2d %s %-4s %.2f%%' % (q, nd(q), p, nd(p), 'up' if k == 0 else 'down', 100 * s))
