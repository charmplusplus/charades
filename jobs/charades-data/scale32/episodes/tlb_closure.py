#!/usr/bin/env python3
"""Job E: per untraced run, 0.25 s bins from 0.75 s after the clock start to the end:
time lost against a reference rate (simulated time per wall second), and how much of
it falls in bins where TLB shootdowns summed over the run's nodes exceed a threshold.
Usage: tlb_closure.py <job dir> <ref k/s> <TLB threshold k/s> arm_r1 [arm_r2 ...]"""
import csv, glob, os, re, sys
d, ref, thr = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
H = {os.path.basename(f)[:-4]: [(float(r['unix_s']), int(r['TLB'])) for r in csv.DictReader(open(f))]
     for f in glob.glob(os.path.join(d, 'hfi', '*.csv'))}
def val(rows, t):
    for a, b in zip(rows, rows[1:]):
        if a[0] <= t <= b[0]: return a[1] + (b[1] - a[1]) * (t - a[0]) / (b[0] - a[0])
print('%-16s %6s %8s | %5s %8s %6s | %s' % ('run', 'bins', 'lost s', 'hiTLB', 'lost s', 'share', 'mean sim k/s in bins: TLB high / low'))
for tag in sys.argv[4:]:
    f = glob.glob(os.path.join(d, 'n32', tag, 'ctl_sweep', 'logs', '*.out'))[0]
    U, p = None, [(0.0, 0)]
    for l in open(f):
        m = re.match(r'Simulation Starting: .* Unix time ([\d.]+)', l)
        if m: U = float(m.group(1))
        m = re.match(r'GVT\s+\d+:\s+(\d+) \(.*\), [\d.]+ MB, ([\d.]+) s', l)
        if m: p.append((float(m.group(2)), int(m.group(1))))
    def at(t):
        for (ta, va), (tb, vb) in zip(p, p[1:]):
            if ta <= t <= tb: return va + (vb - va) * (t - ta) / max(1e-9, tb - ta)
    n = tot = hn = hl = 0; hi, lo = [], []
    k = 3
    while True:
        a, b = 0.25 * k, 0.25 * k + 0.25; k += 1
        sa, sb = at(a), at(b)
        if sa is None or sb is None: break
        rate = (sb - sa) / 0.25 / 1e3
        tlb = sum((val(r, U + b) - val(r, U + a)) / 0.25 for r in H.values() if val(r, U + a) is not None and val(r, U + b) is not None) / 1e3
        lost = max(0.0, (ref - rate) / ref * 0.25)
        n += 1; tot += lost
        if tlb > thr: hn += 1; hl += lost; hi.append(rate)
        else: lo.append(rate)
    m = lambda v: sum(v) / len(v) if v else float('nan')
    print('%-16s %6d %8.2f | %5d %8.2f %5.0f%% | %6.0f / %6.0f' % (tag, n, tot, hn, hl, 100 * hl / tot if tot else 0, m(hi), m(lo)))
