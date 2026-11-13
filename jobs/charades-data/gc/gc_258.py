#!/usr/bin/env python3
"""Job GC (charades results/controller.md sections 258-259): the grid check.
Part C: Charades on F4b's six steady workloads at 4 and 16 nodes, a finer
fixed-W grid and the controller. Part D: Devastator on F1's 14 cells at 1-8
nodes over a finer grid, Charades' controller beside it. Rates are M committed
ev/s; medians of 5 reps; higher is better. Ratios across engines are
Charades / Devastator."""
import csv, glob, os, re, statistics as st
from collections import defaultdict
H = os.path.expanduser('~/charades-data/')
GC = H + 'gc/j3694715/'
F4B = H + 'f4/f4b250/j3691176/'
F1 = [H + 'f1/scale240/' + d for d in ('a_j3689004', 'b_j3689513')]
med = st.median

# ---------- loaders
def ch_rows(pattern):
    out = []
    for f in glob.glob(pattern):
        N = int(re.search(r'/n(\d+)/', f).group(1))
        m = re.match(r'(.*)_r(\d)\.csv$', os.path.basename(f))
        for x in csv.DictReader(open(f)):
            x.update(N=N, tag=m.group(1), rep=int(m.group(2)))
            x['rate'] = float(x['event_rate']) / 1e6 if x['status'] == 'ok' else None
            out.append(x)
    return out
def dv_rows(pattern):
    out = []
    for p in glob.glob(pattern):
        N = int(re.search(r'/n(\d+)/', p).group(1))
        for l in open(p):
            kv = dict(t.split('=', 1) for t in l.split() if '=' in t)
            m = re.match(r'(.*)_w(\d+)_r(\d)$', kv['label'])
            if not m: continue
            out.append(dict(N=N, tag=m.group(1), W=int(m.group(2)), rep=int(m.group(3)), status=kv['status'],
                            committed=kv.get('committed'), rate=float(kv['committed_per_s']) / 1e6 if kv['status'] == 'ok' else None))
    return out

gc_ch = ch_rows(GC + 'n*/*_r[0-9].csv')
gc_dv = dv_rows(GC + 'n*/deva_*/results.txt')
bad = [r for r in gc_ch if r['status'] != 'ok'] + [r for r in gc_dv if r['status'] != 'ok']
print('runs: Charades %d, Devastator %d; not ok: %d' % (len(gc_ch), len(gc_dv), len(bad)))

def spread(v): v = [x for x in v if x]; return max(v) / min(v)
lab = lambda a: 'ctl' if a == 'mb:0' else 'W ' + a[2:]
NAME = {'la10': 'lookahead 10, σ 500', 'g100': 'σ 100', 'g2000': 'σ 2,000', 'uni': 'uniform', 'tr': 'traffic', 'df': 'dragonfly',
        'g500': 'σ 500', 'g1000': 'σ 1,000', 'g4000': 'σ 4,000', 'l10g500': 'lookahead 10, σ 500', 'l10g2000': 'lookahead 10, σ 2,000'}

# ---------- part C
F4GRID = {'la10': [25, 50, 100, 300], 'g100': [100, 200, 300, 400], 'g2000': [100, 200, 300, 400], 'uni': [100, 200, 300, 400],
          'tr': [500, 750, 1000], 'df': [10000, 20000, 40000]}
f4 = ch_rows(F4B + 'n*/*_r[0-9].csv')
f4 = [r for r in f4 if not r['tag'].endswith('_old') and r['tag'] != 'warm']
print('\n# Part C: Charades, F4b\'s cells (M committed ev/s, median of 5; spread = fastest / slowest rep)')
counts = []
partc = {}
for N in (4, 16):
    for wl in ('la10', 'g100', 'g2000', 'uni', 'tr', 'df'):
        rows = [r for r in gc_ch if r['N'] == N and r['tag'] == 'c_' + wl]
        arms = sorted({r['arm'] for r in rows}, key=lambda a: (a == 'mb:0', int(a[2:]) if a != 'mb:0' else 0))
        rate = {a: med([r['rate'] for r in rows if r['arm'] == a]) for a in arms}
        rep = lambda a, k: next(r['rate'] for r in rows if r['arm'] == a and r['rep'] == k)
        fixed = [a for a in arms if a != 'mb:0']
        old = [a for a in fixed if int(a[2:]) in F4GRID[wl]]
        best = max(fixed, key=rate.get); bold = max(old, key=rate.get)
        # F4b's definition: per rep, the controller / the best fixed W of that rep (median, range)
        per = [rep('mb:0', k) / max(rep(a, k) for a in fixed) for k in range(1, 6)]
        per_old = [rep('mb:0', k) / max(rep(a, k) for a in old) for k in range(1, 6)]
        f4rows = [r for r in f4 if r['N'] == N and r['tag'] == wl]
        f4fixed = sorted({r['arm'] for r in f4rows if r['arm'].startswith('w:')})
        f4per = [next(r['rate'] for r in f4rows if r['arm'] == 'mb:0' and r['rep'] == k) /
                 max(r['rate'] for r in f4rows if r['arm'] in f4fixed and r['rep'] == k) for k in (1, 2, 3)]
        f4ctl = med([r['rate'] for r in f4rows if r['arm'] == 'mb:0'])
        cnt = {int(r['committed']) for r in rows}; cnt4 = {int(r['committed']) for r in f4rows}
        counts.append((N, wl, cnt == cnt4 and len(cnt) == 1))
        mw = med([float(r['mean_window']) for r in rows if r['arm'] == 'mb:0'])
        partc[(N, wl)] = dict(best=best, bold=bold, gain=rate[best] / rate[bold], ctl_med=rate['mb:0'] / rate[best],
                              per=per, per_old=per_old, f4per=f4per, rate=rate, mw=mw)
        print('\n%s, %d nodes: %s' % (NAME[wl], N, '  '.join('%s %.1f s%.2f' % (lab(a), rate[a], spread([r['rate'] for r in rows if r['arm'] == a])) for a in arms)))
        print('  best %s; best at F4b grid points %s; best / that %.3f; controller mean W %.0f' % (lab(best), lab(bold), rate[best] / rate[bold], mw))
        print('  controller / best fixed: per rep (F4b def) median %.3f (%.3f-%.3f); vs F4b-grid points only %.3f; ratio of medians %.3f; F4b had %.3f (%.3f-%.3f)' % (
            med(per), min(per), max(per), med(per_old), rate['mb:0'] / rate[best], med(f4per), min(f4per), max(f4per)))
        print('  this job / F4b (cross-job): controller %.3f, %s %.3f' % (rate['mb:0'] / f4ctl, lab(bold),
              rate[bold] / med([r['rate'] for r in f4rows if r['arm'] == bold])))
print('\nPart C counts equal to F4b (one per cell):', all(c for *_, c in counts), [c for c in counts if not c[2]])
allper = [med(v['per']) for v in partc.values()]
print('controller / refined best, per-rep definition, medians over cells: %.3f-%.3f' % (min(allper), max(allper)))
print('ratio of medians over cells: %.3f-%.3f' % (min(v['ctl_med'] for v in partc.values()), max(v['ctl_med'] for v in partc.values())))
print('gain of refined grid over F4b points: %.3f-%.3f' % (min(v['gain'] for v in partc.values()), max(v['gain'] for v in partc.values())))

# ---------- part D
def f1_load():
    ch, dv = [], []
    for d in F1:
        for f in glob.glob(d + '/n*/*.csv'):
            N = int(re.search(r'/n(\d+)/', f).group(1))
            m = re.match(r'(\w+?)_(pp\d+|wps\d+)_r(\d)\.csv$', os.path.basename(f))
            if not m: continue
            for x in csv.DictReader(open(f)):
                if x['arm'] == 'mb:0' and x['status'] == 'ok':   # F1's sigma 1,000 PP 512 series is filed as g1000x
                    ch.append(dict(N=N, wl=m.group(1).rstrip('x'), agg=m.group(2), rep=int(m.group(3)), rate=float(x['event_rate']) / 1e6, committed=int(x['committed'])))
        for p in glob.glob(d + '/n*/deva/results.txt'):
            N = int(re.search(r'/n(\d+)/', p).group(1))
            for l in open(p):
                kv = dict(t.split('=', 1) for t in l.split() if '=' in t)
                m = re.match(r'(\w+?)_w(\d+)_r\d', kv.get('label', ''))
                if m and kv.get('status') == 'ok':
                    dv.append(dict(N=N, wl=m.group(1), W=int(m.group(2)), rate=float(kv['committed_per_s']) / 1e6, committed=int(kv['committed'])))
    return ch, dv
f1ch, f1dv = f1_load()
CELLS = ['g100_1', 'g500_1', 'g500_2', 'g1000_1', 'g2000_1', 'g4000_1', 'g4000_2', 'uni_1', 'uni_2', 'uni_4', 'uni_8', 'l10g500_1', 'l10g500_2', 'l10g2000_1']
print('\n# Part D: Devastator\'s grid on F1\'s cells (M committed ev/s, median of 5; spread = fastest / slowest rep)')
partd = {}
for c in CELLS:
    wl, N = c.rsplit('_', 1)[0], int(c.rsplit('_', 1)[1])
    F1G = [100, 200, 400] if wl.startswith('l10') else [500, 1000, 2000]
    dr = [r for r in gc_dv if r['tag'] == 'd_' + c]
    Ws = sorted({r['W'] for r in dr})
    dmed = {w: med([r['rate'] for r in dr if r['W'] == w]) for w in Ws}
    db = max(dmed, key=dmed.get); dold = max([w for w in Ws if w in F1G], key=dmed.get)
    cr = [r for r in gc_ch if r['tag'].startswith('d_' + c + '_')]
    aggs = sorted({r['tag'].split('_')[-1] for r in cr})
    cmed = {a: med([r['rate'] for r in cr if r['tag'].endswith('_' + a)]) for a in aggs}
    ca = max(cmed, key=cmed.get)
    # F1
    f1c = {a: med([r['rate'] for r in f1ch if r['N'] == N and r['wl'] == wl and r['agg'] == a]) for a in {r['agg'] for r in f1ch if r['N'] == N and r['wl'] == wl}}
    f1d = {w: med([r['rate'] for r in f1dv if r['N'] == N and r['wl'] == wl and r['W'] == w]) for w in {r['W'] for r in f1dv if r['N'] == N and r['wl'] == wl}}
    f1ca = max(f1c, key=f1c.get); f1db = max(f1d, key=f1d.get)
    cnt = {int(r['committed']) for r in cr} | {int(r['committed']) for r in dr}
    cnt1 = {r['committed'] for r in f1ch if r['N'] == N and r['wl'] == wl} | {r['committed'] for r in f1dv if r['N'] == N and r['wl'] == wl}
    edge = db in (Ws[0], Ws[-1])
    partd[c] = dict(db=db, dold=dold, gain=dmed[db] / dmed[dold], cd=cmed[ca] / dmed[db], cd_old=cmed[ca] / dmed[dold],
                    f1cd=f1c[f1ca] / f1d[f1db], cvf1=cmed[ca] / f1c[ca], dvf1=dmed[dold] / f1d[dold], edge=edge,
                    counts=(len(cnt) == 1 and cnt == cnt1), ca=ca, f1ca=f1ca)
    print('\n%s, %d node%s: %s' % (NAME[wl], N, 's' if N > 1 else '', '  '.join('W%d %.1f s%.2f' % (w, dmed[w], spread([r['rate'] for r in dr if r['W'] == w])) for w in Ws)))
    print('  Devastator best W %d%s; best at F1 grid points W %d; best / that %.3f' % (db, ' (GRID END)' if edge else '', dold, dmed[db] / dmed[dold]))
    print('  Charades controller %s: %s (better %s; F1 better %s)' % (' '.join('%s %.1f s%.2f' % (a, cmed[a], spread([r['rate'] for r in cr if r['tag'].endswith('_' + a)])) for a in aggs), '', ca, f1ca))
    print('  C/D: this job vs refined best %.3f; vs F1-grid best %.3f; F1 %.3f | this job / F1: Charades ctl %.3f, Devastator W%d %.3f | counts one and = F1: %s' % (
        partd[c]['cd'], partd[c]['cd_old'], partd[c]['f1cd'], partd[c]['cvf1'], dold, partd[c]['dvf1'], partd[c]['counts']))
print('\nPart D: Devastator gain range %.3f-%.3f; C/D (refined) %.3f-%.3f; cells where gain > 1.03: %s; best still at grid end: %s' % (
    min(v['gain'] for v in partd.values()), max(v['gain'] for v in partd.values()),
    min(v['cd'] for v in partd.values()), max(v['cd'] for v in partd.values()),
    [c for c, v in partd.items() if v['gain'] > 1.03], [c for c, v in partd.items() if v['edge']]))
print('Charades ctl this job / F1: %.3f-%.3f; Devastator F1-grid best this job / F1: %.3f-%.3f; counts all one and = F1: %s' % (
    min(v['cvf1'] for v in partd.values()), max(v['cvf1'] for v in partd.values()),
    min(v['dvf1'] for v in partd.values()), max(v['dvf1'] for v in partd.values()), all(v['counts'] for v in partd.values())))

# ---------- spread
print('\n# Spread between reps (fastest / slowest), every arm')
sp = []
for (N, tag, arm), v in sorted(defaultdict(list, {}).items()): pass
grp = defaultdict(list)
for r in gc_ch:
    if not r['tag'].startswith('warm'): grp[('C', r['N'], r['tag'], r['arm'])].append(r['rate'])
for r in gc_dv:
    if not r['tag'].startswith('warm'): grp[('D', r['N'], r['tag'], r['W'])].append(r['rate'])
over = []
for k, v in grp.items():
    s = sorted(v); sp.append(s[-1] / s[0])
    if s[-1] / s[0] > 1.10: over.append((k, s[-1] / s[0], s[-1] / s[1]))
print('arms %d; median spread %.3f; above 1.10: %d' % (len(grp), med(sp), len(over)))
for k, a, b in sorted(over, key=lambda x: -x[1]): print('  %s %.2f (without the slowest %.2f)' % (k, a, b))
