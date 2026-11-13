#!/usr/bin/env python3
"""htram inbox modes 0/1/2 (charades RESULTS.md section 108/109). Usage: sdiag15_summary.py <job dir>"""
import csv, glob, math, statistics as st, sys
from collections import defaultdict
d = sys.argv[1]; mean = st.fmean
NAMES = {"gauss:100:1000:100": "σ 100", "gauss:100:1000:2000": "σ 2,000", "steady:100:1000:1.0": "uniform"}
R = defaultdict(list)
for f in glob.glob(f"{d}/m*_*_n*_r*.csv"):
    tag = f.split("/")[-1][:-4]; m = int(tag.split("_")[0][1:]); agg = tag.split("_")[1]
    for x in csv.DictReader(open(f)):
        if x["status"] != "ok": continue
        cell = NAMES.get(x["workload"], x["workload"]) + (", WPs" if agg == "wps512" else ", PP")
        arm = "W 400" if x["arm"].startswith("w:") else "controller"
        R[(int(x["nodes"]), cell, arm, m)].append(float(x["event_rate"]) / 1e6)
cells = ["σ 100, PP", "σ 2,000, PP", "uniform, PP", "uniform, WPs"]
print("A. Throughput by inbox mode (M committed ev/s at mode 0, mean of 3 reps; ratio = mode / mode 0, higher is better)")
for arm in ("W 400", "controller"):
    print(f"\n  {arm}")
    for c in cells:
        line = f"  {c:14}"
        for n in (1, 4, 16):
            b = R.get((n, c, arm, 0))
            if not b: line += " |   -"; continue
            line += f" | {n:>2}n {mean(b):6.1f} padded {mean(R[(n, c, arm, 1)]) / mean(b):.3f} rings {mean(R[(n, c, arm, 2)]) / mean(b):.3f}"
            line += " (" + "/".join(f"{x:.0f}" for x in R[(n, c, arm, 2)]) + " vs " + "/".join(f"{x:.0f}" for x in b) + ")"
        print(line)
for n in (1, 4, 16):
    for m in (1, 2):
        rs = [mean(R[(n, c, a, m)]) / mean(R[(n, c, a, 0)]) for c in cells for a in ("W 400", "controller") if R.get((n, c, a, 0)) and R.get((n, c, a, m))]
        if rs: print(f"  {n:>2} nodes mode {m}: geomean {math.exp(mean(map(math.log, rs))):.3f}, min {min(rs):.3f}, max {max(rs):.3f}")

print("\nB. htram node-level receives at 16 nodes, uniform, W 400, all PEs, whole run (µs; lower is better)")
P = ["alloc_s", "sort_s", "free_in_s", "handoff_s", "unref_s", "own_s"]
for c in ("uni_wps512", "uni_pp512"):
    for m in (0, 1, 2):
        for rep in (1, 2):
            fs = glob.glob(f"{d}/R_{c}_m{m}_r{rep}/ctl_sweep/recv_parts_*.csv")
            if not fs: print(f"  {c} mode {m} r{rep}: no data"); continue
            S = defaultdict(float)
            for f in fs:
                for x in csv.DictReader(open(f)):
                    for k, v in x.items():
                        if k not in ("pe", "rank"): S[k] += float(v)
            calls = max(S["calls"], 1)
            rate = [float(x["event_rate"]) / 1e6 for x in csv.DictReader(open(f"{d}/R_{c}_m{m}_r{rep}.csv")) if x["status"] == "ok"]
            print(f"  {c:10} mode {m} r{rep}: {1e6 * S['total_s'] / calls:.2f} µs/receive (hand-off {1e6 * S['handoff_s'] / calls:.2f}, "
                  f"free_in {1e6 * S['free_in_s'] / calls:.2f}) | pushes/receive {S['pushes'] / calls:.1f}, µs/push {1e6 * S['handoff_s'] / max(S['pushes'], 1):.3f}, "
                  f"overflows {S.get('overflows', 0) / max(S['pushes'], 1) * 100:.3f}% | drain µs/item {1e6 * S['drain_s'] / max(S['items'], 1):.3f} | rate {rate[0] if rate else float('nan'):.1f}")
