# Working context: Charades on Reconverse, toward SIGSIM PADS 2027

Written for: Ritvik, or a Claude session, picking this work up on Stampede3.
Snapshot of 2026-10-19. Work up to 2026-10-18 was done on a Mac laptop; on
2026-10-19 it moved to Stampede3 (builds and test results below). The full
research plan lives only on that laptop, so the parts needed to continue are
copied here.

## Goal and deadlines

- **SIGSIM PADS 2027, second call: 2027-01-22.** 10-page ACM full paper,
  double-blind; conference June 9–11, 2027, Atlanta. About half time, alongside
  the SC27 "ACIC beyond SSSP" work. Collides with the IPDPS revision due
  2027-01-18 and the rebuttal (Nov 30 – Dec 3).
- Only Charm++ on **Reconverse** is used, never classic Charm++. The one
  non-Charm++ build is ROSS, as an MPI baseline.
- Aggregation goes in **htram**: transport mechanisms in htram, PDES policy in
  Charades. Reference builds of the IPDPS work pin htram tag `ipdps27`
  (7db9c0a), so htram `master` is free to change.

## Research direction

**Thesis link.** ACIC (SSSP) and optimistic PDES have the same shape:
asynchronous work ordered by a logical key (distance / virtual time), wasted
speculation (rejected relaxations / rollbacks), and a progress floor (histogram
minimum / GVT). The thesis claim is global-view control of speculation and
aggregation for such computations; this paper is the PDES chapter.

**Mechanism.** One mechanism, done properly:
- Charades sends remote events through htram instead of one Charm++ message
  each. Anti-messages and GVT control bypass aggregation. Buffered events
  count as in transit, and their earliest timestamp enters the GVT.
- A controller driven by a timestamp histogram piggybacked on the GVT
  reduction sets an urgency threshold (send events near the GVT frontier at
  once), the buffer size, and optionally an optimism window or event holding.

**Prior work that bounds the claim:**
- **Devastator** (Bachan et al., PADS'24) already controls optimism globally:
  a time window tuned by hill climbing on committed/executed, piggybacked on
  GVT. On its own Gaussian PHOLD it loses to ROSS by 8.7× when communication
  is remote-heavy (σ = 10⁴), and names that as future work.
- **Mikida & Kale, "An Adaptive Non-Blocking GVT Algorithm" (PADS'19)** — in
  Charades itself. It introduced the bucketed GVT (`gvt=4`). Its Section 5
  holds outgoing events more than a cutoff ahead of GVT, annihilates a held
  event with its anti-message in the sender, and releases held events as GVT
  advances (30–55% fewer PHOLD events sent; up to +18% PHOLD, +70% dragonfly
  event rate). The cutoff is static, chosen offline; no aggregation; all runs
  one PE per process.
- Also: Elastic Time / NPSI (Srinivasan & Reynolds) and Ferscha PADS'95
  (global state → optimism); Chetlur/Wilsey PADS'98 (local-rate adaptive
  aggregation); Mikida 2018 (leash throttle tuned offline); TramLib (IA3'24);
  Williams et al. PADS'21 (ROSS-MC-CMT); Steinman's Breathing Time Warp
  (holding sends past the event horizon; verify the citation).

**So the claim is:** control from a timestamp *distribution* rather than a
scalar efficiency, joint with aggregation, adapted online rather than from an
offline cutoff, with several PEs per process — and winning the remote-heavy
regime where Devastator loses.

**Baselines (same engine, policy differs):** no aggregation; opportunistic
aggregation (ship whatever is queued each scheduler pass, as Devastator does);
best fixed (size, timeout) under a fair tuning budget; PADS'98-style local-rate
controller; **Mikida & Kale's static-offset hold**; Mikida's leash throttle;
Devastator's efficiency hill-climb window, reimplemented. Other engines: ROSS,
and Devastator if its public code (github.com/cychan-lbnl/devastator) builds.

**Workloads.** Headline: Devastator's Gaussian PHOLD (exponential delay,
Gaussian destination, 15 rays per LP, 100 LPs per core), σ swept 100 → 25600,
targeting the remote-heavy end. Also PHOLD sweeps (remote %, lookahead, event
population), a phase-changing PHOLD, dragonfly with phase-changing traffic,
and the traffic model.

**Metrics.** Committed events/s; efficiency (committed/executed); rollback
counts and depth; physical messages and items per message; event residence
time percentiles; GVT rate; controller overhead. 1–32 nodes.

## Timeline and gates

| Window | Work | Gate |
|---|---|---|
| now – Nov 2 | Build on Stampede3; `tests/test.py` passes there | Tests pass on 2 machines |
| Nov 3 – Nov 16 | Gaussian PHOLD; per-event latency/residence instrumentation; profile per-message overhead at 1–16 nodes | **Go/no-go:** if per-message overhead is < ~10% of runtime at 4–16 nodes, aggregation can't matter → pivot to optimism control only |
| Nov 17 – Dec 7 | htram `-DPDES` fixed-slot flavour, urgent-send and min-key APIs; Charades sends through htram; ROSS comparison | Identical committed results vs. unaggregated on deterministic configs |
| Dec 8 – Dec 28 | Histogram controller; baselines; ablations | Adaptive ≥ best fixed on ≥ 2 workloads |
| Dec 29 – Jan 12 | Full runs 1–32 nodes | Every number has a job ID |
| Jan 13 – Jan 22 | Write | 10 pages |

Fallback if the go/no-go fails or time runs out: a 4-page short paper
(where time goes in a message-driven Time Warp, plus a first aggregation
result) and/or a 2-page PhD colloquium abstract.

## State of the code (2026-10-19)

| Repo | Branch / ref | State |
|---|---|---|
| charmplusplus/charades | `main` @ 09df056 | Reconverse port, SMP fixes, test harness, two optimistic-engine GVT fixes |
| charmplusplus/charades | `smp-gvt-fixes` | Bucketed GVT fixes (four-counter rule, 32-bit phase, index macros), event holding wired up, `Event::index` fix, init races, `test.py --repeat/--nodes`, srun-safe `test.py`, Gaussian PHOLD, Stampede3 scripts, this file. Pushed up to 7423578; later commits are local and on the Stampede3 clone only. |
| charmplusplus/charm | `recharm` @ 9d6a55780 | Includes user-driven interop on Reconverse (PR #4055, merged 2026-10-19). Pins Reconverse `main` ebafde2. All three builds (Mac, `charm-pads`, `charm-pads-qd`) are on this commit |
| charmplusplus/reconverse | `main` @ ebafde2 | Contains interop (#288, merged) |
| charmplusplus/reconverse | `idle-progress-poll` @ ff33b56 | QD speed fix; **PR #290** (open, not merged) |

**Why `idle-progress-poll` matters.** Reconverse's default scheduler polled the
network ~40 times per idle sweep before raising idle conditions. Quiescence
detection waits on those conditions every hop, so with one PE per process a QD
round took 10.7 ms instead of 0.39 ms on the Mac (libfabric TCP, a `kevent`
per poll). Synchronous GVT and the conservative scheduler use QD every round:
Charades conservative `long` went from 70 s to 4.1 s. On Stampede3
(Omni-Path, verbs) the cost per poll is far lower, but the fix still gives
3–4× (see "First Stampede3 measurements").

### First Stampede3 measurements (2026-10-19, idev job 3615231, 2 skx nodes)

`scripts/stampede3/ab_qd.sh 3`: pinned Reconverse vs. `idle-progress-poll`,
1 PE per process, 3 repetitions alternated (spread < 5%). QD loop is 500
back-to-back `CkStartQD` rounds; PHOLD is simple `long`.

| Nodes × processes | QD round, ms (pinned → fix) | Conservative exec, s | Blocking GVT exec, s |
|---|---|---|---|
| 1 × 1 | 0.025 → 0.021 | 0.26 → 0.24 | 0.03 → 0.03 |
| 1 × 2 | 0.51 → 0.13 | 3.72 → 1.22 | 0.07 → 0.05 |
| 1 × 4 | 0.55 → 0.16 | 4.15 → 1.61 | 0.11 → 0.09 |
| 2 × 2 | 0.51 → 0.13 | 3.81 → 1.26 | 0.07 → 0.05 |
| 2 × 4 | 0.56 → 0.17 | 4.34 → 1.82 | 0.12 → 0.09 |
| 2 × 8 | 0.89 → 0.27 | 6.61 → 2.65 | 0.15 → 0.10 |

So PR #290 is worth 2.4–3× on QD-bound runs here too; use the `-qd` build
for anything that uses QD until it merges.

Synchronous vs. bucketed GVT, Gaussian PHOLD (4,096 LPs, 15 start events
per LP, end time 32,000; `scripts/stampede3/gvt_cost.sh`), pinned
Reconverse, one run each, 16 PEs on 2 nodes:

| σ | Layout | Blocking | Bucketed (size 8) | Bucketed (size 256) |
|---|---|---|---|---|
| 100 | 2 procs × 8 PEs | 1.33 s | 1.04 s | 1.20 s |
| 100 | 16 procs × 1 PE | 1.88 s | 1.59 s | 1.60 s |
| 2000 | 2 procs × 8 PEs | 3.85 s | **hangs** | **hangs** |
| 2000 | 16 procs × 1 PE | 3.53 s | 5.84 s | 6.00 s |

Committed counts match across GVTs (1,961,605 at σ = 100; 1,961,944 at
σ = 2000). Bucketed rolls back 32–540× more events than blocking (e.g.
1.87 M vs. 3,750 at σ = 2000, 16 × 1): with no throttle, optimism runs away
in the remote-heavy regime — the regime the paper targets.

**The σ = 2000, 2 × 8 "hang" is a Time Warp rollback storm, not a runtime
bug** (diagnosed 2026-10-19, idev job 3615673). GVT stops advancing while
the network is saturated: each node received ~10 M packets in 30 s (hfi1
`RxPkt`), 3.5× what the whole run needs (2.8 M), and gdb shows most PE
threads in `charm_anti_send` under rollback/cancel processing. The bucketed
GVT never throttles execution, so the rollback cascade can grow instead of
dying out. With `--optimism-window` (added 2026-10-19), default transport:

| Window | Result | Rolled back |
|---|---|---|
| 1,000 | 10.9 s | 3.0 M |
| 3,000 | 52 s | 24.6 M (committed: 1.96 M) |
| 10,000 / none | no progress in 90 s | — |

Whether a run stays stable also depends on latency, which is why transport
changes "fixed" it: `+lci_ndevices` 2/4/8 (4.5/8.9/14.5 s), libfabric
`FI_OFI_RXM_MSG_RX_SIZE=1024` (9.6 s; the TX size, completions per
progress, and more connections per peer did not help), `tcp;ofi_rxm` (7.7 s),
or 4 processes × 8 PEs instead of 2 (6.1 s). It needs ≥ 8 PEs per process
with 2 processes (7 is fine). Ruled out: LCI's per-device lock starving the
CQ poller (no change with LCI locks off) and receiver-not-ready retries
(hfi1 `RnrNak` stays 0).

So the remote-heavy regime is unstable without optimism control, exactly as
Devastator reported — this is the paper's motivating problem, now
reproducible in Charades on two nodes.

### Optimism window sweep (2026-10-19, idev job 3615917, 4 skx nodes)

`scripts/stampede3/window_sweep.sh` on the `-qd` build: Gaussian PHOLD,
128 LPs per PE, 15 start events per LP, end time 128,000, mean delay 1,000,
lookahead 100. CSVs in `$WORK/charades-runs/window_sweep/` (`sweep1.csv`
3 reps, `sweep2_small.csv` 2 reps, `sweep3_ppn1.csv` 2 reps). Committed
counts are identical across every GVT and window for a given (nodes, σ), so
the window does not change results. Medians, M committed events/s
(efficiency):

2 processes × 8 PEs per node (32 PEs on 2 nodes, 64 on 4):

| Nodes | σ | Blocking | Bucketed, no window | w=125 | w=250 | w=500 | w=1000 |
|---|---|---|---|---|---|---|---|
| 2 | 100 | 2.65 (99%) | 2.28 (57%) | 2.56 (100%) | 2.42 (98%) | 2.23 (90%) | 2.19 (74%) |
| 2 | 500 | 1.21 (99%) | 0.57 (50%) | 1.25 (100%) | 1.28 (98%) | 1.02 (83%) | 0.55 (48%) |
| 2 | 2000 | 0.68 (99%) | 0.35 (58%) | 0.67 (100%) | 0.68 (97%) | 0.46 (71%) | 0.33 (54%) |
| 2 | 8000 | 0.70 (99%) | 0.37 (60%) | 0.69 (100%) | 0.68 (97%) | 0.55 (78%) | 0.46 (70%) |
| 4 | 100 | 4.66 (99%) | 3.93 (51%) | 5.00 (100%) | 5.21 (99%) | 4.09 (94%) | 4.58 (85%) |
| 4 | 500 | 2.26 (99%) | 1.01 (46%) | 2.34 (100%) | 2.25 (99%) | 1.57 (84%) | 1.02 (51%) |
| 4 | 2000 | 1.27 (99%) | 0.67 (58%) | 1.31 (100%) | 1.32 (99%) | 1.02 (82%) | 0.62 (55%) |
| 4 | 8000 | 1.17 (99%) | 0.59 (56%) | 1.22 (100%) | 1.22 (99%) | 0.93 (80%) | 0.60 (57%) |

1 process × 8 PEs per node (the layout that storms; 16 / 32 PEs):

| Nodes | σ | Blocking | No window | w=100 | w=250 | w=500 | w=1000 |
|---|---|---|---|---|---|---|---|
| 2 | 500 | 0.66 | 0.21 (34%) | 0.65 (100%) | 0.63 (94%) | 0.29 (49%) | 0.21 (34%) |
| 2 | 2000 | 0.53 | **stalls 2/2** | 0.53 (100%) | 0.50 (94%) | 0.24 (50%) | 0.20 (44%) |
| 4 | 500 | 1.33 | 0.92 (65%) | 1.38 (100%) | 1.37 (98%) | 0.85 (73%) | 0.90 (64%) |
| 4 | 2000 | 0.74 | 0.42 (59%) | 0.80 (100%) | 0.78 (97%) | 0.50 (68%) | 0.42 (60%) |

What it says:
- Unthrottled bucketed GVT runs at 0.3–0.6× of blocking once σ ≥ 500, and
  can stall outright. The efficiency loss is the whole story: rollbacks.
- A window of 1–2.5 lookaheads (100–250; a quarter of the mean delay)
  removes the rollbacks and matches blocking (0.91–1.13×, mostly within the
  run-to-run spread). Windows ≥ the mean delay buy almost nothing. Below the
  lookahead (w=50) is ~5–10% slower.
- With rollbacks gone (≈100% efficiency) the rate still falls 3.9× from
  σ = 100 to σ = 2000 at 2 nodes, and flattens past σ ≈ 2000: the remaining
  cost is per-event communication across processes and nodes. That is the
  ceiling aggregation would have to raise — the first evidence for the
  go/no-go, to be confirmed with per-message overhead measurements.
- So the static optimum here is a small window, and it is model-dependent
  (it tracks lookahead / delay): the case for an online controller is
  robustness across models and phases, not beating the best static window
  on a steady PHOLD.

### Per-message cost and scaling (2026-10-20, idev job 3620576, 8 skx nodes)

Uniform PHOLD (the thesis's PHOLD Base shape: 64 LPs per PE, 16 start
events, mean delay 1,000, lookahead 100; destination uniform with
probability `remote`, else a self-send), end time 256,000, 2 processes × 8
PEs per node, `-qd` build, `+lci_ndevices 8`, `--comm-stats=1`, 2 reps.
`scripts/stampede3/window_sweep.sh` with `WORKLOAD=uniform`; analysis
`scripts/stampede3/comm_summary.py`. CSV:
`$WORK/charades-runs/window_sweep/uniform_scale_fixed.csv` (run after the
startup-race fix below; the pre-fix run agrees within a few %).

**LCI devices.** With the default single device, 8 PE threads share it and a
send call costs 26–29 µs (52–60% of PE time) at remote 0.5 on 2 nodes;
2/4/8 devices: 15/11/9.3 µs, and +30–40% event rate at 8. Use
`+lci_ndevices 8` (one per PE) for all communication measurements.

**Per-message cost** — fit of PE-time per committed event against remote
messages per committed event, window 250 (≥ 99% efficiency):

| Nodes | Per event | Per remote message | of which send call | Messages' share of time, remote 0.1 / 0.5 / 1 |
|---|---|---|---|---|
| 2 | 4.1 µs | 25.4 µs | 9.5 µs | 38% / 76% / 86% |
| 4 | 4.7 µs | 31.6 µs | 11.4 µs | 40% / 77% / 87% |
| 8 | 5.8 µs | 34.4 µs | 12.4 µs | 37% / 75% / 85% |

So the go/no-go is **GO**: per-message overhead is 37–87% of the run time
whenever ≥ 10% of events are remote, far above the 10% threshold. Most of
a message's cost is outside the send call (receive, scheduling, delivery).

**GVT setups** (M committed events/s; eff %):

| Nodes | remote | Blocking | Bucketed, no window | Bucketed, w=250 |
|---|---|---|---|---|
| 2 | 0 | 10.0 | 15.1 | 11.2 |
| 2 | 0.1 | 4.48 (96) | 1.77 (26) | 4.90 (100) |
| 2 | 0.5 | 1.75 (97) | stalls | 1.87 (99) |
| 4 | 0 | 16.7 | 28.6 | 18.5 |
| 4 | 0.1 | 6.97 (95) | 1.61 (13) | 7.94 (100) |
| 4 | 0.5 | 2.86 (97) | stalls | 3.04 (100) |
| 8 | 0 | 24.2 | 50.0 | 25.0 |
| 8 | 0.1 | 11.8 (95) | 1.90 (8) | 14.6 (100) |
| 8 | 0.5 | 4.98 (96) | stalls | 5.44 (100) |

- Unthrottled bucketed GVT collapses as soon as there is remote traffic
  (8–26% efficiency at 10% remote, stalls at ≥ 25%): every wasted event
  costs ~30 µs messages. The thesis (Mikida 2019) found non-blocking GVT
  faster than blocking at 64–1,024 nodes; its messages (PAMI/GNI, one
  process per core) were far cheaper.
- Bounded by a window, bucketed beats blocking, increasingly with nodes at
  10% remote (1.09× → 1.14× → 1.24×) — the thesis's direction, but only
  with optimism bounded.
- The best window depends on the traffic: with no remote events, w=250
  halves the rate at 8 nodes (25 vs. 50 M/s); with any, it is essential.
  A static window cannot be right for both — the case for the controller.

**Fixed so far** (details in the commit messages):
- Builds against Charm++ on Reconverse; Makefiles track header dependencies
  (`src/module.mk`, `src/model.mk`); unknown or malformed options abort (the
  old tests passed `--synch` and silently ran conservative).
- SMP: PE 0 broadcasts the start; thread-safe dispatcher table, message ids,
  LP and GVT-manager proxies, RNG table, load-balancing settings; LP mapping
  validated at startup.
- Synchronous GVT with async reductions: stale results dropped, PE held until
  it contributes.
- Optimistic engine: a straggler's rollback left its LP's token late; cancel
  processing skipped LPs (heap reordered mid-loop). Both let GVT pass pending
  work and predate the port.
- Bucketed GVT: one wave's sent==received sums were not a consistent cut
  (~20% failures at 3–4 PEs per process); now Mattern's four-counter rule.
  Cost at 256-LP PHOLD, 4 PEs: same run time, ~5% fewer GVT rounds.
  Two more bugs found 2026-10-19, so the earlier bucketed stress results
  were weaker than they looked:
  - `RemoteEvent::phase` (the bucket) was 8 bits. Every test config has
    8,000–128,000 buckets (bucket size 8), so past bucket 255 events were
    counted in `b mod 256` and later buckets had no in-transit accounting at
    all. New assertions fire at once if this regresses.
  - `SENT_IDX`/`RECV_IDX` lacked parentheses, so the four-counter code read
    misaligned previous-wave counts after any wave that completed buckets.
- Event holding (PADS'19 Sec. 5) works now. The 2019 merge brought in the
  hold code in `bucketed.C` but not its send side: `produce()`'s answer was
  ignored (held events were sent anyway; cancelled anti-messages were sent
  after being deleted), anti-messages never had `anti` set, and the fields
  were uninitialized. Options (2018 names): `gvt-adaptive-buckets`,
  `gvt-reserve-buckets` (the static cutoff), `gvt-reserve-threshold`,
  `gvt-clear-lag`, `gvt-clear-buckets`. Test configs `bucket_hold`,
  `bucket_hold_early`.
- `Event::index` was 8 bits: a chare with > 256 pending events corrupted its
  heap.
- SMP startup race (2026-10-20): in interop SMP, option parsing runs only on
  rank 0 of each process, but PE 0 created the scheduler group right after
  its own parse, so worker ranks of other processes could construct it with
  default settings (event buffer, GVT scheme/trigger/interval, bucket size,
  window...). Exposed by `+lci_ndevices 8` at ≥ 4 nodes (8192-event buffer
  aborts). PE 0 now creates the group from a quiescence callback. Results
  before this fix were rechecked on 2 nodes (same picture).
- Permanent assertions catch GVT running ahead: LP token vs. earliest pending
  event at each synchronous GVT contribution; events or anti-events arriving
  below GVT; committing an event that is in the cancel queue.

**Test status.**
- Mac: full matrix 360/360; 0 failures in 1,800 synchronous-GVT stress runs
  at 2–4 PEs. (The 1,400 bucketed runs from 2026-10-18 predate the phase and
  macro fixes.)
- Stampede3, 2 skx nodes, `verbs;ofi_rxm`, libfabric 2.7.0 (idev job
  3615231): `--quick` on one node 160/160; full matrix with `--nodes 2`
  360/360 (before the phase and macro fixes). Bucketed stress
  (`--quick --repeat 20 bucket`, phase fix only): 599/600; the failure was a
  `double free or corruption (!prev)` at exit in Example `base` at 4 PEs, not
  reproduced in 300 reruns.
- After all bucketed fixes (four-counter, phase width, macros) and event
  holding: Mac `--quick --repeat 15 bucket bucket_hold bucket_hold_early`
  1350/1350. Stampede3 `--nodes 2 --quick --repeat 10` of the same configs:
  417/417 before it was stopped for time (the slow `bucket_hold` cases),
  then `--repeat 2 bucket_hold bucket_hold_early` over every model config
  132/132. Quick matrix of the other configs with `--nodes 2`: 176/176.
- Mac full matrix with every config (including `gaussian`, `bucket_hold`,
  `bucket_hold_early`): 550/550.

### Aggregation through htram (2026-10-20, idev job 3621217, 4 skx nodes)

**Code.**
- Charades branch `htram`; htram branch `pdes` (UIUC-PPL/htram, off master `d877a09`).
- Built in only when `src/config.mk` sets `HTRAM_DIR` (`src/htram.mk`).
  Charades then compiles `htram_group.C` itself with `-DPDES -DBUCKETS_BY_DEST -DPDES_TIMED`, so both sides agree on the item layout.
- `simcore/aggregation.{h,C,ci}`:
  - an `Aggregator` group per PE;
  - `agg_send()` copies a `RemoteEvent` into a fixed 64 B `PdesItem` (72 B with `PDES_TIMED`) after `produce()` has counted it;
  - htram's batch callback rebuilds the event on the destination PE and calls `recv_remote_event`, which consumes it.
- What bypasses htram:
  - payloads over `PDES_PAYLOAD_BYTES` (16) go directly. Imbalanced PHOLD's message is 24 B, so all of its events go directly;
  - anti-messages and GVT traffic.
- Options:
  - `--aggregation`
  - `--agg-mode` (WPs=0, WsP=1, PP=2, WW=3)
  - `--agg-buffer` (events)
  - `--agg-urgent=T` (ship if ts < GVT + T)
  - `--agg-scope` (1: only events to other processes)
  - `--agg-gvt-flush` (0/1/2)
- Flush rules, each needed for correctness or liveness:
  - a PE with nothing it may execute (idle or window-blocked) calls `flushIdle`;
  - every GVT update flushes everything (`--agg-gvt-flush=2`, required with bucketed GVT);
  - a PE flushes before joining a blocking (QD-based) round, because QD cannot see buffered events;
  - under bucketed GVT every event in the sender's current bucket ships at once. That bucket can't complete while one of its events sits in a buffer, and a busy PE never idles.
- Startup chain on PE 0, each step on quiescence: htram's node groups → HTram → Aggregators → scheduler group. HTram's own start reduction can't be used: on one PE it completes inside HTram's constructor, before that branch is registered.

**htram changes (`pdes`).**
- `PdesItem`.
- `insert`, `flushTo`, `insertUrgent`, `flushPending` and `setAggregationMode`, so one send/flush policy means the same thing in all four modes. WsP and PP had no per-destination flush, and `flushIdle` did nothing in them.
- WW receive leaked its batch array.
- PP's shared node buffer had three bugs, found here:
  1. Relaxed atomics only, once BUCKETS_BY_DEST compiles out the mailbox fences. That's fine on x86, a race on ARM.
  2. A PE waiting for a busy buffer, or flushing one, kept `fetch_add`ing `get_idx`, which wrapped past `INT_MAX` during a stalled ship. The result was segfaults at `0xffffffd8…` (−2³¹ × 80 B) with 16-item buffers.
  3. Waiting at all deadlocked across processes. The shipper's LCI send retries until the destination progresses, while the destination's PEs wait on their own shipper. Now a PE that finds the buffer busy sends its 16-item local buffer alone (`local_bypasses`).

None of this touches the WPs path the SSSP client uses. GRAPH, GRAPH with compact wire, and HISTO still compile, but the SSSP parity check has **not** been run yet.

**Correctness.**
- Mac:
  - final code, every `agg_*` config at 1/4/2×2 PEs, `--repeat 3`: 891/891;
  - before the PP fixes: `--repeat 10` on the bucketed ones 1650/1650;
  - full matrix including `agg_*`: 1319/1320. The failure was PP bucketed at 3 PEs with empty output, not reproduced in 300 reruns, and predates the PP fixes.
- Stampede3, 4 nodes, final code:
  - `agg_blocking_*` and `agg_conservative_wps` at 4×4, 2×8 and 1×8: 165/165;
  - `agg_bucket_*` at 4×4 and 1×8: 88/88.
  
  Bucketed at 2×8 is excluded because of the pre-existing hang below.
- New launch shape 2×8: plain `bucket` (no aggregation) hangs on Imbalanced PHOLD `combo` and `noself`. It stalls at 54% of the end time, with every worker in LCI `post_am` retry. Same mechanism as open issue 5; see open issue 7.

**Stage 1: mode × buffer** (uniform PHOLD, remote 0.5, 4 nodes × 2 processes × 8 PEs, 8,192 LPs, `+lci_ndevices 8`, `--comm-stats=1`, 2 reps; `$WORK/charades-runs/agg_sweep/stage1_all.csv`; M committed events/s):

| GVT | direct | WPs 64 | WsP 64 | PP 64 | WW (any buffer) | events/msg | cross-node latency |
|---|---|---|---|---|---|---|---|
| blocking | 2.99 | **9.04 (3.02×)** | 8.79 | 8.58 (8.89 at 1024) | 5.6–5.9 | ~15 (WW 2.3) | 187 → ~510 µs |
| bucketed, window 250 | 2.97 | 6.12 (2.06×) | 4.11 | **6.27 (2.11×)** | 4.1–4.7 | ~3 (WW 1.5) | 118 → ~290 µs |

- Send-call time falls from 11.3–11.7 µs to 0.3–0.5 µs per event. Efficiency stays at 97–99%.
- **Buffer size above 64 changes nothing.** Events per message saturate (~15 blocking, ~3 bucketed), so the flush cadence is the binding constraint, not the buffer:
  - blocking: one flush per GVT round;
  - bucketed: current-bucket events are urgent, and every bucket advance flushes.
  
  That cadence is what the controller should set.
- Predictions, checked:
  - "WW fewest events per message": yes.
  - "WPs or PP best": yes, with WsP tied under blocking.
  - "PP most events per message": no, same as WPs.
  - "urgency matters most under bucketed": the cadence does.
- WsP under bucketed is only 1.3×: its receive hands the whole message to every PE of the node, and each scans for its range.
- With aggregation, blocking now beats bucketed + window (9.0 vs 6.3). Direct, they are equal at this remote fraction.

**Other remote fractions and 2 nodes** (64-event buffers, 2 reps; `stage1_remote.csv`, `stage1_n2.csv`):

| nodes | remote | GVT | direct | WPs | PP | events/msg |
|---|---|---|---|---|---|---|
| 4 | 0.1 | blocking | 7.12 | 11.10 (1.56×) | 10.92 (1.53×) | 3.3 |
| 4 | 0.1 | bucketed w250 | 7.02 | 8.47 (1.21×) | 8.49 (1.21×) | 1.4 |
| 4 | 1.0 | blocking | 1.80 | 7.06 (3.93×) | **7.17 (3.99×)** | 31 / 21 |
| 4 | 1.0 | bucketed w250 | 1.74 | 4.92 (2.83×) | **5.66 (3.25×)** | 6–7 |
| 2 | 0.5 | blocking | 1.82 | **6.06 (3.34×)** | 5.75 (3.17×) | 31 / 21 |
| 2 | 0.5 | bucketed w250 | 1.78 | 4.25 (2.39×) | 4.13 (2.33×) | 5.3 |

- Blocking GVT at 10% remote reaches about the ceiling the per-message fit predicted (~1.6×).
- Bucketed GVT gets roughly half the possible gain, held back by its flush cadence.

### Deadline flush policy (2026-10-20, idev job 3621758, 4 skx nodes)

**The policy.** `--agg-policy=1`:
- events go into htram keyed by timestamp (`HTram::insert(item, pe, key)`, which tracks the minimum key per destination);
- an event with ts < GVT + h ships at once;
- idle PEs and GVT updates call `flushDue(GVT + h)`, which ships only destinations holding a due event.

`--agg-horizon` h defaults to the optimism window W. The rationale: no receiver may execute past GVT + W, so an event beyond that can wait at no rollback cost.

**Why it was needed.** The flush-cause counters showed eager bucketed runs sending 96% of their messages from *idle* flushes. Window-blocked PEs shipped about 3 events per pass. The current-bucket urgent rule never fired, because lookahead 100 is far more than the bucket size of 8.

**Statistics added.**
- htram messages by cause: full / urgent / idle / GVT update / GVT round.
- With `--comm-stats`, remote-event slack on arrival (ts minus the chare's current time): straggler % and quantiles.

**Results** (uniform PHOLD, 4 nodes × 2 processes × 8 PEs, `+lci_ndevices 8`, 64-event buffers, 2 reps; `$WORK/charades-runs/agg_sweep/policy_{a..f}.csv`; M committed events/s, given as WPs / PP; direct given as blocking / bucketed):

| workload | blocking, eager | bucketed, eager | bucketed, deadline h = W | direct |
|---|---|---|---|---|
| remote 0.1, lookahead 100, mean 1000, W 250 | 11.05 / 11.12 | 9.69 / 8.73 | 10.56 / **11.22** | 7.20 / 7.59 |
| remote 0.5, same slack, W 250 | 8.69 / 8.55 | 5.62 / 5.25 | 7.77 / **9.83 (3.4×)** | 2.99 / 2.88 |
| remote 1.0, same slack, W 250 | **7.20** / 7.07 | 4.47 / 5.24 | 6.30 / **7.30 (4.15×)** | 1.79 / 1.76 |
| remote 0.5, lookahead 10, mean 200, W 25 | 5.31 / 5.68 (84–88% eff) | 7.10 / 7.01 | 7.78 / **8.10** | 2.95 / 2.93 |

- **Horizon.**
  - Below W the policy breaks: events arrive after receivers may have passed them. WPs at W 250, h 8–125: 8% stragglers, 47–62% efficiency.
  - At W it works: under 2% stragglers, 22–48 events per message instead of about 3.
  - Above W, more events are due on insert and messages shrink: h = 2W gives 1.9×, h = 4W gives 1.2–1.4×.
  - Low slack, W 25: h = 32 is about as good as 25. At W 50, horizons 8–32 lose (h = 50 was not run).
  - The default of 2W came from a 4-PE single-process Mac test and was wrong.
- **PP vs. WPs below W:** PP degrades less, because its shared per-process buffers fill and ship on their own (92–98% of its messages), which bounds how long events wait.
- **Blocking GVT:** the deadline policy with h = 0 equals eager (round flushes only).
  - At default slack, a horizon only adds urgent flushes: h 250 to 1000 gives 2.9× down to 1.2×.
  - At low slack, h = 32 *helps*: 7.96 vs 5.31, efficiency 84% → 97%. Shipping due events promptly cuts stragglers.
- **Low slack needs a matching window.** At W 250, bucketed GVT runs at 10.6% efficiency even with direct sends (a rollback storm); at W 25 or 50 it reaches 98–100%.
- **Conclusion: the right window and horizon both follow the workload's timestamp slack.** That is the controller's job:
  - W from the slack distribution;
  - h = W, plus a small margin when GVT advances quickly.

**Correctness.**
- Stampede3, 4 nodes: every `agg_*` config at 4×4, 144/144 (traffic excluded, open issue 8).
- Deadline configs with the final default at 4×4 and 1×8, 2 repeats: 264/264.
- The payload slot is now 24 B, so Imbalanced PHOLD and traffic go through htram.

### Window controller (design, 2026-10-20; written before any runs)

**The rule.**
- A remote event straggles when it arrives behind its receiver: ts < t_r, the receiver's current time.
- It was sent at the sender's current time t_s with delay δ = ts − t_s.
- Under a window W, both t_s and t_r lie in [GVT, GVT + W], so a straggler needs δ < t_r − t_s ≤ W.
- Hence primary stragglers per executed event ≤ r · F(W), where r is remote sends per executed event and F is the CDF of δ over remote sends.
- The controller holds that bound at a target ε: W = F⁻¹(min(q_max, ε / r)).
  - When ε / r ≥ q_max (little remote traffic), W is the q_max quantile, so the window rarely binds.
  - Under bucketed GVT, W ≥ bucket size (liveness).
- The deadline horizon follows: h = W.
- F is a property of the model, not of the window, so this is feed-forward. Devastator's hill climb (PADS'24) and Elastic Time instead feed back from an outcome (efficiency, or the state of the system).

**Mechanism.**
- Each PE builds a log-linear histogram of δ over its remote sends (8 sub-bins per power of two), plus deltas of events executed, rolled back, committed, timestamp rollbacks (stragglers) and remote sends.
- After each GVT update, a PE contributes once per round to a sum reduction (a `Controller` group).
- The broadcast result goes to every PE, and each computes the same W from the same data.
  - New delays fold into the global histogram once 256 have arrived, and the histogram is halved at each fold, so it follows phase changes.
  - Folding by sample count, not by round, was a fix: rounds can carry about 20 delays (4 PEs, 8-unit buckets). Halving every round held the histogram under the minimum, and W froze.
- **Calibration (`--ctl-calibrate=1`, the default), added after the first local runs.**
  - The bound is very loose in practice. On 4 PEs in one process (lookahead 10 / mean 200), the uncalibrated rule at ε 0.05 gave 0.0001 stragglers per event; even with no window the rate is only 0.025.
  - So the rule scales the bound by α = (stragglers seen per executed event) / (r · F(W)) at the window in force, giving W = F⁻¹(min(q_max, ε / (r·α))). α moves by at most 2× per fold.
  - The realised rate then tracks ε: ε 0.005 → 0.007, ε 0.001 → 0.0024. Where even an unthrottled run stays under ε, W opens to the q_max = 0.99 quantile.
  - ε is now a target straggler rate rather than a bound, and α (0.02–0.09 locally) measures how loose the bound is.
  - *Superseded on Stampede3, the same day:* calibration now targets the rolled-back share of executed events, not primary stragglers, and α moves at most 1.25× per fold. See "Window controller, first Stampede3 results".
- Options: `--ctl=1` (quantile rule), `--ctl=2` (Devastator's hill climb, reimplemented from the paper's Sec. 2.1 as a baseline in the same loop), `--ctl-epsilon` (default 0.05), `--ctl-calibrate`, `--ctl-log` (one line per round on PE 0).
- The hill climb's W is capped at the end time: past it a window changes nothing, and doubling while efficiency stays above 95% overflowed.
- Phase-changing PHOLD: `--phase-length`, `--alt-lookahead`, `--alt-mean`, `--alt-remote` (odd phases), plus the test dataset `phases`.

**Local check (Mac, 4 PEs, 1024 LPs, phases of 40,000, base lookahead 10 / mean 200, alt lookahead 100 / mean 1000, remote 0.5).**
- Uncalibrated: W averages 31 in base phases and 196 in alt, as predicted (30 and 195). Each switch takes under a quarter of a phase.
- Calibrated at ε 0.005: W averages 115–144 in base and 830–1100 in alt.
- The hill climb goes to W = end time (no window) at 89% efficiency: one process is benign.
- Single-process rates are too noisy to rank the policies (fixed W 192 spans 3.1–5.2 M ev/s over 3 repeats). Rankings wait for Stampede3.

**Check against measurements so far.**
- PHOLD with lookahead 100, mean 1000: δ = 100 + Exp(900).
  - At remote 0.5 and ε = 0.05, q = 0.1 → W ≈ 195.
  - The window sweep's best fixed W was 125–250.
- Lookahead 10, mean 200, remote 0.5: q = 0.1 → W ≈ 30. W 25–50 gave 98–100% efficiency; W 250 gave 10%.

**Predictions** (to be checked on 4 Stampede3 nodes, bucketed GVT, deadline policy, PP and WPs):
1. A single ε (0.02–0.1) lands within 10% of the best fixed W in each of three regimes:
   - lookahead 100 / mean 1000;
   - lookahead 10 / mean 200;
   - remote 0.1, 0.5 and 1.0, where W should grow as r falls.
2. On a phase-changing PHOLD that alternates those slack regimes, the controller beats every fixed W.
3. The hill climb approaches the best fixed W on steady workloads, but lags after each phase change. With W 250 at low slack it first goes through the rollback storm, and it loses most at remote 1.0 (Devastator's own weak spot).
4. Realised straggler % stays well below ε (the bound is loose). If it is far below, a feedback trim on ε is the follow-up. *Confirmed locally at once (0.0001 vs 0.05); calibration is that trim, so predictions 1–3 now apply to the calibrated rule, with ε as the target rate.*

### Window controller, first Stampede3 results (2026-10-20, idev job 3622528, 4 skx nodes)

**Fixes from the first 4-node runs** (commits 6f1cbc5, 81f1461):
- Starting from W 2000 set off a rollback storm that slowed GVT, and so the controller, for most of a run (6% efficiency). `--ctl=1` with no `--optimism-window` now starts at the smallest window and opens it.
- Only 0.017 primary stragglers per event rolled back 94% of events (cascades). Calibration now targets the rolled-back share of executed events, so ε is the waste the rule aims for, and α absorbs cascades.
- One reduction per GVT update cost 12–20%. Rounds now come every 8 GVT updates (`--ctl-interval`); with W held steady by the bare bound, the remaining cost is 2–9%.
- α moved up to 2× per fold, and W swung 12–60 around a best fixed W of 25. It now moves a quarter of the way per fold (in log), at most 1.25×.

**Sweep 1** (`scripts/stampede3/ctl_sweep.sh`, `$WORK/charades-runs/ctl_sweep/sweep1.csv`):
- Setup: PHOLD, 4 nodes × 2 processes × 8 PEs, 128 LPs per PE, 15 start events, end 64,000, remote 0.5, bucketed GVT, htram PP with 64-event buffers and the deadline policy (h = W), `+lci_ndevices 8`, 3 reps.
- Values are median M committed events/s, with the ratio to the best fixed W in parentheses.

| arm | lookahead 10 / mean 200 | lookahead 100 / mean 1000 | phases of 8000 alternating the two |
|---|---|---|---|
| fixed W 25 | **9.67** (1.00) | 3.75 (0.40) | 7.39 (0.90) |
| fixed W 50 | 9.06 (0.94) | 6.42 (0.68) | **8.22** (1.00) |
| fixed W 100 | 5.94 (0.61) | **9.38** (1.00) | 6.77 (0.82) |
| fixed W 250 | 0.47 (0.05) | 9.02 (0.96) | 0.60 (0.07) |
| fixed W 500 | stalls 3/3 | 7.71 (0.82) | 0.29 (0.03) |
| quantile ε 0.02 | 8.48 (0.88), W 37, 98.0% eff | 8.14 (0.87), W 267, 98.0% | **8.31 (1.01)**, W 75, 98.0% |
| quantile ε 0.05 | 8.18 (0.85), W 65, 95.0% | 7.80 (0.83), W 391, 95.0% | 7.81 (0.95), W 123, 94.9% |
| quantile ε 0.1 | 7.09 (0.73), W 84, 89.7% | 7.10 (0.76), W 501, 89.8% | 6.42 (0.78), W 210, 84.2% |
| hill climb from 250 | 5.17 (0.53), W 97, 73.9% | 7.00 (0.75), W 494, 90.2% | 3.82 (0.46), W 237, 62.2% |

- **The best fixed W moves 4× between workloads (25, 100, 50), and a wrong one is catastrophic** (0.03–0.40).
- **The calibrated rule holds its efficiency target exactly** (98.0 / 95.0 / 89.7–89.8%).
  - It is never catastrophic, and on the phase-changing workload it beats every fixed W (prediction 2 holds).
  - Smaller ε is better throughout.
- **On steady workloads it reaches 0.87–0.88 of the best fixed W.** Prediction 1 (within 10%) misses narrowly.
  - The gap is not the choice of W: at high slack fixed W 250 gives 9.02 against the rule's 8.14 at W ≈ 267.
  - So about 10% is the controller's cost at a given mean W: rounds, W varying around its mean, horizon changes.
- **The hill climb loses everywhere** (0.46–0.75), worst on phases (62% efficiency). That fits prediction 3 and Devastator's own account.
  - It decided every 8 GVT updates, like the rule; sweep 2 tries every update (`hill1`).
- **Efficiency is not the objective by itself.** At high slack W 25–250 all run at 98.5–99.2% efficiency, but W 25 is 2.5× slower: a small window costs parallelism, not rollbacks.

**Sweep 2** (same setup, `sweep2.csv`, 3 reps; median M committed events/s, ratio to the best fixed W in parentheses):

| arm | lookahead 10 / mean 200 | lookahead 100 / mean 1000 | phases |
|---|---|---|---|
| best fixed W | 9.50 (W 25) | 9.53 (W 100) | 8.49 (W 50) |
| quantile ε 0.005 | 6.66 (0.70), W 11, 98.3% | 8.64 (0.91), W 99, 99.2% | 6.64 (0.78), W 21, 98.4% |
| quantile ε 0.01 | 6.70 (0.71), W 12, 98.3% | 8.65 (0.91), W 192, 99.0% | 6.70 (0.79), W 28, 98.4% |
| quantile ε 0.02 | 8.59 (0.90), W 38, 98.0% | 8.02 (0.84), W 264, 98.0% | 8.26 (0.97), W 74, 98.0% |
| hill climb every GVT (`hill1`) | 1.59 (0.17), W 210, 33% | 0.93 (0.10), W 1448, 24% | 1.46 (0.17), W 514, 32%; 1 of 3 failed |

- **Deciding after every GVT update, as Devastator's paper describes, makes the hill climb far worse** (0.10–0.17). Its 16-round efficiency average lags, so it keeps doubling W into a storm.
- **A waste floor: ε below about 1.6% is unreachable at low slack.**
  - Efficiency stays at 98.3–98.4% and stragglers at 0.006 per event, however small W gets.
  - The rule then drives W to its minimum (11–12 for ε 0.005–0.01) and loses parallelism (0.70–0.79).
  - Hypothesis: the bound assumes one GVT, but PEs learn of GVT updates at different times, so a receiver can lead a sender by W plus that skew (about a bucket or two), comparable to W at low slack. If so, the floor grows with the bucket size and does not move with W. Next: fixed W 8–25 × bucket size 4–16, with and without htram.
- **The remaining ~10% cost at a given mean W** is to be split with `--ctl-dry=1`: rounds and computation run, but W stays fixed.


### Waste floor, controller cost, horizon margin (2026-10-20, idev job 3623246, 4 skx nodes)

`$WORK/charades-runs/ctl_sweep/{floor_pp,floor_direct,dry,margin,sweep3_m8}.csv`. Setup as in sweep 1 (lookahead 10 / mean 200 unless noted).

- **The waste floor comes from htram's deadline holding, not the window.**
  - With htram (PP, h = W), efficiency is flat in W (8–25) at 96.6–97.2%, 98.3–98.5% and 99.3% for buckets 4, 8 and 16.
  - Sent directly, it is 99.9–100% everywhere.
  - Mechanism: a held event ships when its sender learns of the GVT update that makes it due. A receiver that learned of it first may already have run to the new GVT + W, and the waste per GVT update scales as 1 / bucket size.
  - My skew hypothesis (bound off by the GVT skew, floor growing with bucket size) was wrong in direction.
- **Fix: `--agg-horizon-margin` (h = W + m).**
  - With m ≥ 8, fixed W 25 runs at 99.9–100% efficiency, and controller stragglers fall from 0.004–0.011 to 0.0013 per event.
  - Throughput barely moves (the floor was small), and larger margins shrink messages. Fixed W 25 at bucket 8: m 0 / 8 / 16 / 32 → 9.32 / 9.78 / 8.63 / 6.81 M ev/s (2 reps). m = 8 (one bucket) is about neutral.
- **Controller machinery costs at most about 5%.** `--ctl-dry` against the same fixed W gives 0.95–1.00 (3 reps; one outlier at 1.35).
  - The rest of the earlier ~10% gap is the window choice: at ε 0.02 the rule spends its waste budget on a bigger W, which does not pay at low slack.
- **Bucket size is a knob too.** Bucket 16 with W 25 gives 10.2–10.4 M ev/s at low slack, the best so far, against 9.3–9.6 at bucket 8.
- **With m = 8, small ε becomes reachable and works** (sweep 3, 2 reps, ratio to the best fixed W):

| ε | lookahead 10 / mean 200 | lookahead 100 / mean 1000 | phases |
|---|---|---|---|
| 0.005 | 1.00 (W 43) | 0.83 (W 199) | **1.13** (W 71) |
| 0.01 | 0.84 (W 45) | 0.96 (W 256) | **1.14** (W 86) |
| 0.02 | 0.82 (W 54) | 0.93 (W 310) | 1.06 (W 101) |

  - At end time 64,000, high-slack runs last under 1 s, so start-up and noise are ±15%. A confirmation at end time 256,000 with 3 reps is in `sweep4_long.csv`.

### Two speeds of the bucketed GVT (2026-10-20, idev job 3623246)

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

### Two GVT speeds: cause and fix (2026-10-21, idev job 3624457, 4 skx nodes)

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

### Gaussian PHOLD σ sweep (design, 2026-10-21; written before any runs)

**Why.** Devastator (PADS'24) loses to ROSS by 8.7× (2 nodes) to 1.5× (16 nodes) on Gaussian PHOLD at σ = 10⁴, the remote-heavy end. This experiment asks where htram aggregation and the controller win on that benchmark, at 4 nodes.

**What σ means here.** Destinations are LP id + round(N(0, σ)), wrapping around; LPs sit in contiguous blocks (128 per PE, 1,024 per process, 2,048 per node; 8,192 in all at 4 nodes). Share of events that leave each level (% of events, computed):

| σ (LP ids) | leave the PE (%) | leave the process (%) | leave the node (%) |
|---|---|---|---|
| 100 | 54.9 | 7.8 | 3.9 |
| 500 | 89.8 | 38.2 | 19.5 |
| 1,000 | 94.9 | 62.4 | 38.2 |
| 2,000 | 97.4 | 80.0 | 62.3 |
| 4,000 | 98.4 | 87.3 | 74.6 |
| uniform, remote 1.0 | 98.4 | 87.5 | 75.0 |

- At 4 nodes, σ ≥ 8,000 is the same as uniform remote 1.0 (σ approaches the LP count). So the sweep stops at 4,000 and adds uniform remote 1.0 as the all-remote end.
- The same calculation at Devastator's layout (100 LPs per core, 128 cores per node assumed) reproduces their 0.6% off-node at σ = 100 and 80.5% at σ = 25,600 on 16 nodes. Results are compared by off-node share, not by σ.

**Setup.**
- 4 nodes × 2 processes × 8 PEs, 128 LPs per PE, 15 start events per LP, end time 64,000, lookahead 100, mean delay 1,000, `+lci_ndevices 8`, 3 reps.
- `ctl_sweep.sh`, once with direct sends and once with htram PP, 64-event buffers, deadline policy, margin 8.
- Arms in each: blocking GVT; bucketed GVT with fixed W 50 / 100 / 250 / 500; the hill climb from W 250; the controller at ε 0.01.

**Predictions.**
1. Aggregation gain, best htram arm ÷ best direct arm (both in M committed events/s, higher is better), grows with the off-node share:
   - at most 1.3× at σ 100;
   - at least 2× by σ 1,000;
   - 3–4× at σ 4,000 and uniform remote 1.0, as in the deadline-policy results (4.15× at remote 1.0).
2. With direct sends, throughput falls about 4× from σ 100 to 2,000 and then flattens, as in the October 19 window sweep.
3. The controller with htram lands within 10% of the best htram arm at every σ. Its mean window stays between 100 and 300 at every σ, because the delay distribution doesn't depend on σ and r only moves from about 0.55 to 0.98.
4. A fixed W of 250 is also within 10% of the best at every σ. On this benchmark the controller's value is not needing the sweep, not beating it.
5. The hill climb with htram reaches at most 0.85 of the best fixed W at σ ≥ 1,000.
6. At this slack (lookahead 100, mean 1,000), blocking GVT with htram is within 10% of the controller with htram, as at remote 1.0 earlier (7.20 vs 7.30 M ev/s). Bucketed GVT should pull ahead only at low slack. If time allows, a second pass runs lookahead 10 / mean 200 at σ 500 and 2,000, predicting the controller with htram at ≥ 1.3× blocking with htram.

## Open issues

1. **Event holding needs a realistic cutoff.** With the test configs'
   bucket size 8 and mean delay 1000, `gvt-reserve-buckets=1` holds nearly
   every remote event until GVT reaches its bucket, which serializes the run
   on GVT waves: PHOLD `long` takes 2 s on 1 PE and 11.6 s on 4 (0.56 s
   without holding); imbalanced `base` at 2x2 takes ~25 s. Correct, but pick
   the cutoff (and bucket size) per model before using it as the PADS'19
   baseline. Its statistics go to `gvt_<pe>.out` in the run directory.
2. CD GVT (`gvt=2`) and phased GVT (`gvt=3`) hang at more than one PE on every
   runtime (issue #11). `test.py` skips them unless `--all`.
3. Load balancing / migration never run on Reconverse or with several PEs per
   process; anti-message lookup trees draw nodes from a per-PE pool, flagged in
   the code as a migration problem. The paper runs with LB off.
4. Dragonfly and PCS still use the pre-2019 `ross_api.h` and don't build.
   Traffic builds but has no test configs.
5. **Unthrottled bucketed GVT is unstable in the remote-heavy regime**
   (σ = 2000, 2 × 8 PEs): a rollback storm that never settles (see "First
   Stampede3 measurements"). Not a runtime bug. Use `--optimism-window` (or
   blocking GVT) for any bucketed run; picking the window is the controller
   problem. Reproduce: `scripts/stampede3/gvt_cost.sh` once, then
   `scripts/stampede3/try.sh 90 2 2 16 x -- $WORK/charades-runs/gvt_cost/gauss_2000
   tests/test_configs/bucket`.
6. One `double free or corruption (!prev)` at exit in ~600 Stampede3 runs
   (Example `base`, bucketed, 4 PEs, one process); no core was kept. Run
   `scripts/stampede3/repro.sh` with cores enabled if it shows up again.
7. **Bucketed GVT hangs on Imbalanced PHOLD at 2 × 8 PEs** (`combo`, `noself`;
   without aggregation too). It's a launch shape the earlier matrices never ran.
   Stacks (`$WORK/charades-runs/hang/imbalanced_combo_bucket_2x8/`) show every
   worker in LCI `post_am` retry inside Reconverse's send loop
   (`comm_backend_lci2.cpp:305`); on the Mac LCI warns "device does not have any
   posted recvs". Same rollback-storm/backpressure picture as issue 5. Exclude
   that shape from aggregation gates until it's fixed or windowed.
   `scripts/stampede3/catch_hang.sh` reproduces it and saves stacks.

8. FIXED 2026-10-20: **traffic's committed count was not deterministic.**
   - **Symptoms:** sequential 14718; 14789 on one process; 14766–14794 across Stampede3 processes; failures in single-process runs too.
   - **Cause:** `CustomEventComparator`, which orders each chare's pending heap, called equal-timestamp events for *different* LPs equivalent in both directions while ordering those for the *same* LP. That is not a strict weak ordering. With A and C for one LP and B for another (A ≈ B, B ≈ C, A < C), the heap could pop C before A, depending on the rest of the heap and on arrival order.
   - **Why only traffic:** its events carry their own cars, so swapping two of them gives each car different random draws. PHOLD's events are interchangeable, so its counts never showed it.
   - **Fix:** order equal-timestamp events by destination LP. The order is now total; nothing changes between independent LPs. My first guess (event IDs not rewound on rollback) was wrong: IDs only order events from one source to one LP, which each source creates in its own deterministic order.
   - **Verification:**
     - every scheduler gives base 14789 and congested 15638, sequential included;
     - traffic matrix with every config, including aggregation, at 1–4 PEs and 2×1/2×2/4×1 processes: 296/296;
     - before the fix: 113/152;
     - traffic is back in `test.py`.
   - **Open:** the `USE_SPLAY` queue (off by default) still orders by timestamp alone.

## Building on Stampede3

Run Claude and VS Code locally, not on login nodes (per-user process limit,
`ulimit -u` = 300). Build and run on compute nodes inside `idev`.

**Getting a node.** `salloc` is refused by TACC's submit filter, and a
sleeping `sbatch` job driven with `srun --jobid --overlap` from the login node
was killed after 3 minutes (signal 53, job 3615217). What works: start idev in
a detached tmux on the login node and ssh to its master node:

```
tmux new -d -s idev "idev -p skx-dev -N 2 -n 96 -m 120 -A TG-ASC050039N"
scripts/stampede3/nd '<command>'      # from the login node; see its README
```

ssh shells on the node lack TACC's `MODULEPATH`, so `module load gcc/13.2.0`
silently does nothing (you get `/usr/bin/g++`, no cmake, and the Charm++
build falls back to `./buildold` and fails). Run `module use
/opt/apps/modulefiles` first; `nd` does this. `$WORK` metadata is slow:
expect long pauses early in the Charm++ build.

**Charm++.** Two trees in `$WORK`, built 2026-10-19 with gcc 13.2.0 and cmake
4.1.1 (from `reconverse-interop`; now checked out at `recharm` 9d6a55780,
which differs from the built commit only in CI files): `charm-pads` (Reconverse pinned at ebafde2) and `charm-pads-qd` (the
same, with Reconverse on `idle-progress-poll` ff33b56):

```
git clone -b recharm https://github.com/charmplusplus/charm.git charm-pads
cd charm-pads
git submodule update --init -- contrib/reconverse     # pinned ebafde2
# for charm-pads-qd only (PR #290):
git -C contrib/reconverse fetch origin idle-progress-poll && git -C contrib/reconverse checkout FETCH_HEAD
module use /opt/apps/modulefiles; module load gcc/13.2.0 cmake
./build charm++ reconverse-linux-x86_64 --disable-fortran -j24
```

- Don't pass `smp` (the reconverse target is always SMP). CMake options go in
  `--with-cmake-args="..."`; a bare `-DFOO=BAR` silently becomes a compiler
  flag. Check `<builddir>/include/conv-autoconfig.h` for `CMK_SMP` and
  `CMK_RECONVERSE`.
- `~/charm_reconverse` there is an old June build; don't use it.
- LCI is built with both ibv and ofi and loads `libfabric.so.1` by soname,
  so libfabric 2.7.0 can be swapped in at run time.

**Charades.** `$WORK/charades` (branch `smp-gvt-fixes`, against `charm-pads`)
and `$WORK/charades-qd` (a detached worktree of it, against
`charm-pads-qd`):

```
cd charades/src
cp config.mk.template config.mk      # set CHARADES_SRC and CHARM_DIR
make
cd ../models/phold/simple && make    # each model builds the library first
```

`config.mk` must keep `CFLAGS += -std=c++17`. Commits made elsewhere reach
the clone with `git push stampede3:/work2/09863/rrao/stampede3/charades
<branch>:refs/heads/incoming`, then `git merge --ff-only incoming` there.

**Environment for every run:** `source scripts/stampede3/env.sh`. It sets
LCI to libfabric `verbs;ofi_rxm` (the only provider that works on
Omni-Path besides tcp: default ibv aborts, psm2 hangs, opx fails at init),
uses libfabric 2.7.0 from node-local `/tmp` if
`scripts/stampede3/stage_libfabric.sh` was run on that node (the system
2.6.0a1 segfaults at exit in ~10% of runs), and in an ssh shell on the idev
node takes the job's `SLURM_*` variables from idev's environment file so
`srun` works.

## Running

- **Always `srun`, never `lcrun`, on the cluster — even for one process.**
  Inside an allocation LCI reads `SLURM_NTASKS` and waits for peers that never
  start. `srun --mpi=pmi2 -N <nodes> -n <procs> -c <PEs per process> ./phold
  +pe <total PEs> <model cfg> <sync cfg>`.
- `tests/test.py --launcher srun` does this for every run, with
  `--kill-on-bad-exit=1 --wait=30` and `-c <PEs per process>` (otherwise a
  process's PEs share one core), and on timeout sends SIGTERM before
  SIGKILL. `--nodes 2` spreads multi-process runs over two nodes. A SIGKILLed `srun` leaves its step registered, and every later
  `srun` in the allocation then fails ("step creation temporarily disabled");
  diagnose with `squeue -s -j <job>`.
- Debug in one interactive allocation (`idev`), stepping through by hand. Don't
  resubmit a failed batch job blind, and keep at most one job per dev queue.

## Testing practice

- Every model config sets `expected-events`; the simulator aborts on a
  mismatch, so a passing run has the right committed count.
- The races fixed so far failed in 0.5–20% of runs, which one pass usually
  misses. Use `python3 tests/test.py --quick --repeat 20 bucket` (or any
  configs) after touching the engine or a GVT.
- `python3 tests/test.py --help` lists the rest (`--quick`, `--all`,
  `--no-build`, `--timeout`). Output goes to `tests/test_output/`.

## Next steps, in order

1. DONE 2026-10-20 (see "Aggregation through htram"): events go through htram
   in all four modes, with a correctness gate on the Mac and on 4 Stampede3
   nodes, and stage 1 of the sweep. Remaining from the original plan:
   - SSSP parity check on htram `pdes` before merging it into master;
   - stage 2 at 8+ nodes (skx-dev allows at most 4) and PPN 1 vs 2;
   - payload slot size for models with larger messages (Imbalanced PHOLD needs 24 B).
   
   DONE 2026-10-20: deadline flush policy (see "Deadline flush policy"). Next: the controller that sets the window and horizon from the timestamp distribution; then the htram hold (#3) and in-buffer annihilation of anti-messages (#4) from the flush-policy brainstorm; dragonfly port after that.

   The original options for this step:
   - per-destination minimum bucket tracking, so a GVT advance flushes only destinations holding now-current events (htram min-key query);
   - then the histogram controller choosing urgency and cadence.
   
   The original plan's notes for this step:
   - htram `pdes` (built with `-DPDES -DBUCKETS_BY_DEST`):
     - `PdesItem` (event header + 16 B payload, ~64 B);
     - `sendUrgent(item, pe)`;
     - `flushDest` for WsP and PP, so one flush policy runs in all modes;
     - fix the WW `receiveOnPE` leak of `buf`, which also skips `tot_recv_count`;
     - make `receiveOnProc` abort (it drops items in BUCKETS_BY_DEST builds);
     - SSSP parity check before merging to master.
   - Charades branch `htram`:
     - Options: `--aggregation`, `--agg-mode`, `--agg-buffer`, `--agg-urgent=k` (ship events within k buckets of GVT now), `--agg-scope`.
     - Send path: `produce()`, then insert into htram. Receive: rebuild a `RemoteEvent` and call `recv_remote_event`. Anti-messages and GVT control bypass htram.
     - Flush rules:
       - `flushIdle` when `execute()` finds no ready LP or is window-blocked. The scheduler never goes idle in Charm's sense, so `[whenidle]` won't fire.
       - `flushStale` each GVT round.
       - `tflush` in `gvt_begin` before QD for blocking GVT. Otherwise QD can complete with events still buffered.
     - Event holding off with aggregation for now.
     - Gate: every `test.py` config in all four modes, with the committed count unchanged.
   - Sweep:
     - mode × buffer {16, 64, 256, 1024} at remote 0.5, 4 nodes;
     - then the best two modes × urgency × remote {0.1, 0.5, 1} × nodes {2, 4, 8};
     - then PPN 1 vs 2.
     
     Full design and predictions are in the research plan, "Current phase".
2. Window sweep on a model with different lookahead/delay and a
   phase-changing PHOLD (e.g. remote 0 ↔ 0.5 phases), to show the best static
   window moves; then the histogram controller. Include the remote-0 case,
   where w=250 costs 2× at 8 nodes.
3. Event holding: realistic cutoff and bucket size per model (open issue 1);
   the PADS'19 baseline.
4. Gaussian PHOLD at Devastator's scale (100 LPs per core, 15 start events,
   σ 100 → 25,600) and 16+ nodes, `+lci_ndevices 8`, `--comm-stats=1`.
5. ROSS baseline build on Stampede3; check whether Devastator builds.
6. Dragonfly port when needed.
