#!/usr/bin/env python3
"""Rank 0's system calls from strace -ff (charades RESULTS.md section 93/94). Usage: sdiag8_summary.py <job dir>"""
import glob, re, sys, os, statistics as st
from collections import defaultdict, Counter
d = sys.argv[1]
LINE = re.compile(r"^(\d+):(\d+):([\d.]+) (\w+)\((.*)\)\s+= (.*?)(?: <([\d.]+)>)?$")
def secs(h, m, s): return int(h) * 3600 + int(m) * 60 + float(s)
for tag in sorted(os.path.basename(p) for p in glob.glob(f"{d}/ST_*") if os.path.isdir(p)):
    logs = glob.glob(f"{d}/{tag}/ctl_sweep/logs/*.out")
    tid2rank = {}
    for lg in logs:
        for m in re.finditer(r"GVT trace: PE (\d+) rank (\d+) tid (\d+)", open(lg).read()):
            if int(m.group(1)) < 23: tid2rank[m.group(3)] = int(m.group(2))
    files = glob.glob(f"{d}/{tag}/st.*")
    data = {}; fdname = {}; tmin, tmax = 1e18, 0
    for f in files:
        tid = f.rsplit(".", 1)[1]; rows = []
        for l in open(f, errors="replace"):
            m = LINE.match(l.strip())
            if not m: continue
            t = secs(*m.group(1, 2, 3)); name, args, ret, dur = m.group(4), m.group(5), m.group(6), float(m.group(7) or 0)
            rows.append((t, name, args, ret, dur)); tmin = min(tmin, t); tmax = max(tmax, t)
            if name in ("openat", "open") and re.match(r"-?\d+$", ret.split()[0]):
                p = re.search(r'"([^"]+)"', args)
                if p: fdname[ret.split()[0]] = p.group(1)
        data[tid] = rows
    lo, hi = tmin + 0.3 * (tmax - tmin), tmin + 0.9 * (tmax - tmin); span = hi - lo
    print(f"\n{tag}: {len(files)} thread files, {len(tid2rank)} PE tids mapped; window {span:.2f} s of {tmax - tmin:.2f} s")
    per = {}
    for tid, rows in data.items():
        w = [r for r in rows if lo <= r[0] <= hi]
        c = Counter(); tt = defaultdict(float); tgt = Counter()
        for t, name, args, ret, dur in w:
            c[name] += 1; tt[name] += dur
            if name in ("ioctl", "writev", "write", "read", "poll", "mmap", "munmap", "madvise"):
                fd = args.split(",")[0].strip()
                key = name + ":" + (fdname.get(fd, "fd" + fd) if name not in ("mmap", "munmap", "madvise") else args.split(",")[1].strip() if "," in args else "")
                tgt[key] += 1
        per[tid] = (sum(c.values()) / span, sum(tt.values()) / span, c, tt, tgt)
    def show(label, tid):
        n, tsum, c, tt, tgt = per.get(tid, (0, 0, Counter(), {}, Counter()))
        top = ", ".join(f"{k} {v / span:.0f}/s {tt[k] / span * 1e3:.1f} ms/s" for k, v in c.most_common(6))
        print(f"  {label:<18} {n:8.0f} calls/s, {tsum * 1e3:6.1f} ms/s in calls: {top}")
        if tgt: print(f"  {'':<18} targets: " + ", ".join(f"{k} {v / span:.0f}/s" for k, v in tgt.most_common(5)))
    r2t = {r: t for t, r in tid2rank.items()}
    for r in (0, 1, 11, 22):
        if r in r2t: show(f"rank {r} ({r2t[r]})", r2t[r])
    pe_rates = [per[t][0] for t in tid2rank if t in per]
    print(f"  median PE: {st.median(pe_rates):.0f} calls/s; rank 0 ÷ median = {per[r2t[0]][0] / max(st.median(pe_rates), 1e-9):.0f}" if 0 in r2t else "")
    for tid in sorted(per, key=lambda t: -per[t][0]):
        if tid not in tid2rank and per[tid][0] > 1: show(f"other {tid}", tid)
