#!/usr/bin/env python3
"""Late ranks vs LCI device count and PSM2_RCVTHREAD (charades RESULTS.md section 87). Usage: sdiag5_summary.py <job dir>"""
import csv, glob, re, sys, statistics as st
from collections import defaultdict, Counter
d = sys.argv[1]; med = st.median; mean = st.fmean
ARMS = ["16", "23", "8", "4", "16rt0"]; WLS = ["gauss_100_1000_100", "gauss_100_1000_2000"]
def dev0(arm):  # ranks that poll device 0
    nd = int(arm.replace("rt0", "")); per = -(-23 // nd); return set(range(per))
def rate(tag):
    v = [float(x["event_rate"]) / 1e6 for f in glob.glob(f"{d}/{tag}.csv") for x in csv.DictReader(open(f)) if x["status"] == "ok"]
    return v[0] if v else float("nan")
print("R. Throughput, untraced (M committed ev/s, mean of 2 reps; ratio = arm ÷ 16 devices, higher is better)\n")
for wl in WLS:
    base = mean([rate(f"T_off_nd16_{wl}_w400_r{k}") for k in (1, 2)])
    for arm in ARMS:
        r = [rate(f"T_off_nd{arm}_{wl}_w400_r{k}") for k in (1, 2)]
        print(f"  {wl} {arm:>6}: {mean(r):7.1f} ({r[0]:.1f}, {r[1]:.1f})  ratio {mean(r)/base:.3f}")
print("\nL. Late ranks (traced, waves 10%-95%, both reps)\n")
for wl in WLS:
    for arm in ARMS:
        D = defaultdict(list); above = Counter(); last = Counter(); nwav = tot = 0; worst_all = []; worst_wo = []
        d0 = dev0(arm)
        for k in (1, 2):
            files = sorted(glob.glob(f"{d}/T_tr_nd{arm}_{wl}_w400_r{k}/ctl_sweep/gvt_ranks_*.csv"), key=lambda f: int(re.search(r"_(\d+)\.csv", f).group(1)))
            P = [[list(map(float, row)) for row in list(csv.reader(open(f)))[1:]] for f in files]
            if not P: continue
            n = min(len(p) for p in P); nr = len(P[0][0])
            for i in range(max(2, n // 10), n - n // 20):
                wp = max(range(len(P)), key=lambda p: max(P[p][i])); row = P[wp][i]
                last[max(range(nr), key=row.__getitem__)] += 1; nwav += 1
                worst_all.append(max(max(p[i]) for p in P))
                worst_wo.append(max(max(v for r, v in enumerate(p[i]) if r not in d0) for p in P))
                for p in P:
                    m = med(p[i])
                    for r in range(nr):
                        D[r].append(p[i][r]); above[r] += p[i][r] > m
                    tot += 1
        if not D: print(f"  {wl} {arm}: no traces"); continue
        nr = len(D); others = [mean(D[r]) for r in range(nr) if r not in d0 and r != 22]
        show = sorted(d0 | {len(d0), len(d0) + 1, 21, 22})
        print(f"  {wl} ndev {arm} (device 0 = ranks {min(d0)}-{max(d0)}):")
        print(f"    mean delay µs: " + " ".join(f"r{r}={mean(D[r]):.0f}" for r in show) + f"  median of the rest={med(others):.0f}")
        print(f"    share above process median: " + " ".join(f"r{r}={above[r]/tot:.2f}" for r in show))
        print(f"    slowest process's last rank: " + ", ".join(f"r{r} {c/nwav:.2f}" for r, c in last.most_common(5)))
        print(f"    slowest-PE delay µs: all {mean(worst_all):.0f}, without device-0 ranks {mean(worst_wo):.0f} ({mean(worst_wo)/mean(worst_all)-1:+.0%})")
