#!/usr/bin/env python3
"""Job AG32 (charades results/aggregation.md sections 256-257): Charades only,
32 nodes, 5 reps. Part A: uniform and sigma 4,000 x {direct, PP 512, PP 2,048,
WPs 512, WPs 2,048} x {W 300-600, controller}. Part B: fixed windows past F1's
and F5's grids. Rates are M committed ev/s, medians of reps (higher is better);
spread = fastest rep / slowest rep. F1-32 (scale240/big_j3688916) and F5-32b
(scale240/f5big_j3690451) give the earlier 32-node arms for comparison."""
import csv, glob, os, re, statistics as st
from collections import defaultdict
H = os.path.expanduser('~/charades-data/f1/')
AG = H + 'ag32_256/j3692756/n32/'
F1 = H + 'scale240/big_j3688916/n32/'
F5 = H + 'scale240/f5big_j3690451/n32/'

def load(d, skip=('warm',)):
    r = defaultdict(list)   # (cell, arm) -> rows; each CSV holds one rep (its rep column is always 1)
    for f in sorted(glob.glob(d + '*.csv')):
        m = re.match(r'(.*)_r(\d+)\.csv$', os.path.basename(f))
        if not m or m.group(1).startswith(skip): continue
        for x in csv.DictReader(open(f)):
            x['rep'] = m.group(2); r[(m.group(1), x['arm'])].append(x)
    return r
ag, f1, f5 = load(AG), load(F1), load(F5)

def rate(rows): return st.median(float(x['event_rate']) / 1e6 for x in rows)
def spread(rows):
    v = sorted(float(x['event_rate']) for x in rows); return v[-1] / v[0], v[-1] / v[1]
def epm(rows):
    v = [float(x['htram_events']) / float(x['htram_msgs']) for x in rows if x['htram_msgs'] not in ('', '0')]
    return st.median(v) if v else float('nan')
def mw(rows): return st.median(float(x['mean_window']) for x in rows)
ARMS = ['w:300', 'w:400', 'w:500', 'w:600', 'mb:0']
AGGS = ['off', 'pp512', 'pp2048', 'wps512', 'wps2048']
lab = lambda a: 'ctl' if a == 'mb:0' else 'W ' + a[2:]

# AG-1: committed counts
print('AG-1. Committed counts (distinct values per workload; F1/F5 32-node count):')
wlof = lambda cell: cell.split('_')[0]
cnt = defaultdict(set)
for (cell, arm), rows in ag.items():
    st_ = {x['status'] for x in rows}
    assert st_ == {'ok'}, (cell, arm, st_)
    for x in rows: cnt[wlof(cell)].add(int(x['committed']))
ref = defaultdict(set)
for (cell, arm), rows in list(f1.items()) + [(k, v) for k, v in f5.items() if k[0].startswith('tr_')]:
    for x in rows: ref[wlof(cell)].add(int(x['committed']))
for wl in sorted(cnt):
    print('  %-9s %s  ref %s  %s' % (wl, sorted(cnt[wl]), sorted(ref[wl]), 'equal' if cnt[wl] == ref[wl] else 'DIFFERENT'))
nruns = sum(len(v) for v in ag.values()); print('  runs (without warm-up): %d' % nruns)

# Part A
print('\nPart A (M committed ev/s, median of 5; spread = fastest/slowest rep; epm = htram events per message, median):')
for wl in ('uni', 'g4000'):
    print('\n  %s' % wl)
    print('  %-8s | %s' % ('agg', ' | '.join('%-24s' % lab(a) for a in ARMS)))
    best = {}
    for g in AGGS:
        cells = []
        for a in ARMS:
            rows = ag[('%s_%s' % (wl, g), a)]
            cells.append('%6.1f s%.2f e%5.1f%s' % (rate(rows), spread(rows)[0], epm(rows), (' w%3.0f' % mw(rows)) if a == 'mb:0' else ''))
            best.setdefault(g, []).append((rate(rows), a))
        print('  %-8s | %s' % (g, ' | '.join('%-24s' % c for c in cells)))
    bd = max(best['off']); bh = max(max(v) + (g,) for g, v in best.items() if g != 'off')
    print('  AG-2 best htram %s %s %.1f / best direct %s %.1f = %.2f' % (bh[2], lab(bh[1]), bh[0], lab(bd[1]), bd[0], bh[0] / bd[0]))
    bfix = {g: max((r, a) for r, a in v if a != 'mb:0') for g, v in best.items()}
    print('  AG-4 best fixed W per agg:', '  '.join('%s %s (%.1f)' % (g, lab(bfix[g][1]), bfix[g][0]) for g in AGGS))
    print('  AG-6 ctl / best fixed per agg:', '  '.join('%s %.3f' % (g, dict((a, r) for r, a in best[g])['mb:0'] / bfix[g][0]) for g in AGGS))
    bp = max(max(best['pp512']), max(best['pp2048'])); bw = max(max(best['wps512']), max(best['wps2048']))
    print('  AG-3 best PP %.1f / best WPs %.1f = %.3f' % (bp[0], bw[0], bp[0] / bw[0]))
    for m in ('pp', 'wps'):
        print('  AG-3 %s epm 2048/512 by arm:' % m, '  '.join('%s %.2f' % (lab(a), epm(ag[('%s_%s2048' % (wl, m), a)]) / epm(ag[('%s_%s512' % (wl, m), a)])) for a in ARMS))
    for g in AGGS[1:]:
        print('  AG-3 %s epm W600/W300 %.2f' % (g, epm(ag[('%s_%s' % (wl, g), 'w:600')]) / epm(ag[('%s_%s' % (wl, g), 'w:300')])))
    # F1-32 for the same cells
    for g in ('pp512', 'wps512'):
        if ('%s_%s' % (wl, g), 'mb:0') in f1:
            print('  F1-32 %s: %s' % (g, '  '.join('%s %.1f e%.1f' % (lab(a), rate(f1[('%s_%s' % (wl, g), a)]), epm(f1[('%s_%s' % (wl, g), a)])) for a in ('w:300', 'w:400', 'mb:0'))))

# Part B
print('\nPart B (M committed ev/s, median of 5; spread; mean controller W). F1/F5 32-node arms in brackets:')
PB = [('g100_pp2048', ['w:400', 'w:500', 'w:600']), ('g500_pp2048', ['w:400', 'w:500', 'w:600']),
      ('g1000_pp2048', ['w:400', 'w:500', 'w:600']), ('g2000_pp512', ['w:400', 'w:500', 'w:600']),
      ('l10g500_pp2048', ['w:50', 'w:75', 'w:100', 'w:150']), ('l10g2000_wps512', ['w:50', 'w:75', 'w:100']),
      ('tr_pp2048', ['w:1000', 'w:1500', 'w:2000'])]
for cell, ws in PB:
    old = f5 if cell.startswith('tr') else f1
    oarms = sorted({a for (c, a) in old if c == cell}, key=lambda a: (a == 'mb:0', float(a[2:]) if a != 'mb:0' else 0))
    vals = {a: rate(ag[(cell, a)]) for a in ws + ['mb:0']}
    fixed = {a: v for a, v in vals.items() if a != 'mb:0'}
    bfa = max(fixed, key=fixed.get)
    s = '  '.join('%s %.1f s%.2f' % (lab(a), vals[a], spread(ag[(cell, a)])[0]) for a in ws)
    s += '  ctl %.1f s%.2f w%.0f' % (vals['mb:0'], spread(ag[(cell, 'mb:0')])[0], mw(ag[(cell, 'mb:0')]))
    o = '  '.join('%s %.1f' % (lab(a), rate(old[(cell, a)])) for a in oarms)
    print('  %-16s %s  [%s]' % (cell, s, o))
    # widened grid: this job's fixed arms plus the earlier job's narrower arms (cross-job, noisier)
    ofix = {a: rate(old[(cell, a)]) for a in oarms if a != 'mb:0' and a not in fixed}
    print('  %-16s best fixed (this job) %s %.1f; ctl / that %.3f; W/W ratios: %s; ctl(this)/ctl(old) %.3f; W400or1000(this)/(old) %s; ctl / best fixed incl. old arms %.3f' % (
        '', lab(bfa), fixed[bfa], vals['mb:0'] / fixed[bfa],
        '  '.join('%s/%s %.3f' % (lab(ws[i + 1]), lab(ws[i]), fixed[ws[i + 1]] / fixed[ws[i]]) for i in range(len(ws) - 1)),
        vals['mb:0'] / rate(old[(cell, 'mb:0')]),
        '%.3f' % (fixed[ws[0]] / rate(old[(cell, ws[0])])) if (cell, ws[0]) in old else '-',
        vals['mb:0'] / max(list(fixed.values()) + list(ofix.values()))))

# AG-7: spread
print('\nAG-7. Spread (fastest/slowest rep) per arm; second number drops the slowest rep:')
bad = [(c, a, *spread(r)) for (c, a), r in sorted(ag.items()) if spread(r)[0] > 1.15]
print('  arms over 1.15: %d of %d' % (len(bad), len(ag)))
for c, a, s0, s1 in bad: print('   %-16s %-7s %.2f  %.2f%s' % (c, a, s0, s1, '  (over 1.15 without the slowest)' if s1 > 1.15 else ''))
sp = sorted(spread(r)[0] for r in ag.values()); print('  median spread %.3f, max %.2f' % (st.median(sp), sp[-1]))
# slow reps by rep number
slow = defaultdict(int)
for (c, a), rows in ag.items():
    v = sorted(rows, key=lambda x: float(x['event_rate']))
    if float(v[1]['event_rate']) / float(v[0]['event_rate']) > 1.10: slow[v[0]['rep']] += 1
print('  arms whose slowest rep is >10%% below the next, by rep: %s' % dict(sorted(slow.items())))
low = defaultdict(int)
for (c, a), rows in ag.items():
    m = st.median(float(x['event_rate']) for x in rows)
    for x in rows:
        if float(x['event_rate']) < 0.9 * m: low[x['rep']] += 1
print('  runs below 0.9 of their arm median, by rep: %s' % dict(sorted(low.items())))

# matched arms against F1-32 / F5-32b (between-job agreement)
print('\nMatched arms, this job / F1-32 or F5-32b (medians):')
mr = []
for (c, a), rows in sorted(ag.items()):
    old = f5 if c.startswith('tr') else f1
    if (c, a) in old: mr.append((rate(rows) / rate(old[(c, a)]), c, a))
for v, c, a in mr: print('  %-16s %-7s %.3f' % (c, lab(a), v))
print('  range %.3f-%.3f; without the lookahead 10 sigma 500 controller %.3f-%.3f' % (min(mr)[0], max(mr)[0],
      min(v for v, c, a in mr if (c, a) != ('l10g500_pp2048', 'mb:0')), max(v for v, c, a in mr if (c, a) != ('l10g500_pp2048', 'mb:0'))))

# controller (F1-32 / F5-32b) / best fixed over both jobs' grids
print('\nF1-32 / F5-32b controller / best fixed W over both grids (cross-job where the best is an AG32 arm):')
for cell in [c for c, _ in PB] + ['uni_wps512', 'g4000_pp512']:
    old = f5 if cell.startswith('tr') else f1
    fx = {('old', a): rate(r) for (c, a), r in old.items() if c == cell and a != 'mb:0'}
    fx.update({('new', a): rate(r) for (c, a), r in ag.items() if c == cell and a != 'mb:0'})
    b = max(fx, key=fx.get)
    print('  %-16s ctl %.1f / %s %s %.1f = %.3f' % (cell, rate(old[(cell, 'mb:0')]), b[0], lab(b[1]), fx[b], rate(old[(cell, 'mb:0')]) / fx[b]))

# window ratios within this job, the paper settings
print('\nW ratios within this job (paper settings):')
for cell, ws in [('uni_wps512', ARMS[:4]), ('g4000_pp512', ARMS[:4])] + PB:
    v = {a: rate(ag[(cell, a)]) for a in ws}; b = max(v, key=v.get)
    print('  %-16s best %s; each W / best: %s' % (cell, lab(b), '  '.join('%s %.3f' % (lab(a), v[a] / v[b]) for a in ws)))
