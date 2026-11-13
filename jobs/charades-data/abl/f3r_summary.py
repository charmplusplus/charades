#!/usr/bin/env python3
"""Job F3R (charades RESULTS.md section 224): the PADS'19 hold with PADS'19's
release rule, no hold with and without the local fast path, ROSS's dragonfly
window.

Usage: f3r_summary.py <job dir>   (e.g. ~/charades-data/abl/f3r/j3683036)
"""
import csv, glob, os, re, statistics as st, sys
from collections import defaultdict

D = sys.argv[1]
WLS = ['g100', 'g2000', 'uni', 'tr']
NAME = {'g100': 'σ 100', 'g2000': 'σ 2,000', 'uni': 'uniform', 'tr': 'traffic'}
WB = {'g100': 400, 'g2000': 400, 'uni': 400, 'tr': 1000}
# deadline htram at its better fixed W, job ABL (section 223), M ev/s
DEADLINE = {4: {'g100': 201.18, 'g2000': 153.27, 'uni': 132.18, 'tr': 284.05},
            16: {'g100': 810.71, 'g2000': 603.62, 'uni': 384.24, 'tr': 1063.61}}
LOGSTATS = {'remote': 'Remote Sends', 'anti': 'Anti Event Sends',
            'held': 'Remote Events Held', 'cancelled': 'Held Events Cancelled In Sender'}

rows = []
for f in glob.glob(os.path.join(D, 'n*', '*.csv')):
    N = int(os.path.basename(os.path.dirname(f))[1:])
    m = re.match(r'(g100|g2000|uni|tr|df)_(.+)_r(\d)$', os.path.basename(f)[:-4])
    if not m:
        continue
    wl, group, rep = m.group(1), m.group(2), int(m.group(3))
    with open(f) as fh:
        for r in csv.DictReader(fh):
            r.update(N=N, wl=wl, group=group, rep=rep)
            w = r['arm'].split(':')[1] if r['arm'].startswith('w:') else None
            logs = glob.glob(os.path.join(D, f'n{N}', f'{wl}_{group}_r{rep}', 'ctl_sweep', 'logs', f'*_w{w}.out')) if w else []
            if len(logs) == 1:
                for line in open(logs[0], errors='replace'):
                    for k, label in LOGSTATS.items():
                        if line.strip().startswith(label + ' ') or line.strip().startswith(label + '\t'):
                            r[k] = float(line.split()[-1])
            rows.append(r)

def mean(xs):
    xs = [x for x in xs if x is not None]
    return st.mean(xs) if xs else None

def fmt(x, d=2):
    return '—' if x is None else f'{x:.{d}f}'

def sel(N, wl, group, arm):
    return [r for r in rows if r['N'] == N and r['wl'] == wl and r['group'] == group and r['arm'] == arm and r['status'] == 'ok']

def rate(N, wl, group, arm):
    return mean([float(r['event_rate']) / 1e6 for r in sel(N, wl, group, arm)])

def stat(N, wl, group, arm, k, scale=1e6):
    return mean([r[k] / scale for r in sel(N, wl, group, arm) if k in r])

def rb(N, wl, group, arm):
    return mean([float(r['rolled_back']) / 1e6 for r in sel(N, wl, group, arm)])

print('# Counts and digests (one value per workload and node count is right)')
for N in (4, 16, 1):
    for wl in WLS + ['df']:
        rs = [r for r in rows if r['N'] == N and r['wl'] == wl]
        if not rs:
            continue
        ok = [r for r in rs if r['status'] == 'ok']
        print(f"n{N} {wl:5s} ok {len(ok):3d} not ok {len(rs) - len(ok):2d}  counts {sorted({r['committed'] for r in ok})}  digests {sorted({r['digest'] for r in ok if r.get('digest')})}")

ARMS = [('fp', 0, 'no hold, fast path on'), ('fp', 'B', 'no hold, fast path on'),
        ('nofp', 0, 'no hold, fast path off'), ('nofp', 'B', 'no hold, fast path off'),
        ('hold16', 0, 'hold, cutoff 16'), ('hold128', 0, 'hold, cutoff 128'), ('hold512', 0, 'hold, cutoff 512'),
        ('hold16w', 'B', 'hold, cutoff 16'), ('hold128w', 'B', 'hold, cutoff 128')]
for N in (4, 16):
    print(f'\n## {N} nodes: M committed ev/s (mean of 2 reps; higher is better) and event counts (M, mean of 2 reps)')
    for wl in WLS:
        print(f'\n### {NAME[wl]} (W B = {WB[wl]})')
        print('| arm | window | M ev/s | rolled back (M) | remote sends (M) | anti-messages (M) | held (M) | held ÷ remote sends | held cancelled in sender (M) |')
        print('|---|---|---|---|---|---|---|---|---|')
        for g, w, label in ARMS:
            W = WB[wl] if w == 'B' else 0
            arm = f'w:{W}'
            rem, held = stat(N, wl, g, arm, 'remote'), stat(N, wl, g, arm, 'held')
            print(f"| {label} | {'none' if W == 0 else W} | {fmt(rate(N, wl, g, arm))} | {fmt(rb(N, wl, g, arm), 1)} | {fmt(rem, 1)} | {fmt(stat(N, wl, g, arm, 'anti'), 1)} | {fmt(held, 1)} | {fmt(held / rem if held is not None and rem else None)} | {fmt(stat(N, wl, g, arm, 'cancelled'), 1)} |")
    print(f'\n## {N} nodes: ratios (higher is better for the first arm named)')
    print('| workload | fast path off ÷ on, no window / W B | hold ÷ no hold (fast path off), no window, cutoff 16 / 128 / 512 | hold ÷ no hold (fast path off), W B, cutoff 16 / 128 | best hold ÷ best no hold (fast path on) | best hold ÷ deadline htram (section 223) | no window ÷ W B, fast path on |')
    print('|---|---|---|---|---|---|---|')
    for wl in WLS:
        B = f'w:{WB[wl]}'
        r = lambda g, a: rate(N, wl, g, a)
        def q(a, b):
            return a / b if a and b else None
        holds = [x for x in (r('hold16', 'w:0'), r('hold128', 'w:0'), r('hold512', 'w:0'), r('hold16w', B), r('hold128w', B)) if x]
        fps = [x for x in (r('fp', 'w:0'), r('fp', B)) if x]
        bh, bf = (max(holds) if holds else None), (max(fps) if fps else None)
        print(f"| {NAME[wl]} | {fmt(q(r('nofp', 'w:0'), r('fp', 'w:0')))} / {fmt(q(r('nofp', B), r('fp', B)))}"
              f" | {fmt(q(r('hold16', 'w:0'), r('nofp', 'w:0')))} / {fmt(q(r('hold128', 'w:0'), r('nofp', 'w:0')))} / {fmt(q(r('hold512', 'w:0'), r('nofp', 'w:0')))}"
              f" | {fmt(q(r('hold16w', B), r('nofp', B)))} / {fmt(q(r('hold128w', B), r('nofp', B)))}"
              f" | {fmt(q(bh, bf))} | {fmt(q(bh, DEADLINE[N][wl]))} | {fmt(q(r('fp', 'w:0'), r('fp', B)))} |")

print('\n# ROSS dragonfly window (M committed ev/s, mean of 2 reps) and Charades controller')
ross = defaultdict(list)
fn = os.path.join(D, 'ross.txt')
for line in open(fn):
    kv = dict(t.split('=', 1) for t in line.split() if '=' in t)
    if kv.get('status') == 'ok' and kv.get('M_ev_s'):
        ross[(int(kv['nodes']), int(kv['window']))].append((float(kv['M_ev_s']), kv['committed'], float(kv.get('efficiency') or 'nan')))
    elif kv:
        print('ROSS not ok:', line.strip()[:160])
for N in (1, 4):
    ws = sorted(w for (n, w) in ross if n == N)
    rates = {w: mean([x for x, _, _ in ross[(N, w)]]) for w in ws}
    eff = {w: mean([e for _, _, e in ross[(N, w)]]) for w in ws}
    counts = sorted({c for w in ws for _, c, _ in ross[(N, w)]})
    bw = max((w for w in ws if w), key=lambda w: rates[w])
    ch = mean([float(r['event_rate']) / 1e6 for r in rows if r['N'] == N and r['wl'] == 'df' and r['status'] == 'ok'])
    chc = sorted({r['committed'] for r in rows if r['N'] == N and r['wl'] == 'df' and r['status'] == 'ok'})
    print(f'n{N}: ' + ', '.join(f'W {w}: {fmt(rates[w])} ({fmt(eff[w], 1)}%)' for w in ws)
          + f' | best ÷ none {fmt(rates[bw] / rates[0])} (W {bw}) | Charades controller {fmt(ch)} ÷ ROSS best {fmt(ch / max(rates.values()) if ch else None)}'
          + f' | ROSS counts {counts} Charades {chc}')
