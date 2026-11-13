#!/usr/bin/env python3
"""GVT round cost (charades RESULTS.md): per-run wave stats from --gvt-trace."""
import csv, glob, re, statistics as st
from collections import defaultdict
rows = defaultdict(list)
for d in sorted(glob.glob("tr_*_r[12]")) + sorted(glob.glob("we*_r[12]")):
    t = list(csv.DictReader(open(f"{d}/ctl_sweep/gvt_trace.csv")))
    log = glob.glob(f"{d}/ctl_sweep/logs/*.out")[0]
    txt = open(log).read()
    g = lambda k: float(re.search(re.escape(k) + r"\s+([0-9.]+)", txt).group(1))
    run = list(csv.DictReader(open(f"{d}.csv")))[0]
    dur = [float(w["end_s"]) - float(w["start_s"]) for w in t]
    gap = [float(t[i + 1]["start_s"]) - float(t[i]["end_s"]) for i in range(len(t) - 1)]
    comp = [int(w["completed"]) for w in t]
    span = float(t[-1]["end_s"]) - float(t[0]["start_s"])
    key = re.sub(r"_r[12]$", "", d)
    rows[key].append(dict(
        rate=float(run["event_rate"]) / 1e6, exec=float(run["exec_s"]), gvts=g("Total GVT Computations"),
        waves=len(t), wave_us=1e6 * st.median(dur), gap_us=1e6 * st.median(gap),
        wave_share=sum(dur) / span, per_adv_us=1e6 * span / g("Total GVT Computations"),
        comp_per_wave=sum(comp) / len(t), zero=sum(c == 0 for c in comp) / len(t),
        in_exec=g("Time in execute() %"),
        blocked=g("Batches: Window Blocked") / (g("Batches: Full") + g("Batches: Window Blocked") + g("Batches: Out of Events"))))
print("| run | M ev/s | exec s | GVT advances | waves | waves per advance | µs per advance | wave (PE 0), median µs | PE 0 gap between waves, median µs | share of time inside waves | buckets completed per wave | waves completing none | time in execute() % | batches blocked by window % |")
print("|" + "---|" * 14)
for k, v in rows.items():
    m = lambda f: st.median(x[f] for x in v)
    print(f"| {k} | {m('rate'):.1f} | {m('exec'):.2f} | {m('gvts'):.0f} | {m('waves'):.0f} | {m('waves')/m('gvts'):.2f} | {m('per_adv_us'):.0f} | {m('wave_us'):.0f} | {m('gap_us'):.1f} | {m('wave_share'):.2f} | {m('comp_per_wave'):.2f} | {100*m('zero'):.0f}% | {m('in_exec'):.1f} | {100*m('blocked'):.0f} |")
print()
for l in open("redbench_results.txt"): print(l.strip())
