#!/usr/bin/env python3
"""VLSI calibration on the balanced layout, job V1 (RESULTS.md section 193):
b19 x N (one copy per node) at 1 and 4 nodes in three engines, span 1 and
(4 nodes) span 4. Per node count and span: committed counts across engines
and Charades digests per layout (W1); each engine's arms (M committed ev/s,
median of 2 reps, and each rep / that engine's best fixed setting in the
same rep, higher is better; Charades' blocked share at the window, mean and
per-PE min/max); aggregation (htram / direct at the same W, W7, W8);
Charades / Devastator and / ROSS, each at its best fixed setting on the
balanced layout (W8-W10); balanced / file order (W3, W4); ROSS windowed /
unwindowed (W9). File-order arms are never an engine's best.
Usage: vcal193_summary.py <job dir>"""
import csv, glob, os, statistics as st, sys
d = sys.argv[1]

rows = []
for f in glob.glob(f'{d}/n*/s[14]_*_r[12].csv'):
    n = int(f.split('/n')[-1].split('/')[0]); tag = os.path.basename(f)[:-4]
    head, rep = tag.rsplit('_r', 1); span, var = head.split('_', 1)
    for r in csv.DictReader(open(f)):
        if r['status'] != 'ok': print('charades', tag, r['arm'], r['status']); continue
        rows.append(dict(engine='charades', n=n, span=int(span[1:]), rep=int(rep), arm=f"{var} {r['arm']}",
                         file=var == 'file', fixed=r['arm'].startswith('w:') and var != 'file',
                         rate=float(r['committed']) / float(r['exec_s']) / 1e6, committed=r['committed'],
                         digest=('file' if var == 'file' else 'balanced', r['digest']), eff=float(r['efficiency']),
                         blk=float(r['blocked_pct'] or 0), bmin=float(r['blocked_min_pct'] or 0),
                         bmax=float(r['blocked_max_pct'] or 0), meanw=r['mean_window']))
for eng, fn in (('devastator', 'deva.txt'), ('ross', 'ross.txt')):
    p = f'{d}/{fn}'
    if not os.path.exists(p): continue
    for line in open(p):
        r = dict(x.split('=', 1) for x in line.split() if '=' in x)
        if r.get('status') != 'ok' or not r.get('M_ev_s'):
            print(eng, r.get('nodes'), r.get('span'), r.get('arm'), 'rep', r.get('rep'), r.get('status')); continue
        file = r.get('chunk') == '0'
        eff = float(r.get('efficiency') or 0) if eng == 'ross' else 100.0 * int(r['committed']) / max(1, int(r['executed'] or 0))
        arm = ('file ' if file else '') + r['arm']
        rows.append(dict(engine=eng, n=int(r['nodes']), span=int(r.get('span', 1)), rep=int(r['rep']), arm=arm,
                         file=file, fixed=r['arm'] != 'adaptive' and not file, rate=float(r['M_ev_s']),
                         committed=r['committed'], digest=None, eff=eff, blk=0.0, bmin=0.0, bmax=0.0, meanw='',
                         det=r.get('deterministic', '')))

def med(xs): return st.median(xs) if xs else None
best = {}
for n in (1, 4):
    for span in (1, 4):
        rs = [r for r in rows if r['n'] == n and r['span'] == span]
        if not rs: continue
        counts = sorted({r['committed'] for r in rs})
        dg = {}
        for r in rs:
            if r['digest']: dg.setdefault(r['digest'][0], set()).add(r['digest'][1])
        det = sorted({r.get('det') for r in rs if r['engine'] == 'devastator'})
        print(f"\n===== {n} node(s), span {span}: counts {counts}{' <-- DIFFER' if len(counts) != 1 else ''}; "
              f"Charades digests {dict((k, sorted(v)) for k, v in dg.items())}; Devastator deterministic {det}")
        for eng in ('charades', 'devastator', 'ross'):
            er = [r for r in rs if r['engine'] == eng]
            if not er: continue
            arms = sorted({r['arm'] for r in er})
            m = {a: med([r['rate'] for r in er if r['arm'] == a]) for a in arms}
            fx = [a for a in arms if any(r['fixed'] for r in er if r['arm'] == a)]
            bestrep = {k: max([r['rate'] for r in er if r['rep'] == k and r['fixed']], default=None) for k in (1, 2)}
            if fx:
                top = max(fx, key=lambda a: m[a]); best[(n, span, eng)] = (top, m[top])
                print(f"-- {eng}: best fixed {top} ({m[top]:.1f} M ev/s)")
            print(f"   {'arm':24} {'M ev/s':>8} {'eff%':>7} {'blk%':>5} {'min':>5} {'max':>5} {'meanW':>7}  ÷best of rep (r1/r2)")
            for a in sorted(arms, key=lambda a: -m[a]):
                ar = sorted([r for r in er if r['arm'] == a], key=lambda r: r['rep'])
                rat = '/'.join(f"{r['rate'] / bestrep[r['rep']]:.2f}" for r in ar if bestrep[r['rep']])
                mw = ar[0]['meanw']
                mw = f"{float(mw):7.0f}" if mw not in ('', None) else '       '
                b = (f"{med([r['blk'] for r in ar]):5.1f} {med([r['bmin'] for r in ar]):5.1f} {med([r['bmax'] for r in ar]):5.1f}"
                     if eng == 'charades' else ' ' * 17)
                print(f"   {a:24} {m[a]:8.1f} {med([r['eff'] for r in ar]):7.2f} {b} {mw}  {rat}")
        cr = [r for r in rs if r['engine'] == 'charades']
        g = lambda a: med([r['rate'] for r in cr if r['arm'] == a])
        for w in ('2500', '10000'):
            dr = g(f'direct w:{w}')
            for h in (f'pp2048 w:{w}', f'wps512 w:{w}'):
                if g(h) and dr: print(f"-- aggregation at W {w}, {h.split()[0]} ÷ direct: {g(h) / dr:.2f}")
        c = best.get((n, span, 'charades')); ctl = g('pp2048 mb:0')
        if c and ctl: print(f"-- Charades' controller ÷ its best fixed W: {ctl / c[1]:.2f}")
        for eng in ('devastator', 'ross'):
            o = best.get((n, span, eng))
            if c and o: print(f"-- Charades ÷ {eng}, each at its best fixed: {c[1] / o[1]:.2f}" + (f"; Charades' controller ÷ {eng}: {ctl / o[1]:.2f}" if ctl else ''))
        if span == 1:
            fc = g('file w:2500'); bc = g('pp2048 w:2500')
            if fc and bc: print(f"-- Charades at W 2,500, balanced ÷ file order: {bc / fc:.2f} (file order {fc:.1f} M ev/s)")
            dv = [r for r in rs if r['engine'] == 'devastator']
            fd = med([r['rate'] for r in dv if r['arm'] == 'file 10000']); bd = med([r['rate'] for r in dv if r['arm'] == '10000'])
            if fd and bd: print(f"-- Devastator at W 10,000, balanced ÷ file order: {bd / fd:.2f} (file order {fd:.1f} M ev/s)")
            ro = [r for r in rs if r['engine'] == 'ross']
            un = med([r['rate'] for r in ro if r['arm'] == 'vlsi_s1_b8g64'])
            o = best.get((n, span, 'ross'))
            if un and o: print(f"-- ROSS best windowed ÷ unwindowed batch 8: {o[1] / un:.2f} ({o[0]})")
for eng in ('charades', 'devastator'):
    a, b = best.get((4, 4, eng)), best.get((4, 1, eng))
    if a and b: print(f"\n-- 4 nodes, {eng}'s best at span 4 ÷ at span 1: {a[1] / b[1]:.2f}")
a, b = best.get((1, 1, 'charades')), best.get((4, 1, 'charades'))
if a and b: print(f"-- span 1, Charades per-node rate at 4 nodes ÷ at 1: {b[1] / 4 / a[1]:.2f}")
