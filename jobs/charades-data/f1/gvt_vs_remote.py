#!/usr/bin/env python3
"""GVT pace against the share of events sent to another process, Charades and
Devastator, from F1's PHOLD runs (charades results section 255; jobs
3689004, 3689513, 3688916; no new runs). Per GVT advance: wall time (ms),
virtual time advanced, and committed events. Charades: its controller (mb:0)
and its best fixed W at the htram setting F1's table uses ('gvts' = GVT
advances, 'count_waves' = count reductions, 'exec_s'). Devastator: its best
fixed W ('updates' in its window line = GVT advances: global_status.update
runs only when an epoch advances GVT, pdes.cxx:896; 'Wall time', max over
ranks). Medians over reps.
Usage: gvt_vs_remote.py"""
import csv, glob, os, re, statistics as st, collections
g = {}
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'f1_240_summary.py')).read().split('argv = sys.argv[1:]')[0], g)
dirs = ['scale240/a_j3689004', 'scale240/b_j3689513', 'scale240/big_j3688916']
cells = g['cells'](*g['load'](dirs)[:3])
END = {'l10g500': 512000, 'l10g2000': 512000}
ch = collections.defaultdict(list)    # (wl, N, agg, arm) -> rows
for d in dirs:
    for f in glob.glob(f'{d}/n*/*_r[0-9].csv'):
        N = int(f.split('/n')[1].split('/')[0]); m = re.match(r'(\w+?)_(pp\d+|wps\d+)_r\d\.csv', os.path.basename(f))
        if not m: continue
        for r in csv.DictReader(open(f)):
            if r['status'] == 'ok': ch[(m.group(1), N, m.group(2), r['arm'])].append(r)
dv = collections.defaultdict(list)    # (wl, N, W) -> (wall, updates, committed, remote share)
for d in dirs:
    for f in glob.glob(f'{d}/n*/deva/*.out'):
        N = int(f.split('/n')[1].split('/')[0]); m = re.match(r'(\w+?)_w(\d+)_r\d\.out', os.path.basename(f))
        if not m: continue
        t = open(f, errors='replace').read()
        w = re.search(r'Wall time\.+([\d.]+) s', t); u = re.search(r'updates (\d+)', t)
        c = re.search(r'Committed events\.+(\d+)', t); rs = re.search(r'Remote sends\.+\d+ \(([\d.]+)%', t)
        if w and u and c: dv[(m.group(1), N, m.group(2))].append((float(w.group(1)), int(u.group(1)), int(c.group(1)), float(rs.group(1)) if rs else None))
WL = ['g100', 'g500', 'g1000', 'g2000', 'g4000', 'uni', 'l10g500', 'l10g2000']
def cstats(rows):
    ms = st.median(float(r['exec_s']) / float(r['gvts']) * 1e3 for r in rows)
    vt = st.median(END.get(wl, 2048000) / float(r['gvts']) for r in rows)
    ev = st.median(float(r['committed']) / float(r['gvts']) for r in rows)
    wv = st.median(float(r['count_waves']) / float(r['gvts']) for r in rows)
    sh = st.median(float(r['htram_events']) / (float(r['committed']) + float(r['rolled_back'])) for r in rows) if rows[0]['htram_events'] else None
    return ms, vt, ev, wv, sh
for N in (1, 4, 16, 32):
    print(f'\n## {N} nodes. Per GVT advance: wall ms | virtual time | committed events (k). Charades at its controller and at its best fixed W (waves per advance); Devastator at its best W')
    print(f"{'workload':9} {'remote%':>7} | {'C ctl: ms':>9} {'vt':>6} {'kev':>6} | {'C fixed W':>9} {'ms':>6} {'vt':>6} {'waves':>5} | {'D W':>6} {'ms':>6} {'vt':>6} {'kev':>6} {'D rem%':>6} | {'ms D/C':>6}")
    for wl in WL:
        c = cells[(wl, N)]; agg = c['ca'].split()[0]
        rc = ch[(wl, N, agg, 'mb:0')]; fa = c['fa']; rf = ch[(wl, N, fa[0], fa[1])]
        if not rc or not rf: continue
        ms, vt, ev, wv, sh = cstats(rc); fms, fvt, fev, fwv, _ = cstats(rf)
        dw = c['dw']; rd = dv[(wl, N, str(dw))]
        if not rd: print(wl, 'no Devastator outputs'); continue
        dms = st.median(w / u * 1e3 for w, u, _, _ in rd); dvt = st.median((END.get(wl, 2048000)) / u for _, u, _, _ in rd)
        dev = st.median(cm / u for _, u, cm, _ in rd); drem = st.median(x for *_, x in rd if x is not None)
        print(f"{wl:9} {sh * 100 if sh else float('nan'):6.1f}% | {ms:9.3f} {vt:6.1f} {ev / 1e3:6.1f} | {fa[1]:>9} {fms:6.3f} {fvt:6.1f} {fwv:5.2f} | {dw:>6} {dms:6.3f} {dvt:6.1f} {dev / 1e3:6.1f} {drem:5.1f}% | {dms / ms:6.2f}")
