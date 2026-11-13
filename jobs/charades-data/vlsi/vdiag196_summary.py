#!/usr/bin/env python3
"""VLSI diagnostic, job V2 (RESULTS.md section 196): Charades only, b19 x N at
1 and 4 nodes. Per node count: each arm (M committed ev/s, median of 2 reps,
and ÷ the reference: direct sends, W 2,500, buckets of 500, batch 16; higher is
better), efficiency, blocked share (mean, per-PE min/max), mean W, GVT updates,
count waves, the slowest PE's mean lead over GVT; counts and digests (X1).
Then the traces (rep 1, --gvt-trace=1): waves, waves per GVT update, wave
duration, gap between waves, PE 0's lead over GVT (X7).
Usage: vdiag196_summary.py <job dir>"""
import csv, glob, os, statistics as st, sys
d = sys.argv[1]

def med(xs): return st.median(xs) if xs else None
rows = []
for f in glob.glob(f'{d}/n*/s1_*_r[12].csv'):
    n = int(f.split('/n')[-1].split('/')[0]); tag = os.path.basename(f)[:-4]
    head, rep = tag.rsplit('_r', 1)
    for r in csv.DictReader(open(f)):
        if r['status'] != 'ok': print('FAILED', n, tag, r['arm'], r['status']); continue
        ex = float(r['exec_s'])
        rows.append(dict(n=n, rep=int(rep), arm=f"{head[3:]} {r['arm']}", rate=int(r['committed']) / ex / 1e6,
                         committed=r['committed'], digest=r['digest'], eff=float(r['efficiency']),
                         blk=float(r['blocked_pct'] or 0), bmin=float(r['blocked_min_pct'] or 0),
                         bmax=float(r['blocked_max_pct'] or 0), meanw=float(r['mean_window'] or 0),
                         gvts=int(r['gvts']), waves=int(r['count_waves'] or 0), lag=float(r['gvt_lag'] or 0), ex=ex))
REF = 'direct_batch16 w:2500'
for n in (1, 4):
    rs = [r for r in rows if r['n'] == n]
    if not rs: continue
    print(f"\n===== {n} node(s): counts {sorted({r['committed'] for r in rs})}; digests {sorted({r['digest'] for r in rs})}")
    arms = sorted({r['arm'] for r in rs})
    m = {a: med([r['rate'] for r in rs if r['arm'] == a]) for a in arms}
    ref = m.get(REF)
    print(f"   {'arm':32} {'M ev/s':>7} {'÷ref':>5} {'eff%':>6} {'blk%':>5} {'min':>5} {'max':>5} {'meanW':>6} {'GVTs':>6} {'waves/GVT':>9} {'lag ps':>7} {'ms/cycle':>8}")
    for a in sorted(arms, key=lambda a: -m[a]):
        ar = [r for r in rs if r['arm'] == a]
        g = lambda k: med([r[k] for r in ar])
        print(f"   {a:32} {m[a]:7.1f} {m[a] / ref if ref else 0:5.2f} {g('eff'):6.2f} {g('blk'):5.1f} {g('bmin'):5.1f} {g('bmax'):5.1f} "
              f"{g('meanw'):6.0f} {g('gvts'):6.0f} {g('waves') / max(1, g('gvts')):9.2f} {g('lag'):7.0f} {1000 * g('ex') / 5000:8.3f}")
    pick = lambda a: m.get(a)
    for c, f in (('direct_ctl mb:0', 'direct_batch16 w:2500'), ('direct_ctl_b2500 mb:0', 'direct_b2500 w:2500'),
                 ('direct_ctl_b2500 mb:0', 'direct_batch16 w:2500'), ('wps512_b2500 w:2500', 'direct_b2500 w:2500')):
        if pick(c) and pick(f): print(f"-- {c} ÷ {f}: {pick(c) / pick(f):.2f}")
    v1pp = {1: 19.3, 4: 48.0}[n]
    if pick('pp2048_ctl_b2500 mb:0'): print(f"-- pp2048_ctl_b2500 mb:0 ÷ V1's best PP 2,048 ({v1pp}): {pick('pp2048_ctl_b2500 mb:0') / v1pp:.2f}")

print("\n===== traces (rep 1, direct W 2,500)")
for f in sorted(glob.glob(f'{d}/n*/trace_*/ctl_sweep/gvt_trace.csv')):
    n = int(f.split('/n')[-1].split('/')[0]); b = f.split('/trace_b')[1].split('/')[0]
    w = [r for r in csv.DictReader(open(f))]
    if len(w) < 20: print(f"  {n} node(s), buckets {b}: only {len(w)} waves"); continue
    w = w[len(w) // 10: len(w) * 9 // 10]   # middle 80%
    dur = [float(r['end_s']) - float(r['start_s']) for r in w]
    gap = [float(w[i + 1]['start_s']) - float(w[i]['end_s']) for i in range(len(w) - 1)]
    upd = sum(1 for r in w if int(r['completed']) > 0)
    lead = [int(r['lead0']) for r in w]
    span_s = float(w[-1]['end_s']) - float(w[0]['start_s'])
    print(f"  {n} node(s), buckets {b}: {len(w)} waves (middle 80%) over {span_s:.2f} s; waves per GVT update {len(w) / max(1, upd):.2f}; "
          f"wave duration median {1e3 * med(dur):.3f} ms (p90 {1e3 * sorted(dur)[len(dur) * 9 // 10]:.3f}); "
          f"gap median {1e3 * med(gap):.3f} ms; PE 0 lead over GVT median {med(lead)} ps, share ≥ 1,500 ps {sum(x >= 1500 for x in lead) / len(lead):.2f}; "
          f"valid buckets median {med([int(r['valid']) for r in w])}")
