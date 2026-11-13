#!/usr/bin/env python3
"""F5 (RESULTS.md section 187): traffic and dragonfly weak scaling in Charades,
Devastator and ROSS. Usage: f5_summary.py <job dir> [<job dir> ...]
(a_j<id> = F5a, 1-16 nodes; big_j<id> = F5b, 16 nodes on two halves, 32).

Per application, job and node count: committed counts across engines and
Charades digests (S1); each engine's arms (M committed ev/s, median over
reps); each engine at its best (Charades' controller and its best fixed W
against Devastator's best W and ROSS's best arm, Charades ÷ other, higher is
better; S2, S3); the controller ÷ the best fixed W in its htram mode, per rep
(S4); per-node rate ÷ the 1-node rate (S5, S6); aggregation, best htram ÷ best
direct (S7)."""
import csv, glob, os, re, statistics as st, sys
APPS = {'df': 'dragonfly', 'tr': 'traffic'}
CTL_MODE = {'dragonfly': 'wps512', 'traffic': 'pp2048'}
rows = []
for d in sys.argv[1:]:
    job = os.path.basename(d.rstrip('/'))
    for f in glob.glob(f'{d}/n*/*_r[0-9].csv'):
        n = int(f.split('/n')[-1].split('/')[0]); tag = os.path.basename(f)[:-4]
        head, rep = tag.rsplit('_r', 1)
        if head.startswith('warm'): continue
        app, agg = head.split('_', 1)
        for r in csv.DictReader(open(f)):
            if r['status'] != 'ok': print('FAILED charades', job, tag, r['arm'], r['status']); continue
            rows.append(dict(job=job, engine='charades', app=APPS[app], n=n, rep=int(rep), mode=agg,
                             arm=f"{agg} {r['arm']}", fixed=r['arm'].startswith('w:'),
                             rate=float(r['committed']) / float(r['exec_s']) / 1e6, committed=r['committed'],
                             digest=r['digest'], eff=float(r['efficiency']), meanw=r['mean_window']))
    for eng, fn in (('devastator', 'deva.txt'), ('ross', 'ross.txt')):
        p = f'{d}/{fn}'
        if not os.path.exists(p): continue
        for line in open(p):
            r = dict(x.split('=', 1) for x in line.split() if '=' in x)
            if r.get('status') != 'ok' or not r.get('M_ev_s'):
                print('FAILED', eng, job, r.get('app'), r.get('nodes'), r.get('arm'), 'rep', r.get('rep'), r.get('status')); continue
            eff = float(r.get('efficiency') or 0) if eng == 'ross' else 100.0 * int(r['committed']) / max(1, int(r['executed'] or 0))
            rows.append(dict(job=job, engine=eng, app=r['app'], n=int(r['nodes']), rep=int(r['rep']), mode='',
                             arm=r['arm'], fixed=r['arm'] != 'adaptive', rate=float(r['M_ev_s']),
                             committed=r['committed'], digest='', eff=eff, meanw=''))

def med(xs): return st.median(xs) if xs else None
summary = {}
for app in ('dragonfly', 'traffic'):
    for job in sorted({r['job'] for r in rows}):
        for n in sorted({r['n'] for r in rows if r['job'] == job and r['app'] == app}):
            rs = [r for r in rows if r['job'] == job and r['app'] == app and r['n'] == n]
            counts = {r['committed'] for r in rs}; digests = {r['digest'] for r in rs if r['engine'] == 'charades'}
            reps = sorted({r['rep'] for r in rs})
            print(f"\n===== {app}, {n} node(s), {job}: reps {reps}; counts {sorted(counts)}{' <-- DIFFER' if len(counts) != 1 else ''}; "
                  f"digests {sorted(digests)}{' <-- DIFFER' if len(digests) != 1 else ''}")
            best = {}
            for eng in ('charades', 'devastator', 'ross'):
                er = [r for r in rs if r['engine'] == eng]
                arms = sorted({r['arm'] for r in er})
                m = {a: med([r['rate'] for r in er if r['arm'] == a]) for a in arms}
                fx = [a for a in arms if any(r['fixed'] for r in er if r['arm'] == a)]
                if not fx: continue
                top = max(fx, key=lambda a: m[a]); best[eng] = (top, m[top])
                line = '  '.join(f"{a} {m[a]:.1f}" for a in sorted(arms, key=lambda a: -m[a]))
                print(f"  {eng:10} {line}")
            ctl = [r for r in rs if r['engine'] == 'charades' and not r['fixed']]
            ctl_m = med([r['rate'] for r in ctl])
            # controller ÷ best fixed W in its htram mode, per rep
            cr = []
            for k in reps:
                c = [r['rate'] for r in ctl if r['rep'] == k]
                fx = [r['rate'] for r in rs if r['engine'] == 'charades' and r['fixed'] and r['mode'] == CTL_MODE[app] and r['rep'] == k]
                if c and fx: cr.append(c[0] / max(fx))
            ch = [r for r in rs if r['engine'] == 'charades' and r['fixed']]
            h = [med([x['rate'] for x in ch if x['arm'] == a]) for a in {r['arm'] for r in ch if r['mode'] != 'direct'}]
            dr = [med([x['rate'] for x in ch if x['arm'] == a]) for a in {r['arm'] for r in ch if r['mode'] == 'direct'}]
            agg = max(h) / max(dr) if h and dr else None
            summary[(app, job, n)] = dict(ch=best.get('charades'), ctl=ctl_m, dv=best.get('devastator'), ro=best.get('ross'),
                                          cr=cr, agg=agg, eff=med([r['eff'] for r in rs if r['engine'] == 'charades' and r['arm'] == (best.get('charades') or ('',))[0]]))

print('\n\n===== Summary (M committed ev/s, medians; ratios higher is better for Charades)')
for app in ('dragonfly', 'traffic'):
    print(f'\n{app}')
    print(f"{'job':12} {'N':>3} {'ctl':>8} {'C best fixed':>24} {'Deva best':>18} {'ROSS best':>18} {'ctl÷D':>6} {'ctl÷R':>6} {'Cfx÷D':>6} "
          f"{'ctl÷fixed (reps)':>22} {'agg':>5} {'ctl/node':>8}")
    one = {}
    for (a, job, n), s in sorted(summary.items(), key=lambda x: (x[0][1], x[0][2])):
        if a != app: continue
        if n == 1: one[job] = s
        base = one.get(job) or next((v for (aa, jj, nn), v in summary.items() if aa == app and nn == 1), None)
        pn = s['ctl'] / n if s['ctl'] else None
        pn1 = base['ctl'] if base and base['ctl'] else None
        f = lambda x, p=2: f'{x:.{p}f}' if x is not None else '-'
        print(f"{job:12} {n:3d} {f(s['ctl'],1):>8} {(s['ch'][0] + ' ' + f(s['ch'][1],1)) if s['ch'] else '-':>24} "
              f"{(s['dv'][0] + ' ' + f(s['dv'][1],1)) if s['dv'] else '-':>18} {(s['ro'][0] + ' ' + f(s['ro'][1],1)) if s['ro'] else '-':>18} "
              f"{f(s['ctl'] / s['dv'][1] if s['dv'] and s['ctl'] else None):>6} {f(s['ctl'] / s['ro'][1] if s['ro'] and s['ctl'] else None):>6} "
              f"{f(s['ch'][1] / s['dv'][1] if s['dv'] and s['ch'] else None):>6} {'/'.join(f(x) for x in s['cr']):>22} {f(s['agg']):>5} "
              f"{f(pn / pn1 if pn and pn1 else None):>8}")
    # per-node efficiency for every engine, against 1 node of the first job that has it
    print(f"  per-node rate ÷ 1-node rate, each engine at its best (Charades: controller):")
    for eng, key in (('charades', 'ctl'), ('devastator', 'dv'), ('ross', 'ro')):
        line = []
        for (a, job, n), s in sorted(summary.items(), key=lambda x: (x[0][1], x[0][2])):
            if a != app: continue
            b = next((v for (aa, jj, nn), v in summary.items() if aa == app and nn == 1), None)
            if not b: continue
            g = lambda v: (v[key] if key == 'ctl' else (v[key][1] if v[key] else None))
            if g(s) and g(b): line.append(f"{job[:3]}{n}:{g(s) / n / g(b):.2f}")
        print(f"    {eng:10} {' '.join(line)}")
