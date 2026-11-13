#!/usr/bin/env python3
"""Job RA (charades RESULTS.md section 233): where Charades' cost of running
ahead goes on VLSI. Settings D (VS2's), G (--gvt-wave-events=0), E
(--fossil-lazy=0), GE (both), B8 (--batch=8, W 5,000 only) at W 2,500 / 3,750 /
5,000; 4 and 16 nodes; reps r1-r3 untraced, t traced (--gvt-trace=5).

Usage: rahead233_summary.py <job dir>   (e.g. ~/charades-data/vlsi/rahead233/j3686450)
"""
import csv, glob, gzip, os, statistics as st, sys

D = sys.argv[1]
CYC = 5000
SETS = ['D', 'G', 'E', 'GE', 'B8']
WS = [2500, 3750, 5000]
REPS = ['r1', 'r2', 'r3']


def arms():
    for s in SETS:
        for w in WS:
            if s == 'B8' and w != 5000:
                continue
            yield s, w


def row(N, rep, s, w):
    f = os.path.join(D, f'n{N}', rep, f'{s}_w{w}.csv')
    if not os.path.exists(f):
        return None
    r = list(csv.DictReader(open(f)))
    return r[0] if len(r) == 1 else None


def pes(N, rep, s, w):
    f = os.path.join(D, f'n{N}', rep, f'{s}_w{w}', 'ctl_sweep', 'pe_stats.csv')
    if not os.path.exists(f):
        return []
    out = []
    for r in csv.DictReader(open(f)):
        out.append({k: float(v) for k, v in r.items()})
    return out


def parts(N, rep, s, w, pe):
    f = os.path.join(D, f'n{N}', rep, f'{s}_w{w}', 'ctl_sweep', f'exec_parts_{pe}.csv')
    if not os.path.exists(f):
        return None
    r = list(csv.DictReader(open(f)))
    return {k: float(v) for k, v in r[0].items()} if r else None


def rec(N, rep, s, w, pe):
    f = os.path.join(D, f'n{N}', rep, f'{s}_w{w}', 'ctl_sweep', f'gvt_rec_{pe}.csv.gz')
    if not os.path.exists(f):
        return []
    return list(csv.DictReader(gzip.open(f, 'rt')))


def med(x):
    return st.median(x) if x else None


def f2(x, d=2):
    return '—' if x is None else f'{x:.{d}f}'


def rng(x, d=2):
    x = [v for v in x if v is not None]
    if not x:
        return '—'
    lo, hi = min(x), max(x)
    return f'{lo:.{d}f}' if f'{lo:.{d}f}' == f'{hi:.{d}f}' else f'{lo:.{d}f}–{hi:.{d}f}'


def least_blocked(p):
    return min(p, key=lambda r: r['blocked_s'] / r['total_s']) if p else None


for N in (4, 16):
    print(f'\n######## {N} nodes')
    # ---- counts and digests
    cnt, dig, bad = set(), set(), []
    for rep in REPS + ['t']:
        for s, w in arms():
            r = row(N, rep, s, w)
            if r is None:
                bad.append(f'{rep} {s} W{w} missing'); continue
            if r['status'] != 'ok':
                bad.append(f"{rep} {s} W{w} {r['status']}"); continue
            cnt.add(r['committed']); dig.add(r['digest'])
    print(f'counts {sorted(cnt)}; digests {sorted(dig)}' + (f'; NOT OK: {bad}' if bad else ''))

    # ---- run time
    print('\n| setting | W | run time (s), r1 / r2 / r3 (lower is better) | ÷ D at W 2,500, run time (above 1: slower) | D ÷ this setting at the same W, run time (above 1: this setting is faster) | rolled back (M), median | least-blocked PE waiting at the window (%), range |')
    print('|---|---|---|---|---|---|---|')
    for s, w in arms():
        t = [row(N, rep, s, w) for rep in REPS]
        e = [float(r['exec_s']) if r and r['status'] == 'ok' else None for r in t]
        base = [row(N, rep, 'D', 2500) for rep in REPS]
        same = [row(N, rep, 'D', w) for rep in REPS]
        rb = [float(r['rolled_back']) / 1e6 for r in t if r and r['status'] == 'ok']
        bm = [float(r['blocked_min_pct']) for r in t if r and r['status'] == 'ok']
        vs25 = [x / float(b['exec_s']) for x, b in zip(e, base) if x and b]
        vsD = [float(d['exec_s']) / x for x, d in zip(e, same) if x and d]
        print(f"| {s} | {w} | {' / '.join(f2(x) for x in e)} | {rng(vs25, 3)} | {rng(vsD, 3) if s != 'D' else '—'} | {f2(med(rb), 1)} | {rng(bm, 1)} |")

    # ---- per PE, all reps
    print('\n**Per PE** (median over r1–r3 unless noted; per cycle; node = process):')
    print('| setting | W | least-blocked PE: id (node), r1 / r2 / r3 | its waiting share (%) | its working time (ms per cycle) | its events executed per cycle | its events rolled back per cycle | node 2 mean executed per PE per cycle | busiest PE on node 2 ÷ node 2 mean (executed) | least-blocked PE ÷ node 2 mean (executed) | other nodes: mean executed per PE per cycle |')
    print('|---|---|---|---|---|---|---|---|---|---|---|')
    for s, w in arms():
        ids, wait, work, ex, rb, n2m, n2x, lbr, oth = [], [], [], [], [], [], [], [], []
        for rep in REPS:
            p = pes(N, rep, s, w)
            if not p:
                continue
            lb = least_blocked(p)
            ids.append(f"{int(lb['pe'])} ({int(lb['process'])})")
            wait.append(100 * lb['blocked_s'] / lb['total_s'])
            work.append(1e3 * (lb['total_s'] - lb['blocked_s']) / CYC)
            ex.append(lb['executed'] / CYC)
            rb.append(lb['rolled_back'] / CYC)
            n2 = [r['executed'] for r in p if int(r['process']) == 2]
            ot = [r['executed'] for r in p if int(r['process']) != 2]
            n2m.append(st.mean(n2) / CYC); n2x.append(max(n2) / st.mean(n2))
            lbr.append(lb['executed'] / st.mean(n2)); oth.append(st.mean(ot) / CYC)
        print(f"| {s} | {w} | {' / '.join(ids)} | {f2(med(wait), 1)} | {f2(med(work), 3)} | {f2(med(ex), 0)} | {f2(med(rb), 0)} | {f2(med(n2m), 0)} | {f2(med(n2x), 2)} | {f2(med(lbr), 2)} | {f2(med(oth), 0)} |")

    # ---- node 2's PEs: distribution of waiting share and rollbacks, D at 2,500 vs 5,000, r1
    print('\n**Node 2, D, rep 1:** waiting share (%) and rolled back per cycle, PEs sorted by executed (top 8):')
    for w in WS:
        p = [r for r in pes(N, 'r1', 'D', w) if int(r['process']) == 2]
        p.sort(key=lambda r: -r['executed'])
        print(f'  W {w}: ' + '; '.join(f"pe {int(r['pe'])} ex {r['executed']/CYC:.0f} rb {r['rolled_back']/CYC:.0f} wait {100*r['blocked_s']/r['total_s']:.1f}%" for r in p[:8]))
        allp = pes(N, 'r1', 'D', w)
        rbn2 = sum(r['rolled_back'] for r in p); rball = sum(r['rolled_back'] for r in allp)
        print(f'         node 2 holds {100*rbn2/rball:.0f}% of all rolled-back events ({rball/1e6:.2f} M); node 2 waiting share median {st.median([100*r["blocked_s"]/r["total_s"] for r in p]):.1f}%, others {st.median([100*r["blocked_s"]/r["total_s"] for r in allp if int(r["process"]) != 2]):.1f}%')

    # ---- traced rep: the least-blocked PE's time split
    print('\n**Traced rep (t): the least-blocked PE, µs per cycle** (exec_parts; `execute()` = exec_s from pe_stats; outside = total − exec_s):')
    cols = ['loop_s', 'send_total_s', 'drain_s', 'poll_s', 'cancel_q_s', 'iter_end_s', 'rollback_s', 'fossil_s', 'flush_idle_s']
    print('| setting | W | PE (node) | total | waiting | in `execute()` | outside `execute()` | ' + ' | '.join(c[:-2] for c in cols) + ' | executed / rolled back per cycle | loop µs per executed event | passes per cycle |')
    print('|---|---|---|---|---|---|---|' + '---|' * len(cols) + '---|---|---|')
    for s, w in arms():
        p = pes(N, 't', s, w)
        if not p:
            continue
        lb = least_blocked(p); pe = int(lb['pe'])
        x = parts(N, 't', s, w, pe)
        if not x:
            continue
        u = lambda v: f'{1e6 * v / CYC:.0f}'
        print(f"| {s} | {w} | {pe} ({int(lb['process'])}) | {u(lb['total_s'])} | {u(lb['blocked_s'])} | {u(lb['exec_s'])} | {u(lb['total_s'] - lb['exec_s'])} | "
              + ' | '.join(u(x[c]) for c in cols)
              + f" | {lb['executed']/CYC:.0f} / {lb['rolled_back']/CYC:.0f} | {1e6 * x['loop_s'] / lb['executed']:.2f} | {x['passes']/CYC:.0f} |")
    # same split for node 2's mean PE and for the other nodes' mean PE, D only
    print('\n  Node means, D, traced (µs per cycle: total / waiting / loop / drain / rollback / fossil / outside execute(); executed per cycle):')
    for w in WS:
        p = pes(N, 't', 'D', w)
        for lab, sel in (('node 2', lambda r: int(r['process']) == 2), ('others', lambda r: int(r['process']) != 2)):
            q = [r for r in p if sel(r)]
            xs = [parts(N, 't', 'D', w, int(r['pe'])) for r in q]
            xs = [x for x in xs if x]
            m = lambda k: 1e6 * st.mean(x[k] for x in xs) / CYC
            mp = lambda k: 1e6 * st.mean(r[k] for r in q) / CYC
            print(f"    W {w} {lab}: {mp('total_s'):.0f} / {mp('blocked_s'):.0f} / {m('loop_s'):.0f} / {m('drain_s'):.0f} / {m('rollback_s'):.0f} / {m('fossil_s'):.0f} / {mp('total_s') - mp('exec_s'):.0f}; executed {st.mean(r['executed'] for r in q)/CYC:.0f}, rolled back {st.mean(r['rolled_back'] for r in q)/CYC:.0f}")

    # ---- count-wave contributions of the least-blocked PE
    print('\n**Count waves, the least-blocked PE (traced; every 4th wave):** reasons (0 at once, 1 starved, 2 after K events, 3 K already reached), median µs pickup→contribution, median events in between')
    for s, w in arms():
        p = pes(N, 't', s, w)
        if not p:
            continue
        pe = int(least_blocked(p)['pe'])
        r = rec(N, 't', s, w, pe)
        if not r:
            print(f'  {s} W{w}: pe {pe}: no gvt_rec'); continue
        rs = {}
        for x in r:
            rs[x['reason']] = rs.get(x['reason'], 0) + 1
        print(f"  {s} W{w}: pe {pe}: {len(r)} waves; reasons {dict(sorted(rs.items()))}; contrib_us median {st.median(float(x['contrib_us']) for x in r):.1f}; events median {st.median(float(x['events']) for x in r):.0f}")
