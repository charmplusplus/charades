#!/usr/bin/env python3
"""Critical-path hops in the process tree: at each process and wave, which input came last,
and how long that hop took beyond its pair's fastest (section 118). Usage: sdiag20_crit.py <job dir>"""
import csv, glob, os, statistics as st, sys
from collections import defaultdict
d = sys.argv[1]; med = st.median
def pct(v, q):
    v = sorted(v); return v[min(len(v) - 1, int(q * len(v)))] if v else float("nan")
for n in (4, 16):
    for r in ("tree4", "flat"):
        last_kind = defaultdict(int); cx, dx, wait_local, held = [], [], [], []
        for rep in (1, 2):
            run = f"{d}/A_{r}_T_n{n}_r{rep}/ctl_sweep"; rec = defaultdict(list); mins = {}
            for f in glob.glob(f"{run}/gvt_hops_*.csv"):
                p = int(os.path.basename(f)[9:-4])
                for x in csv.DictReader(open(f)):
                    rec[(p, int(x["wave"]))].append((int(x["kind"]), int(x["peer"]), float(x["sent_s"]), float(x["recv_s"])))
            # raw hop minima per pair and direction (offset-free excess)
            for (p, w), v in rec.items():
                for k, peer, s, t in v:
                    if k in (0, 1): key = (p, peer, k); mins[key] = min(mins.get(key, 9e9), t - s)
            waves = sorted({w for (_, w) in rec}); lo, hi = waves[len(waves) // 10], waves[len(waves) * 95 // 100]
            for (p, w), v in rec.items():
                if not lo <= w <= hi: continue
                ins = [x for x in v if x[0] in (0, 2)]
                if not ins: continue
                k, peer, s, t = max(ins, key=lambda x: x[3])
                last_kind["child" if k == 0 else "own PEs"] += 1
                if k == 0: cx.append(1e6 * (t - s - mins[(p, peer, 0)]))
                done = [x for x in v if x[0] == 3]
                if done: held.append(1e6 * (done[0][3] - t))
                for k2, peer2, s2, t2 in v:
                    if k2 == 1: dx.append(1e6 * (t2 - s2 - mins[(p, peer2, 1)]))
        tot = sum(last_kind.values())
        print(f"{n:>2} nodes {r:5}: last input from a child {last_kind['child'] / tot:.2f}, own PEs {last_kind['own PEs'] / tot:.2f}; "
              f"critical up hop excess median {med(cx):.1f} p90 {pct(cx, .9):.1f} mean {st.fmean(cx):.1f} µs; "
              f"down excess median {med(dx):.1f} mean {st.fmean(dx):.1f} µs; last input -> sent on {med(held):.1f} µs")
