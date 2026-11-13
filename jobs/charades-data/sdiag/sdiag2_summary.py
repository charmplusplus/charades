#!/usr/bin/env python3
"""Allocator, slow node in both engines, wider-window cost (charades RESULTS.md section 81/82). Usage: sdiag2_summary.py <job dir>"""
import csv, glob, re, sys, statistics as st
from collections import defaultdict, Counter
d = sys.argv[1]; med = st.median
def rows(pat):
    for f in glob.glob(f"{d}/{pat}"):
        for x in csv.DictReader(open(f)):
            if x["status"] == "ok": yield f.split("/")[-1][:-4], x
print("M. Allocator settings, 16 nodes, W 250 (M ev/s, median of 3; ÷ PP 512 with no setting; events/msg; efficiency)\n")
M = defaultdict(list)
for tag, x in rows("M_*.csv"):
    M[(x["workload"], re.match(r"M_(\w+?)_r\d", tag).group(1))].append((float(x["event_rate"]) / 1e6, float(x["agg_events_per_msg"]), float(x["efficiency"])))
vs = ["base", "mmap", "pad", "cap", "capmmap"]
print("| workload | " + " | ".join(vs) + " |"); print("|---" * (len(vs) + 1) + "|")
for wl in ["gauss:100:1000:100", "gauss:100:1000:2000"]:
    b = med(a[0] for a in M[(wl, "base")])
    print(f"| {wl} | " + " | ".join(f"{med(a[0] for a in M[(wl, v)]):.1f} ({med(a[0] for a in M[(wl, v)])/b:.2f}; {med(a[1] for a in M[(wl, v)]):.0f}; {med(a[2] for a in M[(wl, v)]):.2f})" for v in vs) + " |")
print("\nS. 15 nodes without and with c455-081 (M ev/s, median of 3; without ÷ with)\n")
S = defaultdict(list)
for tag, x in rows("S_*.csv"):
    S[("charades", x["workload"], x["arm"], re.match(r"S_(\w+?)_r\d", tag).group(1))].append(float(x["event_rate"]) / 1e6)
for line in open(f"{d}/deva/results.txt"):
    m = re.search(r"label=S_(with|without)_n15_s(\d+)_w(\d+)_r\d .*status=ok.*committed_per_s=([0-9.e+]+)", line)
    if m: S[("devastator", f"gauss:100:1000:{m.group(2)}", "w:" + m.group(3), m.group(1))].append(float(m.group(4)) / 1e6)
print("| engine | workload | W | without | with | without ÷ with |"); print("|---" * 6 + "|")
for k in sorted({k[:3] for k in S}):
    a, b = S.get(k + ("without",)), S.get(k + ("with",))
    if a and b: print(f"| {k[0]} | {k[1]} | {k[2]} | {med(a):.1f} | {med(b):.1f} | {med(a)/med(b):.3f} |")
print("\nW. Wider windows, 16 nodes, PP 512 (median of 2 reps; µs per advance etc. from the per-process traces)\n")
print("| workload | W | M ev/s | efficiency % | advances | µs/advance (mean) | reduction floor | straggler cost | rolled back (M events) | busiest process (µs/event ÷ median) |")
print("|---" * 10 + "|")
for wl in ["gauss_100_1000_100", "gauss_100_1000_2000"]:
    for w in [250, 400, 600]:
        reps = []
        for rep in (1, 2):
            dd = f"{d}/W_{wl}_w{w}_r{rep}"
            c = list(csv.DictReader(open(f"{dd}.csv")))
            if not c or c[0]["status"] != "ok": continue
            x = c[0]
            files = sorted(glob.glob(f"{dd}/ctl_sweep/gvt_waves_*.csv"), key=lambda f: int(re.search(r"_(\d+)\.csv", f).group(1)))
            P = [list(csv.DictReader(open(f))) for f in files]
            k = min(len(p) for p in P); lo, hi = max(1, k // 10), k - k // 20
            adv, floor, strag = [], [], []
            for i in range(lo, hi):
                work = [float(p[i]["last_s"]) - float(p[i - 1]["result_s"]) for p in P]
                wait = [float(p[i]["result_s"]) - float(p[i]["last_s"]) for p in P]
                adv.append(med([float(p[i]["result_s"]) - float(p[i - 1]["result_s"]) for p in P]))
                floor.append(min(wait)); strag.append(max(work) - med(work))
            ps = list(csv.DictReader(open(f"{dd}/ctl_sweep/pe_stats.csv")))
            pr = defaultdict(lambda: [0.0, 0.0])
            for y in ps: pr[int(y["process"])][0] += float(y["exec_s"]); pr[int(y["process"])][1] += float(y["executed"])
            us = {p: v[0] / v[1] for p, v in pr.items()}; mu = med(us.values()); top = max(us, key=us.get)
            reps.append((float(x["event_rate"]) / 1e6, float(x["efficiency"]), int(x["gvts"]), st.fmean(adv) * 1e6, st.fmean(floor) * 1e6,
                         st.fmean(strag) * 1e6, float(x["rolled_back"]) / 1e6, f"p{top} {us[top]/mu:.3f}"))
        if reps:
            print(f"| {wl} | {w} | " + " | ".join(f"{med(r[j] for r in reps):.{p}f}" for j, p in [(0, 1), (1, 2), (2, 0), (3, 0), (4, 0), (5, 0), (6, 2)]) + f" | {', '.join(r[7] for r in reps)} |")
