#!/usr/bin/env python3
"""Weak scaling 1-16 nodes in one allocation (charades RESULTS.md section 77). Usage: scale_summary.py <job dir>"""
import csv, glob, re, sys, statistics as st
from collections import defaultdict
d = sys.argv[1]
C = defaultdict(list)   # (wl, N, tag, arm) -> [(rate, m, eff, gvts, exec)]
for f in glob.glob(f"{d}/*.csv"):
    tag = f.split("/")[-1][:-4]
    if tag.startswith(("warm", "comm")): continue
    for x in csv.DictReader(open(f)):
        if x["status"] != "ok": continue
        t = re.sub(r"_n\d+_r\d$|_r\d$", "", tag)
        C[(x["workload"], int(x["nodes"]), t, x["arm"])].append(
            (float(x["event_rate"]) / 1e6, float(x["agg_events_per_msg"] or 0), float(x["efficiency"]), int(x["gvts"]), float(x["exec_s"])))
D = defaultdict(list)   # (wl, N, W) -> rates
for line in open(f"{d}/deva/results.txt"):
    m = re.search(r"label=(hi|lo)_n(\d+)_s(\d+)_w(\d+)_r\d .*status=ok.*committed_per_s=([0-9.e+]+)", line)
    if not m: continue
    kind, n, s, w, r = m.groups()
    wl = ("steady:100:1000:1.0" if s == "0" else f"gauss:100:1000:{s}") if kind == "hi" else f"gauss:10:200:{s}"
    D[(wl, int(n), int(w))].append(float(r) / 1e6)
wls = ["gauss:100:1000:100", "gauss:100:1000:500", "gauss:100:1000:1000", "gauss:100:1000:2000",
       "gauss:100:1000:4000", "steady:100:1000:1.0", "gauss:10:200:500", "gauss:10:200:2000"]
Ns = [1, 2, 4, 8, 16]
def cbest(wl, n, pre=("hi_", "lo_", "uni_", "lo2k_")):
    v = [(st.median(a[0] for a in r), t, arm, st.median(a[1] for a in r), st.median(a[3] for a in r), st.median(a[4] for a in r))
         for (w, nn, t, arm), r in C.items() if w == wl and nn == n and t.startswith(pre)]
    return max(v) if v else (float("nan"),) * 6
def dbest(wl, n):
    v = [(st.median(r), w) for (ww, nn, w), r in D.items() if ww == wl and nn == n]
    return max(v) if v else (float("nan"), 0)
print("M committed events/s per node, each engine at its best setting (median of 2; higher is better)\n")
print("| workload | engine | " + " | ".join(f"{n} node{'s' if n > 1 else ''}" for n in Ns) + " | 16 ÷ 4 nodes (efficiency) | 16 ÷ 1 node |")
print("|---" * (len(Ns) + 4) + "|")
for wl in wls:
    c = {n: cbest(wl, n)[0] / n for n in Ns}; dv = {n: dbest(wl, n)[0] / n for n in Ns}
    for name, r in (("Charades", c), ("Devastator", dv)):
        print(f"| {wl} | {name} | " + " | ".join(f"{r[n]:.1f}" for n in Ns) + f" | {r[16]/r[4]:.2f} | {r[16]/r[1]:.2f} |")
print("\nCharades ÷ Devastator (each at its best; higher is better)\n")
print("| workload | " + " | ".join(f"{n}" for n in Ns) + " |"); print("|---" * (len(Ns) + 1) + "|")
for wl in wls:
    print(f"| {wl} | " + " | ".join(f"{cbest(wl, n)[0]/dbest(wl, n)[0]:.2f}" for n in Ns) + " |")
print("\nCharades best setting per N: setting / arm; events per htram message; GVT advances; exec s\n")
for wl in wls:
    print(wl, " ; ".join(f"N{n}: {b[1]} {b[2]} m={b[3]:.1f} gvts={b[4]:.0f} t={b[5]:.2f}" for n in Ns for b in [cbest(wl, n)]))
print("\nDevastator best W per N:", {wl: [dbest(wl, n)[1] for n in Ns] for wl in wls})
print("\nOne process per node vs two at 16 nodes (M ev/s, best arm; events per message)\n")
for wl in ["gauss:100:1000:2000", "gauss:100:1000:4000", "steady:100:1000:1.0", "gauss:10:200:2000"]:
    for agg in ("pp512", "pp2048"):
        r = {}
        for ppn in (1, 2):
            v = [(st.median(a[0] for a in x), st.median(a[1] for a in x), st.median(a[2] for a in x), arm)
                 for (w, nn, t, arm), x in C.items() if w == wl and t in (f"ppn{ppn}_hi_{agg}", f"ppn{ppn}_lo_{agg}")]
            r[ppn] = max(v) if v else (float("nan"),) * 4
        print(f"{wl} {agg}: 1/node {r[1][0]:.1f} (m {r[1][1]:.1f}, eff {r[1][2]:.2f}, {r[1][3]}) | 2/node {r[2][0]:.1f} (m {r[2][1]:.1f}, eff {r[2][2]:.2f}, {r[2][3]}) | ratio {r[1][0]/r[2][0]:.2f}")
