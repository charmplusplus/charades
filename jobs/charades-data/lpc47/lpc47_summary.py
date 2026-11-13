#!/usr/bin/env python3
"""Job L (charades RESULTS.md section 147): 16, 4 and 1 LPs per chare at
W 400/800/1,600 with htram; Devastator from job R (roll45) for reference.
Usage: lpc47_summary.py j<id> [roll45 dir]"""
import glob, os, re, sys, statistics as st, collections
d = sys.argv[1]; rd = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser('~/charades-data/roll45/j3657717')
KEYS = {'committed': 'Events Committed', 'rolled': 'Events Rolled Back', 'rate': 'Event Rate',
        'ts_rb': 'Timestamp Rollback Calls', 'ev_rb': 'Event Rollback Calls',
        'held': r'Held Stragglers \(late or held by htram\)', 'epm': 'Events per htram Message',
        'gvts': 'Total GVT Computations', 'exec': 'Execution Time'}
def parse(f):
    t = open(f).read(); r = {}
    for k, pat in KEYS.items():
        m = re.findall(r'\t' + pat + r'\s+([-\d.]+)', t)
        if m: r[k] = float(m[0])
    return r
C = collections.defaultdict(list)
for f in glob.glob(os.path.join(d, '*_l*_r[12]', 'ctl_sweep', 'logs', '*.out')):
    wl, L, rep = re.match(r'(\w+?)_l(\d+)_r(\d)', f.split(os.sep)[-4]).groups()
    W = int(re.search(r'_w(\d+)\.out$', f).group(1)); r = parse(f)
    if 'rate' in r: C[(wl, int(L), W)].append(r)
D = collections.defaultdict(list)
for l in open(os.path.join(rd, 'deva', 'results.txt')):
    kv = dict(x.split('=', 1) for x in l.split() if '=' in x)
    m = re.match(r'(\w+?)_w(\d+)_r\d', kv.get('label', ''))
    if m and kv.get('status') == 'ok':
        D[(m.group(1), int(m.group(2)))].append((float(kv['committed_per_s']) / 1e6, 100 * int(kv['rolled_back']) / int(kv['executed']), int(kv['committed'])))
NAMES = {'g100': 'σ 100', 'g2000': 'σ 2,000', 'uni': 'uniform'}
ex = lambda r: r['committed'] + r['rolled']
print('Median of 2. rolled % = rolled back / executed (lower is better); M ev/s committed (higher is better);')
print('prim/Mev = primary stragglers per million executed; rb/strag = events rolled back per rollback call\n')
print('%-9s %4s %6s %9s %9s %9s %9s %7s %6s' % ('workload', 'LPC', 'W', 'rolled %', 'M ev/s', 'prim/Mev', 'rb/strag', 'ev/msg', 'GVTs'))
for wl in ('g100', 'g2000', 'uni'):
    for L in (16, 4, 1):
        for W in (400, 800, 1600):
            v = C.get((wl, L, W))
            if not v: print('%-9s %4d %6d   missing' % (NAMES[wl], L, W)); continue
            m = lambda fn: st.median(fn(r) for r in v)
            print('%-9s %4d %6d %9.3f %9.1f %9.1f %9.1f %7.1f %6d' % (NAMES[wl], L, W, m(lambda r: 100 * r['rolled'] / ex(r)), m(lambda r: r['rate'] / 1e6),
                  m(lambda r: 1e6 * r['ts_rb'] / ex(r)), m(lambda r: r['rolled'] / max(1, r['ts_rb'] + r['ev_rb'])), m(lambda r: r.get('epm', 0)), m(lambda r: r['gvts'])))
    for W in (400, 800, 1600):
        v = D.get((wl, W))
        if v: print('%-9s %4s %6d %9.3f %9.1f   (Devastator, job R)' % (NAMES[wl], '-', W, st.median(x[1] for x in v), st.median(x[0] for x in v)))
    commits = {r['committed'] for k, v in C.items() if k[0] == wl for r in v} | {x[2] for k, v in D.items() if k[0] == wl for x in v}
    print('   same committed events in every run (incl. Devastator):', 'yes' if len(commits) == 1 else 'NO %s' % sorted(commits))
