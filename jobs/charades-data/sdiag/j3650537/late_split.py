#!/usr/bin/env python3
"""The late PE's time between picking up a result and contributing, split (job 3649213 traces;
charades RESULTS.md section 121). Usage: late_split.py <sdiag19 job dir>"""
import csv, glob, os, statistics as st, sys
from collections import defaultdict
d = sys.argv[1]; mean = st.fmean
K = ["after", "exec", "drain", "rollback", "recv", "node_gvt", "other", "events", "arrivals"]
for w, n in ((400, 4), (400, 16), (250, 16), (600, 16)):
    L, M = defaultdict(list), defaultdict(list); nw = 0
    for r in (1, 2):
        run = f"{d}/T_w{w}_n{n}_r{r}/ctl_sweep"; files = glob.glob(f"{run}/gvt_rec_*.csv")
        if not files: continue
        nproc = len(glob.glob(f"{run}/gvt_waves_*.csv")) or 1; pepp = len(files) // nproc
        R = defaultdict(dict)
        for f in files:
            pe = int(os.path.basename(f)[8:-4])
            for x in csv.DictReader(open(f)): R[int(x["wave"])][pe] = x
        waves = sorted(wv for wv, v in R.items() if len(v) == len(files) and all(float(y["events"]) < 1e9 for y in v.values()))
        lo, hi = waves[len(waves) // 10], waves[len(waves) * 95 // 100]
        for wv in waves:
            if wv < lo or wv > hi: continue
            by = defaultdict(list)
            for pe, x in R[wv].items(): by[pe // pepp].append((float(x["contrib_us"]), pe))
            sp = max(by, key=lambda p: max(by[p])[0]); o = sorted(by[sp])
            late, mid = o[-1][1], o[(len(o) - 1) // 2][1]; nw += 1
            for X, pe in ((L, late), (M, mid)):
                x = R[wv][pe]; g = lambda k: float(x[k])
                after = g("contrib_us") - g("pick_us")
                X["after"].append(after); X["exec"].append(g("exec_us")); X["drain"].append(g("drain_us"))
                X["rollback"].append(g("rollback_us")); X["recv"].append(g("recv_us")); X["node_gvt"].append(g("node_gvt_us"))
                X["other"].append(after - g("exec_us") - g("recv_us") - g("node_gvt_us"))
                X["events"].append(g("events")); X["arrivals"].append(g("arrivals"))
    if not nw: print(f"W {w} {n} nodes: no traces"); continue
    print(f"W {w:3} {n:>2} nodes ({nw} waves), µs from pickup to contribution (exec includes drain and rollback):")
    for nm, X in (("late", L), ("median", M)):
        e = mean(X["events"])
        print(f"  {nm:6}: " + " ".join(f"{k} {mean(X[k]):.1f}" for k in K) +
              (f" | exec per event {mean(X['exec']) / e:.2f}, exec minus drain and rollback per event {(mean(X['exec']) - mean(X['drain']) - mean(X['rollback'])) / e:.2f}" if e > 1 else ""))
