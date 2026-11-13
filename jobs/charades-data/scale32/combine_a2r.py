#!/usr/bin/env python3
"""A1a + A1b (1-16 nodes) + A2r (32 nodes): all 8 workloads, 1-32 nodes
(charades RESULTS.md section 153). Charades: its controller, the better htram
setting per node count (sigma 1,000 at 1-16 from A1b's g1000x series)."""
import sys, statistics as st
sys.argv = ['x', 'scale32/a_j3653803', 'scale32/b_j3654651', 'scale32/n32_j3657016']
src = open('scale32_summary.py').read().split("med = lambda")[0]
exec(src)
med = lambda xs: st.median(x[0] for x in xs)
def charades(wl, N):
    v = {a: med(x) for (w, n, a, arm), x in ch.items() if w == wl and n == N and arm.startswith('q')}
    a = max(v, key=v.get); return v[a], a
def best(d, wl, N):
    v = {k: med(x) for (w, n, k), x in d.items() if w == wl and n == N}
    k = max(v, key=v.get); return v[k], k
def fixed(wl, N):
    v = {(a, arm): med(x) for (w, n, a, arm), x in ch.items() if w == wl and n == N and arm.startswith('w')}
    k = max(v, key=v.get); return v[k]
Ns = [1, 2, 4, 8, 16, 32]
WL = ['g100', 'g500', 'g1000', 'g2000', 'g4000', 'uni', 'l10g500', 'l10g2000']
rows = {}
for wl in WL:
    for N in Ns:
        cw = 'g1000x' if (wl == 'g1000' and N < 32) else wl
        c, ca = charades(cw, N); d, dw = best(dv, wl, N); r, rm = best(ro, wl, N)
        rows[(wl, N)] = (c, ca, d, dw, r, rm, fixed(cw, N))
print('| workload | Charades ÷ Devastator at 1 / 2 / 4 / 8 / 16 / 32 nodes | Charades ÷ ROSS | efficiency 16→32, Charades / Devastator / ROSS | efficiency 1→32, C / D / R | M ev/s at 32 nodes, C / D / R | Charades controller ÷ best fixed W at 32 |')
print('|---|---|---|---|---|---|---|')
for wl in WL:
    cd = [rows[(wl, N)][0] / rows[(wl, N)][2] for N in Ns]
    cr = [rows[(wl, N)][0] / rows[(wl, N)][4] for N in Ns]
    e1632 = [rows[(wl, 32)][i] / rows[(wl, 16)][i] / 2 for i in (0, 2, 4)]
    e132 = [rows[(wl, 32)][i] / 32 / rows[(wl, 1)][i] for i in (0, 2, 4)]
    r = rows[(wl, 32)]
    print('| %s | %s | %.2f–%.2f | %.2f / %.2f / %.2f | %.2f / %.2f / %.2f | %.1f / %.1f / %.1f | %.2f |' % (
        NAMES[wl], ' / '.join('%.2f' % x for x in cd), min(cr), max(cr), *e1632, *e132, r[0], r[2], r[4], r[0] / r[6]))
lead = sum(1 for k, v in rows.items() if v[0] > v[2])
print('\nCharades ahead of Devastator in %d of %d cells; at 32 nodes: %d of 8' % (lead, len(rows), sum(1 for wl in WL if rows[(wl, 32)][0] > rows[(wl, 32)][2])))
print('Devastator best W at 32:', {wl: rows[(wl, 32)][3] for wl in WL}, ' ROSS arm at 32:', {wl: rows[(wl, 32)][5] for wl in WL})
