import csv, glob, os, re, sys, statistics as st, collections
# Per wave: each process's turnaround = handled(i) - result(i-1) (own clock); the wave period
# = slowest turnaround + the reduction/broadcast latency seen by the slowest process (min wait).
# Within the slowest process: pickup = first - result(i-1), PE spread = last - first, combine = handled - last.
d = sys.argv[1]; bins = float(sys.argv[2]) if len(sys.argv) > 2 else 0.25
P = [list(csv.DictReader(open(f))) for f in sorted(glob.glob(os.path.join(d, 'gvt_waves_*.csv')), key=lambda f: int(re.search(r'_(\d+)\.csv', f).group(1)))]
m = min(len(p) for p in P); np_ = len(P)
F = lambda p, i, k: float(p[i][k])
t0 = F(P[0], 0, 'result_s')
B = collections.OrderedDict()
for i in range(1, m):
    turn = [F(p, i, 'handled_s') - F(p, i-1, 'result_s') for p in P]
    wait = [F(p, i, 'result_s') - F(p, i, 'handled_s') for p in P]
    k = max(range(np_), key=lambda j: turn[j]); pk = P[k]
    per = F(P[0], i, 'result_s') - F(P[0], i-1, 'result_s')
    rec = (per, turn[k], min(wait), st.median(turn), F(pk, i, 'first_s') - F(pk, i-1, 'result_s'), F(pk, i, 'last_s') - F(pk, i, 'first_s'), F(pk, i, 'handled_s') - F(pk, i, 'last_s'), k)
    b = int((F(P[0], i-1, 'result_s') - t0) / bins)
    B.setdefault(b, []).append(rec)
print('µs per wave, means per %.2f s wall bin. period = slowest process turnaround + min wait (reduction after it).' % bins)
print('%-11s %6s %7s %8s %8s %8s | slowest proc: %7s %7s %7s | top slow procs' % ('wall s', 'waves', 'period', 'slow trn', 'min wait', 'med trn', 'pickup', 'PEspread', 'combine'))
for b, rs in B.items():
    if b > 40: break
    c = collections.Counter(r[7] for r in rs).most_common(3)
    mean = lambda j: 1e6 * st.mean(r[j] for r in rs)
    print('%4.2f-%4.2f  %6d %7.0f %8.0f %8.0f %8.0f | %21.0f %7.0f %7.0f | %s' % (b*bins, (b+1)*bins, len(rs), mean(0), mean(1), mean(2), mean(3), mean(4), mean(5), mean(6), c))
