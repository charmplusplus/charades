# Working context: Charades on Reconverse, toward SIGSIM PADS 2027

Written for: Ritvik, or a Claude session, picking this work up on Stampede3.
Snapshot of 2026-10-18 (work so far was done on a Mac laptop). The full research
plan lives only on that laptop, so the parts needed to continue are copied here.

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

## State of the code (2026-10-18)

| Repo | Branch / ref | State |
|---|---|---|
| charmplusplus/charades | `main` @ 09df056 | Reconverse port, SMP fixes, test harness, two optimistic-engine GVT fixes |
| charmplusplus/charades | `smp-gvt-fixes` | Bucketed GVT fix, `Event::index` fix, init races, `test.py --repeat`, srun-safe `test.py`, this file. **Push it if it isn't on origin yet.** |
| charmplusplus/charm | `reconverse-interop` @ a47851b88 | User-driven interop on Reconverse, review addressed; **PR #4055** (open). Pins Reconverse `main` ebafde2 |
| charmplusplus/reconverse | `main` @ ebafde2 | Contains interop (#288, merged) |
| charmplusplus/reconverse | `idle-progress-poll` @ ff33b56 | QD speed fix; **PR #290** (open) |

**Why `idle-progress-poll` matters.** Reconverse's default scheduler polled the
network ~40 times per idle sweep before raising idle conditions. Quiescence
detection waits on those conditions every hop, so with one PE per process a QD
round took 10.7 ms instead of 0.39 ms on the Mac (libfabric TCP, a `kevent`
per poll). Synchronous GVT and the conservative scheduler use QD every round:
Charades conservative `long` went from 70 s to 4.1 s. Whether it matters as
much on Omni-Path/verbs is unmeasured — measure it (QD loop and Charades,
with and without the fix) early on Stampede3.

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
- `Event::index` was 8 bits: a chare with > 256 pending events corrupted its
  heap.
- Permanent assertions catch GVT running ahead: LP token vs. earliest pending
  event at each synchronous GVT contribution; events or anti-events arriving
  below GVT; committing an event that is in the cancel queue.

**Test status on the Mac:** full matrix 360/360; 0 failures in 1,800
synchronous-GVT and 1,400 bucketed-GVT stress runs at 2–4 PEs.

## Open issues

1. **Event holding (PADS'19 Sec. 5) cannot be turned on.** `g_tw_adaptive_buckets`,
   `g_tw_reserve_threshold`, `g_tw_reserve_buckets`, `g_tw_clear_lag` and
   `g_tw_clear_buckets` have defaults in `src/globals.C` but are not
   registered in `src/util/command_line.C`. Register them, then test the path
   (`reserves`, `attempt_cancel`, `charm_event_release` in
   `src/gvt/bucketed.C`); it is a required baseline and has never run under
   Reconverse or SMP.
2. CD GVT (`gvt=2`) and phased GVT (`gvt=3`) hang at more than one PE on every
   runtime (issue #11). `test.py` skips them unless `--all`.
3. Load balancing / migration never run on Reconverse or with several PEs per
   process; anti-message lookup trees draw nodes from a per-PE pool, flagged in
   the code as a migration problem. The paper runs with LB off.
4. Dragonfly and PCS still use the pre-2019 `ross_api.h` and don't build.
   Traffic builds but has no test configs.
5. No timing so far is from a real network. Everything above was measured on a
   laptop.

## Building on Stampede3

Run Claude and VS Code locally, not on login nodes (per-user process limit,
`ulimit -u` = 300). Build and run on compute nodes inside `idev`.

**Charm++.** `~/charm_reconverse` on Stampede3 is an old build (June
`reconverse-specific-build`, Reconverse aa1bd88, no rpath); don't use it for
this. Build a fresh tree, e.g. in `$WORK`:

```
git clone -b reconverse-interop https://github.com/charmplusplus/charm.git charm-pads
cd charm-pads
git submodule update --init -- contrib/reconverse     # pinned ebafde2
# optional, for the QD fix (PR #290):
git -C contrib/reconverse fetch origin && git -C contrib/reconverse checkout idle-progress-poll
./build charm++ reconverse-linux-x86_64 --disable-fortran -j16
```

- Don't pass `smp` (the reconverse target is always SMP). CMake options go in
  `--with-cmake-args="..."`; a bare `-DFOO=BAR` silently becomes a compiler
  flag. Check what was built in `<builddir>/include/conv-autoconfig.h`
  (`CMK_SMP`, `CMK_RECONVERSE`).
- Check which compiler module the existing Stampede3 builds used
  (`CMAKE_CXX_COMPILER` in their `CMakeCache.txt`) and load the same.

**Charades.**

```
cd charades/src
cp config.mk.template config.mk      # set CHARADES_SRC and CHARM_DIR
make
cd ../models/phold/simple && make    # each model builds the library first
```

`config.mk` must keep `CFLAGS += -std=c++17`.

**Environment for every run** (Omni-Path; only `verbs;ofi_rxm` or `tcp` work
for LCI there — default ibv aborts, psm2 hangs, opx fails at init):

```
export LCI_ATTR_BACKEND=ofi
export LCI_ATTR_OFI_PROVIDER_NAME="verbs;ofi_rxm"
export FI_PROVIDER=verbs,ofi_rxm
```

The system libfabric (2.6.0a1) segfaults at shutdown in ~10% of runs (RxM over
verbs). libfabric 2.7.0 in `$WORK/libfabric-2.7.0` fixes it: set
`LD_LIBRARY_PATH=$WORK/libfabric-2.7.0/lib` and `FI_PROVIDER_PATH` to an empty
directory. For multi-node jobs, stage the `.so` to node-local `/tmp` with
`sbcast` first — reading it from `$WORK` stalled a job's first launch for
minutes. `~/c4p_runs/step5_h1.slurm` has a working example of all of this.

## Running

- **Always `srun`, never `lcrun`, on the cluster — even for one process.**
  Inside an allocation LCI reads `SLURM_NTASKS` and waits for peers that never
  start. `srun --mpi=pmi2 -n <procs> ./phold +pe <total PEs> <model cfg> <sync cfg>`.
- `tests/test.py --launcher srun` does this for every run, with
  `--kill-on-bad-exit=1 --wait=30`, and on timeout sends SIGTERM before
  SIGKILL. A SIGKILLed `srun` leaves its step registered, and every later
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

1. Push `smp-gvt-fixes` (if not yet), build Charm++ and Charades on Stampede3,
   get `tests/test.py --launcher srun` passing at one and several PEs per
   process, 1–2 nodes.
2. Measure QD round time and Charades conservative / blocking-GVT runs with
   and without `idle-progress-poll`, and synchronous vs. bucketed GVT cost, at
   1–4 nodes. This decides which GVT the paper uses.
3. Register the event-holding options and test that path (open issue 1).
4. Gaussian PHOLD model; per-event latency and residence-time instrumentation.
5. Go/no-go measurement at 4–16 nodes (see the timeline).
6. Then htram, the controller, baselines; dragonfly port when needed.
