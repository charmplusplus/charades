#!/usr/bin/env python3
"""Job N16 (charades RESULTS.md section 163): is the TLB-shootdown burst automatic
NUMA balancing, and does numactl --localalloc remove it and the dip?
Usage: numa_summary.py <job dir>
1. Per arm: M ev/s (median, reps), ÷ default paired by rep (higher is better),
   time lost in the first 2 s, the largest gap between progress lines (s).
2. Per run, 0.25 s bins from 0.5 s to 3.5 s: simulated time per wall second
   (thousands) and, summed over nodes, per second (thousands): TLB shootdowns,
   numa_pte_updates, numa_hint_faults, numa_pages_migrated, thp_collapse_alloc,
   compact_stall, pgmigrate_success. Delayed runs also from 5 s before the clock.
3. N1/N2 checks: 1.5-2.25 s against 0.75-1.5 s, per run; numa_pte_updates over
   the whole run, numactl ÷ default."""
import csv, glob, os, re, sys, statistics as st
from collections import defaultdict
d = sys.argv[1]
H = {}
for f in glob.glob(os.path.join(d, 'hfi', '*.csv')):
    rows = list(csv.DictReader(open(f)))
    if rows: H[os.path.basename(f)[:-4]] = rows
K = ['TLB', 'numa_pte_updates', 'numa_hint_faults', 'numa_hint_faults_local', 'numa_pages_migrated', 'thp_collapse_alloc', 'compact_stall', 'pgmigrate_success']
def series(k):
    out = []
    for rows in H.values():
        s = [(float(r['unix_s']), int(r[k])) for r in rows if r.get(k) not in (None, '', '-1')]
        if len(s) > 1: out.append(s)
    return out
S = {k: series(k) for k in K}
def val(s, t):
    for a, b in zip(s, s[1:]):
        if a[0] <= t <= b[0]: return a[1] + (b[1] - a[1]) * (t - a[0]) / (b[0] - a[0])
def rate(k, a, b):
    tot = 0.0
    for s in S[k]:
        x, y = val(s, a), val(s, b)
        if x is not None and y is not None: tot += (y - x) / (b - a)
    return tot
def run(tag):
    f = glob.glob(os.path.join(d, 'n16', tag, 'ctl_sweep', 'logs', '*.out'))
    if not f: return None
    U, p, gap = None, [(0.0, 0)], 0.0
    for l in open(f[0]):
        m = re.match(r'Simulation Starting: .* Unix time ([\d.]+)', l)
        if m: U = float(m.group(1))
        m = re.match(r'GVT\s+\d+:\s+(\d+) \(.*\), [\d.]+ MB, ([\d.]+) s', l)
        if m:
            t = float(m.group(2)); gap = max(gap, t - p[-1][0]) if len(p) > 1 else gap; p.append((t, int(m.group(1))))
    r = next(csv.DictReader(open(os.path.join(d, 'n16', tag + '.csv'))))
    return dict(U=U, p=p, gap=gap, rate=float(r['event_rate']) / 1e6, status=r['status'], committed=r['committed'])
def sim(p, a, b):
    def at(t):
        for (ta, va), (tb, vb) in zip(p, p[1:]):
            if ta <= t <= tb: return va + (vb - va) * (t - ta) / max(1e-9, tb - ta)
    x, y = at(a), at(b)
    return (y - x) / (b - a) / 1e3 if x is not None and y is not None else float('nan')
def lost2(p):
    T, V = p[-1]; t2, v2 = max((t, v) for t, v in p if t <= 2.0)
    return t2 - v2 / ((V - v2) / (T - t2))
R = {}
for f in sorted(glob.glob(os.path.join(d, 'n16', '*_r?.csv'))):
    tag = os.path.basename(f)[:-4]; x = run(tag)
    if x: R[tag] = x
arm = lambda t: re.sub(r'_r\d$', '', t)
print('== 1. Per arm (16 nodes, W 400)')
print('%-12s %8s %-24s %-26s %8s %8s  %s' % ('arm', 'M ev/s', 'reps', '÷ default, paired (reps)', 'lost 2s', 'max gap', 'committed equal'))
for a in sorted({arm(t) for t in R}, key=lambda a: (a.split('_')[0], a.split('_')[1] != 'def', a)):
    v = [R[t] for t in sorted(R) if arm(t) == a]
    w = a.split('_')[0]
    pr = [R[t]['rate'] / R['%s_def_r%s' % (w, t[-1])]['rate'] for t in sorted(R) if arm(t) == a and '%s_def_r%s' % (w, t[-1]) in R]
    com = {R[t]['committed'] for t in R if t.startswith(w + '_')}
    print('%-12s %8.1f %-24s %-26s %8.2f %8.3f  %s' % (a, st.median([x['rate'] for x in v]), ', '.join('%.1f' % x['rate'] for x in v),
          '%.3f (%s)' % (st.median(pr), ', '.join('%.3f' % y for y in pr)) if not a.endswith('_def') else '1.000',
          st.median([lost2(x['p']) for x in v]), max(x['gap'] for x in v), len(com) == 1))
print('\n== 2. Per run, per 0.25 s from the clock start: sim k/s | per s summed over nodes, thousands: ' + ', '.join(K))
for t in sorted(R):
    x = R[t]; U = x['U']
    print('-- %s (%.1f M ev/s)' % (t, x['rate']))
    k0 = -20 if 'delay' in t else 2
    for k in range(k0, 14):
        a, b = 0.25 * k, 0.25 * k + 0.25
        s = sim(x['p'], a, b) if a >= 0 else 0.0
        print('   %5.2f %6.0f | %s' % (a, s, ' '.join('%9.2f' % (rate(kk, U + a, U + b) / 1e3) for kk in K)))
print('\n== 3. Burst window 1.5-2.25 s ÷ 0.75-1.5 s (TLB, numa_pte_updates, numa_hint_faults), and the dip: sim 1.5-2.0 ÷ 1.0-1.5')
for t in sorted(R):
    x = R[t]; U = x['U']
    rr = []
    for kk in ('TLB', 'numa_pte_updates', 'numa_hint_faults'):
        a, b = rate(kk, U + 1.5, U + 2.25), rate(kk, U + 0.75, U + 1.5)
        rr.append('%s %8.3g / %-8.3g (%5.1fx)' % (kk[:9], a, b, a / b if b else float('inf')))
    print('   %-14s %s | dip %.2f' % (t, '  '.join(rr), sim(x['p'], 1.5, 2.0) / sim(x['p'], 1.0, 1.5)))
for w in ('g100', 'g2000', 'uni'):
    dd = [rate('numa_pte_updates', R[t]['U'], R[t]['U'] + R[t]['p'][-1][0]) for t in R if t.startswith(w + '_def')]
    for a in ('numa', 'bind'):
        nn = [rate('numa_pte_updates', R[t]['U'], R[t]['U'] + R[t]['p'][-1][0]) for t in R if t.startswith('%s_%s' % (w, a))]
        if dd and nn: print('   %s numa_pte_updates/s over the run: default %s; %s %s; ratio %.4f' % (w, ', '.join('%.3g' % v for v in dd), a, ', '.join('%.3g' % v for v in nn), st.median(nn) / st.median(dd) if st.median(dd) else float('nan')))
print('\n== 4. N6: NUMA hinting faults and migrations per run, from 3 s before the clock to the end (summed over nodes)')
print('   %-14s %12s %8s %12s %12s' % ('run', 'hint faults', 'local', 'migrated', 'pte updates'))
for t in sorted(R):
    U, T = R[t]['U'], R[t]['p'][-1][0]
    tot = lambda k: rate(k, U - 3, U + T) * (T + 3)
    hf, hl = tot('numa_hint_faults'), tot('numa_hint_faults_local')
    print('   %-14s %12.0f %7.1f%% %12.0f %12.0f' % (t, hf, 100 * hl / hf if hf else float('nan'), tot('numa_pages_migrated'), tot('numa_pte_updates')))
