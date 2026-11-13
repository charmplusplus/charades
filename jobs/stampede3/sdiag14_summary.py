#!/usr/bin/env python3
"""--gvt-wave-events 32/64/128 at 1/4/16 nodes, and htram receive parts (charades RESULTS.md section 106/107).
Usage: sdiag14_summary.py <job dir>"""
import csv, glob, math, statistics as st
from collections import defaultdict
d = __import__("sys").argv[1]; mean = st.fmean
NAMES = {"gauss:100:1000:100": "σ 100", "gauss:100:1000:500": "σ 500", "gauss:100:1000:1000": "σ 1,000",
         "gauss:100:1000:2000": "σ 2,000", "gauss:100:1000:4000": "σ 4,000", "steady:100:1000:1.0": "uniform",
         "gauss:10:200:500": "LA10 σ 500", "gauss:10:200:2000": "LA10 σ 2,000"}

# A: rate[(nodes, k, set, workload, arm)] -> list over reps
R = defaultdict(list)
for f in glob.glob(f"{d}/k*_*_n*_r*.csv"):
    tag = f.split("/")[-1][:-4]; k = int(tag.split("_")[0][1:]); agg = tag.split("_")[2]
    for x in csv.DictReader(open(f)):
        if x["status"] != "ok": continue
        arm = "W" if x["arm"].startswith("w:") else "ctl"
        cell = NAMES.get(x["workload"], x["workload"]) + (" WPs" if agg == "wps512" else "")
        R[(int(x["nodes"]), k, cell, arm)].append(float(x["event_rate"]) / 1e6)
cells = sorted({c for (_, _, c, _) in R}, key=lambda c: list(NAMES.values()).index(c.replace(" WPs", "")) + (0.5 if "WPs" in c else 0))
print("A. --gvt-wave-events K / 128 (M committed ev/s, mean of 2 reps; ratio higher is better)")
for arm in ("W", "ctl"):
    print(f"\n  arm: {'fixed W (400; lookahead 10: 50)' if arm == 'W' else 'controller (eps 0.001)'}")
    print(f"  {'cell':16}" + "".join(f" | {n:>2} nodes: K128   32/128  64/128" for n in (1, 4, 16)))
    for c in cells:
        line = f"  {c:16}"
        for n in (1, 4, 16):
            b = R.get((n, 128, c, arm)); r32 = R.get((n, 32, c, arm)); r64 = R.get((n, 64, c, arm))
            if not (b and r32 and r64): line += " |" + " " * 31 + "-"; continue
            line += f" | {mean(b):11.1f} {mean(r32) / mean(b):7.3f} {mean(r64) / mean(b):7.3f}"
        print(line)
    for n in (1, 4, 16):
        for k in (32, 64):
            rs = [mean(R[(n, k, c, arm)]) / mean(R[(n, 128, c, arm)]) for c in cells if R.get((n, k, c, arm)) and R.get((n, 128, c, arm))]
            if rs:
                print(f"  {n:>2} nodes K {k}: geomean {math.exp(mean(map(math.log, rs))):.3f}, min {min(rs):.3f}, cells >= 1.02: {sum(r >= 1.02 for r in rs)}/{len(rs)}")
allr = defaultdict(list)
for (n, k, c, arm), v in R.items():
    if k != 128 and R.get((n, 128, c, arm)): allr[(n, k)].append(mean(v) / mean(R[(n, 128, c, arm)]))
print("\n  both arms together: " + "; ".join(f"{n} nodes K {k}: geomean {math.exp(mean(map(math.log, v))):.3f} min {min(v):.3f}" for (n, k), v in sorted(allr.items())))

# B: receive parts
print("\nB. htram node-level receives, all PEs, whole run (µs per receive; lower is better)")
P = ["alloc_s", "sort_s", "free_in_s", "handoff_s", "unref_s", "own_s"]
for c in ("uni_wps512", "uni_pp512", "s2k_pp512"):
    for n in (4, 16):
        for rep in (1, 2):
            fs = glob.glob(f"{d}/R_{c}_n{n}_r{rep}/ctl_sweep/recv_parts_*.csv")
            if not fs: print(f"  {c} {n} nodes r{rep}: no data"); continue
            S = defaultdict(float)
            for f in fs:
                for x in csv.DictReader(open(f)):
                    for k, v in x.items():
                        if k not in ("pe", "rank"): S[k] += float(v)
            calls = max(S["calls"], 1)
            rate = [float(x["event_rate"]) / 1e6 for x in csv.DictReader(open(f"{d}/R_{c}_n{n}_r{rep}.csv")) if x["status"] == "ok"]
            parts = " ".join(f"{k[:-2]} {1e6 * S[k] / calls:.2f}" for k in P)
            print(f"  {c:10} {n:>2} nodes r{rep}: {1e6 * S['total_s'] / calls:.2f} µs/receive ({parts}; parts sum {1e6 * sum(S[k] for k in P) / calls:.2f}) | "
                  f"items/receive {S['items'] / calls:.1f}, pushes/receive {S['pushes'] / calls:.1f}, µs/push {1e6 * S['handoff_s'] / max(S['pushes'], 1):.2f} | "
                  f"receives per PE {S['calls'] / len(fs):.0f} | drain µs/item {1e6 * S['drain_s'] / max(S['items'], 1):.2f} | rate {rate[0] if rate else float('nan'):.1f}")
