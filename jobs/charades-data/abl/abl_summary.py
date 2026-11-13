#!/usr/bin/env python3
"""Job ABL (charades RESULTS.md section 222): F2, F3 and ROSS's window.

Usage: abl_summary.py <job dir>   (e.g. ~/charades-data/abl/j3682372)
"""
import csv, glob, os, re, statistics as st, sys
from collections import defaultdict

D = sys.argv[1]
WLS = ['g100', 'g2000', 'uni', 'tr']
NAME = {'g100': 'σ 100', 'g2000': 'σ 2,000', 'uni': 'uniform', 'tr': 'traffic'}
AB = {'g100': (250, 400), 'g2000': (250, 400), 'uni': (250, 400), 'tr': (500, 1000)}

rows = []  # dicts with N, wl, group, rep, plus the CSV fields
for f in glob.glob(os.path.join(D, 'n*', '*.csv')):
    N = int(os.path.basename(os.path.dirname(f))[1:])
    m = re.match(r'(g100|g2000|uni|tr|df)_(.+)_r(\d)$', os.path.basename(f)[:-4])
    if not m:
        continue
    wl, group, rep = m.group(1), m.group(2), int(m.group(3))
    with open(f) as fh:
        for r in csv.DictReader(fh):
            r.update(N=N, wl=wl, group=group, rep=rep)
            rows.append(r)

def rate(r):
    try:
        return float(r['event_rate']) / 1e6
    except (ValueError, KeyError):
        return None

def mean(xs):
    xs = [x for x in xs if x is not None]
    return st.mean(xs) if xs else None

def cell(N, wl, group, arm):
    rs = [r for r in rows if r['N'] == N and r['wl'] == wl and r['group'] == group and r['arm'] == arm]
    ok = [r for r in rs if r['status'] == 'ok']
    return rs, ok

def fmt(x, d=2):
    return '—' if x is None else f'{x:.{d}f}'

print('# Counts and digests (ok runs; one value per workload and node count is right)')
for N in (4, 16, 1):
    for wl in WLS + ['df']:
        ok = [r for r in rows if r['N'] == N and r['wl'] == wl and r['status'] == 'ok']
        if not ok:
            continue
        counts = sorted({r['committed'] for r in ok})
        digests = sorted({r['digest'] for r in ok if r.get('digest')})
        bad = [r for r in rows if r['N'] == N and r['wl'] == wl and r['status'] != 'ok']
        print(f'n{N} {wl:5s} ok {len(ok):3d} not ok {len(bad):2d}  counts {counts}  digests {digests}')

print('\n# F2: M committed ev/s, mean of 2 reps (higher is better)')
for N in (4, 16):
    print(f'\n## {N} nodes')
    print('| workload | transport | W A | W B | controller (mean W) | controller ÷ better fixed | events per message | rolled back (M), better W |')
    print('|---|---|---|---|---|---|---|---|')
    best = {}
    for wl in WLS:
        A, B = AB[wl]
        for g in ('direct', 'eager', 'deadline'):
            ra = mean([rate(r) for r in cell(N, wl, g, f'w:{A}')[1]])
            rb = mean([rate(r) for r in cell(N, wl, g, f'w:{B}')[1]])
            okc = cell(N, wl, g, 'mb:0')[1]
            rc = mean([rate(r) for r in okc])
            mw = mean([float(r['mean_window']) for r in okc if r['mean_window'] not in ('', 'none')])
            fixed = [(x, w) for x, w in ((ra, A), (rb, B)) if x is not None]
            bf, bw = max(fixed) if fixed else (None, None)
            best[(wl, g)] = (bf, bw, rc)
            epm = None
            okb = cell(N, wl, g, f'w:{bw}')[1] if bw else []
            if g != 'direct' and okb:
                epm = mean([float(r['htram_events']) / float(r['htram_msgs']) for r in okb
                            if r.get('htram_msgs') not in (None, '', '0')])
            rb_ev = mean([float(r['rolled_back']) / 1e6 for r in okb]) if okb else None
            ratio = rc / bf if (rc and bf) else None
            print(f'| {NAME[wl]} | {g} | {fmt(ra)} | {fmt(rb)} | {fmt(rc)} ({fmt(mw, 0)}) | {fmt(ratio)} | {fmt(epm, 1)} | {fmt(rb_ev, 3)} |')
    print('\n| workload | deadline ÷ direct, better fixed W each | deadline ÷ direct, controllers | eager ÷ deadline, W A | eager ÷ deadline, W B |')
    print('|---|---|---|---|---|')
    for wl in WLS:
        A, B = AB[wl]
        d, e, x = best[(wl, 'deadline')], best[(wl, 'eager')], best[(wl, 'direct')]
        def r_(g, w):
            return mean([rate(r) for r in cell(N, wl, g, f'w:{w}')[1]])
        ea = (r_('eager', A) / r_('deadline', A)) if r_('eager', A) and r_('deadline', A) else None
        eb = (r_('eager', B) / r_('deadline', B)) if r_('eager', B) and r_('deadline', B) else None
        print(f'| {NAME[wl]} | {fmt(d[0] / x[0] if d[0] and x[0] else None)} | {fmt(d[2] / x[2] if d[2] and x[2] else None)} | {fmt(ea)} | {fmt(eb)} |')

print('\n# F3 hold arms (status of each run)')
for N in (4, 16):
    for wl in WLS:
        hs = sorted({r['group'] for r in rows if r['N'] == N and r['wl'] == wl and r['group'].startswith('hold')})
        out = []
        for h in hs:
            rs = [r for r in rows if r['N'] == N and r['wl'] == wl and r['group'] == h]
            out.append(f"{h}: " + ','.join(r['status'] for r in rs))
        print(f'n{N} {wl}: ' + '; '.join(out))

print('\n# ROSS window (M committed ev/s, mean of 2 reps) and Charades controller')
ross = defaultdict(list)
fn = os.path.join(D, 'ross.txt')
if os.path.exists(fn):
    for line in open(fn):
        kv = dict(t.split('=', 1) for t in line.split() if '=' in t)
        if kv.get('status') == 'ok' and kv.get('M_ev_s'):
            ross[(int(kv['nodes']), kv['app'], int(kv['window']))].append((float(kv['M_ev_s']), kv['committed']))
for N in (1, 4):
    for app, wl, grp in (('traffic', 'tr', None), ('dragonfly', 'df', 'wps512')):
        ws = sorted(w for (n, a, w) in ross if n == N and a == app)
        if not ws:
            continue
        rates = {w: mean([x for x, _ in ross[(N, app, w)]]) for w in ws}
        counts = {c for w in ws for _, c in ross[(N, app, w)]}
        base = rates.get(0)
        bw = max((w for w in ws if w), key=lambda w: rates[w], default=None)
        if app == 'traffic':
            g = 'pp2048' if N == 1 else 'deadline'
        else:
            g = 'wps512'
        ch = mean([rate(r) for r in rows if r['N'] == N and r['wl'] == wl and r['group'] == g and r['arm'] == 'mb:0' and r['status'] == 'ok'])
        chc = sorted({r['committed'] for r in rows if r['N'] == N and r['wl'] == wl and r['group'] == g and r['arm'] == 'mb:0' and r['status'] == 'ok'})
        best_r = max(rates.values())
        print(f'n{N} {app}: ' + ', '.join(f'W {w}: {fmt(rates[w])}' for w in ws)
              + f' | best window ÷ none {fmt(rates[bw] / base if bw and base else None)} (W {bw})'
              + f' | Charades controller {fmt(ch)} ÷ ROSS best {fmt(ch / best_r if ch else None)}'
              + f' | ROSS counts {sorted(counts)} Charades {chc}')
