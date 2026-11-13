import csv, glob, re, sys, statistics as st
from collections import defaultdict, Counter
d = sys.argv[1]; mean = st.fmean; med = st.median
def rate(tag):
    v = [float(x["event_rate"]) / 1e6 for f in glob.glob(f"{d}/{tag}.csv") for x in csv.DictReader(open(f)) if x["status"] == "ok"]
    return v[0] if v else float("nan")
print("Throughput, untraced (M ev/s, reps; ratio = arm / m0)")
for wl in ["gauss_100_1000_100", "gauss_100_1000_2000"]:
    base = mean([rate(f"off_m0_{wl}_w400_r{k}") for k in (1, 2)])
    for m in ["m0", "mtrim", "mall"]:
        r = [rate(f"off_{m}_{wl}_w400_r{k}") for k in (1, 2)]
        print(f"  {wl} {m:6}: {mean(r):6.1f} ({r[0]:.1f}, {r[1]:.1f}) ratio {mean(r)/base:.3f}")
print("Lateness (traced): mean delay us r0 / r1 / median rest; r0 last-PE share")
for wl in ["gauss_100_1000_100", "gauss_100_1000_2000"]:
    for m in ["m0", "mtrim", "mall"]:
        D = defaultdict(list); last = Counter(); n_w = 0; worst = []
        for k in (1, 2):
            files = glob.glob(f"{d}/S_{m}_{wl}_w400_r{k}/ctl_sweep/gvt_ranks_*.csv")
            P = [[list(map(float, row)) for row in list(csv.reader(open(f)))[1:]] for f in files]
            if not P: continue
            n = min(len(p) for p in P); nr = len(P[0][0])
            for i in range(max(2, n // 10), n - n // 20):
                wp = max(range(len(P)), key=lambda p: max(P[p][i])); row = P[wp][i]
                last[max(range(nr), key=row.__getitem__)] += 1; n_w += 1; worst.append(max(row))
                for p in P:
                    for r in range(nr): D[r].append(p[i][r])
        if not D: print(f"  {wl} {m}: none"); continue
        rest = med([mean(D[r]) for r in range(2, 22)])
        print(f"  {wl} {m:6}: r0 {mean(D[0]):.0f} r1 {mean(D[1]):.0f} rest {rest:.0f}; r0 last {last[0]/n_w:.2f}; slowest-PE delay {mean(worst):.0f}")
