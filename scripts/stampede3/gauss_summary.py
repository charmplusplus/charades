#!/usr/bin/env python3
"""Cross-transport summary of ctl_sweep.sh CSVs (e.g. the Gaussian sweep):
per workload, the median committed-event rate of every (transport, arm),
its ratio to the best arm of any transport, the best direct and best htram
arm and their ratio (the aggregation gain), and efficiency and mean window.
Rates are M committed events/s, higher is better.

Usage: gauss_summary.py sweep.csv [more.csv ...]
"""
import csv
import statistics
import sys
from collections import defaultdict


def num(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return None


def med(vals):
    vals = [v for v in vals if v is not None]
    return statistics.median(vals) if vals else None


runs = defaultdict(list)
for path in sys.argv[1:]:
    with open(path) as f:
        for r in csv.DictReader(f):
            runs[(r['workload'], r['agg'], r['arm'])].append(r)

ARM_ORDER = {'blk': 0, 'w': 1, 'hill': 2, 'hill1': 3, 'q': 4}


def arm_key(arm):
    kind, val = arm.split(':')
    return (ARM_ORDER.get(kind, 9), float(val))


def wl_key(wl):
    parts = wl.split(':')
    return (parts[0] != 'gauss', [float(p) for p in parts[1:]])


cell = {}
for k, rs in runs.items():
    ok = [r for r in rs if r['status'] == 'ok']
    rates = [num(r['event_rate']) for r in ok]
    rates = [v / 1e6 for v in rates if v]
    cell[k] = dict(
        rate=med(rates), lo=min(rates) if rates else None,
        hi=max(rates) if rates else None, n=len(ok), bad=len(rs) - len(ok),
        eff=med([num(r['efficiency']) for r in ok]),
        win=med([num(r['mean_window']) for r in ok]),
        epm=med([num(r['agg_events_per_msg']) for r in ok]))

workloads = sorted({k[0] for k in cell}, key=wl_key)
aggs = sorted({k[1] for k in cell}, key=lambda a: a != 'off')
arms = sorted({k[2] for k in cell}, key=arm_key)

print('Best arm per transport (M committed events/s, median; higher is better)')
print('%-24s %-10s %8s  %-10s %8s  %s' % ('workload', 'direct', 'Mev/s',
                                          'htram', 'Mev/s', 'htram ÷ direct'))
for wl in workloads:
    best = {}
    for a in aggs:
        c = [(cell[(wl, a, arm)]['rate'], arm) for arm in arms
             if (wl, a, arm) in cell and cell[(wl, a, arm)]['rate']]
        best[a] = max(c) if c else (None, '-')
    d, h = best.get('off', (None, '-')), [best[a] for a in aggs if a != 'off']
    h = h[0] if h else (None, '-')
    print('%-24s %-10s %8s  %-10s %8s  %s' % (
        wl, d[1], '%.2f' % d[0] if d[0] else '-', h[1],
        '%.2f' % h[0] if h[0] else '-',
        '%.2f' % (h[0] / d[0]) if d[0] and h[0] else '-'))

for a in aggs:
    print('\n%s: M committed events/s (median; ÷ best arm of any transport '
          'in parentheses; higher is better)' % a)
    print('%-24s' % 'workload' + ''.join('%17s' % arm for arm in arms))
    for wl in workloads:
        top = max(c['rate'] for k, c in cell.items() if k[0] == wl and c['rate'])
        row = '%-24s' % wl
        for arm in arms:
            c = cell.get((wl, a, arm))
            if not c or not c['rate']:
                row += '%17s' % ('-' if not c else 'fail %d' % c['bad'])
            else:
                row += '%17s' % ('%.2f (%.2f)%s' % (c['rate'], c['rate'] / top,
                                                   '!' if c['bad'] else ''))
        print(row)
    print('  efficiency (%, committed ÷ executed) / mean window (sim. time) '
          '/ events per htram message (count)')
    for wl in workloads:
        row = '%-24s' % wl
        for arm in arms:
            c = cell.get((wl, a, arm))
            row += '%17s' % ('-' if not c or c['eff'] is None else
                             '%.1f/%s/%s' % (c['eff'],
                                             '%.0f' % c['win'] if c['win'] else '-',
                                             '%.0f' % c['epm'] if c['epm'] else '-'))
        print(row)
    print('  spread (max ÷ min over reps)')
    for wl in workloads:
        row = '%-24s' % wl
        for arm in arms:
            c = cell.get((wl, a, arm))
            row += '%17s' % ('-' if not c or not c['lo'] else
                             '%.2f' % (c['hi'] / c['lo']))
        print(row)
