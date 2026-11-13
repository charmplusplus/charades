#!/usr/bin/env python3
"""VLSI calibration, job V0 (RESULTS.md section 191): b19 x N (one copy per
node) at 1 and 4 nodes in three engines, span 1 and (4 nodes) span 4. Per
node count and span: committed counts across engines and Charades digests per
LPs-per-chare setting (V1); each engine's arms (M committed ev/s, median of 2
reps, and each rep / that engine's best fixed setting in the same rep, higher
is better); aggregation (best htram / direct at the same W, V4); Charades /
Devastator and / ROSS, each at its best fixed setting (V7). Then ROSS on
dragonfly, GVT interval 256 against 64 (V9). Usage: vcal_summary.py <job dir>"""
import csv, glob, os, re, statistics as st, sys
d = sys.argv[1]

rows = []
for f in glob.glob(f'{d}/n*/s[14]_*_r[12].csv'):
    n = int(f.split('/n')[-1].split('/')[0]); tag = os.path.basename(f)[:-4]
    head, rep = tag.rsplit('_r', 1); span, var = head.split('_', 1)
    for r in csv.DictReader(open(f)):
        if r['status'] != 'ok': print('charades', tag, r['arm'], r['status']); continue
        rows.append(dict(engine='charades', n=n, span=int(span[1:]), rep=int(rep), arm=f"{var} {r['arm']}",
                         fixed=r['arm'].startswith('w:'), rate=float(r['committed']) / float(r['exec_s']) / 1e6,
                         committed=r['committed'], digest=(var, r['digest']), eff=float(r['efficiency']),
                         blk=float(r['blocked_pct'] or 0), meanw=r['mean_window'], app='vlsi'))
for eng, fn in (('devastator', 'deva.txt'), ('ross', 'ross.txt')):
    p = f'{d}/{fn}'
    if not os.path.exists(p): continue
    for line in open(p):
        r = dict(x.split('=', 1) for x in line.split() if '=' in x)
        if r.get('status') != 'ok' or not r.get('M_ev_s'):
            print(eng, r.get('app'), r.get('nodes'), r.get('span'), r.get('arm'), 'rep', r.get('rep'), r.get('status')); continue
        eff = float(r.get('efficiency') or 0) if eng == 'ross' else 100.0 * int(r['committed']) / max(1, int(r['executed'] or 0))
        rows.append(dict(engine=eng, n=int(r['nodes']), span=int(r.get('span', 1)), rep=int(r['rep']), arm=r['arm'],
                         fixed=r['arm'] != 'adaptive', rate=float(r['M_ev_s']), committed=r['committed'],
                         digest=None, eff=eff, blk=0.0, meanw='', app=r.get('app', 'vlsi'),
                         det=r.get('deterministic', '')))

def med(xs): return st.median(xs) if xs else None
best = {}
for n in (1, 4):
    for span in (1, 4):
        rs = [r for r in rows if r['app'] == 'vlsi' and r['n'] == n and r['span'] == span]
        if not rs: continue
        counts = sorted({r['committed'] for r in rs})
        dg = {}
        for r in rs:
            if r['digest']: dg.setdefault('lpc512' if r['digest'][0] == 'lpc512' else 'lpc128', set()).add(r['digest'][1])
        det = {r.get('det') for r in rs if r['engine'] == 'devastator'}
        print(f"\n===== {n} node(s), span {span}: counts {counts}{' <-- DIFFER' if len(counts) != 1 else ''}; "
              f"Charades digests {dict((k, sorted(v)) for k, v in dg.items())}; Devastator deterministic {sorted(det)}")
        for eng in ('charades', 'devastator', 'ross'):
            er = [r for r in rs if r['engine'] == eng]
            if not er: continue
            arms = sorted({r['arm'] for r in er})
            m = {a: med([r['rate'] for r in er if r['arm'] == a]) for a in arms}
            fx = [a for a in arms if any(r['fixed'] for r in er if r['arm'] == a)]
            bestrep = {k: max([r['rate'] for r in er if r['rep'] == k and r['fixed']], default=None) for k in (1, 2)}
            top = max(fx, key=lambda a: m[a]); best[(n, span, eng)] = (top, m[top])
            print(f"-- {eng}: best fixed {top} ({m[top]:.1f} M ev/s)")
            print(f"   {'arm':22} {'M ev/s':>8} {'eff%':>6} {'blk%':>5} {'meanW':>7}  ÷best of rep (r1/r2)")
            for a in sorted(arms, key=lambda a: -m[a]):
                ar = sorted([r for r in er if r['arm'] == a], key=lambda r: r['rep'])
                rat = '/'.join(f"{r['rate'] / bestrep[r['rep']]:.2f}" for r in ar if bestrep[r['rep']])
                mw = ar[0]['meanw']
                mw = f"{float(mw):7.0f}" if mw not in ('', None) else '       '
                blk = f"{med([r['blk'] for r in ar]):5.1f}" if eng == 'charades' else '     '
                print(f"   {a:22} {m[a]:8.1f} {med([r['eff'] for r in ar]):6.2f} {blk} {mw}  {rat}")
        cr = [r for r in rs if r['engine'] == 'charades']
        g = lambda a: med([r['rate'] for r in cr if r['arm'] == a])
        h = max([x for x in (g('pp2048 w:5000'), g('wps512 w:5000')) if x], default=None)
        dr = g('direct w:5000')
        if h and dr: print(f"-- aggregation at W 5,000, best htram ÷ direct: {h / dr:.2f}")
        c = best.get((n, span, 'charades'))
        ctl = g('pp2048 mb:0')
        for eng in ('devastator', 'ross'):
            o = best.get((n, span, eng))
            if c and o: print(f"-- Charades ÷ {eng}, each at its best fixed: {c[1] / o[1]:.2f}" + (f"; Charades' controller ÷ {eng}: {ctl / o[1]:.2f}" if ctl else ''))
if best.get((4, 1, 'charades')) and best.get((4, 4, 'charades')):
    print(f"\n-- 4 nodes, Charades' best at span 4 ÷ at span 1: {best[(4, 4, 'charades')][1] / best[(4, 1, 'charades')][1]:.2f}")
if best.get((1, 1, 'charades')) and best.get((4, 1, 'charades')):
    print(f"-- span 1, Charades per-node rate at 4 nodes ÷ at 1: {best[(4, 1, 'charades')][1] / 4 / best[(1, 1, 'charades')][1]:.2f}")
print('\n===== ROSS on dragonfly (V9)')
for n in (1, 4):
    dr = [r for r in rows if r['app'] == 'dragonfly' and r['n'] == n]
    m = {a: med([r['rate'] for r in dr if r['arm'] == a]) for a in sorted({r['arm'] for r in dr})}
    if m: print(f"  {n} node(s): " + '  '.join(f"{a} {v:.1f}" for a, v in m.items()) +
                (f"  -> 256 ÷ 64: {m['df_b2g256'] / m['df_b2g64']:.2f}" if 'df_b2g256' in m and 'df_b2g64' in m else ''))
