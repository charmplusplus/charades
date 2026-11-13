#!/usr/bin/env python3
"""Offline analysis of job VS2 (charades RESULTS.md section 228): no new runs.
1. Per-wave latency at PE 0 (--gvt-trace=1 runs, cycles 1,000-4,000): median,
   mean, and the tail (waves over 2x the median).
2. Each run's progress lines (wall time every 64 GVT advances = 64 clock
   cycles): the fast level (10th percentile of ms per cycle), and the share of
   run time in slow stretches (intervals over 1.1x the fast level, excess only).
3. Round-3 runs at 32 nodes: run time with and without the slow stretches.
4. W 2,500 against W 5,000: rollbacks, blocked shares.
Usage: vs2_offline228.py  (run in ~/charades-data/vlsi/vscale216)"""
import csv, glob, re, statistics as st
SETS = [('a2_j3679974', n) for n in (1, 2, 4, 8, 16)] + [('big2_j3679976', 32)]
print('==== 1. per-wave latency at PE 0, us (lower is better)')
for d, n in SETS:
    fs = glob.glob(f'{d}/n{n}/C3gt/ctl_sweep/logs/*.gvt_trace.csv')
    if not fs: continue
    w = [r for r in csv.DictReader(open(fs[0])) if 1000 <= int(r['bucket']) <= 4000]
    x = sorted((float(r['result_s']) - float(r['start_s'])) * 1e6 for r in w)
    m = st.median(x); tail = [v for v in x if v > 2 * m]
    print(f'  {n:2} nodes: median {m:.1f} mean {st.mean(x):.1f}; over 2x median {100 * len(tail) / len(x):.1f}% of waves, '
          f'{100 * sum(tail) / sum(x):.0f}% of wave time; p90 {x[int(.9 * len(x))]:.0f} p99 {x[int(.99 * len(x))]:.0f}')
    parts = {k: st.median((float(r[b]) - float(r[a])) * 1e6 for r in w if r['combined_s'] not in ('', '0'))
             for k, a, b in (('start->combined', 'start_s', 'combined_s'), ('combined->result', 'combined_s', 'result_s'), ('result->pickup', 'result_s', 'end_s'))}
    print('      medians: ' + ', '.join(f'{k} {v:.1f}' for k, v in parts.items())
          + f'; per wave, waves <= 2x median contribute {(sum(x) - sum(tail)) / len(x):.1f}, slower waves {sum(tail) / len(x):.1f}')
def intervals(f):
    ts = [float(m.group(1)) for m in (re.match(r'GVT\s+\d+:.*,\s*([\d.]+) s', l) for l in open(f)) if m]
    return ts, [(b - a) * 1e3 / 64 for a, b in zip(ts, ts[1:])][5:-2]   # ms per cycle, start and end dropped
print('\n==== 2. fast level (p10, ms per cycle) and slow-stretch share of run time, round 3')
for d, n in SETS:
    for arm in ('w2500', 'mb0', 'w5000'):
        p10s, meds, sh = [], [], []
        for f in glob.glob(f'{d}/n{n}/C3_r*/ctl_sweep/logs/*_{arm}.out'):
            _, iv = intervals(f); p = sorted(iv)[len(iv) // 10]
            p10s.append(p); meds.append(st.median(iv)); sh.append(sum(x - p for x in iv if x > 1.1 * p) / sum(iv))
        print(f'  {n:2} nodes {arm:6} fast {min(p10s):.3f}-{max(p10s):.3f}  median {st.median(meds):.3f}  slow {100 * min(sh):.1f}-{100 * max(sh):.1f}%  (runs {len(p10s)})')
print('\n==== 3. 32 nodes, round 3: run time from GVT 64 to the last progress line, s, and without the slow stretches')
for arm in ('mb0', 'w2500', 'w5000'):
    out = []
    for f in sorted(glob.glob(f'big2_j3679976/n32/C3_r*/ctl_sweep/logs/*_{arm}.out')):
        ts, iv = intervals(f); p = sorted(iv)[len(iv) // 10]
        slow = sum(x - p for x in iv if x > 1.1 * p) * 64 / 1e3
        out.append(f'{ts[-1] - ts[0]:.2f}/{ts[-1] - ts[0] - slow:.2f}')
    print(f'  {arm:6} ' + '  '.join(out))
print('\n==== 4. W 2,500 against W 5,000, round 3 (median over reps)')
for d, n in SETS:
    for arm in ('w:2500', 'w:5000'):
        rs = [r for f in glob.glob(f'{d}/n{n}/C3_r*.csv') for r in csv.DictReader(open(f)) if r['arm'] == arm]
        if not rs: continue
        m = lambda k: st.median(float(r[k]) for r in rs)
        print(f"  {n:2} nodes {arm:7} exec {m('exec_s'):5.2f} s  rolled back {m('rolled_back') / 1e6:5.1f} M  blocked {m('blocked_pct'):4.1f}% "
              f"(lowest PE {m('blocked_min_pct'):4.1f}%, highest {m('blocked_max_pct'):4.1f}%)")
