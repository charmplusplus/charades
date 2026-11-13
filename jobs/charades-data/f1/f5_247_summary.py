#!/usr/bin/env python3
"""F5 without diagnostics (charades RESULTS.md sections 247-248): traffic and
dragonfly, Charades, Devastator and ROSS, against an older F5 job.
Charades timing arms carry the launch only; the check arms od / dg / ri (the
old diagnostics; the digest alone; no GVT progress print) run at the best fixed
W (traffic PP 2,048 W 500, dragonfly WPs 512 W 10,000) and are kept out of
every timing comparison.
Usage: f5_247_summary.py <new job dir> <old job dir>"""
import csv, glob, os, re, statistics as st, sys, collections
APPS = {'df': 'dragonfly', 'tr': 'traffic'}
CHECK = ('od', 'dg', 'ri')
REF = {'dragonfly': ('wps512', 'w:10000'), 'traffic': ('pp2048', 'w:500')}

def load(d):
    rows = []
    for f in glob.glob(f'{d}/n*/*_r[0-9].csv'):
        n = int(f.split('/n')[-1].split('/')[0]); tag = os.path.basename(f)[:-4]
        head, rep = tag.rsplit('_r', 1)
        if head.startswith('warm'): continue
        app, mode = head.split('_', 1)
        for r in csv.DictReader(open(f)):
            if r['status'] != 'ok': print('FAILED charades', d, tag, r['arm'], r['status']); continue
            rows.append(dict(engine='charades', app=APPS[app], n=n, rep=int(rep), mode=mode, arm=r['arm'],
                             rate=float(r['event_rate']) / 1e6, committed=r['committed'], digest=r['digest']))
    for eng, fn in (('devastator', 'deva.txt'), ('ross', 'ross.txt')):
        for line in open(f'{d}/{fn}') if os.path.exists(f'{d}/{fn}') else []:
            r = dict(x.split('=', 1) for x in line.split() if '=' in x)
            if r.get('status') != 'ok' or not r.get('M_ev_s'):
                print('FAILED', eng, d, r.get('app'), r.get('nodes'), r.get('arm'), r.get('rep'), r.get('status')); continue
            rows.append(dict(engine=eng, app=r['app'], n=int(r['nodes']), rep=int(r['rep']), mode='', arm=r['arm'],
                             rate=float(r['M_ev_s']), committed=r['committed'], digest=''))
    return rows

def cell(rows, app, n):
    rs = [r for r in rows if r['app'] == app and r['n'] == n]
    med = lambda f: st.median([r['rate'] for r in rs if f(r)]) if any(f(r) for r in rs) else None
    ch = [r for r in rs if r['engine'] == 'charades' and r['mode'] not in CHECK]
    arms = {(r['mode'], r['arm']) for r in ch}
    m = {a: med(lambda r, a=a: r['engine'] == 'charades' and (r['mode'], r['arm']) == a) for a in arms}
    fixed = {a: v for a, v in m.items() if a[1].startswith('w:')}
    ctl = max(v for a, v in m.items() if a[1].startswith('mb'))
    bf = max(fixed, key=fixed.get)
    out = dict(ctl=ctl, fix=fixed[bf], bf=bf, rs=rs)
    for eng in ('devastator', 'ross'):
        e = {r['arm'] for r in rs if r['engine'] == eng}
        em = {a: med(lambda r, a=a, eng=eng: r['engine'] == eng and r['arm'] == a) for a in e}
        out[eng] = (max(em, key=em.get), max(em.values())) if em else (None, None)
    return out

new, old = load(sys.argv[1]), load(sys.argv[2])
print('Rates M committed ev/s, median of 3; ratios Charades ÷ other, higher is better. (old) = the old job.')
for app in ('dragonfly', 'traffic'):
    print(f'\n## {app}')
    print(f"{'N':>3} | {'ctl':>7} {'best fixed':>22} {'ctl/fx':>6} | {'Deva':>14} {'ROSS':>16} | {'C/D ctl':>14} {'C/D fixed':>14} {'C/R ctl':>12} | {'C ctl n/o':>9} {'C fx n/o':>8} {'D n/o':>6} {'R n/o':>6}")
    for n in (1, 2, 4, 8, 16):
        c, o = cell(new, app, n), cell(old, app, n)
        print(f"{n:3d} | {c['ctl']:7.1f} {c['bf'][0] + ' ' + c['bf'][1]:>15} {c['fix']:6.1f} {c['ctl'] / c['fix']:6.3f} | "
              f"{c['devastator'][0]:>6} {c['devastator'][1]:7.1f} {c['ross'][0]:>8} {c['ross'][1]:7.1f} | "
              f"{c['ctl'] / c['devastator'][1]:5.2f} ({o['ctl'] / o['devastator'][1]:4.2f}) {c['fix'] / c['devastator'][1]:5.2f} ({o['fix'] / o['devastator'][1]:4.2f}) "
              f"{c['ctl'] / c['ross'][1]:4.2f} ({o['ctl'] / o['ross'][1]:4.2f}) | {c['ctl'] / o['ctl']:9.3f} {c['fix'] / o['fix']:8.3f} "
              f"{c['devastator'][1] / o['devastator'][1]:6.3f} {c['ross'][1] / o['ross'][1]:6.3f}")
    # controller ÷ best fixed W in its own htram setting, per rep
    line = []
    for n in (1, 2, 4, 8, 16):
        rs = [r for r in new if r['app'] == app and r['n'] == n and r['engine'] == 'charades' and r['mode'] not in CHECK]
        cm = {r['mode'] for r in rs if r['arm'].startswith('mb')}.pop()
        per = []
        for k in (1, 2, 3):
            cc = [r['rate'] for r in rs if r['rep'] == k and r['arm'].startswith('mb')]
            fx = [r['rate'] for r in rs if r['rep'] == k and r['mode'] == cm and r['arm'].startswith('w:')]
            if cc and fx: per.append(cc[0] / max(fx))
        line.append(f"{n}: " + '/'.join(f'{x:.3f}' for x in per))
    print('   controller ÷ best fixed W in its htram setting, per rep: ' + '  '.join(line))
    # check arms ÷ the reference fixed arm, per rep
    mode, arm = REF[app]
    for chk in CHECK:
        line = []
        for n in (1, 2, 4, 8, 16):
            per = []
            for k in (1, 2, 3):
                ref = [r['rate'] for r in new if r['app'] == app and r['n'] == n and r['rep'] == k and r['mode'] == mode and r['arm'] == arm]
                x = [r['rate'] for r in new if r['app'] == app and r['n'] == n and r['rep'] == k and r['mode'] == chk]
                if ref and x: per.append(x[0] / ref[0])
            line.append(f"{n}: {st.median(per):.3f} ({min(per):.3f}-{max(per):.3f})")
        print(f"   {chk} ÷ {mode} {arm} (per rep; median (range)): " + '  '.join(line))
    # counts and digests
    for n in (1, 2, 4, 8, 16):
        rs = [r for r in new if r['app'] == app and r['n'] == n]
        cnt = {r['committed'] for r in rs}; dg = {r['digest'] for r in rs if r['mode'] in ('od', 'dg')}
        empty = sum(1 for r in rs if r['mode'] in ('od', 'dg') and not r['digest'])
        print(f"   {n} nodes: counts {sorted(cnt)}{' <-- DIFFER' if len(cnt) != 1 else ''}; digests {sorted(dg)} (empty: {empty})")
    # per-node rate 16 ÷ 1
    c1, c16 = cell(new, app, 1), cell(new, app, 16)
    print(f"   per-node rate 16 ÷ 1: Charades ctl {c16['ctl'] / 16 / c1['ctl']:.3f}, best fixed {c16['fix'] / 16 / c1['fix']:.3f}, "
          f"Devastator {c16['devastator'][1] / 16 / c1['devastator'][1]:.3f}, ROSS {c16['ross'][1] / 16 / c1['ross'][1]:.3f}")
