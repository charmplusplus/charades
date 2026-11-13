#!/usr/bin/env python3
"""Job UL (charades results/aggregation.md section 277, results in 278): padded
local 1 (PP 512, --agg-pp-local=1 --agg-pp-pad=1, charades-r6) against the
table's setting on F1's binary (charades-r5) on uniform PHOLD at 1-64 nodes.
M committed ev/s, medians of reps; ratios named, higher is better for the first
named. A run without count waves ran on the engine defaults (section 263) and
is dropped. Usage: ul_278.py <job dir> [<job dir> ...]  (small, n32, n64)"""
import csv, glob, os, re, statistics as st, sys, collections
NODES = [1, 2, 4, 8, 16, 32, 64]
REFAGG = {1: 'wps:512', 2: 'pp:512', 4: 'pp:512', 8: 'pp:512', 16: 'wps:512', 32: 'wps:512', 64: 'wps:512'}
TABLE = {1: 45.9, 2: 79.3, 4: 151.9, 8: 229.0, 16: 384.5, 32: 627.8, 64: 980.0}      # F1 / R8 / P64, controller
TABLE_EPM = {1: 74.8, 2: 104.6, 4: 101.9, 8: 36.7, 16: 12.6, 32: 8.3, 64: 5.6}
DEVA = {1: 29.2, 2: 39.1, 4: 67.5, 8: 115.4, 16: 191.0, 32: 312.4, 64: 489.3}        # Devastator best W
ROSS = {1: 9.4, 2: 13.8, 4: 25.5, 8: 46.8, 16: 90.9, 32: 162.4, 64: 295.2}
COUNT = {1: '180941384', 2: '361891305', 4: '723815947', 8: '1447683514', 16: '2895361579', 32: '5790767104', 64: '11581457663'}
PRED = {1: (0.90, 1.02), 2: (0.93, 1.05), 4: (0.93, 1.05), 8: (0.98, 1.15), 16: (1.03, 1.20), 32: (1.20, 1.40), 64: (1.40, 1.60)}
EPM_PRED = {16: (80, 130), 32: (45, 80), 64: (33, 42)}
NEW = 'pp:512:l1:p1'

def logpad(path):
    for line in open(path, errors='replace'):
        m = re.search(r'\(--agg-pp-pad=(\d)\)', line)
        if m and line.startswith('Aggregation:'): return int(m.group(1))
    return 0

runs = collections.defaultdict(list); counts = collections.defaultdict(set); bad = []; dropped = []; probes = []
for J in sys.argv[1:]:
    for f in sorted(glob.glob(os.path.join(J, 'n*', '*.csv'))):
        n = int(os.path.basename(os.path.dirname(f))[1:]); tag = os.path.basename(f)[:-4]
        if tag.startswith('warm'): continue
        for r in csv.DictReader(open(f)):
            if r['status'] != 'ok': bad.append((n, tag, r['arm'], r['status'])); continue
            if not (r.get('count_waves') or '0').strip('0.'): dropped.append((n, tag, r['arm'])); continue
            rate = float(r['event_rate']) / 1e6
            if tag.startswith('probe'): probes.append((n, rate)); continue
            setting = 'ref' if tag.startswith('uni_ref_') else 'new'
            label = 'r%s_n%d_%s_%s_b8_m8_%s' % (r['rep'], n, r['workload'].replace(':', '_'), r['agg'].replace(':', ''), r['arm'].replace(':', ''))
            lp = os.path.join(os.path.dirname(f), tag, 'ctl_sweep', 'logs', label + '.out')
            if not os.path.exists(lp): bad.append((n, tag, r['arm'], 'no log')); continue
            pad = logpad(lp)
            if pad != (1 if setting == 'new' else 0): bad.append((n, tag, r['arm'], 'log says pad %d' % pad))
            if setting == 'ref' and r['agg'] != REFAGG[n]: bad.append((n, tag, 'reference ran %s' % r['agg']))
            com = int(r['committed'])
            runs[(n, setting, r['arm'])].append(dict(rep=int(tag.rsplit('_r', 1)[1]), rate=rate, epm=float(r['agg_events_per_msg'] or 0),
                eff=float(r['efficiency']), mw=float(r['mean_window'] or 0), rb=int(r['rolled_back']) / com))
            counts[n].add(r['committed'])

med = lambda v, k='rate': st.median(x[k] for x in v)
sp = lambda v: max(x['rate'] for x in v) / min(x['rate'] for x in v)
inr = lambda x, lo, hi: 'yes' if lo <= x <= hi else 'NO'
print('runs kept: %d; dropped without count waves: %d; failed/missing log/pad or setting mismatch: %d' % (sum(map(len, runs.values())), len(dropped), len(bad)))
for b in bad + dropped: print('  ', b)
for n, r in probes: print('probe at %d nodes: %.1f M ev/s (F1 WPs 512 W 400: %s)' % (n, r, {16: 383.3, 32: 639.5, 64: 998.9}.get(n)))
have = [n for n in NODES if runs.get((n, 'new', 'mb:0'))]

print('\n# Counts (one per node count; F1 in brackets)')
for n in have: print('  %2d nodes %s [%s] %s' % (n, sorted(counts[n]), COUNT[n], 'SAME' if counts[n] == {COUNT[n]} else 'DIFFER'))

print('\n# Rates (M committed ev/s, median; spread = fastest / slowest rep), events per htram message, lowest efficiency %, controller mean W')
for n in have:
    for (s, arm), v in sorted(((k[1], k[2]), v) for k, v in runs.items() if k[0] == n):
        print('  %2d %-4s %-10s %-5s %8.1f  %.2f  ev/msg %6.1f  eff %.3f  W %5.0f' % (n, s, REFAGG[n] if s == 'ref' else 'local 1 pad 1', arm,
              med(v), sp(v), med(v, 'epm'), min(x['eff'] for x in v), med(v, 'mw')))

print('\n# Checks and ratios (controller medians unless named; higher is better for the first named)')
print('  nodes | ref / table (UL-2 ±5%) | local 1 / ref: medians, paired median [UL-3 range] | ctl / best fixed (UL-5) | local 1 ev/msg (UL-4) | local 1 ctl spread')
for n in have:
    ref = runs.get((n, 'ref', 'mb:0'), []); new = runs[(n, 'new', 'mb:0')]
    rr = med(ref) / TABLE[n] if ref else float('nan')
    ratio = med(new) / med(ref) if ref else float('nan')
    rp = {x['rep']: x['rate'] for x in ref}
    pr = [x['rate'] / rp[x['rep']] for x in new if x['rep'] in rp]
    fixed = {a: med(v) for (m, s, a), v in runs.items() if m == n and s == 'new' and a != 'mb:0'}
    bw = max(fixed, key=fixed.get) if fixed else None
    lo, hi = PRED[n]; e = med(new, 'epm')
    print('  %5d | %.3f %-3s | %.3f, paired %.3f (%s) [%.2f-%.2f %s] | %.3f of %s (%s) | %.1f%s | %.2f' % (
        n, rr, inr(rr, 0.95, 1.05), ratio, st.median(pr) if pr else float('nan'), ' '.join('%.3f' % x for x in pr), lo, hi,
        inr(st.median(pr), lo, hi) if pr else '-', med(new) / fixed[bw] if bw else float('nan'), bw, inr(med(new) / fixed[bw], 0.93, 1.03) if bw else '-',
        e, ' [%d-%d %s]' % (EPM_PRED[n] + (inr(e, *EPM_PRED[n]),)) if n in EPM_PRED else '', sp(new)))

print('\n# The table\'s uniform cell (section 277: local 1 replaces F1\'s value where its controller median is higher, if the reference passed UL-2)')
print('  nodes | F1 cell (M ev/s) | local 1 ctl | ref ok | cell | Charades / Devastator (old -> new) | Charades / ROSS (old -> new)')
cell = {}
for n in NODES:
    new = runs.get((n, 'new', 'mb:0')); ref = runs.get((n, 'ref', 'mb:0'))
    ok = bool(ref) and 0.95 <= med(ref) / TABLE[n] <= 1.05
    v = med(new) if new else None
    use = v is not None and ok and v > TABLE[n]
    cell[n] = v if use else TABLE[n]
    print('  %5d | %7.1f | %s | %s | %s %.1f | %.2f -> %.2f | %.2f -> %.2f' % (n, TABLE[n], '%7.1f' % v if v else '   -   ', 'yes' if ok else 'NO ',
          'local 1' if use else 'F1     ', cell[n], TABLE[n] / DEVA[n], cell[n] / DEVA[n], TABLE[n] / ROSS[n], cell[n] / ROSS[n]))
pn = lambda c, a, b: (c[b] / b) / (c[a] / a)
print('  per-node rate 16->32 %.2f, 32->64 %.2f, 1->64 %.2f (old 0.82, 0.78, 0.33; Devastator 0.82, 0.78, 0.26; ROSS 0.89, 0.91, 0.49)' % (
    pn(cell, 16, 32), pn(cell, 32, 64), pn(cell, 1, 64)))
