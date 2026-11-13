#!/usr/bin/env python3
"""Job F4R (charades RESULTS.md section 231): F4's phase-changing PHOLD cell at
16 nodes, rerun. Per rep: each arm's M committed ev/s, ÷ the best fixed W of the
rep (higher is better), count waves per GVT advance (a fixed-W run above 1.03
marks the rep disturbed, section 231), efficiency, events rolled back, mean and
final W, committed count and digest.
Usage: f4r_summary.py <job dir>   (e.g. ~/charades-data/f4/f4r231/j3685047)"""
import csv, sys
D = sys.argv[1]
print('rep arm      M ev/s   ÷best   waves/adv  eff%     rolled back (M)  mean W  final W  committed   digest')
for rep in (1, 2, 3):
    rs = list(csv.DictReader(open(f'{D}/n16/phases_r{rep}.csv')))
    best = max(float(r['event_rate']) for r in rs if r['arm'].startswith('w:'))
    dist = any(float(r['count_waves']) / float(r['gvts']) > 1.03 for r in rs if r['arm'].startswith('w:'))
    for r in rs:
        x = float(r['event_rate'])
        print(f"{rep}  {r['arm']:7} {x / 1e6:7.1f}  {x / best:5.2f}   {float(r['count_waves']) / float(r['gvts']):6.3f}   {float(r['efficiency']):6.2f}  "
              f"{float(r['rolled_back']) / 1e6:8.1f}  {float(r['mean_window']):7.0f} {r['final_window']:>7} {r['committed']} {r['digest'][:12]}")
    print(f"   rep {rep}: {'DISTURBED' if dist else 'undisturbed'}")
