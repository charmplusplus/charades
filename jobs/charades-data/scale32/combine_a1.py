#!/usr/bin/env python3
"""A1a + A1b combined, 1-16 nodes, all 8 workloads (charades RESULTS.md
section 143). Charades: its controller, the better htram setting per node
count; for sigma 1,000 from A1b's Charades-only series (g1000x)."""
import sys, statistics as st
sys.argv = ['x', 'scale32/a_j3653803', 'scale32/b_j3654651']
src = open('scale32_summary.py').read().split("med = lambda")[0]
exec(src)
med = lambda xs: st.median(x[0] for x in xs)
def charades(wl, N):
    v = {a: med(x) for (w, n, a, arm), x in ch.items() if w == wl and n == N and arm.startswith('q')}
    a = max(v, key=v.get); return v[a], a
def best(d, wl, N):
    v = {k: med(x) for (w, n, k), x in d.items() if w == wl and n == N}
    k = max(v, key=v.get); return v[k], k
Ns = [1, 2, 4, 8, 16]
print('A1a PP 2,048 controller vs A1b PP 2,048 controller at sigma 1,000 (allocation check):')
for N in Ns:
    a = med(ch[('g1000', N, 'pp2048', 'q:0.001')]); b = med(ch[('g1000x', N, 'pp2048', 'q:0.001')])
    print('  %2d nodes: %.1f vs %.1f (%.3f)' % (N, a, b, b / a))
rows = {}
for wl in ['g100', 'g500', 'g1000', 'g2000', 'g4000', 'uni', 'l10g500', 'l10g2000']:
    cw = 'g1000x' if wl == 'g1000' else wl
    for N in Ns:
        c, ca = charades(cw, N); d, dw = best(dv, wl, N); r, rm = best(ro, wl, N)
        rows[(wl, N)] = (c, ca, d, dw, r, rm)
print('\n%-22s %s | %s | %s' % ('workload', 'Charades / Devastator at 1/2/4/8/16', 'Charades / ROSS', 'efficiency 1->16, C / D / R; Charades 16n'))
for wl in ['g100', 'g500', 'g1000', 'g2000', 'g4000', 'uni', 'l10g500', 'l10g2000']:
    cd = [rows[(wl, N)][0] / rows[(wl, N)][2] for N in Ns]
    cr = [rows[(wl, N)][0] / rows[(wl, N)][4] for N in Ns]
    eff = [rows[(wl, 16)][i] / 16 / rows[(wl, 1)][i] for i in (0, 2, 4)]
    print('%-22s %s | %.2f-%.2f | %.2f / %.2f / %.2f; %.1f (%s), D %.1f (W %s), R %.1f (%s)' % (
        NAMES[wl], ' / '.join('%.2f' % x for x in cd), min(cr), max(cr), *eff,
        rows[(wl, 16)][0], rows[(wl, 16)][1], rows[(wl, 16)][2], rows[(wl, 16)][3], rows[(wl, 16)][4], rows[(wl, 16)][5]))
print('\nsigma 1,000 corrected per node count (Charades better setting / Devastator / ROSS):')
for N in Ns:
    c, ca, d, dw, r, rm = rows[('g1000', N)]
    print('  %2d: %.1f (%s) / %.1f / %.1f -> C/D %.2f, C/R %.2f, eff C %.2f' % (N, c, ca, d, r, c / d, c / r, c / N / rows[('g1000', 1)][0]))
lead = sum(1 for k, v in rows.items() if v[0] > v[2])
print('\nCharades ahead of Devastator in %d of %d cells' % (lead, len(rows)))
