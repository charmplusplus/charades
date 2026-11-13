#!/usr/bin/env python3
"""b19 x N: N copies of an ITC'99 .bench netlist joined in a ring. Copy k's
IN1/IN2 bus bits become XOR(external random input, a bit of copy k-1's
output bus); LOGIC0 pseudo-inputs stay 0; BS/NA/HOLD and the external bus
bits are random each cycle. Unit-delay event-driven simulation; per-gate
output-change counts after warm-up; then, for layouts where each copy is
spread over s nodes (s copies sharing a group of s nodes, each node holding
1/s of each, in file order), the share of messages (output change x fanout)
that cross PEs, processes and nodes, and messages per PE per cycle.
Usage: composed.py file.bench copies cycles"""
import random, re, sys
f, N, cycles = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
PPN, PEPP = 2, 23                                   # processes per node, PEs per process
inputs, outputs, gates = [], [], []
for line in open(f):
    line = line.strip()
    m = re.match(r'INPUT\((.+)\)', line)
    if m: inputs.append(m.group(1)); continue
    m = re.match(r'OUTPUT\((.+)\)', line)
    if m:
        if m.group(1) not in outputs: outputs.append(m.group(1))
        continue
    m = re.match(r'(\S+)\s*=\s*(\w+)\((.*)\)', line)
    if m: gates.append((m.group(1), m.group(2), [x.strip() for x in m.group(3).split(',')]))
bus = [i for i in inputs if i.startswith('IN')]
const = [i for i in inputs if 'LOGIC0' in i]
ctrl = [i for i in inputs if i not in bus and i not in const]
# one copy's nets: its inputs, then its gates in file order
local = inputs + [g for g, _, _ in gates]
lidx = {n: i for i, n in enumerate(local)}
C = len(local)
# composed ids: copy k's net j -> k*C + j; then per copy, one XOR per bus bit
# and one external input per bus bit, appended after all copies
typ, ins = [], []
for k in range(N):
    for n in inputs: typ.append('IN'); ins.append([])
    for g, t, src in gates: typ.append(t); ins.append([k * C + lidx[s] for s in src])
xor_base = N * C
ext_base = xor_base + N * len(bus)
for k in range(N):
    prev = (k - 1) % N
    for b, name in enumerate(bus):
        x = xor_base + k * len(bus) + b
        typ.append('XOR'); ins.append([ext_base + k * len(bus) + b, prev * C + lidx[outputs[b % len(outputs)]]])
for k in range(N):
    for b in range(len(bus)): typ.append('IN'); ins.append([])
# the bus inputs of each copy are now driven by its XOR gates: rewire readers
redirect = {k * C + lidx[name]: xor_base + k * len(bus) + b for k in range(N) for b, name in enumerate(bus)}
ins = [[redirect.get(s, s) for s in src] for src in ins]
n = len(typ)
fan = [[] for _ in range(n)]
for g, src in enumerate(ins):
    for s in src: fan[s].append(g)
dffs = [i for i, t in enumerate(typ) if t == 'DFF']
rand_in = [k * C + lidx[c] for k in range(N) for c in ctrl] + list(range(ext_base, n))
val = [0] * n
def ev(g):
    t = typ[g]; v = [val[s] for s in ins[g]]
    if t == 'AND': return int(all(v))
    if t == 'NAND': return int(not all(v))
    if t == 'OR': return int(any(v))
    if t == 'NOR': return int(not any(v))
    if t == 'NOT': return 1 - v[0]
    if t == 'XOR': return v[0] ^ v[1]
    raise ValueError(t)
def propagate(changed):
    msgs = 0; depth = 0
    pending = {x for g in changed for x in fan[g] if typ[x] not in ('DFF', 'IN')}
    while pending:
        depth += 1
        for g in pending: ecnt[g] += 1
        newv = [(g, ev(g)) for g in pending]; nxt = set()
        for g, v in newv:
            if v != val[g]:
                val[g] = v; cnt[g] += 1
                nxt.update(x for x in fan[g] if typ[x] not in ('DFF', 'IN'))
        pending = nxt
    return depth

cnt = [0] * n; ecnt = [0] * n
propagate(list(range(n)))
cnt = [0] * n; ecnt = [0] * n
rng = random.Random(7); warm = cycles // 4
for c in range(cycles):
    if c == warm: cnt = [0] * n; ecnt = [0] * n
    changed = []
    newq = [(q, val[ins[q][0]]) for q in dffs]
    for q, v in newq:
        if v != val[q]: val[q] = v; changed.append(q)
    for i in rand_in:
        v = rng.randint(0, 1)
        if v != val[i]: val[i] = v; changed.append(i)
    for g in changed: cnt[g] += 1
    propagate(changed)
meas = cycles - warm
pin = [0] * n
for g in range(n):
    for d in fan[g]: pin[d] += cnt[g]
clk = [1 if (typ[g] == 'DFF' or g in set(rand_in)) else 0 for g in range(n)]
load = [(pin[g] + ecnt[g]) / meas + clk[g] for g in range(n)]
tot = sum(load)
print(f"events per cycle (estimate): {tot:.0f}  pin {sum(pin)/meas:.0f} eval {sum(ecnt)/meas:.0f} clock {sum(clk)}")
P = 46
import random as R
def report(name, pe):
    per = [0.0] * P
    for g in range(n): per[pe[g]] += load[g]
    m = tot / P; mx = max(per)
    msgs = x = 0
    for g in range(n):
        if cnt[g]:
            for d in fan[g]:
                msgs += cnt[g]
                if pe[d] != pe[g]: x += cnt[g]
    print(f"{name:28} max/mean {mx/m:5.2f}  mean PE busy if max is 100%: {100*m/mx:5.1f}%  crossing PEs {100*x/msgs:5.1f}%  top-5 PE loads/mean " +
          ' '.join(f"{v/m:.2f}" for v in sorted(per, reverse=True)[:5]))

blk = [min(P - 1, g * P // n) for g in range(n)]
per = [[] for _ in range(P)]
for g in range(n): per[blk[g]].append(g)
for p in sorted(range(P), key=lambda p: -sum(load[g] for g in per[p]))[:3]:
    from collections import Counter
    L = sum(load[g] for g in per[p])
    print(f"PE {p}: load/mean {L / (tot / P):.2f}; types {dict(Counter(typ[g] for g in per[p]).most_common(4))}; clock share {sum(clk[g] for g in per[p]) / L:.2f}")
report("block (file order)", blk)
def contiguous(w):
    W = sum(w); acc = 0; out = []
    for g in range(n):
        out.append(min(P - 1, int(acc * P / W))); acc += w[g]
    return out
report("contiguous, weight = activity", contiguous(load))
report("contiguous, static weight", contiguous([clk[g] * 1.0 + 0.4 * len(ins[g]) + 0.05 * len(fan[g]) for g in range(n)]))
report("contiguous, weight = 1 + clocked", contiguous([1 + 30 * clk[g] for g in range(n)]))
