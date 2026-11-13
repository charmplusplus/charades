#!/usr/bin/env python3
"""Job N32 (charades RESULTS.md section 165): numactl --localalloc at 32 nodes.
Usage: numa32_summary.py <job dir>
M1 Charades loc ÷ bal paired by rep; M2 TLB burst and dip; M3 rep spread (max ÷
min); M4 Devastator loc ÷ bal and Charades ÷ Devastator under each launch; M5
16 -> 32 per-node efficiency; M6 controller ÷ W 400 (both --localalloc); M7
largest gap between progress lines. Higher is better for every ratio."""
import csv, glob, os, re, sys, statistics as st
d = sys.argv[1]
med = st.median
H = []
for f in glob.glob(os.path.join(d, 'hfi', '*.csv')):
    rows = [(float(r['unix_s']), int(r['TLB'])) for r in csv.DictReader(open(f))]
    if len(rows) > 1: H.append(rows)
def val(s, t):
    for a, b in zip(s, s[1:]):
        if a[0] <= t <= b[0]: return a[1] + (b[1] - a[1]) * (t - a[0]) / (b[0] - a[0])
def tlb(a, b):
    tot = 0.0
    for s in H:
        x, y = val(s, a), val(s, b)
        if x is not None and y is not None: tot += (y - x) / (b - a)
    return tot
def run(n, tag):
    f = glob.glob(os.path.join(d, n, tag, 'ctl_sweep', 'logs', '*.out'))
    c = os.path.join(d, n, tag + '.csv')
    if not f or not os.path.exists(c): return None
    U, p, gap = None, [(0.0, 0)], 0.0
    for l in open(f[0]):
        m = re.match(r'Simulation Starting: .* Unix time ([\d.]+)', l)
        if m: U = float(m.group(1))
        m = re.match(r'GVT\s+\d+:\s+(\d+) \(.*\), [\d.]+ MB, ([\d.]+) s', l)
        if m:
            t = float(m.group(2))
            if len(p) > 1: gap = max(gap, t - p[-1][0])
            p.append((t, int(m.group(1))))
    r = next(csv.DictReader(open(c)))
    return dict(U=U, p=p, gap=gap, rate=float(r['event_rate']) / 1e6, status=r['status'], committed=r['committed'], rolled=r['rolled_back'], window=r.get('mean_window'))
def sim(p, a, b):
    def at(t):
        for (ta, va), (tb, vb) in zip(p, p[1:]):
            if ta <= t <= tb: return va + (vb - va) * (t - ta) / max(1e-9, tb - ta)
    x, y = at(a), at(b)
    return (y - x) / (b - a) if x is not None and y is not None else float('nan')
R = {}
for n in ('n32', 'n16'):
    for f in glob.glob(os.path.join(d, n, '*_r?.csv')):
        t = os.path.basename(f)[:-4]; x = run(n, t)
        if x: R[(n, t)] = x
print('== Charades, 32 nodes (M ev/s; paired = loc ÷ bal of the same rep)')
print('%-8s %-6s %-30s %8s %-28s %7s %10s %8s %8s %s' % ('workload', 'arm', 'M ev/s: median (reps)', 'spread', 'loc ÷ bal paired (reps)', 'dip', 'TLB burst', 'max gap', 'rolled', 'committed equal'))
for w in ('g100', 'g2000', 'uni'):
    com = {x['committed'] for (n, t), x in R.items() if t.startswith(w + '_')}
    for a in ('loc', 'bal', 'ctl'):
        v = [(t, R[('n32', t)]) for t in sorted(t for (n, t) in R if n == 'n32' and t.startswith('%s_%s_r' % (w, a)))]
        if not v: continue
        rates = [x['rate'] for _, x in v]
        pr = ''
        if a != 'bal':
            ps = [x['rate'] / R[('n32', '%s_bal_r%s' % (w, t[-1]))]['rate'] for t, x in v if ('n32', '%s_bal_r%s' % (w, t[-1])) in R]
            if ps: pr = '%.3f (%s)' % (med(ps), ', '.join('%.3f' % y for y in ps))
        dips = [sim(x['p'], 1.5, 2.0) / sim(x['p'], 1.0, 1.5) for _, x in v]
        bur = [tlb(x['U'] + 1.5, x['U'] + 2.25) / max(1.0, tlb(x['U'] + 0.75, x['U'] + 1.5)) for _, x in v]
        print('%-8s %-6s %-30s %8.2f %-28s %7s %10s %8.3f %8s %s' % (w, a, '%.1f (%s)' % (med(rates), ', '.join('%.1f' % r for r in rates)), max(rates) / min(rates), pr,
              '%.2f-%.2f' % (min(dips), max(dips)), '%.1f-%.1fx' % (min(bur), max(bur)), max(x['gap'] for _, x in v), ','.join(x['rolled'] for _, x in v), len(com) == 1))
c100 = [R[('n32', t)]['rate'] for (n, t) in R if n == 'n32' and t.startswith('g100_ctl')]
l100 = [R[('n32', t)]['rate'] for (n, t) in R if n == 'n32' and t.startswith('g100_loc')]
c2k = [R[('n32', t)]['rate'] for (n, t) in R if n == 'n32' and t.startswith('g2000_ctl')]
l2k = [R[('n32', t)]['rate'] for (n, t) in R if n == 'n32' and t.startswith('g2000_loc')]
if c100 and l100: print('\nM6 controller ÷ W 400 (both --localalloc), medians: σ 100 %.3f, σ 2,000 %.3f' % (med(c100) / med(l100), med(c2k) / med(l2k) if c2k and l2k else float('nan')))
l16 = [R[('n16', t)]['rate'] for (n, t) in R if n == 'n16' and t.startswith('g100_loc')]
if l16 and l100: print('M5 per-node efficiency 16 -> 32, σ 100 --localalloc: %.1f ÷ (2 × %.1f) = %.3f (16-node reps %s)' % (med(l100), med(l16), med(l100) / (2 * med(l16)), ', '.join('%.1f' % r for r in l16)))
print('\n== Devastator, W 1,000 (M ev/s)')
D = {}
for f in glob.glob(os.path.join(d, 'n32', 'deva', 'results.txt')):
    for l in open(f):
        kv = dict(x.split('=', 1) for x in l.split() if '=' in x)
        if 'label' in kv: D[kv['label']] = (float(kv.get('committed_per_s', 'nan')) / 1e6, kv.get('rc'), kv.get('committed'))
for w in ('g100', 'uni'):
    lo = [D[k][0] for k in sorted(D) if k.startswith(w + '_w1000_loc')]
    ba = [D[k][0] for k in sorted(D) if k.startswith(w + '_w1000_bal')]
    ps = [D['%s_w1000_loc_r%d' % (w, i)][0] / D['%s_w1000_bal_r%d' % (w, i)][0] for i in (1, 2) if '%s_w1000_loc_r%d' % (w, i) in D and '%s_w1000_bal_r%d' % (w, i) in D]
    cl = [R[('n32', t)]['rate'] for (n, t) in R if n == 'n32' and t.startswith(w + '_loc')]
    cb = [R[('n32', t)]['rate'] for (n, t) in R if n == 'n32' and t.startswith(w + '_bal')]
    print('  %-5s loc %s | bal %s | loc ÷ bal paired %s | Charades ÷ Devastator: both loc %.2f, both bal %.2f, each at its better %.2f' % (
        w, ', '.join('%.1f' % x for x in lo), ', '.join('%.1f' % x for x in ba), ', '.join('%.3f' % x for x in ps),
        med(cl) / med(lo) if cl and lo else float('nan'), med(cb) / med(ba) if cb and ba else float('nan'),
        max(med(cl), med(cb)) / max(med(lo), med(ba)) if cl and cb and lo and ba else float('nan')))
    print('        committed: %s' % sorted({D[k][2] for k in D if k.startswith(w + '_')}))
