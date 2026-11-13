#!/usr/bin/env python3
"""execute() split into parts on uniform and sigma 4,000 at 4 and 16 nodes (charades RESULTS.md sections 127/128).
Usage: exec25_summary.py <job dir>"""
import csv, glob, statistics as st, sys
d = sys.argv[1]; mean = st.fmean
def rate(tag): 
    v = [float(x["event_rate"]) / 1e6 for r in (1, 2) for f in glob.glob(f"{d}/{tag}_r{r}.csv") for x in csv.DictReader(open(f)) if x["status"] == "ok"]
    return mean(v) if v else float("nan")
K = ["exec", "loop", "handlers", "send_total", "produce", "fp", "fp_miss", "remote", "local", "flush_idle", "cancel_q", "poll", "drain", "untimed", "iter_end"]
def parts(tag):
    out = []
    for r in (1, 2):
        run = f"{d}/{tag}_r{r}/ctl_sweep"
        if not glob.glob(f"{run}/pe_stats.csv"): continue
        P = {int(x["pe"]): x for x in csv.DictReader(open(f"{run}/pe_stats.csv"))}
        E = {}
        for f in glob.glob(f"{run}/exec_parts_*.csv"):
            for x in csv.DictReader(open(f)): E[int(x["pe"])] = {k: float(v) for k, v in x.items()}
        com = sum(float(x["committed"]) for x in P.values()); exe = sum(float(x["executed"]) for x in P.values())
        S = lambda k: sum(e[k] for e in E.values())
        ex = sum(float(x["exec_s"]) for x in P.values())
        o = {"exec": ex, "loop": S("loop_s"), "send_total": S("send_total_s"), "produce": S("produce_s"), "fp": S("fp_s"),
             "fp_miss": S("fp_miss_s"), "remote": S("remote_s"), "local": S("local_s"), "flush_idle": S("flush_idle_s"),
             "cancel_q": S("cancel_q_s"), "poll": S("poll_s"), "drain": S("drain_s"), "iter_end": S("iter_end_s")}
        o["handlers"] = o["loop"] - o["send_total"] - o["local"]
        o["untimed"] = ex - o["loop"] - o["flush_idle"] - o["cancel_q"] - o["poll"] - o["drain"]
        pc = {k: 1e6 * v / com for k, v in o.items()}
        pc["handlers_per_exec"] = 1e6 * o["handlers"] / exe
        pc["remote_each"] = 1e6 * o["remote"] / max(S("remote_n"), 1); pc["fp_share"] = S("fp_n") / max(S("fp_n") + S("remote_n"), 1)
        pc["flush_each"] = 1e6 * o["flush_idle"] / max(S("flush_idle_n"), 1); pc["flush_per_ev"] = S("flush_idle_n") / com
        pc["cover"] = (ex - o["untimed"]) / ex
        out.append(pc)
    return {k: mean(o[k] for o in out) for k in out[0]} if out else None
for wl, name in (("uni", "uniform, WPs 512"), ("s4k", "σ 4,000, PP 512")):
    print(f"{name}, W 400 (µs per committed event, mean of 2 reps; lower is better)")
    A, B = parts(f"T_{wl}_n4"), parts(f"T_{wl}_n16")
    if not A or not B: print("  no traces"); continue
    print("  " + " | ".join(f"{k}" for k in K))
    for n, X in ((4, A), (16, B)):
        print(f"  {n:>2} nodes: " + " ".join(f"{X[k]:.3f}" for k in K) + f" | handlers per executed event {X['handlers_per_exec']:.3f}, remote send each {X['remote_each']:.3f}, "
              f"fast-path share {X['fp_share']:.3f}, idle flush each {X['flush_each']:.3f} ({X['flush_per_ev']:.3f} per event), timed share of exec {X['cover']:.3f}")
    dex = B["exec"] - A["exec"]
    print(f"  16 - 4: exec {dex:+.3f}; " + ", ".join(f"{k} {B[k] - A[k]:+.3f} ({(B[k] - A[k]) / dex:.0%})" for k in K[1:] if k != "exec"))
    for n in (4, 16):
        print(f"  {n:>2} nodes traced ÷ untraced: {rate(f'T_{wl}_n{n}') / rate(f'off_{wl}_n{n}'):.3f} (untraced {rate(f'off_{wl}_n{n}'):.1f} M ev/s)")
