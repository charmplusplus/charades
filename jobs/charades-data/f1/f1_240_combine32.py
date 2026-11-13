#!/usr/bin/env python3
"""F1 at 1-32 nodes, all eight PHOLD workloads (charades results/phold.md section
252): F1a + F1b (1-16 nodes, sections 242-243) and F1-32 (32 nodes, 5 reps),
against the table they replace: A1a + A1b (sections 142-143) and A2r (section
153, 32 nodes). Definitions as in f1_240_combine.py: Charades = its controller
at the better htram setting per node count (σ 1,000 also takes the
Charades-only PP 512 series at 1-16 nodes when faster); Devastator = best W;
ROSS = best arm. Medians of reps. Ratios Charades ÷ other, higher is better."""
import os, sys
here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, 'f1_240_summary.py')).read().split('argv = sys.argv[1:]')[0]
exec(src)
H = os.path.expanduser('~/charades-data/')
NEW = [os.path.join(here, 'scale240/' + d) for d in ('a_j3689004', 'b_j3689513', 'big_j3688916')]
OLD = [H + 'scale32/scale32/' + d for d in ('a_j3653803', 'b_j3654651', 'n32_j3657016')]
WLS = ['g100', 'g500', 'g1000', 'g2000', 'g4000', 'uni', 'l10g500', 'l10g2000']
Ns = [1, 2, 4, 8, 16, 32]

def table(dirs):
    c = cells(*load(dirs)[:3])
    rows = {}
    for wl in WLS:
        for N in Ns:
            if (wl, N) not in c: continue
            x = dict(c[(wl, N)])
            if wl == 'g1000' and ('g1000x', N) in c and c[('g1000x', N)]['ctl'] > x['ctl']:
                x['ctl'], x['ca'] = c[('g1000x', N)]['ctl'], c[('g1000x', N)]['ca'] + ' (x)'
            if wl == 'g1000' and ('g1000x', N) in c and c[('g1000x', N)]['fix'] > x['fix']:
                x['fix'] = c[('g1000x', N)]['fix']
            rows[(wl, N)] = x
    return rows
new, old = table(NEW), table(OLD)
r = lambda t, wl, N: t[(wl, N)]['ctl'] / t[(wl, N)]['dev']
best = lambda t, wl, N: max(t[(wl, N)]['ctl'], t[(wl, N)]['fix'])
print('Charades ÷ Devastator (Charades controller ÷ Devastator best W; higher is better), new (old), 1 / 2 / 4 / 8 / 16 / 32 nodes:')
for wl in WLS:
    print('%-24s %s' % (NAMES[wl], ' | '.join('%.2f (%.2f)' % (r(new, wl, N), r(old, wl, N)) for N in Ns)))
print('\nnew ratio ÷ old ratio at 32 nodes:', '  '.join('%s %.3f' % (wl, r(new, wl, 32) / r(old, wl, 32)) for wl in WLS))
print('\n%-24s | %-28s | %-26s | %-26s | %-11s | %s' % ('workload', 'M ev/s at 32: C / D / R', 'per-node 16→32: C / D / R', 'per-node 1→32: C / D / R', 'C÷R 1-32', 'ctl ÷ best fixed at 32'))
c5 = []
for wl in WLS:
    e16 = [new[(wl, 32)][k] / 2 / new[(wl, 16)][k] for k in ('ctl', 'dev', 'ross')]
    e1 = [new[(wl, 32)][k] / 32 / new[(wl, 1)][k] for k in ('ctl', 'dev', 'ross')]
    cr = [new[(wl, N)]['ctl'] / new[(wl, N)]['ross'] for N in Ns]
    b16 = best(new, wl, 32) / 2 / best(new, wl, 16); c5.append((wl, b16))
    print('%-24s | %7.1f / %7.1f / %6.1f | %.2f / %.2f / %.2f | %.2f / %.2f / %.2f | %.2f-%.2f | %.3f' % (
        NAMES[wl], new[(wl, 32)]['ctl'], new[(wl, 32)]['dev'], new[(wl, 32)]['ross'], *e16, *e1, min(cr), max(cr), new[(wl, 32)]['ctl'] / new[(wl, 32)]['fix']))
print('\nC5: Charades per-node rate 16→32, each at its best arm (controller or fixed):', '  '.join('%s %.3f' % x for x in c5))
print('old per-node 16→32 (controller): ', '  '.join('%s %.2f' % (wl, old[(wl, 32)]['ctl'] / 2 / old[(wl, 16)]['ctl']) for wl in WLS))
lead = sum(new[k]['ctl'] > new[k]['dev'] for k in new)
print('\nCharades ahead in %d of %d cells (old: %d of %d)' % (lead, len(new), sum(old[k]['ctl'] > old[k]['dev'] for k in old), len(old)))
x32 = sorted(r(new, wl, 32) for wl in WLS); print('32 nodes: lowest %.2f, median %.3f' % (x32[0], (x32[3] + x32[4]) / 2))
