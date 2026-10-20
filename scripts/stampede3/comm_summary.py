#!/usr/bin/env python3
"""Per-message cost from a window_sweep.sh CSV run with WORKLOAD=uniform and
COMM_STATS=1 (remote fraction swept in the 'sigma' column).

For each node count and GVT setup it prints, per remote fraction: committed
events/s, efficiency, remote sends per committed event, mean send-call time
and its share of PE time. Then, for each node count, it fits

    PE-seconds per committed event = a + b * (remote sends per committed event)

over the runs of one GVT setup (default: the smallest window, which keeps
efficiency near 100%), so b estimates the full cost of one remote message
(send call + receive side + scheduling), and reports b's share of the time
per event at each remote fraction.

Usage: comm_summary.py sweep.csv [gvt-setup]   e.g. 'bucket w=250'
"""
import csv
import statistics
import sys
from collections import defaultdict


def f(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return None


rows = [r for r in csv.DictReader(open(sys.argv[1])) if r['status'] == 'ok']
fit_setup = sys.argv[2] if len(sys.argv) > 2 else None


def setup(r):
    if r['gvt'] == 'blocking':
        return 'blocking'
    return 'bucket' if r['window'] == '0' else 'bucket w=%s' % r['window']


groups = defaultdict(list)
for r in rows:
    groups[(int(r['nodes']), setup(r), float(r['sigma']))].append(r)

setups = sorted({k[1] for k in groups}, key=lambda s: (s != 'blocking', s))
if fit_setup is None:
    windowed = [s for s in setups if s.startswith('bucket w=')]
    fit_setup = min(windowed, key=lambda s: int(s.split('=')[1])) \
        if windowed else 'blocking'

med = lambda xs: statistics.median(xs) if xs else None

for nodes in sorted({k[0] for k in groups}):
    print('== %d nodes' % nodes)
    print('  %-12s %6s %9s %6s %10s %9s %7s' % (
        'setup', 'remote', 'Mev/s', 'eff %', 'msgs/event', 'send us', 'send %'))
    for s in setups:
        for rem in sorted({k[2] for k in groups if k[0] == nodes and k[1] == s}):
            rs = groups[(nodes, s, rem)]
            rate = med([f(r['event_rate']) for r in rs])
            msgs = med([(f(r['remote_sends']) + f(r['anti_sends'])) / f(r['committed'])
                        for r in rs])
            print('  %-12s %6g %9.3f %6.1f %10.3f %9s %7s' % (
                s, rem, rate / 1e6, med([f(r['efficiency']) for r in rs]), msgs,
                '%.2f' % med([f(r['send_call_us']) for r in rs])
                if rs[0]['send_call_us'] else '-',
                '%.1f' % med([f(r['send_pct']) for r in rs])
                if rs[0]['send_pct'] else '-'))
    # Least-squares fit over individual runs of the chosen setup
    pts = []
    for r in rows:
        if int(r['nodes']) == nodes and setup(r) == fit_setup:
            pes = int(r['pes'])
            y = f(r['exec_s']) * pes / f(r['committed'])  # PE-seconds per event
            x = (f(r['remote_sends']) + f(r['anti_sends'])) / f(r['committed'])
            pts.append((x, y, float(r['sigma'])))
    if len(pts) >= 3 and len({p[0] for p in pts}) > 1:
        mx = statistics.mean(p[0] for p in pts)
        my = statistics.mean(p[1] for p in pts)
        b = sum((p[0] - mx) * (p[1] - my) for p in pts) / \
            sum((p[0] - mx) ** 2 for p in pts)
        a = my - b * mx
        print('  fit (%s): %.2f us per event + %.2f us per remote message' % (
            fit_setup, a * 1e6, b * 1e6))
        for rem in sorted({p[2] for p in pts}):
            xs = [p[0] for p in pts if p[2] == rem]
            x = statistics.mean(xs)
            print('    remote %-5g: messages are %4.0f%% of the time per event' % (
                rem, 100 * b * x / (a + b * x)))
    print()
