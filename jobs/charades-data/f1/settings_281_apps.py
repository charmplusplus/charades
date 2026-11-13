#!/usr/bin/env python3
"""Traffic and dragonfly: median M committed ev/s per (setting, arm) at each node count,
from the paper jobs (F5a2 1-16, R8 8, F5-32b 32, A64 64)."""
import csv, glob, os, re, statistics as st, collections
D = os.path.expanduser('~/charades-data')
JOBS = [('F5a2', D+'/f1/scale240/f5a_j3690453', {1, 2, 4, 16}), ('R8', D+'/f1/r8_260/j3695259', {8}),
        ('F5-32b', D+'/f1/scale240/f5big_j3690451', {32}), ('A64', D+'/s64_262/a_j3696080', {64})]
r = collections.defaultdict(list)
for name, d, only in JOBS:
    for f in glob.glob(d + '/n*/*.csv'):
        N = int(os.path.basename(os.path.dirname(f))[1:])
        if N not in only: continue
        m = re.match(r'(tr|df)_(pp2048|wps512|direct)_r\d\.csv$', os.path.basename(f))
        if not m: continue
        for row in csv.DictReader(open(f)):
            if row['status'] != 'ok': continue
            r[(m.group(1), N, m.group(2), row['arm'])].append(float(row['event_rate']) / 1e6)
for app in ['df', 'tr']:
    for N in [1, 2, 4, 8, 16, 32, 64]:
        c = {(s, a): st.median(v) for (ap, n, s, a), v in r.items() if ap == app and n == N}
        if not c: continue
        print('%s %2d  ' % (app, N) + '  '.join('%s/%s %.1f' % (s, a, v) for (s, a), v in sorted(c.items())))
