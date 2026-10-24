#!/usr/bin/env python3
"""Split each GVT advance into its parts from --gvt-trace (PE 0's view), medians of reps."""
import csv, glob, re, statistics as st
from collections import defaultdict
R = defaultdict(list)
for f in glob.glob("*_r[12].csv"):
    key = re.sub(r"_r[12]\.csv$", "", f)
    for r in csv.DictReader(open(f)):
        if r["status"] != "ok": continue
        t = list(csv.DictReader(open(f"{f[:-4]}/ctl_sweep/gvt_trace.csv")))
        g = lambda w, k: float(w[k])
        ok = [w for w in t if g(w, "combined_s") > 0 and g(w, "result_s") > 0]
        gather = [g(w, "combined_s") - g(w, "start_s") for w in ok]
        cross = [g(w, "result_s") - g(w, "combined_s") for w in ok]
        pick = [g(w, "end_s") - g(w, "result_s") for w in ok]
        nxt = [g(t[i + 1], "start_s") - g(t[i], "end_s") for i in range(len(t) - 1)]
        span = g(t[-1], "end_s") - g(t[0], "start_s")
        R[key].append(dict(rate=float(r["event_rate"]) / 1e6, c=int(r["committed"]),
            adv=1e6 * span / int(r["gvts"]), gather=1e6 * st.mean(gather), cross=1e6 * st.mean(cross),
            pick=1e6 * st.mean(pick), nxt=1e6 * st.mean(nxt), meanw=r["mean_window"]))
print("| run | M ev/s | committed | µs per advance | PE 0 contributes → its process combined | combined → result | result → PE 0 picks up | PE 0 picks up → contributes again | mean W |")
print("|" + "---|" * 9)
for k in sorted(R):
    v = R[k]; m = lambda f: st.median(x[f] for x in v)
    print(f"| {k} | {m('rate'):.1f} | {sorted(set(x['c'] for x in v))} | {m('adv'):.0f} | {m('gather'):.0f} | {m('cross'):.0f} | {m('pick'):.0f} | {m('nxt'):.0f} | {v[0]['meanw']} |")
