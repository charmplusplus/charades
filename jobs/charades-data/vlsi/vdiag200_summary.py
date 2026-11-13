#!/usr/bin/env python3
"""VLSI job V4 (RESULTS.md section 200): b19 x N, one copy per node, span 1,
direct sends, buckets of 2,500 ps, 1 and 4 nodes. Charades A (2 x 23), B
(1 x 46), C (2 x 23, Charm++ --enable-shmem), D (2 x 23, +ipc), Ccs (C with
--comm-stats); Devastator d2 (2 x 23) and d1 (1 x 46). Per node count: each
arm (M committed ev/s, median of 2 reps, ÷ A at W 2,500, ms per cycle; higher
rate is better), counts, digests and shared-memory messages (Z1); C ÷ A and
C ÷ B (Z2); D ÷ C (Z3); latencies through the pool (Z4); Devastator's layouts
and Charades ÷ Devastator, each at its best (Z5); wider windows (Z6); per-PE
stats (Z7); per-copy activity, the same in every arm and as on the Mac (Z8).
Usage: vdiag200_summary.py <job dir> [Mac b19_4_5000.out]"""
import csv, glob, os, re, statistics as st, sys
d = sys.argv[1]; mac = sys.argv[2] if len(sys.argv) > 2 else None
CYC = 5000

def med(xs): return st.median(xs) if xs else None
def stat(f, key):
    for line in open(f):
        if key in line: return float(line.split()[-1])
    return None
def copies(f):
    return tuple(int(m.group(1)) for m in re.finditer(r'Copy activity \d+: (\d+)', open(f).read()))

rows = []
for f in glob.glob(f'{d}/n*/s1_*_r[12].csv'):
    n = int(f.split('/n')[-1].split('/')[0]); tag = os.path.basename(f)[:-4]
    head, rep = tag.rsplit('_r', 1); x = head[3:]
    for r in csv.DictReader(open(f)):
        if r['status'] != 'ok': print('FAILED charades', n, tag, r['arm'], r['status']); continue
        ex = float(r['exec_s']); c = int(r['committed']); w = int(r['arm'].split(':')[1])
        logs = glob.glob(f'{d}/n{n}/{tag}/ctl_sweep/logs/*_w{w}.out')
        rows.append(dict(eng='C', n=n, arm=f'{x} W{w}', x=x, w=w, rep=int(rep), rate=c / ex / 1e6, committed=c,
                         digest=r['digest'], ms=1e3 * ex / CYC, eff=float(r['efficiency']), blk=float(r['blocked_pct'] or 0),
                         bmin=float(r['blocked_min_pct'] or 0), bmax=float(r['blocked_max_pct'] or 0), log=logs[0] if logs else None))
p = f'{d}/deva.txt'
for line in (open(p) if os.path.exists(p) else []):
    r = dict(x.split('=', 1) for x in line.split() if '=' in x)
    if r.get('status') != 'ok' or not r.get('M_ev_s'):
        print('FAILED devastator', r.get('nodes'), r.get('arm'), r.get('window'), 'rep', r.get('rep'), r.get('status')); continue
    c = int(r['committed']); rate = float(r['M_ev_s']); w = int(r['window'])
    rows.append(dict(eng='D', n=int(r['nodes']), arm=f"{r['arm']} W{w}", x=r['arm'], w=w, rep=int(r['rep']), rate=rate,
                     committed=c, digest=None, ms=1e3 * c / (rate * 1e6) / CYC, eff=100.0 * c / max(1, int(r['executed'] or 0)),
                     blk=None, bmin=None, bmax=None, det=r.get('deterministic'), log=None))

def m(n, arm, k='rate', eng=None):
    return med([r[k] for r in rows if r['n'] == n and r['arm'] == arm and (eng is None or r['eng'] == eng)])

for n in (1, 4):
    rs = [r for r in rows if r['n'] == n]
    if not rs: continue
    cnt = sorted({r['committed'] for r in rs}); dg = sorted({r['digest'] for r in rs if r['eng'] == 'C'})
    det = sorted({r.get('det') for r in rs if r['eng'] == 'D'})
    print(f"\n===== {n} node(s): counts {cnt}{' <-- DIFFER' if len(cnt) > 1 else ''}; Charades digests {dg}; Devastator deterministic {det}")
    ref = m(n, 'A W2500')
    print(f"   {'engine arm':18} {'M ev/s':>7} {'÷A':>5} {'ms/cycle':>8} {'eff%':>6} {'blk%':>5} {'min':>5} {'max':>5} {'shm msgs':>12}  reps")
    for eng in ('C', 'D'):
        arms = sorted({r['arm'] for r in rs if r['eng'] == eng}, key=lambda a: -m(n, a))
        for a in arms:
            ar = sorted([r for r in rs if r['arm'] == a], key=lambda r: r['rep'])
            b = (f"{med([r['blk'] for r in ar]):5.1f} {med([r['bmin'] for r in ar]):5.1f} {med([r['bmax'] for r in ar]):5.1f}"
                 if eng == 'C' else ' ' * 17)
            shm = med([stat(r['log'], 'Shared-Memory Messages Received') for r in ar if r['log']]) if eng == 'C' else None
            print(f"   {('Charades ' if eng == 'C' else 'Devastator ') + a:18} {m(n, a):7.2f} {m(n, a) / ref if ref else 0:5.2f} "
                  f"{m(n, a, 'ms'):8.3f} {med([r['eff'] for r in ar]):6.2f} {b} {shm if shm is not None else '':>12}  "
                  f"{'/'.join('%.2f' % r['rate'] for r in ar)}")
    g = lambda a: m(n, a)
    if g('C W2500') and ref: print(f"-- Z2: C ÷ A at W 2,500: {g('C W2500') / ref:.3f}; C ÷ B: {g('C W2500') / g('B W2500'):.3f}; B ÷ A: {g('B W2500') / ref:.3f}")
    if g('D W2500') and g('C W2500'): print(f"-- Z3: D ÷ C at W 2,500: {g('D W2500') / g('C W2500'):.3f}; D ÷ A: {g('D W2500') / ref:.3f}")
    for x in ('B', 'C'):
        if g(f'{x} W2500'):
            print(f"-- Z6: {x}: W 5,000 ÷ W 2,500 {g(f'{x} W5000') / g(f'{x} W2500'):.3f}, W 10,000 ÷ W 2,500 {g(f'{x} W10000') / g(f'{x} W2500'):.3f}")
    cb = max((a for a in {r['arm'] for r in rs if r['eng'] == 'C' and r['x'] != 'Ccs'}), key=g)
    db = max((a for a in {r['arm'] for r in rs if r['eng'] == 'D'}), key=g)
    d2 = max((a for a in {r['arm'] for r in rs if r['x'] == 'd2'}), key=g, default=None)
    d1 = max((a for a in {r['arm'] for r in rs if r['x'] == 'd1'}), key=g, default=None)
    if d1 and d2: print(f"-- Z5: Devastator 1 x 46 ({d1}) ÷ 2 x 23 ({d2}), each at its best W: {g(d1) / g(d2):.3f}")
    print(f"-- Z5: Charades' best ({cb}, {g(cb):.2f}) ÷ Devastator's best ({db}, {g(db):.2f}): {g(cb) / g(db):.3f}"
          + (f"; at W 2,500: B ÷ d2 {g('B W2500') / g('d2 W2500'):.3f}, C ÷ d2 {g('C W2500') / g('d2 W2500'):.3f}" if g('d2 W2500') else ''))
    for r in sorted([r for r in rs if r['x'] == 'Ccs'], key=lambda r: r['rep']):
        f = r['log']
        print(f"-- Z4: Ccs rep {r['rep']} (÷ C at W 2,500 {r['rate'] / g('C W2500'):.3f}): send call {stat(f, 'Mean Send Call (us)')} µs, "
              f"{stat(f, 'Send Calls % of PE Time')}% of PE time; shared-memory messages {stat(f, 'Shared-Memory Messages Received'):,.0f}")
        for c in ('Same Process', 'Same Node', 'Other Node'):
            cntl = stat(f, f'Latency {c}: Count')
            if cntl is None: continue
            q = [stat(f, f'Latency {c}: {k} <= (us)') for k in ('p50', 'p90', 'p99')]
            print(f"       {c:12} count {cntl:>12,.0f}  mean {stat(f, f'Latency {c}: Mean (us)'):7.2f} µs  p50 ≤ {q[0]} p90 ≤ {q[1]} p99 ≤ {q[2]} µs")
    acts = {}
    for r in rs:
        if r['eng'] == 'C' and r['log']: acts.setdefault(copies(r['log']), []).append(r['arm'])
    print(f"-- Z8: per-copy activity: {len(acts)} distinct set(s) over {sum(len(v) for v in acts.values())} runs")
    for a, v in acts.items():
        mean = sum(a) / len(a) if a else 0
        print(f"       {', '.join(f'{x / mean:.3f}' for x in a)} of the mean ({len(v)} runs)")
    if mac and n == 4 and acts:
        ma = copies(mac)
        print(f"       Mac 4 copies, 5,000 cycles: {'SAME' if ma in acts else 'DIFFERENT'} ({ma})")

print()
for f in sorted(glob.glob(f'{d}/n*/pe*/ctl_sweep/pe_stats.csv')):
    rs = [{k: float(v) for k, v in r.items()} for r in csv.DictReader(open(f))]
    for r in rs: r['bs'] = 100 * r['blocked_s'] / r['total_s']
    bs = sorted(r['bs'] for r in rs)
    corr = st.correlation([r['bs'] for r in rs], [r['remote_sends'] for r in rs])
    tag = f.replace(d + '/', '').split('/ctl_sweep')[0]
    lb = min(rs, key=lambda r: r['bs'])
    print(f"-- Z7: {tag}: blocked % min {bs[0]:.1f} (PE {lb['pe']:.0f}, remote sends {lb['remote_sends']:,.0f}), median {st.median(bs):.1f}, "
          f"max {bs[-1]:.1f}; corr(blocked %, remote sends) {corr:.2f}")
for f in sorted(glob.glob(f'{d}/perf/*.report.txt')):
    sh = {}
    for line in open(f):
        mm = re.match(r'\s+([0-9.]+)%\s+(\S+)', line)
        if mm: sh[mm.group(2)] = sh.get(mm.group(2), 0) + float(mm.group(1))
    print(f"-- perf {os.path.basename(f)}: " + ', '.join(f'{k} {v:.1f}%' for k, v in sorted(sh.items(), key=lambda kv: -kv[1])[:7]))
