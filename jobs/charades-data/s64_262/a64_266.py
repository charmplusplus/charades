#!/usr/bin/env python3
"""Job A64 (charades results/phold.md section 262, results in 266): traffic,
dragonfly (shape a = 46, h = 22) and VLSI at 64 nodes, three engines, against
F5-32b (job 3690451, section 253) and V32b (job 3690452, section 254).
Definitions: traffic and dragonfly as F5 (f5_32_summary.py): Charades = its
controller (dragonfly WPs 512, traffic PP 2,048), best fixed = the best
(setting, W) by median, the check arm dg kept out of every timing comparison;
Devastator its best W; ROSS its best arm. VLSI as VA (vscale249_summary.py):
best fixed = the fixed arm with the highest median (E W 5,000, E W 2,500,
L W 2,500), the controller its own median, the check arm G (digest) kept out.
M committed ev/s, medians of reps; ratios Charades / other, higher is better.
Warm-up runs (rep 0) are left out. A Charades run without count waves ran on
the engine defaults (section 263) and is dropped.
Usage: a64_266.py <A64 job dir> <F5-32b job dir> <V32b job dir>"""
import csv, glob, os, statistics as st, sys, collections
A64, F32, V32 = sys.argv[1:4]
APPS = {'df': 'dragonfly', 'tr': 'traffic'}; CHECK = ('od', 'dg', 'ri')
med = lambda x: st.median(x) if x else None

def load(d, n, devf, rossf):
    rows, bad = [], []
    for f in glob.glob(f'{d}/n{n}/*_r[0-9].csv'):
        tag = os.path.basename(f)[:-4]; head, rep = tag.rsplit('_r', 1)
        if head.startswith('warm'): continue
        app, mode = head.split('_', 1)
        for r in csv.DictReader(open(f)):
            if r['status'] != 'ok': bad.append(('charades', tag, r['arm'], r['status'])); continue
            if not (r.get('count_waves') or '0').strip('0.'): bad.append(('charades NO COUNT WAVES', tag, r['arm'])); continue
            rows.append(dict(engine='charades', app=APPS[app], rep=int(rep), mode=mode, arm=r['arm'], rate=float(r['event_rate']) / 1e6,
                             committed=r['committed'], digest=r['digest'], epm=r.get('agg_events_per_msg'), mw=r.get('mean_window')))
    for eng, fn in (('devastator', devf), ('ross', rossf)):
        for line in open(f'{d}/{fn}') if os.path.exists(f'{d}/{fn}') else []:
            r = dict(x.split('=', 1) for x in line.split() if '=' in x)
            if r.get('nodes') != str(n) or r.get('rep') in ('0', 'warm') or not r.get('rep', '').isdigit(): continue
            if r.get('status') != 'ok' or not r.get('M_ev_s'): bad.append((eng, r.get('app'), r.get('arm'), r.get('rep'), r.get('status'))); continue
            rows.append(dict(engine=eng, app=r['app'], rep=int(r['rep']), mode='', arm=r['arm'].replace('df_', '').replace('tr_', ''),
                             rate=float(r['M_ev_s']), committed=r['committed'], digest=''))
    return rows, bad

def cell(rows, app):
    rs = [r for r in rows if r['app'] == app]
    by = collections.defaultdict(list)
    for r in rs:
        if r['engine'] == 'charades' and r['mode'] in CHECK: continue
        by[(r['engine'], r['mode'], r['arm'])].append(r['rate'])
    m = {k: med(v) for k, v in by.items()}
    ctl = max(v for k, v in m.items() if k[0] == 'charades' and k[2].startswith('mb'))
    fixed = {k: v for k, v in m.items() if k[0] == 'charades' and k[2].startswith('w:')}
    bf = max(fixed, key=fixed.get)
    htr = {k: v for k, v in fixed.items() if k[1] != 'direct'}; dr = {k: v for k, v in fixed.items() if k[1] == 'direct'}
    out = dict(ctl=ctl, fix=fixed[bf], bf=bf, m=m, by=by, rs=rs, htr=max(htr.values()), hk=max(htr, key=htr.get), dr=max(dr.values()), dk=max(dr, key=dr.get))
    for eng in ('devastator', 'ross'):
        em = {k[2]: v for k, v in m.items() if k[0] == eng}
        out[eng] = (max(em, key=em.get), max(em.values())) if em else (None, None)
        out[eng + '_fast'] = max((r['rate'] for r in rs if r['engine'] == eng), default=None)
    return out

new, badn = load(A64, 64, 'deva_f5.txt', 'ross_f5.txt'); old, _ = load(F32, 32, 'deva.txt', 'ross.txt')
print('A64 traffic and dragonfly: runs %d; failed, stalled or without count waves: %d' % (len(new), len(badn)))
for b in badn: print('  bad', b)
for app in ('dragonfly', 'traffic'):
    c, o = cell(new, app), cell(old, app)
    print(f'\n## {app} at 64 nodes (F5-32b at 32 in brackets)')
    cnt = {r['committed'] for r in c['rs']}; dg = {r['digest'] for r in c['rs'] if r['engine'] == 'charades' and r['mode'] == 'dg'}
    print(f"  counts {sorted(cnt)} -> {'one count' if len(cnt) == 1 else 'DIFFER'}; Charades digests (dg) {sorted(dg)}")
    print(f"  Charades controller {c['ctl']:.1f} [{o['ctl']:.1f}]; best fixed {c['bf'][1]} {c['bf'][2]} {c['fix']:.1f} [{o['bf'][1]} {o['bf'][2]} {o['fix']:.1f}]; ctl / best fixed {c['ctl'] / c['fix']:.3f} [{o['ctl'] / o['fix']:.3f}]")
    print(f"  Devastator best W {c['devastator'][0]} {c['devastator'][1]:.1f} [W {o['devastator'][0]} {o['devastator'][1]:.1f}]; ROSS best {c['ross'][0]} {c['ross'][1]:.1f} [{o['ross'][0]} {o['ross'][1]:.1f}]")
    print(f"  C/D {c['ctl'] / c['devastator'][1]:.2f} [{o['ctl'] / o['devastator'][1]:.2f}]; against Devastator's fastest rep {c['ctl'] / c['devastator_fast']:.2f}; C/R {c['ctl'] / c['ross'][1]:.2f} [{o['ctl'] / o['ross'][1]:.2f}]")
    print(f"  per-node 32->64: Charades {c['ctl'] / o['ctl'] / 2:.3f}, Devastator {c['devastator'][1] / o['devastator'][1] / 2:.3f}, ROSS {c['ross'][1] / o['ross'][1] / 2:.3f}")
    print(f"  htram / direct (best fixed each): {c['htr'] / c['dr']:.2f} ({c['hk'][1]} {c['hk'][2]} / direct {c['dk'][2]}) [{o['htr'] / o['dr']:.2f}]")
    for k in sorted(c['by']):
        v = sorted(c['by'][k]); print(f"    {k[0]:10} {k[1]:7} {k[2]:9} {med(v):8.1f}  spread {v[-1] / v[0]:.2f}  reps {' '.join('%.0f' % x for x in v)}")
    mw = [float(r['mw']) for r in c['rs'] if r['engine'] == 'charades' and r['arm'].startswith('mb') and r.get('mw')]
    ep = [float(r['epm']) for r in c['rs'] if r['engine'] == 'charades' and r['arm'].startswith('mb') and r.get('epm')]
    print(f"    controller mean W {min(mw):.0f}-{max(mw):.0f}; events per htram message (controller) {med(ep):.1f}")
    dgr = [r['rate'] for r in c['rs'] if r['mode'] == 'dg']
    ref = c['by'][('charades', 'wps512' if app == 'dragonfly' else 'pp2048', 'w:10000' if app == 'dragonfly' else 'w:500')]
    print(f"    dg (digest check) / its timing arm, medians: {med(dgr) / med(ref):.3f}")

# ---------- VLSI
TIME = [('E', 'w5000'), ('E', 'w2500'), ('L', 'w2500'), ('E', 'mb0')]; FIXED = TIME[:3]; DW = ['2500', '5000', '10000']
def vrow(path):
    if not os.path.exists(path): return None
    r = list(csv.DictReader(open(path)))
    return r[0] if len(r) == 1 and r[0]['status'] == 'ok' else None
def vload(base, reps, devf, n):
    ch = collections.defaultdict(list); dig = set(); cnt = set(); bad = []
    for rep in reps:
        for a in TIME + [('G', 'w5000')]:
            r = vrow(os.path.join(base, rep, f'{a[0]}_{a[1]}.csv'))
            if not r: bad.append((rep, a)); continue
            if not (r.get('count_waves') or '0').strip('0.'): bad.append((rep, a, 'NO COUNT WAVES')); continue
            cnt.add(r['committed'])
            if a[0] == 'G': dig.add(r['digest'])
            else: ch[a].append(float(r['event_rate']) / 1e6)
    dv = collections.defaultdict(list)
    for line in open(devf):
        k = dict(t.split('=', 1) for t in line.split() if '=' in t)
        if k.get('nodes') != str(n) or not k.get('rep', '').isdigit(): continue
        if k['status'] != 'ok': bad.append(('dv', k['window'], k['rep'], k['status'])); continue
        dv[k['window']].append(float(k['M_ev_s'])); cnt.add(k['committed'] + ' (D)')
    return ch, dv, dig, cnt, bad
vn = vload(os.path.join(A64, 'n64', 'vlsi'), ['r1', 'r2', 'r3', 'r4', 'r5'], os.path.join(A64, 'deva_vlsi.txt'), 64)
vo = vload(os.path.join(V32, 'n32'), ['r1', 'r2', 'r3', 'r4', 'r5'], os.path.join(V32, 'deva.txt'), 32)
def vbest(v):
    ch, dv = v[0], v[1]
    cm = {a: med(ch[a]) for a in FIXED}; ca = max(cm, key=cm.get); dm = {w: med(dv[w]) for w in DW if dv[w]}; dw = max(dm, key=dm.get)
    return dict(cfix=cm[ca], ca=ca, ctl=med(ch[TIME[3]]), dev=dm[dw], dw=dw, fast=max(x for w in dm for x in dv[w]))
n, o = vbest(vn), vbest(vo)
print('\n## VLSI at 64 nodes (V32b at 32 in brackets)')
print(f"  counts {sorted(vn[3])}; Charades digests (G) {sorted(vn[2])}; not ok: {vn[4]}")
for a in TIME:
    v = sorted(vn[0][a]); print(f"    Charades {a[0]} {a[1]:6} {med(v):7.1f} [{med(vo[0][a]):7.1f}] spread {v[-1] / v[0]:.2f}  reps {' '.join('%.0f' % x for x in v)}")
for w in DW:
    v = sorted(vn[1][w]); print(f"    Devastator W {w:6}   {med(v):7.1f} [{med(vo[1][w]):7.1f}] spread {v[-1] / v[0]:.2f}  reps {' '.join('%.0f' % x for x in v)}")
print(f"  Charades best fixed {n['ca'][0]} {n['ca'][1]} {n['cfix']:.1f} [{o['ca'][0]} {o['ca'][1]} {o['cfix']:.1f}]; controller {n['ctl']:.1f} [{o['ctl']:.1f}]; Devastator W {n['dw']} {n['dev']:.1f} [W {o['dw']} {o['dev']:.1f}]")
print(f"  C/D controller {n['ctl'] / n['dev']:.2f} [{o['ctl'] / o['dev']:.2f}]; best fixed {n['cfix'] / n['dev']:.2f} [{o['cfix'] / o['dev']:.2f}]; against Devastator's fastest rep {n['ctl'] / n['fast']:.2f}")
print(f"  per-node 32->64: Charades controller {n['ctl'] / o['ctl'] / 2:.3f}, best fixed {n['cfix'] / o['cfix'] / 2:.3f}; Devastator {n['dev'] / o['dev'] / 2:.3f}")
per = [c / max(f) for c, f in zip(vn[0][TIME[3]], zip(*[vn[0][a] for a in FIXED]))]
print(f"  controller / best fixed arm of the same rep: {' '.join('%.3f' % x for x in per)}; median {med(per):.3f}")
gr = [x for x in [float(r['event_rate']) / 1e6 for r in [vrow(os.path.join(A64, 'n64', 'vlsi', rep, 'G_w5000.csv')) for rep in ['r1', 'r2', 'r3', 'r4', 'r5']] if r]]
print(f"  G (digest check) / E W 5,000, medians: {med(gr) / med(vn[0][TIME[0]]):.3f}")
