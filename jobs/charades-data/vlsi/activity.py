#!/usr/bin/env python3
"""Toy unit-delay event-driven simulation of an ITC'99 .bench netlist with
random primary inputs each clock cycle. Measures what a gate-level PDES
workload would carry: per cycle, gate output changes (events that send
messages), messages (output changes x fanout), and the depth of the event
wave (unit-delay steps until quiet). Usage: activity.py file.bench [cycles]"""
import random, re, sys, collections
f = sys.argv[1]; cycles = int(sys.argv[2]) if len(sys.argv) > 2 else 40
inputs, outputs, gates = [], [], {}
for line in open(f):
    line = line.strip()
    if not line or line.startswith('#'): continue
    m = re.match(r'INPUT\((.+)\)', line)
    if m: inputs.append(m.group(1)); continue
    m = re.match(r'OUTPUT\((.+)\)', line)
    if m: outputs.append(m.group(1)); continue
    m = re.match(r'(\S+)\s*=\s*(\w+)\((.*)\)', line)
    if m: gates[m.group(1)] = (m.group(2), [x.strip() for x in m.group(3).split(',')])
names = inputs + list(gates)
idx = {n: i for i, n in enumerate(names)}
typ = [None] * len(inputs) + [gates[n][0] for n in gates]
ins = [[] for _ in inputs] + [[idx[x] for x in gates[n][1]] for n in gates]
fan = [[] for _ in names]
for g, src in enumerate(ins):
    for s in src: fan[s].append(g)
dffs = [i for i, t in enumerate(typ) if t == 'DFF']
val = [0] * len(names)
def ev(g):
    t = typ[g]; v = [val[s] for s in ins[g]]
    if t == 'AND': return int(all(v))
    if t == 'NAND': return int(not all(v))
    if t == 'OR': return int(any(v))
    if t == 'NOR': return int(not any(v))
    if t == 'NOT': return 1 - v[0]
    if t == 'BUFF' or t == 'BUF': return v[0]
    if t == 'XOR': return sum(v) % 2
    if t == 'XNOR': return 1 - sum(v) % 2
    raise ValueError(t)
# settle the combinational logic once from all-zero state
order_changed = set(i for i in range(len(names)) if typ[i] not in (None, 'DFF'))
for _ in range(400):
    nxt = set()
    for g in order_changed:
        nv = ev(g)
        if nv != val[g]: val[g] = nv; nxt.update(x for x in fan[g] if typ[x] != 'DFF')
    order_changed = nxt
    if not nxt: break
rng = random.Random(1)
stats = []
for c in range(cycles):
    # clock edge: flip-flops take their D input; primary inputs change at random
    changed = []
    newq = {q: val[ins[q][0]] for q in dffs}
    for q, v in newq.items():
        if v != val[q]: val[q] = v; changed.append(q)
    for i in range(len(inputs)):
        v = rng.randint(0, 1)
        if v != val[i]: val[i] = v; changed.append(i)
    changes = len(changed); msgs = sum(len(fan[g]) for g in changed); depth = 0
    per_step = []
    pending = set(x for g in changed for x in fan[g] if typ[x] != 'DFF')
    while pending:
        depth += 1; nxt = set(); step_changes = 0
        newvals = [(g, ev(g)) for g in pending]
        for g, nv in newvals:
            if nv != val[g]:
                val[g] = nv; step_changes += 1; msgs += len(fan[g])
                nxt.update(x for x in fan[g] if typ[x] != 'DFF')
        changes += step_changes; per_step.append(step_changes)
        pending = {g for g in nxt}
        if depth > 5000: break
    stats.append((changes, msgs, depth, max(per_step) if per_step else 0))
ng = len(gates); nd = len(dffs)
warm = stats[cycles // 4:]
avg = lambda k: sum(s[k] for s in warm) / len(warm)
print(f"{f.split('/')[-1]}: {ng} gates, {nd} flip-flops, {len(inputs)} inputs; fanout mean {sum(len(x) for x in fan) / len(names):.2f}, max {max(len(x) for x in fan)}")
print(f"per cycle (cycles {cycles // 4}-{cycles - 1}): output changes {avg(0):.0f} ({100 * avg(0) / ng:.1f}% of gates), "
      f"messages {avg(1):.0f}, depth {avg(2):.0f} unit-delay steps, widest step {avg(3):.0f} changes")
for pes, label in ((46, '1 node'), (46 * 32, '32 nodes'), (46 * 256, '256 nodes')):
    print(f"  {label:9} ({pes:5d} PEs): {ng / pes:8.1f} gates per PE, {avg(1) / pes:8.2f} messages per PE per cycle, "
          f"{avg(3) / pes:7.3f} changes per PE in the widest step")
