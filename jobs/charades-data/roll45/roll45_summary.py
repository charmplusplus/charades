#!/usr/bin/env python3
"""Job R (charades RESULTS.md section 145): rollbacks at the same window,
Charades with htram / direct sends / Devastator. Usage: roll45_summary.py j<id>"""
import glob, os, re, sys, statistics as st, collections
d = sys.argv[1]
KEYS = {'committed': 'Events Committed', 'rolled': 'Events Rolled Back', 'rate': 'Event Rate',
        'exec': 'Execution Time', 'gvts': 'Total GVT Computations', 'ts_rb': 'Timestamp Rollback Calls',
        'ev_rb': 'Event Rollback Calls', 'late': r'Late Stragglers \(delay >= window\)',
        'held': r'Held Stragglers \(late or held by htram\)', 'anti': 'Anti Event Sends',
        'fp_anti': r'Process Anti Sends \(fast path\)', 'epm': 'Events per htram Message',
        'blocked_held': 'Held Stragglers, at a PE blocked at its window'}
def parse(f):
    t = open(f).read(); r = {}
    for k, pat in KEYS.items():
        m = re.findall(r'\t' + pat + r'\s+([-\d.]+)', t)
        if m: r[k] = float(m[-1] if k != 'committed' else m[0])
    return r
C = collections.defaultdict(list)   # (wl, kind, W) -> [run dicts]
for f in glob.glob(os.path.join(d, '*_r[12]', 'ctl_sweep', 'logs', '*.out')):
    tag = f.split(os.sep)[-4]; wl, kind, rep = re.match(r'(\w+?)_(htram|direct|spin)_r(\d)', tag).groups()
    W = int(re.search(r'_w(\d+)\.out$', f).group(1)); r = parse(f)
    if 'rate' in r: C[(wl, kind, W)].append(r)
D = collections.defaultdict(list)
for l in open(os.path.join(d, 'deva', 'results.txt')):
    kv = dict(x.split('=', 1) for x in l.split() if '=' in x)
    m = re.match(r'(\w+?)_w(\d+)_r\d', kv.get('label', ''))
    if m and kv.get('status') == 'ok':
        D[(m.group(1), int(m.group(2)))].append(dict(rate=float(kv['committed_per_s']), committed=int(kv['committed']),
            rolled=int(kv['rolled_back']), executed=int(kv['executed'])))
med = lambda xs, k: st.median(x[k] for x in xs)
NAMES = {'g100': 'σ 100', 'g2000': 'σ 2,000', 'uni': 'uniform'}
print('Rolled back as % of executed, and M committed ev/s (median of 2; higher rate is better)')
print('%-9s %-12s %6s %9s %9s %8s %8s %8s %8s %7s %7s' % ('workload', 'engine', 'W', 'rolled %', 'M ev/s', 'prim/Mev', 'held %', 'late %', 'anti rb%', 'ev/msg', 'GVTs'))
for wl in ('g100', 'g2000', 'uni'):
    rows = []
    for kind in ('htram', 'direct', 'spin'):
        for W in sorted({k[2] for k in C if k[0] == wl and k[1] == kind}):
            v = C[(wl, kind, W)]
            ex = [r['committed'] + r['rolled'] for r in v]
            rb = st.median(100 * r['rolled'] / (r['committed'] + r['rolled']) for r in v)
            prim = st.median(1e6 * r['ts_rb'] / (r['committed'] + r['rolled']) for r in v)
            held = st.median(100 * r['held'] / r['ts_rb'] if r['ts_rb'] else 0 for r in v)
            late = st.median(100 * r['late'] / r['ts_rb'] if r['ts_rb'] else 0 for r in v)
            evrb = st.median(100 * r['ev_rb'] / (r['ts_rb'] + r['ev_rb']) if r['ts_rb'] + r['ev_rb'] else 0 for r in v)
            print('%-9s %-12s %6d %9.3f %9.1f %8.1f %8.1f %8.1f %8.1f %7s %7d' % (NAMES[wl], 'Ch ' + kind, W, rb, med(v, 'rate') / 1e6, prim, held, late, evrb,
                  '%.1f' % med(v, 'epm') if 'epm' in v[0] else '-', med(v, 'gvts')))
    for W in sorted({k[1] for k in D if k[0] == wl}):
        v = D[(wl, W)]
        rb = st.median(100 * x['rolled'] / x['executed'] for x in v)
        print('%-9s %-12s %6d %9.3f %9.1f' % (NAMES[wl], 'Devastator', W, rb, med(v, 'rate') / 1e6))
    commits = {r['committed'] for k, v in C.items() if k[0] == wl for r in v} | {x['committed'] for k, v in D.items() if k[0] == wl for x in v}
    print('   same committed events in every run:', 'yes' if len(commits) == 1 else 'NO %s' % sorted(commits))
print('\n(prim/Mev = primary stragglers (timestamp rollback calls) per million executed events; held % and late % = shares of them;')
print(' anti rb% = rollbacks caused by anti-messages as a share of all rollback calls)')
