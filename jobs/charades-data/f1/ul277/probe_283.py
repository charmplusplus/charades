#!/usr/bin/env python3
"""charades results/aggregation.md section 283: the slow probes of UL 32/64
(3711819, 3711820, reruns 3716315, 3716316) and L64b (3704609 slow, 3708796
normal). The same probe in every job: charades-r5, uniform, WPs 512, W 400,
end 2,048,000.

For each probe:
  - run time from its GVT progress lines (one every 64 rounds), and the time
    beyond a run at F1's / P64's rate (639.5 M ev/s at 32 nodes, 998.9 at 64);
  - that extra time split into stalls (gaps > 0.15 s between GVT lines) and the
    rest (a slower steady pace);
  - from the network record before and after the probe (start.nodes,
    probe.nodes): packets lost on any node, and the card's back-pressure,
    TxWait per word sent (port_xmit_data), median over nodes.
Usage: probe_283.py  (paths are fixed below)"""
import collections, glob, os, re, statistics as st

D = os.path.expanduser('~/charades-data/f1')
JOBS = [  # job, nodes, directory
    ('3704609', 64, D + '/l64/b_j3704609'),
    ('3708796', 64, D + '/l64/b_j3708796'),
    ('3711819', 32, D + '/ul277/fail/n32_j3711819'),
    ('3716315', 32, D + '/ul277/fail/n32_j3716315'),
    ('3711820', 64, D + '/ul277/fail/n64_j3711820'),
    ('3716316', 64, D + '/ul277/fail/n64_j3716316'),
]
COMMITTED = {32: 5790767104, 64: 11581457663}
REF = {32: 639.5e6, 64: 998.9e6}
LOST = ['RcvHdrOvr', 'PktDrop', 'XmitDscd', 'TxDropped', 'port_xmit_discards', 'port_rcv_errors',
        'excessive_buffer_overrun_errors', 'DcRxReplay', 'DcTxReplay', 'link_error_recovery',
        'local_link_integrity_errors']

def gvt_times(f):
    return [float(m.group(1)) for l in open(f, errors='replace')
            for m in [re.match(r'GVT\s+\d+:.*,\s*([\d.]+) s\s*$', l)] if m]

def load(f):
    v = collections.defaultdict(lambda: collections.Counter())
    for l in open(f, errors='replace'):
        p = l.rstrip('\n').split(' ', 1)
        if len(p) < 2 or p[1].startswith('time '): continue
        m = re.match(r'(\S+?):(-?\d+)$', p[1])
        if not m: continue
        name = m.group(1).split('/')[-1].split(',')[0]
        name = 'RcvHdrOvr' if name.startswith('RcvHdrOvr') else name
        v[p[0]][name] += int(m.group(2))
    return v

print('%-8s %5s %8s %9s %9s %8s %7s %8s %11s %6s %13s' % ('job', 'nodes', 'run (s)', 'M ev/s', 'rate/ref', 'extra s',
      'stalls', 'stall s', 'steady s', 'gap p50', 'TxWait/word'))
for job, n, d in JOBS:
    log = glob.glob(d + '/n%d/probe_r5/ctl_sweep/logs/*.out' % n)[0]
    t = gvt_times(log); g = [b - a for a, b in zip(t, t[1:])]
    stall = sum(x for x in g if x > 0.15); nst = sum(x > 0.15 for x in g)
    extra = t[-1] - COMMITTED[n] / REF[n]
    rate = COMMITTED[n] / t[-1]
    tw = '-'; lost = '-'
    a, b = d + '/net/start.nodes', d + '/net/probe.nodes'
    if os.path.exists(a) and os.path.exists(b):
        A, B = load(a), load(b); hs = [h for h in B if h in A]
        w = [(B[h]['TxWait'] - A[h]['TxWait']) / max(1, B[h]['port_xmit_data'] - A[h]['port_xmit_data']) for h in hs]
        tw = '%.2e' % st.median(w)
        lost = sum(max(0, B[h][k] - A[h][k]) for h in hs for k in LOST)
    print('%-8s %5d %8.1f %9.1f %9.3f %8.1f %7d %8.1f %11.1f %6.3f %13s  lost %s' % (job, n, t[-1], rate / 1e6, rate / REF[n],
          extra, nst, stall, extra - stall, sorted(g)[len(g) // 2], tw, lost))
