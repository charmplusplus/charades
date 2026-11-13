#!/usr/bin/env python3
"""Start-up waves split into the slowest process's work and the reduction floor, by 100-wave block
(charades RESULTS.md section 121). Usage: startup_split.py <job dir> <tag> ..."""
import csv, glob, os, sys, statistics as st
d = sys.argv[1]
for tag in sys.argv[2:]:
    P = {}
    for f in glob.glob(f"{d}/{tag}/ctl_sweep/gvt_waves_*.csv"):
        P[int(os.path.basename(f)[10:-4])] = [{k: float(v) for k, v in x.items()} for x in csv.DictReader(open(f))]
    n = min(len(v) for v in P.values()); out = []
    for b0 in list(range(1, 1001, 100)) + [n // 2]:
        W, F, S = [], [], []
        for i in range(b0, min(b0 + 100, n)):
            work = {p: v[i]["last_s"] - v[i - 1]["result_s"] for p, v in P.items()}
            s = max(work, key=work.get); w = P[s][i]
            W.append(1e6 * work[s]); F.append(1e6 * (w["result_s"] - w["last_s"]))
            S.append(1e6 * (w["last_s"] - w["first_s"]))
        out.append(f"{'mid' if b0 == n // 2 else b0}: work {st.fmean(W):.0f} floor {st.fmean(F):.0f} spread {st.fmean(S):.0f}")
    print(f"{tag} (µs, mean per wave; work = slowest process, previous result -> its last PE in; spread = its first PE -> last PE):")
    print("   " + " | ".join(out))
