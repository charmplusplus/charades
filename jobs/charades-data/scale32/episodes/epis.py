import csv, glob, os, re, sys, statistics as st, collections
# Per bin: pickup (first PE contribution - result(i-1)) median/max over processes; turnaround median/max;
# which process contributes last (min wait), and its share; the per-process wait spread (max wait - min wait).
d = sys.argv[1]; bins = float(sys.argv[2]); tmax = float(sys.argv[3])
P = [list(csv.DictReader(open(f))) for f in sorted(glob.glob(os.path.join(d, 'gvt_waves_*.csv')), key=lambda f: int(re.search(r'_(\d+)\.csv', f).group(1)))]
m = min(len(p) for p in P); np_ = len(P)
A = [[(float(r['first_s']), float(r['last_s']), float(r['result_s']), float(r['handled_s'])) for r in p[:m]] for p in P]
t0 = A[0][0][2]; B = collections.OrderedDict()
for i in range(1, m):
    pick = [a[i][0] - a[i-1][2] for a in A]
    turn = [a[i][3] - a[i-1][2] for a in A]
    wait = [a[i][2] - a[i][3] for a in A]
    last = min(range(np_), key=lambda j: wait[j])
    b = int((A[0][i-1][2] - t0) / bins)
    if b * bins > tmax: break
    B.setdefault(b, []).append((st.median(pick), max(pick), st.median(turn), max(turn), min(wait), max(wait) - min(wait), last, A[0][i][2] - A[0][i-1][2]))
print('µs, means per bin; last = process with the shortest wait (contributed last)')
print('%-10s %5s %6s | pickup med  max | turn med  max | min wait | wait spread | last proc (share)' % ('wall s', 'waves', 'period'))
for b, rs in B.items():
    mean = lambda j: 1e6 * st.mean(r[j] for r in rs)
    c = collections.Counter(r[6] for r in rs).most_common(3)
    print('%4.2f-%4.2f %5d %6.0f | %10.0f %4.0f | %8.0f %4.0f | %8.0f | %11.0f | %s' % (b*bins, (b+1)*bins, len(rs), mean(7), mean(0), mean(1), mean(2), mean(3), mean(4), mean(5), ', '.join('%d (%.0f%%)' % (k, 100.0*v/len(rs)) for k, v in c)))
