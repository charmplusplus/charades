#!/usr/bin/env python3
"""Rings vs mutex inboxes on the 8 scaling workloads (charades RESULTS.md section 110/111). Usage: sdiag16_summary.py <job dir>"""
import csv, glob, math, statistics as st, sys
from collections import defaultdict
d = sys.argv[1]; mean = st.fmean
NAMES = {"gauss:100:1000:100": "σ 100", "gauss:100:1000:500": "σ 500", "gauss:100:1000:1000": "σ 1,000",
         "gauss:100:1000:2000": "σ 2,000", "gauss:100:1000:4000": "σ 4,000", "steady:100:1000:1.0": "uniform",
         "gauss:10:200:500": "LA10 σ 500", "gauss:10:200:2000": "LA10 σ 2,000"}
R = defaultdict(list)
for f in glob.glob(f"{d}/m*_*_n*_r*.csv"):
    tag = f.split("/")[-1][:-4]; m = int(tag.split("_")[0][1:]); agg = tag.split("_")[2]
    for x in csv.DictReader(open(f)):
        if x["status"] != "ok": continue
        cell = NAMES[x["workload"]] + (" WPs" if agg == "wps512" else "")
        arm = "W" if x["arm"].startswith("w:") else "ctl"
        R[(int(x["nodes"]), cell, arm, m)].append(float(x["event_rate"]) / 1e6)
order = list(NAMES.values()) + ["uniform WPs"]
print("Rings / mutex inbox (M committed ev/s, mean of reps; per-rep values; higher is better)")
for n in (16, 4):
    for arm in ("W", "ctl"):
        print(f"\n  {n} nodes, {'fixed W (400; LA10 50)' if arm == 'W' else 'controller'}")
        rs = []
        for c in order:
            a, b = R.get((n, c, arm, 2)), R.get((n, c, arm, 0))
            if not (a and b): continue
            r = mean(a) / mean(b); rs.append(r)
            print(f"    {c:14} mutex {mean(b):6.1f} rings {mean(a):6.1f} ratio {r:.3f} | rings {' '.join(f'{x:.0f}' for x in a)} | mutex {' '.join(f'{x:.0f}' for x in b)}")
        print(f"    geomean {math.exp(mean(map(math.log, rs))):.3f} min {min(rs):.3f}")
