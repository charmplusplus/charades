#!/usr/bin/env python3
"""Job P (charades RESULTS.md section 151): per-LP rollback (--rollback-unit=1)
against chare rollback. Tags: <wl>_c16 / c4 (chare rollback, W 400),
<wl>_p16def / p4def (per-LP, W 400 and 800, deadline W + 8), <wl>_p16held /
p4held (per-LP, W 800, deadline 408), <wl>_c1held (1 LP per chare, chare
rollback, W 800, deadline 408), g2000_p4spin{def,held} (20 us GVT delay).
Usage: lprb51_summary.py j<id>"""
import glob, os, re, sys, statistics as st, collections
d = sys.argv[1]
KEYS = {'committed': 'Events Committed', 'rolled': 'Events Rolled Back', 'rate': 'Event Rate',
        'ts_rb': 'Timestamp Rollback Calls', 'ev_rb': 'Event Rollback Calls',
        'held': r'Held Stragglers \(late or held by htram\)', 'epm': 'Events per htram Message'}
def parse(f):
    t = open(f).read(); r = {}
    for k, pat in KEYS.items():
        m = re.findall(r'\t' + pat + r'\s+([-\d.]+)', t)
        if m: r[k] = float(m[0])
    return r
C = collections.defaultdict(list)
for f in glob.glob(os.path.join(d, '*_r[12]', 'ctl_sweep', 'logs', '*.out')):
    wl, arm, rep = re.match(r'(\w+?)_(c16|c4|c1held|p16def|p16held|p4def|p4held|p4spindef|p4spinheld)_r(\d)', f.split(os.sep)[-4]).groups()
    W = int(re.search(r'_w(\d+)\.out$', f).group(1)); r = parse(f)
    if 'rate' in r: C[(wl, arm, W)].append(r)
NAMES = {'g100': 'σ 100', 'g2000': 'σ 2,000', 'uni': 'uniform'}
LABEL = {'c16': '16/chare  W+8', 'c4': '4/chare   W+8', 'p16def': '16/LP     W+8', 'p16held': '16/LP     408',
         'p4def': '4/LP      W+8', 'p4held': '4/LP      408', 'c1held': '1/chare   408'}
ex = lambda r: r['committed'] + r['rolled']
med = lambda v, fn: st.median(fn(r) for r in v)
print('Median of 2. LPC/unit and deadline; rolled % (lower is better); M ev/s (higher is better);')
print('÷best = ÷ 4 LPs per chare, chare rollback, W 400 (the best setting before); rb/call = events rolled back per rollback call\n')
print('%-9s %-15s %5s %8s %8s %6s %8s %7s %6s' % ('workload', 'LPC/unit dl', 'W', 'rolled%', 'M ev/s', '÷best', 'prim/Mev', 'rb/call', 'ev/msg'))
for wl in ('g100', 'g2000', 'uni'):
    base = C.get((wl, 'c4', 400)); b = med(base, lambda r: r['rate']) if base else None
    for arm in ('c16', 'c4', 'p16def', 'p16held', 'p4def', 'p4held', 'c1held'):
        for W in (400, 800):
            v = C.get((wl, arm, W))
            if not v: continue
            rate = med(v, lambda r: r['rate'])
            print('%-9s %-15s %5d %8.3f %8.1f %6s %8.1f %7.1f %6.1f' % (NAMES[wl], LABEL[arm], W, med(v, lambda r: 100 * r['rolled'] / ex(r)), rate / 1e6,
                  '%.3f' % (rate / b) if b else '-', med(v, lambda r: 1e6 * r['ts_rb'] / ex(r)), med(v, lambda r: r['rolled'] / max(1, r['ts_rb'] + r['ev_rb'])), med(v, lambda r: r.get('epm', 0))))
    commits = {r['committed'] for k, v in C.items() if k[0] == wl for r in v}
    print('   same committed events in every run:', 'yes' if len(commits) == 1 else 'NO %s' % sorted(commits))
print('\n20 us GVT delay, σ 2,000, 4 LPs per chare, per-LP rollback (with ÷ without; higher is better):')
for arm, W, base in (('p4spindef', 400, 'p4def'), ('p4spinheld', 800, 'p4held')):
    v = C.get(('g2000', arm, W)); b = C.get(('g2000', base, W))
    if v and b:
        a, c = med(v, lambda r: r['rate']) / 1e6, med(b, lambda r: r['rate']) / 1e6
        print('  W %-4d %-9s: %.1f with, %.1f without, ratio %.3f' % (W, 'default' if base == 'p4def' else 'held 408', a, c, a / c))
