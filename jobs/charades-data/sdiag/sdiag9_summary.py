#!/usr/bin/env python3
"""Rank 0's faults: perf vs /proc, light sampler, numactl (charades RESULTS.md section 96/97). Usage: sdiag9_summary.py <job dir>"""
import csv, glob, re, os, sys, statistics as st
from collections import defaultdict, Counter
d = sys.argv[1]; mean = st.fmean; med = st.median
def rate(tag):
    v = [float(x["event_rate"]) / 1e6 for f in glob.glob(f"{d}/{tag}.csv") for x in csv.DictReader(open(f)) if x["status"] == "ok"]
    return v[0] if v else float("nan")
print("Throughput, untraced (M ev/s; ratio numa / plain, higher is better)")
for s in ("100", "2000"):
    p = [rate(f"off_plain_s{s}_r{k}") for k in (1, 2)]; n = [rate(f"off_numa_s{s}_r{k}") for k in (1, 2)]
    print(f"  sigma {s}: plain {mean(p):.1f} ({p[0]:.1f}, {p[1]:.1f}); numa {mean(n):.1f} ({n[0]:.1f}, {n[1]:.1f}); ratio {mean(n)/mean(p):.3f}")
def late(prefix):
    D = defaultdict(list); last = Counter(); nw = 0; worst = []
    for f0 in glob.glob(f"{d}/{prefix}_r[12]"):
        P = [[list(map(float, r)) for r in list(csv.reader(open(f)))[1:]] for f in glob.glob(f"{f0}/ctl_sweep/gvt_ranks_*.csv")]
        if not P: continue
        n = min(len(p) for p in P); nr = len(P[0][0])
        for i in range(max(2, n // 10), n - n // 20):
            wp = max(range(len(P)), key=lambda q: max(P[q][i])); row = P[wp][i]
            last[max(range(nr), key=row.__getitem__)] += 1; nw += 1; worst.append(max(row))
            for p in P:
                for r in range(nr): D[r].append(p[i][r])
    if not D: return "no traces"
    return f"r0 {mean(D[0]):.0f} us, r1 {mean(D[1]):.0f}, rest {med([mean(D[r]) for r in range(2, 22)]):.0f}; r0 last PE {last[0]/nw:.2f}; slowest-PE delay {mean(worst):.0f} us"
print("\nLateness (traced, waves 10-95%, both reps)")
for t in ("T_plain_s100", "T_fullperf_s100", "T_light_s100", "T_numa_s100", "T_light_s2000", "T_numa_s2000"):
    print(f"  {t:<16} {late(t)}")
def parse(f):
    hdr = open(f).readline(); lid = int(re.search(r"localid (\d+)", hdr).group(1))
    TH = defaultdict(list)
    for l in open(f):
        v = l.split()
        if v[0] == "L": TH[v[2]].append((float(v[1]), int(v[3]), int(v[4]), int(v[5]), int(v[6])))  # t last minflt utime stime
        elif v[0] == "T": TH[v[2]].append((float(v[1]), int(v[5]), int(v[11]), int(v[13]), int(v[14])))
    return lid, TH
def rank_stats(f):
    lid, TH = parse(f); out = {}; bycore = {}
    for tid, s in TH.items():
        if len(s) < 3: continue
        t1 = s[-1][0]; w = [x for x in s if 0.3 * t1 <= x[0] <= 0.9 * t1]
        if len(w) < 2: w = s[1:]
        if len(w) < 2 or w[-1][0] <= w[0][0]: continue
        dt = w[-1][0] - w[0][0]; core = Counter(x[1] for x in w).most_common(1)[0][0]
        m = ((w[-1][2] - w[0][2]) / dt, (w[-1][4] - w[0][4]) / 100 / dt, w[-1][3] + w[-1][4], s[-1][2])
        if core >= 2 and core % 2 == lid % 2 and (core not in bycore or m[2] > bycore[core][1][2]): bycore[core] = (tid, m)
    for core, (tid, m) in bycore.items(): out[(core - 2 - lid) // 2] = (tid, m)
    return out
print("\nPer-thread /proc, 30-90% window: minor faults/s and kernel-time share (mean over processes)")
for t in ("T_fullperf_s100", "T_light_s100", "T_numa_s100", "T_light_s2000", "T_numa_s2000"):
    R = defaultdict(list)
    for f in glob.glob(f"{d}/{t}_r[12]/sched.*.txt"):
        for r, (tid, m) in rank_stats(f).items(): R[r].append(m)
    if not R: print(f"  {t}: none"); continue
    rest = [m for r in range(2, 22) for m in R[r]]
    print(f"  {t:<16} r0 faults/s {mean(m[0] for m in R[0]):.0f}, kernel {mean(m[1] for m in R[0]):.3f} | r1 {mean(m[0] for m in R[1]):.0f}, {mean(m[1] for m in R[1]):.3f} | median rest {med(m[0] for m in rest):.0f}, {med(m[1] for m in rest):.3f}")
print("\nperf (every user-mode fault, process 0) vs /proc minor faults over the whole run, per rank")
for f0 in sorted(glob.glob(f"{d}/T_fullperf_s100_r[12]")):
    pf = glob.glob(f"{f0}/pf.*.data"); sch = [f for f in glob.glob(f"{f0}/sched.*.txt") if f.endswith(".0.txt")]
    if not pf or not sch: print(f"  {f0}: missing"); continue
    cnt = Counter(l.split()[0] for l in os.popen(f"perf script -i {pf[0]} -F tid 2>/dev/null"))
    rs = rank_stats(sch[0])
    for r in (0, 1, 11, 22):
        if r in rs:
            tid, m = rs[r]; pc = cnt.get(tid, 0)
            print(f"  {os.path.basename(f0)} rank {r} (tid {tid}): perf user faults {pc}, /proc minflt {m[3]}, perf/proc {pc / max(m[3], 1):.2f}")
