#!/usr/bin/env python3
"""Charades and Devastator on long runs, 1/4/16 nodes (charades RESULTS.md sections 129/130). Usage: long26_summary.py <job dir>"""
import csv, glob, re, sys, statistics as st
from collections import defaultdict
d = sys.argv[1]; med = st.median
# section 95 (job 3642157, short runs): Charades ÷ Devastator 1/4/16; efficiency 4->16 Charades / Devastator; controller ÷ best W at 16
OLD = {"gauss:100:1000:100": ((1.17, 1.04, 1.06), (0.99, 0.97), None), "gauss:100:1000:500": ((1.09, 1.08, 1.19), (0.97, 0.88), None),
       "gauss:100:1000:1000": ((1.08, 1.19, 1.31), (0.95, 0.86), None), "gauss:10:200:500": ((0.98, 0.98, 1.09), (0.97, 0.86), None),
       "gauss:10:200:2000": ((1.14, 1.18, 1.15), (0.89, 0.91), None)}
C = defaultdict(list)
for f in glob.glob(f"{d}/*_n*_r[123].csv"):
    tag = f.split("/")[-1][:-4]; base = re.sub(r"_n\d+_r\d$", "", tag); n = int(re.search(r"_n(\d+)_r", tag).group(1))
    for x in csv.DictReader(open(f)):
        if x["status"] == "ok": C[(x["workload"], n, base, x["arm"])].append(float(x["event_rate"]) / 1e6)
D = defaultdict(list)
for line in open(f"{d}/deva/results.txt"):
    m = re.search(r"label=(hi|lo)_n(\d+)_s(\d+)_w(\d+)_r\d .*status=ok.*committed_per_s=([0-9.e+]+)", line)
    if not m: continue
    kind, n, s, w, r = m.groups()
    D[(f"gauss:100:1000:{s}" if kind == "hi" else f"gauss:10:200:{s}", int(n), int(w))].append(float(r) / 1e6)
Ns = [1, 4, 16]
def cb(wl, n): return max((med(v), t, a, len(v)) for (w, nn, t, a), v in C.items() if w == wl and nn == n)
def db(wl, n): return max((med(v), w, len(v)) for (ww, nn, w), v in D.items() if ww == wl and nn == n)
print("Long runs (end time 2,048,000; lookahead 10: 512,000), each engine at its best setting, median of 3 (M committed ev/s; higher is better)")
print("| workload | Charades 1 / 4 / 16 nodes | Devastator 1 / 4 / 16 nodes | Charades ÷ Devastator 1 / 4 / 16 | short runs (section 95) | efficiency 4→16, Charades / Devastator | short runs |")
print("|---|---|---|---|---|---|---|")
for wl, o in OLD.items():
    c = [cb(wl, n)[0] for n in Ns]; dv = [db(wl, n)[0] for n in Ns]
    sp = [a / b for a, b in zip(c, dv)]; ec = (c[2] / 16) / (c[1] / 4); ed = (dv[2] / 16) / (dv[1] / 4)
    print(f"| {wl} | {c[0]:.1f} / {c[1]:.1f} / {c[2]:.1f} | {dv[0]:.1f} / {dv[1]:.1f} / {dv[2]:.1f} | **{sp[0]:.2f} / {sp[1]:.2f} / {sp[2]:.2f}** | "
          f"{o[0][0]:.2f} / {o[0][1]:.2f} / {o[0][2]:.2f} | {ec:.2f} / {ed:.2f} | {o[1][0]:.2f} / {o[1][1]:.2f} |")
print("\nBest settings (reps counted): Charades per node count; Devastator W")
for wl in OLD:
    print(f"  {wl}: " + "; ".join(f"N{n} {cb(wl, n)[1]} {cb(wl, n)[2]} ({cb(wl, n)[3]})" for n in Ns) + " | Devastator W " + ", ".join(f"{db(wl, n)[1]} ({db(wl, n)[2]})" for n in Ns))
print("\nCharades' controller ÷ its best fixed W (same aggregation), 1 / 4 / 16 nodes; short runs at 16 in brackets")
for wl, o in OLD.items():
    out = []
    for n in Ns:
        b = max((med(v), t) for (w, nn, t, a), v in C.items() if w == wl and nn == n and not a.startswith("q"))
        q = [med(v) for (w, nn, t, a), v in C.items() if w == wl and nn == n and t == b[1] and a.startswith("q")]
        out.append(f"{q[0] / b[0]:.2f}" if q else "n/a")
    print(f"  {wl}: " + " / ".join(out) + (f" [{o[2]:.2f}]" if o[2] else ""))
print("\nSpread: max/min over the 3 reps of the best Charades cell at 16 nodes")
for wl in OLD:
    _, t, a, _ = cb(wl, 16); v = C[(wl, 16, t, a)]
    print(f"  {wl}: {', '.join(f'{x:.1f}' for x in v)} ({max(v) / min(v):.3f})")
