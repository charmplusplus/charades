#!/usr/bin/env python3
"""What paces GVT at sigma 2,000; bucket size; margin x window (charades RESULTS.md section 115/116).
Usage: sdiag19_summary.py <job dir>"""
import csv, glob, os, statistics as st, sys
from collections import Counter, defaultdict
d = sys.argv[1]; mean = st.fmean; med = st.median
NAMES = {"gauss:100:1000:2000": "σ 2,000", "gauss:100:1000:4000": "σ 4,000"}

def rows(tag):
    return [x for f in glob.glob(f"{d}/{tag}.csv") for x in csv.DictReader(open(f)) if x["status"] == "ok"]
def mrate(fmt, pred=lambda x: True):
    v = [float(x["event_rate"]) / 1e6 for r in (1, 2) for x in rows(fmt.format(r=r)) if pred(x)]
    return (mean(v) if v else float("nan")), v

print("A. Throughput, σ 2,000, PP 512 (M committed ev/s, mean of 2 reps; higher is better)")
for w, ns in ((400, (4, 16)), (250, (16,)), (600, (16,))):
    for n in ns:
        o, ov = mrate(f"off_w{w}_n{n}_r{{r}}"); t, _ = mrate(f"T_w{w}_n{n}_r{{r}}")
        print(f"  W {w:3} {n:>2} nodes: {o:6.1f} ({', '.join(f'{x:.1f}' for x in ov)}) traced/untraced {t / o:.3f}")
o4, _ = mrate("off_w400_n4_r{r}"); o16, _ = mrate("off_w400_n16_r{r}")
print(f"  4->16 node efficiency at W 400: {o16 / (4 * o4):.2f}")

print("\nA. Waves (PE 0's gvt_trace.csv, waves 10-95%, both reps)")
for w, n in ((400, 4), (400, 16), (250, 16), (600, 16)):
    W = []
    for r in (1, 2):
        for f in glob.glob(f"{d}/T_w{w}_n{n}_r{r}/ctl_sweep/gvt_trace.csv"):
            x = list(csv.DictReader(open(f))); W += x[len(x) // 10: len(x) * 95 // 100]
    if not W: print(f"  W {w} {n} nodes: no trace"); continue
    open_ = [int(x["prev_valid"]) - int(x["completed"]) for x in W]
    tr = [int(x["transit_total"]) for x in W]
    print(f"  W {w:3} {n:>2} nodes ({len(W)} waves): completed/wave {mean(int(x['completed']) for x in W):.1f}, "
          f"passed at previous wave {mean(int(x['prev_valid']) for x in W):.1f}, waves with a passed bucket left open {sum(o > 0 for o in open_) / len(W):.2f}, "
          f"with events in transit {sum(t > 0 for t in tr) / len(W):.2f}, events in transit (mean) {mean(tr):.0f}, "
          f"advances/wave {sum(int(x['completed']) > 0 for x in W) / len(W):.2f}, µs/wave {1e6 * mean(float(x['end_s']) - float(x['start_s']) for x in W):.0f}")

print("\nA. The late PE (the slowest process's last PE) against the median PE of its process (gvt_rec, waves 10-95%, both reps)")
print("   delay/pickup/after in µs after the previous result; arrivals = events received since the PE's previous contribution;")
print("   near = arrivals within one bucket of GVT; lag = mean distance from GVT in buckets")
K = ["delay", "pick", "after", "events", "arrivals", "near", "lag", "count"]
for w, n in ((400, 4), (400, 16), (250, 16), (600, 16)):
    L, M = defaultdict(list), defaultdict(list); ranks = Counter(); nw = 0
    for r in (1, 2):
        run = f"{d}/T_w{w}_n{n}_r{r}/ctl_sweep"; files = glob.glob(f"{run}/gvt_rec_*.csv")
        if not files: continue
        nproc = len(glob.glob(f"{run}/gvt_waves_*.csv")) or 1; pepp = len(files) // nproc
        R = defaultdict(dict)
        for f in files:
            pe = int(os.path.basename(f)[8:-4])
            for x in csv.DictReader(open(f)): R[int(x["wave"])][pe] = x
        waves = sorted(wv for wv, v in R.items() if len(v) == len(files) and all(float(y["events"]) < 1e9 for y in v.values()))
        if not waves: continue
        lo, hi = waves[len(waves) // 10], waves[len(waves) * 95 // 100]
        for wv in waves:
            if wv < lo or wv > hi: continue
            by = defaultdict(list)
            for pe, x in R[wv].items(): by[pe // pepp].append((float(x["contrib_us"]), pe))
            sp = max(by, key=lambda p: max(by[p])[0]); o = sorted(by[sp])
            late, mid = o[-1][1], o[(len(o) - 1) // 2][1]; ranks[late % pepp] += 1; nw += 1
            for X, pe in ((L, late), (M, mid)):
                x = R[wv][pe]
                X["delay"].append(float(x["contrib_us"])); X["pick"].append(float(x["pick_us"]))
                X["after"].append(float(x["contrib_us"]) - float(x["pick_us"])); X["events"].append(float(x["events"]))
                X["arrivals"].append(float(x["arrivals"])); X["near"].append(float(x["near"]))
                if float(x["lag_mean"]) >= 0: X["lag"].append(float(x["lag_mean"]))
                X["count"].append(1.0 if int(x["reason"]) in (2, 3) else 0.0)
    if not nw: print(f"  W {w} {n} nodes: no traces"); continue
    fmt = lambda X: " ".join(f"{k} {mean(X[k]):.2f}" if k == "count" else f"{k} {mean(X[k]) if X[k] else float('nan'):.1f}" for k in K)
    print(f"  W {w:3} {n:>2} nodes ({nw} waves):")
    print(f"    late  : {fmt(L)}")
    print(f"    median: {fmt(M)}")
    print(f"    late/median arrivals {mean(L['arrivals']) / max(mean(M['arrivals']), 1e-9):.2f}, near share late {sum(L['near']) / max(sum(L['arrivals']), 1):.3f} "
          f"median {sum(M['near']) / max(sum(M['arrivals']), 1):.3f} | late PE's rank: " + ", ".join(f"r{k} {v / nw:.2f}" for k, v in ranks.most_common(3)))

print("\nB. GVT bucket size / 8 (PP 512; M committed ev/s at bucket 8, mean of 2 reps; higher is better)")
for n in (16, 4):
    for wl in NAMES:
        for arm in ("w:400", "q:0.001"):
            base, _ = mrate(f"B_b8_n{n}_r{{r}}", lambda x: x["workload"] == wl and x["arm"] == arm)
            line = f"  {n:>2} nodes {NAMES[wl]:8} {('W 400' if arm == 'w:400' else 'controller'):10} b8 {base:6.1f}"
            for b in (16, 32):
                m, v = mrate(f"B_b{b}_n{n}_r{{r}}", lambda x: x["workload"] == wl and x["arm"] == arm)
                line += f" | b{b} {m / base:.3f} ({', '.join(f'{x:.0f}' for x in v)})"
            print(line)

print("\nC. Horizon margin x window, σ 2,000, 16 nodes (M committed ev/s; ratio to margin 8 at W 400; higher is better)")
base, _ = mrate("C_m8_n16_r{r}", lambda x: x["arm"] == "w:400")
for m in (4, 8, 16):
    for w in ("w:400", "w:600"):
        v, vs = mrate(f"C_m{m}_n16_r{{r}}", lambda x, w=w: x["arm"] == w)
        eff = [float(x["efficiency"]) for r in (1, 2) for x in rows(f"C_m{m}_n16_r{r}") if x["arm"] == w]
        epm = [float(x["agg_events_per_msg"]) for r in (1, 2) for x in rows(f"C_m{m}_n16_r{r}") if x["arm"] == w]
        print(f"  margin {m:>2} {w}: {v:6.1f} ({', '.join(f'{x:.0f}' for x in vs)}) ratio {v / base:.3f} | efficiency {mean(eff) if eff else float('nan'):.4f}, events/msg {mean(epm) if epm else float('nan'):.1f}")
