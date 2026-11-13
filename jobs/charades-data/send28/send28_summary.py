#!/usr/bin/env python3
"""Where an htram message's cost goes (charades RESULTS.md sections 133/134). Usage: send28_summary.py <job dir>"""
import csv, glob, statistics as st, sys
d = sys.argv[1]; mean = st.fmean
def rate(tag):
    v = [float(x["event_rate"]) / 1e6 for r in (1, 2) for f in glob.glob(f"{d}/{tag}_r{r}.csv") for x in csv.DictReader(open(f)) if x["status"] == "ok"]
    return mean(v) if v else float("nan")
print("uniform, WPs 512, W 400, long runs (µs per send, mean over PEs and 2 reps; lower is better)")
R = {}
for n in (4, 16):
    out = []
    for r in (1, 2):
        E = [{k: float(v) for k, v in x.items()} for f in glob.glob(f"{d}/T_n{n}_r{r}/ctl_sweep/exec_parts_*.csv") for x in csv.DictReader(open(f))]
        if not E: continue
        S = lambda k: sum(e[k] for e in E)
        sn, cn, an = S("send_n"), S("cmi_send_n"), S("cmi_am_n")
        o = dict(trim=1e6 * S("send_trim_s") / sn, charm=1e6 * S("send_charm_s") / sn, renew=1e6 * S("send_renew_s") / sn,
                 cmi=1e6 * S("cmi_send_s") / max(cn, 1), ipc=1e6 * S("cmi_ipc_s") / max(cn, 1), am=1e6 * S("cmi_am_s") / max(an, 1),
                 ipc_share=S("cmi_ipc_n") / max(cn, 1), cmi_per_send=cn / sn,
                 flush_msg=1e6 * S("flush_gvt_s") / max(S("flush_gvt_msgs"), 1), msgs_upd=S("flush_gvt_msgs") / max(S("gvt_done_n"), 1),
                 flush_upd=1e6 * S("flush_gvt_s") / max(S("gvt_done_n"), 1), sends_per_upd=sn / max(S("gvt_done_n"), 1))
        o["charm_own"] = o["charm"] - o["cmi"] * o["cmi_per_send"]
        o["whole"] = o["trim"] + o["charm"] + o["renew"]
        out.append(o)
    if not out: print(f"  {n} nodes: no trace"); continue
    R[n] = {k: mean(o[k] for o in out) for k in out[0]}
    x = R[n]
    print(f"  {n:>2} nodes: a send {x['whole']:.3f} = trim {x['trim']:.3f} + Charm++ send {x['charm']:.3f} + renew {x['renew']:.3f} | "
          f"inside the Charm++ send: Reconverse node send {x['cmi']:.3f} per call ({x['cmi_per_send']:.2f} calls per htram send; shared-memory attempt {x['ipc']:.3f}, "
          f"sent by shared memory {x['ipc_share']:.2f}; LCI issueAm {x['am']:.3f} per call), Charm++'s own {x['charm_own']:.3f}")
    print(f"           GVT-time flush: {x['flush_upd']:.1f} µs per update, {x['msgs_upd']:.2f} messages, {x['flush_msg']:.2f} µs per message | "
          f"traced ÷ untraced {rate(f'T_n{n}') / rate(f'off_n{n}'):.3f} (untraced {rate(f'off_n{n}'):.1f} M ev/s)")
if 4 in R and 16 in R:
    a, b = R[4], R[16]
    slope = (b["flush_upd"] - a["flush_upd"]) / (b["msgs_upd"] - a["msgs_upd"])
    print(f"\nGVT-time flush slope between 4 and 16 nodes: {slope:.2f} µs per message; a send costs {a['whole']:.2f} (4 nodes) and {b['whole']:.2f} (16 nodes)"
          f" -> sends explain {b['whole'] / slope:.0%} of the slope; fixed part per update {a['flush_upd'] - slope * a['msgs_upd']:.1f} µs")
