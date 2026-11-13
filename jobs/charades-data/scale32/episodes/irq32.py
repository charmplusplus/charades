#!/usr/bin/env python3
"""Job E: per 0.25 s from the clock start, simulated time per wall second (thousands)
and TLB-shootdown, function-call and rescheduling interrupts per second summed over the
run's nodes (thousands), from the hfi sampler's /proc/interrupts columns."""
import csv, glob, os, re, sys
d, arm = sys.argv[1], sys.argv[2]
H = {os.path.basename(f)[:-4]: [(float(r['unix_s']), int(r['TLB']), int(r['CAL']), int(r['RES'])) for r in csv.DictReader(open(f))]
     for f in glob.glob(os.path.join(d, 'hfi', '*.csv'))}
def val(rows, t, i):
    for a, b in zip(rows, rows[1:]):
        if a[0] <= t <= b[0]: return a[i] + (b[i] - a[i]) * (t - a[0]) / (b[0] - a[0])
    return None
for f in sorted(glob.glob(os.path.join(d, os.environ.get('NDIR', 'n32'), arm, 'ctl_sweep', 'logs', '*.out'))):
    U, p = None, [(0.0, 0)]
    for l in open(f):
        m = re.match(r'Simulation Starting: .* Unix time ([\d.]+)', l)
        if m: U = float(m.group(1))
        m = re.match(r'GVT\s+\d+:\s+(\d+) \(.*\), [\d.]+ MB, ([\d.]+) s', l)
        if m: p.append((float(m.group(2)), int(m.group(1))))
    def at(t):
        for (ta, va), (tb, vb) in zip(p, p[1:]):
            if ta <= t <= tb: return va + (vb - va) * (t - ta) / max(1e-9, tb - ta)
    print('%s (clock start %.2f)' % (arm, U))
    print('  %-10s %8s %9s %9s %9s %s' % ('wall s', 'sim k/s', 'TLB k/s', 'CAL k/s', 'RES k/s', 'top TLB nodes (k/s)'))
    k = -8
    while True:
        a, b = 0.25 * k, 0.25 * k + 0.25
        sa, sb = at(a) if a >= 0 else 0, at(b) if b >= 0 else 0
        if sa is None or sb is None: break
        rates = []; per = []
        for i in (1, 2, 3):
            tot = 0
            for h, rows in H.items():
                x, y = val(rows, U + a, i), val(rows, U + b, i)
                if x is not None and y is not None:
                    tot += (y - x) / 0.25
                    if i == 1: per.append(((y - x) / 0.25, h))
            rates.append(tot)
        per.sort(reverse=True)
        print('  %4.2f-%5.2f %8.0f %9.1f %9.1f %9.1f %s' % (a, b, (sb - sa) / 0.25 / 1e3, rates[0] / 1e3, rates[1] / 1e3, rates[2] / 1e3, ' '.join('%s %.1f' % (h[-7:], r / 1e3) for r, h in per[:3])))
        k += 1
