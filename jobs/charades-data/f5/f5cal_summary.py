#!/usr/bin/env python3
"""F5 calibration (RESULTS.md section 186): traffic and dragonfly at 1 and 4
nodes in three engines. Per application and node count: each engine's arms
(M committed ev/s, median of the reps, and each rep ÷ that engine's best arm
of the same rep; higher is better), committed counts and Charades digests
(K1), aggregation (best htram ÷ best direct, K4), and each engine at its best
(Charades ÷ the other, K8)."""
import csv, glob, os, re, statistics as st, sys
d = sys.argv[1]
APPS = {'df': 'dragonfly', 'tr': 'traffic'}

# Charades: n<N>/<app>_<agg>_r<rep>.csv from ctl_sweep.sh
ch = []
for f in glob.glob(f'{d}/n*/*_r[12].csv'):
    n = int(f.split('/n')[-1].split('/')[0]); tag = os.path.basename(f)[:-4]
    head, rep = tag.rsplit('_r', 1); app, agg = head.split('_', 1)
    for r in csv.DictReader(open(f)):
        if r['status'] != 'ok': print('charades', tag, r['arm'], r['status']); continue
        ch.append(dict(engine='charades', app=APPS[app], n=n, rep=int(rep), arm=f"{agg} {r['arm']}",
                       rate=float(r['committed']) / float(r['exec_s']) / 1e6, committed=r['committed'],
                       digest=r['digest'], eff=float(r['efficiency']), blk=float(r['blocked_pct'] or 0),
                       meanw=r['mean_window'], finalw=r['final_window']))

def kv(line):
    return dict(x.split('=', 1) for x in line.split() if '=' in x)
other = []
for eng, fn in (('devastator', 'deva.txt'), ('ross', 'ross.txt')):
    p = f'{d}/{fn}'
    if not os.path.exists(p): continue
    for line in open(p):
        r = kv(line)
        if r.get('status') != 'ok' or not r.get('M_ev_s'):
            print(eng, r.get('app'), r.get('nodes'), r.get('arm'), 'rep', r.get('rep'), r.get('status')); continue
        other.append(dict(engine=eng, app=r['app'], n=int(r['nodes']), rep=int(r['rep']), arm=r['arm'],
                          rate=float(r['M_ev_s']), committed=r['committed'],
                          eff=float(r.get('efficiency') or 0) if eng == 'ross' else
                              100.0 * int(r['committed']) / max(1, int(r['executed'] or 0)),
                          det=r.get('deterministic', '')))
rows = ch + other

def armkey(a):
    m = re.search(r'([\d.]+)$', a)
    return (a.split()[0] if ' ' in a else '', float(m.group(1)) if m else 1e18, a)

best_of = {}
for app in ('dragonfly', 'traffic'):
    for n in (1, 4):
        rs = [r for r in rows if r['app'] == app and r['n'] == n]
        if not rs: continue
        counts = {r['committed'] for r in rs}
        digests = {r['digest'] for r in rs if r['engine'] == 'charades'}
        print(f'\n===== {app}, {n} node(s): committed counts {sorted(counts)}; Charades digests {sorted(digests)}'
              f"{'' if len(counts) == 1 else '  <-- COUNTS DIFFER'}")
        for eng in ('charades', 'devastator', 'ross'):
            er = [r for r in rs if r['engine'] == eng]
            if not er: continue
            fixed = lambda r: r['arm'].split()[1].startswith('w:') if eng == 'charades' else r['arm'] != 'adaptive'
            bestrep = {k: max([r['rate'] for r in er if r['rep'] == k and fixed(r)], default=None) for k in (1, 2)}
            arms = sorted({r['arm'] for r in er}, key=armkey)
            med = {a: st.median(r['rate'] for r in er if r['arm'] == a) for a in arms}
            fx = [a for a in arms if (a.split()[1].startswith('w:') if eng == 'charades' else a != 'adaptive')]
            top = max(fx, key=lambda a: med[a])
            best_of[(app, n, eng)] = (top, med[top])
            print(f"-- {eng}: best fixed setting by median {top} ({med[top]:.1f} M ev/s)")
            print(f"   {'arm':22} {'M ev/s':>8} {'eff%':>6} {'blk%':>5} {'meanW':>7}  ÷best of rep (r1/r2)")
            for a in arms:
                ar = sorted([r for r in er if r['arm'] == a], key=lambda r: r['rep'])
                rat = '/'.join(f"{r['rate'] / bestrep[r['rep']]:.2f}" for r in ar if bestrep[r['rep']])
                eff = st.median(r['eff'] for r in ar)
                blk = f"{st.median(r['blk'] for r in ar):5.1f}" if eng == 'charades' else '     '
                mw = ar[0].get('meanw') or ''
                mw = f"{float(mw):7.0f}" if mw not in ('', None) else '       '
                print(f"   {a:22} {med[a]:8.1f} {eff:6.2f} {blk} {mw}  {rat}")
        # aggregation: best htram arm ÷ best direct arm (fixed W only), Charades
        cr = [r for r in rs if r['engine'] == 'charades' and r['arm'].split()[1].startswith('w:')]
        h = [st.median(x['rate'] for x in cr if x['arm'] == a) for a in {r['arm'] for r in cr if not r['arm'].startswith('direct')}]
        dr = [st.median(x['rate'] for x in cr if x['arm'] == a) for a in {r['arm'] for r in cr if r['arm'].startswith('direct')}]
        if h and dr: print(f'-- aggregation, best htram ÷ best direct: {max(h) / max(dr):.2f}')
        c = best_of.get((app, n, 'charades'))
        for eng in ('devastator', 'ross'):
            o = best_of.get((app, n, eng))
            if c and o: print(f'-- Charades ÷ {eng}, each at its best fixed setting: {c[1] / o[1]:.2f}')
