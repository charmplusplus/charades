#!/usr/bin/env python3
"""--wave-batch: shorter passes while a count wave is in flight (charades RESULTS.md sections 119/120).
Usage: sdiag21_summary.py <job dir>"""
import csv, glob, os, statistics as st, sys
from collections import defaultdict
d = sys.argv[1]; mean = st.fmean; med = st.median
RED = ["charm", "tree4", "flat", "ar"]
NAME = {"charm": "Charm++ reduction", "tree4": "tree, fan-out 4", "flat": "flat tree", "ar": "recursive doubling"}

def rows(tag):
    return [x for f in glob.glob(f"{d}/{tag}.csv") for x in csv.DictReader(open(f)) if x["status"] == "ok"]
def mrate(fmt, pred=lambda x: True):
    v = [float(x["event_rate"]) / 1e6 for r in (1, 2) for x in rows(fmt.format(r=r)) if pred(x)]
    return (mean(v) if v else float("nan")), v
def pct(v, q):
    v = sorted(v); return v[min(len(v) - 1, int(q * len(v)))] if v else float("nan")
def mid(n):  # waves 10-95%
    return range(max(1, n // 10), n * 95 // 100)

def waves(run):
    """Per process: list of gvt_waves rows (one per wave, own clock)"""
    P = {}
    for f in glob.glob(f"{run}/gvt_waves_*.csv"):
        P[int(os.path.basename(f)[10:-4])] = [{k: float(v) for k, v in x.items()} for x in csv.DictReader(open(f))]
    return P

def split(run):
    """Advance, floor (slowest process: last PE in -> result), first hop, as in section 80"""
    P = waves(run)
    if not P: return None
    n = min(len(v) for v in P.values()); A, F, H, Hs, R = [], [], [], [], []
    for i in mid(n):
        work = {p: v[i]["last_s"] - v[i - 1]["result_s"] for p, v in P.items()}
        s = max(work, key=work.get); w = P[s][i]
        F.append(1e6 * (w["result_s"] - w["last_s"]))
        if w["handled_s"] > 0: Hs.append(1e6 * (w["handled_s"] - w["last_s"]))
        A.append(1e6 * (P[0][i]["result_s"] - P[0][i - 1]["result_s"]))
        for v in P.values():
            if v[i]["handled_s"] > 0: H.append(1e6 * (v[i]["handled_s"] - v[i]["last_s"]))
    return dict(advance=mean(A), floor=mean(F), floor_med=med(F), hop1=med(H) if H else float("nan"),
                hop1_slow=med(Hs) if Hs else float("nan"), n=len(A))


def crit(run):
    """Critical-path hop waits beyond each pair's fastest hop (µs): up hops where a child's sums came last, all down hops"""
    rec = defaultdict(list); mins = {}
    for f in glob.glob(f"{run}/gvt_hops_*.csv"):
        p = int(os.path.basename(f)[9:-4])
        for x in csv.DictReader(open(f)):
            rec[(p, int(x["wave"]))].append((int(x["kind"]), int(x["peer"]), float(x["sent_s"]), float(x["recv_s"])))
    for (p, w), v in rec.items():
        for k, peer, s, t in v:
            if k in (0, 1): key = (p, peer, k); mins[key] = min(mins.get(key, 9e9), t - s)
    if not rec: return [], []
    waves = sorted({w for (_, w) in rec}); lo, hi = waves[len(waves) // 10], waves[len(waves) * 95 // 100]
    cx, dx = [], []
    for (p, w), v in rec.items():
        if not lo <= w <= hi: continue
        ins = [x for x in v if x[0] in (0, 2)]
        if ins:
            k, peer, s, t = max(ins, key=lambda x: x[3])
            if k == 0: cx.append(1e6 * (t - s - mins[(p, peer, 0)]))
        for k2, peer2, s2, t2 in v:
            if k2 == 1: dx.append(1e6 * (t2 - s2 - mins[(p, peer2, 1)]))
    return cx, dx

F = ["base", "wb2", "wb4", "wb8", "wb4pe"]
NAME = {"base": "batch 16 (baseline)", "wb2": "--wave-batch=2", "wb4": "--wave-batch=4", "wb8": "--wave-batch=8", "wb4pe": "--wave-batch=4, when 1"}
print("A. Throughput, σ 2,000, W 400, PP 512, Charm++ reduction (M committed ev/s, mean of 2 reps; ÷ baseline; higher is better)")
for n in (4, 16):
    b, _ = mrate(f"A_base_n{n}_r{{r}}")
    for f in F:
        o, ov = mrate(f"A_{f}_n{n}_r{{r}}")
        print(f"  {n:>2} nodes {NAME[f]:24}: {o:6.1f} ({', '.join(f'{x:.1f}' for x in ov)}) ratio {o / b:.3f}")
for f in F:
    o4, _ = mrate(f"A_{f}_n4_r{{r}}"); o16, _ = mrate(f"A_{f}_n16_r{{r}}")
    print(f"  4->16 node efficiency, {NAME[f]}: {o16 / (4 * o4):.2f}")

print("\nA'. A GVT advance, 16 nodes, traced (µs, waves 10-95%, both reps; lower is better)")
for tag, nm in (("T_base", "batch 16"), ("T_wb4", "--wave-batch=4"), ("T_wb4pe", "--wave-batch=4, when 1"),
                ("T_tree4_base", "tree 4, batch 16"), ("T_tree4_wb4", "tree 4, --wave-batch=4")):
    S = [split(f"{d}/{tag}_r{rep}/ctl_sweep") for rep in (1, 2)]; S = [s for s in S if s]
    t, _ = mrate(f"{tag}_r{{r}}")
    if not S: print(f"  {nm}: no trace"); continue
    g = lambda k: mean(s[k] for s in S)
    line = f"  {nm:24}: advance {g('advance'):5.0f}, floor {g('floor'):5.1f} (median {g('floor_med'):5.1f}), first hop {g('hop1'):4.1f}, traced M ev/s {t:6.1f}"
    if "tree4" in tag:
        cx, dx = [], []
        for rep in (1, 2):
            a, b2 = crit(f"{d}/{tag}_r{rep}/ctl_sweep"); cx += a; dx += b2
        if cx: line += f" | critical up-hop wait mean {mean(cx):.1f} (median {med(cx):.1f}), down-hop wait mean {mean(dx):.1f} (median {med(dx):.1f})"
    print(line)

print("\nB. --wave-batch=4 ÷ baseline, 16 nodes (M committed ev/s, mean of 2 reps; higher is better)")
for wl, tag in (("gauss:100:1000:100", "s100"), ("gauss:100:1000:4000", "s4k"), ("steady:100:1000:1.0", "uni")):
    for arm in ("w:400", "q:0.001"):
        c, cv = mrate(f"B_base_{tag}_r{{r}}", lambda x: x["arm"] == arm)
        f, fv = mrate(f"B_wb4_{tag}_r{{r}}", lambda x: x["arm"] == arm)
        print(f"  {wl:22} {('W 400' if arm == 'w:400' else 'controller'):10}: baseline {c:6.1f} ({', '.join(f'{x:.0f}' for x in cv)}), "
              f"wave-batch 4 {f:6.1f} ({', '.join(f'{x:.0f}' for x in fv)}), ratio {f / c:.3f}")
