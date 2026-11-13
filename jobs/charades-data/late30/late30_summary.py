#!/usr/bin/env python3
"""Summary of job late30 (charades RESULTS.md section 138): held stragglers and
throughput for base / --agg-flush-ahead / --diag-window-lag-ns, from each run's log.
Usage: late30_summary.py <job dir>"""
import glob, os, re, statistics as st, sys, collections

d = sys.argv[1]
KEYS = ['Event Rate', 'Efficiency', 'Events Committed', 'Events Rolled Back',
        'Held Stragglers (late or held by htram)', 'Events Through htram',
        'htram Messages', 'htram Messages: GVT Update', 'htram Messages: Flush Ahead',
        'htram Messages: Urgent Event', 'htram Messages: Buffer Full',
        'Total GVT Computations', 'Held Stragglers, at a PE blocked at its window']
DT = ['0-5', '5-10', '10-20', '20-50', '50-100', '100+']
OFF = ['below', '0-8', '8-16', '16-32', '32-64', '64+']
KEYS += ['Held Stragglers, us after its GVT ' + b for b in DT]
KEYS += ['Held Stragglers, past previous horizon ' + b for b in OFF]

def parse(f):
    r = {}
    for l in open(f, errors='replace'):
        m = re.match(r'\s*(.+?)\s+(-?[\d.]+(?:e[+-]?\d+)?)\s*$', l)
        if m and m.group(1).strip() in KEYS:
            r[m.group(1).strip()] = float(m.group(2))
    return r if 'Event Rate' in r and 'Simulation Executed Successfully' in open(f, errors='replace').read() else None

cells = collections.defaultdict(list)   # (part, wl, agg, variant) -> [run dicts]
bad = []
for tagdir in sorted(glob.glob(os.path.join(d, '[ABCD]_*_r[0-9]'))):
    tag = os.path.basename(tagdir)
    m = re.match(r'([ABCD])_(base|ahead1|ahead|lag)_?(pp512|pp2048cap|pp2048)?_r(\d)', tag)
    if not m: continue
    part, v, agg, rep = m.groups()
    for f in glob.glob(os.path.join(tagdir, 'ctl_sweep', 'logs', '*.out')):
        b = os.path.basename(f)
        wl = 'uniform' if 'steady' in b else 'sigma ' + re.search(r'gauss_100_1000_(\d+)', b).group(1)
        a = agg or re.search(r'_(wps\d+|pp\d+)_', b).group(1)
        r = parse(f)
        if r is None: bad.append(f); continue
        cells[(part, wl, a, v)].append(r)

def med(rs, k): return st.median(r.get(k, 0.0) for r in rs)
def tot(rs, k): return sum(r.get(k, 0.0) for r in rs)

print('runs ok: %d; failed or unparsed: %d' % (sum(len(v) for v in cells.values()), len(bad)))
for f in bad: print('  bad:', f)
print()
print('Throughput and held stragglers (median of reps; ratio = variant / base; held removed = 1 - held/base held)')
print('%-4s %-11s %-7s %-6s %3s %8s %6s %7s %10s %8s %8s %9s %9s' % (
    'part', 'workload', 'agg', 'var', 'n', 'Mev/s', 'ratio', 'eff%', 'held', 'held%', 'removed', 'msg/kev', 'msg ratio'))
order = {'A': 0, 'B': 1, 'C': 2, 'D': 3}
for key in sorted(cells, key=lambda k: (order[k[0]], k[1], k[2], ["base", "ahead", "ahead1", "lag"].index(k[3]))):
    part, wl, a, v = key
    rs = cells[key]; base = cells.get((part, wl, a, 'base'))
    rate = med(rs, 'Event Rate') / 1e6
    held = med(rs, 'Held Stragglers (late or held by htram)')
    com = med(rs, 'Events Committed')
    mpk = 1e3 * med(rs, 'htram Messages') / com
    if base:
        brate = med(base, 'Event Rate') / 1e6
        bheld = med(base, 'Held Stragglers (late or held by htram)')
        bmpk = 1e3 * med(base, 'htram Messages') / med(base, 'Events Committed')
        ratio = '%.3f' % (rate / brate); rem = '%.1f%%' % (100 * (1 - held / bheld)) if bheld else '-'
        mr = '%.3f' % (mpk / bmpk)
    else:
        ratio = rem = mr = '-'
    print('%-4s %-11s %-7s %-6s %3d %8.1f %6s %7.2f %10.0f %8.4f %8s %9.2f %9s' % (
        part, wl, a, v, len(rs), rate, ratio, med(rs, 'Efficiency'), held, 100 * held / com, rem, mpk, mr))

print()
print('Held stragglers by when and where they arrived (base arms, summed over reps; shares of held stragglers)')
print('%-4s %-11s %-7s %-6s %9s | %s | %s | %s' % ('part', 'workload', 'agg', 'var', 'held',
      ' '.join('%6s' % b for b in DT), ' '.join('%6s' % b for b in OFF), 'blocked'))
for key in sorted(cells, key=lambda k: (order[k[0]], k[1], k[2], ["base", "ahead", "ahead1", "lag"].index(k[3]))):
    rs = cells[key]
    h = sum(tot(rs, 'Held Stragglers, us after its GVT ' + b) for b in DT)
    if not h: continue
    dt = [tot(rs, 'Held Stragglers, us after its GVT ' + b) / h for b in DT]
    off = [tot(rs, 'Held Stragglers, past previous horizon ' + b) / h for b in OFF]
    bl = tot(rs, 'Held Stragglers, at a PE blocked at its window') / h
    print('%-4s %-11s %-7s %-6s %9.0f | %s | %s | %6.2f' % (key[0], key[1], key[2], key[3], h,
          ' '.join('%6.2f' % x for x in dt), ' '.join('%6.2f' % x for x in off), bl))
    # F1 summaries
    print('%49s within 50 us %.2f; at most 32 past %.2f; below %.2f' % ('', sum(dt[:4]), sum(off[1:4]), off[0]))

print()
print('htram messages by cause per GVT update (median)')
for key in sorted(cells, key=lambda k: (order[k[0]], k[1], k[2], ["base", "ahead", "ahead1", "lag"].index(k[3]))):
    rs = cells[key]; g = med(rs, 'Total GVT Computations')
    print('%-4s %-11s %-7s %-6s gvt-update %7.1f  ahead %7.1f  urgent %7.1f  full %7.1f' % (key + (
        med(rs, 'htram Messages: GVT Update') / g, med(rs, 'htram Messages: Flush Ahead') / g,
        med(rs, 'htram Messages: Urgent Event') / g, med(rs, 'htram Messages: Buffer Full') / g)))
