#!/usr/bin/env python3
"""Job CC (charades RESULTS.md sections 245-246): where the frozen controller's
3-7% against the best fixed W goes. Per cell (PHOLD sigma 500 and traffic, 16
and 1 nodes): rates per arm (median of 3), the ratios that test each candidate,
and from the per-round logs (CL, CPL, DL) the controller's extra PE time over
the dry run's, split by the window in force and by rounds since the last change.
Usage: cc245_summary.py [job dir]"""
import csv, glob, math, os, re, statistics as st, sys, collections
d = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), 'cc245/cc_j3690326')
WB = {('g500', 1): 300, ('g500', 16): 400, ('tr', 1): 500, ('tr', 16): 500}
NAMES = {'g500': 'PHOLD σ 500', 'tr': 'traffic'}
rates = collections.defaultdict(list)    # (wl, N, arm label) -> rates
counts = collections.defaultdict(set); digests = collections.defaultdict(set)
logs = collections.defaultdict(list)     # (wl, N, arm) -> log files
for f in glob.glob(os.path.join(d, 'n*/*_r[0-9]_*.csv')):
    N = int(f.split('/')[-2][1:]); m = re.match(r'(g500|tr)_r(\d)_(\w+)\.csv', os.path.basename(f))
    wl, rep, arm = m.group(1), int(m.group(2)), m.group(3)
    for r in csv.DictReader(open(f)):
        if r['status'] != 'ok': print('FAILED', f, r['arm'], r['status']); continue
        lab = 'F ' + r['arm'] if arm == 'F' else arm
        rates[(wl, N, lab)].append(float(r['event_rate']) / 1e6)
        counts[(wl, N)].add(r['committed']); digests[(wl, N)].add(r['digest'])
    if arm in ('CL', 'CPL', 'DL'):
        logs[(wl, N, arm)] += glob.glob(os.path.join(d, f'n{N}/{wl}_r{rep}_{arm}/ctl_sweep/logs/*.out'))
med = {k: st.median(v) for k, v in rates.items()}

def parse(f):
    rows = []
    for l in open(f):
        if l.startswith('CTL round'):
            t = l.split(); kv = dict(zip(t[3::2], t[4::2]))
            rows.append((int(kv['window']), int(kv['committed']), float(kv['round_ms'])))
    # the W in force during round i is the one decided at round i-1
    return [(p[0], c[1], c[2]) for p, c in zip(rows, rows[1:])]

print('Rates: M committed ev/s, median of 3 (higher is better); ratios higher is better for the first arm.')
for wl in ('g500', 'tr'):
    for N in (16, 1):
        if (wl, N) not in counts: continue
        fx = {k[2]: v for k, v in med.items() if k[0] == wl and k[1] == N and k[2].startswith('F ')}
        bf = max(fx, key=fx.get); wb = WB[(wl, N)]
        g = lambda a: med.get((wl, N, a))
        print(f"\n## {NAMES[wl]}, {N} node(s): counts {len(counts[(wl, N)])}, digests {len(digests[(wl, N)])}")
        print('   fixed: ' + '  '.join(f"{a[2:]} {v:.1f}" for a, v in sorted(fx.items(), key=lambda x: int(x[0].split(':')[1]))) +
              f'   (best {bf[2:]}; cost of one 1.5 step from it: ' +
              ', '.join(f"{a[2:]} {fx[bf] / v:.3f}" for a, v in fx.items() if a != bf) + ' x time)')
        for a in ('C', 'CL', 'CPL', 'D', 'DL'):
            reps = sorted(rates[(wl, N, a)])
            print(f"   {a:4} {g(a):7.1f}  ÷ best fixed {g(a) / fx[bf]:.3f}  reps " + ' '.join(f'{x:.1f}' for x in reps))
        print(f"   C ÷ best fixed {g('C') / fx[bf]:.3f} | D ÷ F W{wb} (measuring) {g('D') / fx['F w:' + str(wb)]:.3f} | "
              f"DL ÷ D (log, fixed W) {g('DL') / g('D'):.3f} | CL ÷ C (log) {g('CL') / g('C'):.3f} | CPL ÷ CL (period 32) {g('CPL') / g('CL'):.3f} | "
              f"C ÷ D (moving W, both measuring) {g('C') / g('D'):.3f}")
        # per-round decomposition against DL's cost per event
        dl = [parse(f) for f in logs[(wl, N, 'DL')]]
        cdl = st.median(sum(r[2] for r in x) / sum(r[1] for r in x) for x in dl)
        for arm in ('CL', 'CPL'):
            out = []
            for f in sorted(logs[(wl, N, arm)]):
                rr = parse(f)
                T = sum(r[2] for r in rr); ex = T - sum(r[1] for r in rr) * cdl
                near = [r for r in rr if abs(math.log(r[0] / wb)) < math.log(1.12)]
                exn = sum(r[2] for r in near) - sum(r[1] for r in near) * cdl
                # rounds since the last change of W
                since = collections.defaultdict(lambda: [0.0, 0]); k = 0; prev = None
                for r in rr:
                    k = 0 if r[0] != prev else k + 1; prev = r[0]
                    b = min(k, 3); since[b][0] += r[2]; since[b][1] += r[1]
                cs = {b: (v[0] / v[1]) / cdl for b, v in since.items() if v[1]}
                tsh = {b: v[0] / T for b, v in since.items()}
                changes = sum(1 for a, b in zip(rr, rr[1:]) if a[0] != b[0])
                out.append(f"extra time {100 * ex / T:4.1f}% (near W{wb}: {100 * exn / max(ex, 1e-12):3.0f}% of it; time near {100 * sum(r[2] for r in near) / T:3.0f}%), "
                           f"changes {changes} of {len(rr)} rounds, cost ÷ DL by rounds since change "
                           + ' '.join(f"{b}{'+' if b == 3 else ''}:{cs[b]:.3f}({100 * tsh[b]:.0f}%)" for b in sorted(cs)))
            print(f"   {arm} per round (DL cost {cdl * 1e6:.1f} ns per committed event per PE-ms):")
            for o in out: print('      ' + o)
