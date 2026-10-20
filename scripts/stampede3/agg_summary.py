#!/usr/bin/env python3
"""Summarize agg_sweep.sh CSVs: one row per (nodes, remote fraction, PHOLD
lookahead:mean, GVT setup, aggregation config) with medians over the runs
that finished -- committed events/s and its ratio to the direct
(unaggregated) runs of the same case, efficiency, events per htram message,
the share of htram messages each flush cause sent (full buffer, urgent event,
idle PE, GVT update, blocking GVT round), remote stragglers and median slack
-- and how many runs stalled or failed. Reads CSVs from before the policy,
slack and flush-cause columns existed (those show as '-').

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


def agg_label(r):
    if r['agg_mode'] == 'off':
        return 'direct'
    if r.get('agg_policy', 'eager') == 'deadline':
        return '%s b=%s dl h=%s' % (r['agg_mode'], r['agg_buffer'], r['agg_horizon'])
    return '%s b=%s u=%s' % (r['agg_mode'], r['agg_buffer'], r['agg_urgent'])


rows = defaultdict(list)
for path in sys.argv[1:]:
    with open(path) as f:
        for r in csv.DictReader(f):
            setup = r['gvt'] if r['window'] == '0' else '%s w=%s' % (r['gvt'], r['window'])
            slack = '%s:%s' % (r.get('lookahead', '100'), r.get('mean', '1000'))
            rows[(int(r['nodes']), float(r['remote']), slack, setup, agg_label(r))].append(r)

MODE_ORDER = {'direct': 0, 'wps': 1, 'wsp': 2, 'pp': 3, 'ww': 4}


def order(key):
    nodes, remote, slack, setup, agg = key
    parts = agg.split()
    buf = int(parts[1][2:]) if len(parts) > 1 else 0
    pol = 1 if 'dl' in parts else 0
    knob = int(parts[-1].split('=')[1]) if len(parts) > 2 else 0
    return (nodes, remote, slack, setup, MODE_ORDER.get(parts[0], 9), buf, pol, knob)


rate_of = {k: med([num(r['event_rate']) for r in rs if r['status'] == 'ok'])
           for k, rs in rows.items()}
CAUSES = [('msgs_full', 'full'), ('msgs_urgent', 'urg'), ('msgs_idle', 'idle'),
          ('msgs_gvt', 'gvt'), ('msgs_round', 'rnd')]


def causes(ok):
    tot = [sum(num(r.get(c)) or 0 for c, _ in CAUSES) for r in ok]
    if not ok or not any(tot):
        return '-'
    shares = []
    for c, name in CAUSES:
        v = med([(num(r.get(c)) or 0) / t for r, t in zip(ok, tot) if t])
        if v and v >= 0.01:
            shares.append('%s %.0f%%' % (name, 100 * v))
    return ' '.join(shares)


print('%5s %6s %8s %-12s %-22s %2s %2s %2s %8s %6s %5s %6s %6s %6s  %s' % (
    'nodes', 'remote', 'la:mean', 'gvt', 'aggregation', 'ok', 'st', 'fl',
    'Mev/s', 'vs dir', 'eff%', 'ev/msg', 'strag%', 'slk50', 'messages by cause'))
last = None
for key in sorted(rows, key=order):
    rs = rows[key]
    ok = [r for r in rs if r['status'] == 'ok']
    if last is not None and key[:4] != last:
        print()
    last = key[:4]
    rate = rate_of[key]
    direct = rate_of.get(key[:4] + ('direct',))
    print('%5d %6g %8s %-12s %-22s %2d %2d %2d %8s %6s %5s %6s %6s %6s  %s' % (
        key[0], key[1], key[2], key[3], key[4], len(ok),
        sum(r['status'] == 'stall' for r in rs),
        sum(r['status'] == 'fail' for r in rs),
        fmt(rate / 1e6 if rate else None, '.3f'),
        fmt(rate / direct if rate and direct else None, '.2f'),
        fmt(med([num(r['efficiency']) for r in ok]), '.1f'),
        fmt(med([num(r['agg_events_per_msg']) for r in ok]), '.1f'),
        fmt(med([num(r.get('stragglers_pct')) for r in ok]), '.1f'),
        fmt(med([num(r.get('slack_p50')) for r in ok]), '.0f'),
        causes(ok)))
