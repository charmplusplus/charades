import csv, glob, os, re, sys, statistics as st
# Steady (waves 10-95%): mean period; slowest and median process turnaround (result(i-1) -> its contribution sent);
# reduction after the last contribution (min over processes of result(i) - contribution sent). µs.
B = sys.argv[1]
for wl in ('g100_pp2048', 'g2000_pp512', 'uni_wps512'):
    for N in (16, 32):
        d = os.path.join(B, 'n%d' % N, wl + '_trace', 'ctl_sweep')
        P = [list(csv.DictReader(open(f))) for f in sorted(glob.glob(os.path.join(d, 'gvt_waves_*.csv')), key=lambda f: int(re.search(r'_(\d+)\.csv', f).group(1)))]
        m = min(len(p) for p in P)
        A = [[(float(r['result_s']), float(r['handled_s'])) for r in p[:m]] for p in P]
        per, slow, med, red = [], [], [], []
        for i in range(max(1, m // 10), 95 * m // 100):
            turn = [a[i][1] - a[i-1][0] for a in A]
            per.append(A[0][i][0] - A[0][i-1][0]); slow.append(max(turn)); med.append(st.median(turn))
            red.append(min(a[i][0] - a[i][1] for a in A))
        print('%-12s %2d nodes: period %5.0f | turnaround slowest %5.0f median %5.0f | reduction after last %5.0f  (medians: period %5.0f slowest %5.0f red %5.0f)' % (
            wl, N, 1e6*st.mean(per), 1e6*st.mean(slow), 1e6*st.mean(med), 1e6*st.mean(red), 1e6*st.median(per), 1e6*st.median(slow), 1e6*st.median(red)))
