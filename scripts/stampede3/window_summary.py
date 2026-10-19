#!/usr/bin/env python3
"""Summarize window_sweep.sh CSVs: one row per (nodes, sigma, config) with the
median committed-event rate and wall time over the runs that finished, the
median efficiency and rollbacks, and how many runs stalled or failed.

Usage: window_summary.py sweep.csv [more.csv ...]
"""
import csv
import statistics
import sys
from collections import defaultdict


def num(x):
    try:
        return float(x.rstrip('%'))
    except (ValueError, AttributeError):
        return None


rows = defaultdict(list)
for path in sys.argv[1:]:
    with open(path) as f:
        for r in csv.DictReader(f):
            cfg = r['gvt'] if r['gvt'] == 'blocking' or r['window'] == '0' \
                else 'bucket w=%s' % r['window']
            rows[(int(r['nodes']), int(r['sigma']), cfg)].append(r)


def order(key):
    nodes, sigma, cfg = key
    rank = 0 if cfg == 'blocking' else 1 if cfg == 'bucket' else 2
    w = int(cfg.split('=')[1]) if '=' in cfg else 0
    return (nodes, sigma, rank, w)


def med(vals):
    vals = [v for v in vals if v is not None]
    return statistics.median(vals) if vals else None


def fmt(v, spec):
    return format(v, spec) if v is not None else '-'


print('%5s %6s %-14s %3s %5s %4s %11s %8s %7s %11s' % (
    'nodes', 'sigma', 'config', 'ok', 'stall', 'fail', 'rate (ev/s)',
    'wall s', 'eff %', 'rolled back'))
last = None
for key in sorted(rows, key=order):
    rs = rows[key]
    ok = [r for r in rs if r['status'] == 'ok']
    stall = sum(r['status'] == 'stall' for r in rs)
    fail = sum(r['status'] == 'fail' for r in rs)
    if last is not None and key[:2] != last:
        print()
    last = key[:2]
    rate = med([num(r['event_rate']) for r in ok])
    if rate is None:  # fall back to committed / execution time
        rate = med([num(r['committed']) / num(r['exec_s'])
                    for r in ok if num(r['exec_s'])])
    print('%5d %6d %-14s %3d %5d %4d %11s %8s %7s %11s' % (
        key[0], key[1], key[2], len(ok), stall, fail,
        fmt(rate, '.3g'), fmt(med([num(r['wall_s']) for r in ok]), '.2f'),
        fmt(med([num(r['efficiency']) for r in ok]), '.1f'),
        fmt(med([num(r['rolled_back']) for r in ok]), '.3g')))
