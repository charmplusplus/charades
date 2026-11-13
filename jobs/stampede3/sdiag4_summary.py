#!/usr/bin/env python3
"""Rank 0 timers and perf (charades RESULTS.md section 85/86). Usage: sdiag4_summary.py <job dir>"""
import csv, glob, re, sys, os, statistics as st
from collections import defaultdict, Counter
d = sys.argv[1]; med = st.median; mean = st.fmean
def rate(tag):
    v = [float(x["event_rate"]) / 1e6 for f in glob.glob(f"{d}/{tag}.csv") for x in csv.DictReader(open(f)) if x["status"] == "ok"]
    return v[0] if v else float("nan")
print("T1. Overhead: traced ÷ untraced (M ev/s)\n")
for wl in ["gauss_100_1000_100", "gauss_100_1000_2000"]:
    for w in (250, 400):
        r = [rate(f"T_tr_{wl}_w{w}_r{k}") / rate(f"T_off_{wl}_w{w}_r{k}") for k in (1, 2)]
        print(f"  {wl} W {w}: {', '.join(f'{x:.3f}' for x in r)}")
print("\nT2. Contribution delay by rank (µs after the previous result, waves 10%-95%)\n")
for wl in ["gauss_100_1000_100", "gauss_100_1000_2000"]:
    for w in (250, 400):
        D = defaultdict(list); above = Counter(); slow_last = Counter(); nwav = 0; tot = 0
        for k in (1, 2):
            files = sorted(glob.glob(f"{d}/T_tr_{wl}_w{w}_r{k}/ctl_sweep/gvt_ranks_*.csv"), key=lambda f: int(re.search(r"_(\d+)\.csv", f).group(1)))
            P = [[list(map(float, row)) for row in list(csv.reader(open(f)))[1:]] for f in files]
            if not P: continue
            n = min(len(p) for p in P); nr = len(P[0][0])
            for i in range(max(2, n // 10), n - n // 20):
                worst = max(range(len(P)), key=lambda p: max(P[p][i]))
                row = P[worst][i]; slow_last[max(range(nr), key=row.__getitem__)] += 1; nwav += 1
                for p in P:
                    m = med(p[i])
                    for r in range(nr):
                        D[r].append(p[i][r]); above[r] += p[i][r] > m
                    tot += 1
        if not D: continue
        nr = len(D)
        print(f"  {wl} W {w}: mean delay µs by rank: " + " ".join(f"r{r}={mean(D[r]):.0f}" for r in range(nr)))
        print(f"    share of (process, wave) where the rank is above its process median: " + " ".join(f"r{r}={above[r]/tot:.2f}" for r in (0, 1, 2, 11, 20, 21, 22)))
        print(f"    slowest process's last rank: " + ", ".join(f"r{r} {c/nwav:.2f}" for r, c in slow_last.most_common(5)))
print("\nT3. Per-PE time per 10-wave interval (µs per wave; mean over processes and intervals 10%-95%)\n")
cats = ["dt", "exec", "drain", "rollback", "poll", "node_gvt", "recv", "outside", "events"]
for wl in ["gauss_100_1000_100", "gauss_100_1000_2000"]:
    for w in (250, 400):
        A = defaultdict(lambda: defaultdict(list))
        for k in (1, 2):
            for f in glob.glob(f"{d}/T_tr_{wl}_w{w}_r{k}/ctl_sweep/gvt_pe_*.csv"):
                rows = list(csv.DictReader(open(f)))
                if len(rows) < 10: continue
                rk = int(rows[0]["rank"]); n = len(rows)
                for a, b in zip(rows[max(1, n // 10):n - n // 20], rows[max(1, n // 10) + 1:n - n // 20]):
                    waves = int(b["wave"]) - int(a["wave"])
                    g = lambda c: (float(b[c]) - float(a[c])) * 1e6 / waves
                    dt = g("t_s"); ex = g("exec_s"); ng = g("node_gvt_s"); rc = g("recv_s")
                    for c, v in [("dt", dt), ("exec", ex), ("drain", g("drain_s")), ("rollback", g("rollback_s")), ("poll", g("poll_s")),
                                 ("node_gvt", ng), ("recv", rc), ("outside", dt - ex - ng - rc), ("events", (int(b["executed"]) - int(a["executed"])) / waves)]:
                        A[rk][c].append(v)
        if not A: continue
        print(f"  {wl} W {w}:")
        for rk in sorted(A):
            print(f"    r{rk:<2} " + " ".join(f"{c}={mean(A[rk][c]):.1f}" for c in cats))
        if 0 in A and 11 in A:
            print("    r0 − r11: " + " ".join(f"{c}={mean(A[0][c]) - mean(A[11][c]):+.1f}" for c in cats))
print("\nP1. perf, process 0 (share of each thread's samples by category)\n")
def cat(sym, dso):
    s = sym.lower(); o = dso.lower()
    if "lci" in s or "lci" in o or "psm" in o or "fabric" in o or "fi_" in s or "hfi" in o: return "network"
    if "htram" in s: return "htram"
    if any(k in s for k in ("cmi", "csd", "converse", "queue", "mpmc", "scheduler", "cqs", "ck", "charm")) and "lpchare" not in s: return "runtime"
    if any(k in s for k in ("malloc", "free", "memcpy", "memset", "_int_", "operator new", "operator delete")): return "alloc/copy"
    return "charades/model"
for pdir in sorted(glob.glob(f"{d}/P_*")):
    logs = glob.glob(f"{pdir}/ctl_sweep/logs/*.out")
    tid2rank = {}
    for lg in logs:
        for m in re.finditer(r"GVT trace: PE (\d+) rank (\d+) tid (\d+)", open(lg).read()):
            tid2rank[m.group(3)] = int(m.group(2))
    for f in glob.glob(f"{pdir}/perf.*.data"):
        cmd = f"perf report -i {f} --stdio -q --sort pid,dso,sym --percent-limit 0 2>/dev/null"
        C = defaultdict(Counter); SY = defaultdict(Counter)
        for line in os.popen(cmd):
            m = re.match(r"\s*([\d.]+)%\s+(\d+):\S*\s+(\S+)\s+\[\S\]\s+(.*)", line)
            if not m: continue
            pct, tid, dso, sym = float(m.group(1)), m.group(2), m.group(3), m.group(4).strip()
            if tid in tid2rank:
                C[tid2rank[tid]][cat(sym, dso)] += pct; SY[tid2rank[tid]][sym[:60]] += pct
        print(f"  {os.path.basename(pdir)}: ({len(tid2rank)} tids mapped)")
        for rk in (0, 1, 11, 21, 22):
            if rk in C:
                t = sum(C[rk].values())
                print(f"    r{rk:<2} total {t:5.2f}% of samples: " + " ".join(f"{k} {v / t:.2f}" for k, v in sorted(C[rk].items(), key=lambda kv: -kv[1])))
        if 0 in SY and 11 in SY:
            t0, t11 = sum(SY[0].values()), sum(SY[11].values())
            diff = sorted(set(SY[0]) | set(SY[11]), key=lambda k: -(SY[0][k] / t0 - SY[11][k] / t11))
            print("    symbols most over-represented on r0 vs r11 (share r0 / r11): " + "; ".join(f"{k} {SY[0][k]/t0:.3f}/{SY[11][k]/t11:.3f}" for k in diff[:6]))
