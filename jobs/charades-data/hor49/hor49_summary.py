#!/usr/bin/env python3
"""Job H (charades RESULTS.md section 149): wide W with the flush deadline held
at 408, 4 and 1 LPs per chare; GVT delay. Usage: hor49_summary.py j<id>"""
import glob, os, re, sys, statistics as st, collections
d = sys.argv[1]
KEYS = {'committed': 'Events Committed', 'rolled': 'Events Rolled Back', 'rate': 'Event Rate',
        'ts_rb': 'Timestamp Rollback Calls', 'ev_rb': 'Event Rollback Calls',
        'held': r'Held Stragglers \(late or held by htram\)', 'epm': 'Events per htram Message',
        'gvts': 'Total GVT Computations'}
def parse(f):
    t = open(f).read(); r = {}
    for k, pat in KEYS.items():
        m = re.findall(r'\t' + pat + r'\s+([-\d.]+)', t)
        if m: r[k] = float(m[0])
    return r
C = collections.defaultdict(list)
for f in glob.glob(os.path.join(d, '*_r[12]', 'ctl_sweep', 'logs', '*.out')):
    wl, L, kind, rep = re.match(r'(\w+?)_l(\d+)_(def|held|spindef|spinheld)_r(\d)', f.split(os.sep)[-4]).groups()
    W = int(re.search(r'_w(\d+)\.out$', f).group(1)); r = parse(f)
    if 'rate' in r: C[(wl, int(L), kind, W)].append(r)
NAMES = {'g100': 'σ 100', 'g2000': 'σ 2,000', 'uni': 'uniform'}
ex = lambda r: r['committed'] + r['rolled']
print('Median of 2. deadline: def = W + 8, held = 408. rolled % lower is better; M ev/s higher is better;')
print('prim/Mev = primary stragglers per million executed; held% = share of them htram held\n')
print('%-9s %3s %-9s %5s %8s %8s %8s %6s %6s %6s' % ('workload', 'LPC', 'deadline', 'W', 'rolled%', 'M ev/s', 'prim/Mev', 'held%', 'ev/msg', 'GVTs'))
for wl in ('g100', 'g2000', 'uni'):
    for L in (4, 1):
        for kind, W in (('def', 400), ('def', 800), ('held', 800), ('held', 1600)):
            v = C.get((wl, L, kind, W))
            if not v: continue
            m = lambda fn: st.median(fn(r) for r in v)
            print('%-9s %3d %-9s %5d %8.3f %8.1f %8.1f %6.1f %6.1f %6d' % (NAMES[wl], L, kind, W, m(lambda r: 100 * r['rolled'] / ex(r)), m(lambda r: r['rate'] / 1e6),
                  m(lambda r: 1e6 * r['ts_rb'] / ex(r)), m(lambda r: 100 * r['held'] / max(1, r['ts_rb'])), m(lambda r: r.get('epm', 0)), m(lambda r: r['gvts'])))
    commits = {r['committed'] for k, v in C.items() if k[0] == wl for r in v}
    print('   same committed events in every run:', 'yes' if len(commits) == 1 else 'NO %s' % sorted(commits))
print('\nGVT delay 20 us, σ 2,000, 1 LP per chare (M ev/s, median of 2; ratio = with delay ÷ without):')
for kind, W, base in (('spindef', 400, 'def'), ('spinheld', 1600, 'held')):
    v = C.get(('g2000', 1, kind, W)); b = C.get(('g2000', 1, base, W))
    if v and b:
        a, c = st.median(r['rate'] for r in v) / 1e6, st.median(r['rate'] for r in b) / 1e6
        print('  W %-5d deadline %-4s: %.1f with delay, %.1f without, ratio %.3f' % (W, base, a, c, a / c))
