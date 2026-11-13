#!/usr/bin/env python3
"""Job R16 (charades RESULTS.md section 156), part B: where process 0's extra
time goes in sigma 2,000's start-up ramp.
Usage: r16_perf.py <perf script .gz (tid time: sym)> <the run's log>

The clock start is the first sample in an event handler or the scheduler's
execute(). Windows: start = the first 0.75 s after it, steady = 2-5 s. Each
symbol's samples are divided by the simulated time the run advanced in the
window (from the time-stamped progress lines), so a symbol whose cost per
unit of simulated time does not change contributes no excess. Excess = what
the start's samples exceed the steady rate times the start's simulated time.
"""
import gzip, re, sys
from collections import Counter, defaultdict

script, log = sys.argv[1], sys.argv[2]
LINE = re.compile(r'^\s*(\d+)\s+([\d.]+):\s+[0-9a-f]+\s+(.*?)\s*$')
S = []
for l in gzip.open(script, 'rt', errors='replace'):
    m = LINE.match(l)
    if m: S.append((int(m.group(1)), float(m.group(2)), m.group(3)))
S.sort(key=lambda x: x[1])
START_SYMS = ('execute_me', '::forward', 'Scheduler::execute')
t0 = next(t for _, t, sym in S if any(k in sym for k in START_SYMS))
pts = [(0.0, 0)]
for l in open(log):
    m = re.match(r'GVT\s+\d+:\s+(\d+) \(.*\), [\d.]+ MB, ([\d.]+) s', l)
    if m: pts.append((float(m.group(2)), int(m.group(1))))
def simt(a, b):
    """simulated time advanced between wall times a and b (s after the clock start), interpolated"""
    def at(t):
        for (ta, va), (tb, vb) in zip(pts, pts[1:]):
            if ta <= t <= tb: return va + (vb - va) * (t - ta) / max(1e-9, tb - ta)
        return pts[-1][1]
    return at(b) - at(a)
W = {'start': (0.0, 0.75), 'steady': (2.0, 5.0)}
cnt = {k: Counter() for k in W}; thr = {k: Counter() for k in W}
for tid, t, sym in S:
    r = t - t0
    for k, (a, b) in W.items():
        if a <= r < b:
            cnt[k][sym] += 1; thr[k][tid] += 1
st = {k: simt(*W[k]) for k in W}
tot = {k: sum(cnt[k].values()) for k in W}
print('clock start at perf time %.3f; samples %d; threads %d' % (t0, len(S), len({x[0] for x in S})))
for k in W:
    print('  %-6s %.2f-%.2f s: %d samples, simulated time %d, samples per 1,000 units %.1f' % (k, W[k][0], W[k][1], tot[k], st[k], 1e3 * tot[k] / st[k]))
excess_total = tot['start'] - tot['steady'] / st['steady'] * st['start']
print('  extra samples in the start window: %.0f (%.0f%% of its samples)\n' % (excess_total, 100 * excess_total / tot['start']))
ex = {}
for sym in set(cnt['start']) | set(cnt['steady']):
    rs, rt = cnt['start'][sym] / st['start'], cnt['steady'][sym] / st['steady']
    ex[sym] = ((rs - rt) * st['start'], rs / rt if rt else float('inf'), cnt['start'][sym], cnt['steady'][sym])
print('%8s %6s %8s %8s  %s' % ('excess', 'ratio', 'start', 'steady', 'symbol (top 30 by excess samples; ratio = per unit simulated time, start / steady)'))
for sym, (e, r, a, b) in sorted(ex.items(), key=lambda x: -x[1][0])[:30]:
    print('%8.0f %6.2f %8d %8d  %s' % (e, r, a, b, sym[:110]))
doubled = sum(e for e, r, a, b in ex.values() if r >= 2 and e > 0)
print('\nsymbols at least 2x per unit simulated time hold %.0f of %.0f extra samples (%.0f%%)' % (doubled, excess_total, 100 * doubled / excess_total))
print('\nthreads (top 8 by excess):')
tx = {t: thr['start'][t] - thr['steady'][t] / st['steady'] * st['start'] for t in set(thr['start']) | set(thr['steady'])}
for t, e in sorted(tx.items(), key=lambda x: -x[1])[:8]:
    print('  tid %d: excess %.0f (start %d, steady %d)' % (t, e, thr['start'][t], thr['steady'][t]))
