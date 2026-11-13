#!/usr/bin/env python3
"""Which lock rank 0 takes 10x as often: strace -k futex stacks (charades RESULTS.md section 98/99). Usage: sdiag10_summary.py <job dir>"""
import glob, re, os, sys, statistics as st
from collections import defaultdict, Counter
d = sys.argv[1]
HEAD = re.compile(r"^(\d+):(\d+):([\d.]+) futex\((0x[0-9a-f]+), ([A-Z_|]+)")
FR = re.compile(r"^ > (\S+?)\((.*?)\+0x[0-9a-f]+\) \[")
FR2 = re.compile(r"^ > (\S+?)\(\) \[")
def short(lib, fn):
    lib = os.path.basename(lib)
    fn = re.sub(r"\(.*", "", fn)
    return f"{fn or '?'}@{lib}"
def load(f):
    calls = []; cur = None
    for l in open(f, errors="replace"):
        m = HEAD.match(l)
        if m:
            if cur: calls.append(cur)
            h, mi, s, a, op = m.groups(); cur = [int(h) * 3600 + int(mi) * 60 + float(s), a, op, []]
        elif cur and l.startswith(" > "):
            m2 = FR.match(l) or FR2.match(l)
            if m2: cur[3].append(short(m2.group(1), m2.group(2) if m2.lastindex >= 2 else ""))
    if cur: calls.append(cur)
    return calls
for tag in sorted(os.path.basename(p) for p in glob.glob(f"{d}/K_*") if os.path.isdir(p)):
    tid2rank = {}
    for lg in glob.glob(f"{d}/{tag}/ctl_sweep/logs/*.out"):
        for m in re.finditer(r"GVT trace: PE (\d+) rank (\d+) tid (\d+)", open(lg).read()):
            if int(m.group(1)) < 23: tid2rank[m.group(3)] = int(m.group(2))
    T = {f.rsplit(".", 1)[1]: load(f) for f in glob.glob(f"{d}/{tag}/sk.*")}
    pe = [t for t in T if t in tid2rank]
    if not pe: print(f"{tag}: no PE threads mapped"); continue
    # simulation window: middle 80% of the span in which non-main PEs make futex calls
    ts = sorted(c[0] for t in pe if tid2rank[t] != 0 for c in T[t])
    lo, hi = ts[len(ts) // 10], ts[len(ts) * 9 // 10]; span = hi - lo
    W = {t: [c for c in T[t] if lo <= c[0] <= hi] for t in T}
    r2t = {r: t for t, r in tid2rank.items()}; t0 = r2t.get(0)
    print(f"\n{tag}: {len(T)} threads, window {span:.2f} s")
    by = {t: Counter(c[1] for c in W[t]) for t in pe}
    others = [t for t in pe if t != t0]
    addrs = set(a for t in pe for a in by[t])
    def medo(a): return st.median(by[t][a] for t in others)
    top = sorted(addrs, key=lambda a: -by[t0][a])[:5]
    for a in top:
        print(f"  {a}: rank 0 {by[t0][a] / span:.0f}/s, median other PE {medo(a) / span:.0f}/s, max other {max(by[t][a] for t in others) / span:.0f}/s")
    hot = top[0]
    for who, ts_ in (("rank 0", [t0]), ("other PEs", others)):
        sig = Counter(); n = 0
        for t in ts_:
            for c in W[t]:
                if c[1] == hot:
                    sig[(c[2].split("|")[0], " < ".join(f for f in c[3][:9]))] += 1; n += 1
        print(f"  stacks on {hot}, {who} ({n} calls):")
        for (op, s), k in sig.most_common(4):
            print(f"    {k:5d} {op}: {s}")
    non = [t for t in T if t not in tid2rank]
    for t in non:
        n = sum(1 for c in W[t] if c[1] == hot)
        if n: print(f"  non-PE thread {t}: {n} calls on {hot}")
