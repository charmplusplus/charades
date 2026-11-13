#!/usr/bin/env python3
"""Job A16 (charades RESULTS.md section 158): PP's start-up ramp against glibc
settings, with TLB shootdowns. Usage: a16_summary.py <job dir>
Per run: M ev/s; time lost in the first 2 s at the rest's rate (from the
time-stamped progress lines); TLB-shootdown, function-call and rescheduling
interrupts per second, summed over all nodes, in the first 0.75 s after the
clock start and at 2-5 s. Then medians per arm."""
import csv, glob, os, re, sys, statistics as st
from collections import defaultdict

d = sys.argv[1]
H = {os.path.basename(f)[:-4]: list(csv.DictReader(open(f))) for f in glob.glob(os.path.join(d, 'hfi', '*.csv'))}

def rate(k, a, b):
    tot = 0.0
    for rows in H.values():
        sel = [r for r in rows if a <= float(r['unix_s']) <= b and r.get(k, '-1') not in ('', '-1')]
        if len(sel) >= 2:
            tot += (int(sel[-1][k]) - int(sel[0][k])) / (float(sel[-1]['unix_s']) - float(sel[0]['unix_s']))
    return tot

def course(log):
    U, pts = None, [(0.0, 0)]
    for l in open(log):
        m = re.match(r'Simulation Starting: .* Unix time ([\d.]+)', l)
        if m: U = float(m.group(1))
        m = re.match(r'GVT\s+\d+:\s+(\d+) \(.*\), [\d.]+ MB, ([\d.]+) s', l)
        if m: pts.append((float(m.group(2)), int(m.group(1))))
    T, V = pts[-1]
    t2, v2 = max(((t, v) for t, v in pts if t <= 2.0))
    lost = t2 - v2 / ((V - v2) / (T - t2))
    return U, lost

arms = defaultdict(list)
print('%-22s %8s %8s | %-27s | %-27s | %-27s' % ('run', 'M ev/s', 'lost 2s', 'TLB/s: first 0.75 s | 2-5 s', 'CAL/s: first 0.75 | 2-5 s', 'RES/s: first 0.75 | 2-5 s'))
for f in sorted(glob.glob(os.path.join(d, 'n16', '*.csv'))):
    tag = os.path.basename(f)[:-4]
    if tag.startswith('warm'): continue
    r = list(csv.DictReader(open(f)))[0]
    log = glob.glob(os.path.join(d, 'n16', tag, 'ctl_sweep', 'logs', '*.out'))
    if r['status'] != 'ok' or not log: print(tag, r['status']); continue
    U, lost = course(log[0])
    rr = [(rate(k, U, U + 0.75), rate(k, U + 2, U + 5)) for k in ('TLB', 'CAL', 'RES')]
    arm = re.sub(r'_r\d+$', '', tag)
    arms[arm].append((float(r['event_rate']) / 1e6, lost) + tuple(x for p in rr for x in p))
    print('%-22s %8.1f %8.2f | %12.3g | %12.3g | %12.3g | %12.3g | %12.3g | %12.3g' % ((tag, float(r['event_rate']) / 1e6, lost) + tuple(x for p in rr for x in p)))
print('\nPer arm, median of reps (M ev/s higher is better; lost s and interrupt rates lower is better):')
base = med = None
for arm, v in sorted(arms.items()):
    m = [st.median([x[i] for x in v]) for i in range(8)]
    if arm == 'g2000_pp': base = m[0]
    print('  %-18s %7.1f M ev/s  lost %5.2f s  TLB/s %9.3g | %9.3g  (first ÷ steady %5.2f)  CAL/s %9.3g | %9.3g  RES/s %9.3g | %9.3g' % (
        arm, m[0], m[1], m[2], m[3], m[2] / m[3] if m[3] else float('nan'), m[4], m[5], m[6], m[7]))
if base:
    print('\n÷ PP 512 (higher is better): ' + ', '.join('%s %.3f' % (a, st.median([x[0] for x in v]) / base) for a, v in sorted(arms.items())))
