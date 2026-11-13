#!/usr/bin/env python3
"""Uniform's steady state on 4 and 16 nodes: time per wave against simulated time per wave, and where in the
wave the slowest process's time goes (job 3650843 --gvt-trace=2; charades RESULTS.md section 125).
Usage: uni_steady.py <job dir> <tag> ..."""
import csv, glob, os, sys, statistics as st
d = sys.argv[1]; mean = st.fmean
for tag in sys.argv[2:]:
    run = f"{d}/{tag}/ctl_sweep"
    g = list(csv.DictReader(open(f"{run}/gvt_trace.csv"))); n = len(g); lo, hi = n // 10, n * 95 // 100
    comp = [int(x["completed"]) for x in g[lo:hi]]
    P = {int(os.path.basename(f)[10:-4]): [{k: float(v) for k, v in x.items()} for x in csv.DictReader(open(f))]
         for f in glob.glob(f"{run}/gvt_waves_*.csv")}
    m = min(len(v) for v in P.values()); lo2, hi2 = m // 10, m * 95 // 100
    A, W, F, S, MW = [], [], [], [], []
    for i in range(max(1, lo2), hi2):
        work = {p: v[i]["last_s"] - v[i - 1]["result_s"] for p, v in P.items()}
        s = max(work, key=work.get); w = P[s][i]
        A.append(1e6 * (P[0][i]["result_s"] - P[0][i - 1]["result_s"])); W.append(1e6 * work[s])
        F.append(1e6 * (w["result_s"] - w["last_s"])); S.append(1e6 * (w["last_s"] - w["first_s"]))
        MW.append(1e6 * st.median(work.values()))
    print(f"{tag}: waves {n}; steady: buckets completed per wave {mean(comp):.2f}, advance {mean(A):.0f} µs, "
          f"µs per bucket {mean(A) / mean(comp):.1f}; slowest process work {mean(W):.0f} (median process {mean(MW):.0f}), "
          f"floor {mean(F):.0f}, spread in slowest process {mean(S):.0f}")
