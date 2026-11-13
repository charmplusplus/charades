#!/usr/bin/env python3
"""The post and the poll inside each send; +lci_send_progress 0 (charades RESULTS.md sections 135/136). Usage: send29_summary.py <job dir>"""
import csv, glob, statistics as st, sys
d = sys.argv[1]; mean = st.fmean
def rate(tag):
    v = [float(x["event_rate"]) / 1e6 for r in (1, 2) for f in glob.glob(f"{d}/{tag}_r{r}.csv") for x in csv.DictReader(open(f)) if x["status"] == "ok"]
    return (mean(v) if v else float("nan")), v
print("A. Uniform, WPs 512, W 400, long runs (M committed ev/s, mean of 2 reps; higher is better)")
for n in (4, 16):
    a, av = rate(f"off_sp1_n{n}"); b, bv = rate(f"off_sp0_n{n}")
    print(f"  {n:>2} nodes: send progress on {a:6.1f} ({', '.join(f'{x:.1f}' for x in av)}), off {b:6.1f} ({', '.join(f'{x:.1f}' for x in bv)}), off ÷ on {b / a:.3f}")
print("\nB. Inside a send (traced; µs per htram send or per issueAm call, mean over PEs and 2 reps; lower is better)")
for n in (4, 16):
    for sp in (1, 0):
        out = []
        for r in (1, 2):
            E = [{k: float(v) for k, v in x.items()} for f in glob.glob(f"{d}/T_sp{sp}_n{n}_r{r}/ctl_sweep/exec_parts_*.csv") for x in csv.DictReader(open(f))]
            if not E: continue
            S = lambda k: sum(e[k] for e in E)
            am = max(S("cmi_am_n"), 1); sn = max(S("send_n"), 1); upd = max(S("gvt_done_n"), 1)
            out.append(dict(send=1e6 * (S("send_trim_s") + S("send_charm_s") + S("send_renew_s")) / sn, am=1e6 * S("cmi_am_s") / am,
                            post=1e6 * S("cmi_post_s") / am, prog=1e6 * S("cmi_progress_s") / am, posts_per=S("cmi_post_n") / am,
                            prog_per=S("cmi_progress_n") / am, did=S("cmi_progress_did_n") / max(S("cmi_progress_n"), 1),
                            prog_each=1e6 * S("cmi_progress_s") / max(S("cmi_progress_n"), 1),
                            flush_upd=1e6 * S("flush_gvt_s") / upd, msgs_upd=S("flush_gvt_msgs") / upd, poll=1e6 * S("poll_s") / upd))
        if not out: print(f"  {n} nodes, progress {sp}: no trace"); continue
        x = {k: mean(o[k] for o in out) for k in out[0]}
        print(f"  {n:>2} nodes, send progress {'on ' if sp else 'off'}: a send {x['send']:.2f}; issueAm {x['am']:.2f} = post {x['post']:.2f} ({x['posts_per']:.2f} posts per call) "
              f"+ progress {x['prog']:.2f} ({x['prog_per']:.2f} calls per issueAm, {x['prog_each']:.2f} each, {x['did']:.2f} of them completed something) | "
              f"GVT-time flush {x['flush_upd']:.1f} µs per update ({x['msgs_upd']:.2f} messages), whole GVT step {x['poll']:.1f}")
print("\nC. Other workloads, 16 nodes, long runs (off ÷ on; higher is better)")
for tag, nm in (("s2k", "σ 2,000, PP 512, W 400"), ("s100", "σ 100, PP 2,048, controller")):
    a, av = rate(f"C_{tag}_sp1"); b, bv = rate(f"C_{tag}_sp0")
    print(f"  {nm:28}: on {a:6.1f} ({', '.join(f'{x:.1f}' for x in av)}), off {b:6.1f} ({', '.join(f'{x:.1f}' for x in bv)}), {b / a:.3f}")
