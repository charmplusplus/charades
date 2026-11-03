#!/usr/bin/env python3
"""Where each cycle's wall time goes along its chain of dependent events.

Reads the event_trace_<pe>.bin files of a run with --event-trace-from/-to
(records: src/simcore/event.h, EtraceRecord). Wall times are comparable only
between PEs of one process: trace runs with one process per node, on 1 node.

For each period [c*P, (c+1)*P) inside the traced range, the committed event of
that period whose final execution ends last is followed back through the
events that sent it, up to --back periods before. Each hop parent -> child
splits into
  send     the parent's forward from its start to the send
  transit  send -> the child entering the receiver's pending heap
  queue    in the heap -> the child's final execution starts
  exec     the last event's own forward
and transit and queue are split again by what the receiving PE did meanwhile:
  later    executing events with a later timestamp than the child
  earlier  executing events with an earlier or equal timestamp
  pass     inside a scheduler pass that executed events, not executing
  blocked  in passes that executed nothing, held by the optimism window
  empty    in passes that executed nothing and were not blocked
  outside  between passes (runtime scheduling, messages, GVT, fossils)

Usage: event_trace.py DIR [--period 2500] [--back 1] [--cycles N]
"""
import argparse
import bisect
import glob
import os
import re
import struct
import sys
from collections import defaultdict

REC = struct.Struct('<d5Q2I')
SEND, RECV, EXEC, ROLLBACK, PASS, GVT = range(6)
NONE = (1 << 64) - 1
CATS = ['later', 'earlier', 'pass', 'blocked', 'empty', 'outside']


def load(d):
    files = sorted(glob.glob(os.path.join(d, 'event_trace_*.bin')),
                   key=lambda f: int(re.search(r'_(\d+)\.bin$', f).group(1)))
    if not files:
        sys.exit('no event_trace_*.bin in ' + d)
    send, recv, execs, rbs, gvts = {}, {}, defaultdict(list), defaultdict(int), []
    pe_exec = []    # per PE: sorted (start, end, ts)
    pe_pass = []    # per PE: sorted (start, end, blocked, n)
    for f in files:
        pe = int(re.search(r'_(\d+)\.bin$', f).group(1))
        ex, ps = [], []
        for wall, ts, src, eid, x, y, kind, aux in REC.iter_unpack(open(f, 'rb').read()):
            k = (src, eid)
            if kind == EXEC:
                execs[k].append((wall, wall + x * 1e-9, pe, ts))
                ex.append((wall, wall + x * 1e-9, ts))
            elif kind == SEND:
                send[k] = (wall, (x, y), ts)
            elif kind == RECV:
                recv[k] = (wall, pe)
            elif kind == ROLLBACK:
                rbs[k] += 1
            elif kind == PASS:
                ps.append((wall, wall + x * 1e-9, y, aux, ts))
            elif kind == GVT and pe == 0:
                gvts.append((wall, ts))
        while len(pe_exec) <= pe:
            pe_exec.append([]); pe_pass.append([])
        ex.sort(); ps.sort()
        pe_exec[pe], pe_pass[pe] = ex, ps
    return send, recv, execs, rbs, gvts, pe_exec, pe_pass


def overlap(iv, a, b, pred=None):
    """Total overlap of [a, b] with the sorted intervals iv (start, end, ...)."""
    t = 0.0
    i = bisect.bisect_left(iv, (a,)) - 1
    i = max(i, 0)
    while i < len(iv) and iv[i][0] < b:
        s, e = iv[i][0], iv[i][1]
        if e > a and (pred is None or pred(iv[i])):
            t += min(e, b) - max(s, a)
        i += 1
    return t


def split(pe_exec, pe_pass, pe, a, b, ts):
    """What PE pe did during [a, b], by CATS (seconds)."""
    out = dict.fromkeys(CATS, 0.0)
    if b <= a:
        return out
    ex, ps = pe_exec[pe], pe_pass[pe]
    out['later'] = overlap(ex, a, b, lambda r: r[2] > ts)
    out['earlier'] = overlap(ex, a, b, lambda r: r[2] <= ts)
    busy_pass = overlap(ps, a, b, lambda r: r[3] > 0)
    out['pass'] = max(busy_pass - out['later'] - out['earlier'], 0.0)
    out['blocked'] = overlap(ps, a, b, lambda r: r[3] == 0 and r[2] == 1)
    out['empty'] = overlap(ps, a, b, lambda r: r[3] == 0 and r[2] == 0)
    out['outside'] = max((b - a) - sum(out.values()), 0.0)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('dir')
    ap.add_argument('--period', type=int, default=2500)
    ap.add_argument('--back', type=int, default=1, help='periods to follow a chain back')
    ap.add_argument('--cycles', type=int, default=0, help='at most this many periods (0: all)')
    a = ap.parse_args()
    send, recv, execs, rbs, gvts, pe_exec, pe_pass = load(a.dir)
    P = a.period
    committed = {k: v[-1] for k, v in execs.items() if len(v) > rbs.get(k, 0)}
    tss = [v[3] for v in committed.values()]
    lo, hi = min(tss) // P, max(tss) // P
    print(f'{len(pe_exec)} PEs; {len(committed)} committed events traced '
          f'({sum(len(v) for v in execs.values())} executions, {sum(rbs.values())} rollbacks); '
          f'periods {lo}-{hi} of {P}')
    # GVT crossings (PE 0's view): when GVT first reached each period boundary
    cross = {}
    for w, g in gvts:
        c = g // P
        for cc in range(lo, c + 1):
            cross.setdefault(cc, w)
    by_period = defaultdict(list)
    for k, v in committed.items():
        by_period[v[3] // P].append((v[1], k))
    tot = defaultdict(float)
    tot_chain = tot_cycle = 0.0
    n = 0
    hdr = ('period', 'cycle_ms', 'chain_ms', 'hops', 'reexec', 'send', 'transit', 'queue', 'exec') + tuple(CATS)
    print(' '.join(f'{h:>8}' for h in hdr))
    # skip the first and last periods: chains there leave the traced range
    for c in range(lo + a.back, hi):
        if a.cycles and n >= a.cycles:
            break
        end, k = max(by_period[c])
        acc = defaultdict(float)
        hops = reexec = 0
        root_start = committed[k][0]
        acc['exec'] += committed[k][1] - committed[k][0]
        while True:
            s = send.get(k)
            if s is None or s[1][0] == NONE:
                break
            pk = s[1]
            pv = committed.get(pk)
            r = recv.get(k)
            if pv is None or r is None or pv[3] < (c - a.back) * P:
                break
            ek = committed[k]
            send_w, (recv_w, rpe) = s[0], r
            acc['send'] += max(send_w - pv[0], 0.0)
            acc['transit'] += max(recv_w - send_w, 0.0)
            acc['queue'] += max(ek[0] - recv_w, 0.0)
            for cat, v in split(pe_exec, pe_pass, rpe, send_w, ek[0], ek[3]).items():
                acc[cat] += v
            reexec += len(execs[k]) > 1
            hops += 1
            root_start = pv[0]
            k = pk
        chain = end - root_start
        cyc = cross.get(c + 1, 0) - cross.get(c, 0) if (c in cross and c + 1 in cross) else float('nan')
        row = [c, cyc * 1e3, chain * 1e3, hops, reexec] + [acc[x] * 1e3 for x in
               ('send', 'transit', 'queue', 'exec')] + [acc[x] * 1e3 for x in CATS]
        print(' '.join(f'{v:>8}' if isinstance(v, int) else f'{v:>8.3f}' for v in row))
        for x in acc:
            tot[x] += acc[x]
        tot_chain += chain
        tot_cycle += cyc if cyc == cyc else 0
        n += 1
    if n:
        print(f'\nmean over {n} periods: cycle {tot_cycle / n * 1e3:.3f} ms (GVT crossings, PE 0), '
              f'chain {tot_chain / n * 1e3:.3f} ms')
        for x in ('send', 'transit', 'queue', 'exec') + tuple(CATS):
            print(f'  {x:8} {tot[x] / n * 1e3:8.3f} ms  {tot[x] / tot_chain * 100:5.1f}% of the chain')


if __name__ == '__main__':
    main()
