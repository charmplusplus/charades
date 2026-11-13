#!/usr/bin/env python3
"""Uniform: WPs buffer-size perturbation (charades RESULTS.md sections 125/126). Usage: uni24_summary.py <job dir>"""
import csv, glob, statistics as st, sys
d = sys.argv[1]; mean = st.fmean
def rows(tag): return [x for r in (1, 2) for f in glob.glob(f"{d}/{tag}_r{r}.csv") for x in csv.DictReader(open(f)) if x["status"] == "ok"]
def agg(tag):
    R = rows(tag)
    if not R: return None
    g = lambda k: mean(float(x[k]) for x in R)
    rate = g("event_rate") / 1e6; pes = int(R[0]["pes"])
    return dict(rate=rate, reps=[float(x["event_rate"]) / 1e6 for x in R], epm=g("agg_events_per_msg"),
                rs=g("remote_sends") / g("committed"), pet=pes / rate, eff=g("efficiency"))
print("Uniform, W 400, short runs (mean of 2 reps). rate M committed ev/s (higher is better); PE time per committed event µs (lower is better)")
base4, base16 = agg("A_b512_n4"), agg("B_b512_n16")
for tag, b0 in [(f"A_b{b}_n4", base4) for b in (512, 64, 32, 16)] + [(f"B_b{b}_n16", base16) for b in (512, 16)]:
    a = agg(tag)
    if not a: print(f"  {tag}: no data"); continue
    mpe = a["rs"] / a["epm"]
    print(f"  {tag:10}: rate {a['rate']:6.1f} ({', '.join(f'{x:.1f}' for x in a['reps'])}) ÷ WPs 512 {a['rate'] / b0['rate']:.3f} | events/msg {a['epm']:5.1f}, "
          f"messages per event {mpe:.4f} | PE time per event {a['pet']:.3f} µs | efficiency {a['eff']:.3f}")
a16 = agg("A_b16_n4")
if a16 and base4 and base16:
    m = lambda a: a["rs"] / a["epm"]
    s4 = (a16["pet"] - base4["pet"]) / (m(a16) - m(base4)); s416 = (base16["pet"] - base4["pet"]) / (m(base16) - m(base4))
    print(f"\nSlope, extra PE time per extra message (µs): 4-node buffer perturbation {s4:.1f}; 4 -> 16 nodes {s416:.1f} (ratio {s4 / s416:.2f})")
    print(f"Share of the 4->16 PE-time-per-event rise that thinning accounts for at the perturbation's slope: "
          f"{s4 * (m(base16) - m(base4)) / (base16['pet'] - base4['pet']):.0%}")
