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
        newv = [(g, ev(g)) for g in pending]; nxt = set()
        for g, v in newv:
            if v != val[g]:
                val[g] = v; cnt[g] += 1
                nxt.update(x for x in fan[g] if typ[x] not in ('DFF', 'IN'))
        pending = nxt
    return depth
cnt = [0] * n
propagate(list(range(n)))
cnt = [0] * n
rng = random.Random(7); warm = cycles // 4; depths = []
for c in range(cycles):
    if c == warm: cnt = [0] * n
    changed = []
    newq = [(q, val[ins[q][0]]) for q in dffs]
    for q, v in newq:
        if v != val[q]: val[q] = v; changed.append(q)
    for i in rand_in:
        v = rng.randint(0, 1)
        if v != val[i]: val[i] = v; changed.append(i)
    for g in changed: cnt[g] += 1
    d = propagate(changed)
    if c >= warm: depths.append(d)
meas = cycles - warm
msgs_total = sum(cnt[g] * len(fan[g]) for g in range(n)) / meas
print(f"{f.split('/')[-1]} x {N}: {n} nets ({sum(t not in ('IN',) for t in typ)} gates incl. {N * len(bus)} joining XORs), "
      f"{sum(cnt) / meas / n * 100:.1f}% change per cycle, {msgs_total:.0f} messages per cycle, depth {sum(depths) / len(depths):.0f}")
# ring traffic: messages from one copy into the next
cross_copy = sum(cnt[s] for g in range(xor_base, ext_base) for s in ins[g][1:]) / meas
print(f"  messages per cycle from one copy into the next (all copies): {cross_copy:.0f} ({100 * cross_copy / msgs_total:.2f}% of all)")
# layouts: each node holds 1/s of each of s copies (file order within a copy);
# XORs and external inputs go with the copy they feed
copy_of = [g // C if g < xor_base else ((g - xor_base) // len(bus) if g < ext_base else (g - ext_base) // len(bus)) for g in range(n)]
off_in_copy = [g % C if g < xor_base else 0 for g in range(n)]
pes_per_node = PPN * PEPP
for s in (1, 2, 4):
    if N % s: continue
    def place(g):
        k = copy_of[g]; grp = k // s
        part = off_in_copy[g] * s // C              # which 1/s slice of the copy
        node = grp * s + part
        # within the node, the s slices (one per copy of the group) are laid out
        # one after another; block-map that range over the node's PEs
        slice_lo = part * C // s; slice_len = (part + 1) * C // s - slice_lo
        pos = (k % s) * slice_len + (off_in_copy[g] - slice_lo)
        pe = node * pes_per_node + min(pes_per_node - 1, pos * pes_per_node // (s * slice_len))
        return pe
    pe = [place(g) for g in range(n)]
    tot = xpe = xproc = xnode = 0
    for g in range(n):
        if not cnt[g]: continue
        for d in fan[g]:
            m = cnt[g]; tot += m
            if pe[d] != pe[g]: xpe += m
            if pe[d] // PEPP != pe[g] // PEPP: xproc += m
            if pe[d] // pes_per_node != pe[g] // pes_per_node: xnode += m
    pes = N * pes_per_node
    print(f"  each copy over {s} node(s): per PE {n / pes:6.0f} nets, {tot / meas / pes:6.1f} messages per cycle; "
          f"crossing PEs {100 * xpe / tot:5.1f}%, processes {100 * xproc / tot:5.1f}%, nodes {100 * xnode / tot:5.1f}%")
