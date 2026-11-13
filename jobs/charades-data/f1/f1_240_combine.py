#!/usr/bin/env python3
"""F1a + F1b combined, 1-16 nodes, all eight PHOLD workloads (charades RESULTS.md
section 243), against A1a + A1b combined the same way (section 143). Charades:
its controller at the better htram setting per node count; σ 1,000 also takes
the Charades-only series (g1000x: PP 512 in F1, PP 512 and PP 2,048 in A1) when
it is faster. Devastator: best W; ROSS: best arm."""
import os, sys
here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, 'f1_240_summary.py')).read().split('argv = sys.argv[1:]')[0]
exec(src)
H = os.path.expanduser('~/charades-data/')
NEW = [os.path.join(here, 'scale240/a_j3689004'), os.path.join(here, 'scale240/b_j3689513')]
OLD = [H + 'scale32/scale32/a_j3653803', H + 'scale32/scale32/b_j3654651']
WLS = ['g100', 'g500', 'g1000', 'g2000', 'g4000', 'uni', 'l10g500', 'l10g2000']
Ns = [1, 2, 4, 8, 16]

def table(dirs):
    c = cells(*load(dirs)[:3])
    rows = {}
    for wl in WLS:
        for N in Ns:
            x = dict(c[(wl, N)])
            if wl == 'g1000' and ('g1000x', N) in c and c[('g1000x', N)]['ctl'] > x['ctl']:
                x['ctl'], x['ca'] = c[('g1000x', N)]['ctl'], c[('g1000x', N)]['ca'] + ' (x)'
            rows[(wl, N)] = x
    return rows

new, old = table(NEW), table(OLD)
print('Charades ÷ Devastator (Charades controller ÷ Devastator best W; higher is better), new (old):')
for wl in WLS:
    print('%-24s %s' % (NAMES[wl], ' | '.join('%.2f (%.2f)' % (new[(wl, N)]['ctl'] / new[(wl, N)]['dev'], old[(wl, N)]['ctl'] / old[(wl, N)]['dev']) for N in Ns)))
print('\nnew ratio ÷ old ratio:')
rs = []
for wl in WLS:
    r = [(new[(wl, N)]['ctl'] / new[(wl, N)]['dev']) / (old[(wl, N)]['ctl'] / old[(wl, N)]['dev']) for N in Ns]; rs += r
    print('%-24s %s' % (NAMES[wl], '  '.join('%.3f' % x for x in r)))
print('in 1.10-1.30: %d of %d; range %.3f-%.3f' % (sum(1.10 <= x <= 1.30 for x in rs), len(rs), min(rs), max(rs)))
print('\nσ 1,000 Charades setting per node count:', '  '.join('%d: %s %.1f' % (N, new[('g1000', N)]['ca'], new[('g1000', N)]['ctl']) for N in Ns))
print('\n%-24s | %-28s | %-22s | %-12s | %s' % ('workload', 'M ev/s at 16: C / D / R', 'per-node 16÷1: C / D / R', 'C÷R 1-16', 'ctl ÷ best fixed 1-16'))
for wl in WLS:
    e = [new[(wl, 16)][k] / 16 / new[(wl, 1)][k] for k in ('ctl', 'dev', 'ross')]
    cr = [new[(wl, N)]['ctl'] / new[(wl, N)]['ross'] for N in Ns]
    cf = [new[(wl, N)]['ctl'] / new[(wl, N)]['fix'] for N in Ns]
    print('%-24s | %6.1f / %6.1f / %6.1f | %.2f / %.2f / %.2f | %.2f-%.2f | %.3f-%.3f' % (
        NAMES[wl], new[(wl, 16)]['ctl'], new[(wl, 16)]['dev'], new[(wl, 16)]['ross'], *e, min(cr), max(cr), min(cf), max(cf)))
lead = sum(new[k]['ctl'] > new[k]['dev'] for k in new)
print('\nCharades ahead in %d of %d cells (old: %d)' % (lead, len(new), sum(old[k]['ctl'] > old[k]['dev'] for k in old)))
