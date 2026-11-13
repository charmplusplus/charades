#!/usr/bin/env python3
"""Job E (charades RESULTS.md section 154): slow cross-process GVT reductions.
Usage: epi_summary.py <job dir> <job .out file (for the node list)>

1. Untraced runs: per run, the throughput over the first 2 s of wall time and
   over the rest, from the time-stamped progress lines (simulated time per
   wall second; rest ÷ first > 1 means the start is slower), the time lost in
   the first 2 s at the rest's rate, and other slow stretches (0.25 s bins
   under half the run's median rate).
2. Traced runs, per 0.25 s of wall time: wave period, the slowest process's
   turnaround (counts sent - previous result here), the reduction after the
   last process (result here - counts sent, smallest over processes), and the
   PEs' thread usage per wave: kernel time per PE, the largest single-PE
   kernel time, minor faults per PE, involuntary switches per PE.
3. Tree runs (--gvt-wave-tree): each hop's time beyond its pair's fastest
   (offset-free), up and down, per bin; in slow bins, which receivers and
   senders the excess sits on.
4. hfi1 counters per run window (Unix start .. + exec): per node deltas
   summed and the largest node; first 2 s against the rest, per second.
5. Devastator.
"""
import csv, glob, os, re, sys, statistics as st
from collections import defaultdict, Counter

d, jobout = sys.argv[1], sys.argv[2]
NL = []
for l in open(jobout):
    m = re.search(r'nodes (c\S+(?: c\S+)+)', l)
    if m: NL = m.group(1).split(); break
med = st.median
def fmean(v): return sum(v) / len(v) if v else float('nan')

def log_of(run_dir):
    f = glob.glob(os.path.join(run_dir, 'ctl_sweep', 'logs', '*.out'))
    return f[0] if f else None

def progress(log):
    """(unix start, [(wall s, simulated time)], exec s)"""
    U, pts, ex = None, [(0.0, 0)], None
    for l in open(log):
        m = re.match(r'Simulation Starting: .* Unix time ([\d.]+)', l)
        if m: U = float(m.group(1))
        m = re.match(r'GVT\s+\d+:\s+(\d+) \(.*\), [\d.]+ MB, ([\d.]+) s', l)
        if m: pts.append((float(m.group(2)), int(m.group(1))))
        if 'Execution Time' in l and ex is None: ex = float(l.split()[-1])
    return U, pts, ex

def runs(N, traced):
    out = []
    for f in sorted(glob.glob(os.path.join(d, 'n%d' % N, '*.csv'))):
        tag = os.path.basename(f)[:-4]
        if tag.startswith('warm') or (('_trace' in tag) != traced): continue
        rows = [r for r in csv.DictReader(open(f))]
        if not rows: continue
        out.append((tag, rows[0], os.path.join(d, 'n%d' % N, tag)))
    return out

def arm_of(tag): return re.sub(r'_r\d+$', '', tag)

# ---------------------------------------------------------------- 1
print('== 1. Untraced runs: throughput, first 2 s against the rest (from progress lines)')
print('%-22s %3s %5s %7s %8s | %12s %10s | other slow 0.25 s bins (s)' % ('arm', 'N', 'rep', 'exec s', 'M ev/s', 'rest÷first2s', 'lost in 2s'))
starts = {}
summ = defaultdict(list)
for N in (32, 16):
    for tag, r, rd in runs(N, False):
        log = log_of(rd)
        if not log: continue
        U, pts, ex = progress(log)
        starts[(N, tag)] = (U, float(r['exec_s']))
        if len(pts) < 10 or r['status'] != 'ok':
            print('%-22s %3d %5s %s' % (arm_of(tag), N, tag[-2:], r['status'])); continue
        T, V = pts[-1]
        v2 = max(v for t, v in pts if t <= 2.0)
        t2 = max(t for t, v in pts if t <= 2.0)
        rate_rest = (V - v2) / (T - t2); rate_first = v2 / t2 if t2 else float('nan')
        lost = t2 - v2 / rate_rest
        bins = defaultdict(lambda: [None, None])
        for (ta, va), (tb, vb) in zip(pts, pts[1:]):
            k = int(ta / 0.25)
            b = bins[k]; b[0] = ta if b[0] is None else b[0]; b[1] = (tb, vb, va if b[1] is None else b[1][2])
        rates = {k: (b[1][1] - b[1][2]) / max(1e-9, b[1][0] - b[0]) for k, b in bins.items() if b[1]}
        mr = med(list(rates.values()))
        slow = [k * 0.25 for k, x in sorted(rates.items()) if x < 0.5 * mr and k * 0.25 >= 2.0]
        summ[(arm_of(tag), N)].append((float(r['exec_s']), float(r['event_rate']) / 1e6, rate_rest / rate_first, lost))
        print('%-22s %3d %5s %7.2f %8.1f | %12.2f %10.2f | %s' % (arm_of(tag), N, tag[-2:], float(r['exec_s']), float(r['event_rate']) / 1e6, rate_rest / rate_first, lost, ' '.join('%.2f' % x for x in slow[:12]) + (' ...' if len(slow) > 12 else '')))
print('\nPer arm (median of reps): exec s, M ev/s, rest÷first 2 s, s lost in the first 2 s; ratio to g100_def at the same N (higher is better)')
for (arm, N), v in sorted(summ.items(), key=lambda x: (-x[0][1], x[0][0])):
    base = summ.get(('g100_def', N)) if arm.startswith('g100') else None
    m = [med([x[i] for x in v]) for i in range(4)]
    print('  %-20s %3d  exec %6.2f  %7.1f M ev/s  %5.2f  %5.2f s%s' % (arm, N, m[0], m[1], m[2], m[3], ('   ÷ default %.3f' % (m[1] / med([x[1] for x in base]))) if base and arm != 'g100_def' else ''))

# ---------------------------------------------------------------- 2, 3
def load_waves(cs):
    files = sorted(glob.glob(os.path.join(cs, 'gvt_waves_*.csv')), key=lambda f: int(re.search(r'_(\d+)\.csv', f).group(1)))
    P = [list(csv.DictReader(open(f))) for f in files]
    m = min(len(p) for p in P)
    return [p[:m] for p in P], m

def hops(cs):
    rec = defaultdict(list); mins = {}
    for f in glob.glob(os.path.join(cs, 'gvt_hops_*.csv')):
        p = int(re.search(r'_(\d+)\.csv', f).group(1))
        for x in csv.DictReader(open(f)):
            k = int(x['kind'])
            if k in (0, 1):
                peer, dt = int(x['peer']), float(x['recv_s']) - float(x['sent_s'])
                rec[int(x['wave'])].append((p, k, peer, dt))
                key = (p, peer, k); mins[key] = min(mins.get(key, 9e9), dt)
    return rec, mins

print('\n== 2. Traced runs, per 0.25 s of wall time (µs per wave; lower is better). Kernel, faults and switches per PE per wave.')
for N in (32, 16):
    for tag, r, rd in runs(N, True):
        cs = os.path.join(rd, 'ctl_sweep')
        if not glob.glob(os.path.join(cs, 'gvt_waves_*.csv')): print(tag, 'no waves'); continue
        P, m = load_waves(cs)
        npe = 23 * len(P)
        F = lambda p, i, k: float(p[i].get(k) or 0)
        t0 = F(P[0], 0, 'result_s')
        H, mins = hops(cs) if 'tree' in tag else ({}, {})
        B = defaultdict(list); HB = defaultdict(list); recv_ex = defaultdict(Counter)
        periods = []
        for i in range(1, m):
            turn = [F(p, i, 'handled_s') - F(p, i - 1, 'result_s') for p in P]
            wait = [F(p, i, 'result_s') - F(p, i, 'handled_s') for p in P]
            per = F(P[0], i, 'result_s') - F(P[0], i - 1, 'result_s'); periods.append(per)
            last = min(range(len(P)), key=lambda j: wait[j])
            st_sum = sum(F(p, i, 'stime_us') for p in P); ut_sum = sum(F(p, i, 'utime_us') for p in P)
            st_max = max(F(p, i, 'stime_max_us') for p in P)
            flt = sum(F(p, i, 'minflt') for p in P); ivc = sum(F(p, i, 'nivcsw') for p in P)
            b = int((F(P[0], i - 1, 'result_s') - t0) / 0.25)
            B[b].append((per, max(turn), min(wait), st_sum / npe, st_max, flt / npe, ivc / npe, ut_sum / npe, F(P[last], i, 'stime_max_us')))
            for (p, k, peer, dt) in H.get(i, []):
                ex = dt - mins[(p, peer, k)]
                HB[b].append((k, ex))
                recv_ex[b][p] += ex
        steady = med(periods[len(periods) // 10: 95 * len(periods) // 100])
        print('-- %s, %d nodes (steady median period %.0f µs)' % (tag, N, 1e6 * steady))
        print('   %-9s %5s %6s %6s %6s | %7s %7s %6s %6s %7s | %s' % ('wall s', 'waves', 'period', 'slowtn', 'reduc', 'kern/PE', 'kernmax', 'flt/PE', 'ivc/PE', 'user/PE', 'hops: up / down excess mean (µs); top receivers of excess'))
        for b in sorted(B):
            if b > 48: break
            v = B[b]; mm = lambda j: fmean([x[j] for x in v])
            hl = ''
            if HB.get(b):
                up = [e for k, e in HB[b] if k == 0]; dn = [e for k, e in HB[b] if k == 1]
                tot = sum(recv_ex[b].values()) or 1
                hl = '%6.1f / %6.1f; %s' % (1e6 * fmean(up), 1e6 * fmean(dn), ', '.join('%d %.0f%%' % (p, 100 * e / tot) for p, e in recv_ex[b].most_common(3)))
            print('   %4.2f-%4.2f %5d %6.0f %6.0f %6.0f | %7.1f %7.0f %6.2f %6.3f %7.1f | %s' % (b * .25, (b + 1) * .25, len(v), 1e6 * mm(0), 1e6 * mm(1), 1e6 * mm(2), mm(3), mm(4), mm(5), mm(6), mm(7), hl))

# ---------------------------------------------------------------- 4
print('\n== 4. hfi1 counters per run window, all nodes (per second; first 2 s | rest), and the largest node over the run')
HF = {}
for f in glob.glob(os.path.join(d, 'hfi', '*.csv')):
    rows = list(csv.DictReader(open(f)))
    if rows: HF[os.path.basename(f)[:-4]] = rows
KEYS = ['TxWait', 'TxFlowStall', 'DRIVER_EgrBufFull', 'DRIVER_EgrHdrFull', 'RcvOverflow', 'SeqDrop0', 'RxCtxEgrS', 'RcvHdrOvr_sum', 'PioWait', 'SendSched', 'KmemWait', 'TxWords']
def delta(rows, a, b, k):
    sel = [r for r in rows if a <= float(r['unix_s']) <= b]
    if len(sel) < 2: return 0.0
    x, y = int(sel[0][k]), int(sel[-1][k])
    return float(y - x) if x >= 0 and y >= 0 else 0.0
if not HF: print('   no sampler files')
else:
    print('   %-24s %s' % ('run', '  '.join('%-24s' % k for k in KEYS)))
    for (N, tag), (U, ex) in sorted(starts.items(), key=lambda x: x[1][0] or 0):
        if U is None: continue
        nodes = NL[:N] if NL else list(HF)
        cells = []
        for k in KEYS:
            first = sum(delta(HF[h], U, U + 2, k) for h in nodes if h in HF) / 2
            rest = sum(delta(HF[h], U + 2, U + ex, k) for h in nodes if h in HF) / max(1e-9, ex - 2)
            per_node = [(delta(HF[h], U, U + ex, k), h) for h in nodes if h in HF]
            top = max(per_node) if per_node else (0, '-')
            cells.append('%9.3g|%-9.3g %s' % (first, rest, top[1][-7:] if top[0] > 0 else ''))
        print('   %-24s %s' % ('n%d %s' % (N, tag), '  '.join('%-24s' % c for c in cells)))

# ---------------------------------------------------------------- 5
print('\n== 5. Devastator')
for f in glob.glob(os.path.join(d, 'n*', 'deva', 'results.txt')):
    for l in open(f):
        kv = dict(x.split('=', 1) for x in l.split() if '=' in x)
        print('   %-18s nodes %s rc %s wall %s s, %.1f M ev/s, committed %s' % (kv.get('label'), kv.get('nodes'), kv.get('rc'), kv.get('wall_s'), float(kv.get('committed_per_s', 'nan')) / 1e6, kv.get('committed')))
