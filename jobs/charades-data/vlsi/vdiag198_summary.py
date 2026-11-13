#!/usr/bin/env python3
"""VLSI step-cost diagnostic, job V3 (RESULTS.md section 198): b19 x N, one
copy per node, span 1, direct sends, buckets of 2,500 ps, 1 and 4 nodes.
Per node count: each arm of both engines (M committed ev/s, median of 2 reps,
÷ that engine's reference arm, ms per clock cycle; higher rate is better,
lower ms is better), counts and digests (Y1); Charades ÷ Devastator at W 2,500
and W 10,000 (Y2); on a single worker (Y3) and the share of the 1-node gap
that per-event cost accounts for; 1 x 46 ÷ 2 x 23 and the share hops between
processes account for (Y4); --comm-stats latencies by class (Y5); per-cycle
time at 4 nodes minus at 1 node (Y6); per-PE stats at W 2,500 and 10,000 (Y7).
Usage: vdiag198_summary.py <job dir>"""
import csv, glob, math, os, re, statistics as st, sys
d = sys.argv[1]
CYC = {'1w': 500}          # clock cycles per run: 5,000 except the single-worker arms

def med(xs): return st.median(xs) if xs else None
rows = []
for f in glob.glob(f'{d}/n*/s1_*_r[12].csv'):
    n = int(f.split('/n')[-1].split('/')[0]); tag = os.path.basename(f)[:-4]
    head, rep = tag.rsplit('_r', 1); arm = head[3:]
    for r in csv.DictReader(open(f)):
        if r['status'] != 'ok': print('FAILED charades', n, tag, r['status']); continue
        ex = float(r['exec_s']); c = int(r['committed'])
        rows.append(dict(eng='C', n=n, arm=arm, rep=int(rep), rate=c / ex / 1e6, committed=c, digest=r['digest'],
                         ms=1e3 * ex / CYC.get(arm, 5000), eff=float(r['efficiency']), blk=float(r['blocked_pct'] or 0),
                         bmin=float(r['blocked_min_pct'] or 0), bmax=float(r['blocked_max_pct'] or 0),
                         log=glob.glob(f'{d}/n{n}/{tag}/ctl_sweep/logs/*.out')))
p = f'{d}/deva.txt'
for line in (open(p) if os.path.exists(p) else []):
    r = dict(x.split('=', 1) for x in line.split() if '=' in x)
    if r.get('status') != 'ok' or not r.get('M_ev_s'):
        print('FAILED devastator', r.get('nodes'), r.get('arm'), 'rep', r.get('rep'), r.get('status')); continue
    if r['arm'] == 'perf': continue
    c = int(r['committed']); rate = float(r['M_ev_s'])
    rows.append(dict(eng='D', n=int(r['nodes']), arm=r['arm'], rep=int(r['rep']), rate=rate, committed=c, digest=None,
                     ms=1e3 * c / (rate * 1e6) / CYC.get(r['arm'], 5000), eff=100.0 * c / max(1, int(r['executed'] or 0)),
                     blk=None, bmin=None, bmax=None, det=r.get('deterministic'), log=[]))

def m(eng, n, arm, k='rate'): return med([r[k] for r in rows if r['eng'] == eng and r['n'] == n and r['arm'] == arm])
def stat(f, key):
    for line in open(f):
        if key in line: return float(line.split()[-1])
    return None

for n in (1, 4):
    rs = [r for r in rows if r['n'] == n]
    if not rs: continue
    full = sorted({r['committed'] for r in rs if r['arm'] != '1w'})
    one = sorted({r['committed'] for r in rs if r['arm'] == '1w'})
    dg = sorted({r['digest'] for r in rs if r['eng'] == 'C' and r['arm'] != '1w'})
    det = sorted({r.get('det') for r in rs if r['eng'] == 'D'})
    print(f"\n===== {n} node(s): counts {full}{' <-- DIFFER' if len(full) > 1 else ''}; single worker {one}"
          f"{' <-- DIFFER' if len(one) > 1 else ''}; Charades digests {dg}; Devastator deterministic {det}")
    print(f"   {'engine arm':16} {'M ev/s':>7} {'÷ref':>5} {'ms/cycle':>8} {'eff%':>6} {'blk%':>5} {'min':>5} {'max':>5}  reps")
    for eng in ('C', 'D'):
        ref = m(eng, n, 'ref')
        for a in sorted({r['arm'] for r in rs if r['eng'] == eng}, key=lambda a: -m(eng, n, a)):
            ar = [r for r in rs if r['eng'] == eng and r['arm'] == a]
            b = (f"{med([r['blk'] for r in ar]):5.1f} {med([r['bmin'] for r in ar]):5.1f} {med([r['bmax'] for r in ar]):5.1f}"
                 if eng == 'C' else ' ' * 17)
            print(f"   {('Charades ' if eng == 'C' else 'Devastator ') + a:16} {m(eng, n, a):7.2f} "
                  f"{m(eng, n, a) / ref if ref and a != '1w' else float('nan'):5.2f} {m(eng, n, a, 'ms'):8.3f} "
                  f"{med([r['eff'] for r in ar]):6.2f} {b}  {'/'.join('%.2f' % r['rate'] for r in sorted(ar, key=lambda r: r['rep']))}")
    r46 = (m('C', n, 'ref') or 0) / (m('D', n, 'ref') or 1)
    print(f"-- Y2: Charades ÷ Devastator at W 2,500: {r46:.3f}" + (
        f"; at W 10,000: {m('C', n, 'w10k') / m('D', n, 'w10k'):.3f}; each at its better W: "
        f"{max(m('C', n, 'ref'), m('C', n, 'w10k')) / max(m('D', n, 'ref'), m('D', n, 'w10k')):.3f}" if m('C', n, 'w10k') and m('D', n, 'w10k') else ''))
    g = (m('C', n, '1p') or 0) / (m('C', n, 'ref') or 1)
    print(f"-- Y4: Charades 1 x 46 ÷ 2 x 23: {g:.3f}" + (f"; share of the gap (ln g / -ln Y2): {math.log(g) / -math.log(r46):.2f}" if g > 0 and 0 < r46 < 1 else ''))
    if n == 1 and m('C', 1, '1w') and m('D', 1, '1w'):
        r1 = m('C', 1, '1w') / m('D', 1, '1w')
        print(f"-- Y3: single worker, Charades ÷ Devastator: {r1:.3f} ({m('C', 1, '1w'):.2f} / {m('D', 1, '1w'):.2f} M ev/s; "
              f"µs per committed event {1 / m('C', 1, '1w'):.3f} / {1 / m('D', 1, '1w'):.3f})"
              + (f"; share of the gap (ln Y3 / ln Y2): {math.log(r1) / math.log(r46):.2f}" if 0 < r46 < 1 else ''))
    for a in ('cs', '1pcs'):
        ar = [r for r in rs if r['eng'] == 'C' and r['arm'] == a]
        if not ar: continue
        base = m('C', n, 'ref' if a == 'cs' else '1p')
        print(f"-- Y5: {a} (÷ {'2 x 23' if a == 'cs' else '1 x 46'} without --comm-stats: {m('C', n, a) / base:.3f})")
        for r in sorted(ar, key=lambda r: r['rep']):
            for f in r['log']:
                print(f"     rep {r['rep']}: send call {stat(f, 'Mean Send Call (us)')} µs, {stat(f, 'Send Calls % of PE Time')}% of PE time")
                for c in ('Same Process', 'Same Node', 'Other Node'):
                    cnt = stat(f, f'Latency {c}: Count')
                    if cnt is None: continue
                    q = [stat(f, f'Latency {c}: {k} <= (us)') for k in ('p50', 'p90', 'p99')]
                    print(f"       {c:12} count {cnt:>12,.0f}  mean {stat(f, f'Latency {c}: Mean (us)'):7.2f} µs  "
                          f"p50 ≤ {q[0]} p90 ≤ {q[1]} p99 ≤ {q[2]} µs")

print()
for eng, a in (('C', 'ref'), ('C', '1p'), ('D', 'ref')):
    t1, t4 = m(eng, 1, a, 'ms'), m(eng, 4, a, 'ms')
    if t1 and t4: print(f"-- Y6: {'Charades' if eng == 'C' else 'Devastator'} {a}: ms per cycle 1 node {t1:.3f}, 4 nodes {t4:.3f}, "
                        f"difference {t4 - t1:.3f} ms (4 nodes ÷ 1 node {t4 / t1:.2f})")

for f in sorted(glob.glob(f'{d}/n*/pe*/ctl_sweep/pe_stats.csv')):
    rs = [{k: float(v) for k, v in r.items()} for r in csv.DictReader(open(f))]
    for r in rs:
        r['bs'] = 100 * r['blocked_s'] / r['total_s']; r['xc'] = r['executed'] / max(1, r['committed'])
    mex = st.mean(r['executed'] for r in rs); mcm = st.mean(r['committed'] for r in rs)
    bs = sorted(r['bs'] for r in rs)
    corr = st.correlation([r['bs'] for r in rs], [r['executed'] for r in rs]) if len(rs) > 2 else float('nan')
    corc = st.correlation([r['bs'] for r in rs], [r['committed'] for r in rs]) if len(rs) > 2 else float('nan')
    tag = f.replace(d + '/', '').split('/ctl_sweep')[0]
    print(f"\n-- Y7: {tag}: {len(rs)} PEs; blocked % min {bs[0]:.1f}, median {st.median(bs):.1f}, max {bs[-1]:.1f}; "
          f"median PE executed ÷ committed {st.median(r['xc'] for r in rs):.3f}; corr(blocked %, executed) {corr:.2f}, "
          f"(blocked %, committed) {corc:.2f}")
    for r in sorted(rs, key=lambda r: r['bs'])[:5]:
        print(f"     least blocked: PE {r['pe']:.0f} (process {r['process']:.0f}, rank {r['rank']:.0f}) blocked {r['bs']:.1f}%, "
              f"executed ÷ mean {r['executed'] / mex:.2f}, committed ÷ mean {r['committed'] / mcm:.2f}, executed ÷ committed {r['xc']:.3f}, "
              f"remote sends {r['remote_sends']:,.0f}")
print("\nperf reports:", sorted(glob.glob(f'{d}/perf/*.report.txt')))
