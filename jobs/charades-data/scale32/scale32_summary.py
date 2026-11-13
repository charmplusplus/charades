#!/usr/bin/env python3
"""Summary of the paper-grade weak-scaling jobs (charades RESULTS.md sections
141-142): Charades (controller, fixed W), Devastator (best W) and ROSS (best of
optimistic and conservative) per workload and node count.
Usage: scale32_summary.py <job dir> [<job dir> ...]   (e.g. scale32/a_j3653803)"""
import csv, glob, os, re, statistics as st, sys, collections

NAMES = {'g100': 'σ 100', 'g500': 'σ 500', 'g1000': 'σ 1,000', 'g2000': 'σ 2,000',
         'g4000': 'σ 4,000', 'uni': 'uniform', 'l10g500': 'lookahead 10, σ 500',
         'l10g2000': 'lookahead 10, σ 2,000', 'g1000x': 'σ 1,000, Charades only (PP 512 and PP 2,048)'}
ORDER = list(NAMES)
ch = collections.defaultdict(list)    # (wl, N, agg, arm) -> [(rate, committed, eff)]
dv = collections.defaultdict(list)    # (wl, N, W) -> [(rate, committed)]
ro = collections.defaultdict(list)    # (wl, N, mode) -> [(rate, committed)]
bad = []
for d in sys.argv[1:]:
    for ndir in glob.glob(os.path.join(d, 'n*')):
        N = int(os.path.basename(ndir)[1:])
        for f in glob.glob(os.path.join(ndir, '*.csv')):
            m = re.match(r'(\w+?)_(pp\d+|wps\d+)_r(\d)\.csv$', os.path.basename(f))
            if not m: continue
            wl, agg = m.group(1), m.group(2)
            for r in csv.DictReader(open(f)):
                if r['status'] != 'ok': bad.append((f, r['arm'], r['status'])); continue
                ch[(wl, N, agg, r['arm'])].append((float(r['event_rate']) / 1e6, int(r['committed']), float(r['efficiency'])))
        p = os.path.join(ndir, 'deva', 'results.txt')
        if os.path.exists(p):
            for l in open(p):
                kv = dict(x.split('=', 1) for x in l.split() if '=' in x)
                m = re.match(r'(\w+?)_w(\d+)_r\d', kv.get('label', ''))
                if not m: continue
                if kv.get('status') != 'ok': bad.append((p, kv['label'], kv.get('status'))); continue
                dv[(m.group(1), N, int(m.group(2)))].append((float(kv['committed_per_s']) / 1e6, int(kv['committed'])))
        p = os.path.join(ndir, 'ross', 'results.txt')
        if os.path.exists(p):
            for l in open(p):
                kv = dict(x.split('=', 1) for x in l.split() if '=' in x)
                m = re.match(r'(\w+?)_(opt|cons)_r\d', kv.get('label', ''))
                if not m: continue
                if kv.get('rc') != '0' or not kv.get('M_ev_s'): bad.append((p, kv['label'], 'rc ' + kv.get('rc', '?'))); continue
                ro[(m.group(1), N, m.group(2))].append((float(kv['M_ev_s']), int(kv['committed'])))

med = lambda xs: st.median(x[0] for x in xs)
print('runs: Charades %d, Devastator %d, ROSS %d; failed or missing results: %d' % (
    sum(map(len, ch.values())), sum(map(len, dv.values())), sum(map(len, ro.values())), len(bad)))
for b in bad: print('  bad:', b)

summary = {}
for wl in ORDER:
    Ns = sorted({k[1] for k in ch if k[0] == wl})
    if not Ns: continue
    print('\n## %s (M committed ev/s, median of reps; higher is better)' % NAMES[wl])
    print('%3s | %14s %14s | %16s | %16s | %7s %7s | %s' % ('N', 'Charades ctl', 'best fixed W', 'Devastator best', 'ROSS best', 'C÷D', 'C÷R', 'same events'))
    for N in Ns:
        ctl = {a: med(v) for (w, n, a, arm), v in ch.items() if w == wl and n == N and arm.startswith('q')}
        fix = {(a, arm): med(v) for (w, n, a, arm), v in ch.items() if w == wl and n == N and arm.startswith('w')}
        dvs = {W: med(v) for (w, n, W), v in dv.items() if w == wl and n == N}
        ros = {m: med(v) for (w, n, m), v in ro.items() if w == wl and n == N}
        ca = max(ctl, key=ctl.get) if ctl else None
        fa = max(fix, key=fix.get) if fix else None
        db = max(dvs, key=dvs.get) if dvs else None
        rb = max(ros, key=ros.get) if ros else None
        commits = set(c for (w, n, *_), v in list(ch.items()) + list(dv.items()) + list(ro.items())
                      if w == wl and n == N for (_, c, *__) in v)
        summary[(wl, N)] = dict(ctl=ctl.get(ca), fix=fix.get(fa), dev=dvs.get(db), ross=ros.get(rb))
        if not dvs or not ros:
            print('%3d | %s | best fixed W %.1f (%s %s)' % (N, '  '.join('ctl %s %.1f' % (a, v) for a, v in sorted(ctl.items())),
                  fix[fa], fa[0], fa[1]))
            continue
        print('%3d | %7.1f %-6s %7.1f %-6s | %7.1f (W %5s) | %7.1f (%-4s) | %7.2f %7.2f | %s' % (
            N, ctl[ca], ca, fix[fa], fa[1].replace('w:', 'W'), dvs[db], db, ros[rb], rb,
            ctl[ca] / dvs[db], ctl[ca] / ros[rb], 'yes' if len(commits) == 1 else 'NO: %s' % sorted(commits)))
    print('   weak-scaling efficiency (per-node rate ÷ 1-node rate; 1.0 is perfect):')
    for key, name in (('ctl', 'Charades ctl'), ('dev', 'Devastator'), ('ross', 'ROSS')):
        if summary[(wl, Ns[0])][key] is None: continue
        base = summary[(wl, Ns[0])][key] / Ns[0]
        print('     %-13s %s' % (name, '  '.join('%d: %.2f' % (N, summary[(wl, N)][key] / N / base) for N in Ns)))
    # spread of the headline cells
    sp = []
    for N in Ns:
        for (w, n, a, arm), v in ch.items():
            if w == wl and n == N and arm.startswith('q') and len(v) > 1:
                xs = [x[0] for x in v]; sp.append(max(xs) / min(xs))
    if sp: print('   Charades controller rep spread (max ÷ min): up to %.3f' % max(sp))

print('\n## Controller ÷ best fixed W (higher is better)')
for wl in ORDER:
    Ns = sorted({k[1] for k in summary if k[0] == wl})
    if Ns: print('%-24s %s' % (NAMES[wl], '  '.join('%d: %.2f' % (N, summary[(wl, N)]['ctl'] / summary[(wl, N)]['fix']) for N in Ns)))
