# The engine: GVT, rollback and per-event cost

What paces the bucketed GVT at scale, rollback depth and unit, the same-process fast path, and the rounds that closed Charades' per-event gap to Devastator. Part of the Charades results: the current paper tables are on the front page, [../RESULTS.md](../RESULTS.md), and every section's date, job, status and file is in [INDEX.md](INDEX.md). Sections keep the numbers (§N) they had in the single RESULTS.md they came from (split 2026-11-07); "section N" anywhere means §N.

| § | date | status | section |
|---|---|---|---|
| 46 | 2026-10-24 | design | GVT round cost at 4 and 16 nodes |
| 47 | 2026-10-24 | current | GVT round cost at 4 and 16 nodes, results |
| 48 | 2026-10-24 | current | Where a reduction's time goes, one node |
| 49 | 2026-10-24 | design | GVT count waves combined per process, `--gvt-node-waves` |
| 50 | 2026-10-24 | current | GVT count waves combined per process, results |
| 51 | 2026-10-24 | design | The cross-process part of a GVT advance: allreduce by recursive doubling |
| 52 | 2026-10-24 | current | The cross-process part of a GVT advance, results |
| 53 | 2026-10-24 | design | What makes a process late to a count wave: batch size and wave holding |
| 54 | 2026-10-24 | current | What makes a process late to a count wave, results |
| 55 | 2026-10-24 | design | Which PE is slow, and why |
| 56 | 2026-10-24 | current | Which PE is slow, and why, results |
| 59 | 2026-10-24 | design | Count waves that ask about every bucket up to the window |
| 60 | 2026-10-24 | current | Count waves that ask about every bucket up to the window, results |
| 61 | 2026-10-24 | design | Same-process events by pointer (`--local-fast-path`) |
| 62 | 2026-10-24 | current | Same-process events by pointer, results |
| 63 | 2026-10-24 | design | Where the fast path loses at σ 2,000, and with WPs |
| 64 | 2026-10-24 | current | Where the fast path loses at σ 2,000, and with WPs, results |
| 79 | 2026-10-25 | design | Where a GVT advance's time goes at scale; PP 2,048's allocation vs its limit; the horizon margin |
| 80 | 2026-10-25 | current | Where a GVT advance's time goes at scale; PP 2,048's allocation vs its limit; the horizon margin, results |
| 83 | 2026-10-25 | design | Where a wider window's cost goes, on a clean allocation |
| 84 | 2026-10-25 | current | Where a wider window's cost goes, on a clean allocation, results: the slowest process is usually late becau… |
| 104 | 2026-10-26 | design | Why one PE holds up each GVT advance at uniform and σ 2,000: per-PE wave records, and fewer events per wave |
| 105 | 2026-10-26 | current | Per-PE wave records, results: at uniform the late PE is slowed by receiving many small messages; `--gvt-wav… |
| 106 | 2026-10-26 | design | `--gvt-wave-events` 32 / 64 / 128 at 1, 4 and 16 nodes; what an htram receive costs |
| 107 | 2026-10-26 | current | Wave events and receive cost, results: 128 stays; a receive's fixed cost is its input buffer pushes, which… |
| 115 | 2026-10-27 | design | What paces GVT at σ 2,000: events in transit or the late PE's work; GVT bucket size; horizon margin with wi… |
| 116 | 2026-10-27 | superseded in part (120) | What paces GVT at σ 2,000, results: neither transit nor a growing straggler; the cross-process reduction (3… |
| 117 | 2026-10-27 | design | Where the cross-process reduction's 70 µs goes: Charades' own process tree with per-hop times; a flat tree;… |
| 118 | 2026-10-27 | current | Where the reduction's time goes, results: a hop's network time is about 4 µs; the rest is waiting for a PE… |
| 119 | 2026-10-27 | design | Shorter scheduler passes only while a count wave is in flight (`--wave-batch`) |
| 120 | 2026-10-27 | superseded in part (121) | `--wave-batch`, results: the floor falls by 27 µs but the advance does not; the floor was never on the crit… |
| 125 | 2026-10-27 | design | Uniform's steady loss: thinner htram messages or more destinations? A buffer-size perturbation on 4 nodes |
| 126 | 2026-10-27 | current | Uniform's buffer perturbation, results: thinning explains only 16% of the loss; 45% is inside `execute()`,… |
| 127 | 2026-10-28 | design | Splitting `execute()` on uniform at 4 and 16 nodes, against σ 4,000 as a control |
| 128 | 2026-10-28 | current | `execute()` split, results: on uniform the event handlers and sends do not grow; half of `execute()`'s rise… |
| 131 | 2026-10-28 | design | Is applying a GVT result on uniform's critical path? A known delay in that step, and its parts |
| 132 | 2026-10-28 | current | The GVT-result step, results: on 16 nodes it is fully on the critical path, and the GVT-time flush is 97% o… |
| 145 | 2026-10-29 | design | Why Charades rolls back more than Devastator at the same window |
| 146 | 2026-10-29 | current | Why Charades rolls back more than Devastator at the same window, results: not the hold; Charades' own engin… |
| 147 | 2026-10-29 | design | The rollback unit: LPs per chare at lookahead 100 and wide W |
| 148 | 2026-10-29 | current | The rollback unit, results: one LP per chare cuts rollbacks 5–23× and beats Devastator's at σ 2,000 and uni… |
| 151 | 2026-10-29 | design | Per-LP rollback inside a chare, `--rollback-unit=1` |
| 152 | 2026-10-29 | current | Per-LP rollback inside a chare, results: 1 LP per chare's rollbacks at no cost; the held deadline is a new… |
| 203 | 2026-11-03 | design | Closing the gap: where Charades' per-event and per-pass time goes, and the first changes |
| 204 | 2026-11-03 | current | Closing the gap, round 1: skipping the empty cancel-queue walk (2.36× on one PE), committing fossils lazily… |
| 210 | 2026-11-03 | design | Closing the gap, round 2: no network polling in one-process runs, and several scheduler passes per `execute… |
| 211 | 2026-11-03 | current | Closing the gap, round 2 results: neither change moves the rate (no network poll 1.00, `--pass-loop` 1.01);… |
| 213 | 2026-11-03 | design | Closing the gap, round 3: the engine's work per event |
| 215 | 2026-11-03 | current | Closing the gap, round 3 results: 1.64× at one process per node (37.6 → 61.8 M ev/s, 1.35× Devastator's bes… |
| 9 | 2026-10-20 | historical | Two speeds of the bucketed GVT |
| 10 | 2026-10-21 | historical | Two GVT speeds: cause and fix |
| 23 | 2026-10-21 | superseded | Profile: where Charades spends its time against Devastator |
| 24 | 2026-10-21 | historical | Per-event fast paths |

## Current

Current findings, and designs with their results, in the order they were written.

### §46 · GVT round cost at 4 and 16 nodes (design, 2026-10-24; written before any runs)

> **Status: design.** Written before any runs.

**Why.** At W 250 every run needs about 8,300 GVT advances at any node count, and they slow from about 175 µs each at 4 nodes to 260 µs at 16 and 355 µs at 32; a wider window does not hide it (window sweep, 16 nodes). An advance is made of count waves: every PE contributes a tuple reduction (sent and received counts per bucket, plus the minimum buckets passed), the result is broadcast, and each PE contributes the next wave when it handles the result. A wave's time is therefore the reduction itself plus how late the slowest PE answers. This splits the two.

**Setup.** One skx-dev job, 16 nodes, 30 min: `$WORK/charades-runs/gvtprobe/gvtprobe.slurm`, output in `$WORK/charades-runs/gvtprobe/`. Full-node layout and psm2 as in every recent run.
- **A. Reduction alone**: `tools/redbench` (new; charades repo) runs back-to-back waves shaped like the GVT's (8 buckets: a 16-int sum plus an int minimum, result broadcast to the group, next wave on receipt), 20,000 waves after 1,000 warm-up, at 1, 2, 4, 8 and 16 nodes, 2 reps. It reports time per wave and PE 0's contribute-to-result latency (median, p90, p99). On the Mac (2 processes × 2 PEs) it takes 67 µs per wave.
- **B. Waves in Charades**: `--gvt-trace=1` (PE 0 records each wave's start and end, buckets asked, completed; every PE's time in `execute()`), σ 100 and σ 2,000 at W 250 and W 400, 4 and 16 nodes, 2 reps.
- **C. One knob**: 16 nodes, σ 2,000, W 400, `--gvt-wave-events` 0 (contribute at once) against the default 128, 2 reps.

**Predictions:**
- G1. The reduction alone takes 30–80 µs per wave at 1–4 nodes and grows by at most 2× to 16 nodes.
- G2. In Charades, a wave takes 2–4× the reduction alone at the same node count, and the excess (PEs answering late) accounts for most of the growth in wave time from 4 to 16 nodes.
- G3. Buckets completed per wave, and waves per GVT advance, are about the same at 4 and 16 nodes.
- G4. `--gvt-wave-events=0` changes the 16-node rate by less than 10%.

### §47 · GVT round cost at 4 and 16 nodes, results (2026-10-24, batch job 3635612 on skx-dev)

> **Status: current.**

**Runs.** `$WORK/charades-runs/gvtprobe/gvtprobe.slurm`; outputs, traces and CSVs copied to `~/charades-data/gvtprobe/`; summary `probe_summary.py`. Every run finished; the two reps agree within 4%.

**A. The reduction alone** (`tools/redbench`, µs per back-to-back wave, median of 2; lower is better):

| nodes (PEs) | 1 (46) | 2 (92) | 4 (184) | 8 (368) | 16 (736) |
|---|---|---|---|---|---|
| µs per wave | 71.8 | 98.7 | 109.3 | 139.9 | 161.5 |
| PE 0's latency, median / p99 (µs) | 70 / 88 | 95 / 123 | 104 / 141–432 | 130 / 484 | 142 / 514 |

**B. Waves in Charades** (`--gvt-trace=1`; medians of 2; each row is one run's medians):

| run | M ev/s | GVT advances | waves per advance | µs per advance (mean) | wave seen by PE 0, median µs | PE 0's delay before contributing, median µs | buckets completed per wave | time in `execute()` % | batches blocked by the window % |
|---|---|---|---|---|---|---|---|---|---|
| 4 nodes, σ 100, W 250 | 121.9 | 8,342 | 1.00 | 178 | 72 | 90 | 7.7 | 60 | 94 |
| 4 nodes, σ 2,000, W 250 | 100.7 | 8,333 | 1.00 | 216 | 73 | 121 | 7.7 | 56 | 95 |
| 4 nodes, σ 2,000, W 400 | 98.1 | 7,030 | 1.00 | 262 | 160 | 51 | 9.1 | 56 | 95 |
| 16 nodes, σ 100, W 250 | 333.8 | 8,278 | 1.00 | 262 | 187 | 7 | 7.7 | 57 | 97 |
| 16 nodes, σ 100, W 400 | 408.9 | 5,781 | 1.00 | 306 | 214 | 11 | 11.1 | 62 | 95 |
| 16 nodes, σ 2,000, W 250 | 292.9 | 8,306 | 1.00 | 297 | 198 | 9 | 7.7 | 55 | 97 |
| 16 nodes, σ 2,000, W 400 | 331.6 | 5,756 | 1.00 | 379 | 243 | 17 | 11.1 | 57 | 96 |

**C.** 16 nodes, σ 2,000, W 400: `--gvt-wave-events=0` 326.4 against 331.6 M ev/s with the default 128 (0.98): no effect.

**What it says:**
- **Every GVT advance is one count wave**, completing about 7.7 buckets at W 250 at both node counts, and 95–97% of scheduler batches end blocked by the window. PEs spend 55–62% of their time in `execute()`; the rest is mostly waiting for GVT.
- **At 16 nodes, a GVT advance is the reduction's latency.** PE 0 answers each wave within 7–17 µs, then waits 187–243 µs for the result, close to the reduction alone at 16 nodes (162 µs; more under load). At 4 nodes the reduction is partly hidden: PE 0 is still finishing a batch for 90–121 µs before it contributes, and then waits only 72 µs.
- **The reduction is slow even inside one node**: 72 µs for 46 PEs in 2 processes. A spanning tree over 46 PEs is about 3 levels up and 3 down, so this is roughly 12 µs per hop through Reconverse's scheduler and messaging. It then grows by about 20 µs per doubling of nodes.
- **So the lever for scale is reduction latency in Reconverse** (or a GVT path that doesn't go through a general group reduction): if a wave took 30–50 µs at 16 nodes, an advance would take roughly 100 µs instead of 260–300, and PEs that now sit blocked by the window 97% of the time would run. That estimate assumes nothing else becomes the limit.

**Predictions:**
- G1. **Wrong** on the level (72–162 µs, not 30–80); right that it grows by at most 2× from 4 to 16 nodes (1.48×).
- G2. **Wrong.** At 16 nodes a wave is 1.2–1.5× the reduction alone, and PE 0 answers at once; the growth is the reduction, not PEs answering late. At 4 nodes PE 0's late answer (90–121 µs) is as large as the wave.
- G3. Right: one wave per advance and 7.7 buckets per wave at W 250 at both node counts.
- G4. Right: 0.98.

### §48 · Where a reduction's time goes, one node (2026-10-24, skx-dev batch job 3635622, plus the Mac)

> **Status: current.** No design section: a short diagnostic follow-up to "GVT round cost", run the same morning. A larger follow-up (job 3635628: reduction modes, PEs per process, 4 and 16 nodes, `perf`) never ran: the job was killed at startup (signal 53, no output) while `/work2` hung on skx-dev compute nodes (an `ssh node hostname` to a fresh allocation also hung).

**Runs.** `tools/redbench` gained a ping-pong mode (`-p PEER`: round trips of a one-int group message between PE 0 and PE PEER) and reduction modes (`-m`: 0 the GVT's tuple, 1 one int, 2 the 16-int array). `$WORK/charades-runs/gvtprobe/hop.slurm`; copied to `~/charades-data/gvtprobe/hop/`. One skx node, psm2, `+lci_ndevices 16`; 2 reps, which agree within 4% except one noted. The first launch of the job (one process, rep 1) stalled at startup for 120 s; its rep 2 ran normally.

**Message hops** (round trip, µs, mean of 100,000; lower is better):

| | round trip |
|---|---|
| 1 process × 23 PEs, PE 0 ↔ PE 1 | 2.11 |
| 2 processes × 23 PEs, PE 0 ↔ PE 1 (same process) | 2.96–3.02 |
| same, `+backend_poll_thread 23` (one network poller per process) | 2.75–2.86 |
| same, `+backend_poll_freq 1` | 2.59–2.63 |
| same, `+lci_ndevices 1` | 3.12–3.23 |
| 2 processes, PE 0 ↔ PE 23 (other process, same node) | 9.18–9.19 (median 7.63) |

**Reductions shaped like a GVT count wave** (µs per wave; lower is better):

| | µs per wave |
|---|---|
| 2 processes × 1 PE | 7.1–7.2 |
| 1 process × 23 PEs | 26.5–26.9 |
| 2 processes × 23 PEs | 71.0–71.4 |
| same, `+backend_poll_thread 23` | 72.3, 79.7 |
| same, `+backend_poll_freq 1` | 71.0–72.4 |

On the Mac (one process, 8 PEs): the GVT's tuple 7.9 µs per wave, one int 5.1, the 16-int array without a tuple 5.3. On the Mac with 2 processes everything is slow (a same-process round trip 27 µs against 0.6 with one process): every PE's loop spends about half its time in libfabric tcp's `kevent` progress call; that is the Mac's tcp provider, not what Stampede3's psm2 does.

**What it says:**
- **Message hops are cheap on Stampede3**: about 1.5 µs within a process and 4–5 µs between the two processes of a node; network polling settings change neither.
- **The reduction's cost is its shape.** Charm++'s group reduction (`CkReductionMgr::init_TopoTree`) is flat within a process: every PE but the first sends its contribution straight to the process's first PE, which receives and combines 22 messages one after another. The result comes back through Reconverse's `CmiForwardMsgToPeers`, also flat: the first PE allocates and sends one copy per local PE (22 `CmiAlloc` + `memcpy` + push; its own comment: "FIXME: now it's just a flat p2p send!! When node size is large, it should also be sent in a tree"). That is about 44 serial message operations on one PE per wave per process, about 1.2 µs each: 26.5 µs for one process of 23 PEs.
- **Two processes cost far more than one plus a hop** (71 µs against 26.5 + 7). Not yet explained; the profile that would have shown it is in the job that did not run.
- In Charades the first PE of each process is also executing events, so its 44 operations per wave wait behind its batches.
- **The GVT's tuple adds about half on top of a plain sum** (Mac, 8 PEs), which Charades can avoid on its own.

**Fixes, in order of reach:** (1) Charades: combine each process's counts in shared memory (atomic adds into a per-process buffer; the last PE in contributes once per process) and publish the result through shared memory, so the cross-process reduction has 2 members per node instead of 46 and no PE handles 44 messages per wave; drop the tuple. (2) Reconverse: a tree for the local fan-out (the FIXME), and a node-aware local fan-in in Charm++'s reduction manager. (1) needs no runtime change.

### §49 · GVT count waves combined per process, `--gvt-node-waves` (design, 2026-10-24; written before any code or runs)

> **Status: design.** Written before any code or runs.

**Why.** At 16 nodes a GVT advance is one count wave and takes about as long as the reduction under it ("GVT round cost"), and that reduction is slow because of its shape ("Where a reduction's time goes"): each process's first PE receives and combines 22 contributions, then allocates and sends 22 copies of the result, one after another, and the GVT's tuple message adds about half again. Charades can avoid all of it without runtime changes, the way `--agg-input-buffer` already avoids per-PE htram messages.

**Design** (`--gvt-node-waves=1`; bucketed GVT only; off under `--sched-park`, like `--agg-input-buffer`, since parked PEs do not poll):
1. **Contribute into shared memory.** A new nodegroup `NodeWaves` holds, per process, one slot per PE and an arrival counter. A PE's wave contribution (sent and received counts for the buckets asked, buckets passed, and the controller's counters and histogram when it sends them) becomes one flat array of 64-bit integers written to its own slot; it then increments the arrival counter.
2. **The last PE in combines.** The PE that brings the counter to the process's PE count sums the slots (minimum for buckets passed), resets the counter, and hands the combined array to its process's `NodeWaves` branch (one local message), which contributes it to a nodegroup reduction.
3. **No tuple.** The cross-process reduction uses one custom reducer over the flat array (sum everywhere except one minimum), registered at startup like the statistics reducer.
4. **The result comes back once per process** (a nodegroup broadcast). The handler copies it into the process's shared result and bumps a generation counter.
5. **PEs pick it up where they already look for work**: at the top of `execute()`, next to the htram input buffer drain, a PE that is waiting on a wave checks the generation counter and, if it moved, runs the existing `check_counts` logic on the shared result. That logic is unchanged, so every PE still makes the same decision from the same sums.
- Correctness: a PE contributes to wave k+1 only after it has read wave k's result, as now (Mattern's four-counter rule needs exactly that); the slots and the result buffer are reused safely because no PE can contribute to wave k+1, or a result k+1 exist, before every PE of the process has read result k. Committed counts must equal the message path's.
- The start reduction (once per run) is unchanged.

**Gate.** Mac: `test.py --tier change` and the bucketed configs with `--gvt-node-waves=1` (with and without htram, with the controller on the count waves), `--repeat 20` on two of them; committed counts equal to the message path.

**Then on Stampede3** (when `/work2` works on compute nodes again): `--gvt-trace=1` runs at 4 and 16 nodes, σ 100 and σ 2,000, W 250 and 400, both paths, 2 reps.

**Predictions:**
- N1. At 16 nodes a wave (seen by PE 0) drops from 187–243 µs to at most 80 µs, and a GVT advance from 262–379 µs to at most 130.
- N2. At 16 nodes the best fixed W gains 30–60% (σ 100 and σ 2,000), and weak-scaling efficiency at σ 2,000 rises from 0.76 to at least 0.9. At 4 nodes the gain is 5–15%, since there the wave is partly hidden behind PE 0's batches.
- N3. Committed counts are identical to the message path in every run.
- N4. With cheaper rounds, the best W at 16 nodes moves back toward 250–300.

### §50 · GVT count waves combined per process, results (2026-10-24, skx-dev batch job 3635736, 16 nodes)

> **Status: current.** Short runs (end 512,000), 2 reps; the two paths ran from the same binary (`$WORK/charades-nw`: eef0778 plus the `gvt-node-waves` change), interleaved.

**Runs.** `$WORK/charades-runs/nodewaves.slurm`; CSVs, traces and `summary.md` in `~/charades-data/nodewaves/`. All 40 measured runs finished (the job's first launch, a warm-up, hit the cap: the usual cold start). **Committed counts are identical between the two paths in every workload.**

**Results** (medians of 2; M committed events/s, higher is better; µs per GVT advance, lower is better):

| run | message path: M ev/s | µs per advance | per-process waves: M ev/s | µs per advance | gain |
|---|---|---|---|---|---|
| 4 nodes, σ 100, W 250 | 122.6 | 177 | **162.4** | 131 | 1.32 |
| 4 nodes, σ 100, W 400 | 104.6 | 235 | 141.6 | 171 | 1.35 |
| 4 nodes, σ 2,000, W 250 | 105.4 | 205 | **135.8** | 156 | 1.29 |
| 4 nodes, σ 2,000, W 400 | 99.2 | 254 | 118.3 | 213 | 1.19 |
| 16 nodes, σ 100, W 250 | 329.8 | 265 | 467.3 | 181 | 1.42 |
| 16 nodes, σ 100, W 400 | 400.4 | 308 | **469.7** | 224 | 1.17 |
| 16 nodes, σ 2,000, W 250 | 291.7 | 299 | **373.8** | 227 | 1.28 |
| 16 nodes, σ 2,000, W 400 | 315.8 | 397 | 365.0 | 311 | 1.16 |
| 16 nodes, controller, σ 100 (mean W) | 346.6 (292) | 297 | 450.7 (296) | 209 | 1.30 |
| 16 nodes, controller, σ 2,000 (mean W) | 288.9 (277) | 338 | 366.2 (275) | 252 | 1.27 |

- **Best against best: 1.29–1.32× at 4 nodes and 1.17–1.18× at 16.** At 16 nodes the best W moves back to 250 (σ 2,000) or ties 250 and 400 (σ 100), and the controller reaches 0.96 and 0.98 of the best fixed W, up from 0.86.
- A GVT advance takes 131–156 µs at 4 nodes (was 177–205) and 181–227 µs at 16 at W 250 (was 265–299). At 16 nodes most of what remains is the reduction across the 32 processes.
- **Against Devastator** (its rates from earlier jobs with the same end time, 3633769 and 3635596, so indicative only; Charades ÷ Devastator, higher is better for Charades): 4 nodes σ 100 0.96 (was 0.73), σ 2,000 1.29 (was 1.02); 16 nodes σ 100 0.71 (was 0.62), σ 2,000 0.98 (was 0.86).
- Weak-scaling efficiency from 4 to 16 nodes, each path against its own 4-node rate: σ 100 0.72, σ 2,000 0.69. It looks lower than before only because the 4-node rate rose more.

**Predictions:**
- N1. **Wrong.** At 16 nodes a wave seen by PE 0 is 116–179 µs (not ≤ 80) and an advance 181–311 µs (not ≤ 130): combining within processes removed about a third, and the cross-process reduction remains.
- N2. **Wrong both ways.** 16 nodes gain 17–18% best against best (not 30–60%); 4 nodes gain 29–32% (not 5–15%). The per-process combine matters as much at 4 nodes, where PE 0 used to spend its time handling 44 messages per wave.
- N3. Right: identical committed counts.
- N4. Right: the best W at 16 nodes is back to 250 (σ 2,000) or 250–400 (σ 100).

**Default since 2026-10-24** (user decision): `--gvt-node-waves=1`. The message path stays reachable with `=0` and is covered by the `*_msgwaves` test configs. Mac gate for the switch: every bucketed config 612/612 (quick shapes), engine tier 940/942 with the 2 non-passes caused by a second `lcrun` I started during the run, both 20/20 when rerun alone.

**What this means:** `--gvt-node-waves` is the largest single gain since psm2, and it is free of any runtime change. The cross-engine numbers in "Current numbers" (message path) understate Charades by about 1.3× at 4 nodes; the paper-grade comparison should be rerun with it on. What is left at 16 nodes is the reduction across processes (32 members, about 180–230 µs per advance), next to try: a flatter or wider tree across processes, or contributing as soon as a process is complete rather than through an entry method.

### §51 · The cross-process part of a GVT advance: allreduce by recursive doubling (design, 2026-10-24; written before any runs on Stampede3)

> **Status: design.** Written before the Stampede3 runs; the Mac numbers below are the only measurements so far.

**Why.** With `--gvt-node-waves` a run is still paced by GVT advances (95–97% of scheduler batches end blocked by the window), and an advance takes 131–156 µs at 4 nodes and 181–227 µs at 16. What is left in it: the slowest PE of each process contributing, one local message to the process's `NodeWaves` branch, Charm++'s nodegroup reduction across processes and its broadcast back, and the PEs noticing the result. The nodegroup reduction goes up a tree and back down; an allreduce by recursive doubling (in round r every process swaps its partial sums with process me XOR 2^r; after log2 P rounds every process has the total) has no separate broadcast and half the depth. On the Mac (lcrun, tcp), `tools/redbench` (new modes `-m 3`: nodegroup reduction and broadcast, one contribution per process; `-m 4`: recursive doubling) gives 19.6 against 15.5 µs per wave with 2 processes and 54.0 against 30.9 with 4.

**Design** (`--gvt-wave-allreduce=1`; with `--gvt-node-waves`; needs a power-of-two process count, else the nodegroup reduction is used):
- The last PE in a process hands the combined array to its `NodeWaves` branch as now; that branch runs the allreduce with `[exclusive]` nodegroup entry methods, buffering a partner's message that arrives a round (or a wave) early, and publishes the total exactly as the reduction result is published now. Integer sums and one minimum are exact, so every process gets the same result.
- `--gvt-trace=1` also records, for PE 0's process, when its last PE arrived and when the result was published, to split an advance into gathering, crossing processes, and pickup.

**Runs** (one skx-dev job, 16 nodes): `redbench -m 3` and `-m 4` at 1, 2, 4, 8 and 16 nodes; Charades σ 100 and σ 2,000 at W 250, 4 and 16 nodes, `--gvt-wave-allreduce` 0 and 1, traced, 2 reps.

**Predictions:**
- A1. `redbench`: recursive doubling takes at most 60% of the nodegroup reduction's time at 8 and 16 nodes.
- A2. In Charades at 16 nodes, crossing processes is at least half of an advance with the nodegroup reduction; with the allreduce an advance drops from 181–227 µs to 110–150, and throughput rises 15–35%. At 4 nodes the gain is 5–15%.
- A3. Committed counts are identical.

### §52 · The cross-process part of a GVT advance, results (2026-10-24, skx-dev batch job 3635974; benchmark also from the cancelled job 3635873)

> **Status: current.** Short runs (end 512,000), 2 reps, W 250 unless noted. Job 3635840 died at startup on a node with a hanging `/work2` (signal 53, no output); job 3635873 was cancelled when `redbench -m 4` hung, a bug in `redbench` (a partner's first message taken before the process had started the wave), fixed and rerun in 3635974, which excluded the suspect nodes. Charades' allreduce already had the guard `redbench` lacked.

**Runs.** `$WORK/charades-runs/allreduce.slurm`, `allreduce2.slurm`; copied to `~/charades-data/allreduce/`; `scripts/stampede3/advance_split.py` (new) splits each advance from the trace. All Charades runs finished; committed counts are identical between the two paths in every workload.

**The reduction across processes alone** (`redbench`, µs per wave, lower is better; nodes = physical nodes, 2 processes each):

| nodes | 1 | 2 | 4 | 8 | 16 |
|---|---|---|---|---|---|
| nodegroup reduction (`-m 3`) | 10.9 | 22.4 | 27.8 | 40.3 | 49.4–49.7 |
| recursive doubling (`-m 4`) | 5.8–6.0 | 12.6 | 20.4 | 29.5 | 40.7–42.8 |

**A GVT advance, split** (PE 0's view; µs, means over waves, medians of 2; M committed events/s):

| run | M ev/s | µs per advance | PE 0 contributes → its process combined | combined → result | result → PE 0 picks it up | picks up → contributes again |
|---|---|---|---|---|---|---|
| 4 nodes, σ 100: nodegroup / allreduce | 160.5 / 160.8 | 133 / 132 | 20 / 20 | 86 / 87 | 4 / 4 | 23 / 21 |
| 4 nodes, σ 2,000 | 133.1 / 133.5 | 159 / 159 | 40 / 41 | 93 / 90 | 5 / 6 | 20 / 22 |
| 16 nodes, σ 100 | 465.0 / 445.2 | 182 / 191 | 13 / 13 | 152 / 165 | 4 / 3 | 13 / 10 |
| 16 nodes, σ 2,000 | 373.3 / 371.4 | 227 / 228 | 23 / 26 | 185 / 183 | 5 / 4 | 14 / 14 |
| 16 nodes, controller, σ 100 | 435.2 / 423.0 | 216 / 222 | 14 / 11 | 179 / 194 | 5 / 3 | 15 / 11 |
| 16 nodes, controller, σ 2,000 | 364.4 / 373.1 | 254 / 245 | 24 / 27 | 204 / 193 | 6 / 6 | 17 / 18 |

**What it says:**
- **Crossing processes is 75–85% of an advance, but the reduction is not what takes the time.** In the runs it takes 152–204 µs at 16 nodes against 41–50 µs for the same reduction alone, and 86–93 µs against about 25 at 4 nodes. The rest is waiting for the slowest process to finish gathering its own PEs; the allreduce cannot shorten that, and it changes throughput by 0.96–1.02.
- PE 0's own process gathers in 13–41 µs and picks the result up in 3–6 µs, so the slow processes are elsewhere; what holds a process back is not yet measured. Candidates: a PE busy in a 16-event batch when the result arrives, and a PE holding its contribution until it has run 128 events (`--gvt-wave-events`).

**Predictions:**
- A1. **Wrong.** Recursive doubling is 0.73 (8 nodes) and 0.84 (16) of the nodegroup reduction, not ≤ 0.6.
- A2. Crossing is more than half of an advance (right), but the allreduce does not shorten it (**wrong**): no throughput gain at 4 or 16 nodes.
- A3. Right: identical committed counts.

**Decision:** `--gvt-wave-allreduce` stays as an option, off. Next: what makes a process late, tried first with existing settings (`--gvt-wave-events=0`; `--batch` 4 and 8), traced, at 4 and 16 nodes.

### §53 · What makes a process late to a count wave: batch size and wave holding (design, 2026-10-24; written before any runs)

> **Status: design.** Written before any runs.

**Why.** Crossing processes takes 152–204 µs of a 16-node advance while the reduction itself takes about 50 ("The cross-process part of a GVT advance, results"): the wave waits for the slowest process to gather its PEs. A PE runs a wave's result and contributes to the next only between scheduler batches (16 events by default), and it holds its contribution until it has run 128 events since its last one unless it ran out of work (`--gvt-wave-events`).

**Runs** (one skx-dev job, 16 nodes, excluding the nodes suspected of the `/work2` hang): σ 100 and σ 2,000, W 250, `--gvt-trace=1`, 4 and 16 nodes, 2 reps; arms: default (batch 16, wave events 128); `--gvt-wave-events=0`; `--batch 8`; `--batch 4`; `--batch 4 --gvt-wave-events=0`.

**Predictions:**
- K1. If late PEs are what the wave waits for, `--batch 4` cuts the combined → result time at 16 nodes by at least 30% and raises throughput by at least 10%; the extra scheduler passes cost at most 5% at 4 nodes.
- K2. `--gvt-wave-events=0` alone changes throughput by less than 5%.

### §54 · What makes a process late to a count wave, results (2026-10-24, skx-dev batch job 3636110)

> **Status: current.** Short runs (end 512,000), W 250, 2 reps. The first submission (3636097) died at startup like 3635628 and 3635840 (signal 53, no output), on nodes that had run fine an hour before, so the `/work2` hang is not tied to particular nodes; this job wrote its own output to `$SCRATCH` and started at once. Two runs hit the cap (the warm-up launch and one 4-node default run, whose rep 2 stands in).

**Runs.** `$WORK/charades-runs/late2.slurm`; copied to `~/charades-data/late/`. Committed counts are identical across arms.

**Throughput and advances** (M committed events/s, medians of 2, higher is better; µs per GVT advance):

| arm | 4 nodes σ 100 | 4 nodes σ 2,000 | 16 nodes σ 100 | 16 nodes σ 2,000 |
|---|---|---|---|---|
| default (batch 16, wave events 128) | 165.5 (128 µs) | 129.7 (164) | 458.3 (185) | 370.2 (229) |
| `--gvt-wave-events=0` | 164.7 (80) | **137.1** (111) | **466.6** (152) | **381.6** (185) |
| `--batch 8` | 155.3 (136) | 127.3 (166) | 447.7 (188) | 361.7 (233) |
| `--batch 4` | 145.8 (145) | 121.7 (174) | 428.6 (196) | 335.6 (251) |
| `--batch 4 --gvt-wave-events=0` | 129.4 (54) | 114.2 (78) | 409.0 (123) | 357.4 (157) |

**What it says:**
- **Faster waves do not make the run faster.** Contributing at once (`--gvt-wave-events=0`) cuts the time per advance by 18–38%, but the run then needs 20–60% more advances (16 nodes σ 2,000: 8,543 → 10,213; 4 nodes σ 100: 8,350 → 13,649), each moving GVT less: throughput changes by −0.5% to +6%.
- **The slowest PE sets the pace.** In every arm PE 0 leads GVT by the whole window (250), while the buckets every PE has passed reach only about 22 past GVT (about 180 of simulated time): one PE lags the rest by about 70, and GVT cannot pass it. Each wave completes about 7.5 buckets in every default arm, at 4 and 16 nodes alike.
- Smaller batches cost more than they save (more scheduler passes): 0.88–0.98.
- So from here, cheaper GVT advances buy little at W 250. What makes the slowest PE slow is the open question: more events in its range, events reaching it late, or its core doing other work (htram's node-level receives and `NodeWaves` combining run on whichever PE takes them).

**Predictions:**
- K1. **Wrong.** `--batch 4` is slower everywhere (0.88–0.94).
- K2. Right at 16 nodes (+2–3%) and at 4 nodes σ 100 (−0.5%); just outside at 4 nodes σ 2,000 (+6%).

### §55 · Which PE is slow, and why (design, 2026-10-24; written before any runs)

> **Status: design.** Written before any runs.

**Why.** At W 250 GVT waits for the slowest PE, which trails the window's edge by about 70 of simulated time while the rest sit at it ("What makes a process late", results). New option `--pe-stats=1` (charades 8a8abfa): PE 0 writes each PE's executed, committed and rolled-back events, remote sends, and how its scheduler batches ended (full, blocked by the window, out of events) to `pe_stats.csv`. A PE that is rarely blocked by the window is one the others wait for.

**Runs** (skx-dev, 16 nodes, job output on `$SCRATCH`): σ 100 and σ 2,000, W 250, 4 and 16 nodes, `--pe-stats=1 --gvt-trace=1`, 2 reps.

**Predictions:**
- S1. The PEs least often blocked by the window are the first PE of each process (rank 0), which also runs htram's node-level receives and the `NodeWaves` combine.
- S2. Executed events per PE vary by at most 5% around the mean: load imbalance is not the cause.

### §56 · Which PE is slow, and why, results (2026-10-24, skx-dev batch job 3636151)

> **Status: current.** Short runs (end 512,000), W 250, 2 reps, all 8 finished; `scripts/stampede3/pe_summary.py`; data `~/charades-data/pestats/`.

| run | executed per PE: max ÷ mean, min ÷ mean | window-blocked batches per PE: mean, least | rank 0 vs other ranks (mean blocked) |
|---|---|---|---|
| 4 nodes σ 100 | 1.010, 0.990 | 330–451 K, 153–219 K | 275–357 K vs 332–456 K |
| 4 nodes σ 2,000 | 1.003, 0.997 | 524–525 K, 396–443 K | 481–484 K vs 526 K |
| 16 nodes σ 100 | 1.013, 0.988 | 937–941 K, 696–738 K | 880–886 K vs 939–943 K |
| 16 nodes σ 2,000 | 1.004–1.005, 0.996 | 1,170–1,244 K, 1,015–1,061 K | 1,128–1,196 K vs 1,172–1,246 K |

- **S2 right:** events are balanced to ±1.3%.
- **S1 right in tendency, but it is not the explanation.** Rank 0 (the first PE of each process) is blocked by the window 4–21% less often than other ranks, and most of the ten least-blocked PEs are rank 0; but even the least-blocked PE is blocked hundreds of thousands of times. No PE is busy while the others wait.
- So the lag of the slowest PE's position behind the window's edge (about 70 of simulated time) is not a slow core. The traces say each wave completes about half the buckets it asks about because their sent and received totals do not yet match: events sent into them have not arrived. One candidate is htram PP's per-node buffer, which goes out only when it fills (512 items) or on a full flush, not when a due event is in it.

### §59 · Count waves that ask about every bucket up to the window (design, 2026-10-24; written before any code or runs)

> **Status: design.** Written before any code or runs.

**Change** (`--gvt-ask-ahead=A`): a wave reports counts for max(valid − completed, A) buckets (capped at the buckets left) instead of valid − completed. With A at least the window in buckets, the previous wave has always reported counts for every bucket all PEs had passed, so a bucket can complete one wave after every PE passed it and its counts match, instead of about three. Mattern's four-counter rule is unchanged: a bucket still completes only when it was passed by every PE at the previous wave and the previous wave's received total equals this wave's sent total. Cost: 2A integers per contribution instead of about 30 (A = 33 at W 250: 66).

**Gate.** Mac change tier on the bucketed configs with `--gvt-ask-ahead` set, `--repeat 20` on two; committed counts equal to the default.

**Predictions:**
- G1. Buckets completed per wave rise from 7.5 to at least 12 at W 250 (the bound is valid ÷ 2 ≈ 11 if valid stays at 22.5, more if PEs then pass further).
- G2. Throughput rises at least 1.3× at 4 and 16 nodes with htram (PP 512), since runs are paced by GVT advances; less with direct sends, which are slower per event.
- G3. With faster GVT the best W moves down.
- G4. Committed counts identical.

### §60 · Count waves that ask about every bucket up to the window, results (2026-10-24, skx-dev batch job 3636197)

> **Status: current.** Short runs (end 512,000), 2 reps, all measured runs finished (the warm-up launch hit the cap as usual); data `~/charades-data/askahead/`. Committed counts are identical with and without the option.

| nodes, σ, arm | ask-ahead off: M ev/s (buckets per wave) | `--gvt-ask-ahead=-1` | on ÷ off |
|---|---|---|---|
| 4, σ 100, W 250 | 160.0 (7.5) | 156.4 (8.4) | 0.98 |
| 4, σ 100, W 400 | 138.2 (8.5) | 129.5 (8.7) | 0.94 |
| 4, σ 100, controller | 152.8 (8.0) | 137.9 (8.3) | 0.90 |
| 4, σ 2,000, W 250 | 131.8 (7.5) | 133.1 (8.5) | 1.01 |
| 4, σ 2,000, W 400 | 113.1 (8.9) | 104.4 (9.2) | 0.92 |
| 4, σ 2,000, controller | 129.0 (7.9) | 121.3 (8.5) | 0.94 |
| 16, σ 100, W 250 | 456.2 (7.5) | 480.2 (8.7) | 1.05 |
| 16, σ 100, W 400 | 468.8 (9.4) | 451.0 (9.9) | 0.96 |
| 16, σ 100, controller | 458.3 (8.3) | 440.2 (9.1) | 0.96 |
| 16, σ 2,000, W 250 | 375.6 (7.5) | 387.6 (8.9) | 1.03 |
| 16, σ 2,000, W 400 | 357.5 (10.1) | 358.2 (11.3) | 1.00 |
| 16, σ 2,000, controller | 368.5 (8.2) | 353.6 (9.5) | 0.96 |

(Buckets per wave here = 64,000 buckets ÷ GVT advances.)

**What it says:**
- The bookkeeping cap was real (completed rises from exactly valid ÷ 3), but lifting it moves completion only from 7.5 to 8.4–8.9 buckets per wave, and throughput by −10% to +5%. Once every passed bucket can be asked about, most still do not complete in the next wave: their sent and received totals do not match yet, so events sent into them are still in transit. Why they are, at this lag, is not measured.
- **G1 wrong** (8.4–8.9, not ≥ 12); **G2 wrong** (0.90–1.05, not ≥ 1.3); G3 not tested; **G4 right** (identical counts).
- `--gvt-ask-ahead` stays as an option, off (default 0).

**Where the GVT work stands.** Combining waves per process (`--gvt-node-waves`) gained 1.17–1.32×. Everything tried after it on the GVT side (allreduce across processes, contributing at once, smaller batches, asking ahead) moves throughput by −12% to +6%. The largest gain seen since is not on the GVT side: htram WPs 512 instead of PP 512 at 16 nodes and σ 100 (1.25×; 0.85× at σ 2,000).

### §61 · Same-process events by pointer (`--local-fast-path`) (design, 2026-10-24; written before any code or runs)

> **Status: design.** Written before any code or runs.

**Why.** At σ 100, Charades takes 1.27× Devastator's cycles per committed event, and that ratio is the whole gap there (speedup 0.71–0.77 at 4 nodes; 0.71 with PP 512 at 16). The profile puts 20% of PE time in sends (9%) and htram delivery (11%: input buffer drain, `Aggregator::deliver`, `recv_remote_event`), and 97% of events at σ 100 stay in their process (128 LPs per PE, 16 per chare: 8 chares per PE, so most events go to another chare on the same PE or a neighbouring PE). Every one of them is copied into a 64 B htram item, buffered, flushed, copied out into a new message, indexed in the receiver's hash so an anti-message can find it, and removed from the hash at commit. Devastator hands a same-process event to its receiver as a pointer and cancels it by pointer.

**Change.** With `--local-fast-path=1`, an event for a chare on another PE of the same process, or on another chare of the same PE, skips htram and Charm++ messages:
- **Send.** As now up to `produce()` (GVT bucket counts, `far`, controller delay sample). The sender then pushes the message pointer onto the destination PE's input buffer: a lock-free multi-producer list per PE (one compare-and-swap per event), or a plain vector when the destination is the sender's own PE. The sender's event stays in its parent's caused-by list as now, marked sent, and keeps the message pointer as its handle.
- **Receive.** At the start of every `execute()` (beside `poll()` and `agg_drain()`), the PE takes its whole input buffer with one exchange, restores send order, and for each message does what `recv_remote_event` does (`consume()`, straggler statistics, `recv_local_event`) except the hash insert. The receiver's event is stored in the message, so the message pointer finds it.
- **Cancel.** The sender pushes a small anti-message carrying the target message pointer into the same input buffer. One sender's pushes arrive in order, so the event always arrives before its anti-message, and nothing needs indexing. The target is still alive: the receiver frees it only when it commits (its timestamp is below GVT, so its sender can no longer roll back the event that sent it) or when this anti-message arrives.
- **GVT.** Unchanged: an event is counted sent at `produce()` and received when drained, so one waiting in an input buffer is in transit, exactly as with htram's input buffers. As with `--agg-input-buffer`, only with the bucketed GVT and the optimistic scheduler, not with `--sched-park`, load balancing, or event holding (`--gvt-adaptive-buckets`); elsewhere the option is refused.
- **Same chare**: unchanged (already by pointer). **Other processes**: unchanged (htram or direct).
- Statistics: "Process Sends (fast path)" and "Process Anti Sends (fast path)", counted within Remote Sends and Anti Event Sends as before.

**Gate.** Mac change and engine tiers with new `*_fastpath` configs: committed counts equal to the expected counts, `--repeat 20` on two, multi-process and multi-PE (lcrun 2 × 4 PEs).

**Predictions** (4 and 16 nodes, PP 512, best fixed W and the controller, σ 100 and 2,000):
- F1. σ 100, 4 nodes: 1.10–1.20× (most of the 20% send and delivery time is same-process; Charades ÷ Devastator from 0.77 to about 0.9).
- F2. σ 2,000: 1.03–1.10× (more events leave the process).
- F3. Fewer htram messages per committed event (same-process items leave htram), and efficiency equal or higher (same-process events are no longer held by the deadline policy).
- F4. Committed counts identical.
- F5. At 16 nodes the gain is smaller than at 4, since runs there are paced by GVT advances rather than per-event cost.

### §62 · Same-process events by pointer, results (2026-10-24, skx-dev batch job 3636369)

> **Status: current.** Short runs (end 512,000), 2 reps (medians), htram PP 512 for events to other processes, `--gvt-node-waves` (default); data `~/charades-data/fastpath/` (`fp_summary.py`). All 48 runs finished; committed counts identical with the fast path off and on. Mac: change tier 108/108 on six new `*_fastpath` configs, engine tier 1408/1408 including `--repeat 20` of `bucket_window_fastpath` and `agg_deadline_bucket_pp_fastpath`.

| nodes, σ, arm | off: M ev/s | on: M ev/s | on ÷ off (higher is better) | µs per GVT advance, off / on (lower is better) | events per htram message, off / on | remote sends by pointer |
|---|---|---|---|---|---|---|
| 4, σ 100, W 250 | 163.1 | 165.2 | 1.01 | 129 / 128 | 203 / 38 | 97% |
| 4, σ 100, W 400 | 136.9 | 156.6 | 1.14 | 176 / 156 | 139 / 26 | 97% |
| 4, σ 100, controller | 150.2 | 165.1 | 1.10 | 151 / 136 | 192 / 35 | 97% |
| 4, σ 2,000, W 250 | 130.4 | 126.4 | 0.97 | 162 / 168 | 117 / 74 | 50% |
| 4, σ 2,000, W 400 | 116.7 | 115.1 | 0.99 | 215 / 221 | 71 / 45 | 50% |
| 4, σ 2,000, controller | 128.2 | 123.1 | 0.96 | 174 / 182 | 107 / 69 | 50% |
| 16, σ 100, W 250 | 455.3 | 540.2 | 1.19 | 186 / 157 | 193 / 39 | 97% |
| 16, σ 100, W 400 | 461.6 | 563.7 | 1.22 | 229 / 184 | 107 / 27 | 97% |
| 16, σ 100, controller | 441.9 | 541.8 | 1.23 | 213 / 173 | 185 / 37 | 97% |
| 16, σ 2,000, W 250 | 362.9 | 362.5 | 1.00 | 233 / 234 | 116 / 74 | 50% |
| 16, σ 2,000, W 400 | 361.1 | 357.5 | 0.99 | 313 / 319 | 62 / 44 | 50% |
| 16, σ 2,000, controller | 352.5 | 347.2 | 0.98 | 261 / 266 | 107 / 69 | 50% |

Best ÷ best (each arm set at its best W): 4 nodes σ 100 1.01, σ 2,000 0.97; 16 nodes σ 100 1.22, σ 2,000 1.00. The 4-node σ 2,000 drop (2–5%) is in both reps; at 16 nodes it is within the rep spread. Efficiency is equal or slightly higher with the fast path (99.84–99.99%). GVT advances per run are unchanged (W sets them).

**What it says:**
- **The per-event saving shows only where a GVT advance waits on work.** At 4 nodes and W 250 both arms sit at the same advance time (129 µs, the round itself), so the cheaper events buy nothing; at W 400, under the controller, and everywhere at σ 100 on 16 nodes, an advance waits for the slowest process's work, and the fast path cuts it by 10–21%.
- **σ 100 at 16 nodes: 1.19–1.23×.** Against Devastator's rates from earlier jobs with the same end time (3633769, 3635596; indicative only), Charades ÷ Devastator moves at 16 nodes from 0.71 to about 0.88 at σ 100 and stays at about 0.98 at σ 2,000; at 4 nodes about 0.97 (σ 100) and 1.25 (σ 2,000).
- **σ 2,000: no gain, 3% loss at 4 nodes.** Half the remote events still leave the process, and the advance time rises by 5–8 µs. Not yet explained; candidates: contended pushes onto input buffers (22 producers per input buffer), messages read from another core's cache instead of copied in bulk, or htram's off-process buffers filling more slowly once same-process items leave them (74 instead of 117 events per message).
- **F1 partly wrong** (best ÷ best 1.01 at 4 nodes; 1.10–1.14 only off the best W); **F2 wrong** (0.97–1.00); **F3 right** (htram carries only off-process events; efficiency equal or higher); **F4 right**; **F5 wrong**: the gain is larger at 16 nodes, where advances wait on work, not smaller.
- `--local-fast-path` stays off by default until the σ 2,000 loss is understood.

### §63 · Where the fast path loses at σ 2,000, and with WPs (design, 2026-10-24; written before any runs)

> **Status: design.** Written before any runs.

**Questions.** (1) Why the fast path costs 3% at σ 2,000 on 4 nodes, where half the remote events go by pointer. (2) Whether htram WPs 512, which was 1.25× PP 512 at 16 nodes σ 100 before the fast path, still helps now that htram carries only off-process events. (3) Charades ÷ Devastator in the same job, same end time.

**New in the code** (Mac change tier 72/72 on `*_fastpath` and `*_fastpath_pe`):
- `--local-fast-path=2`: by pointer only to other chares on the sender's own PE (no atomics); events to other PEs of the process go through htram as before.
- "Input Buffer Push Retries (fast path)": pushes that failed their compare-and-swap because another PE pushed first.

**Job** (skx-dev, 16 nodes, 2 reps, end 512,000, W 250 / W 400 / controller, σ 100 and 2,000, 4 and 16 nodes): fast path 0, 1, 2 with PP 512, and 1 with WPs 512; Devastator at W 500 and 1,000 (`--rng=clcg4`).

**Predictions:**
- P1. Mode 2 recovers the σ 2,000 loss (≥ 1.00 of off) and keeps most of the σ 100 gain at 16 nodes (≥ 1.10), i.e. the cross-PE input buffer is the cost at σ 2,000.
- P2. Push retries are below 5% of pushes, so contention is not the cause; the cost is reading messages from another core's cache.
- P3. WPs 512 with the fast path beats PP 512 with the fast path at 16 nodes σ 100 (≥ 1.05), and loses at σ 2,000 as before.
- P4. Charades ÷ Devastator at 16 nodes σ 100: 0.85–0.90.

### §64 · Where the fast path loses at σ 2,000, and with WPs, results (2026-10-24, skx-dev batch job 3636435)

> **Status: current.** Short runs (end 512,000), 2 reps (medians); data `~/charades-data/fp2/`. 94 of 96 Charades runs finished. The two that did not (fast path off, 4 nodes, σ 100, rep 1, W 250 and W 400) printed nothing before the 60 s cap: a cold start on nodes the 4-node warm-up had not touched, not the code under test (rep 2 and job 3636369 cover both). Later jobs warm every node. Committed counts identical across all four variants.

**÷ fast path off with PP 512** (higher is better):

| nodes, σ, arm | off: M ev/s | on (PP) | this PE only (PP) | on + WPs 512 | µs per GVT advance: off / on / PE only / WPs | input buffer push retries per push (on) |
|---|---|---|---|---|---|---|
| 4, σ 100, W 250 | 164.5 | 1.04 | 1.02 | 1.01 | 129 / 124 / 127 / 128 | 1.2% |
| 4, σ 100, W 400 | 137.7 | 1.15 | 1.12 | 1.19 | 175 / 154 / 157 / 148 | 1.2% |
| 4, σ 100, controller | 150.3 | 1.08 | 1.02 | 1.11 | 151 / 139 / 148 / 137 | 1.2% |
| 4, σ 2,000, W 250 | 132.7 | 0.97 | 0.98 | 0.85 | 160 / 164 / 164 / 187 | 2.8% |
| 4, σ 2,000, W 400 | 116.7 | 0.98 | 1.00 | 0.92 | 215 / 222 / 214 / 245 | 2.7% |
| 4, σ 2,000, controller | 127.3 | 0.99 | 0.99 | 0.87 | 177 / 178 / 178 / 203 | 2.8% |
| 16, σ 100, W 250 | 448.3 | 1.23 | 1.05 | 1.33 | 188 / 154 / 179 / 141 | 1.3% |
| 16, σ 100, W 400 | 448.0 | 1.29 | 1.08 | 1.35 | 236 / 179 / 220 / 170 | 1.2% |
| 16, σ 100, controller | 447.8 | 1.23 | 1.04 | 1.35 | 210 / 168 / 202 / 152 | 1.2% |
| 16, σ 2,000, W 250 | 375.2 | 0.97 | 1.01 | 0.89 | 225 / 231 / 224 / 253 | 2.9% |
| 16, σ 2,000, W 400 | 372.9 | 1.01 | 0.99 | 0.89 | 303 / 297 / 306 / 355 | 2.8% |
| 16, σ 2,000, controller | 367.5 | 0.97 | 1.00 | 0.87 | 251 / 257 / 251 / 291 | 2.9% |

**Charades ÷ Devastator, same job, same end time** (each at its best tested setting; Devastator W 500 or 1,000 with `--rng=clcg4`; higher is better for Charades):

| nodes, σ | Devastator (M ev/s) | Charades, fast path off, PP | fast path, PP | fast path, WPs |
|---|---|---|---|---|
| 4, σ 100 | 171.7 | 0.96 (164.5) | **1.00** (171.5) | 0.97 (166.2) |
| 4, σ 2,000 | 104.2 | 1.27 (132.7) | 1.24 (129.3) | 1.09 (113.3) |
| 16, σ 100 | 661.0 | 0.68 (448.3) | 0.87 (577.1) | **0.91** (604.7) |
| 16, σ 2,000 | 368.8 | 1.02 (375.2) | 1.02 (377.5) | 0.91 (334.2) |

**What it says:**
- **Contention is not the σ 2,000 cost** (P2 right): 2.8% of pushes retry. Sending by pointer only within the PE recovers σ 2,000 (0.98–1.01) but keeps only 1.04–1.08 of the 1.23–1.29 at 16 nodes σ 100 (**P1 wrong**): most of the σ 100 gain is events to other PEs of the process. The σ 2,000 loss is small (0–3%) and, with both modes near 1.00 at 16 nodes, close to the rep spread.
- **WPs with the fast path** is the best Charades at 16 nodes σ 100: 1.35× fast path off, 1.05× fast path with PP (**P3 right**), and loses 8–15% at σ 2,000 as before. The htram mode should follow locality.
- **Against Devastator** (**P4 right**): parity at 4 nodes σ 100 (1.00), ahead at σ 2,000 (1.24 at 4 nodes, 1.02 at 16), behind only at 16 nodes σ 100 (0.87 with PP, 0.91 with WPs; was 0.68).
- With PP, the fast path's best ÷ best: 1.04 (4 nodes σ 100), 0.97 (4 nodes σ 2,000), 1.29 (16 nodes σ 100), 1.01 (16 nodes σ 2,000).

### §79 · Where a GVT advance's time goes at scale; PP 2,048's allocation vs its limit; the horizon margin (design, 2026-10-25; written before any runs)

> **Status: design.** Charades branch `scale-diag` (off `agg-auto`), htram `pdes` with `initPPLimit`. Job script `$WORK/charades-runs/diag.slurm`; output `$WORK/charades-runs/sdiag/j<job>/`.

**Why.** Section 78: at Gaussian σ, Charades' loss from 4 to 16 nodes is all in µs per GVT advance (σ 2,000: 167 → 233), and section 76: PP 2,048's gain at low σ is not aggregation, while its loss at σ ≥ 2,000 comes from events held past their deadline. Earlier work (memory, jobs 3635974–3636197) found that the cross-process wait is waiting for the slowest process, not the reduction, on PE 0's view only.

**New instrumentation** (off by default):
- `--gvt-trace=2`: with `--gvt-node-waves` (the default), every process writes `gvt_waves_<process>.csv`, one row per count wave, all on its own clock: when its first and its last PE contributed, the last PE's rank, and when the result was published there. Per process and wave: *work* = last contribution − previous result (how long until its slowest PE was ready), *spread* = last − first, *wait* = result − last contribution. Per wave across processes: the advance time = result − previous result (the same for every process, up to broadcast skew), the *reduction floor* = the smallest wait (the slowest process waits only for the reduction and broadcast), and the *straggler cost* = the largest work − the median work. No clocks are compared across nodes.
- `--agg-pp-limit=N` (diagnostic): PP's shared buffers are capped at N events while every buffer stays allocated at `--agg-buffer` (htram `initPPLimit`). Mac: test configs `agg_pp_limit`, `bucket_gvt_trace2`.

**Job** (16 nodes, skx-dev; PP 512, W 250, margin 8 unless noted):
- A. N = 16, 8, 4 nodes; σ 100, σ 2,000, uniform; `--gvt-trace=2 --pe-stats=1`, each against an untraced run; 3 reps.
- B. 16 nodes, σ 100 and σ 2,000: PP 512, PP 2,048, PP 2,048 capped at 512; 3 reps.
- C. 16 nodes, σ 100, 2,000, 4,000; PP 512 and PP 2,048; W 250 and 400; margins 8, 32, 64, 128 (the horizon is W + margin); 2 reps.

**Predictions:**
- A1. The trace costs ≤ 3% (traced ÷ untraced ≥ 0.97).
- A2. From 4 to 16 nodes the reduction floor grows by ≤ 30 µs (to 40–80 µs at 16 nodes), and the straggler cost grows by more: it is most of the increase in advance time at σ 2,000 and σ 100.
- A3. The slowest process changes from wave to wave (no process is the last in more than 20% of waves at 16 nodes), and within it the spread (last − first PE) is most of its work, with no fixed last rank.
- B1. At σ 100, PP 2,048 capped at 512 is within 3% of PP 2,048 (the gain is the allocation, a layout effect); at σ 2,000 it is within 3% of PP 512 (the loss follows the limit).
- C1. A larger margin cuts events held past their deadline at σ ≥ 2,000, and PP 2,048 at margin 64–128 recovers to ≥ 0.95 of PP 512 at margin 8. PP 512 gains ≤ 5% at σ ≥ 2,000; at σ 100 every margin is within 2%.

### §80 · Where a GVT advance's time goes at scale; PP 2,048's allocation vs its limit; the horizon margin, results (2026-10-25; skx-dev batch job 3639554)

> **Status: current.** Design and predictions in section 79. Charades `scale-diag` 00b1944, htram 6a5cc0c. 171 runs, all ok; canary passed (32 trace files); 15 min. Data `~/charades-data/sdiag/j3639554/` (CSVs, `gvt_waves_*.csv`, `pe_stats.csv`), summary `~/charades-data/sdiag/sdiag_summary.py`.

**A. GVT advance breakdown, PP 512, W 250** (µs, mean over waves 10%–95% of the run, median of 3 reps; lower is better):

| workload | nodes | traced ÷ untraced | advance | reduction floor | median process work | slowest process work | straggler cost (slowest − median) | spread inside the slowest process | most often slowest process (share of waves, 3 reps) |
|---|---|---|---|---|---|---|---|---|---|
| σ 100 | 4 | 0.98 | 130 | 34 | 29 | 96 | 67 | 86 | 6/6/6 (0.76) |
| σ 100 | 8 | 1.04 | 137 | 44 | 20 | 91 | 69 | 83 | 0/6/9 (0.45) |
| σ 100 | 16 | 0.98 | 158 | 50 | 13 | 106 | 93 | 99 | 22/22/22 (0.55) |
| σ 2,000 | 4 | 0.92 | 181 | 35 | 39 | 145 | 107 | 131 | 6/3/6 (0.76) |
| σ 2,000 | 8 | 1.06 | 178 | 43 | 42 | 141 | 99 | 130 | 2/6/0 (0.38) |
| σ 2,000 | 16 | 1.00 | 228 | 52 | 27 | 174 | 147 | 163 | 22/22/22 (0.46) |
| uniform | 4 | 0.99 | 182 | 30 | 66 | 152 | 86 | 138 | 0/6/6 (0.29) |
| uniform | 8 | 1.04 | 319 | 44 | 85 | 273 | 192 | 236 | 10/6/14 (0.15) |
| uniform | 16 | 1.01 | 535 | 50 | 93 | 482 | 389 | 430 | 22/13/22 (0.06) |

(Work = a process's last PE contribution − the previous result there; reduction floor = the smallest wait from last contribution to result, i.e. the slowest process's; spread = last − first PE contribution in that process.)

- **A1 right, with noise.** Traced ÷ untraced is 0.92–1.06 (median 1.00); one cell (4 nodes, σ 2,000) is below 0.97.
- **A2 right.** From 4 to 16 nodes the reduction floor grows 16–20 µs (to 50–52 µs). The rest of the growth is the straggler cost: σ 2,000 +40 µs of the +47 µs, σ 100 +26 of +28, uniform +303 of +353. The slowest process's time is mostly the spread among its own PEs (its last PE comes 86–163 µs after its first; uniform 430).
- **A3 wrong: the slowest process is not random; at 16 nodes it is one slow node.** Process 22 was slowest in 46–55% of waves in all three reps at σ 100 and σ 2,000. `pe_stats` shows why: both processes on that node (allocation index 11, **c455-081**) execute the same events as every other process (to 0.1%) but spend 4–8% more time doing it (µs per event ÷ median: process 22 1.07–1.08, process 23 1.02–1.05, every other process ≤ 1.05 and mostly ≤ 1.01), and are rarely window-blocked (0.57 of the median's blocked passes). So a node about 6% slower per event sets the pace of every advance. With a tight window (W 250), the whole job runs at the slowest node's speed; the chance of having such a node grows with the node count, which is part of the 4→16-node loss and would hit any Charades run on that node. At 4 nodes process 6 was slowest in 76% of waves without being slower per event (1.00), so there the cause is something else (not yet explained).
- **The last PE inside the slowest process is often rank 0** (σ 100: 0.70 at 4 nodes, 0.36 at 16; less at higher σ), the PE that also does process-level work (node-group entry methods, htram node receives).

**B. PP 2,048's allocation with PP 512's limit, 16 nodes, W 250** (M committed events/s, median of 3; in parentheses events per htram message, efficiency %; higher is better):

| workload | PP 512 | PP 2,048 | PP 2,048 capped at 512 | capped ÷ PP 512 | capped ÷ PP 2,048 |
|---|---|---|---|---|---|
| σ 100 | 516.5 (39.4, 99.98) | 589.7 (39.5, 99.98) | 586.7 (39.5, 99.98) | 1.14 | 0.99 |
| σ 2,000 | 339.2 (74.0, 99.93) | 246.6 (77.7, 98.66) | 378.6 (74.6, 99.93) | 1.12 | 1.54 |

- **B1 right, and it is a free 12–14%.** Allocating the buffers at 2,048 gives the gain (1.14 at σ 100, 1.12 at σ 2,000) with PP 512's messages and efficiency; the 2,048 limit gives the loss at σ 2,000. Capped is the best setting at both σ. The mechanism is unknown: in PP each PE's own `msgBuffers` (allocated at the buffer size, 32 destinations × 2,048 × ~72 B ≈ 4.7 MB per PE) are not used to send, so this is a side effect of the allocation (heap layout or the allocator's behaviour for the 1.2 MB shared buffers allocated at every send), like the unexplained ±10% of section 75. It has to be understood before it becomes a default.

**C. Horizon margin, 16 nodes** (M committed events/s, median of 2; ÷ PP 512 at margin 8 and the same W; higher is better):

| workload | W | setting | margin 8 | 32 | 64 | 128 |
|---|---|---|---|---|---|---|
| σ 100 | 250 | PP 512 | 527.3 (1.00) | 528.1 (1.00) | 510.9 (0.97) | 455.2 (0.86) |
| σ 100 | 250 | PP 2,048 | 577.5 (1.10) | 564.3 (1.07) | 485.4 (0.92) | 498.2 (0.94) |
| σ 100 | 400 | PP 512 | 538.2 (1.00) | 530.1 (0.99) | 512.1 (0.95) | 472.6 (0.88) |
| σ 100 | 400 | PP 2,048 | 531.0 (0.99) | 558.0 (1.04) | 547.0 (1.02) | 487.2 (0.91) |
| σ 2,000 | 250 | PP 512 | 343.2 (1.00) | 334.6 (0.97) | 279.9 (0.82) | 224.9 (0.66) |
| σ 2,000 | 250 | PP 2,048 | 245.5 (0.72) | 388.5 (1.13) | 299.5 (0.87) | 214.1 (0.62) |
| σ 2,000 | 400 | PP 512 | 346.5 (1.00) | 326.4 (0.94) | 296.9 (0.86) | 256.4 (0.74) |
| σ 2,000 | 400 | PP 2,048 | 239.8 (0.69) | 257.9 (0.74) | 263.8 (0.76) | 234.0 (0.68) |
| σ 4,000 | 250 | PP 512 | 295.4 (1.00) | 270.1 (0.91) | 228.0 (0.77) | 192.3 (0.65) |
| σ 4,000 | 250 | PP 2,048 | 206.9 (0.70) | 220.9 (0.75) | 196.9 (0.67) | 177.7 (0.60) |
| σ 4,000 | 400 | PP 512 | 293.2 (1.00) | 283.5 (0.97) | 252.6 (0.86) | 204.6 (0.70) |
| σ 4,000 | 400 | PP 2,048 | 211.2 (0.72) | 225.2 (0.77) | 224.2 (0.76) | 195.3 (0.67) |

- **C1 mostly wrong.** A larger margin does remove the late events (efficiency 98.7 → 99.95–100% at σ 2,000), but it sends events sooner and messages shrink (σ 2,000, W 250: 74 → 61 → 36 → 12 events per message), which costs more than the rollbacks it saves: PP 512 loses 3–35% at σ ≥ 2,000 and up to 14% at σ 100. PP 2,048 recovers only in one cell (σ 2,000, W 250, margin 32: 1.13, which is about the allocation gain of B). **Margin 8 stays the default**; the PP 2,048 lateness is better fixed by the cap (B) than by sending early.

**Consequences.**
- The 4→16-node loss at Gaussian σ splits into a growing reduction floor (+16–20 µs per advance) and a growing straggler cost (+26–40 µs), and here much of the straggler cost was one node ~6% slower per event. Next: (1) find the allocation mechanism behind B (allocator settings such as `MALLOC_MMAP_THRESHOLD_`/`MALLOC_TOP_PAD_` on PP 512, against the capped setting; and whether htram's 1.2 MB per-send shared-buffer allocation is the cause), then make the winner the default; (2) make Charades tolerate a slow PE or node: a window that lets processes drift further apart (Devastator's W 1,000 does this), or less work on rank 0; (3) check whether c455-081 is slow on its own (a single-node benchmark) before treating "slow node" as a general effect.

### §83 · Where a wider window's cost goes, on a clean allocation (design, 2026-10-25; written before any runs)

> **Status: design.** Part W of section 81 repeated with `-x c455-081`, 3 reps: 16 nodes, PP 512, σ 100 and σ 2,000, W 250, 400, 600, `--gvt-trace=2 --pe-stats=1`. Same build (`charades-diag`). Job script `$WORK/charades-runs/diag3.slurm`.

**Predictions:**
- C1. No process is consistently the busiest: the busiest process's µs per event is ≤ 1.03× the median, and a different process is busiest in different runs.
- C2. µs per advance is lower than in section 82 at every W (no slow node), and from W 400 to 600 the straggler cost still accounts for more than half of the added µs per advance.
- C3. From W 400 to 600 the straggler cost grows faster than the work per advance (the ratio of advances), the share that rollbacks add.

### §84 · Where a wider window's cost goes, on a clean allocation, results: the slowest process is usually late because of its rank 0 (2026-10-25; skx-dev batch job 3640064)

> **Status: current.** Design and predictions in section 83. 18 traced runs, all ok (the two warm-ups hit the cap, as intended on fresh nodes); 5 min; allocation c454-[021-022,091-092,094,101-102], c455-[002-004,011,071-072,091-093], without c455-081. Data `~/charades-data/sdiag/j3640064/`, summary `~/charades-data/sdiag/sdiag3_summary.py`.

**16 nodes, PP 512** (median of 3; µs from the per-process traces, mean over waves; higher M ev/s is better, lower µs is better):

| workload | W | M ev/s | efficiency % | GVT advances | µs per advance | reduction floor µs | straggler cost µs | rolled back (M events) |
|---|---|---|---|---|---|---|---|---|
| σ 100 | 250 | 542.4 | 99.98 | 8,537 | 151 | 51 | 82 | 0.12 |
| σ 100 | 400 | 558.6 | 99.96 | 7,016 | 178 | 50 | 107 | 0.32 |
| σ 100 | 600 | 509.7 | 99.78 | 6,195 | 221 | 51 | 146 | 1.58 |
| σ 2,000 | 250 | 362.3 | 99.93 | 8,550 | 209 | 51 | 122 | 0.51 |
| σ 2,000 | 400 | 359.7 | 99.87 | 6,366 | 291 | 56 | 189 | 0.93 |
| σ 2,000 | 600 | 318.5 | 99.07 | 5,168 | 419 | 58 | 304 | 6.77 |

- **C1 right (one exception).** The busiest process's µs per event is 1.006–1.020× the median and it is a different process in each run, except one run (σ 100, W 250, rep 1: process 5 at 1.071).
- **C2 right.** Without c455-081, every cell is faster than in section 82 (σ 100: 542 vs 514 at W 250; µs per advance 151 vs 159), and the straggler cost is most of what W 600 adds (σ 100: 39 of 43 µs; σ 2,000: 115 of 128).
- **C3 right.** The straggler cost grows faster than the work per advance at every step: σ 100, W 400 → 600: ×1.36 against ×1.13; σ 2,000: ×1.61 against ×1.23 (and W 250 → 400: ×1.30 vs ×1.22, ×1.55 vs ×1.34). The reduction floor is flat (50–58 µs). Even at W 250 the straggler cost is 54–58% of an advance.

**Who is late inside the slowest process** (from the last PE's rank in each wave, all 3 reps):

| workload | W | rank 0 is the slowest process's last PE | rank 0 is any process's last PE | the slowest process's first PE contributes after (µs) |
|---|---|---|---|---|
| σ 100 | 250 | 0.62 | 0.11 | 8 |
| σ 100 | 400 | 0.80 | 0.14 | 9 |
| σ 100 | 600 | 0.74 | 0.16 | 13 |
| σ 2,000 | 250 | 0.31 | 0.07 | 10 |
| σ 2,000 | 400 | 0.29 | 0.08 | 17 |
| σ 2,000 | 600 | 0.22 | 0.07 | 25 |

With 23 PEs per process, chance is 0.04. So in the process that holds an advance up, one PE, usually rank 0, comes 100–300 µs after the others.

**Two causes, from `pe_stats`** (σ 100, W 250 / 400, rep 1; rolled-back events per PE, and window-blocked passes ÷ rank 11's):
- **The process edges.** Rolled-back events per PE: rank 0 1,596 / 1,209, rank 22 1,788 / 2,248, ranks 1 and 21 166–772, inner ranks 0–258. At σ 100 events go to nearby LPs, so almost all of a process's cross-process events come into its first and last PEs. Those events go through htram and arrive late (held until due), so those PEs roll back 35–50× more often than inner PEs. Rank 0 is also less often idle (0.88–0.95 of rank 11's window-blocked passes), so it is behind. (Rank 22 is more often idle, 1.15–1.19.)
- **Rank 0's process-level work.** At σ 2,000 rollbacks are even across ranks (1,072–1,666), yet rank 0 is still the slowest process's last PE 22–31% of the time, against 4% by chance, and has the highest µs per event of the inner and edge ranks it was compared with (1.449 vs 1.411–1.438, except rank 22). Rank 0 is where process-level work lands (node-group entry methods; which PE handles htram's node-level receives and the count-wave reduction in Reconverse is to be checked).

**Consequences.** The window's cost and much of the 4→16-node loss come from one late PE per advance, and that PE is predictable: rank 0, and at low σ the process-edge PEs. Two fixes follow, each testable in one short job:
1. **Take process-level work off rank 0.** Each process has one free core (2 × 23 PEs on 48 cores). Put the node-level receive and reduction handling there, like Devastator's master thread, or spread it across PEs. First find which PE runs what (a short trace of node-group entry methods by rank).
2. **Process edges at low σ:** send the few cross-process events of low-σ workloads early or directly instead of holding them until due (at σ 100 only 2–3% of events leave the process), or lay out LPs so a process's edge traffic is spread over its PEs.

### §104 · Why one PE holds up each GVT advance at uniform and σ 2,000: per-PE wave records, and fewer events per wave (design, 2026-10-26; written before any runs)

> **Status: design.** Charades `scale-diag` ff3f4fd (adds `--gvt-trace=4`), htram `pdes` 3cb3d1e, Reconverse `pads-dest-device` 13ae1ac with `+lci_dest_device` off (the same as `pads-runtime`). `+lci_ndevices 23`, glibc defaults. Job K `$WORK/charades-runs/diag13.slurm` (16 nodes, skx-dev and skx, `-x c455-081`, the copy that starts second cancelled).

**Why.** Where Charades still scales worse than Devastator is σ ≥ 2,000 and uniform (4→16-node efficiency 0.81 and 0.52, against 0.91 and 0.69; section 95). Section 80 put most of the growth in time per GVT advance into the straggler cost: the slowest process's last PE contributes long after the others (uniform: +303 of +353 µs per advance from 4 to 16 nodes; the slowest process's own PEs 430 µs apart; σ 2,000: +40 of +47). At uniform the slowest process changes from wave to wave (no process slowest in more than 6% of waves), so this is not the lower-edge effect of sections 84–103, which needs locality. Nothing so far says what that last PE is doing.

**What a contribution waits for.** A PE joins a count wave when it picks up the previous wave's result (at the start of its next scheduler pass) and then either has executed `--gvt-wave-events` events (128) since its last contribution or ends a pass with nothing it may execute. At uniform, each PE executes about 140–150 events per wave (16 nodes, WPs 512, W 400: 278 M ev/s over 736 PEs, 6,473 waves in 2.6 s; 4 nodes: about 140), close to 128. So the last PE may simply be the one that still had events inside the window and ran 128 of them, while PEs that ran out of work joined at once.

**New instrumentation** (off by default): `--gvt-trace=4` adds, for every PE and every 4th wave (`gvt_rec_<pe>.csv`; all PEs sample the same waves), times in µs after the previous result was published in its process (on that process's clock):
- when the PE picked the result up, and when its last scheduler pass before that ended (so a late pickup splits into time still inside a pass and time outside one: other entry methods, network progress);
- when it contributed, and why: at pickup (idle or already past 128 events), or later (ran out of work, or reached 128 events);
- between pickup and contribution: scheduler time, input buffer drains, htram receive handlers, rollbacks, node-group GVT handlers, events executed;
- the buckets past GVT it had passed when it contributed (how far it had got in virtual time).

Mac: test config `bucket_gvt_trace4`, 6/6 (and trace 2/3 unchanged, 12/12).

**Runs** (W 400; uniform = remote 1.0, lookahead 100 / mean 1,000; σ 2,000 at the same lookahead and mean; 2 reps, interleaved):
- Traced (`--gvt-trace=4 --pe-stats=1`) with untraced pairs at 4 and 16 nodes: uniform with WPs 512 (its best at 16 nodes) and PP 512; σ 2,000 with PP 512.
- `--gvt-wave-events` 0 and 32 against the default 128, untraced, 16 nodes: uniform with WPs 512 and PP 512; σ 2,000 PP 512 with 32 only. (0 was tried at σ 100 and σ 2,000 in sections 47 and 54: advances 18–38% shorter but 20–60% more of them, throughput −2% to +6%; never at uniform.)

Summary per traced run, over the recorded waves at 10–95% of the run: in each wave the slowest process's last PE (the "late PE") against the median PE of the same process; its delay split into pickup (inside a pass / outside) and pickup → contribution (scheduler, drains, receives, rollbacks), its events, its time per event, its reason, the buckets it had passed; which ranks and processes are late.

**Predictions:**
- K1. At uniform on 16 nodes the late PE is spread out: no rank is the slowest process's last PE in more than 15% of waves, and no process is the slowest in more than 15%.
- K2. The late PE contributes on the event count (it reached 128) in at least 70% of waves, while the median PE of its process does so in at most 30%. Its pickup delay is at most 25% of its contribution delay. So it is late because it still had events to run, not because it was busy elsewhere.
- K3. Between pickup and contribution, the late PE's time per executed event is within 20% of the median PE's (it is late because it has more to do, not because each event costs more), and it reaches the same number of buckets passed as the median PE or fewer.
- K4. From 4 to 16 nodes, at least 70% of the growth in the late PE's delay is after pickup.
- K5. σ 2,000 at 16 nodes looks the same: the late PE reaches the event count in at least 60% of waves.
- K6. `--gvt-wave-events=32` is at least 1.03× the default at uniform on 16 nodes in both modes, and within ±3% at σ 2,000; `--gvt-wave-events=0` is 0.95–1.10× at uniform.
- K7. `--gvt-trace=4` costs at most 5% (traced ÷ untraced ≥ 0.95).

If K2 holds, the straggler cost at uniform is GVT waiting for the PE with the most work in the window, and the remedies are spreading that work (sharing it within a process) or pacing waves differently, not aggregation. If instead the late PE's time is in pickup or in drains and receives (K2 or K3 wrong), it is receive handling, and fewer, larger messages could help after all.

### §105 · Per-PE wave records, results: at uniform the late PE is slowed by receiving many small messages; `--gvt-wave-events=32` is 1.04–1.06× at 16 nodes (2026-10-26; skx-dev batch job 3643687, 16 nodes)

> **Status: current.** Design and predictions in section 104. 16 nodes (c454-021, c454-022, c454-042, c454-072, c455-022 to -024, c455-031 to -034, c455-041, c455-042, c455-094, c455-101, c455-102; 4-node runs on the first four), 35 runs ok (the first warm-up stalled, as first launches on fresh nodes do); 6 min. Summary `~/charades-data/sdiag/sdiag13_summary.py`, output `~/charades-data/sdiag/j3643687/summary.txt`.

**Throughput** (untraced, W 400, M committed events/s, mean of 2 reps; higher is better):

| workload | htram | 4 nodes | 16 nodes | 4→16 efficiency | traced ÷ untraced (4 / 16 nodes) |
|---|---|---|---|---|---|
| uniform | WPs 512 | 101.7 | 280.2 | 0.69 | 0.984 / 0.985 |
| uniform | PP 512 | 122.1 | 224.5 | 0.46 | 0.987 / 1.018 |
| σ 2,000 | PP 512 | 125.8 | 431.8 | 0.86 | 0.990 / 1.013 |

**`--gvt-wave-events` K ÷ the default 128, 16 nodes** (untraced, both reps in parentheses; higher is better):

| workload | htram | K 0 | K 32 |
|---|---|---|---|
| uniform | WPs 512 | 1.057 (296.7, 295.8 vs 279.4, 281.0) | 1.056 (298.0, 294.0) |
| uniform | PP 512 | 1.037 (233.5, 232.3 vs 224.8, 224.1) | 1.042 (232.0, 235.6) |
| σ 2,000 | PP 512 | — | 1.035 (444.4, 449.6 vs 429.3, 434.4) |

**The late PE against the median PE of its process** (the slowest process's last PE in each recorded wave, waves 10–95%, both reps, about 2,800–3,100 waves per cell; µs after the previous result in that process, lower is better; "by count" = share of waves in which it contributed because it had run 128 events since its last contribution):

| workload | nodes | PE | delay | pickup (in a pass + outside) | after pickup | of which: scheduler (incl. drains) | drains | htram receives | other, outside the scheduler | events after pickup | µs per event after pickup | by count |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| uniform, WPs | 4 | late | 209 | 8 + 9 | 192 | 133 | 35 | 47 | 12 | 79 | 2.44 | 1.00 |
| uniform, WPs | 16 | late | 339 | 22 + 28 | 288 | 159 | 53 | 102 | 27 | 61 | 4.74 | 0.97 |
| uniform, WPs | 16 | median | 78 | 2 + 2 | 75 | 7 | 1 | 2 | 66 | 2 | — | 0.31 |
| uniform, PP | 4 | late | 165 | 8 + 7 | 150 | 125 | 28 | 6 | 19 | 87 | 1.72 | 0.98 |
| uniform, PP | 16 | late | 387 | 13 + 32 | 343 | 154 | 46 | 79 | 110 | 59 | 5.78 | 0.94 |
| σ 2,000, PP | 4 | late | 156 | 12 + 8 | 136 | 117 | 22 | 2 | 17 | 90 | 1.51 | 0.99 |
| σ 2,000, PP | 16 | late | 143 | 20 + 15 | 107 | 78 | 16 | 2 | 13 | 55 | 1.94 | 0.94 |

(The median PE contributes almost at once in every cell: delay 21–81 µs, 1–2 events after pickup. Its "other" time is mostly waiting for its next pass to end.)

**Cost of an htram receive** (ranks 0, 1, 11, 21, 22 of every process, from the `--gvt-trace=3` snapshots, waves 10–100%; µs per receive-handler call):

| workload | htram | 4 nodes | 16 nodes |
|---|---|---|---|
| uniform | WPs 512 | 10.3, 11.1 (30 events per message) | 8.3, 8.2 (12.4) |
| uniform | PP 512 | 5.7, 5.5 (75) | 7.5, 7.3 (13.8) |
| σ 2,000 | PP 512 | 3.7, 3.7 (50) | 3.7, 3.7 (50) |

- **K1 half right.** No rank is the late PE in more than 10% of waves at uniform. But one process is the slowest more often than 15% of the time: process 2 at 16 nodes with WPs (0.26), and processes 2 and 3 at 4 nodes (0.35, 0.32). Processes 2 and 3 are the second node in both runs (c454-022). They are not slower per event (`pe_stats`: every process is within 1.04× of the median), so this is not a slow node like c455-081. Not explained.
- **K2 right, with one detail.** The late PE contributes by count in 94–100% of waves, and its pickup takes 8–15% of its delay. The median PE contributes by count in 29–34% of waves, just over the 30% predicted. The count runs from the PE's last contribution: after pickup the late PE runs only 55–90 events, never 128. So it is late because it is busy after pickup, not because it was busy elsewhere first.
- **K3 wrong at uniform: the late PE is slower, not more loaded.** From 4 to 16 nodes it runs *fewer* events after pickup (WPs 79 → 61, PP 87 → 59) but takes longer per event (2.44 → 4.74 µs, 1.72 → 5.78). The extra time is receive work:
  - WPs: the late PE's delay grows by 130 µs. htram receive handlers +55, pickup +33, drains +18, other time outside the scheduler +15, the events themselves +8.
  - PP: it grows by 222 µs. Other time outside the scheduler +91, htram receives +73, pickup +30, drains +18. The 91 µs is outside Charades' timers: Converse scheduling, LCI progress, and receive-side work that the htram timer does not cover.
  - (The comparison with the median PE was not meaningful: it runs 1–2 events after pickup.)
- **Receive work is even over the run but uneven per wave.** Every rank spends about 2 µs per wave in htram receive handlers on average (WPs, 16 nodes: 0.2–10.4 per PE, no rank above 3). In a given wave, the late PE is the one that took about 100 µs of receives. With LCI, a message lands on the device with the sender's index, so which PE handles a receive depends on the sender's rank, which is effectively random at uniform.
- **K4 right.** 74% (WPs) and 87% (PP) of the growth in the late PE's delay is after pickup. But it is mostly receive work, not event execution.
- **K5 right, and σ 2,000 does not grow in this job.** The late PE contributes by count in 94% of waves. Its delay is 156 µs at 4 nodes and 143 at 16, with receives at 2 µs. This job's σ 2,000 efficiency is 0.86 (0.81 in section 95), so it has little loss left to explain.
- **K6 right for uniform, and better than predicted at σ 2,000.** K 32 gives 1.056 (WPs) and 1.042 (PP) at uniform, and 1.035 at σ 2,000 (predicted ±3%). K 0 gives about the same as 32 at uniform. All four reps are within ±1% of their pair. In section 25 (4 nodes, an older runtime and layout), K 64 was 0.77, so 32 needs checking at 1 and 4 nodes before it becomes the default.
- **K7 right.** Traced ÷ untraced is 0.984–1.018.

**What this means.**
- At uniform, the straggler cost at scale is receive handling of thin messages. Per call, a WPs receive costs about 10.6 µs at 30 events per message and 8.2 µs at 12.4. Fitting a fixed and a per-event cost to these two points gives about 6.5 µs per message plus 0.13 µs per event. So receive cost per event rises from about 0.35 µs to 0.66 µs as messages thin. PP is not consistent with a simple fixed-plus-per-event fit, because it mixes PEs' 16-event local sends with shared-buffer sends.
- So fewer, larger messages *would* help uniform, against section 80's reading. So would a cheaper per-message receive: what the 6.5 µs consists of is not yet measured. One candidate is pushes onto up to 23 PEs' input buffers per message.
- Separately, `--gvt-wave-events=32` is worth 3.5–5.6% at 16 nodes on all three workloads.

**Next:**
1. `--gvt-wave-events` 32 (and 64) against 128 at 1, 4 and 16 nodes across the scaling workloads, before changing the default.
2. Break down an htram receive at 16 nodes (unpacking, input buffer pushes per destination PE, allocation), to find the fixed cost.
3. Then compare cutting that cost with fewer destinations (one process per node with per-socket buffers, or two-hop routing).

### §106 · `--gvt-wave-events` 32 / 64 / 128 at 1, 4 and 16 nodes; what an htram receive costs (design, 2026-10-26; written before any runs)

> **Status: design.** Charades `scale-diag` 859fe1a (adds `recv_parts_<pe>.csv` under `--gvt-trace=3`), htram `pdes` 04457e0 (splits node-level receives into parts), Reconverse `pads-dest-device` 13ae1ac with `+lci_dest_device` off. `+lci_ndevices 23`, glibc defaults. Job L `$WORK/charades-runs/diag14.slurm` (16 nodes, skx-dev and skx, `-x c455-081`, the copy that starts second cancelled).

**Why.** Section 105: `--gvt-wave-events=32` was 1.035–1.056× the default 128 at 16 nodes on uniform and σ 2,000, but 64 was 0.77 at 4 nodes in section 25 (older runtime and layout), so the default should change only if smaller counts do not lose at 1 and 4 nodes or on other workloads. And at uniform the late PE is slowed by htram receives that cost about 6.5 µs per message plus 0.13 µs per event (a two-point fit), but what that fixed cost is made of is unknown.

**A. `--gvt-wave-events` K = 32, 64, 128.** The 8 workloads of the scaling series at 1, 4 and 16 nodes, PP 512:
- lookahead 100 / mean 1,000 (σ 100, 500, 1,000, 2,000, 4,000 and uniform): W 400 and the controller (ε 0.001);
- lookahead 10 / mean 200 (σ 500 and 2,000): W 50 and the controller;
- uniform also with WPs 512 (its best at 16 nodes), W 400 and the controller.

2 reps, interleaved over K; 324 runs.

**B. The cost of an htram receive.** `--gvt-trace=3` at 4 and 16 nodes, W 400: uniform with WPs 512 and PP 512, σ 2,000 with PP 512; 2 reps. Each PE writes its receives over the run, split into:
- allocating the sorted message;
- finding each item's rank and copying it;
- freeing the received message;
- handing the sorted message to the other PEs (one input buffer push, under that input buffer's lock, per PE that gets items);
- dropping the receiver's own reference;
- delivering its own items (Charades' callback).

It also writes the items received, the pushes made, and its input buffer drain time. The timers add 7 clock reads per receive.

**Predictions:**
- L1. At 16 nodes, K 32 is at least 1.02× K 128 in at least 6 of the 9 fixed-W cells and in at least 6 of the 9 controller cells. K 64 lies between them.
- L2. At 1 and 4 nodes, K 32 is within ±3% of K 128 in most cells, and no cell is below 0.95.
- L3. At lookahead 10 (11,400 advances at 16 nodes, against about 8,500), K 32 gains less than at lookahead 100 and stays within ±3%.
- **Decision rule:** K 32 becomes the default if its geometric mean over all cells is at least 1.02 at 16 nodes and at least 0.99 at 1 and at 4 nodes, with no cell below 0.95.
- R1. At uniform on 16 nodes with WPs, handing the message to other PEs is the largest part of a receive, at least 40% of its time.
- R2. Allocating, freeing the received message and dropping the reference together take at most 25%.
- R3. Delivering the PE's own items takes at most 20%.
- R4. Pushes per receive match the number of distinct PEs among the message's items: about 9.8 at 12.4 events per message (23 × (1 − (22/23)^12.4)) and about 17 at 30.
- R5. Time per receive matches section 105 (WPs, 16 nodes: 8.2 µs) within 15%.

### §107 · Wave events and receive cost, results: 128 stays; a receive's fixed cost is its input buffer pushes, which slow from 0.17 to 0.70 µs each as receives get frequent (2026-10-26; skx-dev batch job 3645244, 16 nodes)

> **Status: current.** Design and predictions in section 106. 16 nodes (c455-024, c455-031 to -034, c455-041 to -044, c455-082 to -084, c455-091, c455-101 to -103; 4- and 1-node runs on the first nodes), 338 runs, all ok; 23 min. Summary `~/charades-data/sdiag/sdiag14_summary.py`, output and CSVs in `~/charades-data/sdiag/j3645244/`.

**A. `--gvt-wave-events` K ÷ 128** (PP 512 unless marked WPs; M committed events/s at K 128, mean of 2 reps; ratios higher is better):

Fixed W (400; lookahead 10: 50):

| workload | 1 node: K 128 | 32 | 64 | 4 nodes: K 128 | 32 | 64 | 16 nodes: K 128 | 32 | 64 |
|---|---|---|---|---|---|---|---|---|---|
| σ 100 | 44.4 | 0.889 | 0.899 | 167.3 | 0.976 | 0.959 | 633.1 | 0.925 | 1.011 |
| σ 500 | 38.4 | 0.846 | 0.858 | 146.8 | 0.924 | 0.912 | 552.3 | 1.014 | 1.026 |
| σ 1,000 | 35.4 | 0.880 | 0.903 | 142.9 | 0.912 | 0.919 | 512.7 | 1.017 | 0.959 |
| σ 2,000 | 33.8 | 0.858 | 0.887 | 125.1 | 0.944 | 0.959 | 442.6 | 1.007 | 1.014 |
| σ 4,000 | 33.8 | 0.845 | 0.872 | 115.4 | 0.953 | 0.947 | 424.8 | 1.016 | 1.004 |
| uniform | 35.7 | 0.845 | 0.879 | 119.9 | 0.957 | 0.971 | 211.4 | 1.132 | 1.111 |
| uniform, WPs | 36.1 | 0.858 | 0.899 | 101.8 | 1.009 | 1.031 | 288.1 | 1.007 | 1.020 |
| lookahead 10, σ 500 | 38.0 | 0.891 | 0.940 | 144.3 | 1.027 | 1.014 | 482.7 | 1.033 | 1.040 |
| lookahead 10, σ 2,000 | 33.4 | 0.948 | 0.986 | 108.5 | 1.077 | 1.076 | 369.0 | 1.024 | 1.014 |
| **geometric mean** | | **0.873** | **0.902** | | **0.974** | **0.975** | | **1.018** | **1.021** |

Controller (ε 0.001):

| workload | 1 node: K 128 | 32 | 64 | 4 nodes: K 128 | 32 | 64 | 16 nodes: K 128 | 32 | 64 |
|---|---|---|---|---|---|---|---|---|---|
| σ 100 | 46.9 | 1.012 | 0.981 | 171.8 | 1.015 | 1.009 | 614.8 | 0.993 | 0.993 |
| σ 500 | 41.6 | 1.002 | 1.001 | 154.5 | 1.019 | 1.007 | 564.1 | 0.982 | 0.989 |
| σ 1,000 | 40.3 | 1.017 | 1.009 | 145.8 | 1.021 | 1.018 | 512.5 | 0.991 | 0.974 |
| σ 2,000 | 39.1 | 1.012 | 0.999 | 132.9 | 1.005 | 1.009 | 406.9 | 0.983 | 1.005 |
| σ 4,000 | 38.5 | 1.018 | 1.010 | 119.6 | 1.014 | 1.011 | 382.6 | 0.990 | 1.008 |
| uniform | 41.7 | 1.017 | 1.009 | 130.2 | 0.968 | 0.978 | 208.1 | 1.004 | 1.007 |
| uniform, WPs | 41.0 | 1.023 | 1.005 | 104.3 | 1.081 | 1.068 | 275.1 | 1.042 | 1.053 |
| lookahead 10, σ 500 | 37.8 | 0.997 | 1.002 | 141.5 | 1.020 | 1.010 | 460.9 | 1.034 | 1.043 |
| lookahead 10, σ 2,000 | 33.5 | 1.026 | 1.031 | 109.8 | 1.021 | 1.028 | 356.9 | 1.011 | 1.016 |
| **geometric mean** | | **1.014** | **1.005** | | **1.018** | **1.015** | | **1.003** | **1.009** |

- **L1 wrong.** At 16 nodes, K 32 is ≥ 1.02 in 3 of 9 fixed-W cells and 2 of 9 controller cells, not 6. The geometric mean is 1.018 at fixed W and 1.003 with the controller.
  - The cells section 105 measured gain less here: uniform WPs at W 400 is 1.007 against 1.056, and σ 2,000 is 1.007 against 1.035. Section 105's pairs agreed within 1%, so that gain depended on the allocation.
  - K 64 is not between 32 and 128 in several cells (σ 100: 0.925 / 1.011; σ 1,000: 1.017 / 0.959).
- **L2 wrong, badly at fixed W.** On 1 node every fixed-W cell loses with K 32 (0.845–0.948, geometric mean 0.873). At 4 nodes the geometric mean is 0.974 (minimum 0.912). With the controller K 32 is neutral to slightly better (1.014 on 1 node, 1.018 on 4). The controller adjusts the window, which presumably absorbs the shorter waves. Fixed W cannot.
- **L3 wrong.** Lookahead 10 gains as much or more than lookahead 100 at 4–16 nodes (1.02–1.08).
- **Decision: K 128 stays the default.** K 32 fails the rule on 1 node (0.873 at fixed W) and at 4 nodes (0.974). Its gains at 16 nodes are small (1.003–1.018) and partly allocation-dependent.

**B. What an htram receive costs** (all PEs over the whole run; µs per receive, mean of 2 reps; lower is better):

| workload, htram | nodes | items per receive | µs per receive | allocate | find rank and copy | free received message | **hand off to other PEs** | drop own reference | own items | pushes per receive | **µs per push** | receives per PE (run) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| uniform, WPs | 4 | 29.9 | 10.3 | 0.42 | 0.89 | 0.70 | **7.90** | 0.05 | 0.34 | 15.1 | **0.52** | 29,000 |
| uniform, WPs | 16 | 12.4 | 8.5 | 0.45 | 0.46 | 1.13 | **6.16** | 0.05 | 0.18 | 8.9 | **0.70** | 77,500 |
| uniform, PP | 4 | 76.2 | 5.8 | 0.37 | 1.77 | 0.60 | **2.20** | 0.05 | 0.77 | 10.5 | **0.21** | 11,500 |
| uniform, PP | 16 | 13.8 | 7.3 | 0.43 | 0.47 | 0.84 | **5.28** | 0.05 | 0.19 | 8.5 | **0.62** | 69,300 |
| σ 2,000, PP | 4 | 49.9 | 4.0 | 0.33 | 1.21 | 0.51 | **1.38** | 0.05 | 0.45 | 8.4 | **0.17** | 9,900 |
| σ 2,000, PP | 16 | 50.0 | 3.9 | 0.32 | 1.16 | 0.48 | **1.44** | 0.05 | 0.43 | 8.4 | **0.17** | 9,800 |

(The parts add up to within 0.06 µs of the measured total. Input buffer drains on the receiving PEs cost a further 0.31–0.49 µs per item.)

- **R1 right.** Handing the message to other PEs is 73% of a receive at uniform on 16 nodes with WPs (6.2 of 8.5 µs), 72% with PP.
- **R2 right.** Allocating, freeing the received message and dropping the reference together take 19% (1.6 µs). Freeing the received message grows from 0.70 to 1.13 µs at 16 nodes: this is the cross-thread free into another PE's message pool (section 99).
- **R3 right.** The PE's own items take 2%.
- **R4 roughly right, a little low.** Pushes per receive are 8.9 at 12.4 items (predicted 9.8, or about 9.3 without the PE's own share) and 15.1 at 29.9 (predicted 17).
- **R5 right.** 8.5 µs per receive against 8.2 in section 105.
- **The cost of a push depends on how often receives happen, not on the message.**
  - At about 10,000 receives per PE over the run (σ 2,000, either node count; uniform PP at 4 nodes), a push takes 0.17–0.21 µs.
  - At 29,000 it takes 0.52 µs; at 69,000–78,000, 0.62–0.70 µs.
  - Each push takes the destination input buffer's mutex, appends to its vector and stores its pending count. At uniform on 16 nodes, all 23 PEs of a process push into the same 23 input buffers while each owner drains its own. So the extra cost is contention and cache-line transfers on the input buffers, which grow with the receive rate.
  - Hand-offs take about 77,500 × 6.2 µs ≈ 0.48 s per PE in a run with 2.6 s of execution (WPs, uniform, 16 nodes), about 18% of each PE's time. And they land unevenly per wave, on whichever PE is the late one (section 105).

**What this means for the thinning question.** The fixed per-message cost of section 105 is almost entirely the per-PE hand-off. Its size is set by contention, not by the work itself. Two ways to cut it:
1. **Make a push cheap.** Use a lock-free input buffer: one single-producer queue per (receiving PE, destination PE) pair, which the owner polls, or a multi-producer list with one atomic exchange per push. Then a push is a cache-line write, not a contended mutex. If pushes return to about 0.2 µs, a uniform receive at 16 nodes drops from 8.5 to about 4 µs. That would save roughly 0.3–0.35 s of the 2.6 s per PE, with more in the late PE's waves.
2. **Fewer pushes per event:** larger messages, from fewer destinations. 2D routing gets this only at the cost of a second hop, which also pays a receive.

(1) is local to htram's receive path and keeps one hop, so it comes first.

### §115 · What paces GVT at σ 2,000: events in transit or the late PE's work; GVT bucket size; horizon margin with wider windows (design, 2026-10-27; written before any runs)

> **Status: design.** Charades `scale-diag` cedf3d7 (new trace fields), htram `pdes` 699c3a9, Reconverse 22871c6; the current launch (`+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free`, ring input buffers). Job P `$WORK/charades-runs/diag19.slurm` (16 nodes, skx-dev and skx, `-x c455-081`, the copy that starts second cancelled).

**Why.** σ ≥ 2,000 is where Charades still scales worse than Devastator: 4→16-node efficiency 0.81 at σ 2,000 against 0.91 (section 95). Matching 0.91 at the same 4-node rate needs about 12% more throughput on 16 nodes, roughly 25 µs off a 16-node GVT advance or 12% more simulated time per advance. What is known:
- The loss is time per advance (section 78).
- Most of an advance is the late PE (section 80). After pickup it runs about 55 events at 1.9 µs each (section 105).
- Faster reductions, earlier contributions, smaller batches, asking ahead and flush order moved throughput by −12% to +6% (sections 47–60, 103).
- Section 60: buckets that every PE had passed often did not complete in the next wave because events sent into them were still in transit.

Two explanations fit:
- **(a) Aggregation-paced.** htram holds an event until GVT nears its timestamp (the deadline policy, horizon W + margin 8). So each GVT step waits for: senders learn of the update → flush what is now due → the events arrive → the next wave counts them. The late PE is late because a burst of such events reached it late.
- **(b) Statistical.** The late PE simply has the most work inside the window. The maximum over 736 PEs grows with the PE count.

**New trace fields** (off unless traced):
- PE 0's `gvt_trace.csv`, per wave: how many buckets every PE had passed at the previous wave, and the events sent into the ones of them that did not complete but not yet received (the first such bucket, and all of them).
- `--gvt-trace=4`'s `gvt_rec_<pe>.csv`, per PE per recorded wave: events received since its previous contribution, how many were within one bucket of GVT, and their mean and least distance from GVT in buckets.

Mac: trace configs 54/54.

**Runs** (PP 512, 2 reps, interleaved):
- **A. Traced** (`--gvt-trace=4 --pe-stats=1`) with untraced pairs: σ 2,000 at W 400 on 4 and 16 nodes; at W 250 and 600 on 16 nodes.
- **B. GVT bucket size** 8 (default), 16 and 32: σ 2,000 and σ 4,000, W 400 and the controller, 4 and 16 nodes. Never varied before.
- **C. Horizon margin** 4, 8 and 16 with W 400 and 600: σ 2,000, 16 nodes. Section 80 varied the margin alone (8, 32, 64, 128), at W 250.

**Predictions:**
- P1. At 16 nodes, in at least half of the waves some bucket that every PE had passed at the previous wave stays open with events in transit. At 4 nodes, in fewer waves.
- P2. Since its previous contribution, the late PE has received at least 1.5× the events of the median PE of its process, and a larger share of them within one bucket of GVT.
- If P1 and P2 hold, GVT is aggregation-paced, and the fix is to send the events GVT will need next before it needs them (candidate (a)). If both are wrong, the straggling is statistical, and the fix is sharing work within a process (candidate (b)).
- P3. Bucket size 16 and 32 change throughput by less than 5% either way.
- P4. No margin and window pair in C beats margin 8 at W 400 by more than 3%.

### §116 · What paces GVT at σ 2,000, results: neither transit nor a growing straggler; the cross-process reduction (34 → 70 µs) is the whole 4→16-node loss (2026-10-27; skx-dev batch job 3649213, 16 nodes)

> **Status: superseded in part by section 120:** the measurements stand, but the conclusion that the reduction floor causes the 4→16-node loss is wrong (the floor overlaps the late PE's work). Design and predictions in section 115. 16 nodes (c454-013, c454-022, c454-032, c454-033, c454-072, c454-073, c454-084, c454-092, c454-093, c454-101, c455-004, c455-011, c455-031 to -033, c455-071; 4-node runs on the first four), 78 runs, all ok; 8 min. Current launch (`+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free`, ring input buffers). Summary `~/charades-data/sdiag/sdiag19_summary.py`, output and CSVs in `~/charades-data/sdiag/j3649213/`; the advance split below was computed inline from the `gvt_waves_*.csv` files, as in section 80.

**Throughput, σ 2,000, PP 512** (M committed events/s, mean of 2 reps; higher is better): W 400: 125.4 on 4 nodes and 442.5 on 16, a **4→16-node efficiency of 0.88** (0.81 in section 95 under the old launch; Devastator 0.91 there). On 16 nodes, W 250 is 403.8 (0.91× W 400) and W 600 is 392.2 (0.89×). Traced ÷ untraced: 0.95–0.99.

**A GVT advance, split** (µs, waves 10–95%, both reps; lower is better; definitions as in section 80):

| W | nodes | advance | reduction floor | median process work | slowest process work | straggler cost | spread inside the slowest process |
|---|---|---|---|---|---|---|---|
| 400 | 4 | 196 | 34 | 55 | 161 | 106 | 145 |
| 400 | 16 | 226 | **70** | 43 | 154 | **111** | 138 |
| 250 | 16 | 198 | 60 | 32 | 136 | 104 | 126 |
| 600 | 16 | 280 | 62 | 42 | 217 | 174 | 194 |

**Waves** (PE 0's trace): in every wave at every setting, all buckets that every PE had passed at the previous wave complete (W 400: 8.7 per wave on 4 nodes, 9.6 on 16). No passed bucket was ever left open with events in transit.

**The late PE against the median PE of its process** (W 400): the late PE contributes 157–159 µs after the result on both 4 and 16 nodes, after running 92 (4 nodes) or 54 (16 nodes) events since picking the result up. The median PE runs about 1 event and contributes after 21–23 µs. The late PE picks the result up later on 16 nodes (41 against 19 µs; it is in the middle of a scheduler pass). Since its previous contribution it has received 1.07× (4 nodes) to 1.24× (16 nodes) the events of the median PE. **None of either PE's arrivals came within one bucket of GVT**: they arrive on average about 160 buckets (1,300 time units) ahead of it. Rank 0 is the most frequent late PE (0.12–0.21 of waves; the lower-edge effect of sections 84–103).

**B. GVT bucket size** (÷ bucket 8, PP 512, mean of 2 reps; higher is better): 16 and 32 are 0.976–1.010 in all 16 cells (σ 2,000 and 4,000, W 400 and the controller, 4 and 16 nodes).

**C. Horizon margin × window** (σ 2,000, 16 nodes; ÷ margin 8 at W 400; higher is better):

| margin | W 400 | W 600 |
|---|---|---|
| 4 | 1.007 | 0.898 |
| 8 | 1.000 (438.6 M ev/s) | 0.896 |
| 16 | 0.996 | 0.886 |

Efficiency is 99.84–99.93% at W 400 and 99.0–99.1% at W 600. Events per message are 43–51 at W 400 and 25–27 at W 600.

- **P1 wrong.** GVT never waits on events in transit; every passed bucket completes in the next wave.
- **P2 wrong.** The late PE received only 1.07–1.24× the median PE's events, and none of them close to GVT. So GVT is not aggregation-paced (explanation (a) is out).
- **Explanation (b) is half right.** The straggler is real (about 110 µs of a 226 µs advance): one PE still has events inside the window while the rest are blocked by it. But **it no longer grows with the node count** (106 → 111 µs, slowest process work 161 → 154). In section 80, under the old launch, it grew by 40 µs.
- **What grows is the reduction floor: 34 → 70 µs, the whole +30 µs per advance from 4 to 16 nodes.** This is the slowest process's wait from its last PE's contribution to the published result: the combine across 32 processes and the result's way back. Section 52 found an all-reduce no faster than the nodegroup reduction (0.96–1.02×) when the straggler dominated. The straggler's growth is gone now, so the floor is what limits scaling.
- **P3 right.** Bucket size changes nothing (−2.4% to +1.0%).
- **P4 right.** The margin changes nothing at W 400 (±0.7%), and a wider window loses 10–11% at any margin.

**Next (withdrawn in section 120: the floor is not on the critical path).** Make the cross-process combine fast. A 32-process reduction of a few hundred bytes should take about 10–15 µs on Omni-Path, not 70.
1. Measure where the 70 µs goes, per hop: the message in flight, waiting for a PE to run the nodegroup handler (PEs run handlers only between scheduler passes of up to 16 events, about 30 µs), and combining.
2. Then reduce what dominates. If it is waiting for a PE, run GVT reduction messages promptly: check for them inside the execute loop, or give them to the free core each process already leaves idle. If it is hops, use fewer: the existing recursive doubling (`--gvt-wave-allreduce`, 5 hops), a two-level exchange (2 hops), or one all-to-all exchange of counts (1 hop, 31 small messages per process per wave).

### §117 · Where the cross-process reduction's 70 µs goes: Charades' own process tree with per-hop times; a flat tree; smaller scheduler passes (design, 2026-10-27; written before any runs)

> **Status: design.** Charades `scale-diag` (this commit: `--gvt-wave-tree`), htram `pdes` 699c3a9, Reconverse 22871c6; the current launch (`+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free`, ring input buffers). Job Q `$WORK/charades-runs/diag20.slurm` (16 nodes, skx-dev and skx, `-x c455-081`, the copy that starts second cancelled).

**Why.** Section 116: at σ 2,000 the reduction floor (the slowest process's wait from its last PE's contribution to the published result) grows from 34 µs on 4 nodes to 70 µs on 16, and that is the whole 4→16-node loss. A combine of a few hundred bytes across 32 processes should take about 10–15 µs on Omni-Path.

**How the reduction runs now.** The last PE of a process combines its PEs' counts and sends them to its own process's nodegroup handler (one hop through the node queue). The handler contributes to the Charm++ nodegroup reduction, which goes up a spanning tree of processes with fan-out 4 (`ST_RecursivePartition`, about 2 levels at 8 processes and 3 at 32). The result comes back down Reconverse's spanning-tree node broadcast. Every hop is a nodegroup message that waits until some PE of the receiving process runs it, and PEs run messages only between scheduler passes of up to 16 events (`--batch`, about 30 µs on the late PE). These hops are inside Charm++ and cannot be timed from Charades.

**New option `--gvt-wave-tree=k`** (with `--gvt-node-waves`; 0, the Charm++ reduction, stays the default):
- The processes form a k-ary tree rooted at process 0 (children of p are pk+1 … pk+k). The partial sums go up it in Charades' own messages and the result comes back down the same tree; k ≥ processes − 1 is one gather to process 0 and one scatter (2 hops).
- No hop to the process's own handler: the last PE in adds its process's sums itself, under a lock. Inputs from children are added by whichever PE runs their message.
- `--gvt-trace=2` writes `gvt_hops_<process>.csv`: every input (a child's sums, the parent's result, this process's own sums) with the sender's send time and this process's receive time, and when each process sent on. Clocks differ between nodes, so each parent–child pair's offset is taken offline from the fastest up and fastest down hop in windows of 200 waves (the two directions' fastest hops are assumed equal). A hop's time beyond its pair's fastest is time spent waiting for a PE to run it, or in network queues.
- `gvt_waves_<process>.csv` gains `handled_s`: when the process's handler took its own sums (the Charm++ path's first hop).

Mac: 54/54 on the tree configs (2, 3, 4 processes × 2 PEs; fan-out 2 and 64; bucketed, window, PP aggregation, controller, trace 2), and 252/252 on a 20-repeat pass. The job first runs the same configs through `test.py` on 2 nodes with the psm2 transport and stops if any fails.

**Runs** (σ 2,000, W 400, PP 512, 2 reps, interleaved; 4 and 16 nodes):
- **A. Reduction:** the Charm++ reduction; `--gvt-wave-tree=4` (about as deep as the Charm++ tree); `--gvt-wave-tree=64` (flat); `--gvt-wave-allreduce=1` (recursive doubling, 3 or 5 rounds). Each traced (`--gvt-trace=2`) and untraced.
- **B. Smaller passes:** `--batch` 4 and 8 (default 16) with the Charm++ reduction, untraced; traced at 16 nodes.
- **C. Other workloads, 16 nodes:** σ 4,000 (PP 512) and uniform (WPs 512), W 400 and the controller, the Charm++ reduction against the flat tree, untraced.

**Predictions:**
- P1. On the Charm++ path, the first hop (last PE → its process's handler) has a median under 3 µs at both node counts: the floor is in the cross-process hops.
- P2. With `--gvt-wave-tree=4` at 16 nodes, the median hop is at least twice its pair's fastest hop (fastest about 3–5 µs, median 8–15 µs): hops wait for a PE to run them.
- P3. The fan-out-4 tree's floor is within 15% of the Charm++ reduction's at 16 nodes, so its hops stand for the Charm++ ones.
- P4. The flat tree's floor at 16 nodes is at most 45 µs, and its throughput at least 1.05× the Charm++ reduction's (σ 2,000, 16 nodes); within ±3% at 4 nodes. In C, no cell below 0.97×.
- P5. If hops wait for PEs (P2), `--batch=4` lowers the 16-node floor by at least 10 µs; its throughput is within ±5% of batch 16, because every pass costs a scheduler turn.
- P6. Recursive doubling stays within ±4% of the Charm++ reduction (section 52).

If P2 and P4 hold, the fix is the flat tree (or a 2-level one) plus prompt handling of GVT messages; if hops are fast and the flat tree does not help, the floor is in the network or the send path, and the next step is timing Reconverse's send and receive of these messages.

### §118 · Where the reduction's time goes, results: a hop's network time is about 4 µs; the rest is waiting for a PE to run the message. Fewer hops do not help (2026-10-27; skx-dev batch job 3649717, 16 nodes)

> **Status: current.** Design and predictions in section 117. 16 nodes (c454-004, c454-023, c454-034, c454-041 to -043, c454-074, c454-081, c454-102, c454-104, c455-012, c455-014, c455-073, c455-074, c455-091, c455-092; 4-node runs on the first four), 62 runs, all ok; gate 54/54 on 2 nodes (psm2); 8 min. Summaries `~/charades-data/sdiag/j3649717/sdiag20_summary.py` and `sdiag20_crit.py`, with their output (`summary.txt`, `crit.txt`) and the CSVs. The traces stay in `$WORK/charades-runs/sdiag20/j3649717`.

**Throughput and a GVT advance, σ 2,000, W 400, PP 512** (mean of 2 reps; advance and floor in µs, waves 10–95%, from the traced runs; floor as in section 116):

| reduction | M ev/s, 4 nodes | M ev/s, 16 nodes | ÷ Charm++ reduction, 16 nodes (higher is better) | efficiency 4→16 | advance, 4 / 16 nodes (lower is better) | floor, 4 / 16 nodes (lower is better) |
|---|---|---|---|---|---|---|
| Charm++ reduction (default) | 126.3 | 443.6 | 1.000 | 0.88 | 194 / 223 | 32.8 / 71.8 |
| `--gvt-wave-tree=4` | 125.9 | 441.4 | 0.995 | 0.88 | 195 / 227 | 31.8 / 77.6 |
| `--gvt-wave-tree=64` (flat) | 123.8 | 379.4 | **0.855** | 0.77 | 198 / 253 | 26.5 / 54.8 |
| `--gvt-wave-allreduce=1` | 125.9 | 436.6 | 0.984 | 0.87 | 192 / 219 | 15.1 / 36.7 |

Traced ÷ untraced: 0.985–0.995. Recursive doubling's floor is not comparable with the others: the slowest process finds its partners' sums already waiting, so its own wait is short, but the other processes wait for its sums to spread through all 5 rounds. Its advance is the fair measure, and that is no better.

**Per hop, tree with fan-out 4** (µs, offset-corrected; lower is better):

| nodes | up: fastest / median / p90 | down: fastest / median / p90 | on the path the slowest process waits on, beyond the pair's fastest (mean): up / down |
|---|---|---|---|
| 4 | 3.9 / 14.0 / 29.0 | 3.9 / 7.5 / 20.1 | 13.0 / 6.8 |
| 16 | 4.0 / 12.7–15.4 / 25.8–30.3 | 4.0 / 7.8–8.3 / 20.6–21.6 | 16.5 / 7.1 |

- The ranges at 16 nodes are over the 3 tree levels; the level makes no difference.
- The first hop on the Charm++ path (last PE → its process's handler) takes 3.8–4.1 µs (median); with the tree it is 1.7 µs, a lock.
- Every PE of a process runs hops about equally often (each rank 0.04–0.05 of them).
- At 76–81% of tree nodes, the last input to arrive is the process's own PEs. The child's sums come last on the path from the slowest process to the root.

**What the hops add up to** (16 nodes, fan-out 4, 3 levels): 6 hops at about 4 µs is 24 µs of network time. The rest of the 72–78 µs floor is the critical path's up hops waiting about 16 µs each and its down hops about 7 µs each, plus the 2–4 µs first hop. Up hops wait longer because they arrive while the parent's PEs are still executing their passes. Down hops arrive when most PEs are blocked on the window and back in the scheduler often.

**Flat tree:** the root's 31 sends of the result take 45 µs from first to last (1.5 µs each, serially), and 31 children's sums arriving at one process wait longer (up median 18 µs). So the 2-hop tree loses 15% at 16 nodes.

**B. Smaller scheduler passes** (Charm++ reduction; ÷ batch 16; higher is better):
- **Batch 4:** 0.894 (4 nodes), 0.893 (16 nodes); 16-node floor **71.8 → 44.0 µs**, advance 223 → 241 µs.
- **Batch 8:** 0.932 (4 nodes), 0.960 (16 nodes); 16-node floor 51.3 µs, advance 222 µs.

The floor falls with the pass size, so the hops wait for a pass to end. But smaller passes on every PE cost more than they save.

**C. Flat tree ÷ Charm++ reduction, 16 nodes** (higher is better): σ 4,000 0.847 (W 400) and 0.910 (controller); uniform 0.998 and 0.956.

- **P1 half right.** The first hop is 3.8–4.1 µs, a little over 3. But it is a small part of the floor; the floor is in the cross-process hops.
- **P2 right.** Fastest hop about 4 µs, median up hop 13–15 µs (3.5×), median down hop 7.5–8 µs (2×).
- **P3 right.** The fan-out-4 tree's floor is 8% above the Charm++ reduction's (77.6 against 71.8 µs), at 0.995× the throughput. Its hops stand for the Charm++ ones.
- **P4 wrong.** The flat tree is 0.855× at 16 nodes and 0.98× at 4; C goes down to 0.847×. Serial sends and fan-in at the root cost more than the hops saved.
- **P5 right on the floor (−28 µs at batch 4), wrong on the throughput.** Batch 4 is 0.89× and batch 8 0.96×.
- **P6 right.** Recursive doubling: 0.984× (16 nodes), 0.996× (4 nodes).

**Next.** At 4 µs a hop, the 16-node floor would be about 26 µs instead of 72 µs, which is 20% of a 223 µs advance. Reconverse has no immediate messages and no communication thread: a message waits until the PE that polls its network device, and then some PE of the process, comes back to the scheduler. Candidates:
1. **Shorter passes only while a wave is in flight.** A PE whose process has contributed runs passes of 2–4 events until the result arrives. This is a Charades change of about 20 lines. Batch 4 everywhere cut the floor by 28 µs; this would pay the smaller passes' cost only during the wave, but only if the PEs that must run the hops are the ones taking shorter passes.
2. **Find which wait it is:** the device poll or the queue. Time stamp in Reconverse when the receiving PE takes the message off its device, against when the handler starts.
3. **Run GVT messages on the free core.** One core per process is unused (2 × 23 PEs on 2 × 24 cores). A Reconverse thread there could poll the devices and run messages marked immediate at once. This is the most complete fix, but the largest change.

### §119 · Shorter scheduler passes only while a count wave is in flight (`--wave-batch`) (design, 2026-10-27; written before any runs)

> **Status: design.** Charades `scale-diag` (this commit: `--wave-batch`, `--wave-batch-when`), htram `pdes` 699c3a9, Reconverse 22871c6; the current launch. Job R `$WORK/charades-runs/diag21.slurm` (16 nodes, skx-dev and skx, `-x c455-081`, the copy that starts second cancelled).

**Why.** Section 118: each hop of the cross-process reduction takes about 4 µs on the network but waits for a PE to come back to the scheduler. On the critical path, the wait is about 16 µs per up hop and 7 µs per down hop. `--batch=4` on every pass cut the 16-node floor from 72 to 44 µs but cost 11% overall.

**New option `--wave-batch=k`** (with `--gvt-node-waves`; 0, off, is the default): the scheduler pass is k events instead of `--batch` (16) while a count wave is in flight.
- `--wave-batch-when=0` (default): from when this process's combined sums are sent until its result is published. Every PE of the process has contributed by then, so every PE that could run a hop for it takes short passes. The process also takes short passes while it combines its children's sums, and when the result reaches it, its PEs pick the result up sooner.
- `--wave-batch-when=1`: from when this PE contributes until it runs the result. This also covers the PEs that contribute early and wait for the late PE of their own process.
- A short pass that runs all k events counts as full, so the idle flush and GVT trigger behave as with a full pass of 16.

Mac: 30/30 on the new configs and their bases (1×4, 2×2, 4×2), and 258/258 on a 20-repeat pass. The job first runs them through `test.py` on 2 nodes with the psm2 transport and stops if any fails.

**Runs** (2 reps, interleaved; Charm++ reduction unless stated):
- **A. σ 2,000, W 400, PP 512, 4 and 16 nodes, untraced:** batch 16 (the baseline); `--wave-batch` 2, 4 and 8 (when 0); `--wave-batch=4 --wave-batch-when=1`.
- **A'. Traced (`--gvt-trace=2`), 16 nodes:** the baseline, `--wave-batch=4` (both triggers), and `--gvt-wave-tree=4` with and without `--wave-batch=4` (for the per-hop times).
- **B. Other workloads, 16 nodes:** σ 100 and σ 4,000 (PP 512) and uniform (WPs 512), W 400 and the controller, the baseline against `--wave-batch=4`.

**Predictions:**
- P1. `--wave-batch=4` cuts the 16-node floor from about 72 µs to 50 µs or less.
- P2. Its throughput at 16 nodes (σ 2,000) is at least 1.04× the baseline, and at 4 nodes at least 1.00×. A wave is in flight for about a third of each advance, so a third of batch 4's 11% cost, about 4%, against a floor about 22 µs (10% of an advance) shorter.
- P3. `--wave-batch-when=1` is no better than when 0. Early PEs take short passes for most of the wave, which costs more and does not shorten the hops.
- P4. In the fan-out-4 tree, the critical-path up-hop wait falls from about 16 µs to 8 µs or less, and the down-hop wait from about 7 µs to 4 µs or less.
- P5. In B, no cell is below 0.98×.

If P1 and P2 hold, `--wave-batch` becomes the default at the best k and goes into the paper-grade rerun. If the floor falls but throughput does not rise, the short passes cost too much, and the next step is the free core (section 118, candidate 3).

### §120 · `--wave-batch`, results: the floor falls by 27 µs but the advance does not; the floor was never on the critical path. The late PE's 128 events pace each advance (2026-10-27; skx-dev batch job 3650537, 16 nodes)

> **Status: superseded in part by section 121:** the `--wave-batch` measurements and the count-paced advance stand; the late PE's steady loss is 4% of simulated time, not the 4→16-node loss, and the arrival-burst explanation fails (htram receives are 0.5–2.1 µs per wave). Design and predictions in section 119. 16 nodes (c454-014, c454-024, c454-033, c454-084, c454-091, c454-092, c454-103, c455-003, c455-004, c455-011, c455-014, c455-031 to -033, c455-043, c455-044; 4-node runs on the first four), 56 runs, all ok; 7 min. Gate 30/30 at the second try. The first attempt in this job, and job 3650177 before it, each lost one test to /work2 failing to read `liblci-ucx.so` (Input/output error); the job now reruns the gate once when that is the only failure. Summary `~/charades-data/sdiag/j3650537/sdiag21_summary.py`, output and CSVs alongside.

**A. Throughput, σ 2,000, W 400, PP 512, Charm++ reduction** (M committed ev/s, mean of 2 reps; ÷ batch 16; higher is better):

| pass size | 4 nodes | ÷ batch 16 | 16 nodes | ÷ batch 16 | efficiency 4→16 |
|---|---|---|---|---|---|
| batch 16 (default) | 127.0 | 1.000 | 443.8 | 1.000 | 0.87 |
| `--wave-batch=2` | 119.2 | 0.939 | 404.9 | 0.912 | 0.85 |
| `--wave-batch=4` | 122.5 | 0.965 | 414.2 | 0.933 | 0.85 |
| `--wave-batch=8` | 124.8 | 0.983 | 434.6 | 0.979 | 0.87 |
| `--wave-batch=4`, when 1 | 119.1 | 0.938 | 410.6 | 0.925 | 0.86 |

**A'. A GVT advance, 16 nodes, traced** (µs, waves 10–95%, both reps; lower is better):

| setting | advance | floor | critical-path wait per hop, up / down (mean) |
|---|---|---|---|
| batch 16 | 224 | 74.9 | — |
| `--wave-batch=4` | 226 | **47.9** | — |
| `--wave-batch=4`, when 1 | 231 | 39.4 | — |
| tree 4, batch 16 | 223 | 75.3 | 17.5 / 8.7 |
| tree 4, `--wave-batch=4` | 226 | 50.4 | **8.8** / 6.1 |

**B. `--wave-batch=4` ÷ batch 16, 16 nodes** (higher is better): σ 100 0.984 (W 400) and 0.956 (controller); σ 4,000 0.927 and 0.976; uniform 0.937 and 0.966.

- **P1 right.** The floor falls from 75 to 48 µs (39 µs with when 1).
- **P2 wrong.** Throughput falls: 0.933× at 16 nodes and 0.965× at 4. **The advance stays at 224–226 µs** although the floor is 27 µs shorter.
- **P3 right.** When 1 is no better (0.925×).
- **P4 right on the up hops** (17.5 → 8.8 µs). The down hops improve less (8.7 → 6.1 µs, prediction ≤ 4).
- **P5 wrong.** σ 4,000 and uniform at W 400 drop to 0.927–0.937×.

**Why the advance did not shrink: section 116's split was an accounting identity, not a critical path.** The late PE contributes by count, after 128 events since its previous contribution, in 93–99% of waves (section 116). So the time between its contributions, which is the advance, is the time it takes to run 128 events. The reduction runs while it keeps executing. A shorter floor means it picks the result up earlier, but it still contributes only after its 128th event. From section 116's records (job 3649213, W 400; assuming 128 events between contributions):

| nodes | advance (µs) | per event, overall (µs; lower is better) | per event before it picks up the result (µs) | per event after it picks up the result (µs) | arrivals per wave, late PE ÷ median PE |
|---|---|---|---|---|---|
| 4 | 196 | 1.53 | 1.56 (36 events) | 1.52 (92 events) | 1.07 |
| 16 | 226 | 1.77 | 1.48 (74 events) | **2.15** (54 events) | 1.24 |

So the 4→16-node loss is the late PE running its events more slowly after it picks up each result: 2.15 against 1.52 µs per event, about +30 µs per advance. That is when GVT has just advanced, the other PEs leave the window and send, and the late PE receives a burst (174 arrivals per wave on 16 nodes against 144 on 4). **The reduction floor is not the cause, and section 116's "Next" is withdrawn.** The section 116 numbers themselves stand. Section 118's per-hop times stand too: hops do wait for a PE, but that wait is hidden behind the late PE's work.

`--wave-batch` stays off (default 0). The option and `--gvt-wave-tree` remain as diagnostics.

**Next.** Find what slows the late PE after pickup on 16 nodes: receiving (the htram receive parts and input-buffer drains, `--gvt-trace=3`'s per-PE timers), rollbacks, or fossil collection, split by before and after pickup. Then make that PE cheaper, or give it less: the late PE is rank 0 in 15–18% of waves (the lower-edge effect, sections 84–103).

### §125 · Uniform's steady loss: thinner htram messages or more destinations? A buffer-size perturbation on 4 nodes (analysis of existing traces and design, 2026-10-27; written before any runs)

> **Status: design.** Analysis from job 3650843's traced uniform runs (`--gvt-trace=2`, WPs 512, W 400, short runs; script `uni_steady.py` in `~/charades-data/sdiag/j3650843/`). Job U: Charades `scale-diag` 4e6d8b8 (defaults), htram 699c3a9, Reconverse 22871c6, the current launch; `$WORK/charades-runs/uni24.slurm` (16 nodes, skx-dev and skx, `-x c455-081`), submitted after job T (one job per dev queue).

**Closure.**
- **Uniform's 4→16-node loss is 81% steady-state** (section 122).
- **In the steady state, time per simulated bucket accounts for all of it:** 24.5 µs on 4 nodes against 31.8 µs on 16 (ratio 0.77, the steady efficiency). A 16-node wave completes more buckets (9.5 against 8.4) but takes longer (300 against 207 µs).
- **σ 4,000 has no steady loss:** 23.7 against 23.5 µs per bucket.

**What differs between them** (job 3650843, untraced, 2 reps):

| workload | events per htram message, 4 / 16 nodes (higher is better) | remote sends per committed event, 4 / 16 nodes | time per bucket, 4 / 16 nodes (µs; lower is better) |
|---|---|---|---|
| uniform (WPs 512) | 31.1 / **12.4** | 1.006 / 1.002 | 24.5 / 31.8 |
| σ 4,000 (PP 512) | 46.0 / 45.6 | 1.004 / 1.000 | 23.7 / 23.5 |

On 16 nodes a uniform event goes to one of 32 processes instead of 8. Each PE's per-destination buffers fill 4× more slowly and are flushed by the deadline policy with fewer events, so there are 2.5× as many messages per event (0.032 → 0.081). Two explanations fit:
- **(H1) Thinning:** each message has a fixed cost (sending, network progress, the receive's fixed part), and there are more messages per event. If H1 holds, the PE time per event (1.58 → 2.10 µs) implies about 10.6 µs of PE time per extra message.
- **(H2) More destinations:** the flush scans and per-destination bookkeeping grow with the number of destination buffers, whatever the message count.

**Perturbation.** Cap the WPs buffer on 4 nodes so that messages are as thin as on 16 nodes, without adding destinations. A buffer of 16 events allows at most 16 events per message (now 31). Runs (uniform, W 400, short runs, 2 reps):
- **A. 4 nodes:** WPs 512 (default), 64, 32 and 16, untraced. Also WPs 512 and 16 traced (`--gvt-trace=4`), for the late PE's time split.
- **B. 16 nodes:** WPs 512 and 16, untraced. Also WPs 512 traced (`--gvt-trace=4`).

**Predictions:**
- U1. Under H1, 4-node WPs 16 lowers throughput by at least 15% (time per bucket 24.5 → 28.8 µs or more). The slope, extra PE time per extra message, comes out at 10.6 µs ± 30%, so thinning would account for the whole 4→16 steady loss. Under H2, WPs 16 costs less than 5%.
- U2. WPs 32 and 64 on 4 nodes are within ±3% of WPs 512 (messages already carry about 31 events).
- U3. On 16 nodes, WPs 16 is within ±5% of WPs 512 (messages already carry about 12).

If U1 holds with the slope: uniform's loss is the per-message cost under thinning. The fixes are then:
- fewer, fuller messages at 16 nodes: aggregating by destination node through an intermediate PE (2-D routing), or a longer horizon for far destinations;
- or a cheaper message: its send and receive path, priced from the traced split.

If U1 fails, H2 is next: the cost per destination buffer.

### §126 · Uniform's buffer perturbation, results: thinning explains only 16% of the loss; 45% is inside `execute()`, which the timers do not split (2026-10-27; skx-dev batch job 3651140, 16 nodes)

> **Status: current.** Design and predictions in section 125. 16 nodes (c454-001, c454-002, c454-021, c454-043, c454-044, c454-073, c454-083, c454-084, c455-041, c455-042, c455-083, c455-084, c455-091, c455-092, c455-103, c455-104; 4-node runs on the first four), 20 runs, all ok; 5 min. Summaries `~/charades-data/uni24/uni24_summary.py` and `pe_split.py`, with `summary.txt`, `pe_split.txt` and the CSVs in `~/charades-data/uni24/j3651140/`.

**Buffer sizes** (uniform, W 400, short runs, mean of 2 reps; M committed ev/s, higher is better; PE time per committed event = PEs ÷ rate, lower is better):

| nodes | WPs buffer | M ev/s | ÷ WPs 512 | events per message | messages per event | PE time per event (µs) |
|---|---|---|---|---|---|---|
| 4 | 512 | 115.1 | 1.000 | 30.9 | 0.0325 | 1.598 |
| 4 | 64 | 115.6 | 1.004 | 30.8 | 0.0327 | 1.592 |
| 4 | 32 | 121.5 | **1.056** | 26.3 | 0.0382 | 1.514 |
| 4 | 16 | 111.3 | 0.967 | 15.4 | 0.0650 | 1.653 |
| 16 | 512 | 350.5 | 1.000 | 12.4 | 0.0811 | 2.100 |
| 16 | 16 | 365.5 | **1.043** | 11.4 | 0.0878 | 2.014 |

- **U1 wrong.** Twice the messages per event on 4 nodes (WPs 16) costs 3.3%: **1.7 µs of PE time per extra message**, against the 10.3 µs that thinning would need to explain the 4→16 loss. At that slope thinning accounts for **16%** of the rise in PE time per event from 4 to 16 nodes.
- **U2 half wrong.** WPs 64 is equal to 512, but **WPs 32 is 1.056× faster**.
- **U3 right, with a sign.** On 16 nodes WPs 16 is within ±5%, but faster: 1.043×.

A smaller buffer sends some events when it fills, before the deadline policy would. PEs then wait less on the window: window-blocked passes per committed event are 0.416 at WPs 512 and 0.358 at WPs 16 on 4 nodes. This is a separate, cheap gain to check on other workloads; it is not the scaling loss.

**Closure over all PE time** (traced runs, `--gvt-trace=4 --pe-stats=1`, WPs 512; µs of PE time per committed event, mean of 2 reps; lower is better):

| part | 4 nodes | 16 nodes | 16 − 4 | share | 4 nodes, WPs 16 |
|---|---|---|---|---|---|
| `execute()` without input-buffer drains | 1.045 | 1.291 | +0.246 | **45%** | 1.014 |
| input-buffer drains | 0.285 | 0.320 | +0.035 | 6% | 0.319 |
| htram receive handlers | 0.140 | 0.232 | +0.092 | 17% | 0.172 |
| everything else (runtime loop, idle) | 0.144 | 0.313 | +0.169 | 31% | 0.201 |
| **total** | 1.613 | 2.155 | +0.542 | 100% | 1.706 |

Per committed event, window-blocked passes rise from 0.416 to 0.549, and htram receives from 0.028 to 0.079 (31.0 → 12.3 items each). `execute()` without drains costs 1.037 µs per executed event on 4 nodes and **1.286 on 16**. The thinner messages of WPs 16 on 4 nodes raise the receives and the rest, but not `execute()`. So the largest piece, +0.246 µs in `execute()`, is not caused by message count.

**What `execute()` contains that grows with the number of processes** (untested; `execute()` is timed only as a whole):
- the idle flush, `agg_flush_idle()`, on every pass that is not full (0.55 per event on 16 nodes), which scans this PE's per-destination buffers: 32 destination processes on 16 nodes against 8 on 4;
- sends: the share of events to the PE's own process (the same-process fast path) falls from 1/8 to 1/32;
- cache footprint: the per-destination buffers touched per pass.

**Next.**
1. Split `execute()`: timers for the idle flush, for remote sends (htram insert), for the same-process fast path and for the event handlers. This closes the +0.246 µs.
2. Then a perturbation of whichever piece dominates, before any fix. For example, if it is the idle flush, flush only when the PE has gone idle k passes in a row, and check that the 16-node time moves by the predicted amount.

### §127 · Splitting `execute()` on uniform at 4 and 16 nodes, against σ 4,000 as a control (design, 2026-10-28; written before any runs)

> **Status: design.** Charades `scale-diag` (this commit: `--gvt-trace=5`), htram 699c3a9, Reconverse 22871c6, the current launch. Job V `$WORK/charades-runs/exec25.slurm` (16 nodes, skx-dev and skx, `-x c455-081`, the copy that starts second cancelled).

**Why.** Section 126: on uniform, `execute()` without input-buffer drains is 45% of the 4→16-node rise in PE time per committed event (+0.246 µs), and more messages do not explain it. `execute()` was timed only as a whole.

**New `--gvt-trace=5`:** each PE writes `exec_parts_<pe>.csv` over the run:
- inside `execute()`: the event loop, the idle flush (`agg_flush_idle`, which with the deadline policy runs htram's `flushDue` over every destination buffer), the cancel queue, the result pickup (`poll`) and the input-buffer drains;
- inside the event loop's sends: GVT counting (`produce`), the same-process fast path (hits and misses), the remote send (htram insert and any flush), and sends to the same chare;
- `iteration_end`, which runs outside the `execute()` timer.

On the Mac (2 processes × 2 PEs, uniform), the parts cover 99.9% of `execute()`. The timers add about 6 calls per pass and 4 per remote send, so traced runs are paired with untraced ones. Mac: trace configs 36/36.

**Runs** (W 400, short runs, 2 reps; `--gvt-trace=5 --pe-stats=1`, each with an untraced pair):
- uniform, WPs 512, 4 and 16 nodes;
- σ 4,000, PP 512, 4 and 16 nodes, as a control: it has no steady 4→16-node loss (section 122).

The event handlers' own time is the loop minus the sends.

**Predictions** (µs per committed event, 4 → 16 nodes, uniform):
- V1. **The idle flush** grows by at least 0.08 and is at least 30% of the +0.25 µs: it scans 32 destination buffers on 16 nodes against 8 on 4, on each of 0.42–0.55 non-full passes per committed event.
- V2. **A remote send costs within 10% the same** on 4 and 16 nodes (an htram insert is constant work). The send total grows only because fewer sends take the fast path: 1/8 of sends on 4 nodes against 1/32 on 16.
- V3. **The event handlers' time per executed event is within ±5%** on 4 and 16 nodes.
- V4. **Control:** on σ 4,000 no part grows by more than 0.03.
- V5. **Closure:** the timed parts cover at least 95% of `execute()`, and traced ÷ untraced is at least 0.90.

Whatever part carries most of the +0.25 µs then gets a perturbation before any fix. For example, if it is the idle flush: run the flush only every k-th non-full pass, and check that the 16-node time moves by the predicted amount.

### §128 · `execute()` split, results: on uniform the event handlers and sends do not grow; half of `execute()`'s rise is applying each GVT result (2026-10-28; skx-dev batch job 3652542, 16 nodes)

> **Status: current.** Design and predictions in section 127. 16 nodes (c454-002, c454-074, c454-081, c454-082, c454-102 to -104, c455-073, c455-074, c455-082 to -084, c455-091, c455-092, c455-103, c455-104; 4-node runs on the first four), 18 runs, all ok; gate 24/24; 5 min. Summary `~/charades-data/exec25/exec25_summary.py`, with `summary.txt` and the CSVs in `~/charades-data/exec25/j3652542/`.

**`execute()` split, uniform (WPs 512) and σ 4,000 (PP 512), W 400, short runs** (µs of PE time per committed event, mean of 2 reps, `--gvt-trace=5`; lower is better):

| part | uniform, 4 nodes | uniform, 16 nodes | uniform, 16 − 4 (share) | σ 4,000, 4 nodes | σ 4,000, 16 nodes | σ 4,000, 16 − 4 |
|---|---|---|---|---|---|---|
| event handlers (loop minus sends) | 0.502 | 0.498 | −0.004 (−1%) | 0.605 | 0.599 | −0.006 |
| remote sends, all parts | 0.322 | 0.332 | +0.010 (4%) | 0.369 | 0.365 | −0.003 |
| **applying the GVT result (`poll`)** | 0.289 | 0.426 | **+0.136 (52%)** | 0.165 | 0.163 | −0.002 |
| input-buffer drains | 0.283 | 0.315 | +0.033 (12%) | 0.260 | 0.258 | −0.003 |
| idle flush | 0.016 | 0.047 | +0.031 (12%) | 0.025 | 0.091 | +0.067 |
| cancel queue | 0.017 | 0.022 | +0.005 (2%) | 0.022 | 0.033 | +0.011 |
| untimed, including the timer calls | 0.172 | 0.225 | +0.052 (20%) | 0.190 | 0.244 | +0.054 |
| **`execute()`** | 1.602 | 1.865 | +0.264 | 1.636 | 1.754 | +0.119 |

Other figures:
- **Event handlers per executed event:** uniform 0.498 → 0.496 µs; σ 4,000 0.600 → 0.597.
- **One remote send** (htram insert, plus any flush it triggers): uniform 0.082 → 0.093 µs; σ 4,000 0.131 → 0.128.
- **Share of sends on the fast path:** uniform 0.124 → 0.031; σ 4,000 0.280 both.
- **One idle flush:** uniform 0.076 → 0.164 µs (0.21 → 0.29 per event); σ 4,000 0.090 → 0.198.
- **Timed share of `execute()`:** 0.86–0.89.
- **Traced ÷ untraced:** 0.85–0.90 (untraced: uniform 116.4 and 348.6, σ 4,000 117.2 and 428.3 M ev/s).

- **V1 wrong.** The idle flush grows by 0.031 (12%), not by at least 0.08 (30%), although each call costs twice as much on 16 nodes (more destination buffers to scan).
- **V2 about right.** A remote send costs 13% more on 16 nodes (predicted within 10%). The send total rises only 0.010.
- **V3 right.** The event handlers' time per event is unchanged.
- **V4 partly wrong.** σ 4,000's idle flush and untimed time grow too. Its whole 4→16 loss in short runs is start-up (section 122), and these are whole-run totals, so this growth is probably start-up; a long-run trace would show it. The GVT result step, which grows on uniform, does not grow on σ 4,000.
- **V5 wrong.** The timers cover 86–89% of `execute()` (predicted ≥ 95%) and cost 10–15% (predicted ≤ 10%). Most of the untimed part is the timer calls and the bookkeeping between them, which grow with the number of passes.

**What `poll` does when a result arrives** (`BucketGVT::poll` → `wave_done` → `gvt_done`):
- fossil collection over every LP on the PE;
- the GVT-time flush (`agg_flush_gvt`), which with the deadline policy runs htram's `flushDue`: every destination buffer holding an event now due is sent;
- the controller's update.

On uniform, a PE's events go to all 32 processes on 16 nodes against 8 on 4. So each GVT update sends up to 4× as many small messages from this step. Messages per committed event rise from 0.032 to 0.081. If all the extra messages went out here, the step's rise (+0.136) would mean about 2.8 µs per message, against 1.7 µs per extra message measured in section 126.

**Status of the uniform loss (+0.54 µs of PE time per committed event, 4 → 16 nodes, section 126):**
- **Not grown:** event handlers, sends.
- **Grown:**
  - applying the GVT result (+0.14);
  - htram receives (+0.09, section 126);
  - the runtime loop and idle outside `execute()` (+0.17, section 126);
  - input-buffer drains (+0.03);
  - the idle flush (+0.03).

Messages per event (section 126) can account for part of the receives and of the GVT result step. These totals are PE time, so they say where the time goes, not which part limits throughput.

**Next.**
1. Split `poll` into fossil collection, the GVT-time flush (with the messages it sends) and the rest. Use long runs, so start-up does not mix in.
2. Then a perturbation of the largest part. For the GVT-time flush, send the due buffers of far destinations less often. For fossil collection, collect every k-th GVT.

### §131 · Is applying a GVT result on uniform's critical path? A known delay in that step, and its parts (design, 2026-10-28; written before any runs)

> **Status: design.** Charades `scale-diag` (this commit: `--diag-gvt-spin-ns`, and fossil collection, the GVT-time flush and the controller update timed under `--gvt-trace=5`), htram 699c3a9, Reconverse 22871c6, the current launch. Job X `$WORK/charades-runs/exec27.slurm` (16 nodes, skx-dev and skx, `-x c455-081`), after job W.

**Why.**
- **Section 128:** on uniform, applying each GVT result (`poll`) is the largest part of `execute()`'s 4→16-node rise: +0.136 µs of PE time per committed event, about 37 → 63 µs per PE per GVT update.
- **What sections 116–120 and 54 teach** (re-read note at the top): time a step takes is not throughput lost unless the step is on the critical path. Every PE applies each result, but most PEs are then blocked on the window anyway; only the PE that paces the advance matters.
- **So the first test is causal, not a split.** It adds a known delay to this one step and checks whether throughput falls as the critical path predicts.

**New `--diag-gvt-spin-ns=N`** (diagnostic, 0 = off): every PE busy-waits N ns each time it applies a GVT result. The split (`--gvt-trace=5`) adds:
- the time in fossil collection;
- the GVT-time flush (`agg_flush_gvt`), with the messages it sends;
- the controller's update;
- the number of results applied.

Mac: 36/36 (the trace and spin configs at 1×4, 2×2 and 4×2; committed counts unchanged by the spin).

**Runs** (uniform, WPs 512, W 400, long runs, end time 2,048,000, 2 reps):
- **A. Spin**, untraced: N = 0, 10,000 and 20,000 (0, 10 and 20 µs), on 4 and 16 nodes.
- **B. Split**, traced (`--gvt-trace=5 --pe-stats=1`), on 4 and 16 nodes.

**Predictions:**
- X1. **If the step is on the critical path** (the pacing PE applies each result once per advance, and its next contribution waits for that), every advance gets longer by N.
  - At 20 µs, throughput falls by about 20 ÷ 300 = 6–7% on 16 nodes and 20 ÷ 207 = 9–10% on 4 nodes (advances from section 125); 10 µs costs half that.
  - **If the step mostly overlaps waiting,** 20 µs costs under 2%.
- X2. **Of the step's 4→16-node rise,** the GVT-time flush is at least half: messages sent per GVT update per PE rise about 3× (to up to 32 destinations instead of 8). Fossil collection per committed event changes by under 10%.
- X3. **Closure:** the step's measured sensitivity times its 4→16 rise per advance gives the share of uniform's loss that this step explains. If X1's critical-path case holds, the rise of about 26 µs per update predicts about 25–30% of uniform's steady loss; a fix would then target the larger of its parts.

If X1's overlap case holds instead, this step is not worth fixing, and the next candidates are the htram receives and the runtime loop (section 126), tested the same way.

### §132 · The GVT-result step, results: on 16 nodes it is fully on the critical path, and the GVT-time flush is 97% of its rise (2026-10-28; skx-dev batch job 3652815, 16 nodes)

> **Status: current.** Design and predictions in section 131. 16 nodes (c454-021 to -023, c454-041 to -044, c454-071 to -073, c454-083, c454-084, c454-091 to -094; 4-node runs on the first four), 18 runs, all ok; gate 24/24; 7 min. Summary `~/charades-data/exec27/exec27_summary.py`, with `summary.txt` and the CSVs in `~/charades-data/exec27/j3652815/`.

**A. A known delay in the step** (uniform, WPs 512, W 400, long runs; M committed ev/s, mean of 2 reps; higher is better). The critical-path prediction is 1 ÷ (1 + delay ÷ µs per GVT update):

| nodes | no delay | 10 µs: measured / predicted | 20 µs: measured / predicted | µs per GVT update | measured ÷ predicted cost |
|---|---|---|---|---|---|
| 4 | 111.1 | 0.971 / 0.956 | 0.939 / 0.915 | 215 | 0.64 |
| 16 | 358.8 | **0.968 / 0.967** | **0.935 / 0.936** | 291 | **0.94** |

**B. The step split** (traced; µs per PE per GVT update; lower is better):

| nodes | the whole step | fossil collection | GVT-time flush | messages it sends | controller | other |
|---|---|---|---|---|---|---|
| 4 | 38.6 | 13.6 | 22.7 | 3.50 | 0.0 | 2.3 |
| 16 | 58.5 | 13.4 | **42.1** | **10.21** | 0.0 | 3.0 |
| 16 − 4 | +19.9 | −0.1 (−1%) | **+19.4 (97%)** | +6.71 | 0.0 | +0.6 (3%) |

- **The two points fit the GVT-time flush** as about 12.6 µs per update plus **2.9 µs per message** sent. (Section 134: this split is wrong. A message costs 6.6 µs on 4 nodes and 4.2 on 16, and sends are 95% of the flush on both.)
- **Per committed event,** the step is 0.300 µs of PE time on 4 nodes and 0.433 on 16 (section 128 had 0.289 and 0.426 on short runs).

- **X1: the critical-path case holds on 16 nodes.** Each microsecond added to the step adds a microsecond to the advance: 0.968 and 0.935 against predicted 0.967 and 0.936. On 4 nodes only about two thirds of it shows: some of the delay there falls on PEs that would have waited anyway.
- **X2 right.** The GVT-time flush is 97% of the step's rise: each PE sends 2.9× as many messages per update (10.2 against 3.5). Fossil collection does not change.
- **X3 right.** As a share of uniform's steady loss (24.5 → 31.8 µs per bucket, section 125), the step's rise per bucket is 31% if both node counts are equally sensitive, and 55% with the measured sensitivities (0.64 and 0.94).

**This is the first piece of uniform's 4→16-node loss that is both measured and shown to be on the critical path.**
- **What a fix is worth:** on 16 nodes, every microsecond taken out of the GVT-time flush shortens the advance by a microsecond.
- **At the limit:** bringing it back to its 4-node cost (−19.4 µs per update) would make uniform about 1.07× faster on 16 nodes (291 ÷ 272). Its WPs-to-WPs 4→16 efficiency would rise from about 0.74 to 0.79, and the best-to-best efficiency (section 124) from 0.67 to about 0.71, against Devastator's 0.70.

**Fix candidates** (not yet chosen; each would be checked against this prediction):
1. **A cheaper message.** About 2.9 µs of the sending PE's time per message: building the htram message, copying the items, and Charm++'s and Reconverse's send path. Time those parts first.
2. **Fewer messages from the PE that paces the advance.** At a GVT update, send only destinations holding events due before the next advance is likely to need them; leave the rest to buffer fills and idle flushes. Risk: the flush-versus-GVT-update race (`--ctl-floor`).
3. **Take the flush off the pacing PE.** A PE that still has events to run inside the window postpones its GVT-time flush to its next idle pass, or another PE of its process sends its buffers. Risk: the events it holds may then be what GVT waits for.

### §145 · Why Charades rolls back more than Devastator at the same window (design, 2026-10-29; written before any runs)

> **Status: design.** First step toward a scaling fix (section 144).

**Why.**
- Charades runs at its window edge. At 16 nodes 95–97% of scheduler batches end blocked by the window (section 47), so its rate follows the GVT update rate one for one (section 132). A late message or a rollback delays a GVT update, and every PE waits; a rollback's cost is mostly this (section 18).
- Devastator runs at W 1,000 with slack to spare.
- Charades can't widen W:
  - At σ 100 on 16 nodes it rolled back 3.1% of executed events at W 600 and 12.7% at W 800, losing 36% and 92% of W 400's rate (section 45, old stack).
  - Devastator rolls back 0.05% at W 1,000 (job 3653806).
- Setting the flush deadline below W was tried (section 5). Receivers ran past held events: 8% stragglers, 47–62% efficiency.
- So before any fix: why does Charades roll back so much more than Devastator at the same W?
  - **Hypothesis H (the hold):** htram's deadline policy sends each held event when GVT makes it due, which is the last moment before some receiver may need it. Any delay in that flush makes a straggler, and a wider W makes more events wait at that edge.
  - **Alternative H′:** Charades' own dynamics, such as coarse GVT steps (about 60 time units per update), let PEs drift apart within the window.
  - Direct sends separate the two: they hold nothing.

**Job R** (`$WORK/charades-runs/roll45.slurm`, 16 nodes; skx-dev copy 3657717 and skx copy 3657718, the later one to start is cancelled; frozen build 0a212f0):
- **Workloads:** σ 100 (htram PP 2,048), σ 2,000 (PP 512), uniform (WPs 512).
- **Run length:** end time 512,000, as section 45. 2 reps, arms interleaved.
- **Arms:**
  - **Charades with htram:** W 400, 600, 800. W 1,200 stalled in section 45.
  - **Charades with direct sends:** W 400, 800, 1,600.
  - **Devastator:** W 400, 800, 1,600 (CLCG4).
  - **GVT delay at σ 2,000:** Charades with htram at W 400 and W 800, with `--diag-gvt-spin-ns=20000` (20 µs on every GVT update). This tests whether a wider W absorbs late GVT updates.
- **Recorded:**
  - rolled-back share;
  - primary stragglers (timestamp rollback calls), split into held by htram, late (delay ≥ W) and the rest;
  - rollbacks caused by anti-messages;
  - events per htram message;
  - throughput.

**Predictions:**
- **R1.** With htram at W 800, Charades' rolled-back share is at least 5× Devastator's at W 800, at σ 100 and σ 2,000.
- **R2 (H).** With direct sends at W 800, Charades' rolled-back share is within 3× of Devastator's. So the excess comes from htram's hold.
- **R3 (H).** With htram at W 800, held stragglers are at least half of the primary stragglers.
- **R4.** With htram, W 800 is slower than W 400 at σ 100 and σ 2,000, as in section 45. With direct sends, W 800 is at least as fast as W 400.
- **R5.** The 20 µs GVT delay costs W 800 at most half the share it costs W 400.

**What follows:**
- **If H holds:** the fix is in when htram sends a held event. Send it ahead of the GVT update that makes it due, at a lower cost than `--agg-flush-ahead`, which doubled messages (section 139).
- **If H′ holds:** the fix is in the scheduler or the GVT step.

### §146 · Why Charades rolls back more than Devastator at the same window, results: not the hold; Charades' own engine makes 5–120× more stragglers (2026-10-29; skx-dev batch job 3657717, 16 nodes)

> **Status: current.** Design and predictions in section 145.
> - **Allocation:** 16 nodes (c454-101, -102, -104, c455-023, -024, -031, -033, -034, -041, -083, -084, -093, -101 to -104), 8 min, gate 30/30. The skx copy (3657718) was cancelled before it started.
> - **Runs:** 54, all ok. Every workload committed the same events in every run of all three engines.
> - **Data:** summary `~/charades-data/roll45/roll45_summary.py`, output in `j3657717/summary.txt`, with the CSVs, Devastator's `results.txt` and every Charades run log.

**Rolled back (% of executed events; lower is better) and M committed ev/s (higher is better), median of 2, end time 512,000:**

| workload | W | Charades htram | Charades direct | Devastator | M ev/s: Charades htram / direct / Devastator |
|---|---|---|---|---|---|
| σ 100 | 400 | 0.058 | 0.083 | 0.000 | 657.6 / 339.0 / 635.2 |
| | 600 | 0.478 | — | — | 551.5 / — / — |
| | 800 | 1.193 | 2.661 | 0.022 | 477.4 / 298.6 / 661.9 |
| | 1,600 | — | 9.597 | 0.309 | — / 303.8 / 656.6 |
| σ 2,000 | 400 | 0.155 | 0.152 | 0.062 | 430.2 / 204.7 / 300.7 |
| | 600 | 1.107 | — | — | 378.6 / — / — |
| | 800 | 4.098 | 3.678 | 0.737 | 282.1 / 188.0 / 357.6 |
| | 1,600 | — | 9.400 | 4.506 | — / 184.3 / 375.4 |
| uniform | 400 | 0.514 | 0.157 | 0.759 | 338.1 / 142.6 / 178.3 |
| | 600 | 2.824 | — | — | 298.7 / — / — |
| | 800 | 9.754 | 8.225 | 4.818 | 253.5 / 132.8 / 199.0 |
| | 1,600 | — | 8.815 | 17.825 | — / 131.6 / 166.1 |

**Primary stragglers with htram** (timestamp rollback calls per million executed events, and the share of them that htram held):

| workload | W 400 | W 600 | W 800 | direct sends, W 800 |
|---|---|---|---|---|
| σ 100 | 130 (68% held) | 484 (13%) | 887 (7%) | 1,347 |
| σ 2,000 | 389 (80%) | 937 (33%) | 2,502 (12%) | 2,153 |
| uniform | 2,068 (95%) | 3,042 (67%) | 5,060 (25%) | 3,791 |

Rollbacks caused by anti-messages are 0–0.2% of rollback calls at W 400 and 12–32% at W 800–1,600.

**Predictions:**
- **R1 right.** With htram at W 800, Charades rolls back 54× Devastator's share at σ 100 (1.19% against 0.022%) and 5.6× at σ 2,000.
- **R2 wrong, so H is out.** With direct sends at W 800, Charades rolls back 121× Devastator's share at σ 100 and 5.0× at σ 2,000. That is as much as with htram, or more.
- **R3 wrong.** At W 800 htram held only 7% (σ 100), 12% (σ 2,000) and 25% (uniform) of the primary stragglers. Held events dominate only at W 400, where stragglers are few (section 139's race).
- **R4 half right.** With htram, W 800 is 0.73× (σ 100) and 0.66× (σ 2,000) of W 400. With direct sends it is 0.88–0.93×, not faster.
- **R5 right.** The 20 µs delay on every GVT update costs W 400 8.6% at σ 2,000 (393.4 against 430.2) and W 800 2.8% (274.2 against 282.1). A wider window absorbs two thirds of a late update.

**What it says:**
- **Charades makes far more stragglers than Devastator at the same W, whatever the transport.** Primary stragglers grow steeply with W: with direct sends at σ 100, 91 per million executed events at W 400, 1,347 at W 800 and 3,872 at W 1,600. Devastator at σ 100 rolls back 0.31% at W 1,600, against Charades' 9.6%.
- **htram is not the cause.** At W 800 it rolls back less than direct sends at σ 100 (1.19% against 2.66%) and about as much elsewhere.
- **So the fix is in Charades' engine (H′), not in when htram sends.** At σ 100 almost all events stay inside the process (fast path), so the stragglers come from other PEs of the same process. Something lets PEs of a process drift much further apart within the window than Devastator's ranks do, or creates stragglers some other way. Candidates:
  - **A laggard PE.** Rank 0 and the edge ranks are known to be late (sections 85–101). A PE far behind sends into its neighbours' past.
  - **Equal timestamps.** A PE rolls back when an event arrives with ts equal to its LP's current time (`<=`), and integer timestamps make ties common.
  - **Lazy delivery inside the process.** Fast-path events wait in an input buffer until the receiver's next pass.
- **Why this is the scaling lever:** a wider window absorbs late GVT updates (R5), and that slack is what Devastator has. If Charades rolled back like Devastator, it could run at W 800–1,600 and keep its aggregation advantage.
- **At W 400 Charades is still ahead** of Devastator's best W on σ 2,000 (1.15×) and uniform (1.70×), and level at σ 100 (0.99×).

### §147 · The rollback unit: LPs per chare at lookahead 100 and wide W (design, 2026-10-29; written before any runs)

> **Status: design.** Follows section 146.

**Why.**
- Charades judges a straggler against its chare's time, not its LP's (`LP::get_current_time()` returns the owner chare's, lp.h:330). It also rolls back the whole chare. With 16 LPs per chare, an event is a straggler if it is earlier than the chare's latest event on any of its 16 LPs, and each straggler undoes every later event of all 16.
- Devastator registers each LP as its own rollback domain (section 68).
- **16 was never chosen by measurement.**
  - It first appears in our first Stampede3 script (`gvt_cost.sh`, 5ca0ac6, 2026-10-19), probably taken from the test harness's `wide` config (e7f3b38, a correctness test for wide chares). Every sweep since copied it.
  - Charades' own PHOLD and traffic test configs use 4.
  - Mikida's thesis (2019, ch. 3) leaves the grouping to the model, as ROSS does with kernel processes, whose purpose is cheaper fossil collection (one history per group). Its profile puts fossil collection at 12% of time.
  - The thesis's only tuned grouping is for locality: dragonfly runs best with one router and its terminal and MPI LPs per chare.
  - It does not discuss what the grouping costs in rollbacks.
- Section 68 suspected this at lookahead 10. On the Mac (lookahead 10, W 100), efficiency rose from 62.8% at 16 LPs per chare to 95.1% at 1 (section 69). The 16-node test was planned but never reported.
- **Rough model:** with exponential delays (mean 900 past the lookahead), an LP's latest event sits on average about 67 time units behind its chare's. So judging by LP removes most stragglers from senders that lag just past the lookahead. Each remaining rollback undoes about 1/16 of the events.
- Job R measured about 20 events rolled back per primary straggler at σ 100, W 800, direct sends.
- The Mac can't test it at lookahead 100: there, rollback shares at 16, 4 and 1 LPs per chare (2–5%) move with thread scheduling, not with the chare size.

**Job L** (`$WORK/charades-runs/lpc47.slurm`, 16 nodes; skx-dev copy 3657892 and skx copy 3657893, the later one to start is cancelled; frozen build 0a212f0):
- σ 100 (PP 2,048), σ 2,000 (PP 512), uniform (WPs 512).
- 16, 4 and 1 LPs per chare; W 400, 800, 1,600.
- End time 512,000, 2 reps, chare sizes interleaved.
- Compared with Devastator's numbers from job R (same nodes' partition, same settings).

**Predictions:**
- **L1.** At W 800, 1 LP per chare cuts the rolled-back share at least 10× against 16 at σ 100 and σ 2,000, to within 3× of Devastator's.
- **L2.** Primary stragglers per executed event fall at least 2× from 16 to 1 LP per chare at W 800, and events rolled back per straggler at least 4×.
- **L3.** With 1 LP per chare the best W is 800 or wider at σ 100 and σ 2,000. Its throughput there is within ±10% of 16 LPs per chare at W 400: the saved rollbacks against the extra scheduler and fossil-collection work per chare (0.87× on the Mac at lookahead 10, section 69).
- **L4.** 4 LPs per chare lies between the two in rolled-back share at every W.

**What follows:**
- **If L1 and L2 hold:** the fix is to roll back one LP inside a chare, judging stragglers by the LP's time. Chares stay large, keeping their scheduling cost, but roll back like Devastator. Then the window can widen.
- **If L1 fails:** the rollback unit is not the cause, and the next step is to trace where stragglers come from: the sender's lag and the depth behind the receiver.

### §148 · The rollback unit, results: one LP per chare cuts rollbacks 5–23× and beats Devastator's at σ 2,000 and uniform; a wider W is still slower, because the flush deadline follows it (2026-10-29; skx-dev batch job 3657892, 16 nodes)

> **Status: current.** Design and predictions in section 147.
> - **Allocation:** 16 nodes (c454-093, c455-002 to -004, -011 to -014, -021, -023, -024, -031, -101 to -104), 9 min, gate 30/30. The skx copy (3657893) was cancelled before it started.
> - **Runs:** 54, all ok. Every workload committed the same events in every run, and the same as Devastator in job R.
> - **Data:** summary `~/charades-data/lpc47/lpc47_summary.py`, output in `j3657892/summary.txt`, with the CSVs and every run log.

**Median of 2, htram, end time 512,000.** Rolled back (% of executed; lower is better), M committed ev/s (higher is better), events rolled back per rollback call, events per htram message:

| workload | W | 16 LPs per chare | 4 | 1 | Devastator (job R) |
|---|---|---|---|---|---|
| σ 100 | 400 | 0.054%, 665.7, 4.3, 35 | 0.017%, 664.7, 2.1, 34 | 0.004%, 597.0, 1.3, 33 | 0.000%, 635.2 |
| | 800 | 1.42%, 470.7, 12.2, 9 | 0.79%, 490.3, 5.4, 9 | 0.28%, 499.7, 2.5, 9 | 0.022%, 661.9 |
| | 1,600 | 5.14%, 301.5, 16.2, 7 | 5.18%, 352.8, 7.1, 4 | 2.00%, 333.3, 3.5, 6 | 0.31%, 656.6 |
| σ 2,000 | 400 | 0.144%, 430.9, 3.8, 49 | 0.038%, 429.8, 1.9, 49 | 0.009%, 411.0, 1.2, 48 | 0.062%, 300.7 |
| | 800 | 4.16%, 289.1, 13.2, 20 | 1.74%, 339.1, 6.5, 25 | 0.45%, 359.6, 2.7, 25 | 0.74%, 357.6 |
| | 1,600 | 71.7%, 23.1, 20.3, 4 | 17.5%, 113.8, 8.4, 7 | 5.65%, 196.8, 3.6, 13 | 4.51%, 375.4 |
| uniform | 400 | 0.535%, 335.3, 2.5, 13 | 0.133%, 338.0, 1.5, 13 | 0.035%, 322.5, 1.2, 13 | 0.76%, 178.3 |
| | 800 | 12.2%, 237.8, 14.3, 11 | 2.68%, 264.7, 6.5, 12 | 0.54%, 263.2, 2.7, 11 | 4.82%, 199.0 |
| | 1,600 | 16.9%, 116.1, 16.1, 2 | 19.7%, 135.5, 8.1, 3 | 11.0%, 184.2, 4.2, 8 | 17.8%, 166.1 |

**Primary stragglers per million executed events at W 800** (16 / 4 / 1 LPs per chare): σ 100 1,020 / 1,304 / 1,059; σ 2,000 2,606 / 2,088 / 1,513; uniform 5,780 / 2,886 / 1,706.

**Predictions:**
- **L1 right except at σ 100.** At W 800, 1 LP per chare cuts the rolled-back share against 16 by 9.2× at σ 2,000 (to 0.61× Devastator's) and 23× on uniform (0.11× Devastator's). At σ 100 the cut is only 5.1×, and Charades still rolls back 12.6× Devastator's share.
- **L2 half right.** Events rolled back per rollback call fall 4.9–5.3× from 16 to 1 LP per chare at W 800 in all three workloads. Primary stragglers fall 3.4× on uniform and 1.7× at σ 2,000, but not at all at σ 100.
- **L3 wrong.** With 1 LP per chare the best W is still 400 everywhere: W 800 is 0.84× (σ 100), 0.87× (σ 2,000) and 0.82× (uniform) of it. 1 LP per chare at W 400 is 0.90× of 16 at σ 100, 0.95× at σ 2,000 and 0.96× on uniform.
- **L4 mostly right.** 4 LPs per chare lies between 16 and 1, with three exceptions: W 1,600 on uniform (19.7%, above both), W 1,600 at σ 100 (5.18%, level with 16's 5.14%), and the straggler count at W 800, σ 100.

**What it says:**
- **The rollback unit was most of Charades' excess rollbacks at σ 2,000 and uniform.** With 1 LP per chare, Charades rolls back less than Devastator at the same W there.
- **Shallower rollbacks are most of the gain:** about 2.5 events undone per straggler instead of 12–14.
- **σ 100 has a second cause.** There the number of stragglers doesn't change with chare size: the LPs themselves have passed the event. Events at σ 100 mostly go to the same PE, which can't straggle (a PE runs its lowest event first), or to adjacent PEs. So adjacent PEs drift apart by more than the lookahead much more often than Devastator's ranks do.
- **A wider window still loses throughput, even with few rollbacks.** At σ 2,000 with 1 LP per chare, W 800 rolls back only 0.45% yet runs at 0.87× of W 400. Events per htram message halve (48 to 25), because the flush deadline follows W (h = W + 8). That is the other half of the coupling in section 145.
- **4 LPs per chare is a free improvement at W 400:** 1.00× of 16 at σ 100, 1.00× at σ 2,000, 1.01× on uniform, with 3–4× fewer rollbacks. 1 LP per chare costs 4–10% there: more chares for the scheduler and fossil collection.

**Next (section 149):**
- With rollbacks cheap, test the decoupling again: a wider W with the flush deadline held near 400.
- Section 5's failure of that setting (8% stragglers, 47–62% efficiency) was with 16-LP chares, where each straggler undid 12–20 events.

### §151 · Per-LP rollback inside a chare, `--rollback-unit=1` (implementation and design, 2026-10-29; design written before any runs)

> **Status: design.** Charades branch `lp-rollback`. Follows sections 148 and 150.

**Implementation.**
- A straggler is judged against its own LP's latest processed event, and only that LP's events at or after it are rolled back.
- Each processed event is also linked into its LP's chain (`Event::lp_prev`/`lp_next`; head and tail in `LPBase`). The chare's processed queue stays, in execution order, for migration.
- An anti-message rolls back the cancelled event's LP only.
- Fossil collection commits each LP's chain below GVT: the chare queue is no longer in time order.
- A migrated chare rebuilds the chains.
- **The option:** `--rollback-unit=0` is the chare (the default for now), 1 the LP.
- **Why it is safe:** LPs share no state; no model in the tree reaches another LP (`owner->`, `lp_structs`). An event one LP sent another is cancelled through its causality chain as before.
- **A bug found on the Mac:**
  - **Symptom:** dragonfly committed the wrong number of events without a window: 9–287 too many on its base config, 99–456 too few on its congested config, on 1, 4 and 2 × 2 PEs.
  - **Cause:** a send to an LP of the same chare is delivered at once (`tw_event_send`). Under per-LP rollback the receiving LP can be ahead of the sender, so the send can roll it back inside the sender's forward handler. The rollback then set the chare's current event to another event, and the handler's later sends took their time and causal parent from that.
  - **Fix:** a rollback inside a forward handler (`in_forward`) restores the running event.
  - **Under chare rollback:** the same can happen only with a zero-delay send, because a chare's processed events are never ahead of its running event.
- **Mac tests:**
  - Change tier: the six new configs (bucketed, bucketed with a window, htram PP with the deadline policy, the same with the deadline held at 500 below a window of 2,000, blocking, CD). All pass except CD at 4 PEs, which fails with and without the option. CD is on the harness's known-broken list (issue #11), and its config was dropped.
  - Engine tier with 20 repeats of the five per-LP configs (bucketed, bucketed with a window, htram PP, htram PP with the held deadline, blocking): **2,422/2,422** on the Mac. Commit df75cd2 on branch `lp-rollback`.

**Job P** (`$WORK/charades-runs/lprb51.slurm`, 16 nodes; skx-dev copy 3658328 and skx copy 3658329, the later one to start is cancelled; tree `charades-lprb`, a worktree at df75cd2 on the same Charm++, Reconverse and htram as job H):
- σ 100 (PP 2,048), σ 2,000 (PP 512), uniform (WPs 512); end time 512,000; 2 reps.
- **Arms per workload:**
  - Chare rollback: 16 LPs per chare at W 400 (the paper runs' setting); 4 LPs per chare at W 400 (the best setting so far).
  - Per-LP rollback at 16 and at 4 LPs per chare: W 400, W 800 with the default deadline, and W 800 with the deadline held at 408.
  - Reference: 1 LP per chare, chare rollback, W 800 with the deadline at 408 (job H's best at σ 2,000).
- **GVT delay at σ 2,000:** per-LP rollback at 4 LPs per chare, W 400 and W 800 with the deadline at 408, each with `--diag-gvt-spin-ns=20000`.

**Predictions:**
- **P1.** With per-LP rollback, the rolled-back share at 16 or 4 LPs per chare is within 1.5× of 1 LP per chare's (jobs L and H) at the same W and deadline, in every workload.
- **P2.** At W 400, per-LP rollback costs at most 2% against chare rollback at the same chare size.
- **P3.** The best per-LP setting is at least 1.05× today's best (4 LPs per chare, chare rollback, W 400) at σ 2,000, and within ±2% at σ 100 and uniform.
- **P4.** With per-LP rollback at 4 LPs per chare, the 20 µs GVT delay costs W 800 with the held deadline at most half what it costs W 400.

### §152 · Per-LP rollback inside a chare, results: 1 LP per chare's rollbacks at no cost; the held deadline is a new best at σ 2,000 but loses elsewhere, and a late GVT update costs as much as at W 400 (2026-10-29; skx-dev batch job 3658328, 16 nodes)

> **Status: current.** Design and predictions in section 151. Per-LP rollback became the default on these results (main 9d08fbd, 2026-10-29; full test matrix 13,345/13,345 on the Mac).
> - **Allocation:** 16 nodes, 8 min, gate 48/48 (including the three per-LP configs on 2 nodes). The skx copy (3658329) was cancelled before it started.
> - **Build:** `charades-lprb`, a worktree at df75cd2; the first build failed on a parallel-make race (`scheduler.decl.h` not yet generated) and was rebuilt serially.
> - **Runs:** 58, all ok. Every workload committed the same events in every run.
> - **Data:** summary `~/charades-data/lprb51/lprb51_summary.py`, output in `j3658328/summary.txt`, with every run log.

**Median of 2, htram, end time 512,000.** Rolled back (% of executed; lower is better), M committed ev/s (higher is better), and the rate ÷ 4 LPs per chare with chare rollback at W 400 (the best setting before; higher is better). "Chare" and "LP" are the rollback unit; "W + 8" and "408" the flush deadline.

| workload | LPs per chare, unit, deadline | W 400 | W 800 |
|---|---|---|---|
| σ 100 | 16, chare, W + 8 | 0.046%, 659.7, 0.97 | — |
| | 4, chare, W + 8 | 0.014%, **678.5**, 1.00 | — |
| | 16, LP, W + 8 | 0.004%, 674.4, 0.99 | 0.31%, 516.2, 0.76 |
| | 4, LP, W + 8 | 0.004%, 667.4, 0.98 | 0.28%, 514.3, 0.76 |
| | 16, LP, 408 | — | 0.69%, 622.0, 0.92 |
| | 4, LP, 408 | — | 0.72%, 604.8, 0.89 |
| | 1, chare, 408 | — | 0.68%, 567.3, 0.84 |
| σ 2,000 | 16, chare, W + 8 | 0.134%, 434.5, 1.00 | — |
| | 4, chare, W + 8 | 0.034%, 432.9, 1.00 | — |
| | 16, LP, W + 8 | 0.009%, 436.5, 1.01 | 0.40%, 369.3, 0.85 |
| | 4, LP, W + 8 | 0.009%, 430.8, 1.00 | 0.39%, 370.9, 0.86 |
| | 16, LP, 408 | — | 2.25%, 471.0, 1.09 |
| | 4, LP, 408 | — | 2.20%, **473.7**, 1.09 |
| | 1, chare, 408 | — | 2.21%, 452.1, 1.04 |
| uniform | 16, chare, W + 8 | 0.429%, **347.9**, 1.08 | — |
| | 4, chare, W + 8 | 0.136%, 321.9, 1.00 | — |
| | 16, LP, W + 8 | 0.056%, 333.4, 1.04 | 0.50%, 274.3, 0.85 |
| | 4, LP, W + 8 | 0.036%, 325.9, 1.01 | 0.49%, 272.2, 0.85 |
| | 16, LP, 408 | — | 22.8%, 218.9, 0.68 |
| | 4, LP, 408 | — | 21.1%, 226.8, 0.70 |
| | 1, chare, 408 | — | 15.9%, 249.6, 0.78 |

Events rolled back per rollback call at W 400: 3.7–4.0 (16, chare), 1.5–2.0 (4, chare), 1.2–1.3 (per-LP at 16 or 4).

**20 µs on every GVT update** (σ 2,000, 4 LPs per chare, per-LP rollback; with ÷ without, higher is better): W 400, deadline W + 8: 394.4 ÷ 430.8 = **0.915**. W 800, deadline 408: 430.6 ÷ 473.7 = **0.909**.

**Predictions:**
- **P1 right but for one cell.** Per-LP rollback at 16 or 4 LPs per chare rolls back within 1.5× of 1 LP per chare (jobs H and P) in 17 of 18 cells. The exception is uniform at 16 LPs per chare, W 400: 0.056% against 0.036%, 1.56×.
- **P2 right in 5 of 6 cells.** At W 400 per-LP rollback is −1.6% to +2.2% against chare rollback at the same chare size. The exception is uniform at 16 LPs per chare: −4.2% (333.4 against 347.9), which is near this workload's rep-to-rep spread, since 16 against 4 LPs per chare with chare rollback differs by 8% here and by 1% in job L.
- **P3 right at σ 2,000 and σ 100.** The best per-LP setting is 1.094× the old best at σ 2,000 (4 LPs per chare, W 800, deadline 408) and 0.994× at σ 100 (16 LPs per chare, W 400). On uniform it is 1.036× the old best but 0.958× 16 LPs per chare with chare rollback in this job.
- **P4 wrong.** The GVT delay costs W 800 with the held deadline 9.1%, against 8.5% at W 400. Job H's smaller cost (3.1%) was at W 1,600: a window of twice the deadline does not leave enough room to absorb a late update.

**What it says:**
- **Per-LP rollback does what 1 LP per chare did, at chare cost.** It cuts the rolled-back share at W 400 7.7–15× at 16 LPs per chare (σ 100: 0.046% to 0.004%; σ 2,000: 0.134% to 0.009%; uniform: 0.429% to 0.056%) and 3.5–3.8× at 4, and each rollback undoes 1.2–1.3 events. Throughput at W 400 is unchanged. It removes the reason section 45 found W 600–800 so costly, and it should become the default after the full test matrix.
- **The held deadline is a per-workload choice.** At σ 2,000 it is the best setting measured (1.09×). At σ 100 it loses 8–11%, and on uniform 30%, where held events made 98–99% of stragglers in job H. The controller has to set the deadline and the window together; today it sets only the window.
- **The robustness goal is not met yet.** A late GVT update still costs about what it costs at W 400. Only a window well beyond the deadline (W 1,600 with deadline 408 in job H) absorbed it, and that loses throughput on every workload but σ 2,000.
- **So per-LP rollback is a clean improvement, but not yet the scaling fix.** The next step is the 16→32-node breakdown in A2r (section 144), to see whether the 32-node loss is the GVT step, as at 16 nodes, before choosing between a wider window and faster GVT updates.

### §203 · Closing the gap: where Charades' per-event and per-pass time goes, and the first changes (design, 2026-11-03; written before any runs)

> **Status: design.** User decision 2026-11-03: close Charades' performance gap; Reconverse changes are allowed. Work on an interactive skx node (idev), one change at a time. Reconverse work on branch `pads-perf` (worktree `~/reconverse_perf`, from `pads-remote-free` e9a6668, the tree Stampede3 runs). Script `$WORK/charades-runs/perf1w.sh`.

**What the gap is made of so far** (b19, 1 node, W 2,500; sections 199 and 202):
- Between the node's two processes, each send costs the sender 2 µs through LCI, and the heaviest senders set the pace: 1 × 46 is 1.33× 2 × 23. Reconverse's shared-memory pool is slower still (0.17–0.21×).
- At 1 × 46 Charades runs 0.74× Devastator at the same W. Its non-blocked time per executed event is 0.40 µs; Devastator's cycle (0.607 ms against 0.817) implies about 0.30 µs on the same layout.
- In the 1 × 46 profile (process 0, including spinning while blocked): `process_cancel_q` 10.6% (a walk over all 40 chares on every pass, with nothing queued), LCI progress 11.7% (one process, so nothing to receive), `CmiNodeBarrier` 3.7%, Converse scheduling and queues about 8%. A blocked pass takes 0.70 µs.
- On a single worker (no communication, no waiting) Charades takes 1.57 µs per event against Devastator's 0.63.

**Steps, each measured before the next:**
1. **Single-worker profiles of both engines** (b19 × 1, 500 cycles, perf): where each engine's per-event time goes when nothing waits.
2. **Skip the cancel-queue walk when nothing is queued** (Charades; `min_cancel_time` is set by every queued cancellation). Mac: change tier 30/30 over four models; the engine tier runs before any commit.
3. **Network polling:** at 1 × 46 on 1 node, `+lci_ndevices 1 +backend_poll_thread 46` (one PE polls) against every PE polling. If it pays, a dedicated progress thread on each process's free core in Reconverse, as Devastator's master thread does, so worker PEs never poll.
4. **Fast shared memory between processes** (Reconverse): per-destination queues and allocation the senders do not share, replacing one locked queue and one locked heap per process.

**Predictions:**
- **E1.** The single-worker rates repeat V3's within 5% (Charades 0.64, Devastator 1.60 M ev/s). In Charades' profile, the model's own handlers (gate forward, reverse, commit) take under 25% of cycles; the rest is engine and runtime per event.
- **E2.** The cancel-queue skip makes 1 × 46 at 1 node 3–8% faster at W 2,500, with the same count and digest.
- **E3.** One polling PE makes 1 × 46 at 1 node another 5–10% faster.

### §204 · Closing the gap, round 1: skipping the empty cancel-queue walk (2.36× on one PE), committing fossils lazily (1.12× on VLSI), and a wider window now paying off: Charades at 0.85 of Devastator's best at 1 node (2026-11-03; idev 3677573, c455-104)

> **Status: current.** Design and predictions in section 203. Charades changes tested in `$WORK/charades-perf` (charades c7373b4 plus the diff below), against `charades-vlsi` c7373b4, both on `charm-pads-exp`. Scripts `$WORK/charades-runs/perf1w.sh`, `cmp1n.sh` (b19 × 1, 1 node, direct sends, buckets of 2,500, 5,000 cycles, 2 reps alternating unless noted); outputs `$WORK/charades-runs/{perf1w,cmp1n}/`. Same committed count and digest (87c11aec…) in every run.

**Single worker** (b19 × 1, 500 cycles; perf, process 0):

| | M committed ev/s (higher is better) | top costs |
|---|---|---|
| Charades (c7373b4) | 0.65 | `execute()` 24.8%, `process_cancel_q` 21.0%, `clcg4::seed` 12.4% (setup), `fossil_me` 5.5% |
| Devastator p1w1 | 1.59 | worker loop 21%; much of the rest its master thread polling psm2 |
| **Charades, cancel-queue walk skipped when empty** | **1.53** (2.36×) | setup, `fossil_me`, event allocation and queues |

On one PE the walk visited all 1,840 chares on every pass, and most of `execute()`'s own time was that walk's snapshot. Single-worker per-event cost is now about Devastator's.

**1 node, 46 PEs** (M committed ev/s, 2 reps; higher is better):

| change (all on 1 × 46 unless noted) | W 2,500 | W 5,000 |
|---|---|---|
| c7373b4 (V4's B) | 29.9 / 30.3 | 34.2 (V4) |
| cancel-queue skip | 30.4 / 30.7 (2 × 23: 23.5 / 22.2, against 22.9 / 23.3) | 34.6 / 34.2 |
| + one PE polls the network (`+lci_ndevices 1 +backend_poll_thread 46`) | 30.7 / 31.0 | |
| **+ lazy fossils (`--fossil-lazy=1`)** | **33.6 / 33.2** (2 × 23: 23.4 / 23.6) | **37.6 / 37.4** |
| lazy fossils, 4 chares per pass | 32.3 / 32.6 | |
| lazy fossils, `--batch` 4 / 8 / 32 | 30.9 / 32.2 / 33.8 | batch 32: **38.1 / 38.2**; 64: 38.1 |
| lazy fossils, input buffer drained after every event in a pass (rejected) | 31.6 / 31.4 | |
| lazy fossils, batch 32, W 10,000 | | 36.1 (1 rep) |
| Devastator 2 × 23 (V4) | 41.5 | 44.6 |

- **Fast-path latency** (`--comm-stats=1` now times sends between PEs of a process, "Same Process"): at 1 × 46, W 2,500, an event pushed to another PE waited a mean of 29.4 µs before that PE drained it (median 4–8 µs, p90 ≤ 131, p99 ≤ 524). With lazy fossils: mean 13.4 µs, p90 ≤ 33, p99 ≤ 262.
- **Why lazy fossils help:** on each GVT update (once per clock cycle here) every PE committed the whole previous cycle's events (~550) before running anything, while the next cycle's events waited in its input buffer. `--fossil-lazy=1` records the GVT and commits one chare's fossils per pass that ends without a full batch; all at once at the end, before load balancing, and after 4 updates without finishing. Commit order within each LP is unchanged.
- **Per pass the scheduler machinery still costs:** re-enqueuing `execute()` as a Charm++ message and the Converse sweep (about 25% of process 0's cycles), and LCI progress with nothing to receive (13%), mostly while blocked. `CmiNodeBarrier` (4%) is setup, as `clcg4::seed` is (no frame pointers, so no call graph).

**Predictions (section 203):**
- **E1 right.** Single-worker rates 0.65 / 1.59 (V3 0.64 / 1.60); the model's own handlers take a few percent of Charades' cycles.
- **E2 wrong.** The skip is worth 1–2% at 46 PEs (about 40 chares each), not 3–8%; it is 2.36× on one PE.
- **E3 wrong.** One polling PE is worth 1.4%, not 5–10%.

**Where this leaves the gap (1 node):** Charades' best, 1 × 46 with lazy fossils, batch 32, W 5,000, is 38.1 M ev/s: **0.85 of Devastator's best** (44.6), up from 0.77 (V4) and 0.51 (V1). At 2 × 23 the sends between processes still hold Charades at about 23.5.

**Next:** the Mac engine tier on the cancel-queue skip, then commit; the same tiers with `--fossil-lazy=1` before it becomes the default, and the controller rechecked (it reads committed counts per round); Reconverse's shared-memory pool rewritten (per-PE receive queues, per-sender return lists; branch `pads-perf`), tested on the Mac, then built on an skx node.

### §210 · Closing the gap, round 2: no network polling in one-process runs, and several scheduler passes per `execute()` message (design, 2026-11-03; written before any runs)

> **Status: design; first attempt (idev 3679189, 25 min) found a hang and measured nothing.** User decision 2026-11-03: go ahead with section 209's items 1 and 2. Reconverse branch `pads-perf` (worktree `~/reconverse_perf`), Charades `main`. Measured on an idev node, one change at a time.
> - **Code:** Reconverse bab3df1 (local; on Stampede3 as 75719d5 / 371fdc8 in `charm-pads-perf` / `charm-pads-perfshm`, rebuilt on the node); Charades 5b14290 (`--pass-loop`; the runtime function is looked up with `dlsym`, so the Mac's runtime, which lacks it, leaves the loop off). Mac: Reconverse ctest 112/113 (`abort_peer-multinode` times out, as on main; the first version keyed on the process count per partition and hung `partitions-four`, fixed by counting the job's processes); Charades change tier 110/110.
> - **Gate on Stampede3** (change tier, 1 node, 1 × 4, 2 × 2, 4 × 2; VLSI, Simple PHOLD, traffic, dragonfly; `bucket_window`, `agg_ctl_measured_fast_bucket_pp`, `agg_deadline_bucket_wps`): `--pass-loop=16` 90/90. With `+ipc --fossil-lazy=1 --pass-loop=16`, every PHOLD run at 1 × 4 hung (three test timeouts, no output); 2 × 2 and 4 × 2 passed. Cause unknown; bisected on the next idev (`$WORK/charades-runs/r2bisect.sh`).
> - **Measurements lost:** stopping the gate (killing `test.py`) left its running srun step holding the node, so the first arm stalled and the allocation ended. Steps must be cancelled with `scancel`, not by killing their launcher.

**Where a pass goes now** (Reconverse `scheduler_registered.cpp`; Charades `DistributedScheduler::next_iteration`): every pass ends by sending `execute()` to its own PE as a Charm++ group message (`CkAllocSysMsg`, `CkSendMsgBranch`). The scheduler loop then makes two sweeps before the next pass runs: one takes the message from the PE's thread queue and moves it into the prioritized queue (`_skipCldHandler`), and the next walks the slot table to the prioritized queue's slot, polling the network once on the way (`comm_backend::progress`, once per sweep). Section 209's profile puts this machinery at about 31% of the process's cycles (network progress 13.9%, Converse sweeps and queues about 11%, the message about 5%, mutexes 2.7%), most of it while PEs spin blocked at the window. Round 1's test of one polling PE (+1.4%) bounds what polling alone costs.

**Changes:**
1. **Reconverse:** a run with one process does not register the network poll in the scheduler's slot table. Sends within a process never use the network backend, and the backend's barriers poll it themselves. `+backend_poll_single` restores the poll, so one build gives both arms.
2. **Reconverse:** `CmiPeHasPendingWork()`, true when this PE's thread queue, prioritized queue, node queues or shared-memory receive queue hold anything. It does not see the network.
3. **Charades:** `--pass-loop=N` (default 1, today's behaviour). When a pass ends with nothing pending for this PE (change 2) and fewer than N passes have run since the last message, the next pass runs at once inside the same `execute()` call. It ends when the GVT trigger starts a round, when the PE parks, or when anything is pending; the PE then returns to the scheduler, which also bounds how long network messages wait to N passes.

**Measurement** (idev, 1 node; b19 × 1, 1 × 46, `--fossil-lazy=1 --batch=32`, W 5,000, buckets of 2,500; 2 reps alternating; `--gvt-trace=1` cycle times; perf of the best arm):
- base (`+backend_poll_single`, `--pass-loop=1`);
- change 1 only;
- change 1 with `--pass-loop` 4, 16, 64;
- 2 × 23 over `+ipc` (change 1 does not apply there) with `--pass-loop` 1 and 16.

Correctness: Mac change tier on every model with `--pass-loop=16`; Reconverse's ctest on the Mac; Stampede3 VLSI gates.

**Predictions:**
- **G1.** Change 1 alone: +0–3% at 1 × 46 (round 1: one polling PE gave +1.4%).
- **G2.** `--pass-loop=16` on top: +3–8%. The Charm++ and Converse per-pass functions (`CkSendMsgBranch`, `CkAllocSysMsg`, `_processHandler`, `CsdSchedulerRegistered`, `pollConverseThreadQueue`, `pollThreadPrioQueue`, `CcdRaiseCondition`) fall from about 11% to under 3% of cycles. N = 4 gets most of it; N = 64 is no better than 16.
- **G3.** Both together: at least 39.5 M ev/s at 1 × 46 (0.90 of Devastator's 43.8).
- **G4.** 2 × 23 over `+ipc` gains as much from `--pass-loop=16` as 1 × 46 does, ±3%.
- **G5.** The same committed count and digest in every run.

**What follows:** whatever pays becomes the default (with the engine tier on the Mac first), and round 3 takes the per-event costs (allocation and freeing of events and messages, the fast-path drain).

### §211 · Closing the gap, round 2 results: neither change moves the rate (no network poll 1.00, `--pass-loop` 1.01); the per-pass machinery runs while PEs wait, and section 209's profile was mostly setup (2026-11-03; idev 3679621, c454-041)

> **Status: current.** Design and predictions in section 210; first attempt and gate there. Runtime `charm-pads-perf` with Reconverse bab3df1 (75719d5), Charades 5b14290. b19 × 1, 1 node, `--fossil-lazy=1 --batch=32`, W 5,000, buckets of 2,500; 2 reps; one digest (87c11aec…) in every run. Data `~/charades-data/vlsi/idev3679621/`.

**Rates** (M committed ev/s, higher is better; ÷ base, median of 2 reps):

| arm | r1 / r2 | ÷ base |
|---|---|---|
| base: 1 × 46, network poll on (`+backend_poll_single`), `--pass-loop=1` | 37.84 / 37.95 | 1.00 |
| change 1: no network poll | 38.07 / 37.39 | 1.00 |
| + `--pass-loop=4` | 38.41 / 38.07 | 1.01 |
| + `--pass-loop=16` | 37.84 / 38.77 | 1.01 |
| + `--pass-loop=64` | 38.30 / 38.18 | 1.01 |
| 2 × 23 `+ipc` / with `--pass-loop=16` | 32.64 / 32.39; 32.47 / 32.56 | 1.00 (÷ each other) |

**Profiles of the simulation alone** (perf started 9.5 s in, after setup; user cycles of the process):
- **Base:** Charades and the model 68%, runtime 23%, libc 8%. The scheduler machinery per pass is about 10% (`pollConverseThreadQueue` 2.4%, `CsdSchedulerRegistered` 1.6%, `CcdRaiseCondition` 1.5%, `pollNodeQueuesFirst` 1.5%, `CkSendMsgBranch` 1.5%, `_processHandler` 1.3%); network polling 1.3% (`pollProgress`).
- **`--pass-loop=16`:** runtime 15%. Those functions drop out of the top of the profile, but `CmiPeHasPendingWork` takes 4.7% and `execute_pass` 9.7% (3.4% before): PEs blocked at the window (61% of the time) now spin inside the loop instead of in the scheduler. Spinning while blocked costs nothing that matters, so the rate does not move. This is the same lesson as Reconverse's idle cycles.
- **What is left is Charades' per-event work:** `event_alloc` 5.3%, `execute_me` 5.3%, `fp_drain` 5.2–7.5%, `remote_event_delete` 4.7%, `fossil_me` 3.2%, glibc free and malloc 3.5%, mutex lock and unlock 3.2%, `fp_push` 2.1%, `tw_event_free` 2.0%, the event comparator 1.9%, `recv_local_event` and `recv_fast_event` 1.8% each.

**Correction to section 209:** its profile covered the whole process, and a b19 run spends about 9 of its 12 s in setup, where PEs wait in `CmiNodeBarrier`, which polls the network. "Network progress 13.9%" was that setup barrier, not the run; during the simulation it is 1.3%. Section 209's other findings stand.

**A start-up hang with `+ipc` in a one-process run** (`r2bisect.sh`; PHOLD at 1 × 4): `+ipc` hangs with or without `--pass-loop` and with the network poll restored, and every run without `+ipc` passes. gdb: PEs 0 and 1 wait in `CmiNodeBarrier` inside `CmiCheckAffinity` (Charm++'s `_initCharm`), while PEs 2 and 3 have passed it into the scheduler. `CmiCheckAffinity` returns early when the CPU topology is not enabled, and `+ipc` gathers the topology at Converse start-up, so the PEs evidently disagree on that test. This is Reconverse's, not round 2's; whether it predates the pool rewrite is untested. No Charades configuration runs `+ipc` with one process. Recorded for a Reconverse fix.

**Predictions (section 210):**
- **G1 wrong:** change 1 is 1.00, not +0–3%.
- **G2 wrong:** `--pass-loop=16` is +1.5%, not +3–8%. The per-pass functions do drop out of the profile, but the time moves into the loop.
- **G3 wrong:** 38.3, not at least 39.5.
- **G4 right:** 2 × 23 gains as little as 1 × 46 does.
- **G5 right.**

**What follows:**
- Both changes stay off. The Reconverse commit can stay on `pads-perf`: `CmiPeHasPendingWork` is harmless, and so is skipping the poll in one-process runs.
- Per-pass work is not the 1-node gap. The remaining candidate is per-event work: allocating and freeing events and messages, the fast-path push and drain, and fossil commits.
- But at the same layout the engines are already level (section 209). Devastator's lead comes from its two-process layout being faster than its one-process layout, which Charades cannot copy by cutting per-event work alone.

### §213 · Closing the gap, round 3: the engine's work per event (design, 2026-11-03; written before any Stampede3 runs)

> **Status: design.** User decision 2026-11-03: work on round 3 on the Mac while the scaling job (section 212) waits. It is measured on Stampede3 when a 1-node allocation is free.
>
> **Amended before any Stampede3 run** (2026-11-03, after the Mac checks below):
> - Change d gains two items: `BucketGVT::attempt_gvt`, run on every send and receive, returns at once while a GVT round is under way, before two 64-bit divisions and a virtual call; and the fast path keeps each chare's route (this PE, another PE's rank, another process) and this PE's rank, instead of asking the runtime (`CkMyPe`, `CkNodeOf`, `CkRankOf`, `CkMyRank`) on every send and drain.
> - Switches for the measurement: `--msg-pool=2` is the spare list (the new default; `--msg-pool=1` is the old per-PE pool) and `--direct-execute=0` restores the proxy call.
> - Changes c and d have no switch, so the measurement attributes the changes cumulatively: the current tree; c+d (`--direct-execute=0 --msg-pool=1`); + a (`--msg-pool=1`); + b (all). R2's per-change ranges apply to those steps.
> - Script `$WORK/charades-runs/r3meas213.slurm` (copy in `~/charades-data/vlsi/`). It builds `charades-r3` on the node, gates it, and has 3 reps at 1 × 46. `charades-r3` is a worktree of `charades-perf` at b0b4ed4, with its `config.mk` pointed at itself. Submitted 2026-11-03 as 3679750 (skx; job a held the skx-dev slot), then as 3679870 (skx-dev), which ran first and failed in 16 s: a fresh tree's `make -j46` compiled files before charmc had generated the `.decl.h` headers they include (3679750 had already been cancelled as the slower copy). The tree was then built on the login node (`-j4`), and the job's build step now retries serially. Resubmitted as 3679892 (skx-dev) and 3679893 (skx).
> - **Mac checks so far** (development only; Mac timings do not compare with Stampede3's, and the Mac was in use):
>   - **Pool misses** (b19 × 1, 500 cycles), before → after b: 1 PE 6.88 M → 0.20 M; 4 PEs 0.49 M → 0.18 M; 8 PEs 0.61 M → 0.17 M. No frees after b. What is left is the first allocation of the messages in flight.
>   - **The same digest** as the current tree at 1, 4 and 8 PEs.
>   - **Rates** (M committed ev/s, median of 3 alternating reps, higher is better), made before d's two added items:

| Mac, b19 × 1 | current tree | c+d | + a | + b (all) |
|---|---|---|---|---|
| 1 PE, 500 cycles | 2.59 | 2.62 | 2.81 | 2.77 |
| 4 PEs, 2,000 cycles | 7.69 | 9.16 | 9.82 | 9.71 |

> - **Mac gate on the final code** (charades `b0b4ed4`): the change tier with 14 configs on every model at 1 × 4 and 2 × 2 passes 431 of 440. All 9 failures are VLSI under the conservative scheduler, which aborts on the lookahead check in the current tree too. With `--fossil-lazy=1`, VLSI and Simple PHOLD pass 60 of 60. The 4-PE digest is unchanged.


**Where the per-event work goes.** Section 211's profile of the simulation alone (1 × 46, lazy fossils, batch 32, W 5,000) has PEs blocked at the window 61% of the time. The engine's per-event functions take most of the rest. Four costs in it are not the model's work.

1. **Calling each event's chare through a Charm++ proxy.**
   - `Scheduler::schedule_next_lp` runs `lps(i).execute_me()`, a `[local]` entry method. Every event builds a proxy and finds the chare in the location manager's hash table (`ckLocal`, `std::_Hashtable::find`). It then pushes and pops Charm++'s call stack, which starts and stops the load balancer's timer for the chare (`CkCallstackPush/Pop`, `CkLocRec::startTiming/stopTiming`).
   - That is about 5% of the process's cycles: 1.17 + 1.07 + 0.84 + 0.69 + 0.61 + 0.61%.
   - The scheduler's token already holds the chare's pointer.
2. **Message allocation when a PE's message pool is empty.**
   - Every event's message comes from the sending PE's pool (`--msg-pool`, section 24). It goes back into the pool of the PE that commits the event, the receiver.
   - A PE that sends more than it receives runs dry and allocates. One that receives more fills to the cap (65,536) and frees.
   - In a one-process run Reconverse has no memory pool, so both go to glibc. The message was allocated on another thread, so the free takes that thread's arena lock.
   - glibc `_int_free`, `_int_malloc`, `malloc` and `free` plus mutex lock and unlock are about 7% of cycles; `CmiFree` adds 1.2%.
   - Mac counts (b19 × 1, 500 cycles, new counters `Message Pool Misses` / `Frees`): 4% of messages miss at 4 PEs, 7% at 16, 11% at 46 (oversubscribed). At 1 PE, 56% miss because more messages are in flight than the cap.
3. **Fossil collection visits every LP of a chare.** With per-LP rollback (the default), `fossil_me` walks all 128 LPs of the chare at each GVT update to find the events below GVT. b19 has about 4,900 LPs per PE, against about 550 events per PE per clock cycle. `fossil_me` is 3.2% of cycles.
4. **Per-PE values and the mapper are out-of-line calls.**
   - `PE_VALUE` and `PE_STATS` call `get_globals()` and `get_statistics()`, out-of-line functions used several times per event (1.19% + 0.80%).
   - The block mapper divides by the run's LPs per chare, a runtime value, up to four times per event (1.01% + 0.53%).

**Changes (Charades only; every one keeps the same committed events):**
- **a. Direct call.** With load balancing off (`--ldb-interval` 0, as in every paper run), the scheduler calls the chare's `execute_me()` through the token's pointer. The proxy, the location lookup and the call-stack push are skipped. With load balancing on, the proxy path stays.
- **b. Pool rebalancing.**
  - A PE whose pool holds more than 4,096 messages moves 2,048 of them to a process-wide spare list, held by a mutex, one lock per 2,048 messages. A PE whose pool is empty takes up to 2,048 from it before allocating.
  - Messages are then freed only when the spare list holds more than the process's PEs × 65,536.
  - Messages in this process's shared-memory segment are still never pooled (section 201).
- **c. Fossil collection over the LPs that hold processed events.** Each chare keeps a list of its LPs whose chain of processed events is not empty. `fossil_me` walks that list and drops the LPs it empties.
- **d. Inline per-PE accessors and a shift-based mapper.**
  - `get_globals()` and `get_statistics()` become inline reads of a thread-local pointer, which the scheduler sets on each PE.
  - When the LPs per chare are a power of two (128 for VLSI, 16 in the paper's other runs), the block mapper shifts and masks instead of dividing.

**Mac checks:** the change tier on every model at 1 × 4 and 2 × 2; the engine tier before Stampede3; counts and digests unchanged.

**Measurement** (1 node, b19 × 1, 1 × 46, `--fossil-lazy=1 --batch=32`, W 5,000, buckets of 2,500; 2 reps alternating; `--gvt-trace=1` cycle times):
- the current tree;
- each change alone;
- all four together;
- the profile of the simulation alone (`perfwrap_d.sh`) with all four;
- all four at 2 × 23 over `+ipc`;
- Simple PHOLD σ 100 and uniform at 2 × 23 (the paper's launch) against the current tree.

**Predictions:**
- **R1.** Pool misses fall to under 0.1% of messages after the first 100 cycles.
- **R2. Each change alone at 1 × 46:**
  - a: +1–4%;
  - b: +2–6%;
  - c: +0–2% (lazy fossils already run while PEs wait);
  - d: +0–3%.
- **R3. All four:** +5–12% at 1 × 46, 39–42 M ev/s (0.89–0.96 of Devastator's 43.8).
- **R4. In the profile:** glibc allocation and mutex fall from about 7% to under 1%, and `ckLocal`, the location hash table, the call-stack push and the load balancer's timers leave it.
- **R5. Elsewhere:** 2 × 23 over `+ipc` gains as much as 1 × 46, ±3%; PHOLD gains 0–5%.
- **R6.** The same committed count and digest in every run.

**What follows:**
- What pays and passes the engine tier becomes the default. A change with no gain stays only if it is simpler than what it replaces.
- If R3 holds, the VLSI scaling job's Charades cells are rerun (section 212's rule: a gain of 3% or more).
- If R3 fails, the 1-node gap is reported as it stands: at the same layout the engines are level (section 209).

### §215 · Closing the gap, round 3 results: 1.64× at one process per node (37.6 → 61.8 M ev/s, 1.35× Devastator's best at 1 node); the message pool's spare list alone is 1.42×, because a pool miss in a one-process run went to glibc and freed memory another thread allocated; PHOLD at 2 × 23 gains 1.16–1.18 (2026-11-03; skx-dev batch job 3679892, c455-033)

> **Status: current.** Design, amendment and predictions in section 213.
> - **Job:** 10.5 minutes; skx copy 3679893 cancelled; first attempt 3679870 failed at build (section 213).
> - **Gate on the node:** 150/150 (VLSI, Simple PHOLD, traffic, dragonfly; 1 × 4, 2 × 2, 4 × 2), and with `--fossil-lazy=1` 75/75.
> - **Counts:** every VLSI run commits 125,998,590 events with digest 87c11aec… (the same as V5 and job a); PHOLD one count per workload in both trees.
> - **Data:** `~/charades-data/vlsi/r3meas213/j3679892/`.

**VLSI b19 × 1, 1 node** (`--fossil-lazy=1 --batch=32`, W 5,000, buckets of 2,500; M committed ev/s, reps after the median; higher is better; cumulative, as amended):

| arm | M ev/s | ÷ previous row | ÷ current tree | blocked share |
|---|---|---|---|---|
| current tree (5b14290), 1 × 46 | 37.61 (38.18 / 37.50 / 37.61) | | 1.00 | 60.2% |
| + c and d: fossil list, inline accessors, mapper shift, `attempt_gvt` return, fast-path routes | 42.00 (42.14 / 42.00 / 41.58) | 1.117 | 1.117 | 60.8% |
| + a: direct `execute_me` | 43.60 (43.60 / 43.15 / 43.60) | 1.038 | 1.159 | 65.3% |
| + b: the pool's spare list (all four, the new defaults) | **61.76** (62.07 / 61.76 / 61.46) | **1.417** | **1.642** | 54.3% |
| 2 × 23 over `+ipc`: current tree / all four | 32.95 / 33.43 | | 1.015 | 59.7% / 64.9% |

**Simple PHOLD, 2 × 23 over LCI** (the paper's launch; W 300, 2 reps):

| workload | current tree | all four | ratio (higher is better) |
|---|---|---|---|
| σ 100, PP 2,048 | 45.87 | 54.01 | 1.177 |
| uniform, WPs 512 | 40.35 | 46.82 | 1.160 |

**Against Devastator at 1 node:**
- Charades with all four runs 61.76 M ev/s, 0.408 ms per clock cycle.
- Devastator's best in job a is 45.65 (2 × 23, W 10,000), 0.552 ms per cycle.
- **Charades ÷ Devastator is 1.35**, from 0.84. The two numbers come from different allocations, a node apart; Devastator's 1-node reps in job a vary by 4%.

**The pool counters:**
- **Without the spare list** (cda): 12.4 M of the run's roughly 131 M messages missed the pool and were allocated through glibc, and 11.1 M were freed into it from a thread other than the allocating one.
- **With it:** 0.23 M misses (each message's first allocation) and no frees (R1 right).
- **With `+ipc` and all four:** still 15.1 M misses and 15.0 M frees. A message from the other process arrives in a shared-memory block, which is never pooled (section 201), so the sender's pool drains at the rate of cross-process sends. That is why `+ipc` gains nothing.

**Why the profile understated it.**
- **What the profile showed:** glibc `_int_free`, `_int_malloc` and `malloc`, plus mutex lock and unlock, were about 7% of user cycles, yet removing them gained 1.42×.
- **Likely reason:** in a one-process run Reconverse has no memory pool, so a miss is `malloc` and a free from another thread takes the allocating thread's arena lock. A thread waiting on a contended lock sleeps in the kernel, and `perf record -e cycles:u` does not count that time.
- **Status:** this is inferred, not measured; a context-switch count would test it.
- **What it changes:** section 78's finding that one process per node is 0.71–0.87 of two on PHOLD predates this fix, and the multi-process runs never had the problem.

**Profile of the simulation alone, all four** (user cycles):
- `fossil_me` and glibc `_int_free` drop out of the top.
- `execute_me` (8.1%) and `fp_drain` (8.1%) now lead.
- Mutex lock and unlock remain about 3.5%. The profile records no callers; they are probably the runtime's queues.

**Predictions (section 213):**
- **R1 right.**
- **R2 one of three steps inside its range:**
  - a: +3.8%, inside +1–4%;
  - c and d together: +11.7%, above their combined +0–5%;
  - b: +41.7%, far above +2–6%.
- **R3 wrong, by far:** 1.64×, not 1.05–1.12; 61.8 M ev/s, not 39–42.
- **R4 half:** glibc frees and the proxy path's functions are gone; mutex time is not under 1%.
- **R5 wrong:** `+ipc` gains 1.015, not as much as 1 × 46; PHOLD at 2 × 23 gains 1.16–1.18, not 0–5%.
- **R6 right.**

**What follows:**
- **All four are the defaults** (charades b0b4ed4). The engine tier on the Mac follows before the next merge.
- **Section 212's rule:** a gain of 3% or more reruns the Charades cells of the VLSI scaling job on the new tree (design in the next section).
- **The paper's other tables** (PHOLD, traffic, dragonfly) used the paper's tree e1fbdc4. On the new tree PHOLD at 2 × 23 is 1.16–1.18× faster, so those tables would need rerunning to use it. That is the user's decision.
- **Layout:** with glibc contention gone, one process per node may now beat two on the other workloads as well (section 78 found 0.71–0.87 before). It is checked in the rerun at 1 and 4 nodes.

## Earlier

Superseded or historical sections, in the order they were written. Their numbers came from an older stack, launch or setting, or a later section replaced them; each says which.

### §9 · Two speeds of the bucketed GVT (2026-10-20, idev job 3623246)

> **Status: historical.** A GVT bug (Debug (-O0) runtime on verbs); fixed in the next section.

- **Runs with identical settings land in one of two modes, distinguished by the number of GVT computations.**
  - High slack, fixed W 250, end 256,000: 7,348–7,642 GVTs at 12.8–13.3 M ev/s, or 12,000–13,100 GVTs at 9.0–9.6.
  - Fewer, larger GVT steps are fast. The slow mode also has about 2× the urgent htram sends and 2× the rollbacks.
- **Every arm shows it, fixed windows included** (`sweep5_modes.csv`: 6 reps, end 128,000, margin 8). Examples:
  - phases, fixed W 50: 8.0 or 10.0–10.4;
  - low slack, fixed W 25: 8.8–9.4 or 10.5–10.7;
  - high slack, ε 0.01: 8.3–8.6 or 11.5–12.1.
- **`--gvt-min-buckets` (pass k buckets before starting a round) does not select the mode.** At W 250 fast runs were 1/3, 0/3 and 2/3 for k = 1, 2 and 4.
- **Consequences.**
  - Medians over a few reps partly measure which mode runs fell into, so ±15% comparisons between arms are not resolved yet.
  - Making the fast mode reliable could be worth 1.3–1.4× by itself. Next step is a trace of one run in each mode.
- **Controller medians from sweep 5** (ratio to the best fixed median): ε 0.005 gives 0.91 / 0.82 / 1.16 and ε 0.01 gives 0.98 / 0.92 / 0.89 (low slack / high slack / phases).
  - It is never catastrophic, where a wrong fixed W is 0.03–0.40, but it does not reliably beat a window tuned in hindsight.

### §10 · Two GVT speeds: cause and fix (2026-10-21, idev job 3624457, 4 skx nodes)

> **Status: historical.** The fix for the two GVT speeds (Debug (-O0) runtime on verbs).

**Cause.**
- The bucketed GVT runs its count waves back to back, each starting when the previous result reaches a PE, so wave pace is set by how quickly every PE handles the broadcast.
- A bucket needs two waves (Mattern's four-counter rule), so frequent waves each confirm only a sliver of progress.
- With 16-event batches, PEs answer quickly. In a slow run, waves come every ~230 µs (round trip, PE 0), complete 2.67 buckets each, and the slowest PE leads GVT by only ~8 buckets. PEs spend 72% of their time outside `execute()`, mostly re-queuing window-blocked batches (23.7 M of them).
- Runs settled into one of two paces, and the wave pace sets the whole simulation's speed: PEs sit at the window edge waiting for GVT.

**What did not fix it.**
- `--gvt-min-buckets`: it gates only the first reduction of a round, and waves then run continuously.
- `--sched-park=1`: window-blocked PEs wait instead of spinning, and blocked batches drop 10×. Throughput is unchanged (batch 16: 1 of 4 runs fast, as before). Kept as an option, default off.

**Batch size changes it** (high slack, W 250, 4 reps unless noted; M committed events/s, higher is better):

| `--batch` (events per execute()) | throughput (M ev/s) | GVT computations (count) | waves/s (count/s) | buckets per wave (count) |
|---|---|---|---|---|
| 4 | 6.67–7.03 | 9,655–9,949 | 4,678 | 1.53 |
| 16 (default) | 8.90–9.94 (20 traced runs) | 5,803–6,534 | 3,662 | 2.67 |
| 64 | 12.63–13.21 | 2,418–2,605 | 2,035 | 6.61 |
| 256 | 10.67–11.08 | 2,065–2,083 | – | – |

**Fix: `--gvt-wave-events=K`, default 128 (commit ccead4d).**
- A PE holds its contribution to the next count wave until it has executed K events since its last one, or until an `execute()` batch stops early (blocked or out of events), so it cannot hold a wave forever.
- At batch 16 and high slack, W 250, K 0 / 64 / 128 / 256 gives the throughputs below. Higher is better; each range is over 4 runs, and the default row over 8 unflagged runs.

| K (events per PE between waves) | throughput (M ev/s) | spread |
|---|---|---|
| 0 (old behaviour) | 8.88–12.73 | bimodal |
| 64 | 10.75–12.97 | — |
| **128** | **13.21–13.59** | — |
| 256 | 12.80–13.29 | — |
| 128, the new default, unflagged | 13.40–13.98 | 4% |

- **Three workloads, 4 nodes, margin 8, 4 reps** (`wave0.csv`, `wave128.csv`; median M committed events/s, higher is better):

| workload | arm | K 0 | K 128 | K 128 ÷ K 0 |
|---|---|---|---|---|
| lookahead 10 / mean 200 | fixed W 25 | 9.17 | 9.89 | 1.08 |
| | fixed W 50 | 8.35 | **11.49** | 1.38 |
| | fixed W 100 | 5.51 | 7.32 | 1.33 |
| | controller ε 0.01 | 8.34 | 10.95 | 1.31 |
| lookahead 100 / mean 1000 | fixed W 50 | 6.89 | 6.90 | 1.00 |
| | fixed W 100 | 10.23 | 10.41 | 1.02 |
| | controller ε 0.01 | 8.49 | **11.55** | 1.36 |
| phases | fixed W 25 | 7.55 | 7.77 | 1.03 |
| | fixed W 50 | 8.09 | **10.41** | 1.29 |
| | fixed W 100 | 6.17 | 8.25 | 1.34 |
| | controller ε 0.01 | 7.93 | 9.66 | 1.22 |

  - No arm got slower, and the spread over 4 reps is 1–5% (unpaced: up to 10% here, 50% in earlier sweeps).
  - With pacing, the controller is 0.95 / 1.11 / 0.93 of the best fixed W (low slack / high slack / phases).
- **2 nodes, 3 reps** (M committed events/s, higher is better):
  - High slack, W 100: 6.72–6.86 unpaced, 6.40–6.65 paced (0.96×). The GVT count barely moved there (5,470 → 5,290), so waves were not the limit, and holding them back costs a little.
  - Low slack, W 50: 5.15–5.65 unpaced, 6.76–6.95 paced (1.27×).
  - A K that adapts (for example to buckets completed per wave) is the follow-up.

### §23 · Profile: where Charades spends its time against Devastator (2026-10-21, idev job 3626915)

> **Status: superseded.** Production runtime on verbs, before the fast paths and psm2. Current profile: "Controller level, `--agg-scope`, σ 100 profile, results".

Setup: best launch settings (2 × 23 PEs per node, `+pemap 2-46:2,3-47:2`, `+lci_ndevices 4`), `charades-prod`, Gaussian σ 2,000, high slack, W 250, 4 nodes; Devastator at fixed W 1,000 on the same 23,552 LPs. `perf` on node 0 mid-run (`$WORK/charades-runs/profile.sh`, `profile_dwarf.sh`; data and reports in `$WORK/charades-runs/profile/`); Projections traces of short runs (charm-pads-trace = production + `--enable-tracing`, `charades-trace` with `-DCHARADES_NO_BRACKETS`; logs in `$SCRATCH/proj/`). Analysis scripts: `scripts/stampede3/projsum.py` (time per entry method from Projections logs) and `stackcallers.py` (callers of hot leaf functions from `perf script`).

**Counters per committed event on one node** (perf stat, 2 s; Charades at about 11.3 and Devastator at about 25 M committed events/s per node):

| | Charades | Devastator | Charades ÷ Devastator |
|---|---|---|---|
| instructions | ~12,100 | ~7,500 | 1.6× |
| cycles | ~11,100 | ~5,300 | 2.1× |
| instructions per cycle (higher is better) | 1.09 | 1.41 | 0.77× |
| LLC load misses per s | 33 M | 16 M | 2.1× |

Both engines poll on every core, so these include polling.

**Where Charades' PE time goes** (one process, DWARF call stacks, inclusive shares of its PE time):
- Charm message handling 61%, of which:
  - the scheduler pass (`Scheduler::execute`) 30.5%: LP event execution 20%, of which the PHOLD forward handlers (the model's own work) are only **6.6%** and sends 7.8% (`agg_send` into htram 6.5%);
  - htram per-PE delivery (`HTram::receivePerPE`) **12.6%**, of which inserting each received event into the per-PE anti-message AVL tree (`recv_remote_event` → `avlInsertOrDelete`) is about 6%;
  - GVT count waves (`BucketGVT::check_counts`) 10.4%, of which fossil collection 8.2%, nearly all `tw_event_free` (AVL deletes 3.5%; cross-thread frees to the Reconverse mempool 2.9%).
- Network progress polled by every PE (`pollProgress` → LCI → libfabric RxM/verbs) **13.5%**.
- The Converse scheduler and queue polling outside handlers about 15% (`try_dequeue` 5.7%, `CcdRaiseCondition`, `CcdNumTimerCBs`, `pollConverseThreadQueue` etc.).
- Locks 8.1% as leaf (`pthread_mutex_lock/unlock`): message allocation through LCI's mempool (`CkAllocMsg` → `CmiAlloc` → `mempool_malloc`) 1.5%, `_processHandler` 1.5%, libfabric CQ progress about 2.5% (23 PEs polling 4 devices contend), event frees and `agg_send`.
- `__tls_get_addr` 2.6%: thread-locals reached through the shared `libreconverse.so` (scheduler, `CmiGetState`, `CcdRaiseCondition`, LCI thread context).
- By library (full nodes, self time): Charades + Charm core + model 41%, `libreconverse.so` 34%, libc 10% (mostly the locks), kernel 6%, libfabric + LCI + hfi1 4%.

**Projections** (node 0, 46 PEs): the Charades entry methods are all `[notrace]` in the `.ci` files, so the trace shows only htram and Charm internals; 84% of PE time is outside traced entry methods. What it does show: `HTram::receivePerPE` takes 9.9% of PE time at 1.5 µs per call, with 2.2 M calls carrying the node's roughly 5.6 M events, so **about 2.5 events per per-PE message**; `HTramRecv::receive` (node buffers) 2.6% at 12.5 µs per call. Tracing cost 8% of throughput (33.8 against 36.7 M ev/s).

**Devastator by contrast**: 82% of its time in its own binary, no runtime layer: `pdes::drain` 19%, thread-channel reaping 18% (mostly polling), event execution 6%, glibc malloc/free about 12%.

**Ranked opportunities** (shares of Charades PE time; estimates, not measured gains):
1. **htram's per-PE fan-out** (receivePerPE 12.6% incl., plus its share of allocation, queueing and freeing): PP delivers a node buffer, then one Charm message per destination PE carrying about 2.5 events. Deliver straight into the destination PEs' event queues in bulk, or make per-PE batches larger.
2. **The anti-message AVL tree** (about 9–10%: inserts 6%, deletes 3.5%): every received remote event is inserted and later deleted. A hash keyed by (sender, event id), or matching only when an anti-message arrives, should be far cheaper.
3. **Event frees at fossil collection** (8.2%): frees cross threads into the Reconverse mempool; recycle events into per-PE free lists instead.
4. **Converse scheduler and polling overhead** (about 15%, plus 2.6% TLS): link Reconverse statically (initial-exec TLS) and trim per-iteration condition and timer checks.
5. **Network progress on every PE** (13.5%, part of it lock contention in libfabric): fewer pollers once the `+backend_poll_thread` hang is fixed.
6. Message allocation locks (1.5%).

Even all of this together is unlikely to close 2.2×; items 1–3 are Charades/htram changes worth an estimated 1.2–1.3×, items 4–5 are Reconverse work.

### §24 · Per-event fast paths (2026-10-21, idev job 3627053, 4 skx nodes)

> **Status: historical.** Production runtime, verbs. The three fast paths are the default.

Three changes from the profile's ranked list (charades 4bb324b, htram 50acab7 on `pdes`), each behind a switch. **All three are the default since the same day** (user decision; the input buffer turns itself off under `--sched-park`, other GVTs and the conservative scheduler); test configs `bucket_avl` and `agg_noinputbuf_bucket_pp` keep the old paths covered. Not yet re-run with the new defaults:
- `--agg-input-buffer=1` (htram `setInputBufferDelivery` / `drainInputBuffer`): a PP/WPs node receive puts each PE's share of a node message in that PE's input buffer (a mutex-protected vector in the `HTramRecv` node group) instead of sending it a `receivePerPE` message; the optimistic scheduler drains it at the start of every iteration, and the receiving PE's own share is delivered in place. Only with the bucketed GVT (which counts each event when its chare receives it, so an event in an input buffer is in transit) and the optimistic scheduler; refused with `--sched-park`. QD-based GVTs would not see input buffer items.
- `--event-index=1`: received events indexed for cancellation by an open-addressing hash per chare (`collections/event_hash.h`; linear probing, tombstones, key (ts, event_id, src_lp)) instead of the AVL tree. Same insert-or-annihilate contract.
- `--msg-pool=1`: event messages (`RemoteEvent`) recycled through a per-PE pool (`remote_event_new` / `remote_event_delete` in event.C) on the hot paths: model sends, htram delivery, fossil frees, `agg_send`. Capacity is read from the envelope; reused messages are marked unused so they can be sent again.

Tests (Mac): change tier on the new configs 60/60; input buffer configs repeated 10× on 2×2, 1×4, 2×4: 360/360; existing aggregation configs 84/84; engine tier 484/484. Committed counts identical in every Stampede3 run below.

**Throughput** (production runtime, 2 × 23 PEs per node pinned, `+lci_ndevices 4`, Gaussian σ 2,000; M committed events/s, median of 3; higher is better):

| configuration | full nodes, W 250 | ÷ base | 64 PEs high slack, W 250 | 64 PEs low slack, W 50 |
|---|---|---|---|---|
| base (all off) | 43.7 | 1.00 | 20.7 | 14.2 |
| hash index only | 48.7 | 1.11 | | |
| message pool only | 48.9 | 1.12 | | |
| input buffer only | 45.2 | 1.03 | | |
| all three | **56.0** | **1.28** | **27.3** (1.32×) | **17.6** (1.24×) |

With all three on full nodes (2 runs each; ÷ W 250 at 56.9): W 175 0.93, W 350 0.85; controller ε 0.003 51.7 (0.91, mean W 309), ε 0.001 39.7 (0.70, pinned at W 110 near the floor). So ε 0.003 stays the default.

**Gap to Devastator** (each at its best fixed W; Devastator ÷ Charades, lower is better for Charades): full nodes ~100 / 56 = **1.8×** (was 2.2×); 64 cores high slack 54.2 / 27.3 = **2.0×** (was 2.6×); low slack 52.5 / 17.6 = **3.0×** (was 3.7×). A longer full-node run (end 2,048,000) reached 61.0 M ev/s.

**Profile with all three** (one process, DWARF stacks): about 8,300 cycles and 9,200 instructions per committed event (was 11,100 / 12,100; Devastator ~5,300 / 7,500). The AVL tree is gone; fossil collection is down to 6%; event execution is 26% of PE time (the model's forward work ~8%). What remains is mostly communication: LCI/libfabric progress 15%, sends through the node queue (`CkSendMsgNodeBranch` → `CldNodeEnqueue`, PP's node messages) 7%, `issueAm` 7.6%, mutexes 8% (libfabric CQ, node queue), Converse queue polling and TLS ~6%.
