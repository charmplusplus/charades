#!/usr/bin/env python3
"""1/4/16 nodes on 23 devices, both engines; glibc no-trim at 16 nodes (charades RESULTS.md section 93/95). Usage: scale23_summary.py <job dir>"""
import csv, glob, re, sys, statistics as st
from collections import defaultdict
d = sys.argv[1]; med = st.median
OLD = {  # job 3639098 (16 devices): Charades / Devastator M ev/s at 1, 4, 16 nodes; speedup 1/4/16; eff 4->16 C/D
 "gauss:100:1000:100": ((1.14, 0.97, 0.92), (0.93, 0.98)), "gauss:100:1000:500": ((1.07, 1.10, 1.08), (0.90, 0.92)),
 "gauss:100:1000:1000": ((1.08, 1.21, 1.26), (0.89, 0.86)), "gauss:100:1000:2000": ((1.27, 1.21, 0.95), (0.71, 0.91)),
 "gauss:100:1000:4000": ((1.32, 1.40, 1.04), (0.69, 0.93)), "steady:100:1000:1.0": ((1.38, 1.69, 0.99), (0.40, 0.68)),
 "gauss:10:200:500": ((0.96, 0.91, 0.85), (0.81, 0.87)), "gauss:10:200:2000": ((1.09, 0.97, 0.76), (0.71, 0.91))}
C = defaultdict(list); M = defaultdict(list)
for f in glob.glob(f"{d}/*_n*_r[123].csv"):
    tag = f.split("/")[-1][:-4]; base = re.sub(r"_n\d+_r\d$", "", tag); n = int(re.search(r"_n(\d+)_r", tag).group(1))
    for x in csv.DictReader(open(f)):
        if x["status"] != "ok": continue
        r = float(x["event_rate"]) / 1e6
        if base.startswith("mt_"): M[(x["workload"], base[3:], x["arm"])].append(r)
        else: C[(x["workload"], n, base, x["arm"])].append(r)
D = defaultdict(list); DM = defaultdict(list)
for line in open(f"{d}/deva/results.txt"):
    m = re.search(r"label=(mt)?(hi|lo)_n(\d+)_s(\d+)_w(\d+)_r\d .*status=ok.*committed_per_s=([0-9.e+]+)", line)
    if not m: continue
    mt, kind, n, s, w, r = m.groups()
    wl = ("steady:100:1000:1.0" if s == "0" else f"gauss:100:1000:{s}") if kind == "hi" else f"gauss:10:200:{s}"
    (DM if mt else D)[(wl, int(n), int(w))].append(float(r) / 1e6)
Ns = [1, 4, 16]
def cb(wl, n): return max((med(v), t, a) for (w, nn, t, a), v in C.items() if w == wl and nn == n)
def db(wl, n): return max((med(v), w) for (ww, nn, w), v in D.items() if ww == wl and nn == n)
print("| workload | Charades 1 / 4 / 16 nodes (M ev/s) | Devastator 1 / 4 / 16 nodes (M ev/s) | Charades ÷ Devastator 1 / 4 / 16 | before (16 devices) | efficiency 4→16, Charades / Devastator | before |")
print("|---|---|---|---|---|---|---|")
for wl in OLD:
    c = [cb(wl, n)[0] for n in Ns]; dv = [db(wl, n)[0] for n in Ns]
    sp = [a / b for a, b in zip(c, dv)]; ec = (c[2] / 16) / (c[1] / 4); ed = (dv[2] / 16) / (dv[1] / 4)
    o = OLD[wl]
    print(f"| {wl} | {c[0]:.1f} / {c[1]:.1f} / {c[2]:.1f} | {dv[0]:.1f} / {dv[1]:.1f} / {dv[2]:.1f} | **{sp[0]:.2f} / {sp[1]:.2f} / {sp[2]:.2f}** | {o[0][0]:.2f} / {o[0][1]:.2f} / {o[0][2]:.2f} | {ec:.2f} / {ed:.2f} | {o[1][0]:.2f} / {o[1][1]:.2f} |")
print("\nBest settings: Charades per N; Devastator W per N")
for wl in OLD:
    print(f"  {wl}: " + "; ".join(f"N{n} {cb(wl, n)[1]} {cb(wl, n)[2]}" for n in Ns) + " | Deva W " + ", ".join(str(db(wl, n)[1]) for n in Ns))
print("\nController ÷ best fixed W (same aggregation), 1 / 4 / 16 nodes")
for wl in OLD:
    out = []
    for n in Ns:
        b = max((med(v), t) for (w, nn, t, a), v in C.items() if w == wl and nn == n and not a.startswith("q"))
        q = [med(v) for (w, nn, t, a), v in C.items() if w == wl and nn == n and t == b[1] and a.startswith("q")]
        out.append(f"{q[0] / b[0]:.2f}" if q else "n/a")
    print(f"  {wl}: " + " / ".join(out))
print("\nglibc no-trim ÷ defaults at 16 nodes, same arm (median of 3 each; higher is better)")
print("| workload | Charades, fixed W (setting) | Charades, controller | Devastator (W) |")
print("|---|---|---|---|")
for wl in OLD:
    fx = [(med(M[k]) / med(C[(wl, 16, k[1], k[2])]), k[1], k[2]) for k in M if k[0] == wl and not k[2].startswith("q") and (wl, 16, k[1], k[2]) in C]
    qq = [(med(M[k]) / med(C[(wl, 16, k[1], k[2])]), k[1]) for k in M if k[0] == wl and k[2].startswith("q") and (wl, 16, k[1], k[2]) in C]
    dm = [(med(DM[k]) / med(D[k]), k[2]) for k in DM if k[0] == wl and k in D]
    print(f"| {wl} | " + ", ".join(f"{r:.3f} ({t} {a})" for r, t, a in sorted(fx, key=lambda z: z[1])) + " | " + ", ".join(f"{r:.3f} ({t})" for r, t in sorted(qq, key=lambda z: z[1])) + " | " + ", ".join(f"{r:.3f} (W {w})" for r, w in dm) + " |")
allc = [med(M[k]) / med(C[(k[0], 16, k[1], k[2])]) for k in M if (k[0], 16, k[1], k[2]) in C]
alld = [med(DM[k]) / med(D[k]) for k in DM if k in D]
print(f"\nCharades no-trim ÷ defaults over all {len(allc)} cells: geomean {st.geometric_mean(allc):.3f}, range {min(allc):.3f}-{max(allc):.3f}, >= 1.03 in {sum(x >= 1.03 for x in allc)}")
print(f"Devastator: geomean {st.geometric_mean(alld):.3f}, range {min(alld):.3f}-{max(alld):.3f}")
best_m = {}
for wl in OLD:
    bm = max(med(v) for k, v in M.items() if k[0] == wl); b0 = cb(wl, 16)[0]
    best_m[wl] = bm / b0
print("Charades best no-trim ÷ best defaults (over the full grid) at 16 nodes: " + ", ".join(f"{wl.split(':')[-1] if 'gauss:100' in wl else wl}: {r:.3f}" for wl, r in best_m.items()))
