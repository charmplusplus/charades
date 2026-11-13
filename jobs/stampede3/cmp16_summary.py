#!/usr/bin/env python3
"""Charades (23 devices) vs Devastator at 16 nodes, same allocation (charades RESULTS.md section 91/92). Usage: cmp16_summary.py <job dir>"""
import csv, glob, re, sys, statistics as st
from collections import defaultdict
d = sys.argv[1]
OLD_C = {"gauss:100:1000:100": 612.8, "gauss:100:1000:500": 558.4, "gauss:100:1000:1000": 521.6, "gauss:100:1000:2000": 363.2,
         "gauss:100:1000:4000": 312.0, "steady:100:1000:1.0": 190.4, "gauss:10:200:500": 435.2, "gauss:10:200:2000": 273.6}
OLD_D = {"gauss:100:1000:100": 667.2, "gauss:100:1000:500": 518.4, "gauss:100:1000:1000": 414.4, "gauss:100:1000:2000": 382.4,
         "gauss:100:1000:4000": 300.8, "steady:100:1000:1.0": 192.0, "gauss:10:200:500": 510.4, "gauss:10:200:2000": 361.6}
C = defaultdict(list); bad = defaultdict(int)
for f in glob.glob(f"{d}/*_r[123].csv"):
    t = re.sub(r"_r\d$", "", f.split("/")[-1][:-4])
    for x in csv.DictReader(open(f)):
        if x["status"] == "ok": C[(x["workload"], t, x["arm"])].append(float(x["event_rate"]) / 1e6)
        else: bad[(x["workload"], t, x["arm"])] += 1
D = defaultdict(list)
for line in open(f"{d}/deva/results.txt"):
    m = re.search(r"label=(hi|lo)_n16_s(\d+)_w(\d+)_r\d .*status=ok.*committed_per_s=([0-9.e+]+)", line)
    if not m: continue
    kind, s, w, r = m.groups()
    wl = ("steady:100:1000:1.0" if s == "0" else f"gauss:100:1000:{s}") if kind == "hi" else f"gauss:10:200:{s}"
    D[(wl, int(w))].append(float(r) / 1e6)
print("| workload | Charades (M ev/s) | setting | Devastator (M ev/s) | W | Charades ÷ Devastator | before (job 3639098) | Charades ÷ its 3639098 best |")
print("|---|---|---|---|---|---|---|---|")
for wl in OLD_C:
    c = max((st.median(v), t, arm, len(v)) for (w, t, arm), v in C.items() if w == wl)
    dv = max((st.median(v), w, len(v)) for (ww, w), v in D.items() if ww == wl)
    print(f"| {wl} | {c[0]:.1f} | {c[1]} {c[2]} (n={c[3]}) | {dv[0]:.1f} | {dv[1]} (n={dv[2]}) | **{c[0]/dv[0]:.2f}** | {OLD_C[wl]/OLD_D[wl]:.2f} | {c[0]/OLD_C[wl]:.2f} |")
print("\nDevastator by W (median):")
for wl in OLD_C:
    print(f"  {wl}: " + ", ".join(f"W{w} {st.median(v):.1f} (n={len(v)})" for (ww, w), v in sorted(D.items()) if ww == wl))
print("\nCharades controller ÷ Charades best fixed W (same agg as best):")
for wl in OLD_C:
    best = max((st.median(v), t) for (w, t, arm), v in C.items() if w == wl and not arm.startswith("q"))
    q = [st.median(v) for (w, t, arm), v in C.items() if w == wl and t == best[1] and arm.startswith("q")]
    print(f"  {wl}: {q[0]/best[0]:.2f} ({best[1]})" if q else f"  {wl}: n/a")
print("\nNot ok:", dict(bad))
