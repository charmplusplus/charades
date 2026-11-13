#!/usr/bin/env python3
"""Wider-window cost on a clean allocation (charades RESULTS.md section 83/84). Usage: sdiag3_summary.py <job dir>"""
import csv, glob, re, sys, statistics as st
from collections import defaultdict
d = sys.argv[1]; med = st.median
print("\nW. Wider windows, 16 nodes, PP 512 (median of 3 reps; µs per advance etc. from the per-process traces)\n")
print("| workload | W | M ev/s | efficiency % | advances | µs/advance (mean) | reduction floor | straggler cost | rolled back (M events) | busiest process (µs/event ÷ median) |")
print("|---" * 10 + "|")
for wl in ["gauss_100_1000_100", "gauss_100_1000_2000"]:
    for w in [250, 400, 600]:
        reps = []
        for rep in (1, 2, 3):
            dd = f"{d}/W_{wl}_w{w}_r{rep}"
            c = list(csv.DictReader(open(f"{dd}.csv")))
            if not c or c[0]["status"] != "ok": continue
            x = c[0]
            files = sorted(glob.glob(f"{dd}/ctl_sweep/gvt_waves_*.csv"), key=lambda f: int(re.search(r"_(\d+)\.csv", f).group(1)))
            P = [list(csv.DictReader(open(f))) for f in files]
            k = min(len(p) for p in P); lo, hi = max(1, k // 10), k - k // 20
            adv, floor, strag = [], [], []
            for i in range(lo, hi):
                work = [float(p[i]["last_s"]) - float(p[i - 1]["result_s"]) for p in P]
                wait = [float(p[i]["result_s"]) - float(p[i]["last_s"]) for p in P]
                adv.append(med([float(p[i]["result_s"]) - float(p[i - 1]["result_s"]) for p in P]))
                floor.append(min(wait)); strag.append(max(work) - med(work))
            ps = list(csv.DictReader(open(f"{dd}/ctl_sweep/pe_stats.csv")))
            pr = defaultdict(lambda: [0.0, 0.0])
            for y in ps: pr[int(y["process"])][0] += float(y["exec_s"]); pr[int(y["process"])][1] += float(y["executed"])
            us = {p: v[0] / v[1] for p, v in pr.items()}; mu = med(us.values()); top = max(us, key=us.get)
            reps.append((float(x["event_rate"]) / 1e6, float(x["efficiency"]), int(x["gvts"]), st.fmean(adv) * 1e6, st.fmean(floor) * 1e6,
                         st.fmean(strag) * 1e6, float(x["rolled_back"]) / 1e6, f"p{top} {us[top]/mu:.3f}"))
        if reps:
            print(f"| {wl} | {w} | " + " | ".join(f"{med(r[j] for r in reps):.{p}f}" for j, p in [(0, 1), (1, 2), (2, 0), (3, 0), (4, 0), (5, 0), (6, 2)]) + f" | {', '.join(r[7] for r in reps)} |")
