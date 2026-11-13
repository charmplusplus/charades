#!/usr/bin/env python3
"""Job P16 (charades RESULTS.md section 160): --agg-pp-alloc=1 and WPs 512
against PP on four workloads, 16 nodes. Usage: p16_summary.py <job dir>
Per workload and arm, median of reps: M ev/s, ÷ PP (higher is better), time
lost in the first 2 s (lower is better), events per htram message; and the
committed count (must match within a workload)."""
import csv, glob, os, re, sys, statistics as st
from collections import defaultdict

d = sys.argv[1]
R = defaultdict(list)
for f in glob.glob(os.path.join(d, 'n16', 'g*_r*.csv')):
    tag = os.path.basename(f)[:-4]
    m = re.match(r'g(\d+)_(\w+)_r(\d)$', tag)
    if not m: continue
    r = list(csv.DictReader(open(f)))[0]
    if r['status'] != 'ok': print(tag, r['status']); continue
    log = glob.glob(os.path.join(d, 'n16', tag, 'ctl_sweep', 'logs', '*.out'))
    pts = [(0.0, 0)]
    for l in open(log[0]):
        mm = re.match(r'GVT\s+\d+:\s+(\d+) \(.*\), [\d.]+ MB, ([\d.]+) s', l)
        if mm: pts.append((float(mm.group(2)), int(mm.group(1))))
    T, V = pts[-1]; t2, v2 = max((t, v) for t, v in pts if t <= 2.0)
    lost = t2 - v2 / ((V - v2) / (T - t2))
    R[(int(m.group(1)), m.group(2))].append((float(r['event_rate']) / 1e6, lost, float(r['agg_events_per_msg'] or 0), int(r['committed'])))
print('16 nodes, W 400, median of 3 reps')
print('%-8s %-8s %8s %8s %10s %8s  %s' % ('sigma', 'arm', 'M ev/s', '÷ PP', 'lost 2s s', 'ev/msg', 'reps (M ev/s)'))
for sig in sorted({k[0] for k in R}):
    base = st.median([x[0] for x in R[(sig, 'pp')]])
    commits = {x[3] for a in ('pp', 'ppalloc', 'wps') for x in R.get((sig, a), [])}
    for arm in ('pp', 'ppalloc', 'wps'):
        v = R.get((sig, arm))
        if not v: continue
        m = [st.median([x[i] for x in v]) for i in range(3)]
        print('%-8s %-8s %8.1f %8.3f %10.2f %8.1f  %s' % (sig if arm == 'pp' else '', arm, m[0], m[0] / base, m[1], m[2], ', '.join('%.1f' % x[0] for x in v)))
    print('%-8s committed counts equal: %s' % ('', len(commits) == 1))
