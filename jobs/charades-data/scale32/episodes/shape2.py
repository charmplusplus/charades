import csv, sys, statistics as st
# compact: 0.25 s wall bins, mean wave period (us) per bin, until 8 s
for path in sys.argv[1:]:
    t = list(csv.DictReader(open(path + '/gvt_trace.csv')))
    s = [float(w['start_s']) for w in t]; n = len(s); t0 = s[0]
    steady = st.median([s[i+1]-s[i] for i in range(n//2, 9*n//10)])
    bins = {}
    for i in range(n-1):
        k = int((s[i]-t0)/0.25)
        bins.setdefault(k, []).append(s[i+1]-s[i])
    row = ' '.join('%5.0f' % (1e6*st.mean(bins[k])) if k in bins else '    -' for k in range(0, 36))
    print('%-28s steady %4.0f | %s' % (path.split('n32_j3657016/')[1].replace('/ctl_sweep',''), 1e6*steady, row))
