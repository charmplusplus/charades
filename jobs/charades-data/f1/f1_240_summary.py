#!/usr/bin/env python3
"""F1 on the final defaults (charades RESULTS.md section 240): Gaussian PHOLD,
Charades against Devastator and ROSS, per workload and node count, against the
paper table it replaces (A1/A2r, sections 142-143 and 153).
Charades: its controller (mb:0 now, q:0.001 in A1) at the better htram setting
per node count, and its best fixed W; Devastator: best of its W; ROSS: best of
optimistic, conservative and optimistic with its window (optw<W>).
Usage: f1_240_summary.py <new job dir> [...] -- <old job dir> [...]"""
import csv, glob, os, re, statistics as st, sys, collections

NAMES = {'g100': 'σ 100', 'g500': 'σ 500', 'g1000': 'σ 1,000', 'g2000': 'σ 2,000',
         'g4000': 'σ 4,000', 'uni': 'uniform', 'l10g500': 'lookahead 10, σ 500',
         'l10g2000': 'lookahead 10, σ 2,000', 'g1000x': 'σ 1,000, Charades only (PP 512)'}

def load(dirs):
    ch = collections.defaultdict(list)   # (wl, N, agg, arm) -> [(rate, committed)]
    dv = collections.defaultdict(list)   # (wl, N, W) -> [(rate, committed)]
    ro = collections.defaultdict(list)   # (wl, N, mode) -> [(rate, committed)]
    bad = []
    for d in dirs:
        for ndir in glob.glob(os.path.join(d, 'n*')):
            N = int(os.path.basename(ndir)[1:])
            for f in glob.glob(os.path.join(ndir, '*.csv')):
                m = re.match(r'(\w+?)_(pp\d+|wps\d+)_r(\d)\.csv$', os.path.basename(f))
                if not m: continue
                for r in csv.DictReader(open(f)):
                    if r['status'] != 'ok': bad.append((f, r['arm'], r['status'])); continue
                    ch[(m.group(1), N, m.group(2), r['arm'])].append((float(r['event_rate']) / 1e6, int(r['committed'])))
            p = os.path.join(ndir, 'deva', 'results.txt')
            for l in (open(p) if os.path.exists(p) else []):
                kv = dict(x.split('=', 1) for x in l.split() if '=' in x)
                m = re.match(r'(\w+?)_w(\d+)_r\d', kv.get('label', ''))
                if not m: continue
                if kv.get('status') != 'ok': bad.append((p, kv['label'], kv.get('status'))); continue
                dv[(m.group(1), N, int(m.group(2)))].append((float(kv['committed_per_s']) / 1e6, int(kv['committed'])))
            p = os.path.join(ndir, 'ross', 'results.txt')
            for l in (open(p) if os.path.exists(p) else []):
                kv = dict(x.split('=', 1) for x in l.split() if '=' in x)
                m = re.match(r'(\w+?)_(opt|cons|optw\d+)_r\d', kv.get('label', ''))
                if not m: continue
                if kv.get('rc') != '0' or not kv.get('M_ev_s'): bad.append((p, kv['label'], 'rc ' + kv.get('rc', '?'))); continue
                ro[(m.group(1), N, m.group(2))].append((float(kv['M_ev_s']), int(kv['committed'])))
    return ch, dv, ro, bad

med = lambda xs: st.median(x[0] for x in xs)
is_ctl = lambda arm: arm.startswith('mb') or arm.startswith('q')

def cells(ch, dv, ro):
    out = {}
    for wl, N in sorted({(k[0], k[1]) for k in ch}):
        ctl = {a: med(v) for (w, n, a, arm), v in ch.items() if w == wl and n == N and is_ctl(arm)}
        fix = {(a, arm): med(v) for (w, n, a, arm), v in ch.items() if w == wl and n == N and arm.startswith('w')}
        dvs = {W: med(v) for (w, n, W), v in dv.items() if w == wl and n == N}
        ros = {m: med(v) for (w, n, m), v in ro.items() if w == wl and n == N}
        ca = max(ctl, key=ctl.get); fa = max(fix, key=fix.get)
        db = max(dvs, key=dvs.get) if dvs else None
        rb = max(ros, key=ros.get) if ros else None
        commits = {c for (w, n, *_), v in list(ch.items()) + list(dv.items()) + list(ro.items())
                   if w == wl and n == N for (_, c) in v}
        spread = max(max(x[0] for x in v) / min(x[0] for x in v)
                     for (w, n, a, arm), v in ch.items() if w == wl and n == N and is_ctl(arm) and a == ca)
        out[(wl, N)] = dict(ctl=ctl[ca], ca=ca, fix=fix[fa], fa=fa, dev=dvs.get(db), dw=db, dvs=dvs,
                            ross=ros.get(rb), rm=rb, ros=ros, commits=commits, spread=spread)
    return out

argv = sys.argv[1:]
new_dirs, old_dirs = (argv[:argv.index('--')], argv[argv.index('--') + 1:]) if '--' in argv else (argv, [])
ch, dv, ro, bad = load(new_dirs)
print('runs: Charades %d, Devastator %d, ROSS %d; failed or missing: %d' % (
    sum(map(len, ch.values())), sum(map(len, dv.values())), sum(map(len, ro.values())), len(bad)))
for b in bad: print('  bad:', b)
new = cells(ch, dv, ro)
old = cells(*load(old_dirs)[:3]) if old_dirs else {}

print('\nRates: M committed ev/s, median of reps (higher is better). Ratios: Charades ÷ other (higher is better).')
print('C/D ctl: Charades controller ÷ Devastator best W (as the old table); C/D best: Charades best arm (controller or fixed) ÷ Devastator best.')
print('new/old: this C/D ctl ÷ the old table\'s; C n/o, D n/o, R n/o: that engine\'s rate (Charades: controller) ÷ its own in the old job.')
for wl in NAMES:
    Ns = sorted(N for (w, N) in new if w == wl)
    if not Ns: continue
    print('\n## %s' % NAMES[wl])
    print('%3s | %-16s %-18s %6s | %-13s %-16s | %6s %6s %6s | %6s %7s | %6s %6s %6s | %5s %s' % (
        'N', 'Charades ctl', 'best fixed', 'ctl/fx', 'Devastator', 'ROSS', 'C/D ct', 'C/D bs', 'C/R', 'old', 'new/old',
        'C n/o', 'D n/o', 'R n/o', 'sprd', 'same events'))
    for N in Ns:
        c = new[(wl, N)]
        cb = max(c['ctl'], c['fix'])
        o = old.get((wl if wl != 'g1000x' else 'g1000x', N))
        line = '%3d | %6.1f %-9s %6.1f %-11s %6.3f | %6.1f W%-5s %6.1f %-9s |' % (
            N, c['ctl'], c['ca'], c['fix'], c['fa'][0] + ' ' + c['fa'][1].replace('w:', 'W'), c['ctl'] / c['fix'],
            c['dev'] or 0, c['dw'], c['ross'] or 0, c['rm'])
        if c['dev']:
            line += ' %6.2f %6.2f %6.2f |' % (c['ctl'] / c['dev'], cb / c['dev'], c['ctl'] / c['ross'])
        else:
            line += ' %6s %6s %6s |' % ('', '', '')
        if o and o['dev'] and c['dev']:
            oc = o['ctl'] / o['dev']
            line += ' %6.2f %7.3f | %6.3f %6.3f %6.3f |' % (oc, c['ctl'] / c['dev'] / oc, c['ctl'] / o['ctl'], c['dev'] / o['dev'], c['ross'] / o['ross'])
        else:
            line += ' %6s %7s | %6s %6s %6s |' % ('', '', '', '', '')
        line += ' %5.3f %s' % (c['spread'], 'yes' if len(c['commits']) == 1 else 'NO %s' % sorted(c['commits']))
        print(line)
    if new[(wl, Ns[0])]['dev']:
        print('   per-node rate ÷ 1-node rate (1.0 is perfect):')
        for key, name in (('ctl', 'Charades ctl'), ('dev', 'Devastator'), ('ross', 'ROSS')):
            base = new[(wl, Ns[0])][key] / Ns[0]
            print('     %-13s %s' % (name, '  '.join('%d: %.2f' % (N, new[(wl, N)][key] / N / base) for N in Ns)))
        print('   ROSS arms (M ev/s):', ' | '.join('%d: %s' % (N, ' '.join('%s %.1f' % (m, v) for m, v in sorted(new[(wl, N)]['ros'].items())))
                                                 for N in Ns))

print('\n## Controller ÷ best fixed W (higher is better)')
for wl in NAMES:
    Ns = sorted(N for (w, N) in new if w == wl)
    if Ns: print('%-30s %s' % (NAMES[wl], '  '.join('%d: %.3f' % (N, new[(wl, N)]['ctl'] / new[(wl, N)]['fix']) for N in Ns)))
lead = [(k, v['ctl'] / v['dev']) for k, v in new.items() if v['dev']]
print('\nCharades controller ahead of Devastator in %d of %d cells; lowest %.2f (%s %d nodes)' % (
    sum(1 for k, r in lead if r > 1), len(lead), min(r for k, r in lead), *min(lead, key=lambda x: x[1])[0]))
