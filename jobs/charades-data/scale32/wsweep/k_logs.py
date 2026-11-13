#!/usr/bin/env python3
"""Job K per-run logs: off-process (htram) share, blocked passes, htram messages per event."""
import glob, re, os, statistics as st, sys, collections
d = sys.argv[1]
def num(txt, key):
    m = re.search(r'^\s*' + re.escape(key) + r'\s+([-\d.]+)', txt, re.M)
    return float(m.group(1)) if m else float('nan')
R = collections.defaultdict(list)
for f in glob.glob(f'{d}/n*/*_r[123]/ctl_sweep/logs/*.out'):
    t = open(f).read()
    n = int(f.split('/n')[1].split('/')[0]); wl = f.split('/')[-4].split('_')[0]
    arm = re.search(r'_(w\d+|q[\d.]+)\.out$', f).group(1)
    com = num(t, 'Events Committed'); ex = num(t, 'Total Events Processed')
    R[(wl, n, arm)].append(dict(
        rate=num(t, 'Event Rate') / 1e6,
        r_all=num(t, 'Remote Sends') / ex,
        r_htram=num(t, 'Events Through htram') / ex,
        mpe=num(t, 'htram Messages') / com * 1000,
        blocked=num(t, 'Batches: Window Blocked') / (num(t, 'Batches: Window Blocked') + num(t, 'Batches: Full')),
        upd=num(t, 'htram Messages: GVT Update') / num(t, 'htram Messages'),
        held=num(t, 'Held Stragglers (late or held by htram)') / com * 1e6,
        waves=num(t, 'Count Reductions'), exec_s=num(t, 'Execution Time')))
order = ['w250', 'w300', 'w400', 'w500', 'w600', 'q0.001']
for wl in ('g100', 'g2000', 'uni'):
    for n in (16, 32):
        print(f'\n== {wl} {n} nodes   r_all  r_htram  htram msgs/1e3 ev  blocked share  GVT-update share  us/wave  advance/wave')
        for a in order:
            v = R[(wl, n, a)]
            if not v: continue
            m = lambda k: st.median(x[k] for x in v)
            usw = st.median(x['exec_s'] / x['waves'] * 1e6 for x in v)
            adv = st.median(2048000 / x['waves'] for x in v)
            print(f"{a:7} {m('r_all'):6.3f} {m('r_htram'):7.4f} {m('mpe'):8.3f} {m('blocked'):10.3f} {m('upd'):10.3f} {usw:8.0f} {adv:8.1f}")
