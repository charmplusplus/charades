#!/usr/bin/env python3
"""Per-transport policy summary of ctl_sweep.sh CSVs (companion to
gauss_summary.py):

1. Each arm's median committed-event rate ÷ the best fixed window (w:*) in the
   same workload and transport (higher is better), with the worst case per
   arm over all workloads.
2. Rollback cost: PE time per committed event at the best fixed W, and PE
   time per extra rolled-back event for each fixed-W or controller arm that
   rolls back more than that W (Δ(exec_s × PEs) ÷ Δrolled_back, medians),
   and their ratio.

Usage: policy_summary.py sweep.csv [more.csv ...]
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

cell = {}
for k, rs in runs.items():
    ok = [r for r in rs if r['status'] == 'ok']
    cell[k] = dict(
        rate=med([num(r['event_rate']) / 1e6 for r in ok if num(r['event_rate'])]),
        pe_s=med([num(r['exec_s']) * num(r['pes']) for r in ok]),
        rb=med([num(r['rolled_back']) for r in ok]),
        com=med([num(r['committed']) for r in ok]),
        n=len(ok), bad=len(rs) - len(ok))


def wl_key(wl):
    p = wl.split(':')
    return (p[0] != 'gauss', [float(x) for x in p[1:]])


def arm_key(arm):
    order = {'blk': 0, 'w': 1, 'q': 2, 'hill': 3}
    kind, val = arm.split(':')
    return (order.get(kind, 9), float(val))


workloads = sorted({k[0] for k in cell}, key=wl_key)
aggs = sorted({k[1] for k in cell}, key=lambda a: a != 'off')

for a in aggs:
    arms = sorted({k[2] for k in cell if k[1] == a}, key=arm_key)
    print('\n%s: rate ÷ best fixed W in the same workload (median rates; '
          'higher is better; "x" = no ok run)' % a)
    print('%-22s %-7s' % ('workload', 'best W') + ''.join('%10s' % x for x in arms))
    worst = defaultdict(lambda: None)
    for wl in workloads:
        fixed = [(cell[(wl, a, x)]['rate'], x) for x in arms
                 if x.startswith('w:') and (wl, a, x) in cell and cell[(wl, a, x)]['rate']]
        if not fixed:
            continue
        best, bw = max(fixed)
        row = '%-22s %-7s' % (wl, bw)
        for x in arms:
            c = cell.get((wl, a, x))
            if c is None:
                row += '%10s' % '-'
                continue
            r = c['rate'] / best if c['rate'] else 0.0
            row += '%10s' % ('x' if not c['rate'] else '%.2f' % r)
            worst[x] = r if worst[x] is None else min(worst[x], r)
        print(row)
    print('%-30s' % 'worst case' + ''.join(
        '%10s' % ('-' if worst[x] is None else '%.2f' % worst[x]) for x in arms))

    print('\n%s: rollback cost (PE µs per event; ratio = per extra rolled-back '
          '÷ per committed at the best fixed W)' % a)
    for wl in workloads:
        fixed = [(cell[(wl, a, x)]['rate'], x) for x in arms
                 if x.startswith('w:') and (wl, a, x) in cell and cell[(wl, a, x)]['rate']]
        if not fixed:
            continue
        _, bw = max(fixed)
        b = cell[(wl, a, bw)]
        per_com = b['pe_s'] / b['com'] * 1e6
        parts = []
        for x in arms:
            c = cell.get((wl, a, x))
            # Only arms that differ from the best W in optimism alone; blocking
            # GVT and the hill climb add synchronisation and window swings
            if x == bw or x.split(':')[0] not in ('w', 'q') or not c or \
                    not c['rate'] or c['rb'] is None:
                continue
            drb = c['rb'] - b['rb']
            if drb < 0.002 * b['com']:  # too few extra rollbacks to measure
                continue
            per_rb = (c['pe_s'] - b['pe_s']) / drb * 1e6
            parts.append('%s %.0f (%.1f×)' % (x, per_rb, per_rb / per_com))
        print('  %-22s committed %.1f µs at %s; %s' % (
            wl, per_com, bw, '; '.join(parts) if parts else 'no arm with enough extra rollbacks'))
