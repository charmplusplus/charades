#!/usr/bin/env python3
"""Does the steady-state wave time account for the run's time? (charades RESULTS.md section 121)
Usage: closure.py <job dir> <tag> ...   (traced runs: <tag>.csv and <tag>/ctl_sweep/gvt_waves_0.csv)"""
import csv, sys, statistics as st
d = sys.argv[1]
for tag in sys.argv[2:]:
    row = [x for x in csv.DictReader(open(f"{d}/{tag}.csv")) if x["status"] == "ok"][0]
    w = [{k: float(v) for k, v in x.items()} for x in csv.DictReader(open(f"{d}/{tag}/ctl_sweep/gvt_waves_0.csv"))]
    res = [x["result_s"] for x in w]; n = len(res)
    adv = [b - a for a, b in zip(res, res[1:])]
    lo, hi = n // 10, n * 95 // 100
    mid = adv[lo:hi]
    print(f"{tag}: exec_s {float(row['exec_s']):.3f}, wall_s {float(row['wall_s']):.3f}, committed {int(row['committed'])/1e6:.1f} M, waves {n}; "
          f"first result at {res[0]-w[0]['first_s']:.3f} s after process 0's first contribution; span first->last result {res[-1]-res[0]:.3f} s; "
          f"mean advance: waves 0-10% {1e6*st.fmean(adv[:lo]):.0f} µs, 10-95% {1e6*st.fmean(mid):.0f} µs, 95-100% {1e6*st.fmean(adv[hi:]):.0f} µs; "
          f"time in 0-10% {sum(adv[:lo]):.3f} s, 10-95% {sum(mid):.3f} s, 95-100% {sum(adv[hi:]):.3f} s")
