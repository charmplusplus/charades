#!/usr/bin/env python3
"""GVT advance breakdown, PP allocation vs limit, horizon margin (charades RESULTS.md section 79/80).
Usage: sdiag_summary.py <job dir>"""
import csv, glob, re, sys, statistics as st
from collections import defaultdict, Counter
d = sys.argv[1]
def rows(pat):
    for f in glob.glob(f"{d}/{pat}"):
        for x in csv.DictReader(open(f)):
            if x["status"] == "ok": yield f.split("/")[-1][:-4], x
med = st.median
# ---- A: traced vs untraced, and the wave breakdown
print("A. GVT advance breakdown, PP 512, W 250 (mean over waves, median over reps; µs; lower is better)\n")
print("| workload | nodes | traced ÷ untraced | advance | reduction floor (min wait) | median work | max work | straggler cost (max − median work) | spread in slowest process | advance p90 | most often slowest process (share of waves) | its most frequent last rank (share) |")
print("|---" * 12 + "|")
R = defaultdict(list)
for tag, x in rows("A_*.csv"):
    m = re.match(r"A_(tr|off)_(.+)_n(\d+)_r(\d)", tag)
    R[(m.group(2), int(m.group(3)), m.group(1))].append(float(x["event_rate"]))
for wl in ["gauss_100_1000_100", "gauss_100_1000_2000", "steady_100_1000_1.0"]:
    for n in [4, 8, 16]:
        ratio = med(R[(wl, n, "tr")]) / med(R[(wl, n, "off")]) if R[(wl, n, "tr")] and R[(wl, n, "off")] else float("nan")
        per_rep = []
        for rep in (1, 2, 3):
            files = sorted(glob.glob(f"{d}/A_tr_{wl}_n{n}_r{rep}/ctl_sweep/gvt_waves_*.csv"))
            if not files: continue
            P = [list(csv.DictReader(open(f))) for f in files]
            k = min(len(p) for p in P)
            lo, hi = k // 10, k - k // 20   # skip start-up and the tail
            adv, floor, mwork, xwork, strag, spread, lastp, lastr = [], [], [], [], [], [], Counter(), Counter()
            for w in range(max(lo, 1), hi):
                work = []; wait = []; sp = []; lr = []
                for p in P:
                    a, b = p[w - 1], p[w]
                    work.append(float(b["last_s"]) - float(a["result_s"]))
                    wait.append(float(b["result_s"]) - float(b["last_s"]))
                    sp.append(float(b["last_s"]) - float(b["first_s"]))
                    lr.append(int(b["last_rank"]))
                i = max(range(len(work)), key=work.__getitem__)
                adv.append(med([float(p[w]["result_s"]) - float(p[w - 1]["result_s"]) for p in P]))
                floor.append(min(wait)); mwork.append(med(work)); xwork.append(work[i])
                strag.append(work[i] - med(work)); spread.append(sp[i]); lastp[i] += 1; lastr[lr[i]] += 1
            nw = sum(lastp.values())
            mean = st.fmean
            top = lastp.most_common(1)[0]
            per_rep.append([mean(adv), mean(floor), mean(mwork), mean(xwork), mean(strag), mean(spread),
                            top[1] / nw, lastr.most_common(1)[0][1] / nw, lastr.most_common(1)[0][0],
                            sorted(adv)[int(0.9 * len(adv))], int(re.search(r"_(\d+)\.csv", files[top[0]]).group(1))])
        if not per_rep: continue
        c = [med(r[j] for r in per_rep) * 1e6 for j in range(6)]
        print(f"| {wl} | {n} | {ratio:.2f} | {c[0]:.0f} | {c[1]:.0f} | {c[2]:.0f} | {c[3]:.0f} | {c[4]:.0f} | {c[5]:.0f} | "
              f"{med(r[9] for r in per_rep)*1e6:.0f} | {'/'.join(str(r[10]) for r in per_rep)} ({med(r[6] for r in per_rep):.2f}) | {'/'.join(str(r[8]) for r in per_rep)} ({med(r[7] for r in per_rep):.2f}) |")
# ---- B
print("\nB. PP 2,048's allocation with PP 512's limit, 16 nodes, W 250 (M ev/s, median of 3; events per message; efficiency %)\n")
B = defaultdict(list)
for tag, x in rows("B_*.csv"):
    v = re.match(r"B_(\w+?)_r\d", tag).group(1)
    B[(x["workload"], v)].append((float(x["event_rate"]) / 1e6, float(x["agg_events_per_msg"]), float(x["efficiency"])))
print("| workload | PP 512 | PP 2,048 | PP 2,048 capped at 512 | capped ÷ PP 512 | capped ÷ PP 2,048 |"); print("|---" * 6 + "|")
for wl in ["gauss:100:1000:100", "gauss:100:1000:2000"]:
    r = {v: (med(a[0] for a in B[(wl, v)]), med(a[1] for a in B[(wl, v)]), med(a[2] for a in B[(wl, v)])) for v in ["pp512", "pp2048", "pp2048cap"]}
    print(f"| {wl} | " + " | ".join(f"{r[v][0]:.1f} ({r[v][1]:.1f}, {r[v][2]:.2f})" for v in ["pp512", "pp2048", "pp2048cap"]) +
          f" | {r['pp2048cap'][0]/r['pp512'][0]:.2f} | {r['pp2048cap'][0]/r['pp2048'][0]:.2f} |")
# ---- C
print("\nC. Horizon margin, 16 nodes (M ev/s, median of 2; ÷ PP 512 at margin 8 and the same W)\n")
C = defaultdict(list)
for tag, x in rows("C_*.csv"):
    a = re.match(r"C_(\w+?)_r\d", tag).group(1)
    C[(x["workload"], x["arm"], a, int(x["margin"]))].append((float(x["event_rate"]) / 1e6, float(x["efficiency"]), float(x["agg_events_per_msg"])))
print("| workload | W | setting | margin 8 | 32 | 64 | 128 |"); print("|---" * 7 + "|")
for wl in ["gauss:100:1000:100", "gauss:100:1000:2000", "gauss:100:1000:4000"]:
    for arm in ["w:250", "w:400"]:
        base = med(a[0] for a in C[(wl, arm, "pp512", 8)])
        for a in ["pp512", "pp2048"]:
            cells = []
            for mg in [8, 32, 64, 128]:
                v = C[(wl, arm, a, mg)]
                cells.append(f"{med(x[0] for x in v):.1f} ({med(x[0] for x in v)/base:.2f}; eff {med(x[1] for x in v):.2f}; m {med(x[2] for x in v):.0f})" if v else "—")
            print(f"| {wl} | {arm} | {a} | " + " | ".join(cells) + " |")
