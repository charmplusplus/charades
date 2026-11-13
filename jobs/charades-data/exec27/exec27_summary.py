#!/usr/bin/env python3
"""Uniform: --diag-gvt-spin-ns perturbation and the GVT-result step split (charades RESULTS.md sections 131/132).
Usage: exec27_summary.py <job dir>"""
import csv, glob, statistics as st, sys
d = sys.argv[1]; mean = st.fmean
def rows(tag): return [x for r in (1, 2) for f in glob.glob(f"{d}/{tag}_r{r}.csv") for x in csv.DictReader(open(f)) if x["status"] == "ok"]
def rate(tag):
    v = [float(x["event_rate"]) / 1e6 for x in rows(tag)]; return (mean(v) if v else float("nan")), v
print("A. Spin in the GVT-result step (uniform, WPs 512, W 400, long runs; M committed ev/s, mean of 2 reps; higher is better)")
adv = {}
for n in (4, 16):
    b, _ = rate(f"A_sp0_n{n}")
    R = rows(f"A_sp0_n{n}")
    if R:
        g = lambda k: mean(float(x[k]) for x in R)
        adv[n] = 1e6 * g("exec_s") / g("gvts")  # µs per GVT update
    for sp in (0, 10000, 20000):
        r, v = rate(f"A_sp{sp}_n{n}")
        pred = 1 / (1 + sp / 1e3 / adv[n]) if n in adv else float("nan")
        print(f"  {n:>2} nodes, spin {sp // 1000:>2} µs: {r:6.1f} ({', '.join(f'{x:.1f}' for x in v)}) ÷ no spin {r / b:.3f}"
              + (f" | critical-path prediction {pred:.3f} (µs per GVT update {adv[n]:.0f})" if sp else ""))
print("\nB. The GVT-result step split (traced; per PE per GVT update, µs, and µs of PE time per committed event; lower is better)")
S = {}
for n in (4, 16):
    out = []
    for r in (1, 2):
        run = f"{d}/B_T_n{n}_r{r}/ctl_sweep"
        if not glob.glob(f"{run}/pe_stats.csv"): continue
        P = {int(x["pe"]): x for x in csv.DictReader(open(f"{run}/pe_stats.csv"))}
        E = [{k: float(v) for k, v in x.items()} for f in glob.glob(f"{run}/exec_parts_*.csv") for x in csv.DictReader(open(f))]
        com = sum(float(x["committed"]) for x in P.values()); upd = sum(e["gvt_done_n"] for e in E)
        T = lambda k: sum(e[k] for e in E)
        o = {k: T(k) for k in ("poll_s", "fossil_s", "flush_gvt_s", "ctl_gvt_s", "flush_gvt_msgs")}
        o["other_s"] = o["poll_s"] - o["fossil_s"] - o["flush_gvt_s"] - o["ctl_gvt_s"]
        out.append({**{f"{k}_upd": 1e6 * v / upd for k, v in o.items() if k.endswith("_s")},
                    **{f"{k}_ev": 1e6 * v / com for k, v in o.items() if k.endswith("_s")},
                    "msgs_upd": o["flush_gvt_msgs"] / upd})
    if not out: print(f"  {n} nodes: no trace"); continue
    S[n] = {k: mean(o[k] for o in out) for k in out[0]}
    x = S[n]
    print(f"  {n:>2} nodes: per update: poll {x['poll_s_upd']:.1f} = fossil {x['fossil_s_upd']:.1f} + GVT-time flush {x['flush_gvt_s_upd']:.1f} "
          f"({x['msgs_upd']:.2f} messages) + controller {x['ctl_gvt_s_upd']:.1f} + other {x['other_s_upd']:.1f} | per committed event: poll {x['poll_s_ev']:.3f}, "
          f"fossil {x['fossil_s_ev']:.3f}, flush {x['flush_gvt_s_ev']:.3f}, controller {x['ctl_gvt_s_ev']:.3f}, other {x['other_s_ev']:.3f}")
if 4 in S and 16 in S:
    dp = S[16]["poll_s_upd"] - S[4]["poll_s_upd"]
    print("  16 - 4 per update: " + ", ".join(f"{k[:-6]} {S[16][k] - S[4][k]:+.1f} ({(S[16][k] - S[4][k]) / dp:.0%})" for k in ("fossil_s_upd", "flush_gvt_s_upd", "ctl_gvt_s_upd", "other_s_upd"))
          + f"; poll {dp:+.1f} µs per update")
