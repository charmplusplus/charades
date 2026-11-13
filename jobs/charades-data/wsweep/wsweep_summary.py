#!/usr/bin/env python3
"""Window sweep at 16/32 nodes: medians over reps of ok runs (M committed ev/s)."""
import csv, glob, re, statistics as st, sys
from collections import defaultdict
N = sys.argv[1] if len(sys.argv) > 1 else "16"
d = defaultdict(list)
for f in glob.glob(f"*_n{N}_r*.csv"):
    tag = f.split("_n")[0]
    for r in csv.DictReader(open(f)):
        d[(r["workload"], tag + ":" + r["arm"])].append(r)
for wl in ("gauss:100:1000:100", "gauss:100:1000:2000", "steady:100:1000:1.0"):
    print(wl)
    for k in sorted(k for k in d if k[0] == wl):
        rs = [r for r in d[k] if r["status"] == "ok"]
        if not rs: print(f"  {k[1]:22s} 0 of {len(d[k])} ok"); continue
        m = lambda c: st.median(float(r[c]) for r in rs)
        print(f"  {k[1]:22s} {len(rs)} of {len(d[k])} {m('event_rate')/1e6:7.1f} eff {m('efficiency'):6.2f} meanW {m('mean_window'):6.0f} epm {m('agg_events_per_msg'):5.0f}")
dv = defaultdict(list)
for l in open("deva/results.txt"):
    kv = dict(t.split("=", 1) for t in l.split() if "=" in t)
    if kv["label"].startswith(f"deva_n{N}_") and kv["status"].startswith("ok") and "committed_per_s" in kv:
        dv[re.sub(r"_r\d+$", "", kv["label"])].append(float(kv["committed_per_s"]) / 1e6)
for k, v in sorted(dv.items()): print(k, len(v), round(st.median(v), 1))
