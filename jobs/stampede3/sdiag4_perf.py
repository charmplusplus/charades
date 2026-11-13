#!/usr/bin/env python3
"""Rank 0 timers and perf (charades RESULTS.md section 85/86). Usage: sdiag4_summary.py <job dir>"""
import csv, glob, re, sys, os, statistics as st
from collections import defaultdict, Counter
d = sys.argv[1]; med = st.median; mean = st.fmean
def rate(tag):
    v = [float(x["event_rate"]) / 1e6 for f in glob.glob(f"{d}/{tag}.csv") for x in csv.DictReader(open(f)) if x["status"] == "ok"]
    return v[0] if v else float("nan")
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
