# ROSS and Devastator as baselines

First runs and feasibility, ROSS's optimism window on PHOLD, and the Mac checks that both engines commit Charades' counts. Part of the Charades results: the current paper tables are on the front page, [../RESULTS.md](../RESULTS.md), and every section's date, job, status and file is in [INDEX.md](INDEX.md). Sections keep the numbers (§N) they had in the single RESULTS.md they came from (split 2026-11-07); "section N" anywhere means §N.

| § | date | status | section |
|---|---|---|---|
| 241 | 2026-11-06 | current | RW results: ROSS's window gains PHOLD only 1.00–1.04× at 4 nodes, because ROSS without it already commits 9… |
| 14 | 2026-10-21 | historical | External baselines, Mac feasibility |
| 16 | 2026-10-21 | historical | ROSS on Stampede3, first runs (same job) |

## Current

Current findings, and designs with their results, in the order they were written.

### §241 · RW results: ROSS's window gains PHOLD only 1.00–1.04× at 4 nodes, because ROSS without it already commits 97.9–99.3% of the events it executes; σ 100 at 1 node is the exception (1.23×) (2026-11-06; skx-dev batch job 3688911, 5 nodes)

> **Status: current.** Design and predictions in section 240 (C6).
> - **Job:** 10 minutes of runs (11:48–11:58); 96 runs, all finished. The skx copy 3688912 was cancelled before it started.
> - **Data:** `~/charades-data/f1/rosswin240/rosswin_j3688911/`; summary `~/charades-data/f1/rosswin240_summary.py`, output `rosswin240/j3688911_summary.txt`.
> - **Counts:** within each workload and node count, every window commits the same events.
> - **The file F1 reads** (`$WORK/charades-runs/f1_240/ross_windows.txt`) was written before any F1 job started. It holds W 250 (σ 100), 500 (σ 500, 1,000 and 2,000), 1,000 (σ 4,000), 100 (both lookahead-10 workloads) and 0 (uniform, where no window beat none). So F1 runs one ROSS window arm on seven workloads, and none on uniform.

ROSS optimistic, batch 16 / GVT interval 64, A0's run length (end time 512,000; lookahead 10: 128,000), 1 rep. Rates in M committed events/s, higher is better. Efficiency is committed ÷ executed events, in %. Gain is the best window's rate ÷ the rate without a window, higher is better.

| workload | 1 node, no window: M ev/s (efficiency %) | 1 node, best window: W, M ev/s | gain, 1 node | 4 nodes, no window: M ev/s (efficiency %) | 4 nodes, best window: W, M ev/s (efficiency %) | gain, 4 nodes |
|---|---|---|---|---|---|---|
| σ 100 | 13.98 (93.3) | 250, 17.17 | **1.23** | 56.61 (97.9) | 250, 58.71 (99.99) | 1.04 |
| σ 500 | 10.58 (98.9) | 2,000, 11.02 | 1.04 | 39.05 (98.9) | 500, 39.88 (99.89) | 1.02 |
| σ 1,000 | 9.10 (99.2) | 1,000, 9.14 | 1.00 | 34.18 (99.1) | 500, 34.51 (99.95) | 1.01 |
| σ 2,000 | 8.83 (99.3) | 500, 8.91 | 1.01 | 28.56 (99.2) | 500, 28.82 (99.97) | 1.01 |
| σ 4,000 | 8.76 (99.3) | 1,000, 8.79 | 1.00 | 27.14 (99.2) | 1,000, 27.22 (99.25) | 1.00 |
| uniform | 8.89 (99.2) | 4,000, 8.90 | 1.00 | 25.92 (99.3) | none (best window 1,000: 25.88) | 1.00 |
| lookahead 10, σ 500 | 10.56 (98.3) | 100, 10.69 | 1.01 | 38.35 (98.2) | 100, 39.02 (99.53) | 1.02 |
| lookahead 10, σ 2,000 | 8.55 (98.8) | 100, 8.68 | 1.02 | 27.87 (98.8) | 100, 28.26 (99.66) | 1.01 |

**What the job shows:**
- **A window can only remove the work ROSS rolls back, and on PHOLD there is little of it.**
  - Without a window, ROSS commits 97.9–99.3% of the events it executes at 4 nodes. The best window raises that to 99.25–99.99%, and the rate by at most 4%.
  - With one rep, the job cannot tell gains of 1–2% from the spread between runs.
- **σ 100 at 1 node is the exception.** Without a window ROSS commits only 93.3% there; W 250 raises that to 99.97% and the rate 1.23×.
  - W 250 is the lowest window tried. At 99.97% there is almost no rollback left to remove, so a narrower window could only add waiting.
- **Narrow windows cost; wide ones do nothing.**
  - At 4 nodes, W 250 runs at 0.95–0.98 of no window on σ 1,000 to uniform, and lookahead 10's W 50 at 0.98.
  - W 2,000 and 4,000 run at 0.97–1.00 of no window, at about the same efficiency: they rarely bind.
  - From 500 to 1,000 the rate is flat within 1% on σ 500–4,000, so the choice between them hardly matters.
- **Why ROSS rolls back so little on PHOLD (not tested):**
  - ROSS's GVT is synchronous: every PE stops for it every 64 passes of its scheduling loop, and each pass runs at most 16 events, so at most 1,024 events apart (`core/gvt/mpi_allreduce.c`, blocking `MPI_Allreduce`).
  - That may already bound how far one PE runs ahead of the others, leaving the window little to do.
  - On traffic and dragonfly the same window gains 1.13–1.19× and 1.35–1.48× (sections 223, 225).

**Predictions (C6):**
- **"Beats no window by 1.05–1.25× on at least five of the eight workloads at 4 nodes": wrong.**
  - It gains 1.00–1.04× on all eight.
  - Only σ 100 at 1 node (1.23×) falls in the range.
  - C6 carried over the gains on traffic and dragonfly. On PHOLD, ROSS rolls back too little for that.
- **"ROSS's best window at lookahead 100 is 1,000–4,000": wrong.** It is 250–1,000 (σ 100: 250; σ 500–2,000: 500; σ 4,000: 1,000), and no window on uniform.
- **"Charades ÷ ROSS at its best (window included) stays at least 2.0 in every F1 cell":** F1 tests this.
  - The old range was 2.42–3.02 at σ 100 and 2.4–5.3 overall, against ROSS without its window.
  - At 4 nodes the window moves ROSS's best by at most 4%. At 1 node on σ 100 it moves it by up to 1.23×.

**What follows:**
- **F1's ROSS arms use these windows.** The file was in place before any of F1's six jobs started (all still pending at 12:00).
- **In the paper,** ROSS on PHOLD is the best of optimistic, conservative and optimistic with its window, tuned per workload.
  - That answers the fairness question for every workload: ROSS's window was tried on PHOLD, traffic, dragonfly and VLSI.
  - On PHOLD it hardly changes ROSS's rate, except σ 100 at 1 node.
- **Nothing to rerun.**

## Checks on the Mac


Moved here from `~/pdes-baselines/NOTES.md` and `~/pdes-baselines/ross-debug/REPORT.md`, which keep the build notes and the diagnosis. Counts only: Mac timings are meaningless.

### ROSS reproduces Charades (2026-10-21, Mac)

**1. Cross-engine: ROSS reproduces Charades' committed-event counts exactly.**
- The Charades side is single-process: `~/charades/models/phold/simple/phold +pe 1 ... --buffer-size=200000`. It needs a buffer larger than the default 8192 at 15 start events.
- Both engines use the same clcg4 streams, so equal counts mean the two models make the same draws in the same order.

Committed events (count; the two engines must be equal):

| config | Charades committed | ROSS `--synch=1` net events |
|---|---|---|
| test_configs/base: 32 LPs, end 64,000, lookahead 100 | 2,055 (expected-events) | 2,055 |
| test_configs/gaussian: 64 LPs, 4 start, σ 6 | 16,389 (expected-events) | 16,389 |
| test_configs/long: 16 LPs, end 1,024,000 | 16,370 (expected-events) | 16,370 |
| test_configs/wide: 64 LPs | 4,085 (expected-events) | 4,085 (4,083 with `--int-ts=0`) |
| 1024 LPs, 15 start, lookahead 100 / mean 1000, end 2000, σ 0, remote 0.25 | 29,219 | 29,219 |
| same, σ 100 | 29,318 | 29,318 |
| same, σ 2000 | 29,338 | 29,338 |
| 1024 LPs, 15 start, lookahead 10 / mean 200, end 2000, σ 0, remote 0.25 | 152,687 | 152,687 |
| same, σ 100 | 153,714 | 153,714 |
| same, σ 2000 | 153,741 | 153,741 |

The Charades `phases` test config (alt-phase parameters) is not implemented in phold-gauss.

**2. Inside ROSS: all schedulers commit the same number of events.**
- Command: `runs/verify_ross.sh` (env `LA`, `MEAN`, `END`).
- Common flags: `--num-lps=1024 --start-events=15 --end=2000 --extramem=200000`.
- Columns:
  - `--synch=1` is sequential;
  - `--synch=6` is ROSS's rollback check: it runs forward, then reverse-executes every event;
  - `--synch=2` is conservative with 2 ranks;
  - `--synch=3` is optimistic, with 2 and 4 ranks (`mpirun -np N`, Open MPI 5.0.8);
  - the last column is optimistic with 4 ranks and `--batch=4 --gvt-interval=256 --nkp=4`, to force rollbacks.

Net (committed) events (count); the number in parentheses is events rolled back:

| lookahead / mean | σ | seq | rollback check | cons. 2 | opt. 2 | opt. 4 | opt. 4, aggressive |
|---|---|---|---|---|---|---|---|
| 100 / 1000 | 0, remote 0.25 | 29,219 | 29,219 | 29,219 | 29,219 (0) | 29,219 (0) | 29,219 (202) |
| 100 / 1000 | 100 | 29,318 | 29,318 | 29,318 | 29,318 (0) | 29,318 (0) | 29,318 (0) |
| 100 / 1000 | 2000 | 29,338 | 29,338 | 29,338 | 29,338 (0) | 29,338 (0) | 29,338 (2,535) |
| 10 / 200 | 0, remote 0.25 | 152,687 | 152,687 | 152,687 | 152,687 (425) | 152,687 (1,041) | 152,687 (1,489) |
| 10 / 200 | 100 | 153,714 | 153,714 | 153,714 | 153,714 (0) | 153,714 (388) | 153,714 (4,134) |
| 10 / 200 | 2000 | 153,741 | 153,741 | 153,741 | 153,741 (137) | 153,741 (196) | 153,741 (69,864) |

- Every column matches, including runs with up to 69,864 rolled-back events. The reverse handler is therefore correct for both σ paths.
- Also: the Charades Gaussian config gives 16,389 under `--synch=6` and under optimistic with 2 ranks (522 rolled back).
- Timings on the Mac are meaningless (runs take milliseconds), so none are reported.

### Devastator reproduces Charades (2026-10-21, Mac)

Setup: 1024 LPs, 15 start events, end time 2000. Builds: threads world with 2 and 4 ranks (Apple clang), GASNet smp with 2 processes × 1 worker (gcc-15). Every row exited 0. Source: `runs/devastator-phold-gauss-mac.out` (`runs/deva_pg_check.sh <binary>`).

Committed events (count). The Charades/ROSS column comes from Part A; the clcg4 column must equal it:

| lookahead / mean | σ (LP ids) | Charades = ROSS | Devastator clcg4, all 3 layouts | Devastator xorshift, all 3 layouts | xorshift vs. Charades |
|---|---|---|---|---|---|
| 100 / 1000 | 0 (remote 0.25) | 29,219 | 29,219 | 29,195 | −0.08% |
| 100 / 1000 | 100 | 29,318 | 29,318 | 29,475 | +0.54% |
| 100 / 1000 | 2000 | 29,338 | 29,338 | 29,377 | +0.13% |
| 10 / 200 | 0 (remote 0.25) | 152,687 | 152,687 | 153,816 | +0.74% |
| 10 / 200 | 100 | 153,714 | 153,714 | 153,246 | −0.30% |
| 10 / 200 | 2000 | 153,741 | 153,741 | 153,238 | −0.33% |

- **Exact cross-engine match:** with `--rng=clcg4` Devastator commits exactly Charades' and ROSS's counts in all 6 configs and all 3 layouts. Up to 34,095 events were rolled back (smp, 10/200, σ = 2000). So the workload semantics (delay, σ, wrapping, end time, initial events) are identical, and state-saving rollback is correct.
- **Devastator's own RNG** (the timed configuration) lands within 0.74% of Charades' counts, as expected from a different random stream.
- **Determinism: yes, committed counts are layout-independent.** For a fixed RNG and seed, the count is the same for threads 2 ranks, threads 4 ranks and GASNet smp 2 processes, and the same on repeated runs; only executed and rolled-back counts vary.
  - Larger check: 16,384 LPs, 15 start, lookahead 10 / mean 200, σ = 100, end 5000, xorshift. Committed = 6,145,777 in every run: threads 2 ranks (0 rolled back), threads 4 ranks ×3 runs (5,228 / 1,592 / 48,206 rolled back), smp 2 procs (579). With static windows 20 and 200 (4 ranks): also 6,145,777.
  - So the count depends only on the total LP count: 1024 LPs → 29,338 and 1536 LPs → 44,196 at σ = 2000 (clcg4). `smoke_conduits.sh` uses these as exact checks on the cluster.
  - The engine's `deterministic` flag prints **0** anyway. It flags commits with equal (time, subtime), and those happen here: root events get subtime = local LP index, timestamps are integers, and 15 roots per LP collide. Tied events at one LP are interchangeable in PHOLD (same LP, same RNG stream, anonymous events), so counts are unaffected.
- The adaptive window runs away on these small runs: efficiency stays > 0.95, so look_dt doubles every GVT epoch up to the 2⁵⁸ clamp. Devastator is then effectively unbounded-optimistic. Expect that on Stampede3 too, unless rollbacks push efficiency below 0.95.
- Exit: the 4-rank threads binary exited 0 in all 20+ runs this time. The SIGABRT at exit from Part B did not reproduce.
- `world=threads ranks=1` does not compile (`signal_slots<unsigned,1>` alignment error), so there is no 1-rank sequential reference. Use the clcg4 counts above instead.
- Mac timings are meaningless (milliseconds, shared machine) and are not reported.

### ROSS optimistic abort, reproduced on the Mac (2026-10-21; Open MPI 5.0.8, 4 ranks, 1,024 LPs; expected 983,216 committed events)

- **Stock ROSS never fails**, over tcp or shared memory, under aggressive `--batch`, `--gvt-interval` and `--nkp`, or with `--read-buffer` 1 and 2.
- **A PMPI shim that forces MPI-legal reorderings reproduces the exact abort**:
  - `LAG_P` delays a completion with probability p;
  - `LAG_REVERSE` returns completed indices in descending order.
- **Results:**
  - Stock with `LAG_REVERSE=1`, or with `LAG_P=0.5`: aborts.
  - Patched: 983,216 committed events; 27–1,079 anti-messages held (count).
  - Stock with `--read-buffer=1`: 983,216.

## Earlier

Superseded or historical sections, in the order they were written. Their numbers came from an older stack, launch or setting, or a later section replaced them; each says which.

### §14 · External baselines, Mac feasibility (2026-10-21; details in `~/pdes-baselines/NOTES.md`)

> **Status: historical.** Build feasibility; the Mac verification counts are in "Baseline verification on the Mac" below.

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

### §16 · ROSS on Stampede3, first runs (same job)

> **Status: historical.** ROSS has not been rerun since. Its own numbers stand; the Charades numbers beside it are from the Debug runtime.

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
