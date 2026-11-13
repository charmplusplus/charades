#!/usr/bin/env python3
"""Job E: simulated time per wall second in 0.5 s bins, per untraced run (thousands; higher is faster)."""
import glob, os, re, sys
d = sys.argv[1]; arms = sys.argv[2].split(',')
def pts_of(log):
    p = [(0.0, 0)]
    for l in open(log):
        m = re.match(r'GVT\s+\d+:\s+(\d+) \(.*\), [\d.]+ MB, ([\d.]+) s', l)
        if m: p.append((float(m.group(2)), int(m.group(1))))
    return p
def at(p, t):
    for (ta, va), (tb, vb) in zip(p, p[1:]):
        if ta <= t <= tb: return va + (vb - va) * (t - ta) / max(1e-9, tb - ta)
    return None
print('%-16s' % 'run' + ''.join('%6.1f' % (0.5 * k) for k in range(14)))
for arm in arms:
    for f in sorted(glob.glob(os.path.join(d, 'n32', arm + '_r?', 'ctl_sweep', 'logs', '*.out'))):
        tag = f.split('/')[-4]; p = pts_of(f); row = []
        for k in range(14):
            a, b = at(p, 0.5 * k), at(p, 0.5 * k + 0.5)
            row.append('%6.0f' % ((b - a) / 0.5 / 1e3) if a is not None and b is not None else '     -')
        print('%-16s' % tag + ''.join(row))
