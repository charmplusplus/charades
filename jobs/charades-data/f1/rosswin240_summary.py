#!/usr/bin/env python3
"""Job RW (charades RESULTS.md sections 240-241): ROSS's optimism window
(--max-opt-lookahead) on F1's eight Gaussian PHOLD workloads, optimistic batch
16 / GVT interval 64, 1 and 4 nodes, 1 rep. Per workload and node count: the
rate without a window, the best window and its rate, and the gain."""
import sys, os
d = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(os.path.abspath(__file__)), 'rosswin240/rosswin_j3688911')
rows = []
for line in open(os.path.join(d, 'results.txt')):
    kv = dict(t.split('=', 1) for t in line.split() if '=' in t)
    rows.append(kv)
WLS = ['g100', 'g500', 'g1000', 'g2000', 'g4000', 'uni', 'l10g500', 'l10g2000']
bad = [r['label'] + ' n' + r['nodes'] for r in rows if r['rc'] != '0' or not r.get('M_ev_s')]
print(f'runs {len(rows)}, failed {len(bad)} {bad}')
# counts: every window commits the same events per workload and node count
for n in ('1', '4'):
    for wl in WLS:
        c = {r['committed'] for r in rows if r['wl'] == wl and r['nodes'] == n}
        if len(c) != 1:
            print(f'COUNT MISMATCH {wl} n{n}: {c}')
print()
print('ROSS optimistic b16/g64; rate in M committed events/s (higher is better);')
print('gain = best window rate / no-window rate (higher is better); efficiency in % committed/executed')
print(f'{"workload":10} {"nodes":>5} {"none M/s":>9} {"eff %":>6} {"best W":>7} {"best M/s":>9} {"eff %":>6} {"gain":>6}   all windows (W: M/s)')
for n in ('1', '4'):
    for wl in WLS:
        rs = [r for r in rows if r['wl'] == wl and r['nodes'] == n]
        none = next(r for r in rs if r['window'] == '0')
        best = max(rs, key=lambda r: float(r['M_ev_s']))
        g = float(best['M_ev_s']) / float(none['M_ev_s'])
        allw = ' '.join(f"{r['window']}:{r['M_ev_s']}" for r in sorted(rs, key=lambda r: int(r['window'])))
        print(f"{wl:10} {n:>5} {none['M_ev_s']:>9} {none['efficiency']:>6} {best['window']:>7} {best['M_ev_s']:>9} {best['efficiency']:>6} {g:6.3f}   {allw}")
