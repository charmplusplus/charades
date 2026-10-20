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

8. **Traffic's committed count is not deterministic** (found 2026-10-20 while
   adding it to the tests). It commits 14789 events on one process at any PE count, but
   14766–14794 across 4 Stampede3 processes, with or without aggregation;
   sequential (one chare) commits 14718. Likely cause: events with equal
   timestamps are ordered by `(ts, src_lp, event_id)`, `event_id` comes from a
   per-chare counter that rollbacks never rewind (`LPChare::get_next_event_id`),
   and traffic's intersections depend on that order (PHOLD does not).
   Fixes to try: rewind the counter in rollback, or tie-break on a
   deterministic key. Until then traffic is out of `test.py`; its configs are
   in `models/traffic/test_configs/`.

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
