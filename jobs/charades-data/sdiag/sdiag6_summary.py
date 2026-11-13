#!/usr/bin/env python3
"""Per-thread scheduler statistics (charades RESULTS.md section 89/90). Usage: sdiag6_summary.py <job dir>"""
import glob, re, sys, os, statistics as st
from collections import defaultdict, Counter
d = sys.argv[1]; med = st.median
def parse(f):
    hdr = open(f).readline(); lid = int(re.search(r"localid (\d+)", hdr).group(1)); host = re.search(r"host (\S+)", hdr).group(1)
    T = defaultdict(list); C = defaultdict(list)
    for l in open(f):
        v = l.split()
        if v[0] == "T":
            T[v[2]].append(dict(t=float(v[1]), comm=v[3], cpus=v[4], last=int(v[5]), run=int(v[6]), wait=int(v[7]), sl=int(v[8]),
                                vcsw=int(v[9]), nvcsw=int(v[10]), minflt=int(v[11]), utime=int(v[13]), stime=int(v[14])))
        elif v[0] == "C":
            C[int(v[2])].append((float(v[1]), int(v[3]) + int(v[4])))
    return lid, host, T, C
def window(s):  # samples from 20% to 90% of the sampled time
    t1 = s[-1]["t"]; w = [x for x in s if 0.2 * t1 <= x["t"] <= 0.9 * t1]
    return (w[0], w[-1]) if len(w) >= 2 else (None, None)
for tag in sorted({os.path.basename(p) for p in glob.glob(f"{d}/S_*")}, key=lambda t: (t.split("_r")[-1], t)):
    rows = defaultdict(list); helpers = []; irq = defaultdict(list); last_on_r0 = Counter()
    for f in glob.glob(f"{d}/{tag}/sched.*.txt"):
        lid, host, T, C = parse(f)
        r0core = 2 + lid
        for tid, s in T.items():
            a, b = window(s)
            if a is None: continue
            dt = b["t"] - a["t"]; run = (b["run"] - a["run"]) / 1e9
            m = dict(wait_ms_per_s=(b["wait"] - a["wait"]) / 1e6 / dt, run_frac=run / dt, nvcsw_s=(b["nvcsw"] - a["nvcsw"]) / dt,
                     vcsw_s=(b["vcsw"] - a["vcsw"]) / dt, minflt_s=(b["minflt"] - a["minflt"]) / dt, stime_frac=(b["stime"] - a["stime"]) / 100 / dt)
            cpus = b["cpus"]
            if re.fullmatch(r"\d+", cpus) and int(cpus) % 2 == lid % 2 and int(cpus) >= 2:
                rows[(int(cpus) - 2 - lid) // 2].append(m)
            else:
                w = [x for x in s if a["t"] <= x["t"] <= b["t"]]
                lc = Counter(x["last"] for x in w)
                helpers.append((host, lid, tid, b["comm"], cpus, m, lc.most_common(3)))
                if r0core in lc: last_on_r0[b["comm"]] += 1
        if lid == 0:
            for cpu, v in C.items():
                v2 = [x for x in v if 0.2 * v[-1][0] <= x[0] <= 0.9 * v[-1][0]]
                if len(v2) >= 2: irq[cpu].append((v2[-1][1] - v2[0][1]) / 100 / (v2[-1][0] - v2[0][0]) * 1e3)
    if not rows: print(f"{tag}: no data"); continue
    print(f"\n{tag}: {len(rows)} ranks, {sum(len(v) for v in rows.values())} PE threads, {len(helpers)} other threads")
    keys = ["wait_ms_per_s", "nvcsw_s", "vcsw_s", "run_frac", "stime_frac", "minflt_s"]
    def line(name, ms): return f"    {name:<14}" + " ".join(f"{k}={st.fmean(m[k] for m in ms):.3g}" for k in keys)
    print(line("rank 0", rows[0])); print(line("rank 1", rows[1]))
    mid = [m for r in range(2, 22) for m in rows[r]]
    print(line("ranks 2-21", mid)); print(line("rank 22", rows[22]))
    print(f"    ranks 2-21 median: wait_ms_per_s={med(m['wait_ms_per_s'] for m in mid):.3g} stime_frac={med(m['stime_frac'] for m in mid):.3g} minflt_s={med(m['minflt_s'] for m in mid):.3g}")
    hc = Counter((h[3], h[4]) for h in helpers)
    print("    other threads (name, allowed cores: count): " + "; ".join(f"{k[0]} {k[1]}: {v}" for k, v in hc.most_common(6)))
    for name in sorted({h[3] for h in helpers}):
        hs = [h for h in helpers if h[3] == name]
        print(f"      {name}: run_frac={st.fmean(h[5]['run_frac'] for h in hs):.4f} vcsw/s={st.fmean(h[5]['vcsw_s'] for h in hs):.1f} "
              f"last cores (first 3 processes)={[h[6] for h in hs[:3]]}")
    print(f"    processes where a non-PE thread last ran on rank 0's core in the window: {dict(last_on_r0)}")
    if irq:
        s0 = {c: st.fmean(v) for c, v in irq.items()}
        print("    irq+softirq ms per s, socket 0 cores 0-10: " + " ".join(f"c{c}={s0[c]:.2f}" for c in range(0, 11, 2)) +
              f"; socket 0 median {med(s0[c] for c in s0 if c % 2 == 0):.2f}; socket 1 median {med(s0[c] for c in s0 if c % 2 == 1):.2f}")
