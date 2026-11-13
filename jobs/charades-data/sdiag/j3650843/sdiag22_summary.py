#!/usr/bin/env python3
"""Warm-up pings, long runs, closure on uniform and sigma 4,000 (charades RESULTS.md sections 121/122).
Usage: sdiag22_summary.py <job dir>"""
import csv, glob, statistics as st, sys
d = sys.argv[1]; mean = st.fmean
def rows(tag): return [x for f in glob.glob(f"{d}/{tag}.csv") for x in csv.DictReader(open(f)) if x["status"] == "ok"]
def m(fmt, key="event_rate", scale=1e-6):
    v = [float(x[key]) * scale for r in (1, 2) for x in rows(fmt.format(r=r))]
    return (mean(v) if v else float("nan")), v
def closure(tag):
    out = []
    for r in (1, 2):
        rr = rows(f"{tag}_r{r}")
        f = glob.glob(f"{d}/{tag}_r{r}/ctl_sweep/gvt_waves_0.csv")
        if not rr or not f: continue
        res = [float(x["result_s"]) for x in csv.DictReader(open(f[0]))]; n = len(res)
        adv = [b - a for a, b in zip(res, res[1:])]; lo, hi = n // 10, n * 95 // 100
        out.append((float(rr[0]["exec_s"]), sum(adv[:lo]), sum(adv[lo:hi]), sum(adv[hi:])))
    return [mean(c) for c in zip(*out)] if out else None

print("A/B. σ 2,000, W 400, PP 512 (M committed ev/s, mean of 2 reps; higher is better); exec_s in s (lower is better)")
for length, p in (("short (end 512,000)", "A"), ("long (end 2,048,000)", "B")):
    for wp in (0, 1):
        r4, v4 = m(f"{p}_w{wp}_n4_r{{r}}"); r16, v16 = m(f"{p}_w{wp}_n16_r{{r}}")
        e4, _ = m(f"{p}_w{wp}_n4_r{{r}}", "exec_s", 1); e16, _ = m(f"{p}_w{wp}_n16_r{{r}}", "exec_s", 1)
        w4, _ = m(f"{p}_w{wp}_n4_r{{r}}", "wall_s", 1); w16, _ = m(f"{p}_w{wp}_n16_r{{r}}", "wall_s", 1)
        print(f"  {length:22} warm-up {wp}: 4 nodes {r4:6.1f} ({', '.join(f'{x:.1f}' for x in v4)}), 16 nodes {r16:6.1f} ({', '.join(f'{x:.1f}' for x in v16)}), "
              f"efficiency 4->16 {r16 / (4 * r4):.3f} | exec_s {e4:.3f} / {e16:.3f}, wall_s {w4:.2f} / {w16:.2f}")
for p, wp in (("A", 1), ("B", 0), ("B", 1)):
    for n in (4, 16):
        b, _ = m(f"A_w0_n{n}_r{{r}}"); x, _ = m(f"{p}_w{wp}_n{n}_r{{r}}")
        print(f"  {n:>2} nodes, {'long' if p == 'B' else 'short'} warm-up {wp} ÷ short warm-up 0: {x / b:.3f}")

print("\nClosure (traced, mean of 2 reps; s; lower is better): exec_s | first 10% of waves | waves 10-95% | last 5%")
for tag in ("AT_w0_n16", "AT_w1_n16", "BT_w0_n16", "CT_s4k_n4", "CT_s4k_n16", "CT_uni_n4", "CT_uni_n16"):
    c = closure(tag)
    print(f"  {tag:11}: " + (" | ".join(f"{x:.3f}" for x in c) if c else "no trace"))
for wl in ("s4k", "uni"):
    a, b = closure(f"CT_{wl}_n4"), closure(f"CT_{wl}_n16")
    if a and b:
        dt = b[0] - a[0]
        print(f"  {wl}: 16 - 4 nodes: exec_s +{dt:.3f} s; first 10% +{b[1] - a[1]:.3f} ({(b[1] - a[1]) / dt:.0%}), "
              f"10-95% +{b[2] - a[2]:.3f} ({(b[2] - a[2]) / dt:.0%}), last 5% {b[3] - a[3]:+.3f}; steady efficiency {a[2] / b[2]:.3f}")

print("\nC. Warm-up on uniform (WPs 512) and σ 4,000 (PP 512), W 400, short runs (M committed ev/s; higher is better)")
for wl in ("uni", "s4k"):
    for n in (4, 16):
        a, av = m(f"C_{wl}_w0_n{n}_r{{r}}"); b, bv = m(f"C_{wl}_w1_n{n}_r{{r}}")
        print(f"  {wl:3} {n:>2} nodes: warm-up 0 {a:6.1f} ({', '.join(f'{x:.1f}' for x in av)}), 1 {b:6.1f} ({', '.join(f'{x:.1f}' for x in bv)}), ratio {b / a:.3f}")
    a4, _ = m(f"C_{wl}_w0_n4_r{{r}}"); a16, _ = m(f"C_{wl}_w0_n16_r{{r}}"); b4, _ = m(f"C_{wl}_w1_n4_r{{r}}"); b16, _ = m(f"C_{wl}_w1_n16_r{{r}}")
    print(f"  {wl:3} efficiency 4->16: warm-up 0 {a16 / (4 * a4):.3f}, warm-up 1 {b16 / (4 * b4):.3f}")
