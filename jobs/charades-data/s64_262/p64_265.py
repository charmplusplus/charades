#!/usr/bin/env python3
"""Job P64 (charades results/phold.md section 262, results in 265): F1's
PHOLD workloads at 64 nodes, three engines, against F1-32 (job 3688916,
section 252). Definitions as F1 (f1_240_summary.py, exec'd here): Charades =
its controller at the better htram setting (sigma 1,000 also PP 512, g1000x);
best fixed = the best (htram setting, W) by median; Devastator = its best W by
median; ROSS = the best of optimistic, conservative and optimistic with its
window. M committed ev/s, medians of reps; ratios Charades / other, higher is
better. Bundling = best htram fixed W / best direct fixed W (section 257's
definition). A Charades run without count waves ran on the engine defaults
(section 263) and is dropped.
Usage: p64_265.py <P64 job dir> <F1-32 job dir> <AG32 job dir>"""
import csv, glob, os, re, statistics as st, sys, collections
here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, '..', 'f1', 'f1_240_summary.py')).read().split('argv = sys.argv[1:]')[0]
exec(src)   # NAMES, load(), med (of (rate, count) pairs), is_ctl, cells()
P64, F32, AG = sys.argv[1:4]
smed = st.median
WLS = ['g100', 'g500', 'g1000', 'g2000', 'g4000', 'uni', 'l10g500', 'l10g2000']

def nowaves(d):
    out = []
    for f in glob.glob(os.path.join(d, 'n*', '*.csv')):
        for r in csv.DictReader(open(f)):
            if r['status'] == 'ok' and not (r.get('count_waves') or '0').strip('0.'):
                out.append((os.path.basename(f), r['arm']))
    return out

def merged(d):
    ch, dv, ro, bad = load([d])
    c = cells(ch, dv, ro)
    for k in [k for k in c if k[0] == 'g1000x']:   # sigma 1,000: the better of PP 2,048 and PP 512
        b = ('g1000', k[1])
        if b in c:
            if c[k]['ctl'] > c[b]['ctl']: c[b]['ctl'], c[b]['ca'] = c[k]['ctl'], c[k]['ca'] + ' (x)'
            if c[k]['fix'] > c[b]['fix']: c[b]['fix'], c[b]['fa'] = c[k]['fix'], (c[k]['fa'][0] + ' (x)', c[k]['fa'][1])
    return c, ch, dv, ro, bad

nw = nowaves(P64)
p, pch, pdv, pro, bad = merged(P64)
o, och, odv, oro, _ = merged(F32)
N, M = 64, 32
print('P64 runs: Charades %d, Devastator %d, ROSS %d; failed or stalled: %d; Charades runs without count waves: %d' % (
    sum(map(len, pch.values())), sum(map(len, pdv.values())), sum(map(len, pro.values())), len(bad), len(nw)))
for b in bad: print('  bad', b)
for x in nw: print('  NO COUNT WAVES', x)

print('\n# 64 nodes (F1-32 in brackets): M committed ev/s, medians of 5; ratios Charades / other')
print('%-22s | %-24s | %-26s | %-7s | %-22s | %-18s | %-11s | %-11s | %s' % ('workload', 'Charades ctl (htram)', 'best fixed (htram, W)', 'ctl/fx', 'Devastator best (W)', 'ROSS best', 'C/D', 'C/R', 'per-node 32->64 C / D / R'))
rows = {}
for wl in WLS:
    a, b = p[(wl, N)], o[(wl, M)]
    r = dict(cd=a['ctl'] / a['dev'], cd32=b['ctl'] / b['dev'], cr=a['ctl'] / a['ross'], cr32=b['ctl'] / b['ross'],
             pn=(a['ctl'] / b['ctl'] / 2, a['dev'] / b['dev'] / 2, a['ross'] / b['ross'] / 2), cf=a['ctl'] / a['fix'])
    rows[wl] = r
    print('%-22s | %7.1f %-8s [%7.1f] | %7.1f %-6s W%-4s [W%-4s] | %.3f | %7.1f W%-5s [%7.1f] | %6.1f %-7s | %.2f [%.2f] | %.2f [%.2f] | %.2f / %.2f / %.2f' % (
        NAMES[wl], a['ctl'], a['ca'], b['ctl'], a['fix'], a['fa'][0][:6], a['fa'][1][2:], b['fa'][1][2:], r['cf'], a['dev'], a['dw'], b['dev'],
        a['ross'], a['rm'], r['cd'], r['cd32'], r['cr'], r['cr32'], *r['pn']))
print('C/D range %.2f-%.2f (32: %.2f-%.2f); ahead in %d of %d; C/R range %.2f-%.2f' % (
    min(r['cd'] for r in rows.values()), max(r['cd'] for r in rows.values()), min(r['cd32'] for r in rows.values()), max(r['cd32'] for r in rows.values()),
    sum(r['cd'] > 1 for r in rows.values()), len(rows), min(r['cr'] for r in rows.values()), max(r['cr'] for r in rows.values())))
print('per-node 32->64: Charades %.2f-%.2f, Devastator %.2f-%.2f, ROSS %.2f-%.2f; Charades >= Devastator in %d of 8' % (
    min(r['pn'][0] for r in rows.values()), max(r['pn'][0] for r in rows.values()), min(r['pn'][1] for r in rows.values()), max(r['pn'][1] for r in rows.values()),
    min(r['pn'][2] for r in rows.values()), max(r['pn'][2] for r in rows.values()), sum(r['pn'][0] >= r['pn'][1] for r in rows.values())))
print('controller / best fixed W: %.3f-%.3f' % (min(r['cf'] for r in rows.values()), max(r['cf'] for r in rows.values())))

print('\n# Counts (one per workload over every engine and arm)')
for wl in WLS + ['g1000x']:
    print('  %-9s %s' % (wl, sorted(p[(wl, N)]['commits'])))

print('\n# Charades per arm (median; spread = max/min over reps; controller mean W)')
for wl in WLS + ['g1000x']:
    for (w, n, ag, arm), v in sorted(pch.items()):
        if w != wl or n != N: continue
        x = sorted(r for r, _ in v)
        print('  %-9s %-7s %-6s %7.1f  spread %.2f  reps %s' % (wl, ag, arm, smed(x), x[-1] / x[0], ' '.join('%.0f' % y for y in x)))
    mw = []
    for f in glob.glob(os.path.join(P64, 'n64', wl + '_*_r?.csv')):
        for r in csv.DictReader(open(f)):
            if r['status'] == 'ok' and r['arm'].startswith('mb') and r.get('mean_window'): mw.append(float(r['mean_window']))
    if mw: print('  %-9s controller mean W %.0f-%.0f' % (wl, min(mw), max(mw)))

print('\n# Devastator per W (median; spread) and ROSS per arm')
for wl in WLS:
    print('  %-9s D: %s' % (wl, '  '.join('W%d %.1f s%.2f' % (W, med(v), max(x for x, _ in v) / min(x for x, _ in v)) for (w, n, W), v in sorted(pdv.items()) if w == wl and n == N)))
    print('  %-9s R: %s' % ('', '  '.join('%s %.1f' % (m, med(v)) for (w, n, m), v in sorted(pro.items()) if w == wl and n == N)))
    a = p[(wl, N)]; fast = max(x for (w, n, W), v in pdv.items() if w == wl and n == N for x, _ in v)
    print('  %-9s C/D against Devastator\'s fastest rep (%.1f): %.2f' % ('', fast, a['ctl'] / fast))

print('\n# Bundling: best htram fixed W / best direct fixed W (64 nodes; AG32 at 32)')
def direct(d, n, wl):
    out = collections.defaultdict(list)
    for f in glob.glob(os.path.join(d, 'n%d' % n, wl + '_off_r?.csv')):
        for r in csv.DictReader(open(f)):
            if r['status'] == 'ok' and r['arm'].startswith('w'): out[r['arm']].append(float(r['event_rate']) / 1e6)
    return {k: smed(v) for k, v in out.items()}
def epm(d, n, wl, agg):
    x = []
    for f in glob.glob(os.path.join(d, 'n%d' % n, '%s_%s_r?.csv' % (wl, agg))):
        for r in csv.DictReader(open(f)):
            if r['status'] == 'ok' and r.get('agg_events_per_msg'): x.append(float(r['agg_events_per_msg']))
    return smed(x) if x else float('nan')
for wl, aggs in (('uni', ['pp512', 'wps512']), ('g4000', ['pp512'])):
    dd = direct(P64, 64, wl); db = max(dd, key=dd.get)
    hb = max((((k[2], k[3]), med(v)) for k, v in pch.items() if k[0] == wl and k[1] == N and k[2] in aggs and k[3].startswith('w')), key=lambda t: t[1])
    ag32 = direct(AG, 32, wl)
    h32 = {}
    for f in glob.glob(os.path.join(AG, 'n32', '%s_*_r?.csv' % wl)):
        mm = re.match(r'%s_(pp512|wps512|pp2048|wps2048)_r\d\.csv' % wl, os.path.basename(f))
        if not mm: continue
        for r in csv.DictReader(open(f)):
            if r['status'] == 'ok' and r['arm'].startswith('w'): h32.setdefault((mm.group(1), r['arm']), []).append(float(r['event_rate']) / 1e6)
    h32b = max(((k, smed(v)) for k, v in h32.items()), key=lambda t: t[1]) if h32 else (None, float('nan'))
    d32b = max(ag32.values()) if ag32 else float('nan')
    ctl = p[(wl, N)]['ctl']
    print('  %-6s direct %s; best htram %s %s %.1f; bundling %.2f (AG32 32 nodes: %.2f); controller / best direct %.2f; events per htram message %s' % (
        wl, ' '.join('%s %.1f' % kv for kv in sorted(dd.items())), hb[0][0], hb[0][1], hb[1], hb[1] / dd[db], h32b[1] / d32b, ctl / dd[db],
        ' '.join('%s %.1f' % (ag, epm(P64, 64, wl, ag)) for ag in aggs)))

print('\n# Spread between reps above 1.10 (64 nodes)')
sp = []
for k, v in list(pch.items()) + list(pdv.items()) + list(pro.items()):
    if k[1] != N: continue
    x = sorted(a for a, _ in v)
    if len(x) > 1 and x[-1] / x[0] > 1.10: sp.append((x[-1] / x[0], x[-1] / x[1] if len(x) > 2 else None, k))
for s, s2, k in sorted(sp, key=lambda t: -t[0]):
    print('  %-40s %.2f (without the slowest %s)' % (k, s, '%.2f' % s2 if s2 else '-'))
print('arms above 1.10: %d' % len(sp))
