#!/usr/bin/env python3
"""Summarize Projections logs (version 11, non-delta): per entry method, the
total time and count summed over PEs, plus idle time and time outside any entry
method (runtime scheduler and everything untraced), as a share of PE time.

Usage: projsum.py <trace dir> [max PEs to read]
"""
import collections
import glob
import gzip
import os
import re
import sys

d = sys.argv[1]
maxpe = int(sys.argv[2]) if len(sys.argv) > 2 else 10**9
sts = glob.glob(os.path.join(d, '*.sts'))[0]
names = {}
for line in open(sts):
    m = re.match(r'ENTRY CHARE (\d+) "(.*)" (\d+)', line)
    if m:
        names[int(m.group(1))] = m.group(2)
    m = re.match(r'CHARE (\d+) "(.*)"', line)
    if m:
        names.setdefault(('chare', int(m.group(1))), m.group(2))
for line in open(sts):  # chare of each entry
    m = re.match(r'ENTRY CHARE (\d+) "(.*)" (\d+) (\d+)', line)
    if m:
        c = names.get(("chare", int(m.group(3))), "?")
        names[int(m.group(1))] = '%s::%s' % (c, m.group(2))

logs = sorted(glob.glob(os.path.join(d, '*.log*')),
              key=lambda p: int(re.search(r'\.(\d+)\.log', p).group(1)))[:maxpe]
ep_time = collections.Counter()
ep_count = collections.Counter()
created = collections.Counter()
idle = span = 0
npe = 0
for path in logs:
    op = gzip.open if path.endswith('.gz') else open
    first = last = None
    open_ep = None
    idle_start = None
    with op(path, 'rt') as f:
        for line in f:
            t = line.split()
            if not t or not t[0].isdigit():
                continue
            typ = int(t[0])
            if typ == 2:  # BEGIN_PROCESSING: type mIdx eIdx time ...
                ts = int(t[3]); open_ep = (int(t[2]), ts)
            elif typ == 3:  # END_PROCESSING
                ts = int(t[3])
                if open_ep:
                    ep_time[open_ep[0]] += ts - open_ep[1]
                    ep_count[open_ep[0]] += 1
                open_ep = None
            elif typ == 14:  # BEGIN_IDLE: type time pe
                ts = int(t[1]); idle_start = ts
            elif typ == 15:
                ts = int(t[1])
                if idle_start is not None:
                    idle += ts - idle_start
                idle_start = None
            elif typ == 1:  # CREATION: type mIdx eIdx time ...
                ts = int(t[3]); created[int(t[2])] += 1
            elif typ in (6, 7, 11, 12):
                ts = int(t[1])
            else:
                continue
            first = ts if first is None else first
            last = ts
    if first is not None:
        span += last - first
        npe += 1

total_ep = sum(ep_time.values())
print('%d PEs, %.3f s of PE time traced (sum over PEs)' % (npe, span / 1e6))
print('%-58s %9s %7s %11s %9s %9s' % ('entry method', 'time (s)', 'share', 'calls',
                                      'us/call', 'created'))
for ep, tm in ep_time.most_common(25):
    print('%-58s %9.3f %6.1f%% %11d %9.2f %9d' % (
        names.get(ep, str(ep))[:58], tm / 1e6, 100.0 * tm / span, ep_count[ep],
        tm / ep_count[ep], created[ep]))
print('%-58s %9.3f %6.1f%%' % ('all entry methods', total_ep / 1e6, 100.0 * total_ep / span))
print('%-58s %9.3f %6.1f%%' % ('idle', idle / 1e6, 100.0 * idle / span))
other = span - total_ep - idle
print('%-58s %9.3f %6.1f%%' % ('outside entry methods, not idle', other / 1e6, 100.0 * other / span))
