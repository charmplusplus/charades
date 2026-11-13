#!/usr/bin/env python3
"""The late PE during start-up against the steady state: what its time between pickup and contribution
goes to (job 3649213 --gvt-trace=4; charades RESULTS.md section 121). Usage: startup_late.py <sdiag19 job dir>"""
import csv, glob, os, statistics as st, sys
from collections import defaultdict
d = sys.argv[1]; mean = st.fmean
for n in (4, 16):
    for phase, sel in (("start-up (first 10%)", lambda i, N: i < N // 10), ("steady (10-95%)", lambda i, N: N // 10 <= i < N * 95 // 100)):
        X = defaultdict(list); ranks = defaultdict(int)
        for r in (1, 2):
            run = f"{d}/T_w400_n{n}_r{r}/ctl_sweep"; files = glob.glob(f"{run}/gvt_rec_*.csv")
            nproc = len(glob.glob(f"{run}/gvt_waves_*.csv")); pepp = len(files) // nproc
            R = defaultdict(dict)
            for f in files:
                pe = int(os.path.basename(f)[8:-4])
                for x in csv.DictReader(open(f)): R[int(x["wave"])][pe] = x
            waves = sorted(wv for wv, v in R.items() if len(v) == len(files) and all(float(y["events"]) < 1e9 for y in v.values()))
            N = len(waves)
            for i, wv in enumerate(waves):
                if not sel(i, N): continue
                by = defaultdict(list)
                for pe, x in R[wv].items(): by[pe // pepp].append((float(x["contrib_us"]), pe))
                sp = max(by, key=lambda p: max(by[p])[0]); late = max(by[sp])[1]; x = R[wv][late]
                g = lambda k: float(x[k]); ranks[late % pepp] += 1
                after = g("contrib_us") - g("pick_us")
                for k, v in (("delay", g("contrib_us")), ("pick", g("pick_us")), ("after", after), ("exec", g("exec_us")),
                             ("drain", g("drain_us")), ("rollback", g("rollback_us")), ("recv", g("recv_us")),
                             ("other", after - g("exec_us") - g("recv_us") - g("node_gvt_us")), ("events", g("events")),
                             ("arrivals", g("arrivals")), ("count", 1.0 if int(x["reason"]) in (2, 3) else 0.0)):
                    X[k].append(v)
        tot = sum(ranks.values()); e = mean(X["events"])
        print(f"{n:>2} nodes, {phase:20} ({tot} waves): " + " ".join(f"{k} {mean(v):.1f}" for k, v in X.items())
              + f" | exec per event {mean(X['exec']) / e:.2f} µs | late rank: " + ", ".join(f"r{k} {v / tot:.2f}" for k, v in sorted(ranks.items(), key=lambda kv: -kv[1])[:3]))
