#!/usr/bin/env python3
"""Summarize ctl_sweep.sh CSVs: one row per (nodes, workload, transport, arm)
with medians over the runs that finished -- committed events/s and its ratio
to the best fixed window of the same case, efficiency, the window (fixed, or
the controller's time-weighted mean), stragglers per executed event and the
calibration alpha -- and how many runs stalled or failed.

Usage: ctl_summary.py sweep.csv [more.csv ...]
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


def fmt(v, spec):
    return format(v, spec) if v is not None else '-'


rows = defaultdict(list)
for path in sys.argv[1:]:
    with open(path) as f:
        for r in csv.DictReader(f):
            rows[(int(r['nodes']), r['workload'], r['agg'], r['arm'])].append(r)

ARM_ORDER = {'w': 0, 'qb': 1, 'q': 2, 'hill': 3}


def order(key):
    kind, val = key[3].split(':')
    return key[:3] + (ARM_ORDER.get(kind, 9), float(val))


rate = {k: med([num(r['event_rate']) for r in rs if r['status'] == 'ok'])
        for k, rs in rows.items()}
best_fixed = {}
for k, v in rate.items():
    if k[3].startswith('w:') and v:
        best_fixed[k[:3]] = max(best_fixed.get(k[:3], 0), v)

print('%5s %-34s %-6s %-10s %2s %2s %2s %8s %7s %5s %8s %8s %6s' % (
    'nodes', 'workload', 'agg', 'arm', 'ok', 'st', 'fl', 'Mev/s', 'vs best',
    'eff%', 'window', 'strag/ev', 'alpha'))
last = None
for key in sorted(rows, key=order):
    rs = rows[key]
    ok = [r for r in rs if r['status'] == 'ok']
    if last is not None and key[:3] != last:
        print()
    last = key[:3]
    v, b = rate[key], best_fixed.get(key[:3])
    print('%5d %-34s %-6s %-10s %2d %2d %2d %8s %7s %5s %8s %8s %6s' % (
        key[0], key[1], key[2], key[3], len(ok),
        sum(r['status'] == 'stall' for r in rs),
        sum(r['status'] == 'fail' for r in rs),
        fmt(v / 1e6 if v else None, '.3f'),
        fmt(v / b if v and b else None, '.2f'),
        fmt(med([num(r['efficiency']) for r in ok]), '.1f'),
        fmt(med([num(r['mean_window']) for r in ok]), '.0f'),
        fmt(med([num(r['stragglers_per_event']) for r in ok]), '.4f'),
        fmt(med([num(r['alpha']) for r in ok]), '.3f')))
