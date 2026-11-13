#!/usr/bin/env python3
"""htram mode/buffer selection (charades RESULTS.md section 65/66). Usage: hsel_summary.py n16"""
import csv, glob, re, sys, statistics as st
from collections import defaultdict
d = sys.argv[1]
R = defaultdict(list)  # (workload, agg) -> {arm: [rates]}
C = defaultdict(set)
for f in glob.glob(f"{d}/[hl][io]_*_r[12].csv"):
    for x in csv.DictReader(open(f)):
        if x["status"] != "ok": continue
        R[(x["workload"], x["agg"], x["arm"])].append(float(x["event_rate"]) / 1e6)
        C[x["workload"]].add(x["committed"])
dv = defaultdict(list)
for l in open(f"{d}/deva/results.txt"):
    if "PHOLD_GAUSS_RESULT" not in l or "status=ok" not in l: continue
    kv = dict(t.split("=", 1) for t in l.split() if "=" in t)
    wl = ("steady:100:1000:1.0" if float(kv["remote"]) == 1.0 else f"gauss:{kv['lookahead']}:{kv['mean']}:{kv['sigma']}")
    dv[(wl, kv["window"])].append(float(kv["committed_per_s"]) / 1e6)
wls = ["gauss:100:1000:100", "gauss:100:1000:500", "gauss:100:1000:1000", "gauss:100:1000:2000",
       "gauss:100:1000:4000", "steady:100:1000:1.0", "gauss:10:200:500", "gauss:10:200:2000"]
aggs = ["pp:128", "pp:512", "pp:2048", "wps:128", "wps:512", "wps:2048"]
def best(wl, agg):
    v = [(st.median(r), arm) for (w, a, arm), r in R.items() if w == wl and a == agg]
    return max(v) if v else (float("nan"), "")
print("| workload | PP 512 (M ev/s) | " + " | ".join(a.upper().replace(":", " ") for a in aggs) + " | best | best ÷ PP 512 | Devastator best (M ev/s) | Charades best ÷ Devastator | committed equal |")
print("|---|---|" + "---|" * len(aggs) + "---|---|---|---|---|")
for wl in wls:
    base = best(wl, "pp:512")[0]
    b = {a: best(wl, a) for a in aggs}
    top = max(aggs, key=lambda a: b[a][0])
    dvb = max((st.median(v) for (w, _), v in dv.items() if w == wl), default=float("nan"))
    print(f"| {wl} | {base:.1f} | " + " | ".join(f"{b[a][0]/base:.2f}" for a in aggs) +
          f" | {top} ({b[top][1]}) | {b[top][0]/base:.2f} | {dvb:.1f} | {b[top][0]/dvb:.2f} | {'yes' if len(C[wl])==1 else 'NO'} |")
