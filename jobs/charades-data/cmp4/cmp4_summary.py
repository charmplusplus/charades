#!/usr/bin/env python3
"""Summarise the three-engine comparison at 4 nodes (charades RESULTS.md,
"Three engines at 4 nodes, paper grade"). Run in the directory holding the
Charades CSVs, deva/results.txt and ross/results.txt. Rates are M committed
events/s, medians over reps; a run that appears twice (a rerun) counts once,
its latest line."""
import csv, glob, re, statistics as st
from collections import defaultdict

WL = [("hi", s) for s in (100, 500, 1000, 2000, 4000, 0)] + \
     [("lo", s) for s in (500, 2000, 0)] + [("ph", 0.5), ("ph", 1.0)]

def wl_charades(kind, s):
    if kind == "ph": return f"phases:10:200:100:1000:{s}:32000"
    la, mean = (100, 1000) if kind == "hi" else (10, 200)
    return f"steady:{la}:{mean}:1.0" if s == 0 else f"gauss:{la}:{mean}:{s}"

def name(kind, s):
    if kind == "ph": return f"phases, remote {s}"
    la = "lookahead 100" if kind == "hi" else "lookahead 10"
    return f"{la}, {'uniform' if s == 0 else f'σ {s:,}'}"

# Charades: (agg, workload, arm) -> {rep: (rate, committed, meanW)}
ch = defaultdict(dict)
for f in sorted(glob.glob("*_r[0-9]*.csv")):
    for r in csv.DictReader(open(f)):
        if r["status"] != "ok": continue
        rep = int(re.search(r"_r(\d+)\.csv$", f).group(1))
        ch[(r["agg"], r["workload"], r["arm"])][rep] = (
            float(r["event_rate"]) / 1e6, int(r["committed"]), r["mean_window"])

# Devastator: label -> latest line
dv = {}
for line in open("deva/results.txt"):
    kv = dict(t.split("=", 1) for t in line.split() if "=" in t)
    dv[kv["label"]] = kv
dva = defaultdict(dict)   # (tag, sigma, window) -> {rep: rate or None}
dvc = {}
for lab, kv in dv.items():
    m = re.match(r"(hi|lo|ph_r[0-9.]+)_s(\d+)_w(\w+)_r(\d+)$", lab)
    tag, sig, w, rep = m.group(1), int(m.group(2)), m.group(3), int(m.group(4))
    key = ("ph", float(tag[4:])) if tag.startswith("ph") else (tag, sig)
    ok = kv["status"].startswith("ok") and "committed_per_s" in kv
    dva[(key, w)][rep] = float(kv["committed_per_s"]) / 1e6 if ok else None
    if ok: dvc.setdefault(key, set()).add(int(kv["committed"]))

# ROSS
ro = defaultdict(dict); roc = {}
for line in open("ross/results.txt"):
    m = re.match(r"(hi|lo)_s(\d+)_r(\d+) rc=(\d+) committed (\S*) M_ev_s (\S*)", line)
    if not m: continue
    key, rep = (m.group(1), int(m.group(2))), int(m.group(3))
    if m.group(4) == "0" and m.group(6):
        ro[key][rep] = float(m.group(6)); roc.setdefault(key, set()).add(int(m.group(5)))

med = lambda d: st.median(v[0] if isinstance(v, tuple) else v for v in d.values()) if d else None
f1 = lambda x: "–" if x is None else f"{x:.1f}"
f2 = lambda x: "–" if x is None else f"{x:.2f}"

def best_fixed(agg, w):
    arms = {a: med(v) for (g, wl, a), v in ch.items() if g == agg and wl == w and a.startswith("w:")}
    if not arms: return None, None, arms
    a = max(arms, key=arms.get); return arms[a], a[2:], arms

print("| workload | Charades best fixed W | controller | ÷ best | direct best | direct ctl ÷ | aggregation | Devastator best fixed W | adaptive (÷; ok of n) | ROSS | Charades speedup over Devastator (best ÷ best) | controller ÷ Devastator best | Charades speedup over ROSS | reps | counts agree |")
print("|" + "---|" * 15)
for kind, s in WL:
    w = wl_charades(kind, s)
    cb, cw, _ = best_fixed("pp:512", w)
    cc = med(ch.get(("pp:512", w, "q:0.001"), {}))
    db, dwin, _ = best_fixed("off", w)
    dc = med(ch.get(("off", w, "q:0.001"), {}))
    fixed = {k[1]: med({r: v for r, v in d.items() if v is not None}) for k, d in dva.items()
             if k[0] == (kind, s) and k[1] != "adaptive"}
    fixed = {k: v for k, v in fixed.items() if v is not None}
    vb = max(fixed.values()) if fixed else None
    vw = max(fixed, key=fixed.get) if fixed else None
    ad = dva.get(((kind, s), "adaptive"), {})
    adok = {r: v for r, v in ad.items() if v is not None}
    am = med(adok)
    rs = med(ro.get((kind, s), {})) if kind != "ph" else None
    counts = {v[1] for (g, wl, a), d in ch.items() if wl == w for v in d.values()}
    counts |= dvc.get((kind, s), set()) | roc.get((kind, s), set())
    nrep = len(ch.get(("pp:512", w, "q:0.001"), {}))
    print(f"| {name(kind, s)} | {f1(cb)} (W {cw}) | {f1(cc)} | {f2(cc / cb if cb and cc else None)} | "
          f"{f1(db) + f' (W {dwin})' if db else '–'} | {f2(dc / db if db and dc else None)} | {f2(cb / db if db else None)} | "
          f"{f1(vb)} (W {vw}) | {f1(am)} ({f2(am / vb if am and vb else None)}; {len(adok)} of {len(ad)}) | {f1(rs)} | "
          f"{f2(cb / vb if vb else None)} | {f2(cc / vb if vb else None)} | {f2(cb / rs if rs else None)} | {nrep} | "
          f"{'yes' if len(counts) == 1 else counts} |")
