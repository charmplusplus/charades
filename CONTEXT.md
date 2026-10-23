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

**Why `idle-progress-poll` matters.** Reconverse polled the network many times per idle sweep before raising idle conditions, and quiescence detection waits on those every hop; the fix made QD rounds and the QD-based GVTs several times faster (numbers in `RESULTS.md`).

### Measurements

Every run's numbers (designs with predictions, results, job IDs, status) are in [RESULTS.md](RESULTS.md), in order, with the current headline numbers at the top. Write new designs and results there, not here.

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
4. PCS still uses the pre-2019 `ross_api.h` and doesn't build. Dragonfly was ported 2026-10-23 (merge 4c88814): time is integer ps, so under the bucketed GVT it needs `--gvt-bucket-size=1000` (1 ns; the default 8 is 8 ps and the run crawls). Its test configs set this, and a smaller bucket prints a warning. Every cross-LP message fits htram's 24 B slot.
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
   2026-10-23: LCI's "no posted recvs" alert is the pool starvation that PR #214's fair-share receive cap fixes (`RESULTS.md`, "LCI on native psm2"). Retest this shape with the patched LCI before digging further.

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

## Next steps, in order (revised 2026-10-23)

Results behind each step are in `RESULTS.md` ("Current numbers" at the top). The list as of 2026-10-21 is kept there as "Plan history".

1. **Controller.** Done in part (job 3633379). With htram, a wider window costs aggregation before rollbacks. The new default bound on remote sends inside the window (`--ctl-agg-kappa=0.20`), sparse controller waves and the histogram every 32nd wave raise the worst case from 0.84 to 0.94 of the best fixed W, with no workload worse (`RESULTS.md`). Still open:
   - κ is one constant. Long delays want about 0.17 and short ones about 0.22; a κ that adapts would close the last 6% at lookahead 100.
   - The start: α from 1 holds W low for the first rounds; starting it lower hurt traffic.
   - Test κ on dragonfly, a model it was not fitted to.
2. **Paper-grade 4-node comparison, one allocation:**
   - Devastator with `--rng=clcg4`;
   - ROSS on full nodes, tuned (batch × GVT interval; it has not been rerun since the Debug-runtime days);
   - Charades with the step 1 controller;
   - runs of 10 s or more, since 1.9 s runs understate every adaptive arm.
3. **Dragonfly on Stampede3** (`--gvt-bucket-size=1000`): aggregation, the controller and fixed W, on uniform, worst-case and phase-changing traffic. Charades only, since Devastator and ROSS have no dragonfly.
4. **Scale to 16–32 nodes** on skx-normal, all engines, as batch jobs after a short interactive check.
5. **In-Charades baselines:**
   - the PADS'19 static hold (open issue 1: pick its cutoff per model first);
   - PADS'98 local-rate aggregation;
   - opportunistic aggregation.
6. **Housekeeping:**
   - SSSP parity check on htram `pdes`;
   - retest open issue 7 with PR #214's fair-share cap;
   - the Reconverse TLS PR;
   - bump Reconverse's LCI pin once #214 merges.
7. **User decision, open since 2026-10-21: the paper's framing.** Option (a), the controller ported into Devastator, is still open; see "Plan history".
