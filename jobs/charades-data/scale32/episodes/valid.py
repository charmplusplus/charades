import csv, sys, statistics as st, collections
# per wall bin: mean asked, passed0, valid (min buckets passed over PEs), completed, lead0, transit_first
for path in sys.argv[2:]:
    bins = float(sys.argv[1])
    t = list(csv.DictReader(open(path + '/gvt_trace.csv')))
    t0 = float(t[0]['start_s']); B = collections.OrderedDict()
    for i in range(len(t) - 1):
        w = t[i]; b = int((float(w['start_s']) - t0) / bins)
        B.setdefault(b, []).append((float(t[i+1]['start_s']) - float(w['start_s']), int(w['asked']), int(w['passed0']), int(w['valid']), int(w['completed']), int(w['lead0']), int(w['transit_first']), int(w['prev_valid'])))
    print('==', path.split('scale32/')[-1])
    print('%-10s %5s %6s %6s %7s %6s %9s %6s %7s %8s' % ('wall s', 'waves', 'period', 'asked', 'passed0', 'valid', 'completed', 'lead0', 'transit', 'prevvalid'))
    for b, rs in list(B.items())[:int(sys.argv[3]) if False else 14]:
        m = lambda j: st.mean(r[j] for r in rs)
        print('%4.2f-%4.2f %5d %6.0f %6.1f %7.1f %6.1f %9.2f %6.0f %7.1f %8.1f' % (b*bins, (b+1)*bins, len(rs), 1e6*m(0), m(1), m(2), m(3), m(4), m(5), m(6), m(7)))
