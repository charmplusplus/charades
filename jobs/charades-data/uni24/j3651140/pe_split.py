#!/usr/bin/env python3
"""Closure over PE time: per committed event, the whole run's PE time split into execute() (minus input-buffer
drains), drains, htram receive handlers, and the rest (runtime loop and idle) (charades RESULTS.md section 126).
Usage: pe_split.py <job dir> <tag> ...   (runs with --pe-stats=1 --gvt-trace>=3)"""
import csv, glob, sys, statistics as st
d = sys.argv[1]; mean = st.fmean
for tag in sys.argv[2:]:
    out = []
    for run in sorted(glob.glob(f"{d}/{tag}_r*/ctl_sweep")):
        P = {int(x["pe"]): x for x in csv.DictReader(open(f"{run}/pe_stats.csv"))}
        R = {}
        for f in glob.glob(f"{run}/recv_parts_*.csv"):
            for x in csv.DictReader(open(f)): R[int(x["pe"])] = x
        com = sum(float(x["committed"]) for x in P.values()); npe = len(P)
        tot = sum(float(x["total_s"]) for x in P.values()); ex = sum(float(x["exec_s"]) for x in P.values())
        dr = sum(float(R[p]["drain_s"]) for p in P if p in R); rc = sum(float(R[p]["total_s"]) for p in P if p in R)
        items = sum(float(R[p]["items"]) for p in P if p in R); calls = sum(float(R[p]["calls"]) for p in P if p in R)
        full = sum(float(x["batches_full"]) for x in P.values()); win = sum(float(x["batches_window"]) for x in P.values())
        emp = sum(float(x["batches_empty"]) for x in P.values()); exe = sum(float(x["executed"]) for x in P.values())
        us = lambda s: 1e6 * s / com
        out.append(dict(pes=npe, total=us(tot), exec_nodrain=us(ex - dr), drain=us(dr), recv=us(rc), rest=us(tot - ex - rc),
                        full=full / com, window=win / com, empty=emp / com, recv_calls=calls / com, items_per_call=items / max(calls, 1),
                        exec_per_executed=1e6 * (ex - dr) / exe))
    if not out: print(f"{tag}: no data"); continue
    g = lambda k: mean(o[k] for o in out)
    print(f"{tag} ({out[0]['pes']} PEs, {len(out)} reps): PE time per committed event {g('total'):.3f} µs = execute() without drains {g('exec_nodrain'):.3f} "
          f"+ input-buffer drains {g('drain'):.3f} + htram receives {g('recv'):.3f} + rest {g('rest'):.3f} | per committed event: full passes {g('full'):.4f}, "
          f"window-blocked passes {g('window'):.4f}, empty passes {g('empty'):.4f}, htram receives {g('recv_calls'):.4f} ({g('items_per_call'):.1f} items each) | "
          f"execute() without drains per executed event {g('exec_per_executed'):.3f} µs")
