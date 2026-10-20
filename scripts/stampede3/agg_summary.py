#!/usr/bin/env python3
"""Summarize agg_sweep.sh CSVs: one row per (nodes, remote, GVT setup,
aggregation config) with medians over the runs that finished -- committed
events/s and its ratio to the direct (unaggregated) runs of the same case,
efficiency, events per htram message, mean send-call time and the mean
send-to-receive latency to other nodes -- and how many runs stalled or failed.

Usage: agg_summary.py sweep.csv [more.csv ...]
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
            setup = r['gvt'] if r['window'] == '0' else '%s w=%s' % (r['gvt'], r['window'])
            agg = 'direct' if r['agg_mode'] == 'off' else \
                '%s b=%s u=%s' % (r['agg_mode'], r['agg_buffer'], r['agg_urgent'])
            rows[(int(r['nodes']), float(r['remote']), setup, agg)].append(r)

MODE_ORDER = {'direct': 0, 'wps': 1, 'wsp': 2, 'pp': 3, 'ww': 4}


def order(key):
    nodes, remote, setup, agg = key
    parts = agg.split()
    buf = int(parts[1][2:]) if len(parts) > 1 else 0
    urg = int(parts[2][2:]) if len(parts) > 2 else 0
    return (nodes, remote, setup, MODE_ORDER.get(parts[0], 9), buf, urg)


rate_of = {}
for key, rs in rows.items():
    rate_of[key] = med([num(r['event_rate']) for r in rs if r['status'] == 'ok'])

print('%5s %6s %-14s %-18s %2s %2s %2s %9s %6s %6s %8s %8s %10s' % (
    'nodes', 'remote', 'gvt', 'aggregation', 'ok', 'st', 'fl', 'Mev/s',
    'vs dir', 'eff %', 'ev/msg', 'send us', 'lat oth us'))
last = None
for key in sorted(rows, key=order):
    rs = rows[key]
    ok = [r for r in rs if r['status'] == 'ok']
    if last is not None and key[:3] != last:
        print()
    last = key[:3]
    rate = rate_of[key]
    direct = rate_of.get(key[:3] + ('direct',))
    print('%5d %6g %-14s %-18s %2d %2d %2d %9s %6s %6s %8s %8s %10s' % (
        key[0], key[1], key[2], key[3], len(ok),
        sum(r['status'] == 'stall' for r in rs),
        sum(r['status'] == 'fail' for r in rs),
        fmt(rate / 1e6 if rate else None, '.3f'),
        fmt(rate / direct if rate and direct else None, '.2f'),
        fmt(med([num(r['efficiency']) for r in ok]), '.1f'),
        fmt(med([num(r['agg_events_per_msg']) for r in ok]), '.1f'),
        fmt(med([num(r['send_call_us']) for r in ok]), '.2f'),
        fmt(med([num(r['lat_other_mean_us']) for r in ok]), '.1f')))
