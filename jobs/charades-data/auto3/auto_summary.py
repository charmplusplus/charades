#!/usr/bin/env python3
"""--agg-auto against fixed htram settings (charades RESULTS.md section 69/70). Usage: auto_summary.py n16"""
import csv, glob, re, sys, statistics as st
from collections import defaultdict
d = sys.argv[1]
R = defaultdict(list); C = defaultdict(set); DEC = defaultdict(set)
for f in glob.glob(f"{d}/[hl][io]_*_r[12].csv"):
    tag = re.match(r".*/(?:hi|lo)_(\w+?)_r\d\.csv", f).group(1)
    for x in csv.DictReader(open(f)):
        if x["status"] != "ok": continue
        R[(x["workload"], tag, x["arm"])].append(float(x["event_rate"]) / 1e6)
        C[x["workload"]].add(x["committed"])
        if tag.endswith("auto"):
            log = glob.glob(f[:-4] + f"/ctl_sweep/logs/*_{x['arm'].replace(':','')}.out")
            if log:
                m = re.search(r"Aggregation auto: after .*?: (.*)", open(log[0]).read())
                if m: DEC[x["workload"]].add(m.group(1).strip())
wls = ["gauss:100:1000:100", "gauss:100:1000:500", "gauss:100:1000:1000", "gauss:100:1000:2000",
       "gauss:100:1000:4000", "steady:100:1000:1.0", "gauss:10:200:500", "gauss:10:200:2000"]
tags = ["pp512", "pp2048", "wps512", "pp512auto"]
def best(wl, t):
    v = [(st.median(r), a) for (w, tt, a), r in R.items() if w == wl and tt == t]
    return max(v) if v else (float("nan"), "")
print("| workload | PP 512 (M ev/s) | PP 2,048 ÷ PP 512 | WPs 512 ÷ PP 512 | `--agg-auto` ÷ PP 512 | `--agg-auto` ÷ best fixed | choice | committed equal |")
print("|---|---|---|---|---|---|---|---|")
for wl in wls:
    b = {t: best(wl, t) for t in tags}
    base = b["pp512"][0]; bf = max(b[t][0] for t in tags[:3])
    print(f"| {wl} | {base:.1f} | {b['pp2048'][0]/base:.2f} | {b['wps512'][0]/base:.2f} | {b['pp512auto'][0]/base:.2f} | "
          f"{b['pp512auto'][0]/bf:.2f} | {'; '.join(sorted(DEC[wl]))} | {'yes' if len(C[wl])==1 else 'NO'} |")
