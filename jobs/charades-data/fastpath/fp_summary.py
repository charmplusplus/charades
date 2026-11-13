#!/usr/bin/env python3
"""--local-fast-path results (charades RESULTS.md section 61/62): off vs on."""
import csv, glob, re, statistics as st
from collections import defaultdict
runs = defaultdict(list)   # (fp, N, sigma, arm) -> rows
for f in glob.glob("fp[01]_n*_s*_r[12].csv"):
    fp, N, s = re.match(r"fp(\d)_n(\d+)_s(\d+)_r\d", f).groups()
    for r in csv.DictReader(open(f)):
        if r["status"] != "ok": print("not ok:", f, r["arm"], r["status"]); continue
        d = f[:-4]
        logs = glob.glob(f"{d}/ctl_sweep/logs/*{r['arm'].replace(':','')}*.out")
        txt = open(logs[0]).read() if logs else ""
        g = lambda k: float(m.group(1)) if (m := re.search(re.escape(k) + r"\s+([0-9.]+)", txt)) else float("nan")
        runs[(int(fp), int(N), int(s), r["arm"])].append(dict(
            rate=float(r["event_rate"]) / 1e6, committed=int(r["committed"]), eff=float(r["efficiency"]),
            gvts=int(r["gvts"]), epm=float(r["agg_events_per_msg"] or "nan"), w=r["mean_window"],
            rb=int(r["rolled_back"]), fast=g("Process Sends (fast path)"), remote=g("Remote Sends")))
m = lambda v, k: st.median(x[k] for x in v)
print("| nodes, σ, arm | off: M ev/s | on: M ev/s | on ÷ off | efficiency % off / on | events per htram message off / on | GVT advances off / on | share of remote sends by pointer | committed equal |")
print("|---|---|---|---|---|---|---|---|---|")
for (fp, N, s, arm) in sorted(k for k in runs if k[0] == 0):
    a, b = runs[(0, N, s, arm)], runs.get((1, N, s, arm), [])
    if not b: continue
    eq = len({x["committed"] for x in a + b}) == 1
    print(f"| {N}, σ {s:,}, {arm} | {m(a,'rate'):.1f} | {m(b,'rate'):.1f} | {m(b,'rate')/m(a,'rate'):.2f} | "
          f"{m(a,'eff'):.2f} / {m(b,'eff'):.2f} | {m(a,'epm'):.0f} / {m(b,'epm'):.0f} | {m(a,'gvts'):.0f} / {m(b,'gvts'):.0f} | "
          f"{m(b,'fast')/m(b,'remote'):.3f} | {'yes' if eq else 'NO'} |")
