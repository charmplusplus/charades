#!/usr/bin/env python3
"""Per-PE wave records (--gvt-trace=4) and --gvt-wave-events (charades RESULTS.md section 104/105).
Usage: sdiag13_summary.py <job dir>"""
import csv, glob, os, sys, statistics as st
from collections import Counter
d = sys.argv[1]; mean = st.fmean; med = st.median
CONFIGS = ["uni_wps512", "uni_pp512", "s2k_pp512"]
NODES = [4, 16]; REPS = [1, 2]

def rate(tag):
    v = [float(x["event_rate"]) / 1e6 for f in glob.glob(f"{d}/{tag}.csv") for x in csv.DictReader(open(f)) if x["status"] == "ok"]
    return v[0] if v else float("nan")
def mrate(fmt):
    v = [rate(fmt.format(r=r)) for r in REPS]
    v = [x for x in v if x == x]
    return (mean(v) if v else float("nan")), v

print("Throughput (M committed ev/s, W 400, mean of 2 reps; higher is better)")
print(f"  {'config':11} {'4 nodes':>8} {'16 nodes':>9} {'4->16 eff':>9} {'traced/untraced 4':>18} {'16':>6}")
for c in CONFIGS:
    o4, _ = mrate(f"off_{c}_n4_r{{r}}"); o16, _ = mrate(f"off_{c}_n16_r{{r}}")
    t4, _ = mrate(f"T_{c}_n4_r{{r}}"); t16, _ = mrate(f"T_{c}_n16_r{{r}}")
    print(f"  {c:11} {o4:8.1f} {o16:9.1f} {o16 / (4 * o4):9.2f} {t4 / o4:18.3f} {t16 / o16:6.3f}")
print("\n--gvt-wave-events K / default 128, 16 nodes, untraced (higher is better)")
for c, ks in (("uni_wps512", (0, 32)), ("uni_pp512", (0, 32)), ("s2k_pp512", (32,))):
    b, bv = mrate(f"off_{c}_n16_r{{r}}")
    for k in ks:
        m, v = mrate(f"we{k}_{c}_n16_r{{r}}")
        print(f"  {c:11} K {k:>2}: {m:6.1f} ({', '.join(f'{x:.1f}' for x in v)}) vs {b:.1f} ({', '.join(f'{x:.1f}' for x in bv)}) ratio {m / b:.3f}")

F = ["pick_us", "prev_end_us", "contrib_us", "exec_us", "drain_us", "recv_us", "rollback_us", "node_gvt_us", "events", "passed", "reason"]
def load(run):
    files = glob.glob(f"{run}/gvt_rec_*.csv")
    if not files: return None
    nproc = len(glob.glob(f"{run}/gvt_waves_*.csv")) or 1
    pepp = len(files) // nproc
    R = {}
    for f in files:
        pe = int(os.path.basename(f)[8:-4])
        for x in csv.DictReader(open(f)):
            R.setdefault(int(x["wave"]), {})[pe] = [float(x[k]) for k in F]
    return R, pepp, nproc, len(files)

def split(r):
    pick, prev_end, contrib = r[0], r[1], r[2]
    inpass = min(max(prev_end, 0.0), pick) if prev_end > -1e8 else 0.0
    return dict(delay=contrib, pick_in_pass=inpass, pick_outside=pick - inpass, after_pick=contrib - pick,
                exec=r[3], drain=r[4], recv=r[5], rollback=r[6], node_gvt=r[7], events=r[8], passed=r[9],
                count=1.0 if r[10] in (2, 3) else 0.0)

print("\nThe late PE (the slowest process's last PE) against the median PE of the same process, per recorded wave, waves 10-95%, both reps")
print("(µs after the previous result in that process; lower is better; 'count' = share of waves it contributed because it reached --gvt-wave-events)")
KEYS = ["delay", "pick_in_pass", "pick_outside", "after_pick", "exec", "drain", "recv", "rollback", "events", "count"]
for c in CONFIGS:
    for n in NODES:
        L, M = {k: [] for k in KEYS + ["passed"]}, {k: [] for k in KEYS + ["passed"]}
        ranks, procs, nw = Counter(), Counter(), 0
        for rep in REPS:
            got = load(f"{d}/T_{c}_n{n}_r{rep}/ctl_sweep")
            if not got: continue
            R, pepp, nproc, npe = got
            # a statistics reset between pickup and contribution (seen once on the Mac) leaves a wrapped count
            waves = sorted(w for w, v in R.items() if len(v) == npe and all(r[8] < 1e9 and r[3] >= 0 for r in v.values()))
            if not waves: continue
            lo, hi = waves[len(waves) // 10], waves[len(waves) * 95 // 100]
            for w in waves:
                if w < lo or w > hi: continue
                v = R[w]
                by = {}
                for pe, r in v.items(): by.setdefault(pe // pepp, []).append((r[2], pe))
                sp = max(by, key=lambda p: max(by[p])[0])
                ordered = sorted(by[sp]); late = ordered[-1][1]; mid = ordered[(len(ordered) - 1) // 2][1]
                ranks[late % pepp] += 1; procs[sp] += 1; nw += 1
                for X, pe in ((L, late), (M, mid)):
                    s = split(v[pe])
                    for k in KEYS + ["passed"]: X[k].append(s[k])
        if not nw:
            print(f"  {c} {n} nodes: no traces"); continue
        def row(X):
            per_ev = sum(X["after_pick"]) / max(1.0, sum(X["events"]))
            return " ".join(f"{k} {mean(X[k]):.0f}" if k != "count" else f"count {mean(X[k]):.2f}" for k in KEYS) + \
                   f" | µs/event after pickup {per_ev:.2f} | buckets passed (median) {med(X['passed']):.0f}"
        print(f"  {c} {n} nodes ({nw} waves):")
        print(f"    late  : {row(L)}")
        print(f"    median: {row(M)}")
        print(f"    late PE's rank (share): " + ", ".join(f"r{r} {k / nw:.2f}" for r, k in ranks.most_common(4)) +
              f" | slowest process: " + ", ".join(f"p{p} {k / nw:.2f}" for p, k in procs.most_common(3)) +
              f" | late PE ran >= 128 events in {sum(1 for e in L['events'] if e >= 128) / nw:.2f} of waves")
