#!/usr/bin/env python3
"""23 vs 16 LCI devices at 16 nodes (charades RESULTS.md section 89/90). Usage: dev23_summary.py <job dir>"""
import csv, glob, sys, statistics as st
from collections import defaultdict
d = sys.argv[1]; R = defaultdict(list)
for f in glob.glob(f"{d}/*_nd*_r*.csv"):
    nd = f.split("_nd")[1].split("_")[0]
    for x in csv.DictReader(open(f)):
        if x["status"] == "ok":
            R[(x["workload"], x["arm"], nd)].append(float(x["event_rate"]) / 1e6)
print("| workload | arm | 16 devices (M ev/s) | 23 devices (M ev/s) | 23 ÷ 16 | spread 16 / 23 (max÷min) |")
print("|---|---|---|---|---|---|")
ratios = defaultdict(list)
for wl, arm in sorted({(k[0], k[1]) for k in R}, key=lambda k: (k[0].split(":")[1] == "10", k[0], k[1])):
    a, b = R[(wl, arm, "16")], R[(wl, arm, "23")]
    if not a or not b: continue
    r = st.median(b) / st.median(a); ratios[arm[0]].append(r)
    print(f"| {wl} | {arm} | {st.median(a):.1f} (n={len(a)}) | {st.median(b):.1f} (n={len(b)}) | {r:.3f} | {max(a)/min(a):.3f} / {max(b)/min(b):.3f} |")
for k, v in ratios.items():
    g = st.geometric_mean(v)
    print(f"\n{'controller' if k == 'q' else 'fixed W'}: geomean 23 ÷ 16 = {g:.3f}; range {min(v):.3f}-{max(v):.3f}; >= 1.03 in {sum(x >= 1.03 for x in v)} of {len(v)}; < 0.98 in {sum(x < 0.98 for x in v)}")
