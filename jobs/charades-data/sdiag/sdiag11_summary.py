#!/usr/bin/env python3
"""Rotated LP blocks and +lci_dest_device (charades RESULTS.md section 100/101). Usage: sdiag11_summary.py <job dir>"""
import csv, glob, re, sys, statistics as st
from collections import defaultdict, Counter
d = sys.argv[1]; mean = st.fmean; med = st.median
ARMS = ["base", "rot", "dd", "ddrot"]
def rate(tag):
    v = [float(x["event_rate"]) / 1e6 for f in glob.glob(f"{d}/{tag}.csv") for x in csv.DictReader(open(f)) if x["status"] == "ok"]
    return v[0] if v else float("nan")
print("Throughput, untraced (M committed ev/s, mean of 2 reps; ratio = arm / base, higher is better)")
for s in ("100", "2000"):
    b = mean([rate(f"off_base_s{s}_r{k}") for k in (1, 2)])
    for a in ARMS:
        r = [rate(f"off_{a}_s{s}_r{k}") for k in (1, 2)]
        print(f"  sigma {s:>4} {a:6}: {mean(r):6.1f} ({r[0]:.1f}, {r[1]:.1f}) ratio {mean(r)/b:.3f}")
print("\nLateness (traced, waves 10-95%, both reps): mean contribution delay (us) by rank; last-PE share of the slowest process")
SHOW = [0, 1, 2, 9, 10, 11, 12, 21, 22]
for s in ("100", "2000"):
    for a in ARMS:
        D = defaultdict(list); last = Counter(); nw = 0; worst = []
        for k in (1, 2):
            P = [[list(map(float, r)) for r in list(csv.reader(open(f)))[1:]] for f in glob.glob(f"{d}/T_{a}_s{s}_r{k}/ctl_sweep/gvt_ranks_*.csv")]
            if not P: continue
            n = min(len(p) for p in P); nr = len(P[0][0])
            for i in range(max(2, n // 10), n - n // 20):
                wp = max(range(len(P)), key=lambda q: max(P[q][i])); row = P[wp][i]
                last[max(range(nr), key=row.__getitem__)] += 1; nw += 1; worst.append(max(row))
                for p in P:
                    for r in range(nr): D[r].append(p[i][r])
        if not D: print(f"  sigma {s} {a}: no traces"); continue
        rest = med([mean(D[r]) for r in range(3, 9)] + [mean(D[r]) for r in range(13, 20)])
        print(f"  sigma {s:>4} {a:6}: " + " ".join(f"r{r}={mean(D[r]):.0f}" for r in SHOW) + f" | middle ranks {rest:.0f} | last PE: " +
              ", ".join(f"r{r} {c/nw:.2f}" for r, c in last.most_common(4)) + f" | slowest-PE delay {mean(worst):.0f}")
