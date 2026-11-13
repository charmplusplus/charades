#!/usr/bin/env python3
"""Job E, tree runs: per wave whose reduction (result - counts sent, smallest over
processes) is at least 2x the run's median, the largest single hop's excess (its
time beyond that sender-receiver pair's fastest, so clock offsets cancel) as a share
of the wave's reduction excess (reduction - median), and the receiving / sending
process of that hop. Tallies receivers and senders over the stretched waves.
Processes 2k and 2k+1 share node k. Usage: hopwave.py <run ctl_sweep dir> [node list file]"""
import csv, glob, os, re, sys, statistics as st
from collections import Counter, defaultdict
cs = sys.argv[1]
NL = []
if len(sys.argv) > 2:
    for l in open(sys.argv[2]):
        m = re.search(r'nodes (c\S+(?: c\S+)+)', l)
        if m: NL = m.group(1).split(); break
files = sorted(glob.glob(os.path.join(cs, 'gvt_waves_*.csv')), key=lambda f: int(re.search(r'_(\d+)\.csv', f).group(1)))
P = [list(csv.DictReader(open(f))) for f in files]
m = min(len(p) for p in P)
red = [min(float(p[i]['result_s']) - float(p[i]['handled_s']) for p in P) for i in range(m)]
t0 = float(P[0][0]['result_s'])
H = defaultdict(list); mins = {}
for f in glob.glob(os.path.join(cs, 'gvt_hops_*.csv')):
    p = int(re.search(r'_(\d+)\.csv', f).group(1))
    for x in csv.DictReader(open(f)):
        k = int(x['kind'])
        if k not in (0, 1): continue
        q, dt = int(x['peer']), float(x['recv_s']) - float(x['sent_s'])
        H[int(x['wave'])].append((p, q, k, dt))
        mins[(p, q, k)] = min(mins.get((p, q, k), 9e9), dt)
med = st.median(red[len(red) // 10:])
recv, send, kinds = Counter(), Counter(), Counter(); shares = []; n = 0
times = []
for i in range(1, m):
    if red[i] < 2 * med or i not in H: continue
    n += 1
    ex = max(((dt - mins[(p, q, k)], p, q, k) for p, q, k, dt in H[i]))
    sh = ex[0] / (red[i] - med)
    shares.append(sh)
    if sh >= 0.7:
        recv[ex[1]] += 1; send[ex[2]] += 1; kinds['up' if ex[3] == 0 else 'down'] += 1
        times.append(float(P[0][i - 1]['result_s']) - t0)
node = lambda p: (NL[p // 2][-7:] if NL else 'node%d' % (p // 2))
print('%s: %d waves, median reduction %.0f µs; %d waves at >= 2x' % (cs.split('/')[-2], m, 1e6 * med, n))
if n:
    shares.sort()
    print('  largest single hop / wave reduction excess: median %.2f; >= 0.7 in %d of %d waves (%.0f%%)' % (shares[len(shares) // 2], sum(s >= 0.7 for s in shares), n, 100 * sum(s >= 0.7 for s in shares) / n))
    print('  in those, hop kind %s' % dict(kinds))
    print('  receivers: %s' % ', '.join('%d (%s) %d' % (p, node(p), c) for p, c in recv.most_common(6)))
    print('  senders:   %s' % ', '.join('%d (%s) %d' % (p, node(p), c) for p, c in send.most_common(6)))
    if times:
        b = Counter(int(t / 0.5) * 0.5 for t in times)
        print('  when (0.5 s bins of wall time: waves): %s' % ', '.join('%.1f: %d' % (k, v) for k, v in sorted(b.items())))
