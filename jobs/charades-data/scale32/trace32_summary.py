#!/usr/bin/env python3
"""A2r traced block (charades RESULTS.md section 144, predictions T1-T4): where
the 16 -> 32-node loss goes. W 400, --gvt-trace=2 --pe-stats=1.
Per run: committed rate per node; waves from PE 0's gvt_trace.csv, split into
start-up (first 10% of waves) and steady (10-95%); per wave, from each
process's gvt_waves_<p>.csv on its own clock: its response = its last PE's
contribution - when it handled the previous wave's result. The slowest
process's response, against the wave period, splits each wave into waiting
for the slowest process and the rest (reduction and broadcast).
Usage: trace32_summary.py <job dir>"""
import csv, glob, os, re, sys, statistics as st
d = sys.argv[1]
def stat(f, key):
    for l in open(f):
        if key in l: return float(l.split()[-1])
R = {}
for N in (16, 32):
    for run in sorted(glob.glob(os.path.join(d, 'n%d' % N, '*_trace'))):
        wl = os.path.basename(run).split('_')[0]
        cs = os.path.join(run, 'ctl_sweep'); log = glob.glob(os.path.join(cs, 'logs', '*.out'))[0]
        committed = stat(log, 'Events Committed'); ex = stat(log, 'Execution Time'); gvts = stat(log, 'Total GVT Computations')
        epm = stat(log, 'Events per htram Message')
        t = list(csv.DictReader(open(os.path.join(cs, 'gvt_trace.csv'))))
        starts = [float(w['start_s']) for w in t]
        n = len(starts); a, b = n // 10, (95 * n) // 100
        startup = starts[a] - starts[0]; steady = (starts[b] - starts[a]) / (b - a)
        # per-process responses, aligned by wave index
        P = [list(csv.DictReader(open(f))) for f in sorted(glob.glob(os.path.join(cs, 'gvt_waves_*.csv')), key=lambda f: int(re.search(r'_(\d+)\.csv', f).group(1)))]
        m = min(len(p) for p in P)
        lo, hi = max(1, m // 10), (95 * m) // 100
        slow, med, per = [], [], []
        p0 = P[0]
        for i in range(lo, hi):
            resp = [float(p[i]['last_s']) - float(p[i - 1]['handled_s']) for p in P]
            slow.append(max(resp)); med.append(st.median(resp))
            per.append(float(p0[i]['handled_s']) - float(p0[i - 1]['handled_s']))
        dec = [1e6 * (starts[min(n - 1, (k + 1) * n // 10)] - starts[k * n // 10]) / max(1, (min(n - 1, (k + 1) * n // 10) - k * n // 10)) for k in range(10)]
        R[(wl, N)] = dict(dec=dec, rate=committed / ex / N / 1e6, ex=ex, waves=n, gvts=gvts, ev_wave=committed / n / N,
                          startup=startup, steady=1e6 * steady, period=1e6 * st.mean(per), slow=1e6 * st.mean(slow),
                          med=1e6 * st.mean(med), epm=epm, procs=len(P))
NAMES = {'g100': 'σ 100', 'g2000': 'σ 2,000', 'uni': 'uniform'}
print('W 400, one run each. Per node: M committed ev/s; waves; committed events per wave per node; times in µs (lower is better)\n')
print('%-9s %3s %8s %6s %7s %8s %9s %8s %8s %8s %6s' % ('workload', 'N', 'Mev/s/n', 'exec s', 'waves', 'ev/wave', 'startup s', 'period', 'slowest', 'median', 'ev/msg'))
for wl in ('g100', 'g2000', 'uni'):
    for N in (16, 32):
        r = R.get((wl, N))
        if r: print('%-9s %3d %8.2f %6.3f %7d %8.0f %9.3f %8.1f %8.1f %8.1f %6.1f' % (NAMES[wl], N, r['rate'], r['ex'], r['waves'], r['ev_wave'], r['startup'], r['period'], r['slow'], r['med'], r['epm']))
print('\n16 -> 32 (ratios 32 ÷ 16):')
for wl in ('g100', 'g2000', 'uni'):
    a, b = R.get((wl, 16)), R.get((wl, 32))
    if not (a and b): continue
    # steady-state closure: per-node rate ∝ events per wave per node / wave period
    pred = (b['ev_wave'] / a['ev_wave']) / (b['period'] / a['period'])
    # start-up share of the loss: time lost = 32's exec - 16's exec (same work per node)
    lost = b['ex'] - a['ex']; lost_start = b['startup'] - a['startup']
    print('  %-9s per-node rate %.3f | steady: events/wave/node %.3f, wave period %.3f (%+.0f µs) -> %.3f | median process response %+.0f µs, slowest - median %+.0f µs | first 10%% of waves: %s of lost time | ev/msg %.2f' % (
        NAMES[wl], b['rate'] / a['rate'], b['ev_wave'] / a['ev_wave'], b['period'] / a['period'], b['period'] - a['period'], pred,
        b['med'] - a['med'], (b['slow'] - b['med']) - (a['slow'] - a['med']),
        '%.0f%%' % (100 * lost_start / lost) if lost > 0 else 'n/a (32 faster)', b['epm'] / a['epm']))
print('\nMean wave period by tenth of the run (µs; lower is better):')
for wl in ('g100', 'g2000', 'uni'):
    for N in (16, 32):
        r = R.get((wl, N))
        if r: print('  %-9s %3d  %s' % (NAMES[wl], N, ' '.join('%5.0f' % x for x in r['dec'])))
