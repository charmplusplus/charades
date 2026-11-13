#!/usr/bin/env python3
"""Job R8 (charades results/phold.md sections 260-261): F1's and F5's 8-node
columns rerun with the batch host (node 0) idle, GC's four 1-node cells off
node 0, and a check of uniform at 8 nodes alone against beside load streams.
Definitions as in F1 (f1_240_summary.py) and F5: Charades = its controller at
the better htram setting (sigma 1,000 also PP 512); Devastator = its best W;
ROSS = its best arm. M committed ev/s, medians of reps; ratios Charades / other,
higher is better; 'this / F1' compares one engine across jobs."""
import csv, glob, os, re, statistics as st
from collections import defaultdict
here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, 'f1_240_summary.py')).read().split('argv = sys.argv[1:]')[0]
exec(src)   # load(), cells(), med (of (rate, count) pairs), NAMES
smed = st.median
R8 = os.path.join(here, 'r8_260/j3695259')
F1 = [os.path.join(here, 'scale240', d) for d in ('a_j3689004', 'b_j3689513')]
F5 = os.path.join(here, 'scale240/f5a_j3690453')
WLS = ['g100', 'g500', 'g1000', 'g2000', 'g4000', 'uni', 'l10g500', 'l10g2000']

def f1cells(dirs, N):
    ch, dv, ro, bad = load(dirs)
    ch = {k: v for k, v in ch.items() if k[1] == N and k[0] in WLS + ['g1000x']}; dv = {k: v for k, v in dv.items() if k[1] == N}; ro = {k: v for k, v in ro.items() if k[1] == N}
    c = cells(ch, dv, ro)
    for k in [k for k in c if k[0] == 'g1000x']:   # sigma 1,000: the better of PP 2,048 and PP 512
        b = ('g1000', k[1])
        if b in c and c[k]['ctl'] > c[b]['ctl']: c[b]['ctl'], c[b]['ca'] = c[k]['ctl'], c[k]['ca'] + ' (x)'
    return c, ch, dv, ro, bad
r8, r8ch, r8dv, r8ro, bad = f1cells([R8], 8)
f1, f1ch, f1dv, f1ro, _ = f1cells(F1, 8)
print('R8 8-node PHOLD: Charades %d, Devastator %d, ROSS %d runs; failed: %d' % (
    sum(map(len, r8ch.values())), sum(map(len, r8dv.values())), sum(map(len, r8ro.values())), len(bad)))
for b in bad: print('  bad', b)

print('\n# 8 nodes, PHOLD (this job; F1 in brackets)')
print('%-22s | %-15s | %-24s | %-15s | %-13s | %-13s | %s' % ('workload', 'Charades ctl', 'Devastator best (W)', 'ROSS best', 'C/D', 'C/R', 'this / F1: C, D, R'))
for wl in WLS:
    a, o = r8[(wl, 8)], f1[(wl, 8)]
    print('%-22s | %6.1f [%6.1f] | %6.1f (W%-4s) [%6.1f W%-4s] | %5.1f [%5.1f] | %.2f [%.2f] | %.2f [%.2f] | %.3f %.3f %.3f' % (
        NAMES[wl], a['ctl'], o['ctl'], a['dev'], a['dw'], o['dev'], o['dw'], a['ross'], o['ross'],
        a['ctl'] / a['dev'], o['ctl'] / o['dev'], a['ctl'] / a['ross'], o['ctl'] / o['ross'], a['ctl'] / o['ctl'], a['dev'] / o['dev'], a['ross'] / o['ross']))
    print('   Devastator per W: %s; counts one and = F1: %s' % ('  '.join('W%d %.1f s%.2f' % (w, med(v), max(x[0] for x in v) / min(x[0] for x in v))
          for (x, n, w), v in sorted(r8dv.items()) if x == wl), r8[(wl, 8)]['commits'] == f1[(wl, 8)]['commits'] and len(r8[(wl, 8)]['commits']) == 1))

# ---------- F5 at 8 nodes
def f5load(d):
    ch = defaultdict(list); dv = defaultdict(list); ro = defaultdict(list); cnt = defaultdict(set)
    for f in glob.glob(d + '/n8/*_r[0-9].csv'):
        m = re.match(r'(df|tr)_(\w+)_r(\d)\.csv$', os.path.basename(f))
        if not m: continue
        for x in csv.DictReader(open(f)):
            if x['status'] == 'ok':
                ch[(m.group(1), m.group(2), x['arm'])].append(float(x['event_rate']) / 1e6); cnt[m.group(1)].add(int(x['committed']))
    for fn, tgt in (('deva_f5.txt', dv), ('deva.txt', dv), ('ross_f5.txt', ro), ('ross.txt', ro)):
        p = os.path.join(d, fn)
        if not os.path.exists(p): continue
        for l in open(p):
            kv = dict(t.split('=', 1) for t in l.split() if '=' in t)
            if kv.get('nodes') != '8' or kv.get('status') != 'ok' or not kv.get('M_ev_s'): continue
            app = {'traffic': 'tr', 'dragonfly': 'df'}[kv['app']]
            arm = kv['arm'] if fn.startswith('deva') else kv['arm'].split('_', 1)[1]
            tgt[(app, arm)].append(float(kv['M_ev_s'])); cnt[app].add(int(kv['committed']))
    return ch, dv, ro, cnt
a5 = f5load(R8); o5 = f5load(F5)
print('\n# 8 nodes, F5 (this job; F5 in brackets)')
for app, agg in (('df', 'wps512'), ('tr', 'pp2048')):
    out = []
    for ch, dv, ro, cnt in (a5, o5):
        c = smed(ch[(app, agg, 'mb:0')])
        fx = max(smed(v) for (p, g, arm), v in ch.items() if p == app and g == agg and arm.startswith('w:'))
        dw = {k[1]: smed(v) for k, v in dv.items() if k[0] == app}; db = max(dw, key=dw.get)
        rw = {k[1]: smed(v) for k, v in ro.items() if k[0] == app}; rb = max(rw, key=rw.get)
        out.append((c, fx, dw[db], db, rw[rb], rb, cnt[app], dw))
    (c, fx, d, dwb, r, rb, cn, dw), (oc, ofx, od, odwb, orr, orb, ocn, odw) = out
    print('%-9s Charades ctl %.1f [%.1f] (ctl / best fixed %.3f [%.3f]); Devastator %.1f W%s [%.1f W%s]; ROSS %.1f %s [%.1f %s]' % (
        app, c, oc, c / fx, oc / ofx, d, dwb, od, odwb, r, rb, orr, orb))
    print('          C/D %.2f [%.2f]; C/R %.2f [%.2f]; this / F5: C %.3f D %.3f R %.3f; counts one and = F5: %s' % (
        c / d, oc / od, c / r, oc / orr, c / oc, d / od, r / orr, cn == ocn and len(cn) == 1))
    print('          Devastator per W: %s' % '  '.join('W%s %.1f s%.2f' % (w, dw[w], max(a5[1][(app, w)]) / min(a5[1][(app, w)])) for w in sorted(dw, key=int)))

# ---------- check: uniform at 8 nodes alone vs with load
print('\n# Check: uniform at 8 nodes, alone vs with load streams on nodes 9-14 (paired per rep)')
chk = defaultdict(dict)
for l in open(os.path.join(R8, 'n8/deva_chk/results.txt')):
    kv = dict(t.split('=', 1) for t in l.split() if '=' in t)
    m = re.match(r'chk_(alone|load)_w(\d+)_r(\d)$', kv['label'])
    if m and kv['status'] == 'ok': chk[('D W' + m.group(2), int(m.group(3)))][m.group(1)] = float(kv['committed_per_s']) / 1e6
for f in glob.glob(os.path.join(R8, 'n8/chk_*_pp512_r?.csv')):
    m = re.match(r'chk_(alone|load)_pp512_r(\d)\.csv', os.path.basename(f))
    for x in csv.DictReader(open(f)): chk[('C ctl', int(m.group(2)))][m.group(1)] = float(x['event_rate']) / 1e6
for arm in ('D W500', 'D W1000', 'C ctl'):
    v = [(r, chk[(arm, r)]) for r in (1, 2, 3) if len(chk[(arm, r)]) == 2]
    print('  %-8s %s; load / alone median %.3f' % (arm, '  '.join('r%d %.1f / %.1f = %.3f' % (r, x['load'], x['alone'], x['load'] / x['alone']) for r, x in v),
          smed([x['load'] / x['alone'] for _, x in v])))
loads = [l for l in open(os.path.join(R8, 'n4/deva_load/results.txt'))] if os.path.exists(os.path.join(R8, 'n4/deva_load/results.txt')) else []
print('  load runs: Devastator 4-node %d, Charades 2-node %d' % (len(loads), len(glob.glob(os.path.join(R8, 'n2/load_c2_*.csv')))))
alone8 = smed([x for (w, n, W), v in r8dv.items() if w == 'uni' for x, _ in v if W == 1000])
print('  Devastator uniform W 1,000 in phase 1 (same nodes, median): %.1f' % alone8)

# ---------- spread
print('\n# Spread between reps (fastest / slowest), 8-node arms')
sp = []
for k, v in list(r8ch.items()) + list(r8dv.items()) + list(r8ro.items()):
    x = sorted(a for a, _ in v); sp.append((x[-1] / x[0], x[-1] / x[1] if len(x) > 2 else None, k))
for k, v in list(a5[0].items()) + list(a5[1].items()) + list(a5[2].items()):
    x = sorted(v); sp.append((x[-1] / x[0], x[-1] / x[1] if len(x) > 2 else None, k))
print('arms %d; median %.3f; above 1.10: %d' % (len(sp), smed(s for s, _, _ in sp), sum(s > 1.10 for s, _, _ in sp)))
for s, s2, k in sorted(sp, key=lambda t: -t[0])[:12]:
    if s > 1.10: print('  %s %.2f (without the slowest %s)' % (k, s, '%.2f' % s2 if s2 else '-'))

# ---------- exact 8-node ratios for the tables
print('\n# Charades / Devastator at 8 nodes, 3 decimals: this job, F1, change')
for wl in WLS:
    a, o = r8[(wl, 8)], f1[(wl, 8)]
    print('  %-9s %.3f  %.3f  %.3f   C/R %.3f %.3f  uniform count %s' % (wl, a['ctl'] / a['dev'], o['ctl'] / o['dev'], (a['ctl'] / a['dev']) / (o['ctl'] / o['dev']),
          a['ctl'] / a['ross'], o['ctl'] / o['ross'], sorted(a['commits']) if wl == 'uni' else ''))
