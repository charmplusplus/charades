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

### Gaussian PHOLD σ sweep, results (2026-10-21, idev job 3624866, 4 skx nodes)

**Runs.**
- CSVs are in `$WORK/charades-runs/gauss/`:
  - main sweep: `pp.csv` (3 reps), `off.csv` (2 reps);
  - ε and fine-window pass: `pp_eps.csv`, `off_eps.csv`;
  - low slack, lookahead 10 / mean 200, end time 64,000: `pp_low.csv`, `off_low.csv`, `off_low_eps.csv`;
  - gap fill: `pp_gap.csv`, `pp_low_gap.csv`.
- Summarize with `scripts/stampede3/gauss_summary.py <csvs>`.
- 414 runs. None failed. The only stalls were fixed W 250 at low slack, 6 of 6, stopped at 90 s; normal runs take about 5 s.
- Committed counts are identical across arms for each workload. Spread over reps is 1–5% for most arms; up to 1.19× for W 500 and 1.7× for the hill climb.

**1. Aggregation wins everywhere, and more as locality falls.** Best arm with htram ÷ best arm with direct sends (both M committed events/s, median; higher is better):

| workload | off-node share (% of events) | best direct (M ev/s) | best htram (M ev/s) | htram ÷ direct |
|---|---|---|---|---|
| σ 100, lookahead 100 / mean 1,000 | 3.9 | 5.49 | 14.81 | 2.70 |
| σ 500 | 19.5 | 3.07 | 12.66 | 4.12 |
| σ 1,000 | 38.2 | 2.35 | 11.86 | 5.04 |
| σ 2,000 | 62.3 | 1.91 | 11.37 | 5.95 |
| σ 4,000 | 74.6 | 1.73 | 11.39 | 6.58 |
| uniform remote 1.0 | 75.0 | 1.77 | 11.57 | 6.54 |
| σ 500, lookahead 10 / mean 200 | 19.5 | 3.14 | 10.60 | 3.37 |
| σ 2,000, low slack | 62.3 | 1.85 | 8.39 | 4.54 |
| uniform remote 1.0, low slack | 75.0 | 1.72 | 8.14 | 4.74 |

- With direct sends, throughput falls 3.1× from σ 100 to the all-remote end. With htram it falls only 1.28×, so htram removes most of the cost of communication.
- At low slack, messages carry fewer events (17–28 per message, against 42–54 at high slack), so the gain is smaller.
- The gain at σ 100 is 2.7×, not the predicted ≤ 1.3×. Even at σ 100, 55% of events leave their PE, nearly all to another PE in the same process, and htram aggregates those too (`--agg-scope=0`).

**2. The controller is the only policy that is good in every regime.** Each policy's committed-event rate ÷ the best fixed W in the same workload and transport (medians; higher is better). Each range covers 6 high-slack and 3 low-slack workloads:

| policy | htram, high slack | htram, low slack | htram, worst case | direct, high slack | direct, low slack | direct, worst case |
|---|---|---|---|---|---|---|
| controller ε 0.003 | 0.86–0.92 | 0.97–0.99 | **0.86** | 0.95–1.00 | 0.97–0.98 | **0.95** |
| controller ε 0.01 | 0.75–0.84 | 0.90–0.94 | 0.75 | 0.84–0.99 | 0.99–1.00 | 0.84 |
| controller ε 0.001 | 0.72–0.95 | 0.94–0.98 | 0.72 | – | – | – |
| fixed W 25 | 0.27–0.34 | 0.90–0.98 | 0.27 | – | 0.94–0.97 | – |
| fixed W 50 | 0.47–0.55 | **1.00** | 0.47 | 0.66–0.85 | 0.99–1.00 | 0.66 |
| fixed W 100 | 0.72–0.79 | 0.34–0.40 | 0.34 | 0.81–0.93 | 0.59–0.62 | 0.59 |
| fixed W 250 | **1.00** | stalls (storm) | 0 | 0.99–1.00 | not run (storm expected) | – |
| blocking GVT | 0.61–0.66 | 0.61–0.74 | 0.61 | 0.77–0.93 | 0.85–0.91 | 0.77 |
| hill climb from W 250 (Devastator's rule) | 0.36–0.48 | 0.32–0.38 | 0.32 | 0.73–0.80 | – | 0.73 |

- The best fixed W moves from 250 (lookahead 100 / mean 1,000) to 50 (lookahead 10 / mean 200).
  - Every single fixed W fails in one regime: at best 0.47 of the best fixed W, and W 250 at low slack is a rollback storm.
  - At ε 0.003 the controller reaches 0.86 or better everywhere with htram, and 0.95 or better with direct sends.
- **Blocking GVT is not competitive** once count waves are paced: 0.61–0.74 with htram. Prediction 6 was wrong at high slack; it expected a tie.
- **The hill climb loses everywhere**, at 0.32–0.48 with htram. Above 95% efficiency it doubles W, so it settles near twice the best fixed W: mean W about 500 at high slack and about 100 at low slack, at 84–91% and 68–77% efficiency.

**3. Why the controller trails with htram at high slack: aggregation makes rollbacks relatively expensive.** σ 2,000, run 1, PE time per event (µs = Δexecution time × 64 PEs ÷ Δevents):

| transport | per committed event, W 250 (µs) | per extra rolled-back event, controller ε 0.01 vs W 250 (µs) | same, W 500 vs W 250 (µs) | rollback ÷ committed cost |
|---|---|---|---|---|
| direct | 33 | 166 | 78 | 2.4–5× |
| htram | 5.6 | 118 | 60 | 11–21× |

- A rolled-back event costs about the same absolute time with either transport. Anti-messages bypass htram, so each one is a direct message. What changes is the cost of a committed event, which is 6× cheaper with htram.
- So a fixed ε, a share of *events* rolled back, means different things on each transport. At 1%, rollbacks cost about 4% of throughput with direct sends and about 16% with htram.
- The throughput peak is also narrow: W 200 and 300 already give 0.93–0.98 of W 250.

**4. A rollback floor traps ε 0.001.**
- About 0.1–0.13% of events roll back even at W 50, below the lookahead of 100, where the window bound rules out window stragglers. So the floor comes from something the window doesn't control.
- At σ 1,000, ε 0.001 sat at that floor in 3 of 3 runs:
  - the controller kept shrinking W and α rose to 1.2–3.8 (about 0.01 elsewhere);
  - W locked at about 98, where F(W) = 0 and calibration stops updating;
  - throughput was 0.72 of the best fixed W.

**Predictions checked:**
1. Aggregation gain: wrong at σ 100 (2.7×, not ≤ 1.3×); right by σ 1,000 (5.0×); above the predicted range at the remote end (6.6×, not 3–4×).
2. Direct sends fall 2.9× from σ 100 to 2,000, not 4×, and flatten after: roughly right.
3. Wrong at ε 0.01: the controller reached 0.75–0.84, with W 326–381.
4. Right: W 250 was the best fixed W at every high-slack σ.
5. Right: the hill climb reached 0.37–0.48 at σ ≥ 1,000.
6. Wrong at high slack (blocking 0.61–0.66 against the controller's 0.75–0.92). Right at low slack: the controller is 1.31–1.60× blocking.

### Controller on the GVT's count waves (implementation, 2026-10-21)

- `--ctl-reduction=1` (commit 28281f3; the default stays 0, the separate `Controller` reduction, until measured).
- **What rides on each wave.** `BucketGVT::contribute_counts` adds tuple elements to the count wave:
  - the controller's 6 counters as `sum_ulong_long` deltas (48 B), on every wave;
  - the delay histogram on every `--ctl-hist-waves`-th wave (default 8): whole (385 bins, 3 KB), or with `--ctl-hist-coarse=1` one bin per power of two (49 bins, 392 B). The receiver spreads a coarse bin evenly over its 8 sub-bins, which is what interpolating within the power of two would give.
- **Why every PE agrees.** Each PE contributes exactly once per wave, so its k-th contribution is the same wave everywhere and all PEs agree which waves carry the histogram. `check_counts` passes the sums to the controller before advancing GVT, and each PE decides once per `--ctl-interval` waves.
- **Fixed in passing:** `check_counts` never freed its reduction message, so every wave leaked one on every PE. `toTuple` copies the data out, so the message is now freed at once.
- **Tests:** `ctl_quantile_shared` (decides every wave, full histogram every 8th), `ctl_hill_shared` (hill climb every wave, as Devastator runs it), `agg_ctl_shared_bucket_pp` (htram, ε 0.003, coarse histogram every wave). Mac gates: 588/588 together with the existing `ctl_*` configs; the full matrix 3,052/3,052; `--quick --repeat 20` on the three new configs and `bucket` 3,360/3,360.
- **`ctl_sweep.sh` arms:**
  - `qs[c]<N>:<ε>`: the quantile rule on the waves, histogram every Nth wave, coarse with `c`;
  - `drys[c]<N>:<W>`: the same in a dry run (W fixed);
  - `hills:<W0>`: the hill climb on the waves, deciding every wave;
  - a new `count_waves` column.

### External baselines, Mac feasibility (2026-10-21; details in `~/pdes-baselines/NOTES.md`)

- **ROSS** (ROSS-org/ROSS `dc3a6a0`, 2026-06-23).
  - Builds with no fixes (CMake, Open MPI).
  - Its GVT is the blocking `mpi_allreduce`; 7 o'clock GVT is retired.
  - New model `models/phold-gauss` (patch `~/pdes-baselines/ross-gauss-phold.patch`) follows our PHOLD draw for draw: the same delay semantics (integer timestamps), Gaussian step, contiguous LP blocks and clcg4 seeding.
  - **It commits exactly the same events as Charades** (PHOLD test configs base / gaussian / long / wide: 2,055 / 16,389 / 16,370 / 4,085; plus σ 0 / 100 / 2,000 at both slack levels). This holds across sequential, conservative and optimistic runs on 2 and 4 ranks, so cross-engine runs can be checked by committed count.
  - ROSS's own normal generator is unusable here: it caches a draw that reverse computation doesn't restore.
  - The tuning knobs Devastator swept are `--batch` and `--gvt-interval` (grid not given in the paper); also `--extramem`.
- **Devastator** (cychan-lbnl/devastator `2c32fda`, 2022-11-14, no later branches).
  - **It contains the adaptive window** (`global_status_state::update()` in `src/devastator/pdes.cxx`, as in PADS'24 Sec. 2.1), so the real hill climb can be run.
  - **Its PHOLD can't be compared with ours as it stands:**
    - σ is in ranks, not LPs;
    - the delay is hard-coded (lookahead 1, mean 10,001);
    - runs stop after a wall-clock limit, with no end time;
    - the paper's common ROSS harness isn't public.
    - We need our own `bench/phold-gauss.cxx`.
  - **Build:** its `brutal` tool, Python < 3.14, GCC with C++14. It downloads GASNet-EX, whose configure flags are hard-coded for Perlmutter (`cxi`). Rank, process and worker counts are compile-time constants, so one binary per layout. Each process runs workers plus a master thread that alone drives GASNet.
  - Runs on the Mac in threads mode and on GASNet's smp conduit. With 4 threads it aborts at exit, cause unknown.
- **Next, on Stampede3:**
  - ROSS with `impi/21.11` or `mvapich/3.0`, one rank per core, a batch × GVT-interval sweep;
  - Devastator with a GASNet conduit that works on Omni-Path (try ofi psm2, ofi `verbs;ofi_rxm`, ibv, udp), and our Gaussian PHOLD for it.

### Controller on the GVT's count waves, results (2026-10-21, idev job 3625507, 4 skx nodes)

**Setup.**
- 4 nodes × 2 processes × 8 PEs, Gaussian σ 2,000 and uniform remote 1.0, htram PP 64 with deadline margin 8.
- Two slack levels: lookahead 100 / mean 1,000 with end time 256,000, and lookahead 10 / mean 200 with end time 64,000.
- 3–4 reps. CSVs in `$WORK/charades-runs/shared/`.
- Shared arms decide every wave (`--ctl-interval=1`).
- No run failed or stalled.

**A. Cost**, with the controller running and the window held fixed (`--ctl-dry`). Throughput ÷ the same fixed W with no controller (median; higher is better):

| controller data path | data per PE per wave (B) | high slack, W 250 | low slack, W 50 |
|---|---|---|---|
| separate reduction, every 8 GVT updates | 3,128 every 8th GVT update | 0.961 | 0.984 |
| on waves, full histogram every 8th wave | 48 + 3,080 every 8th | 0.968 | 0.999 |
| on waves, coarse histogram every 8th wave | 48 + 392 every 8th | 0.976 | 0.993 |
| on waves, full histogram every wave | 3,128 | 0.940 | 0.963 |
| on waves, coarse histogram every wave | 440 | 0.957 | 0.992 |

- Run-to-run spread is 2–4%, so the cheaper variants are within noise of each other and of the separate reduction.
- Only the full histogram on every wave costs clearly more: it slows waves by 6.4% at high slack.
- Throughput follows waves per second almost exactly (rate ratio ≈ wave-rate ratio in every row): **the count waves are the pacing resource**, and anything that slows them slows the run.
- Predictions:
  - "≤ 1% with counters every wave and the histogram every 8th" held at low slack (0.1–0.7%), but not at high slack (2.4–3.2%, within noise of the separate reduction's 3.9%).
  - "Full histogram every wave slows waves ≥ 5%" held at high slack (6.4%), but not at low (3.9%).

**B. Live control at ε 0.003.** Throughput ÷ the best fixed W (W 250 at high slack, W 50 at low; median; higher is better):

| controller data path | high slack, σ 2,000 | high slack, uniform | low slack, σ 2,000 | low slack, uniform |
|---|---|---|---|---|
| separate reduction | 0.917 | 0.894 | 0.970 | 0.990 |
| on waves, full histogram every 8th | 0.906 | 0.894 | 0.985 | 0.987 |
| on waves, coarse histogram every 8th | 0.897 | 0.908 | 0.974 | 0.973 |
| on waves, coarse histogram every wave | 0.797 | 0.760 | 0.836 | 0.873 |
| on waves, full histogram every wave | 0.762 | 0.747 | 0.816 | 0.830 |

- With the histogram on every 8th wave, the shared reduction controls exactly as well as the separate one, and the coarse histogram is enough.
- **A histogram on every wave hurts control, not cost.** Efficiency falls from 99.65% to about 98%. The rule folds new delays in, and recalibrates α, once 256 have arrived. A wave carries thousands, so it folds every wave, the decayed histogram remembers about two waves, and W jitters. Feeding per-wave histograms would need a fold sized in samples per wave, not a fixed 256.

**C. The hill climb deciding more often** (÷ best fixed W, median; higher is better):

| hill climb (from W 250 unless noted) | high slack, σ 2,000 | high slack, uniform | low slack, σ 2,000 | low slack, uniform |
|---|---|---|---|---|
| every 8 GVT updates, separate reduction | 0.45 | 0.48 | 0.33 | 0.38 |
| every GVT update, separate reduction | 0.12 | 0.12 | 0.24 | 0.22 |
| every count wave (Devastator's design) | 0.07 | 0.06 | 0.07 | 0.07 |
| every count wave, from W 50 | 0.07 | 0.07 | 0.07 | 0.07 |

- The prediction was wrong: deciding every wave makes the hill climb far worse, 25–31% efficiency with a mean W of about 950 at high slack.
- The rule doubles W whenever its 16-round efficiency average is above 95%, and rollbacks show up some rounds after W grows. With a round every 0.1–0.6 ms, W doubles several times before the average reacts.
- The rule's behaviour therefore depends on GVT round frequency. Devastator's asynchronous GVT is slower, so its rounds are longer. A fair comparison needs Devastator's own code, which builds.
- The starting window makes no difference.

**Conclusion for step 1.**
- The controller can share the GVT's reduction at no loss, with counters every wave and a coarse histogram every 8th (440 B per PE at most). The shared reduction did not prove cheaper than the separate one.
- The user made `--ctl-reduction=1` (coarse histogram every 8th wave) the default the same day.

### ROSS on Stampede3, first runs (same job)

- **Build.** ROSS `dc3a6a0` + `phold-gauss`, built with `mvapich/3.0` (ch4:ofi) under `gcc/13.2.0`: `$WORK/ROSS/build/models/phold-gauss/phold-gauss`.
  - Intel MPI needs `intel/24.0`, which swaps out gcc.
  - Don't pipe `module load` (it then runs in a subshell and loads nothing).
  - Launch with `srun --mpi=pmi2` after importing idev's `SLURM_*` variables (`scripts/stampede3/env.sh` does this, but also sets libfabric variables meant for LCI).
- **Committed counts equal Charades' everywhere tried:**
  - 7,861,362 (8,192 LPs, σ 2,000, lookahead 100 / mean 1,000, end time 64,000) at 1 to 64 ranks, sequential, conservative and optimistic;
  - 8,106,901 and 40,655,555 at 8,448 LPs (high and low slack), conservative ROSS at 192 ranks and Charades at 192 PEs.
- **Optimistic ROSS aborts across nodes**: `avl_tree.c:276: We never look for non-existent events!`, meaning an anti-message found no event.
  - It fails with libfabric providers psm2 (the default) and tcp at 2 × 32 and 4 × 64 ranks, and with every provider at 4 × 192.
  - It works within one node, and with `FI_PROVIDER="verbs;ofi_rxm"` at 2 × 32 and 4 × 64.
  - Not yet diagnosed: ROSS may rely on an MPI message order that MPI doesn't guarantee across tags. Try Intel MPI, and read `network-mpi.c`.

**Throughput** (M committed events/s, one or two runs each; higher is better; runs are short, about 0.7–5 s of execution):

| engine and layout | high slack, σ 2,000 | low slack, σ 2,000 |
|---|---|---|
| ROSS conservative, psm2, 4 × 16 ranks | 5.54, 8.47 | 4.73 |
| ROSS conservative, verbs, 4 × 16 ranks | 4.38 | – |
| ROSS optimistic, verbs, 4 × 16 ranks | 3.94, 4.39 | – |
| ROSS conservative, psm2, 4 × 48 ranks (8,448 LPs) | 10.40 | 7.31 |
| ROSS sequential, 1 core | 0.80 | – |
| Charades, htram, best fixed W, 4 × 16 PEs (8,192 LPs) | 11.4 | 8.4–8.5 |
| Charades, htram, best fixed W, 4 × 48 PEs (8,448 LPs) | 11.15, 11.39 | 8.46, 9.04 |
| Charades, htram, controller ε 0.003, 4 × 48 PEs | 7.49, 7.50 | 7.89, 8.56 |
| Charades, direct sends, W 250, 4 × 48 PEs | 2.89, 2.99 | – |

**What this means.**
- **The biggest unknown is now partly known.** At this lookahead (100, a tenth of the mean delay), *conservative* ROSS is close to Charades with htram: 10.4 against 11.3 M ev/s on full nodes, and 7.3 against 8.7 at low slack.
  - Charades' lead comes from aggregation alone; with direct sends it is 3–4× slower than ROSS.
  - The paper's claim has to be made where conservative execution suffers: small lookahead relative to the delays.
- **Charades did not get faster from 64 to 192 PEs** on these problem sizes. Runs execute for only about 0.7 s (high slack), so step 3 needs Devastator's sizes (100 LPs per core) and longer end times before scaling is judged.
- **The controller is weak at full nodes and high slack** (0.66 of W 250) against 0.90 at 16 PEs per node. Step 2 has to look at this.
- ROSS's own run-to-run spread is large (5.54 vs 8.47), so it needs repeats, and its batch and GVT-interval settings are untuned.

### Controller step 2: cost-aware target and floor guard (design, 2026-10-21; written before the runs)

**Changes.**
- **`--ctl-cost=1` (default): ε is the share of PE time lost to rollbacks.** The rule allows a rolled-back share of ε / κ, where κ = (PE time per rolled-back event) ÷ (PE time per executed event), measured online:
  - time inside `rollback_me` (reverse handlers, cancellations, anti-message sends), per rolled-back event;
  - plus the mean forward time of an event, timed on every 16th forward;
  - over elapsed PE time per executed event, which includes time blocked by the window: the more the window holds PEs back, the larger the waste budget.
  - Both ride in the controller's counters (3 more fields), decayed like the others.
- **ε defaults:** 0.01 as a time share; 0.003 with `--ctl-cost=0`, the best event share tried in the σ sweep. The old default was 0.05.
- **Floor guard.** W ≥ F⁻¹(0.01), and α is not calibrated while F(W) < 0.01. Below the 1st percentile of delays the window can't cause stragglers, so the waste seen there is a floor. Calibrating against it trapped ε 0.001 at W ≈ 98.
- Tests: `ctl_quantile_events` (event share); the existing `ctl_*` configs now use the time share.
- Sweep arms: `q:` is now the time share; `qev:` the event share.

**Predictions** (4 nodes × 2 × 8 PEs; σ-sweep workloads; ratios ÷ best fixed W, higher is better):
1. **κ:** about 1.5–2.5 with direct sends and about 4–7 with htram at high slack. Lower at low slack, where PEs spend more time blocked.
2. **Time share 0.01 reaches 0.95 or better of the best fixed W in all 9 workloads × 2 transports.**
   - Rolled-back share about 0.15% with htram at high slack (the optimum was about 0.1%) and about 0.5% with direct sends.
   - The event share 0.003 stays at 0.89–0.92 with htram at high slack.
3. **Full nodes** (4 × 2 × 24 PEs): the 0.66 was mostly warm-up. A run 4× longer brings the controller to 0.9 or better. If it doesn't, `--ctl-log` shows whether W or κ is off.
4. **ε sensitivity:** time shares 0.005 and 0.02 stay within 5% of 0.01 on most workloads. A flat optimum is what makes one default defensible.

### Controller step 2, results (2026-10-21, idev job 3626068, 4 skx nodes)

**Setup.**
- CSVs in `$WORK/charades-runs/step2/` and `$WORK/charades-runs/compare_long/`.
- 4 nodes × 2 × 8 PEs unless noted; htram PP 64, margin 8.
- Ratios are ÷ the best fixed W (W 250 at high slack, W 50 at low), median; higher is better.

**1. The time-share target failed.**
- **κ was nowhere near the prediction**: 0.26–1.02 with htram and 0.23–0.57 with direct sends (predicted 4–7 and 1.5–2.5). The measured direct cost of a rolled-back event is only about 3 µs: its reverse handler, anti-message send and forward work.
- **The real cost is indirect.** A rolled-back event costs 60–120 µs of throughput (σ-sweep estimate), so over 95% of a rollback's cost is not CPU work: rollbacks hold GVT back, and PEs wait at the window edge. A target built on timed rollback work can't see that.
- **Results**, time share 0.01 against event share 0.003 (÷ best fixed W, higher is better):

| workloads | time share 0.01 | event share 0.003 |
|---|---|---|
| htram, high slack (6) | 0.64–0.88 | 0.87–0.93 |
| htram, low slack (3) | 0.74–0.90 | 0.97–0.99 |
| direct, high slack (6) | 0.78–0.97 | 0.92–1.01 |
| direct, low slack (3) | 0.97–0.99 | 0.97–1.01 |
| htram, full nodes, high slack | 0.2–0.4 (W ran away to 1,100–3,300; 38–62% efficiency) | 0.57 (W 85) |

**2. The floor guard works at 16 PEs per node.**
- Event share 0.001 no longer traps (W 251–277 at high slack, 36 at low).
- With htram: 0.92–1.02 at high slack (0.92 is a single run at σ 100), and 0.95–0.98 at low slack.
- In the longer runs (end time 512,000 / 128,000): 0.95 at high slack and 0.96–0.97 at low.
- So ε 0.001 beats 0.003 with htram at high slack (0.87–0.93) and is slightly behind at low slack (0.97–0.99). It is untested with direct sends.

**3. Full nodes (4 × 2 × 24 PEs) break the event-share target.**
- About 0.45% of events roll back whether W is 109 or 250, so the rolled-back share barely depends on W. Most waste there is not window-caused.
- Event share 0.003 pins W to the floor guard (0.56–0.67). Event share 0.01 overshoots to W 550–580 (0.82–0.85).
- **The coarse histogram puts the floor below the lookahead**: W 84 against 109 with the full histogram. Delays start at 100, but the coarse bin [64, 128) spreads mass down to 64. The full histogram should be the default.

**4. A run that stalled:** a full-node fixed W 50 run took 27.7 s against 4.9 s, with the same wave count. Probably the system; noted as an outlier.

**Predictions checked:**
1. κ: wrong (0.2–1.0 against 4–7).
2. Time share 0.01 at 0.95 or better everywhere: wrong (0.64–0.99).
3. Full-node 0.66 was warm-up: wrong. A 4× longer run is no better; the cause is the rollback floor (point 3).
4. ε sensitivity: not run (part 3 was dropped once the time share had failed).

**Defaults reverted (same day):** `--ctl-cost=0` (event share), ε 0.003 (tested on both transports), full histogram (`--ctl-hist-coarse=0`). The floor guard stays.

### Three engines on Gaussian PHOLD, 4 nodes (same job; first real comparison)

**ROSS optimistic multi-node abort: diagnosed and fixed** (`~/pdes-baselines/ross-debug/REPORT.md`).
- ROSS processes `MPI_Testsome` completions in index order and assumes an anti-message never completes before its event. MPI orders matching, not completion.
- On Stampede3 the stock control aborts at 2 × 16 (2 of 2). The patched ROSS passes, and it counted 6–217 anti-messages that arrived before their events: **MVAPICH really does reorder completions.**
- Stock ROSS with `--read-buffer=1` also passes, and is about 2× faster than the patch: 7.7 against 3.8 M ev/s at 2 × 16, 36.2 against 18.3 at 4 × 48.
- All counts exact (7,861,362 and 8,106,901).

**Devastator** (`~/pdes-baselines/` Part C; `$WORK/devastator`).
- Built for every GASNet conduit; ofi-psm2 passes the exact-count check (29,338 with Charades' RNG) and is used below.
- Its Gaussian PHOLD with Devastator's own RNG commits within 0.1% of Charades' count (62,931,069 vs 62,941,466).
- Its adaptive window (the hill climb) is on.

**Throughput**, Gaussian σ 2,000, 4 nodes, runs of 2–10 s; M committed events/s, higher is better:

| engine and layout | high slack (lookahead 100 / mean 1,000, end 512,000) | low slack (lookahead 10 / mean 200, end 128,000) |
|---|---|---|
| Charades + htram, best fixed W, 64 PEs (4 × 2 × 8) | 11.40, 11.51 | 8.60, 8.64 |
| Charades + htram, controller (event share 0.001), 64 PEs | 10.88, 10.95 | 8.22, 8.39 |
| Charades + htram, W 250, 192 PEs (4 × 2 × 24) | 10.09 | – |
| ROSS optimistic `--read-buffer=1`, 64 ranks | 12.24, 12.27 | 12.02, 12.03 |
| ROSS optimistic `--read-buffer=1`, 192 ranks | 26.83 | – |
| Devastator, adaptive window, 64 ranks (8 processes × 8 workers) | 36.94, 37.37 | 34.55, 34.63 |
| Devastator, adaptive window, 184 ranks (8 × 23) | 9.60 (38% efficiency) | – |

**Weak scaling on full nodes** (about 128 LPs per core, high slack, end time 128,000; Charades and ROSS commit the same 47,176,098 events; M committed events/s and K committed events/s per core, higher is better):

| engine and layout | M ev/s | K ev/s per core |
|---|---|---|
| Charades + htram W 250, 64 PEs (8 × 8), 8,192 LPs | 11.3 | 177 |
| Charades + htram W 250, 128 PEs (8 × 16), 16,384 LPs | 18.0–18.5 | 143 |
| Charades + htram W 250, 192 PEs (8 × 24), 24,576 LPs | 22.0–23.2 | 118 |
| Charades + htram W 250, 192 PEs (16 × 12) | 19.5–19.6 | 101 |
| Charades + htram W 250, 192 PEs (32 × 6) | 10.1–10.3 | 53 |
| Charades, direct sends, 64 / 192 PEs | 1.89 / 5.13 | 30 / 27 |
| ROSS optimistic `--read-buffer=1`, 192 ranks, 24,576 LPs | 32.9–33.4 | 172 |
| Devastator, fixed W 250, 184 ranks, 23,552 LPs | 80.5 | 437 |
| Devastator, adaptive window, 184 ranks | 0.37 (2.8% efficiency, 123 s) | 2 |

- Charades does scale when the problem grows with it. The earlier "no gain from 64 to 192 PEs" came from spreading 8,448 LPs over 192 PEs (44 per PE). Per-PE rate still falls by a third from 64 to 192 PEs.
- Fewer, larger processes are better: 8 × 24 beats 16 × 12 beats 32 × 6.
- On full nodes, ROSS is 1.46× Charades, and **Devastator with a fixed window is 3.6× Charades**. Devastator's own adaptive window collapses into a rollback storm there, its PADS'24 weakness reproduced, so a fixed W 250 is what makes it fast.

**What this means.**
- **At 64 cores, Devastator is 3.2× (high slack) to 4.0× (low slack) faster than Charades.** Its window runs at 78–80% efficiency and still wins.
- **ROSS is 1.07–1.4× faster** than Charades at 64 cores, and **2.7× faster on full nodes**, where Charades doesn't scale (11.4 at 64 PEs, 10.1 at 192).
- **Devastator's hill-climbed window collapses on full nodes** (38% efficiency, 9.6 M ev/s). That fits its own paper's remote-heavy weakness, but we have one run.
- **The paper's premise needs rethinking.** Charades' per-event cost is 3–4× Devastator's at equal cores, so "Charades with htram and the controller beats Devastator in its weak regime" holds at best on full nodes, against Devastator's collapsing window. Even there ROSS is 2.7× faster than Charades.
- **Devastator's weakness is real, but it is its window, not its engine**: with a fixed window it is the fastest engine by 2.4–3.6×. So the controller's value is clearest *as a window for Devastator-like engines*. Our quantile rule kept Charades at 0.95–0.97 of its best fixed window where Devastator's hill climb fell to 2.8% efficiency. (Correction, same day: that 0.95–0.97 is at 64 PEs, not on the full-node problem where Devastator collapsed; "Three engines: the gaps filled" below measures the controller there.)
- **Before choosing the framing**, find where Charades loses per event against Devastator (about 5.6 µs of core time per committed event at 64 cores, against 1.7–1.9 µs: 64 workers plus 8 master threads): the scheduler, Charm++/Reconverse entry methods, or htram.

### Three engines: the gaps filled (2026-10-21, idev job 3626388, 4 skx nodes)

Why: the comparison above had no controller run on the weak-scaled full-node problem, only one fixed W for Charades there, and no fixed-W runs for Devastator at 64 cores. Script `$WORK/charades-runs/gap_fill.sh` and `gap_fill2.sh`; CSVs and `.out` files in `$WORK/charades-runs/gapfill/`. Charades at bcee55f (defaults: event share, full histogram), htram PP 64, margin 8. Gaussian σ 2,000, 4 nodes. Two runs per point unless noted.

**Predictions (written before the runs):** rollbacks are rare at 128 LPs per PE (0.04% at W 250), so the controller widens W; the best fixed W is 500–1,000; the controller reaches ≥ 0.9; Devastator's fixed W at 64 cores is within 10% of its adaptive window.

**Charades, full nodes weak-scaled** (4 × 2 × 24 PEs, 24,576 LPs, high slack, end time 512,000, 188,809,635 committed events in every run; M committed events/s, median; ÷ best fixed W; higher is better):

| arm | M ev/s | ÷ best fixed W | efficiency (%) | mean W (sim. time) |
|---|---|---|---|---|
| W 100 | 17.6 | 0.75 | 99.95 | 100 |
| W 175 | 22.0 | 0.94 | 99.96 | 175 |
| **W 250** | **23.5** | 1.00 | 99.97 | 250 |
| W 350 | 22.2 | 0.94 | 99.7 | 350 |
| W 500 | 15.6 | 0.67 | 96.4 | 500 |
| W 1,000 | 2.97 | 0.13 | 44.8 | 1,000 |
| controller, event share 0.003 | 22.5 | 0.96 | 99.7 | 342–352 |
| controller, event share 0.001 | 21.9 | 0.93 | 99.9 | 293–303 |
| hill climb (Devastator's rule, in Charades) | 9.0 | 0.38 | 82.6 | 660–664 |

At end time 128,000 (about 2 s of execution, which is short for the controller) the controller is 0.86 (0.003) and 0.89 (0.001) of W 250 (23.0). One W 100 run there took 27 s instead of 6.5 s (first run of the job, during the `$WORK` I/O errors); the median ignores it.

**Devastator, fixed windows** (ofi-psm2; M committed events/s, median; ÷ its own best fixed W; higher is better):

| layout and workload | adaptive (from job 3626068) | W sweep: M ev/s (efficiency %) | best fixed | adaptive ÷ best |
|---|---|---|---|---|
| 64 ranks (8 × 8), 8,192 LPs, high slack, end 512,000 | 37.1 (80%) | 250: 40.9 (99.99); 500: 47.0 (99.7); 1,000: 54.0 (98.8); 2,000: 53.8 (96.2); 4,000: 44.9 (88.2); 8,000: 38.3 (80.8) | 54.0 (W 1,000–2,000) | 0.69 |
| 64 ranks, low slack (lookahead 10, mean 200), end 128,000 | 34.6 (78%) | 25: 33.1; 50: 39.6; 100: 46.1 (99.2); 200: 52.5 (97.1); 400: 51.3 (92.7); 800: 41.5 (82.3) | 52.5 (W 200) | 0.66 |
| 184 ranks (8 × 23), 23,552 LPs, high slack, end 512,000 | 0.37 (2.8%; end 128,000) | 100: 57.5 (100); 250: 77.2 (99.99); 500: 94.6 (99.7); 1,000: 96.9 (96.4); 2,000: 74.4 (81.5); 4,000: 12.5 (43); 8,000: storm (one stall at the 300 s cap, one `std::bad_alloc`) | 96.9 (W 500–1,000) | 0.004 |

**ROSS, full nodes weak-scaled, end 512,000:** 27.1 and 26.9 M ev/s (99.2% efficiency), lower than the 33.1 at end 128,000. Not investigated; the longer run's 2.4× more events are handled at a lower rate.

**Best fixed configuration of each engine** (M committed events/s; higher is better):

| | 64 cores, high slack | 64 cores, low slack | full nodes, weak-scaled |
|---|---|---|---|
| Charades + htram, best fixed W | 11.4 (W 250) | 8.6 (W 50) | 23.5 (W 250) |
| Charades + htram, controller (event share) | 10.9 (0.001) | 8.3 (0.001) | 22.5 (0.003) |
| ROSS optimistic | 12.3 | 12.0 | 27.0 (33.1 at end 128,000) |
| Devastator, its adaptive window | 37.1 | 34.6 | 0.37 |
| Devastator, best fixed W | 54.0 | 52.5 | 96.9 |
| Devastator best ÷ Charades best | 4.7× | 6.1× | 4.1× |

**Predictions checked.**
1. Controller widens W: right (mean W 342–352 against 250), but too far: W 350 fixed is 0.94.
2. Best fixed W 500–1,000: **wrong**. It is 250; W 500 loses a third of the throughput while still committing 96.4% of what it executes.
3. Controller ≥ 0.9: right (0.93–0.96 on the long runs).
4. Devastator fixed ≈ adaptive at 64 cores: **wrong**. Its hill climb leaves 1.45–1.5× on the table at 64 cores too, not only on full nodes.

**What this means.**
- **The controller holds on the full-node weak-scaled problem**: 0.93–0.96 of Charades' best fixed W, against 0.38 for the hill climb in the same engine. The earlier full-node failure (0.56–0.85) was the 44-LP-per-PE problem, where a rollback floor of 0.45% hides the window's effect.
- **Devastator's window is weak everywhere, not only on full nodes**: 0.66–0.69 of its best fixed W at 64 cores, 0.004 on full nodes. That strengthens framing (a): a better window is worth 1.5× in the fastest engine at 64 cores and two orders of magnitude on full nodes.
- **The two engines want very different efficiency targets.** Devastator's best W runs at 96–99% efficiency (1–4% of events rolled back); Charades' at 99.97% (0.03%), and Charades at 96.4% efficiency loses a third of its throughput. A rolled-back event costs Charades far more (about 110 µs of PE time between W 250 and W 500 here, against about 8 µs per committed event), as in step 2: its rollbacks hold GVT back. So an event-share ε does not transfer between engines: Devastator would need ε of about 0.01–0.04 against Charades' 0.003. Porting the controller to Devastator (framing a) needs either a per-engine ε or a target that measures the throughput cost of rollbacks directly; the time-share target (step 2) did not.
- **The gap to Devastator widens with fair tuning**: 4.1–6.1× with each engine at its best fixed W, against 3.2–4.0× before.

### Production runtime build (2026-10-21, batch job 3626643, 4 skx nodes)

**Finding.** Every Stampede3 number above used `$WORK/charm-pads-qd`, built without `--with-production`: `CMAKE_BUILD_TYPE=Debug`, so Reconverse, ck and LCI compiled `-g` with no `-O` (-O0), `CMK_ERROR_CHECKING 1`, `CMK_TRACE_ENABLED 1`, charmc `BUILDOPTS=" -g"`. Devastator is `-O3 -flto -DNDEBUG`. The Mac build was production all along.

**Trees** (same sources: recharm 9d6a55780, Reconverse ff33b56, LCI ca88ce2c, Charades bcee55f):
- `charades-qd` on `charm-pads-qd`: the Debug runtime (all earlier numbers).
- `charades-prodrt` on `charm-pads-prod` (`--with-production`: Release, `-O3 -DNDEBUG` in Reconverse, ck and LCI; error checking and tracing off): Charades flags unchanged (`-O3`, asserts on, htram `PDES_TIMED`).
- `charades-prod`: as prodrt, plus Charades and htram `-DNDEBUG` and no `PDES_TIMED`.
- Script and CSVs: `$WORK/charades-runs/prod/` (`prod.slurm`). Two reps, interleaved across trees; htram PP 64, margin 8; Gaussian σ 2,000; 128 LPs per PE.
- Two build lessons: a copied `config.mk` must also get its own `CHARADES_SRC` (otherwise it builds into the other tree's `src/build`), and a clean `make -j` of `src/` races on generated `.decl.h` files (build serially).

**Results** (M committed events/s, median of 2; higher is better):

| point | Debug runtime | production runtime | production + Charades NDEBUG, no PDES_TIMED | production ÷ Debug |
|---|---|---|---|---|
| 64 PEs, high slack (end 512,000), best fixed W 250 | 11.41 | 21.03 | 20.41 | 1.79–1.84 |
| 64 PEs, low slack (end 128,000), best fixed W 50 | 8.56 | 14.06 | 14.27 | 1.64–1.67 |
| full nodes weak-scaled (24,576 LPs, end 512,000), best fixed W 250 | 23.23 | 34.42 | 34.79 | 1.48–1.50 |
| 64 PEs, direct sends, W 250 (end 128,000) | 2.07 | 3.26 | 3.22 | 1.56–1.57 |
| full nodes, direct sends, W 250 (end 128,000) | 4.91 | 5.80 | 5.56 | 1.13–1.18 |

Controller (event share 0.003) ÷ best fixed W, production + NDEBUG: 0.93 (64 high), 1.00 (64 low), 0.92 (full); Debug: 0.95, 0.98, 0.89. The best fixed W is unchanged by the build (250 / 50 / 250).

Devastator anchors in the same job (fixed W 1,000): 54.2 M ev/s at 64 ranks (two runs) and 103.8 at 184 ranks; one 184-rank run took 25.8 s at 97% efficiency (7.0 M ev/s), a stall not seen before or since, excluded.

**Gap to Devastator, each engine at its best fixed W** (Devastator ÷ Charades, lower is better for Charades): 64 cores high slack 54.2 / 20.4–21.0 = **2.6×** (was 4.7×); low slack 52.5 (job 3626388) / 14.1–14.3 = **3.7×** (was 6.1×); full nodes 96.9–103.8 / 34.4–34.8 = **2.8–3.0×** (was 4.1×). Core time per committed event at 64 cores high slack: about 3.1 µs for Charades (64 worker cores) against 1.3 µs for Devastator (64 workers plus 8 service threads).

**What this means.**
- The runtime build was worth 1.5–1.8× with htram; Charades-side asserts and `PDES_TIMED` are within run-to-run noise. All Stampede3 numbers from before this job understate Charades by that much; ratios within one build (htram ÷ direct, controller ÷ best fixed W) are about unchanged.
- The gain is smallest with direct sends on full nodes (1.13–1.18×), where the cost is per message in the network path, not in the runtime's CPU code.
- Remaining gap 2.6–3.7×. Next, on the production build: pinning, a dedicated progress thread or core per process, `+lci_ndevices`, LCI packet size; then profile what remains.

### Runtime settings on the production build (2026-10-21, idev job 3626832, 4 skx nodes)

Setup: `charades-prod` (production runtime, 8bec616), Gaussian σ 2,000, high slack, end 512,000, htram PP 64, margin 8, W 250, 128 LPs per PE. Scripts `$WORK/charades-runs/rt_sweep{,2,3}.sh`; CSVs in `rtsweep/` and `rtsweep2/`. Node: 2 sockets × 24 cores, no SMT; socket 0 holds the even cores, socket 1 the odd ones. srun's default binding already confines each of 2 tasks per node to its socket.

**Fix needed first (8bec616):** `+setcpuaffinity`, `+pemap` and `+showcpuaffinity` aborted every run with "Argument parse error". Charm++ consumes those flags from a per-PE copy of argv, so they survived in `main`'s argv, which Charades parsed. Charades now parses `CkGetArgv()`. `+pemap` is indexed by global PE modulo the list length, in OS core indices, so one node's list repeats on every node.

**Full nodes, one factor at a time** (M committed events/s, median of 2–3 runs; higher is better):

| configuration | M ev/s | ÷ old 2 × 24 layout |
|---|---|---|
| 2 × 23 PEs, `+pemap 2-46:2,3-47:2` (cores 0 and 1 free), `+lci_ndevices 4` | 45.1–46.2 | 1.32–1.35 |
| 2 × 23, pinned, `+lci_ndevices 8` (base) | 43.2–43.9 | 1.26–1.28 |
| 2 × 23, not pinned (one free core per socket) | 43.7 | 1.28 |
| 2 × 22, pinned (two free cores), ndev 4 / 8 | 44.2 / 43.3 | 1.29 / 1.26 |
| base with LCI packet size 16 K / 32 K | 44.3 / 43.1 | 1.29 / 1.26 |
| base with `+backend_poll_freq` 16 / 256 | 43.6 / 43.2 | 1.27 / 1.26 |
| base with `+backend_poll_thread 2` | 44.1 | 1.29 |
| base with `+lci_ndevices` 2 / 16 / 23 / 1 | 42.2 / 42.5 / 40.7 / 33.2 | 1.23 / 1.24 / 1.19 / 0.97 |
| 4 × 11, pinned | 36.7 | 1.07 |
| 2 × 24, not pinned (every earlier full-node run) | 34.2 | 1.00 |
| 1 × 46, pinned | 33.5 | 0.98 |
| base with `+backend_poll_thread` 4 or 23 | hangs (180 s cap, 2 of 2) | – |

64 PEs (2 × 8 per node): 21.1–21.2 pinned or not, with ndev 4 or 8; nothing here moves it.

**Thread census** (2 × 23 pinned, mid-run): 24 threads per process, the 23 PE threads at 93–98% CPU and one `async` thread at 0%. So the freed core is not feeding a hidden helper thread; it most likely absorbs OS and daemon interruptions that otherwise land on a PE, and a stalled PE stalls everyone through GVT.

**The controller on the best layout** (same run order, 3 reps each; ÷ W 250 at 44.8, higher is better): W 300 41.8 (0.93), event share 0.001 41.3 (0.92, mean W 278), event share 0.003 39.1 (0.87, mean W 322–348). Earlier on the Debug runtime the controller was 0.93–0.96: on the faster runtime throughput falls off more steeply above W 250 (W 350 0.91, W 500 0.59), so ε 0.003 now sets W too wide.

**Devastator in the same allocation** (184 ranks, 23,552 LPs, fixed W 1,000): 96.7 and 104.4 M ev/s.

**Where the gap stands** (Devastator ÷ Charades, each at its best configuration; lower is better for Charades):
- Full nodes: about 100 / 45–46 = **2.2×** (Debug runtime 4.1×, production 2.8–3.0×). Charades and Devastator now run the same 23,552 LPs on 23 compute cores per socket.
- 64 cores, high slack: 54.2 / 21.1 = 2.6× (unchanged by runtime settings).
- Steps so far on full nodes: 23.2 (Debug) → 34.4 (production) → 43.9 (one free core per process) → 45–46 (`+lci_ndevices 4`).

**Next.** Profile what remains (2.2–2.6×, about 2.3× in core time per committed event): the scheduler loop, entry-method and message overheads, and htram; and check whether ε should fall to 0.001 by default now that throughput is more sensitive to W. The `+backend_poll_thread` hang is a Reconverse issue to report (threads that don't poll seem never to get their messages progressed).

### Profile: where Charades spends its time against Devastator (2026-10-21, idev job 3626915)

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

### Per-event fast paths (2026-10-21, idev job 3627053, 4 skx nodes)

Three changes from the profile's ranked list (charades 4bb324b, htram 50acab7 on `pdes`), each behind a switch. **All three are the default since the same day** (user decision; the inbox turns itself off under `--sched-park`, other GVTs and the conservative scheduler); test configs `bucket_avl` and `agg_noinbox_bucket_pp` keep the old paths covered. Not yet re-run with the new defaults:
- `--agg-inbox=1` (htram `setInboxDelivery` / `drainInbox`): a PP/WPs node receive puts each PE's share of a node message in that PE's inbox (a mutex-protected vector in the `HTramRecv` node group) instead of sending it a `receivePerPE` message; the optimistic scheduler drains it at the start of every iteration, and the receiving PE's own share is delivered in place. Only with the bucketed GVT (which counts each event when its chare receives it, so an event in an inbox is in transit) and the optimistic scheduler; refused with `--sched-park`. QD-based GVTs would not see inbox items.
- `--event-index=1`: received events indexed for cancellation by an open-addressing hash per chare (`collections/event_hash.h`; linear probing, tombstones, key (ts, event_id, src_lp)) instead of the AVL tree. Same insert-or-annihilate contract.
- `--msg-pool=1`: event messages (`RemoteEvent`) recycled through a per-PE pool (`remote_event_new` / `remote_event_delete` in event.C) on the hot paths: model sends, htram delivery, fossil frees, `agg_send`. Capacity is read from the envelope; reused messages are marked unused so they can be sent again.

Tests (Mac): change tier on the new configs 60/60; inbox configs repeated 10× on 2×2, 1×4, 2×4: 360/360; existing aggregation configs 84/84; engine tier 484/484. Committed counts identical in every Stampede3 run below.

**Throughput** (production runtime, 2 × 23 PEs per node pinned, `+lci_ndevices 4`, Gaussian σ 2,000; M committed events/s, median of 3; higher is better):

| configuration | full nodes, W 250 | ÷ base | 64 PEs high slack, W 250 | 64 PEs low slack, W 50 |
|---|---|---|---|---|
| base (all off) | 43.7 | 1.00 | 20.7 | 14.2 |
| hash index only | 48.7 | 1.11 | | |
| message pool only | 48.9 | 1.12 | | |
| inbox only | 45.2 | 1.03 | | |
| all three | **56.0** | **1.28** | **27.3** (1.32×) | **17.6** (1.24×) |

With all three on full nodes (2 runs each; ÷ W 250 at 56.9): W 175 0.93, W 350 0.85; controller ε 0.003 51.7 (0.91, mean W 309), ε 0.001 39.7 (0.70, pinned at W 110 near the floor). So ε 0.003 stays the default.

**Gap to Devastator** (each at its best fixed W; Devastator ÷ Charades, lower is better for Charades): full nodes ~100 / 56 = **1.8×** (was 2.2×); 64 cores high slack 54.2 / 27.3 = **2.0×** (was 2.6×); low slack 52.5 / 17.6 = **3.0×** (was 3.7×). A longer full-node run (end 2,048,000) reached 61.0 M ev/s.

**Profile with all three** (one process, DWARF stacks): about 8,300 cycles and 9,200 instructions per committed event (was 11,100 / 12,100; Devastator ~5,300 / 7,500). The AVL tree is gone; fossil collection is down to 6%; event execution is 26% of PE time (the model's forward work ~8%). What remains is mostly communication: LCI/libfabric progress 15%, sends through the node queue (`CkSendMsgNodeBranch` → `CldNodeEnqueue`, PP's node messages) 7%, `issueAm` 7.6%, mutexes 8% (libfabric CQ, node queue), Converse queue polling and TLS ~6%.

### Runtime tuning (2026-10-21 night, idev job 3627274, 4 skx nodes)

Code: charades 0a4c53a (fast paths on by default); `charades-prod` = production runtime; `charades-exp` = production runtime built from Reconverse branch `pads-runtime` (`$WORK/charm-pads-exp`). Scripts in `$WORK/charades-runs/`: `tune1.sh`, `session{1,2,3}.sh`, `tls_ab.sh`, `xport_try.sh`, `final_cmp.sh`, `pt_fix.sh`. Mac tests before: engine tier 508/508, change tier (old paths, --sched-park, all htram modes, ×3) 216/216.

**Step 1, existing knobs re-swept** (full nodes, 2 × 23 PEs pinned, W 250; M committed events/s, median of 3; ÷ base PP 64 = 58.5):
- htram PP buffer: **256 1.10, 512 1.18 (70.9 in session 2), 1024 1.08, 2048 1.12**; events per message 34 (64) → 80 (256) → 113 (512) → 145 (1024). At 64 PEs the buffer barely matters (high slack 27.0–27.5, low slack 19.0–19.5 for 64–1024).
- WPs 64 1.06, WPs 256 0.98, **WW 64 0.36** (9 events per message).
- `+lci_ndevices` 2: 0.91; 8: 0.99 (4 stays). Packet size 16 K, `+backend_poll_freq` 16/256, `--batch` 8/32/64: 0.97–1.02 (noise). `--gvt-wave-events` 64: 0.77, 256: 0.87 (128 stays).

**Step 2, the transport:**
- **Fewer pollers is slower.** `+backend_poll_thread` (every k-th PE polls; PP 512): k = 1 72.7, 2 70.6, 4 69.9, 6 62.3; k = 12 and 23 hung. Cause of the hang: `progress()` polls only the caller's own LCI device (threads are assigned to devices in blocks of 6), so for k past 6 some devices had no poller. **Fixed on Reconverse `pads-runtime`** (76f5a07, 78eedbf): the first thread of each device always polls (`comm_backend::threadMustPoll`); k = 12 and 23 then finish (66.5, 63.8), k = 1 unchanged (71.4–73.0). The earlier hang at k = 4 (before the fast paths) did not recur.
- **psm2 is out of reach without LCI work.** LCI's `fi_getinfo` hints declare no mode bits, and native psm2 (`FI_PROTO_PSMX2`) requires `FI_CONTEXT`; so LCI gets `psm2;ofi_rxd`, which aborts at startup with "Invalid remote handler (rhandler: 4294967295)". With `FI_CONTEXT` declared, the native entries offer only 0 or 4 bytes of CQ data, and LCI puts the source rank in the upper 32 bits of 8. Using native psm2 needs LCI to pass an `fi_context` with every operation and to carry the rank another way. (Probe: `$WORK/charades-runs/fiprobe/probe.c`; a progress-mode patch to LCI, `lci-progress-unspec.patch`, was not the cause.)
- **LCI's native ibv backend** (`LCI_ATTR_BACKEND=ibv LCI_ATTR_MAX_INJECT_SIZE=0 LCI_ATTR_IBV_TD_STRATEGY=none`) works across nodes but fails between two processes on one node ("Network completion failed for peer rank 1"), so only 1 process per node: 54.5–74.4, median 60.6, against verbs;ofi_rxm 2 × 23 at 66–72 (median 70). Not better.

**Step 3, Reconverse:**
- **TLS: compiling libreconverse with `-ftls-model=initial-exec`** (`pads-runtime` dda8c70; `__tls_get_addr` call sites 294 → 0): 6 interleaved pairs, 72.7 against 69.9 (+4.1%), faster in 6 of 6 (+1.0 to +6.8%).
- `CcdRaiseCondition` per iteration is already cheap when no callbacks are registered (returns on an empty list); its cost was the TLS access. Nothing further taken.

**Combined, same job as Devastator** (Charades: fast paths, TLS build, pinned, `+lci_ndevices 4`; PP 512 on full nodes, 256 at 64 PEs; Devastator at its best fixed W; M committed events/s, median of 3; Devastator ÷ Charades, lower is better):

| | Charades | Devastator | gap |
|---|---|---|---|
| full nodes, 23,552 LPs | 72.2 | 104.3 | **1.45×** |
| 64 cores, high slack | 27.4 | 53.9 | **1.97×** |
| 64 cores, low slack | 19.4 | 52.7 | **2.72×** |

From the start of the day on full nodes: 23.2 (Debug runtime) → 34.4 (production) → 43.9 (free core) → 45–46 (ndev 4) → 56–58 (fast paths) → 70 (PP 512) → 72–73 (TLS). The 64-core gaps shrink less: there the htram buffer does not matter and the runtime costs are a larger share.

**Recommended launch** (Stampede3 skx, 4 nodes): `PPN=2 PEPP=23 CPT=24 AGG=pp:512 EXTRA_ARGS="+lci_ndevices 4 +pemap 2-46:2,3-47:2"`, TREE built on a Reconverse with the TLS change. Superseded by native psm2, below.

### Native psm2 through a patched LCI (2026-10-22, idev jobs 3628343 (2 nodes) and 3628358 (4 nodes))

The step 2 diagnosis said psm2 needed LCI work; this is that work. **LCI branch `ofi-psm2-native`** (`~/lci_pr`, 45bc2faf on ca88ce2c, Reconverse's LCI pin; the same change on LCI master is 0d36acd1, branch `ofi-psm2-native-master`). On Stampede3 it is applied in place in `$WORK/charm-pads-exp/reconverse-linux-x86_64/_deps/lci-src` (patch `$WORK/charades-runs/lci-psm2.patch`), so `charades-exp` uses it. Four things kept LCI off native psm2:
- psm2 requires `FI_CONTEXT`. LCI now offers `FI_CONTEXT | FI_CONTEXT2` and, when the provider requires either, wraps each operation's context in a provider-owned `fi_context2` slot (thread-cached) that also records the operation.
- psm2 lists a variant with 0 bytes of CQ data first (its 64-bit tag layout). The hints now ask for 4 bytes.
- 4 bytes of CQ data cannot carry LCI's `rank << 32 | imm`. With under 8 bytes, LCI re-queries the provider with `FI_SOURCE`, uses an `FI_AV_TABLE` (fi_addr = rank), reads completions with `fi_cq_readfrom`, and sends the immediate alone.
- psm2 completes a receive with `FI_REMOTE_CQ_DATA` alone, without `FI_RECV`, so LCI misread receives as reads (segfault) or remote writes ("Unknown matching policy"). With wrapped contexts, completions are now classified by the recorded operation.

Providers that need none of this (verbs;ofi_rxm, tcp, cxi) keep the old paths. LCI ctest over ofi tcp on the Mac (master branch, warnings as errors): 25/25. Charades: `XPORT=psm2` in `scripts/stampede3/env.sh` selects psm2 with the system libfabric (the 2.7.0 build has no psm2 provider). Every run on either transport committed the same number of events.

**Settings** (one run each unless noted; M committed events/s, higher is better):
- **LCI packet size is the lever.** At 2 nodes, full nodes, 4 devices: psm2 with the 8 KB default 37.2 (3 interleaved runs: 37.3–37.6, against verbs 39.3–42.9), 16 KB 41.3, 32 KB 42.1, **64 KB 54.9–56.3**, 128 KB 51.7; verbs 40.6–43.8 at 8, 32 or 64 KB. An htram PP 512 message carries about 136 events (~10 KB); above the packet size LCI uses its rendezvous, a write with immediate data, which psm2 emulates in software.
- **More LCI devices help psm2 and not verbs.** At 4 nodes, 64 KB packets, full nodes: 4 devices 92.7, 8 97.5, 12 105.2, **16 109.2**, 23 108.8 (verbs 71.7, 72.2, 69.2 at 4, 8, 12). 2 × 8 PEs: 2, 4, 8 devices 41.4, 44.5, **48.7** (high slack), 27.1, 31.7, **37.6** (low slack); verbs 27.5 and 26.7, 19.4 and 19.0 at 4 and 8.
- No effect: `PSM2_RCVTHREAD=0`. Worse: htram PP 1024 (51.9), 256 (56.3, against 54.9 for 512, within noise at 2 nodes).

**Same job as Devastator** (`final_cmp2.sh`; Charades: everything above, verbs at 4 devices and 8 KB packets, psm2 at 64 KB packets with 16 devices on full nodes and 8 at 64 cores; Devastator at its best fixed W; M committed events/s, median of 3 interleaved; Devastator ÷ Charades psm2, lower is better):

| | Charades verbs | Charades psm2 | psm2 ÷ verbs | Devastator | gap (was) |
|---|---|---|---|---|---|
| full nodes, 23,552 LPs | 71.9 (71.2–75.1) | 107.6 (107.0–108.5) | 1.50× | 104.2 | **0.97×** (1.45×) |
| 64 cores, high slack | 27.1 (25.8–28.0) | 48.3 (48.3–48.8) | 1.79× | 53.8 | **1.11×** (1.97×) |
| 64 cores, low slack | 19.0 (19.0–19.4) | 37.7 (37.6–37.8) | 1.98× | 52.4 | **1.39×** (2.72×) |

Devastator runs on psm2 through GASNet-EX, so it already had this transport; most of the remaining gap was the transport.

**The controller on psm2** (same job, `ctl_psm2.sh`, one run each; M committed events/s; ÷ best fixed W, higher is better):

| | best fixed W | controller ε 0.003 | hill climb | worst fixed W tried |
|---|---|---|---|---|
| full nodes | 106.9 (W 250) | 92.9 (mean W 358), **0.87** | 32.3, 0.30 | 7.2 (W 1000), 0.07 |
| 64 cores, high slack | 48.5 (W 250) | 44.6 (mean W 299), **0.92** | 12.8, 0.26 | 17.1 (W 1000), 0.35 |
| 64 cores, low slack | 37.3 (W 50) | 35.5 (mean W 56), **0.95** | 9.1, 0.24 | 13.5 (W 250), 0.36 |

Same picture as on verbs (0.87–0.95 of the best fixed W; no single W is safe everywhere; the hill climb trails at 0.24–0.30).

### Gaussian PHOLD σ sweep on the fast stack (design, 2026-10-22; written before any runs)

**Why.** Every core result of the σ sweep (2026-10-21, job 3624866) came from the Debug runtime on verbs: aggregation 2.7–6.6×, rollback ÷ committed cost 11–21× with htram against 2.4–5× direct, the controller at ≥ 0.86 of the best fixed W. Since then the runtime is 1.5–1.8× faster (production, fast paths, TLS) and psm2 gave the htram arm another 1.5–2×. The direct arm has not been measured on psm2, and psm2's small-message rate may help it more, which would shrink the aggregation factor and change the rollback-cost ratio behind the joint-control argument.

**Setup.** As on 2026-10-21, changing only the stack:
- Same: 4 nodes × 2 processes × 8 PEs, 128 LPs per PE, 15 start events per LP, end time 64,000, margin 8; high slack (lookahead 100 / mean 1,000) at σ 100, 500, 1,000, 2,000, 4,000 and uniform remote 1.0; low slack (lookahead 10 / mean 200) at σ 500, 2,000 and uniform remote 1.0; direct sends against htram PP.
- Arms, high slack: blocking GVT; fixed W 50, 100, 250, 500; controller ε 0.003 and 0.01; hill climb from W 250. Low slack: the same with W 25, 50, 100 (W 250 storms there).
- New stack: `charades-exp` (fast paths, TLS Reconverse, LCI ofi-psm2-native), native psm2 with 64 KB packets, `+lci_ndevices 8`, pinned `+pemap 2-16:2,3-17:2`; htram PP 256 (best at 8 PEs per process; it was PP 64).
- Transport attribution: at σ 2,000 and uniform remote 1.0 (high slack), W 250, direct and htram on verbs;ofi_rxm too (4 devices, 8 KB packets).
- 3 reps, interleaved by rep.

**Predictions.**
1. Direct sends gain more than htram from the new stack, so the aggregation factor (best htram ÷ best direct, M committed events/s) shrinks to about 1.5–4×. It is still above 1 everywhere and still grows with the off-node share.
2. The rollback ÷ committed cost ratio (PE time per event, as in section 3 of the results) falls with htram to about 5–15×, because anti-messages, which go direct, also get cheaper on psm2. With direct sends it stays at 2–5×.
3. The controller at ε 0.003 reaches ≥ 0.85 of the best fixed W in every workload with htram, and ≥ 0.9 with direct sends.
4. The hill climb reaches ≤ 0.5 of the best fixed W with htram at every σ.
5. The best fixed W is still 250 at high slack and 50 at low slack.
6. Blocking GVT with htram stays ≤ 0.75 of the best fixed W.

### Gaussian PHOLD σ sweep on the fast stack, results (2026-10-22, idev job 3628587, 4 skx nodes)

**Runs.**
- CSVs are in `$WORK/charades-runs/gauss2/`: `{pp,off}_{hi,lo,verbs}_r{1,2,3}.csv`; script `gauss2_frozen.sh`.
- Summaries: `summary_gauss.txt` (`gauss_summary.py`) and `summary_policy.txt` (new `scripts/stampede3/policy_summary.py`: each arm ÷ the best fixed W in the same transport, and rollback cost).
- 426 runs. None failed or stalled. In every workload, all arms on both transports committed the same number of events.
- **Change from the design:** end time 512,000 at high slack and 128,000 at low slack, not 64,000. At 64,000 the fast stack executes a run in 0.2–0.4 s, too short to measure and too few GVT rounds for the controllers. That gives about 63 M and 79 M committed events per run, as in `final_cmp2.sh`.
- A first attempt was discarded unread: killing its tmux session left the sweep running on the node, alongside the restart.

**1. Aggregation still wins everywhere, by less** (best arm per transport, M committed events/s, median of 3; htram ÷ direct, higher is better):

| workload | off-node share (% of events) | best direct | best htram | htram ÷ direct | was (Debug, verbs) |
|---|---|---|---|---|---|
| σ 100, high slack | 3.9 | 28.6 | 55.3 | 1.94 | 2.70 |
| σ 500 | 19.5 | 21.5 | 52.6 | 2.45 | 4.12 |
| σ 1,000 | 38.2 | 18.3 | 50.5 | 2.76 | 5.04 |
| σ 2,000 | 62.3 | 16.2 | 48.9 | 3.02 | 5.95 |
| σ 4,000 | 74.6 | 15.3 | 49.2 | 3.21 | 6.58 |
| uniform remote 1.0 | 75.0 | 15.6 | 53.3 | 3.41 | 6.54 |
| σ 500, low slack | 19.5 | 21.2 | 45.2 | 2.13 | 3.37 |
| σ 2,000, low slack | 62.3 | 15.9 | 37.9 | 2.37 | 4.54 |
| uniform remote 1.0, low slack | 75.0 | 15.5 | 39.1 | 2.52 | 4.74 |

- **Most of the change is the transport.** At W 250 (median of 3; psm2 ÷ verbs, both on the fast stack):
  - direct sends: 2.89 on verbs against 16.17 on psm2 at σ 2,000, 5.6×; 2.63 against 15.61 at remote 1.0, 5.9×;
  - htram: 27.5 against 48.9, 1.8×; 24.3 against 53.3, 2.2×.
  - On verbs the fast stack's aggregation factor is 9.5× and 9.3×. psm2's small-message rate is what narrows it.
- A committed event now costs 2.2–4.2 µs of PE time with direct sends, against 1.2–1.7 µs with htram: 1.8–3.2× more, where it was 6×.

**2. Policies ÷ the best fixed W, same workload and transport** (medians; higher is better):

| policy | htram, high slack | htram, low slack | htram, worst case | direct, high slack | direct, low slack | direct, worst case |
|---|---|---|---|---|---|---|
| controller ε 0.003 | 0.89–0.92, but **0.74** (σ 4,000) and **0.68** (remote 1.0) | 0.94–0.96 | **0.68** | 0.96–1.00 | 0.98–0.99 | **0.96** |
| controller ε 0.01 | 0.77–0.87 | 0.90–0.94 | 0.77 | 0.91–0.99 | 0.99–1.00 | 0.91 |
| fixed W 50 | 0.43–0.47 | **1.00** | 0.43 | 0.61–0.71 | **1.00** | 0.61 |
| fixed W 100 | 0.67–0.72 | 0.64–0.80 | 0.64 | 0.81–0.86 | 0.89–0.99 | 0.81 |
| fixed W 250 | **1.00** | not run (storms) | – | **1.00** | not run | – |
| fixed W 500 | 0.72–0.76 | not run | – | 0.86–0.99 | not run | – |
| blocking GVT | 0.55–0.65 | 0.35–0.59 | 0.35 | 0.81–0.88 | 0.85–0.88 | 0.81 |
| hill climb from W 250 | 0.19–0.37 | 0.23–0.55 | 0.19 | 0.85–0.95 | 0.89–0.98 | 0.85 |

- The best fixed W is again 250 at high slack and 50 at low slack, with both transports.
- With direct sends, every adaptive policy is now good: the hill climb is 0.85–0.98 (was 0.73–0.80). With htram it stays poor (0.19–0.55). **The case for the controller is now the htram case**, where the fixed-W and hill-climb alternatives fail.

**3. Rollback cost** (PE µs per event; `policy_summary.py`; per extra rolled-back event against W 500 or the controller, divided by the cost of a committed event at the best fixed W):
- htram: 6.5–9.1× from W 500 at σ ≥ 500 (22× at σ 100); 15–30× from the controller at ε 0.01.
- Direct: 0.4–2.0× from W 500 at σ ≥ 1,000 (7.5× at σ 100); 0.8–3.0× from the controller.
- The transport gap behind the joint-control argument is wider than before: with direct sends on psm2 an extra rollback costs about as much as a committed event, with htram an order of magnitude more.

**4. The htram rollback floor, and why ε 0.003 fails at the remote end.**
- With htram, a share of events rolls back whatever the window, even at W 50, below the lookahead of 100. With direct sends nothing rolls back at W ≤ 250. Share rolled back (% of committed events, median):

| | W 50 | W 100 | W 250 | W 500 |
|---|---|---|---|---|
| htram, σ 100 / 500 / 1,000 | 0.04 / 0.09 / 0.12 | 0.05 / 0.11 / 0.17 | 0.06 / 0.15 / 0.23 | 1.4 / 4.3 / 5.5 |
| htram, σ 2,000 / 4,000 / remote 1.0 | 0.21 / 0.25 / 0.28 | 0.24 / 0.30 / 0.34 | 0.24 / 0.26 / 0.28 | 5.5 / 5.8 / 5.6 |
| htram, 2026-10-21 (PP 64, verbs, Debug), same three | 0.09 / 0.02 / 0.02 | 0.09 / 0.02 / 0.02 | 0.08 / 0.04 / 0.04 | 11.6 / 11.6 / 11.9 |
| direct, all six σ | 0.000 | 0.000 | 0.000 | 2.1–4.5 |

- At σ 4,000 and remote 1.0 the floor (0.25–0.34%) sits just under ε 0.003. The controller shrinks W to about 110 (mean W 110–120 in 5 of 6 runs; the best fixed W is 250). Below W 250 the rollbacks don't fall, so it never meets its target: 0.68–0.74 of the best fixed W, at 99.6% efficiency.
- **What causes it** (`floor.sh` and `floor_margin.sh`, σ 4,000, 2 runs each; share rolled back, %):
  - Not the fast paths: `--agg-inbox=0` 0.21–0.24, `--event-index=0` 0.20–0.27, `--msg-pool=0` 0.21–0.26, against 0.24–0.28.
  - htram residence time: PP 64 gives 0.010–0.026 (rate at W 250: 47.5–47.9 against 48.9–49.4). verbs, which delivers more slowly, gives 0.63–0.66 at W 50 and 2.98 at W 250.
  - **The deadline margin removes it:** at W 250, margin 8 gives 0.25 (48.9–49.1 M ev/s), 64 gives 0.001–0.002 (41.2–41.3), 250 and 1,000 give 0.000 (25.3–25.5 and 12.9–13.0).
- **Mechanism.** The window is GVT + W. The deadline policy flushes every destination holding a now-due event at each GVT update and when a PE idles (`flush_due` → `HTram::flushDue`, htram f07aceb). So buffered events *are* re-checked as GVT advances. (A first reading of this result said they were not; that was wrong.) The race is the one the `urgent_window` comment describes: a sender flushes when it learns of a GVT update, and a receiver that learns of the same update first may already run up to the new GVT + W. Every event that update made due is then still in a buffer, or in flight. The margin has to cover how far GVT moves per update. It moves about **61** time units per update on this stack in every configuration (end time ÷ GVT updates; it was 15 in the 2026-10-21 sweep), against a margin of 8. Margin 64 is the first value above the step, and the floor goes from 0.25% to 0.001%. Buffer size and transport change how long a flushed event takes to arrive, not the step, hence PP 64 lower and verbs higher.
- **What it costs.** The floor itself is cheap: at W 250, margin 8 (with the floor) gives 48.9–49.1 M ev/s, margin 64 (without it) 41.2–41.3. The wider horizon sends more events unaggregated, at insert and at each update. **The floor's real cost is to the controller**, whose event-share ε counts rollbacks that no window removes.
- **Options.**
  1. **Make the controller floor-aware** (no throughput cost: margin 8 stays). Estimate the window-independent rollback rate and target ε above it, or count only window stragglers (the existing floor guard did not catch a floor just under ε).
  2. **Tie the margin to the measured GVT step** (removes the floor; costs throughput; a sweep of margins 16–64 would show how much).
  3. A bucket-keyed hold (htram `sendItemPrioDeferredDest` + `changeThreshold`) releases held events at GVT updates too, so by itself it has the same race. It is still the mechanism for holding far-future events and cancelling an event in the buffer when its anti-message arrives.

**Predictions checked:**
1. Right: 1.94–3.41×, above 1 everywhere, growing with the off-node share.
2. Mixed. htram from W 500 is 6.5–9× (in range); from the controller 15–30× (above it). Direct is 0.4–2× at σ ≥ 1,000, below the predicted 2–5×: on psm2 a direct rollback costs about one committed event.
3. Wrong for htram at σ 4,000 (0.74) and remote 1.0 (0.68), because of the floor in section 4 (a race between GVT updates and flushes); right everywhere else, and right for direct (≥ 0.96).
4. Right except σ 500 at low slack (0.55).
5. Right.
6. Right (0.35–0.65). **Recommended launch now:** `XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536 PPN=2 PEPP=23 CPT=24 AGG=pp:512 EXTRA_ARGS="+lci_ndevices 16 +pemap 2-46:2,3-47:2"` (at 8 PEs per process: `+lci_ndevices 8`, PP 256), on `charades-exp`.


### Floor-aware controller, `--ctl-floor` (design, 2026-10-22; written before any runs)

**Change.**
- A sender marks a remote event `far` when its send delay d (ts − the sender's time) is at least its current window W. This is one byte, in padding that already exists in both `RemoteEvent` and htram's `PdesItem`.
- The receiver counts a far event that arrives behind its chare as a **late straggler** (new statistic "Late Stragglers").
- Under a window, a straggler needs d < W, so a far straggler arrived late: buffered, or in flight, past the GVT update that let its receiver pass it.
- With `--ctl-floor=1`, the controller calibrates α on rolled-back events scaled by the share of primary stragglers that were *not* late. So ε bounds the waste the window causes, and the floor no longer drives W down.
- Off by default until measured.

**A/B** (4 nodes, 2 × 8 PEs, psm2 64 KB, `+lci_ndevices 8`, htram PP 256, margin 8, 3 reps): the controller at ε 0.003 with `--ctl-floor=0` and `=1`, against the best fixed W, at:
- σ 4,000 and uniform remote 1.0, high slack: where it failed;
- σ 100 and σ 1,000, high slack, and σ 2,000 at low slack: where it worked.

**Predictions.**
1. With `--ctl-floor=1`, the controller reaches ≥ 0.9 of the best fixed W at σ 4,000 and remote 1.0 (from 0.74 and 0.68), with mean W 200–300 (from ~110).
2. Elsewhere it is within ±3% of `--ctl-floor=0`.
3. At W 250, late stragglers are ≥ 80% of all stragglers at σ 4,000 (the floor dominates there) and ≤ 50% at σ 100.

### Floor-aware controller, results (2026-10-22, idev job 3628811, 4 skx nodes)

**Runs.** `floor_ab.sh` (`--ctl-floor` 0 / 1; charades bc5055d) and `floor_ab2.sh` (0 / 1 / 2; f24c55c), 3 reps each, interleaved. CSVs are in `$WORK/charades-runs/floor_ab{,2}/`. 162 runs; none failed.

**The far flag misses most of the floor (prediction 3 wrong).** At W 250, *no* straggler was far: 0–2 of 54,592–58,014 at σ 4,000 and remote 1.0. The floor's stragglers have send delays below the window. They are short-delay events, so they become due soon after they are buffered, and the GVT-update race catches them. They are flagged far only once W shrinks below their delays, so `--ctl-floor=1` only stops the descent part-way.

**`--ctl-floor=2`** (f24c55c) also leaves out stragglers that htram's deadline policy *held* (not due when sent; `PdesItem` flag bit 1). A held event that straggles became due while buffered or in flight. At W 250, σ 4,000: 54,587 of 54,592 stragglers were held. A storm guard counts everything once more than 5% of executed events roll back.

Controller ε 0.003 ÷ the best fixed W (median of 3 from `floor_ab2.sh`; higher is better; mean W in parentheses):

| workload | best fixed W (M ev/s) | floor = 0 | floor = 1 | floor = 2 |
|---|---|---|---|---|
| σ 4,000, high slack | 49.1 | 0.75 (122) | 0.85 (143–256) | 0.87 (337) |
| uniform remote 1.0 | 52.7 | 0.68 (110) | 0.79 (142) | 0.87 (335) |
| σ 100 | 54.9 | 0.87 (340) | 0.87 (341) | 0.86 (355) |
| σ 1,000 | 49.8 | 0.91 (306) | 0.92 (309) | 0.88 (333) |
| σ 2,000, low slack | 37.4 | 0.95 (56) | 0.96 (56) | 0.96 (57) |
| full nodes, σ 2,000 | 108.0 | 0.88 (362) | 0.86 (367) | 0.86 (388) |

- `floor_ab.sh` agrees for floor 0 and 1 (σ 4,000: 0.74 against 0.93 there; remote 1.0: 0.72 against 0.79).
- **With `--ctl-floor=2` the collapse is gone:** 0.86–0.96 everywhere. But at high slack W now settles at 335–390, above the best fixed W of 250. That is the rollback-cost gap of the σ sweep (a rollback costs 15–30 committed events with htram), which ε 0.003 does not account for. Before this change a smaller ε was trapped by the floor.

**Next, ε 0.001 and 0.002 with `--ctl-floor=2`** (`floor_eps.sh`; predictions written before the runs):
1. At ε 0.001, W 250–300 at high slack and ≥ 0.92 of the best fixed W in every high-slack workload, full nodes included.
2. At low slack, ε 0.001 stays ≥ 0.93 (W near 50).
3. ε 0.002 falls between ε 0.001 and 0.003.

**ε results** (`floor_eps.sh`, CSVs in `$WORK/charades-runs/floor_eps/`; 63 runs, none failed). `--ctl-floor=2`, each ε ÷ the best fixed W in the same run set (medians of 3; higher is better; mean W in parentheses):

| workload | best fixed W (M ev/s) | ε 0.001 | ε 0.002 |
|---|---|---|---|
| σ 100 | 54.4 | 0.91 (319) | 0.88 (339) |
| σ 1,000 | 49.5 | 0.92 (306) | 0.90 (321) |
| σ 4,000 | 48.6 | 0.91 (311) | 0.89 (329) |
| uniform remote 1.0 | 52.4 | 0.89 (311) | 0.87 (323) |
| σ 2,000, low slack | 37.4 | 0.95 (50) | 0.96 (54) |
| uniform remote 1.0, low slack | 38.8 | 0.96 (50) | 0.95 (54) |
| full nodes, σ 2,000 | 107.0 | 0.87 (340) | 0.86 (366) |

- **Predictions:** 1 wrong. W came down to 305–340, not 250–300; 0.89–0.92 at 64 cores and 0.87 on full nodes, not ≥ 0.92. 2 right (0.95–0.96). 3 right.
- **Worst case against the σ sweep's ε 0.003 without the floor fix: 0.68 → 0.87.** ε 0.001 with `--ctl-floor=2` is at least as good in every workload but full nodes (0.87 against 0.88, within noise).
- **ε has little leverage now.** From 0.003 to 0.001 W moves only from ~335 to ~310. Whether an event is held depends on the horizon W + margin, so the share of stragglers left in the calibration grows with W. The fixed point is set more by that classification than by ε.
- **Direct sends** (`direct_eps.sh`, idev job 3628877; 54 runs, none failed; criterion set before the runs: ≥ 0.9 of the best fixed W everywhere and within 3% of the old default). Each controller ÷ the best fixed W (medians of 3; higher is better):

| workload | best fixed W (M ev/s) | ε 0.003, `--ctl-floor=0` (old default) | ε 0.001, `--ctl-floor=2` |
|---|---|---|---|
| σ 100 | 28.44 | 0.95 (W 341) | 0.96 (W 308) |
| σ 2,000 | 16.14 | 0.98 (342) | 0.98 (315) |
| uniform remote 1.0 | 15.59 | 0.99 (349) | 0.99 (315) |
| σ 2,000, low slack | 15.95 | 0.98 (59) | 0.98 (54) |
| uniform remote 1.0, low slack | 15.44 | 0.98 (60) | 0.99 (54) |
| full nodes, σ 2,000 | 32.01 (W 250, the only W run) | 1.05 (381) | 1.03 (337) |

  Passed: 0.96–1.03, and within 1.4% of the old default everywhere.
- **New defaults (2026-10-22): `--ctl-floor=2`, ε 0.001.** Runs before this used `--ctl-floor=0` and ε 0.003. Mac: the controller configs at `--tier change --repeat 2`, 264/264.


### Phase-changing PHOLD and traffic characterisation (design, 2026-10-22; written before any runs)

Run back to back in one 4-node interactive allocation (idev job 3628935). Both use 2 × 8 PEs per node, psm2 64 KB packets, `+lci_ndevices 8` and pinning; htram PP 256 against direct sends; 3 reps. The controller is the new default (`--ctl-floor=2`, ε 0.001).

**Phase-changing PHOLD.**
- The workload alternates low slack (lookahead 10 / mean 200; even phases, starting at 0) and high slack (lookahead 100 / mean 1,000) every 32,000 time units, over an end time of 256,000 (8 phases). PHOLD requires the alternate lookahead to be at least the base one, so low slack is the base (`phases:10:200:100:1000:<remote>:32000`); a first launch the other way round aborted at startup.
- Uniform remote 1.0 and 0.5; 128 LPs per PE.
- Arms: blocking GVT; fixed W 25, 50, 100, 250; the controller; the hill climb from W 250.
- **Why:** on steady workloads the controller's case is robustness: 0.87–0.96 of the best fixed W, which you only know after a sweep. Here no fixed W suits both phases, so the controller can beat every fixed W.
- **Predictions:**
  1. W 250 storms (stalls or falls below 0.3 of the best fixed W) with both transports, because of the low-slack phases.
  2. The best fixed W is 50 or 100, a compromise.
  3. With htram the controller reaches ≥ 1.1× the best fixed W, and with direct sends ≥ 1.0×.
  4. The hill climb reaches ≤ 0.6 of the best fixed W with htram.

**Traffic characterisation** (`ctl_sweep.sh` `traffic:` workloads; `models/traffic`).
- 8,192 intersections (128 per PE), 15 cars per intersection (122,880 cars), end time 512,000.
- A car's three events are Arrival, then Direction (to itself), then Departure (to itself), which sends an Arrival to a grid neighbour. So at most a third of events leave their LP, and north/south moves cross rows. Cars leave the simulation at their destination.
- LPs are laid out row-major in blocks of 2,048 per node, so the grid width sets the off-node share. Estimated: about 1% of events at 128 × 64, up to about 17% at 2,048 × 4.
- Workloads:
  - 128 × 64 uniform. A route is about 64 hops of three events with mean delay 1,100 each, about 210,000 time units, so most cars finish within the run and the load falls;
  - 128 × 64 congested: half the cars start in a 32 × 32 block at one corner and end in one at the other;
  - 2,048 × 4 uniform, high slack. Routes are about 680 hops, so few cars finish;
  - 2,048 × 4 at low slack (lookahead 10 / mean 200).
- Arms: blocking GVT; fixed W 50, 100, 250, 500, 1,000; the controller; the hill climb.
- **Predictions:**
  1. htram ÷ direct (best arms) is ≤ 1.3× at 128 × 64 and 1.5–2.5× at 2,048 × 4, below PHOLD at a similar off-node share (σ 500: 2.45×), because two thirds of events never leave their LP.
  2. The best fixed W is larger than PHOLD's at the same lookahead/mean (≥ 250 at high slack), because fewer events can straggle.
  3. The controller reaches ≥ 0.9 of the best fixed W in every traffic workload.
  4. The congested workload is ≥ 1.5× slower than uniform 128 × 64 (load imbalance from the corner block).

### Phase-changing PHOLD and traffic, results (2026-10-22, idev job 3628935, 4 skx nodes)

**Runs.** `phase_ab.sh`, `traffic_char.sh`, then `traffic_blk.sh`, back to back; CSVs are in `$WORK/charades-runs/{phase_ab,traffic_char,traffic_char_blk}/`. 294 runs; none failed in the end.
- Traffic's blocking-GVT arm first failed 24 of 24 at startup with an assertion: the event pool ran out. The `blocking` test config keeps the default event buffer, while every other arm gets 655,360 from `bucket`. Rerun with `--buffer-size=655360`: 24 of 24 ok. (PHOLD's blocking arm has always run with the default buffer.)
- Committed counts are identical across arms within each workload.

**Phase-changing PHOLD** (rate ÷ the best fixed W in the same workload and transport, medians of 3; higher is better):

| policy | htram, remote 0.5 | htram, remote 1.0 | direct, remote 0.5 | direct, remote 1.0 |
|---|---|---|---|---|
| best fixed W (M ev/s) | 42.6 (W 100) | 35.3 (W 50) | 25.5 (W 250) | 15.2 (W 250) |
| **controller** (default) | **1.08** | **1.08** | 0.99 | 1.00 |
| fixed W 25 | 0.72 | 0.78 | 0.76 | 0.84 |
| fixed W 50 | 0.97 | 1.00 | 0.94 | 0.98 |
| fixed W 100 | 1.00 | 0.92 | 0.98 | 0.99 |
| fixed W 250 | 0.61 | 0.43 | 1.00 | 1.00 |
| blocking GVT | 0.60 | 0.42 | 0.82 | 0.90 |
| hill climb | 0.38 | 0.24 | 0.98 | 0.99 |

- **With htram the controller beats every fixed W, by 8%.** It is the best arm in both workloads, at 46.1 and 38.1 M ev/s.
- With direct sends a large fixed W loses nothing: W 250 is best even with the low-slack phases, and the controller matches it.
- htram ÷ direct (best arms): 1.80 at remote 0.5, 2.51 at remote 1.0.
- **Predictions:**
  1. Wrong: W 250 did not storm. It reached 0.43–0.61 with htram, and was the best fixed W with direct sends.
  2. Right for htram (50 or 100); wrong for direct (250).
  3. Just short for htram: 1.08×, not ≥ 1.1×. Right for direct (0.99–1.00).
  4. Right (0.24–0.38).

**Traffic** (rate ÷ the best fixed W in the same workload and transport; higher is better):

| workload | events leaving their chare (% of committed) | best direct (M ev/s) | best htram (M ev/s) | htram ÷ direct | best fixed W | controller, htram / direct | hill climb, htram / direct | blocking, htram / direct |
|---|---|---|---|---|---|---|---|---|
| 128 × 64, uniform | 12.4 | 43.5 | 48.0 | 1.10 | 1,000 | 1.02 / 0.99 | 0.77 / 1.01 | 0.63 / 0.65 |
| 128 × 64, congested | 11.1 | 36.2 | 38.9 | 1.08 | 500 | 0.99 / 1.00 | 0.68 / 0.97 | 0.46 / 0.45 |
| 2,048 × 4, high slack | 2.3 | 89.5 | 86.5 | 0.97 | 1,000 | 0.92 / 0.94 | 0.91 / 0.96 | 0.33 / 0.32 |
| 2,048 × 4, low slack | 2.3 | 88.0 | 84.7 | 0.96 | 250 | 0.92 / 0.94 | 0.92 / 0.96 | 0.31 / 0.29 |

- **Traffic, laid out row-major, is communication-light.** Only 2.3–12.4% of events leave their *chare*, and fewer leave the node. So aggregation hardly matters (0.96–1.10×) and rollbacks are rare: no arm had enough extra rollbacks to measure their cost.
- The off-node estimate in the design was wrong for 2,048 × 4. Destinations span only 4 rows, so routes run almost entirely east–west along rows a single PE holds, and north–south moves, the ones that cross nodes, are rare.
- **Predictions:**
  1. Right at 128 × 64 (1.08–1.10); wrong at 2,048 × 4 (0.96–0.97, not 1.5–2.5).
  2. Right (best W 250 at low slack, 500–1,000 at high slack).
  3. Right (0.92–1.02).
  4. Wrong: congested is 1.20–1.23× slower than uniform, not ≥ 1.5×.
- **Implication:** with a locality-preserving layout, this model shows that the engine and the controller cost nothing on local workloads (controller 0.92–1.02), not that aggregation helps. To exercise communication it needs a layout or partition that splits neighbours across nodes (more nodes, fewer intersections per PE, or a block or graph partition of a real road network), or a model with longer-range interactions.

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
- **Tiers** (`--tier`, added 2026-10-21, because the whole matrix is about 3,250 runs and mostly redundant). Run counts and approximate Mac times:

| tier | when | what runs | runs (count) | time (min) |
|---|---|---|---|---|
| `change` | a routine change | the named test_configs on 4 core model configs (PHOLD base and phases, Imbalanced combo, Traffic base) at 1 PE, 4 PEs and 2 × 2 | 12 per config | 1–3 |
| `engine` (default) | GVT, scheduler, aggregation or controller | every working test_config on the core model configs at those shapes, then the named ones `--repeat` times (default 20) at the multi-PE shapes on PHOLD base and Imbalanced combo | 400 + 80 per named config | ~6 + ~1 per named config |
| `full` | before merging a large branch or starting a paper's runs | every test_config × every model config × 7 shapes | ~3,250 | ~50 |

- The races fixed so far failed in 0.5–20% of runs, which one pass usually misses. Repeats find them; breadth doesn't. So name the configs you touched, e.g. `python3 tests/test.py bucket` for a GVT change.
- `python3 tests/test.py --help` lists the rest (`--quick`, `--launch`, `--all`, `--no-build`, `--timeout`). Output goes to `tests/test_output/`.

## Next steps, in order (revised 2026-10-21 after the Gaussian σ sweep)

Done:
- Charades on Reconverse, SMP-safe.
- Aggregation through htram in all four modes, with the deadline flush policy.
- The window controller and the hill-climb baseline.
- Paced count waves.
- The 4-node Gaussian σ sweep (see "Gaussian PHOLD σ sweep, results").

What the sweep changes in the claim:
- On steady workloads the controller does not beat the best fixed window; the best fixed W wins by 1–14%. The defensible claim is its worst case.
  - With htram, the controller at ε 0.003 is 0.86 or better of the best fixed W in every regime.
  - Any single fixed W is 0.47 or worse somewhere.
  - Blocking GVT is 0.61 and the hill climb 0.32.
- Aggregation is the large effect: 2.7–6.6×, growing with the off-node share.
- The transport changes the right optimism target: a rolled-back event costs 2.4–5 committed events with direct sends and 11–21 with htram.
  - That is direct evidence that window control and aggregation have to be designed together.
  - The paper's "joint control" claim should rest on this.

1. **DONE 2026-10-21** (see "Controller on the GVT's count waves, results"): the shared reduction controls as well as the separate one and costs about the same; a histogram on every wave hurts control; the hill climb gets worse the more often it decides. **Default since 2026-10-21 (user decision):** `--ctl-reduction=1` with the coarse histogram on every 8th wave and rounds of 8 waves under the bucketed GVT. Other GVTs fall back to the separate reduction; `ctl_quantile_separate` and `ctl_quantile_blocking` cover both paths. Original plan: **One reduction for GVT and the controller** (user decision, 2026-10-21). The controller's data rides on the bucketed GVT's count waves instead of its own `Controller` reduction, as Devastator piggybacks its efficiency counts on GVT.
   - **Today:**
     - a separate sum reduction once per 8 GVT updates (about 3 KB per PE: 385 histogram bins and 6 counters);
     - up to about 5% cost (the dry run);
     - 12–20% when it ran every GVT update.
   - **Design:**
     - Add the controller's counters (executed, rolled back, committed, remote sends, stragglers, elapsed time) as `sum_ulong_long` elements of the count-wave tuple, read as deltas since this PE's last wave.
     - Every PE already contributes exactly once per wave, and every PE receives the same result, so each can compute the same W in `check_counts`, next to the GVT advance.
   - **The delay histogram is the bulky part.** Choose among, by measurement:
     - all 385 bins on every wave;
     - all bins on every Nth wave, with counters on every wave;
     - a coarser histogram, for example one bin per power of two (49 bins), which is enough for the quantiles the rule needs.
   - **Cadence.** Waves come every few hundred µs, about one per 128 events per PE, so the window could change every wave.
     - The quantile rule already folds only every 256 delays.
     - The hill climb's 16-round average would cover milliseconds instead of hundreds of milliseconds.
     - Keep a decision interval in waves as an option.
   - **Scope.**
     - The standalone `Controller` reduction stays for the other GVT managers (blocking GVT has no reduction to share). `--ctl-reduction=shared|separate` picks between them, for the comparison.
     - The start reduction (`all_ready`) carries nothing new; the counters accumulate until the next wave.
   - **Measure** (4 nodes, the σ-sweep workloads, both slack levels):
     - cost in a dry run, shared vs. separate;
     - throughput relative to the best fixed W;
     - GVT waves per second (does the bigger tuple slow the waves?);
     - how fast W settles after a phase change (phases PHOLD).
   - **Predictions:**
     - dry-run cost of 1% or less with counters every wave and the histogram every 8th wave;
     - with the full histogram every wave, waves slow measurably (≥ 5% fewer waves per second);
     - the hill climb fed every wave (Devastator's actual design) does better than at every 8 GVT updates, but still trails the quantile rule.
   - **Gate:** Mac test matrix unchanged (committed counts), and `--repeat 20` on the `ctl_*` configs.
2. **DONE 2026-10-21, partly** (see "Controller step 2, results" and "Three engines on Gaussian PHOLD"):
   - the floor guard works;
   - the time-share target failed (rollbacks cost mostly through GVT, not CPU work), so the defaults went back to event share 0.003 with the full histogram;
   - open: full nodes, where a waste floor of about 0.45% makes the event share uninformative (an affine model, rolled-back share = floor + α·r·F(W), could fix it), and ε 0.001, which is better with htram at high slack but untested with direct sends.

   **DECISION NEEDED before step 3 (the user): the paper's framing.** Devastator is 3.2–4.0× faster than Charades at 64 cores, and 3.6× on full nodes with a fixed window. ROSS is 1.1–1.5× faster. But Devastator's own hill-climbed window collapses on full nodes (2.8% efficiency), where our rule kept Charades at 0.95–0.97 of its best fixed window. Options:
   - (a) the window controller as the contribution, shown in Devastator itself (its `global_status_state::update()` is the hook) and in Charades;
   - (b) close Charades' per-event gap first (profile scheduler, entry methods, htram);
   - (c) keep the Charades-only framing and report the absolute gap.

   Original plan for this step: **Controller fixes**, built on step 1 and checked on the Mac, then the σ sweep rerun on 4 nodes.
   - Default `--ctl-epsilon` 0.003; it is 0.05 now.
   - Floor guard: don't calibrate α, and don't shrink W, while F(W) ≈ 0. This is the ε 0.001 trap at about W 98.
   - A cost-aware target: bound the share of *PE time* lost to rollbacks rather than the share of events.
     - Estimate the cost of a committed and of a rolled-back event from a fit of time against the two counts. Per-wave counters (step 1) give many more points than rounds of 8 GVT updates. Alternatively, time rollback and anti-message sends directly.
   - Prediction: the htram high-slack gap closes from 0.86–0.92 to 0.95 or better, and nothing else drops below 0.95.
   - Gate: worst case of 0.95 or better of the best fixed W over 9 workloads × 2 transports.
   - New from step 1:
     - The controller reaches only 0.66 of W 250 at full nodes (4 × 48 PEs, high slack), against 0.90 at 16 PEs per node. Find out why before tuning ε.
     - If per-wave histograms are wanted, fold by samples per wave rather than a fixed 256.
   - **In parallel with steps 1–2: the external baselines** (user decision, 2026-10-21; moved up because they are the paper's biggest unknown and don't depend on the controller work).
     - Build ROSS on Stampede3. Add Gaussian destinations to its PHOLD (it has only a remote-percent coin flip) with the same parameters as ours: exponential delay, lookahead, σ in LP ids, 15 start events per LP.
     - Try to build Devastator's public code (github.com/cychan-lbnl/devastator, last pushed 2022-11; needs GASNet-EX for Omni-Path). Check whether it has the adaptive window and Gaussian PHOLD.
     - Why now: with htram at σ 2,000 we commit about 178 K events/s per PE. Devastator's Fig. 3 puts ROSS in a similar per-core range at σ = 10⁴ (read off the plot). If tuned pure-MPI ROSS matches or beats us, the framing has to change.
3. **4-node comparison across engines**, together with the hill-climb fairness check and the `--agg-scope` ablation.
   - **Engines:** Charades (direct and htram) against ROSS, and Devastator if it built, on the σ-sweep workloads at both slack levels.
   - **Full nodes.** We have run 16 PEs per node on 48-core nodes, while ROSS uses all 48. Add Charades runs that use the full node (for example 2 processes × 23 PEs), and compare per node as well as per core.
   - **ROSS tuning.** Tune its batch and GVT-interval settings as Devastator did (a grid per node count), and report the tuning cost.
   - **New from the first ROSS runs (2026-10-21):**
     - **Fix or explain optimistic ROSS's multi-node abort** (`avl_tree.c:276`; psm2/tcp, and all providers at 192 ranks). Try Intel MPI, and read how `network-mpi.c` orders events and anti-messages.
     - **Use psm2 for conservative ROSS**: about 2× faster than verbs.
     - **Conservative ROSS is a serious baseline at lookahead 100** (10.4 vs Charades' 11.3 M ev/s on full nodes). Add small-lookahead workloads (lookahead 1–10 against mean 200–1,000), where conservative execution should collapse and optimism matters; that is the regime the claim needs.
     - **Use Devastator's problem size** (100 LPs per core) and longer end times: current runs execute for about 0.7 s, and Charades didn't speed up from 64 to 192 PEs at that size.
     - **Repeat ROSS runs**: two identical conservative runs gave 5.54 and 8.47 M ev/s.
     - **The hill climb**: our rule degrades the more often it decides (0.45 → 0.07 from every 8 GVTs to every wave), so the fair Devastator arm is Devastator's own code. Build it on Stampede3 with a matched `phold-gauss` bench.
   - **Hill-climb fairness.** Our reimplementation stands in for Devastator and loses by 2–3×, so a reviewer may call it a strawman. Run it every GVT round on the shared reduction (step 1), from W 50 and from the bucket size, and against Devastator's own code if available.
   - **`--agg-scope` ablation** (other processes only, against all) at σ 100 and 2,000. It explains the 2.7× gain where only 3.9% of events go off-node. Devastator's in-process path is a cheap lock-free queue insert, so if most of that gain is htram bypassing a slow in-process Charm++ message path, the claim must say so.
4. **Cheaper rollbacks under aggregation.** Anti-messages go through htram, with in-buffer annihilation: an event still in the sender's buffer is cancelled together with its anti-message.
   - Measure the rollback ÷ committed cost ratio, now 11–21× with htram, and throughput at W 500.
   - Risk: a delayed anti-message lets wrong work spread further. Anti-messages may need urgent sends.
5. **Scale** to 16–32 nodes on skx-normal, all engines, as batch jobs after a short interactive check:
   - Gaussian σ up to about 16,000 (32,768 LPs at 16 nodes), with Devastator's 100 LPs per core;
   - uniform remote 1.0;
   - the same policies, both slack levels.
6. **In-Charades baselines and phase-changing workloads.**
   - The PADS'19 static hold (open issue 1: its cutoff needs tuning per model first).
   - PADS'98 local-rate aggregation.
   - Opportunistic aggregation (ship whatever is queued on every pass, as Devastator's service thread does).
   - Phases PHOLD with the fixed controller, where it should beat every fixed W outright, not only in the worst case.
7. **Housekeeping:**
   - SSSP parity check on htram `pdes`;
   - open issue 7;
   - 8 nodes and PPN 1 against 2;
   - units in the older tables of this file.
8. Dragonfly port when needed.
