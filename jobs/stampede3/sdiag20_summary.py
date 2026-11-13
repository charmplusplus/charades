#!/usr/bin/env python3
"""Where the cross-process reduction's time goes (charades RESULTS.md sections 117/118).
Usage: sdiag20_summary.py <job dir>"""
import csv, glob, os, statistics as st, sys
from collections import defaultdict
d = sys.argv[1]; mean = st.fmean; med = st.median
RED = ["charm", "tree4", "flat", "ar"]
NAME = {"charm": "Charm++ reduction", "tree4": "tree, fan-out 4", "flat": "flat tree", "ar": "recursive doubling"}

def rows(tag):
    return [x for f in glob.glob(f"{d}/{tag}.csv") for x in csv.DictReader(open(f)) if x["status"] == "ok"]
def mrate(fmt, pred=lambda x: True):
    v = [float(x["event_rate"]) / 1e6 for r in (1, 2) for x in rows(fmt.format(r=r)) if pred(x)]
    return (mean(v) if v else float("nan")), v
def pct(v, q):
    v = sorted(v); return v[min(len(v) - 1, int(q * len(v)))] if v else float("nan")
def mid(n):  # waves 10-95%
    return range(max(1, n // 10), n * 95 // 100)

def waves(run):
    """Per process: list of gvt_waves rows (one per wave, own clock)"""
    P = {}
    for f in glob.glob(f"{run}/gvt_waves_*.csv"):
        P[int(os.path.basename(f)[10:-4])] = [{k: float(v) for k, v in x.items()} for x in csv.DictReader(open(f))]
    return P

def split(run):
    """Advance, floor (slowest process: last PE in -> result), first hop, as in section 80"""
    P = waves(run)
    if not P: return None
    n = min(len(v) for v in P.values()); A, F, H, Hs, R = [], [], [], [], []
    for i in mid(n):
        work = {p: v[i]["last_s"] - v[i - 1]["result_s"] for p, v in P.items()}
        s = max(work, key=work.get); w = P[s][i]
        F.append(1e6 * (w["result_s"] - w["last_s"]))
        if w["handled_s"] > 0: Hs.append(1e6 * (w["handled_s"] - w["last_s"]))
        A.append(1e6 * (P[0][i]["result_s"] - P[0][i - 1]["result_s"]))
        for v in P.values():
            if v[i]["handled_s"] > 0: H.append(1e6 * (v[i]["handled_s"] - v[i]["last_s"]))
    return dict(advance=mean(A), floor=mean(F), floor_med=med(F), hop1=med(H) if H else float("nan"),
                hop1_slow=med(Hs) if Hs else float("nan"), n=len(A))

def hops(run, k, nproc):
    """Offset-corrected tree hops: up (child -> parent) and down (parent -> child), µs"""
    H = defaultdict(dict)  # (child, parent) -> {('u'|'d', wave): raw}
    rank_n = defaultdict(int); spread = []
    sent_by_wave = defaultdict(list)
    for f in glob.glob(f"{run}/gvt_hops_*.csv"):
        p = int(os.path.basename(f)[9:-4])
        for x in csv.DictReader(open(f)):
            kind, wv, peer = int(x["kind"]), int(x["wave"]), int(x["peer"])
            s, r = float(x["sent_s"]), float(x["recv_s"])
            if kind == 0: H[(peer, p)][("u", wv)] = r - s; rank_n[("up", int(x["rank"]))] += 1
            elif kind == 1:
                H[(p, peer)][("d", wv)] = r - s; rank_n[("down", int(x["rank"]))] += 1
                if peer == 0: sent_by_wave[wv].append(s)
    def depth(c):
        dd = 0
        while c: c = (c - 1) // k; dd += 1
        return dd
    up, dn, upx, dnx = defaultdict(list), defaultdict(list), [], []
    for (c, p), m in H.items():
        ws = sorted({w for (_, w) in m if ("u", w) in m and ("d", w) in m})
        if not ws: continue
        ws = ws[len(ws) // 10: len(ws) * 95 // 100]
        for j in range(0, len(ws), 200):
            win = ws[j:j + 200]
            mu = min(m[("u", w)] for w in win); md = min(m[("d", w)] for w in win)
            off = (mu - md) / 2
            for w in win:
                u = 1e6 * (m[("u", w)] - off); dv = 1e6 * (m[("d", w)] + off)
                up[depth(c)].append(u); dn[depth(c)].append(dv)
                upx.append(1e6 * (m[("u", w)] - mu)); dnx.append(1e6 * (m[("d", w)] - md))
    for wv, s in sent_by_wave.items():
        if len(s) > 1: spread.append(1e6 * (max(s) - min(s)))
    return up, dn, upx, dnx, rank_n, spread

print("A. Throughput, σ 2,000, W 400, PP 512 (M committed ev/s, mean of 2 reps; higher is better)")
base = {}
for n in (4, 16):
    for r in RED:
        o, ov = mrate(f"A_{r}_off_n{n}_r{{r}}"); t, _ = mrate(f"A_{r}_T_n{n}_r{{r}}")
        if r == "charm": base[n] = o
        print(f"  {n:>2} nodes {NAME[r]:20}: {o:6.1f} ({', '.join(f'{x:.1f}' for x in ov)}) ÷ Charm++ reduction {o / base[n]:.3f}, traced/untraced {t / o:.3f}")
for r in RED:
    o4, _ = mrate(f"A_{r}_off_n4_r{{r}}"); o16, _ = mrate(f"A_{r}_off_n16_r{{r}}")
    print(f"  4->16 node efficiency, {NAME[r]}: {o16 / (4 * o4):.2f}")

print("\nA. A GVT advance (µs, waves 10-95%, both reps; lower is better). floor = slowest process, last PE in -> result;")
print("   first hop = last PE in -> its process's handler takes the sums (median over all processes / over the slowest)")
for n in (4, 16):
    for r in RED:
        S = [split(f"{d}/A_{r}_T_n{n}_r{rep}/ctl_sweep") for rep in (1, 2)]; S = [s for s in S if s]
        if not S: print(f"  {n:>2} nodes {NAME[r]}: no trace"); continue
        g = lambda k: mean(s[k] for s in S)
        print(f"  {n:>2} nodes {NAME[r]:20}: advance {g('advance'):5.0f}, floor {g('floor'):5.1f} (median {g('floor_med'):5.1f}), "
              f"first hop {g('hop1'):5.1f} / {g('hop1_slow'):5.1f} ({sum(s['n'] for s in S)} waves)")

print("\nA. Tree hops, offset-corrected (µs; lower is better); excess = above the pair's fastest hop in its 200-wave window")
for n in (4, 16):
    nproc = 2 * n
    for r, k in (("tree4", 4), ("flat", 64)):
        U, D, UX, DX, RK, SP = defaultdict(list), defaultdict(list), [], [], defaultdict(int), []
        for rep in (1, 2):
            u, dn, ux, dx, rk, sp = hops(f"{d}/A_{r}_T_n{n}_r{rep}/ctl_sweep", k, nproc)
            for kk, v in u.items(): U[kk] += v
            for kk, v in dn.items(): D[kk] += v
            UX += ux; DX += dx; SP += sp
            for kk, v in rk.items(): RK[kk] += v
        if not UX: print(f"  {n:>2} nodes {NAME[r]}: no hops"); continue
        print(f"  {n:>2} nodes {NAME[r]}:")
        for lv in sorted(U):
            print(f"    level {lv}: up median {med(U[lv]):5.1f} p90 {pct(U[lv], .9):5.1f} min {min(U[lv]):5.1f} | "
                  f"down median {med(D[lv]):5.1f} p90 {pct(D[lv], .9):5.1f} min {min(D[lv]):5.1f}  ({len(U[lv])} hops)")
        print(f"    excess: up median {med(UX):5.1f} p90 {pct(UX, .9):5.1f} | down median {med(DX):5.1f} p90 {pct(DX, .9):5.1f}"
              + (f" | root's sends to its children span {med(SP):.1f} µs (median)" if SP else ""))
        for dirn in ("up", "down"):
            tot = sum(v for (dd, _), v in RK.items() if dd == dirn)
            top = sorted(((v, rk) for (dd, rk), v in RK.items() if dd == dirn), reverse=True)[:4]
            print(f"    {dirn} handled by rank: " + ", ".join(f"r{rk} {v / tot:.2f}" for v, rk in top))

print("\nB. Scheduler pass size, Charm++ reduction (M committed ev/s; ÷ batch 16; higher is better)")
for n in (4, 16):
    b16, _ = mrate(f"A_charm_off_n{n}_r{{r}}")
    for b in (4, 8):
        o, ov = mrate(f"B_b{b}_off_n{n}_r{{r}}")
        line = f"  {n:>2} nodes batch {b}: {o:6.1f} ({', '.join(f'{x:.1f}' for x in ov)}) ÷ batch 16 {o / b16:.3f}"
        if n == 16:
            S = [split(f"{d}/B_b{b}_T_n16_r{rep}/ctl_sweep") for rep in (1, 2)]; S = [s for s in S if s]
            if S: line += f" | advance {mean(s['advance'] for s in S):.0f} µs, floor {mean(s['floor'] for s in S):.1f} µs"
        print(line)

print("\nC. Flat tree ÷ Charm++ reduction, 16 nodes (M committed ev/s, mean of 2 reps; higher is better)")
for wl, tag in (("gauss:100:1000:4000", "s4k"), ("steady:100:1000:1.0", "uni")):
    for arm in ("w:400", "q:0.001"):
        c, cv = mrate(f"C_charm_{tag}_r{{r}}", lambda x: x["arm"] == arm)
        f, fv = mrate(f"C_flat_{tag}_r{{r}}", lambda x: x["arm"] == arm)
        print(f"  {wl:22} {('W 400' if arm == 'w:400' else 'controller'):10}: Charm++ {c:6.1f} ({', '.join(f'{x:.0f}' for x in cv)}), "
              f"flat {f:6.1f} ({', '.join(f'{x:.0f}' for x in fv)}), ratio {f / c:.3f}")
