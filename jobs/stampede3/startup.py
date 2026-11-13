#!/usr/bin/env python3
"""Shape of the start-up waves (charades RESULTS.md section 121). Usage: startup.py <job dir> <tag> ..."""
import csv, sys, statistics as st
d = sys.argv[1]
for tag in sys.argv[2:]:
    w = [{k: float(v) for k, v in x.items()} for x in csv.DictReader(open(f"{d}/{tag}/ctl_sweep/gvt_waves_0.csv"))]
    res = [x["result_s"] for x in w]; adv = [1e6 * (b - a) for a, b in zip(res, res[1:])]
    n = len(adv); steady = st.median(adv[n // 10: n * 95 // 100])
    # excess over the steady median, by consecutive blocks of 100 waves
    blocks = [sum(a - steady for a in adv[i:i + 100]) / 1e3 for i in range(0, 1000, 100)]
    big = [a for a in adv[: n // 10] if a > 1000]
    print(f"{tag}: steady median {steady:.0f} µs; excess per 100-wave block, first 1,000 waves (ms): "
          + " ".join(f"{b:.1f}" for b in blocks)
          + f" | first 10%: {len(big)} waves over 1 ms, holding {sum(big)/1e3:.1f} ms; longest {max(adv[:n//10])/1e3:.1f} ms; "
          f"median {st.median(adv[:n//10]):.0f} µs")
