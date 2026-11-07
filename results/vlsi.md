# VLSI (b19 × N)

Gate-level simulation of copies of ITC'99's b19: the model and its layout, the gap to Devastator and how it closed, commits, and the paper's VLSI row. Part of the Charades results: the current paper tables are on the front page, [../RESULTS.md](../RESULTS.md), and every section's date, job, status and file is in [INDEX.md](INDEX.md). Sections keep the numbers (§N) they had in the single RESULTS.md they came from (split 2026-11-07); "section N" anywhere means §N.

| § | date | status | section |
|---|---|---|---|
| 190 | 2026-11-02 | design | A VLSI workload: gate-level simulation of b19 × N, copies of ITC'99's largest circuit joined in a ring; the… |
| 191 | 2026-11-02 | design (results in 192) | VLSI calibration at 1 and 4 nodes in three engines: window, layout, aggregation, LPs per chare |
| 192 | 2026-11-02 | current | V0 results: one count in every engine, but the file-order layout puts 9.8× the mean load on one PE, so ever… |
| 193 | 2026-11-02 | design | A balanced VLSI layout: chunks of 512 nets placed by pre-simulated activity (busiest PE 1.04× the mean, est… |
| 195 | 2026-11-02 | current | V1 results: on the balanced layout Devastator is 2.0× Charades at 1 node and 1.3× at 4 nodes; Charades adva… |
| 196 | 2026-11-02 | design | Why Charades trails on VLSI: per-hop latency against GVT pace |
| 197 | 2026-11-02 | current | V2 results: GVT rounds take 5–6% of each cycle, so GVT pace is ruled out; each cycle's own execution takes… |
| 198 | 2026-11-03 | design | Why a Charades clock cycle takes 1.8× Devastator's at the same window |
| 199 | 2026-11-03 | current | V3 results: sends between the node's two processes cost each sending PE 2 µs and stall the heaviest senders… |
| 200 | 2026-11-03 | design | One process per node against shared memory between the node's processes, in both engines; each copy's activity |
| 201 | 2026-11-03 | current | Builds, the shared-memory pool starved by Charades' message pool (fixed), and each copy's activity: one cop… |
| 202 | 2026-11-03 | current | V4 results: one process per node is Charades' best VLSI layout (1.33× / 1.27×; 1.47× with W 5,000 at 1 node… |
| 206 | 2026-11-03 | design | Round 1's settings at 1 and 4 nodes in both engines, and lazy fossils on the other six workloads |
| 207 | 2026-11-03 | design | Where a VLSI clock cycle's wall time goes: an event-level trace of Charades at 1 × 46 |
| 208 | 2026-11-03 | current | V5 results: Charades equals Devastator at 4 nodes (1.00) and is 0.85 of it at 1 node; one process per node… |
| 209 | 2026-11-03 | current | Devastator's 1 × 46 hang was PSM2 pinning every thread to core 0; at the same layout the engines are level… |
| 212 | 2026-11-03 | design | VLSI at 1–32 nodes in three engines, each at its best launch |
| 214 | 2026-11-03 | current (1–16) | VS results at 1–16 nodes: Charades ÷ Devastator 0.84 / 0.91 / 0.99 / 0.97 / 0.89; one count per cell; from… |
| 226 | 2026-11-04 | current | VS2 at 32 nodes (big2): Charades ÷ Devastator on VLSI falls to 1.05 (per rep 0.96–1.07); from 16 to 32 node… |
| 228 | 2026-11-05 | current | Why VLSI's lead shrinks at 32 nodes, from data already taken: two thirds of the cycle's growth is slow coun… |
| 233 | 2026-11-05 | design (results in 234) | Where Charades' cost of running ahead goes on VLSI: each PE's time at W 2,500 / 3,750 / 5,000, and three sw… |
| 234 | 2026-11-05 | current | RA results: the cost of running ahead on VLSI was the lazy commit rule; with eager commits W 5,000 runs at… |
| 235 | 2026-11-05 | design (results in 236) | VLSI's commit setting and its controller row: lazy commits that cannot pile up, eager commits, and the cont… |
| 236 | 2026-11-06 | current | VC results: eager commits at W 5,000 are VLSI's best setting at 1, 2 and 16 nodes and within 3–5% of it at… |
| 238 | 2026-11-06 | design (results in 239) | The paper's VLSI row with VLSI's new setting: eager commits at W 5,000, the widened controller and Devastat… |
| 239 | 2026-11-06 | current | VS3 results: with eager commits at W 5,000 Charades ÷ Devastator on VLSI is 1.51 / 1.40 / 1.26 / 1.30 / 1.2… |
| 216 | 2026-11-03 | design (results in 217, 226) | VLSI at 1–32 nodes with round 3, a cycle-time trace per node count, and one process against two per node on… |
| 217 | 2026-11-03 | superseded | VS2 results at 1–16 nodes: with round 3 Charades ÷ Devastator is 1.37 / 1.27 / 1.23 / 1.29 / 1.19; the coun… |
| 229 | 2026-11-05 | superseded by 233 (not run) | A VLSI window between one and two clock periods: its steady cost at 4–16 nodes |

## Current

Current findings, and designs with their results, in the order they were written.

### §190 · A VLSI workload: gate-level simulation of b19 × N, copies of ITC'99's largest circuit joined in a ring; the model, and checks on the Mac (2026-11-02; design, written before any Stampede3 runs)

> **Status: design (model and both ports built and checked on the Mac).** The user's advisor asked for a VLSI application; the user chose gate-level simulation (2026-11-02) and b19 × N as the workload. Model in `models/vlsi` (main, this commit). Measurement scripts in the session scratchpad (`activity.py`, `composed.py`).

**Prior work and why not reuse it.** Gonsiorowski, Carothers and Tropper simulated a gate-level model built from OpenSPARC T2 on ROSS (about 6 M LPs, up to 1 billion gates, 130× on 1,024 Blue Gene/L processors). Their model (`github.com/gonsie/gates`) has no licence file, its netlist converter is not in the repository, and its timestamps are floating-point with random jitter, which cannot give equal committed events in three engines. McGill's XTW/DVS (Tropper's group, 5–25 M gates) appears unreleased. So Charades gets its own model, following the same design (one LP per gate, cell-type logic and delays, clocked flip-flops).

**The circuit.** ITC'99 (Politecnico di Torino, EUPL-1.2, `github.com/cad-polito-it/I99T`; not copied into this repository):
- b14 is a subset of the Viper processor, b15 of the 80386. b17 is 3 × b15 joined through data registers, b18 is 2 × b14 + 2 × b17 joined on their datapaths, b19 is 2 × b18 joined on their data buses.
- b19's `.bench` form: 231,266 nets, 6,642 flip-flops, six gate types (NAND, NOT, AND, OR, NOR, DFF; fan-in ≤ 5, fanout ≤ 92). Its inputs are 3 control lines, a 10-bit and an 8-bit bus (IN1, IN2) and 3 constant-zero pseudo-inputs; its 27 distinct outputs are a subtractor's.

**How much work b19 holds** (unit-delay simulation, random inputs each cycle; `activity.py` held the three constants random, which raised activity, so the second row is the one that counts):

| run | gates changing per cycle | messages per cycle | depth (unit delays) |
|---|---|---|---|
| b19, constants random (wrong) | 2.6% | 14,875 | 33 |
| b19 × 4, constants 0, per copy | 1.2% | about 8,000 | 25 |

At 32 nodes (1,472 PEs) b19 alone gives 157 gates and about 10 messages per PE per cycle, and fewer than one change per PE in the busiest gate delay: not enough work. Weak scaling keeps each PE near b19-on-1-node (about 5,000 gates, 170 messages per cycle), 7.4 M gates at 32 nodes and 59 M at 256.

**b19 × N.** N copies joined in a ring, as ITC'99 builds its larger circuits:
- copy k's bus inputs become XOR gates of a random external input and a ring flip-flop that samples one of copy k−1's outputs at each clock edge. The flip-flop keeps the ring free of combinational paths between copies;
- the other inputs take a new value at each clock edge, from a hash of (seed, copy, net, cycle), so they carry no random state through rollbacks and do not depend on the layout;
- per copy: 231,326 nets, 224,642 gates, 6,660 flip-flops (18 of them the ring's), 21 random inputs.

**Timing.** Integer ps. A linear delay model, since ITC'99 carries no timing: an intrinsic delay by type (NOT and BUFF 6, NAND 8, NOR 10, AND 12, OR 14, XOR 16), plus 2 ps per input beyond two and 2 ps per fanout up to eight. Flip-flops change 20 ps after the edge, inputs 10 ps after. b19's longest path is 1,934 ps, and the clock period defaults to the longest path plus 25%, rounded up to 100 ps: 2,500 ps.

**Events, and why equal timestamps cannot change the result.**
- A pin change (`PinMsg`) arrives at an even time. A combinational gate's first pin change at time t schedules one evaluation (`EvalMsg`) at t + 1, which sees every pin change of time t. Every delay is even and the output is sent delay − 1 after the evaluation, so pin changes stay at even times and evaluations at odd ones.
- A flip-flop records its D pin and takes it at the clock edge (`ClockMsg`, multiples of the period). Since the period exceeds the longest path, no pin change reaches it at an edge.
- So no two events whose order matters share a timestamp at a gate. The model does not rely on the tie order that traffic and dragonfly needed reproduced in ROSS and Devastator.

**Layout (`--span=s`).** With one copy per node, span s spreads each copy over s nodes: node i of a group of s holds the i-th slice (file order) of each of the group's s copies. Each PE keeps one copy's worth of nets. The layout changes no committed event. Where messages go, b19 × 4 on 4 nodes (2 processes × 23 PEs each; `composed.py`):

| layout | messages per PE per cycle | crossing PEs | crossing processes | crossing nodes |
|---|---|---|---|---|
| each copy on 1 node | 174 | 41% | 7.4% | 0.2% |
| each copy over 2 nodes | 174 | 41% | 7.4% | 7.3% |
| each copy over 4 nodes | 174 | 45% | 12% | 12% |

The two ends are the two cases of the advisor's note: a loosely coupled split (each copy on its own node, as in chiplet co-simulation) and a cut through the circuit.

**Padding.** Charades' block mapper needs the LP count to be a multiple of the LPs per chare, so the model adds inert LPs at the end (68 for b19 × 2 at 128 per chare). The commit digest covers every LP, so digests compare only at the same LPs per chare.

**Checks on the Mac (main, this commit):**
- `test.py --tier change --model VLSI`, five engine configs (bucketed window, deadline PP and WPs, the measured controller with and without htram) × `base` (3 copies of `tiny.bench`, our own 25-gate test circuit) and `span` (4 copies, span 2) × shapes 1, 4 and 2 × 2: 30/30, with up to 9,534 events rolled back.
- **b19 × 2, 40 cycles (1,866,314 committed events):**
  - the sequential run and optimistic runs at 2 processes × 4 PEs (bucketed window, deadline PP, the controller), at 1, 128 and 1,024 LPs per chare, all commit the same events;
  - at each padding, one digest across all runs (87749955…, a74454b9…, ace31535…), with 14,719–96,759 events rolled back;
  - one LP per chare runs 462,652 chares and reaches 0.02 M ev/s; 128 per chare 2.7–2.8 M ev/s (the Mac's rates are not comparable with Stampede3's).

**Ports (2026-11-02, Mac; `~/pdes-baselines/ross-vlsi.patch`, `devastator-vlsi.patch`).** Both compile Charades' own `netlist.C`, so the circuit, layout and gids are the same in all three engines. Neither needs a tie order: equal-timestamp events at a gate commute by construction.
- **ROSS** (`models/vlsi`, C++, `-DVLSI_NETLIST_DIR`; uneven gid blocks per rank): sequential and optimistic (3–4 ranks, `--read-buffer=1`) give 15,489, 40,905 and 1,866,314 committed events on `base`, `span` and b19 × 2, equal to Charades, with equal gate and pin counts.
- **Devastator** (`bench/vlsi.cxx`, threads world, 2 and 4 ranks, adaptive window and W 5,000 ps): the same counts and statistics, every run flagged deterministic.
- **A Mac-only build issue:** with Devastator's own `operator new`, libc++'s out-of-line string code allocates with libc++'s allocator and the bench frees with Devastator's, so the Mac binaries crash in `operator delete`. Mac checks use `opnew=libc`. Linux resolves the replacement process-wide; the calibration job's first runs confirm it with Devastator's own allocator.

**Next:**
1. Stampede3: a separate worktree for the VLSI model (so F5b's `charades-phaseb` binaries stay untouched), ROSS reconfigured with `VLSI_NETLIST_DIR`, Devastator's VLSI binaries for 1–32 nodes with Charades' `models/vlsi` on the include path; I99T cloned to `$WORK`.
2. A calibration job on Stampede3 (1 and 4 nodes, span 1 and 4, LPs per chare, W grid, the controller, direct sends), like section 186's.
3. b19 × N at 1–32 nodes, then 64–256 (the user's goal once 32 is solid), which needs Devastator builds beyond 32 nodes.
4. ROSS batch 2 / GVT interval 256 on dragonfly (section 189) joins the calibration job as one extra arm.

### §191 · VLSI calibration at 1 and 4 nodes in three engines: window, layout, aggregation, LPs per chare (job V0 design, 2026-11-02; written before any runs)

> **Status: design.** PAPER.md work item 3 (applications; VLSI added 2026-11-02, user decision).
> - **Job V0:** `$WORK/charades-runs/vcal191.slurm` (copy in `~/charades-data/vlsi/`), 6 nodes; submitted 2026-11-02 as 3674282 (skx-dev) and 3674283 (skx), the later starter to be cancelled.
> - **Trees:** Charades `charades-vlsi` (main e5e4976 + `ctl_sweep.sh`'s vlsi workload), built on the login node; ROSS `models/vlsi` (`-DVLSI_NETLIST_DIR`); Devastator's vlsi binaries built in the job; I99T cloned to `$WORK/I99T`. F5b keeps `charades-phaseb` untouched.

**Why.** Section 190's model has run only on the Mac. Before the 1–32-node runs, each engine's settings need choosing, as section 186 did for traffic and dragonfly, and three questions about the model need answers: which window suits a clocked circuit, whether a copy spread over nodes (span 4) scales worse than one per node, and whether aggregation helps when most messages stay in the process.

**Runs** (b19 × N, one copy per node, 5,000 clock cycles = 12,500,000 ps; 1-node and 4-node series side by side; 2 reps, rep 2 reversed; caps 300 s):
- **Node 0** (the batch host), after the gate: Devastator's vlsi binaries for 1–32 nodes (ofi-psm2, 2 × 23 per node), with Charades' `models/vlsi` on the include path and Devastator's own allocator. Devastator's runs wait for it.
- **Charades** (`--localalloc`, `--blocked-time=1`, `--commit-digest=1`):
  - span 1, PP 2,048, buckets of 500 ps, 128 LPs per chare: W 1,250, 2,500, 5,000, 10,000 and 20,000 ps (half a cycle to 8 cycles) and the frozen controller;
  - at W 5,000: WPs 512, direct sends, 512 LPs per chare, buckets of 2,500 ps;
  - 4 nodes, span 4: W 2,500, 5,000, 10,000, the controller, and direct sends at W 5,000.
- **Devastator:** span 1, W 1,250 to 20,000 and its adaptive window; span 4, W 2,500 to 10,000.
- **ROSS:** span 1, batch 2, 8 and 32 with GVT interval 64; span 4, batch 8. Conservative ROSS is left out: the lookahead is 1 ps (the evaluation step), so every GVT epoch would advance 1 ps.
- **ROSS on dragonfly** (section 189's open edge): batch 2 with GVT interval 64 and 256, half the F5 size.
- **Gate:** the VLSI change tier (five engine configs) on 2 nodes.

**Predictions:**
- **V1. Counts.** In each node count and span, all three engines commit one count, and Charades one digest per LPs-per-chare setting. Devastator runs with its own allocator on Linux.
- **V2. The window.** Charades' best fixed W at span 1 is 2,500 or 5,000 ps (one or two cycles). W 1,250 is lower, since a window shorter than a cycle stops PEs at every clock edge, and W 20,000 is at least 10% below the best.
- **V3.** The frozen controller reaches at least 0.93 of the best fixed W at span 1 at both node counts.
- **V4. Aggregation.** At span 1, best htram ÷ direct is at least 1.2 at both node counts: 41% of messages cross PEs, almost all in the process, the same-process path that gave traffic 1.36× (section 187).
- **V5. Layout.** At 4 nodes, Charades' best at span 4 is at most 0.8 of its best at span 1 (12% of messages cross nodes against 0.2%).
- **V6.** 512 LPs per chare and buckets of 2,500 ps are each within ±10% of 128 and 500.
- **V7. Engines at span 1:** Charades ÷ Devastator 1.0–1.3 at both node counts, as on traffic; Charades ÷ ROSS at least 2. At span 4, Charades ÷ Devastator at least 1.2, as dragonfly's cross-node scaling suggests.
- **V8.** Charades runs b19 at 1 node at 20 M committed ev/s or more.
- **V9.** ROSS on dragonfly: GVT interval 256 at batch 2 is at most 1.0× of 64, so batch 2 / 64 stays ROSS's best.

**What follows:** the arms of the 1–32-node VLSI runs (a job shaped like F5a and F5b), set by these results in the way section 186 set F5's.

### §192 · V0 results: one count in every engine, but the file-order layout puts 9.8× the mean load on one PE, so every engine's VLSI rate is one PE's per-event cost; the layout must be balanced before any VLSI scaling run (2026-11-02; skx-dev batch job 3674282, 6 nodes)

> **Status: current.** Design and predictions in section 191. 47 minutes (skx copy 3674283 cancelled). Gate 30/30. Charades 56 runs and Devastator 30 runs all finished; ROSS 3 of 12 VLSI runs hit the 300 s cap. Summary `~/charades-data/vlsi/vcal_summary.py`; load estimates `imbalance.py`, `imbalance2.py`, `imbalance3.py` (same directory); data `~/charades-data/vlsi/j3674282/` (per-LP digest files left on `$WORK`).

**Rates** (b19 × N, one copy per node, 5,000 cycles; M committed ev/s, median of 2 reps, higher is better; Charades PP 2,048, buckets of 500 ps, 128 LPs per chare):

| W (ps) | Charades, 1 node | Devastator, 1 node | Charades, 4 nodes span 1 | Devastator, 4 nodes span 1 | Charades, 4 nodes span 4 | Devastator, 4 nodes span 4 |
|---|---|---|---|---|---|---|
| 1,250 | 7.5 | 5.6 | 30.7 | 26.8 | — | — |
| 2,500 | **8.5** | 5.9 | **35.8** | 28.1 | **28.8** | 27.5 |
| 5,000 | 7.9 | 5.8 | 33.4 | 28.9 | 25.7 | 28.1 |
| 10,000 | 7.9 | 5.8 | 33.4 | 29.2 | 24.9 | **29.5** |
| 20,000 | 7.9 | **5.9** | 32.8 | **29.5** | — | — |
| Charades' controller / Devastator's adaptive window | 7.5 | 5.6 | 30.6 | 22.5 | 24.8 | — |
| Charades ÷ Devastator, each at its best fixed W | 1.44 | | 1.22 | | 0.97 | |
| Charades' controller ÷ Devastator's best fixed W | 1.27 | | 1.04 | | 0.84 | |

**Charades' variants at W 5,000** (M committed ev/s, higher is better): WPs 512 7.9 / 33.9; direct sends 7.8 / 33.0 / 24.4 (1 node / 4 nodes span 1 / 4 nodes span 4); 512 LPs per chare 7.7 / 27.4; buckets of 2,500 ps 7.9 / 33.5. Best htram ÷ direct sends: 1.01, 1.03, 1.05.

**ROSS** (no optimism window; M committed ev/s, higher is better): batch 8 is its best, 1.6 at 1 node and 2.2 at 4 nodes; batch 2 1.2 and batch 32 0.4 at 1 node; batch 2 and 32 at 4 nodes, and batch 8 at span 4, hit the 300 s cap (below 1.9). ROSS rolls back 1.4–5.5 events per committed event (its efficiency −36% to −454%). Charades ÷ ROSS is 5.3 (1 node) and 16.2 (4 nodes), but **these are not ROSS's best**: ROSS has a fixed optimism window (`--max-opt-lookahead`, `~/pdes-baselines/NOTES.md`) that V0 did not use. Without it, the PEs with little work run far ahead and are rolled back.

**ROSS on dragonfly (V9)** (M committed ev/s, higher is better): batch 2 with GVT interval 64 runs 10.1 (1 node) and 28.5 (4 nodes), with GVT interval 256 8.5 and 18.2. 256 ÷ 64 is 0.84 and 0.64, so batch 2 / 64 stays ROSS's best.

**Why every engine is slow, and flat in W: one PE holds the flip-flops.**
- Charades is blocked at the window 67–70% of the time (mean over PEs) at every W, even 20,000 ps (8 cycles). Per PE the share ranges from 0.0% to 99.8–99.9% in every run. GVT advances once per clock cycle (5,000–5,008 updates per run).
- **Cause** (offline, `imbalance.py`: b19 × 1, unit-delay, 200 cycles, file-order blocks over one node's 46 PEs):
  - The estimate is 23,693 events per cycle; the run measured 25,200 (126.0 M over 5,000 cycles).
  - b19's `.bench` lists all 6,642 flip-flops first (lines 69–6,710), and every flip-flop takes a clock event each cycle (28% of all events).
  - So PE 0 holds 5,005 flip-flops and does 9.83× the mean load, 99% of it clock events. The next PEs carry 3.76× and 3.72× (NAND/AND datapath regions).
- **Closure.** If PE 0 sets the pace it executes 9.83 / 46 = 21% of all events: 1.8 M ev/s at Charades' 8.5, about 0.55 µs per event, and 1.3 M ev/s at Devastator's 5.9, about 0.79 µs per event. Both are plausible single-PE rates.
- So V0's 1-node Charades ÷ Devastator of 1.44 compares one PE's per-event cost (mostly clock events), not parallel execution. W changes little because nothing else limits the rate.

**Layouts** (offline, one node, 46 PEs; lower is better in both columns):

| layout | busiest PE's load ÷ mean | messages crossing PEs (%) | engines' LP mapping |
|---|---|---|---|
| file-order blocks (V0) | 9.83 | 36.6 | unchanged |
| contiguous, cut at equal static weight (clock + fan-in + fanout) | 4.79 | 40.3 | uneven blocks |
| chunks of 128 nets dealt round-robin | 1.81 | 71.3 | unchanged |
| contiguous, cut at equal measured activity | 1.01 | 59.2 | uneven blocks |
| chunks of 512 nets, heaviest first to the least-loaded PE, equal counts | 1.03 | 65.5 | unchanged |
| chunks of 128 nets, the same | 1.00 | 70.5 | unchanged |
| random per net | 1.14 | 98.0 | unchanged |

The equal-count chunk layouts only reorder gids inside `netlist.C`, which all three engines compile, so every engine's block mapping still applies. The weights come from a short deterministic pre-simulation of one copy (the estimate above), so the layout depends only on the circuit and the seed. The estimate balances load summed over cycles, not within each cycle.

**Charades' controller stays at W 500 ps** (one bucket) at every node count and span, which is 0.85–0.90 of the best fixed W. That is below its 0.91–1.03 on the seven earlier workloads. Its rule sets W from the delays of remote sends (ts − the sender's time). Here every such delay is under 32 ps (a gate's delay), all inside the first 500 ps bucket, so the rule gives its smallest W. Whether this still costs 10–15% once the load is balanced is open.

**Predictions (section 191):**
- **V1 right.**
  - One count per cell in all three engines: 125,998,590 at 1 node, 574,541,914 at 4 nodes (both spans).
  - Charades gives one digest per padding. At 1 node 128 and 512 LPs per chare both pad to 231,424 LPs and give one digest; at 4 nodes 925,312 and 925,696 LPs give two.
  - Devastator built and ran with its own allocator on Linux, deterministic in all 30 runs.
- **V2 partly right.** The best fixed W is 2,500 (one cycle) at both node counts, and W 1,250 is lower (0.86–0.89). W 20,000 is only 6–9% below the best, not 10% or more.
- **V3 wrong.** The controller reaches 0.87–0.90 of the best fixed W at 1 node and 0.85–0.86 at 4 nodes, not 0.93.
- **V4 wrong.** Best htram ÷ direct is 1.01–1.05, not ≥ 1.2. It was measured only at W 5,000, and the busiest PE's event cost, which direct sends do not change, limits the rate.
- **V5 right, at the bound.** 0.80. Devastator loses nothing from span 1 to span 4 (29.5 at both).
- **V6 partly right.** Buckets of 2,500 ps: 1.00 at both node counts. 512 LPs per chare: 0.97 at 1 node, but 0.82 at 4 nodes (not explained).
- **V7 partly right.** At span 1, Charades ÷ Devastator is 1.44 (1 node, above the range) and 1.22 (4 nodes, in range); Charades ÷ ROSS ≥ 2 holds, but against an untuned ROSS. At span 4 the ratio is 0.97, not ≥ 1.2.
- **V8 wrong.** 8.5 M ev/s, not 20; the busiest PE limits the rate.
- **V9 right.** 0.84 and 0.64.

**Consequences.** V2–V8 measured the imbalanced layout. The engine ratios and the controller, aggregation and span results need repeating before they mean anything for the paper.
1. A balanced layout in `netlist.C` before any VLSI scaling run. Chunks of 512 nets, assigned by pre-simulated activity at equal counts, keep every engine's mapping. File order stays as an option for reference.
2. ROSS gets `--max-opt-lookahead` arms (2,500, 5,000 and 10,000 ps). F5's ROSS grids on traffic and dragonfly had no window arm either (dragonfly efficiency 57–70%); to add when ROSS runs next.
3. A shortened V0 on the balanced layout (W grid, controller, direct sends, span 1 and 4, Devastator, ROSS with windows), with new predictions, then the 1–32-node VLSI job.

### §193 · A balanced VLSI layout: chunks of 512 nets placed by pre-simulated activity (busiest PE 1.04× the mean, estimated), the same in all three engines; Mac checks; calibration job V1 (2026-11-02; design, written before any runs)

> **Status: design (layout built and checked on the Mac; V1 not yet run).** User decision 2026-11-02: the chunk layout (section 192's recommendation). **Job V1** submitted 2026-11-02 as 3675179 (skx-dev) and 3675180 (skx).
> - **First attempt failed its gate** (3675179, 3 min 44 s): 44/45. `base` × `agg_deadline_bucket_wps` on 1 PE aborted on a Charades `TW_ASSERT` after 75 s, against 0.5 s for a normal run. The assertion's text was lost: `CkAbort` does not flush stdout, so with stdout piped only `Reason: Assertion Failure` remained. The core dump stayed on c454-043.
> - **Debugged interactively** (idev 3675269, c455-072): 1,210 reruns, all clean. 730 were that case: 20 under `test.py`, 300 run directly with line-buffered output, and 400 as 40 concurrent copies. The rest were the whole gate 10 times (450/450). A 3× oversubscription of the node failed only on memory, since each process's LCI reserves 4 GB; it was discarded. Not reproduced, so its cause is open.
> - **Fix for the next occurrence:** `TW_ASSERT` now flushes stdout before aborting (90e9922; checked on the Mac with stdout piped), so a recurrence leaves its message. `charades-vlsi` was rebuilt at 90e9922.
> - **Resubmitted unchanged otherwise** as 3675299 (skx-dev) and 3675300 (skx), the later starter to be cancelled. Charades main 017e722; ports `~/pdes-baselines/ross-vlsi.patch` and `devastator-vlsi.patch` regenerated. Offline estimates `~/charades-data/vlsi/imbalance*.py` and the session scratchpad's `layout/check.C` and `layout/cross.C`.

**The layout** (`--chunk=c`, default 512; `--chunk=0` keeps file order; `netlist.C`, which all three engines compile):
- **Profile.** A unit-delay simulation of one copy (ring flip-flops sampling its own outputs; inputs from a fixed hash, not `--input-seed`), 50 warm-up and 200 counted cycles. Each net's estimate is its clock events plus pin changes received plus evaluations, in integers, so the layout is the same in every engine and depends only on the circuit. It takes 36 ms for b19.
- **Placement.** Copies come in groups of `--span`. Each copy is cut into chunks of c nets in file order. The group's gids form `bins` equal bins of whole chunk slots, with slots per bin = ⌈chunks per group ÷ bins⌉. Chunks go, heaviest first (ties in file order), to the least-loaded bin with a free slot (ties: the lowest bin). Within a bin they keep file order, and unused slots and the tail of a copy's last chunk are inert LPs.
- **Bins per group** default to PEs (ranks) × span ÷ copies, and `--layout-bins` overrides it. With one bin per PE, an engine that maps gids to PEs in even blocks gives each PE exactly one bin. Charades does (128 LPs per chare, 5,120 LPs per bin, no remainder), and so do the ROSS and Devastator ports (uneven blocks with a remainder of 0). All three run 46 PEs or ranks per node, so all three put the same nets on each PE.
- **Span s > 1:** a copy's chunks spread over every bin of its group of s nodes, with no regard to locality. This is a load-balanced cut without locality, the most communication-heavy case. File order (`--chunk=0`) keeps section 190's slices.

**Estimates** (b19 × 4 on 4 nodes, 2 × 23 PEs each, even gid blocks; from the profile; lower is better in every column):

| layout | busiest PE ÷ mean load | inert LPs (%) | messages crossing PEs (%) | crossing processes (%) | crossing nodes (%) |
|---|---|---|---|---|---|
| file order, span 1 | 9.93 | 0 | 36.6 | 6.8 | 0.6 |
| file order, span 4 | — | 0 | 37.2 | 10.1 | 10.1 |
| chunks of 512, span 1 | 1.04 | 1.8 | 65.9 | 29.1 | 0.0 |
| chunks of 512, span 2 | 1.04 | 1.8 | 65.9 | 45.5 | 29.1 |
| chunks of 512, span 4 | 1.04 | 1.8 | 65.9 | 58.2 | 45.5 |
| chunks of 128, span 1 | 1.00 | 1.8 | 70.6 | 34.8 | 0.0 |

Each PE receives about 186 messages per cycle in every layout. Chunks of 512 stay balanced at 1, 2, 4 and 32 copies. The C++ profile agrees with section 192's Python estimate (file order 9.93 against 9.83; chunks of 512 1.04 against 1.03).

**Checks on the Mac** (all on 017e722 and the regenerated ports):
- **The layout is a bijection.** `gid` and `locate` invert each other over every net of b19 × 1, 2, 4 and 32 at spans 1, 2 and 4 and of `tiny.bench`, and every other gid is inert.
- **`test.py --tier change --model VLSI`**: sequential plus five engine configs × `base` (chunks of 4), `span` (chunks of 4, span 2) and the new `file` (span 2, file order) × shapes 1, 4 and 2 × 2: 48/48.
- **b19 × 2, 40 cycles:** 1,866,314 committed events in every run.
  - Charades sequential, and optimistic at 2 processes × 2 PEs (deadline PP, the bucketed window without htram, and 1,024 LPs per chare), all at 2 bins per copy: one digest, 7f3a5cec…. In file order the digest is still a74454b9… (section 190).
  - ROSS sequential and at 4 ranks: 262,906 gate changes and 684,438 pin changes, equal to Charades.
  - Devastator at 2 and 4 ranks, adaptive and W 5,000: equal counts and statistics, every run deterministic.
  - `tiny.bench`: ROSS (3 and 4 ranks) and Devastator (2 and 4 ranks) commit 15,489 (`base`) and 40,905 (`span`), the test configs' counts.
- The layout, and so the digest, depends on the bin count: digests compare only at equal `--layout-bins` and LPs per chare.

**Stampede3:**
- `charades-vlsi` fast-forwarded to 017e722 and its model rebuilt on the login node.
- ROSS's `vlsi` target rebuilt. F5b's dragonfly and traffic binaries are untouched; F5b, 3673481, is running on `charades-phaseb`.
- Devastator's `bench/vlsi.cxx` copied; its binaries are rebuilt inside V1.

**Job V1** (`~/charades-data/vlsi/vcal193.slurm`; 6 nodes, laid out as V0's; 2 reps, rep 2 reversed; 5,000 cycles; caps 300 s, ROSS 240 s):
- **Gate:** the VLSI change tier (five engine configs × `base`, `span`, `file`) on 2 nodes.
- **Charades** (PP 2,048, buckets of 500 ps, 128 LPs per chare):
  - span 1: W 1,250, 2,500, 5,000, 10,000 and 20,000, and the frozen controller; direct sends at W 2,500 and 10,000; WPs 512 at W 2,500; file order at W 2,500 (V0's best, as a same-job reference);
  - 4 nodes, span 4: W 2,500, 5,000 and 10,000, the controller, and direct sends at W 2,500 and 10,000.
- **Devastator:** span 1 W 1,250 to 20,000 and its adaptive window; file order at W 10,000; span 4 W 2,500 to 10,000.
- **ROSS** (GVT interval 64): span 1 batch 8 with `--max-opt-lookahead` 2,500, 5,000 and 10,000 ps and without a window (rep 1 only); batch 2 and 32 at 5,000; span 4 batch 8 at 5,000.
- Left out, settled by V0: 512 LPs per chare, buckets of 2,500 ps, ROSS on dragonfly.

**Predictions:**
- **W1. Counts.** V0's counts in every cell and engine (125,998,590 at 1 node, 574,541,914 at 4), the file-order arms included; Charades gives one digest per layout.
- **W2. Balance.** Charades' blocked share at span 1 falls from 67–70% to at most 35% (mean over PEs), and the busiest PE (lowest blocked share) no longer sits at 0% while others sit at 99.9%: per-PE spread at most 40 points.
- **W3. Rate.** Charades' best fixed W at 1 node reaches at least 20 M ev/s (2.4× V0), and the same-job file-order arm is within 10% of V0's 8.5.
- **W4.** Devastator's best fixed W at 1 node is at least 2× V0's 5.9 M ev/s.
- **W5. The window.** Charades' best fixed W is 2,500 or 5,000; W 1,250 and W 20,000 are each at least 10% below it.
- **W6. The controller** still holds W at 500 ps (every remote delay is under 32 ps) and reaches 0.80–0.92 of the best fixed W.
- **W7. Aggregation at span 1:** best htram ÷ direct sends at the same W is at least 1.15 (66% of messages cross PEs, 29% cross processes).
- **W8. Span 4** (45% of messages cross nodes): Charades' best at span 4 is at most 0.6 of span 1; htram ÷ direct at least 1.5; Charades ÷ Devastator at least 1.2.
- **W9. ROSS:** a window lifts ROSS's best by at least 2× over its unwindowed batch 8, and Charades ÷ ROSS stays at least 2.
- **W10. Engines at span 1:** Charades ÷ Devastator, each at its best fixed W, 1.0–1.4 at both node counts.

**What follows:** the arms of the 1–32-node VLSI job (one copy per node at span 1, and span 4 if W8 shows it is a distinct case), set by these results.

### §195 · V1 results: on the balanced layout Devastator is 2.0× Charades at 1 node and 1.3× at 4 nodes; Charades advances GVT once per clock cycle and waits at the window 44–75% of the time at every W; htram loses to direct sends (2026-11-02; skx-dev batch job 3675299, 6 nodes)

> **Status: current.** Design and predictions in section 193 (W1–W10). 38 min 40 s (skx copy 3675300 cancelled). Gate 45/45. Devastator's vlsi binaries rebuilt for 1–32 nodes. Every Charades and Devastator run finished. ROSS's unwindowed batch 8 hit its 240 s cap at 1 node and ran out of event buffers at 4 nodes ("Out of events in GVT"). Summary `~/charades-data/vlsi/vcal193_summary.py` (output `j3675299_summary.txt`); data `~/charades-data/vlsi/j3675299/`.

**Rates** (b19 × N, one copy per node, 5,000 cycles; M committed ev/s, median of 2 reps, higher is better):

| engine and setting | 1 node | 4 nodes, span 1 | 4 nodes, span 4 |
|---|---|---|---|
| Charades, direct sends, W 2,500 (its best) | **22.9** | **61.9** | **48.9** |
| Charades, WPs 512, W 2,500 | 22.7 | 59.3 | — |
| Charades, PP 2,048, its best W | 19.3 (W 5,000) | 48.0 (W 2,500) | 33.9 (W 10,000) |
| Charades, controller (PP 2,048) | 15.4 | 42.1 | 30.3 |
| Charades, file order (PP 2,048, W 2,500) | 8.2 | 35.9 | — |
| Devastator, its best W | **45.0** (W 10,000) | **82.6** (W 2,500) | **88.2** (W 10,000) |
| Devastator, adaptive window | 27.0 | 44.3 | — |
| Devastator, file order (W 10,000) | 6.7 | 32.0 | — |
| ROSS, best (with `--max-opt-lookahead`) | 3.3 (batch 2, 5,000) | 7.8 (batch 8, 2,500) | 6.2 (batch 8, 5,000) |
| **Charades ÷ Devastator**, each at its best | 0.51 | 0.75 | 0.55 |
| Charades ÷ ROSS, each at its best | 6.9 | 7.9 | 7.9 |

- **The balanced layout** speeds Charades up 2.3× (1 node) and 1.3× (4 nodes) over file order at the same setting, and Devastator 6.7× and 2.6×. V0's Charades ÷ Devastator of 1.44 (section 192) compared one overloaded PE's per-event cost and does not carry over.
- **Charades' window** (PP 2,048, 1 node): W 1,250 15.8, W 2,500 19.1, W 5,000 19.3, W 10,000 15.1, W 20,000 12.8. Efficiency falls from 97–99% at W ≤ 2,500 to 80–84% at W 10,000 and 69% at W 20,000. Devastator's best W runs at 88% (1 node) and 99% (4 nodes).
- **Per-node rate at 4 nodes ÷ at 1** (span 1): Charades 0.68, Devastator 0.46, ROSS 0.59. Devastator loses more per node, as on dragonfly (section 194), but from a 2× lead.
- **Span 4 ÷ span 1 at 4 nodes:** Charades 0.79, Devastator 1.07.

**What limits Charades here** (measured facts; the cause is not yet established):
- **GVT advances once per clock cycle.** Every Charades run, at every W, mode, node count and span, makes 4,992–5,008 GVT updates for 5,000 cycles. The run time is 5,000 × the update interval: 1.1 ms at 1 node (903 updates/s, direct W 2,500), 1.85 ms at 4 nodes (540/s). Each update takes 2–4 count waves.
- **PEs wait at the window at every W.** Mean blocked share 63% at W 2,500 and still 49% at W 10,000 (1 node); 72–75% at 4 nodes. The least-blocked PE waits about 20% of the time, so no single PE holds the rest back (file order: 0%).
- **Aggregation adds to the cycle time.** PP 2,048 ÷ direct is 0.83 / 0.78 / 0.65 at W 2,500 (1 node / 4 nodes / span 4) and 0.67–0.74 at W 10,000. WPs 512 is 0.96–0.99 of direct.
- **Hypotheses, to be told apart by perturbation before any fix:**
  - **H1, the critical path within a cycle:** about 25 gate levels, with 66% of hops crossing PEs. Each cycle's work then waits on per-hop message latency, and speculation past it is rolled back (efficiency falls with W). Devastator's shared-memory queues deliver a message to another thread faster, and htram's buffering adds latency to each hop. Test: change Charades' per-hop latency (scheduler batch `--batch` 4 / 16 / 64) with the GVT settings fixed.
  - **H2, GVT pace:** the update interval itself sets the cycle time. Test: buckets of 2,500 ps (one per cycle) against 500, with the window fixed.

**Predictions (section 193):**
- **W1 right.**
  - One count per cell in all three engines (125,998,590 / 574,541,914), the file-order arms included.
  - Charades gives one digest per layout. Its file-order digests equal V0's (be287b9c…, d936d32a…).
  - Devastator is deterministic in every run.
- **W2 wrong.** The blocked share stayed 62–75% at W ≤ 2,500, not ≤ 35%. The per-PE spread narrowed from 0–99.9% to about 20–90%, still not within 40 points.
- **W3 right.** Charades' best is 22.9 M ev/s at 1 node (direct sends; PP 2,048 reaches 19.3). The file-order arm gives 8.2, 0.96 of V0's 8.5.
- **W4 right.** Devastator's best is 45.0 M ev/s, 7.6× V0's.
- **W5 right.** The best fixed W is 2,500 (direct; PP 2,500 and 5,000 within 1%). W 1,250 and W 20,000 are 0.69–0.82 and 0.56–0.66 of the best.
- **W6 right in the same mode.** The controller holds W at 500 ps and reaches 0.80 / 0.88 / 0.89 of PP 2,048's best fixed W. Against Charades' best arm overall (direct sends) it reaches 0.62–0.70.
- **W7 wrong.** htram ÷ direct is 0.78–0.99, not ≥ 1.15.
- **W8 wrong.** Span 4 ÷ span 1 is 0.79, not ≤ 0.6. htram ÷ direct at span 4 is 0.65–0.72, not ≥ 1.5. Charades ÷ Devastator at span 4 is 0.55, not ≥ 1.2.
- **W9 right.** With a window, ROSS's best is 3.3 / 7.8 M ev/s, 2.1× / 3.5× V0's unwindowed batch 8. Unwindowed batch 8 stalled or ran out of event buffers here. Charades ÷ ROSS is 6.9–7.9.
- **W10 wrong.** Charades ÷ Devastator is 0.51 and 0.75, not 1.0–1.4.

**Consequences:**
- **Claim 3's wording:** on VLSI at 1–4 nodes Charades trails Devastator by 1.3–2.0×. This is the first application where it does. Charades loses less per node (0.68 against 0.46 from 1 to 4 nodes), so the 1–32-node runs decide whether the order changes, as it did on dragonfly (0.94 → 2.03).
- **The controller (claim 2)** gets 0.62–0.70 of the best arm on VLSI. Its smallest W is one bucket, and every remote delay here falls inside one. Buckets of one clock period (2,500 ps) would make its smallest W the best fixed W; that needs measuring, as the H2 test does.
- **Aggregation (claim 1)** does not help on VLSI. PP loses up to 35%. That fits a workload limited by latency rather than by message count, if H1 holds.
- **Before the 1–32-node VLSI job:** a short diagnostic job at 1 and 4 nodes (the H1 and H2 tests, and the 2,500 ps buckets for the controller), with predictions written first. The user decides whether VLSI gets that engine time.

### §196 · Why Charades trails on VLSI: per-hop latency against GVT pace (job V2 design, 2026-11-02; written before any runs)

> **Status: design.** User decision 2026-11-02: run the short diagnostic job (section 195's proposal). Script `~/charades-data/vlsi/vdiag196.slurm`; Charades only, `charades-vlsi` 90e9922 (unchanged since V1). **Job V2** submitted 2026-11-02 as 3675628 (skx-dev) and 3675629 (skx), the later starter to be cancelled.

**What the bucketed GVT does here** (`src/gvt/bucketed.C`): a bucket completes only when every PE had passed it at the previous count wave and the sent and received totals match. GVT therefore trails the slowest PE by at least two waves. V1's mean lead of the slowest PE over GVT at wave completion was 2,138 ps (4.3 buckets) at W 2,500. So when a wave completes, PEs typically sit almost a window ahead of GVT. A PE contributes to a wave after executing 128 events (`--gvt-wave-events`) or as soon as it cannot execute.

**The two hypotheses (section 195):**
- **H1:** the cycle time is set by per-hop message latency along each cycle's chain of gates.
- **H2:** it is set by GVT pace: per cycle, the slowest PE's work plus the waves that confirm it.

**Runs** (b19 × N, one copy per node, span 1, balanced layout, 5,000 cycles; 1-node and 4-node series side by side; 2 reps, rep 2 reversed; 128 LPs per chare; direct sends unless noted):
- At W 2,500, buckets of 500 ps:
  - `--batch` 4, 16 (V1's setting) and 64. Pass size changes both message latency and wave pace (section 10, PHOLD).
  - `--gvt-wave-events=16`, and `--wave-batch=4` (passes of 4 events only while a wave is in flight). These change wave pace only.
  - On PHOLD at 16 nodes, the advance was the time the late PE took to run its 128 events (section 120), and `--wave-batch=4` cost 3–7%. Here a PE runs about 550 events per cycle at about 0.75 µs each, so 128 events take about 100 µs, against V1's 1.1 ms cycle.
- Buckets of 2,500 ps (one per clock cycle): W 2,500 and W 5,000.
- The frozen controller: direct sends with buckets of 500 and 2,500 ps; PP 2,048 with buckets of 2,500 ps.
- WPs 512 at W 2,500 with buckets of 2,500 ps.
- Rep 1 only: `--gvt-trace=1` (every count wave: start, end, valid buckets, the bucket completed, PE 0's lead over GVT) at W 2,500, with buckets of 500 and of 2,500 ps.
- Gate: the VLSI change tier on 2 nodes. A failing case's output is now kept (`gate_fail_*.out`).

**Predictions:**
- **X1.** One count per cell, as in V1 (125,998,590 / 574,541,914). Every arm gives V1's balanced-layout digest (87c11aec… / 0c800d36…), since no setting here changes the layout.
- **X2 (pass size).** At 1 node, batch 4 is at least 1.10× batch 16 and batch 64 at most 0.90×.
- **X3 (wave pace only).** `--gvt-wave-events=16` and `--wave-batch=4` are each within ±5% of batch 16. If they are, H2 in its wave-latency form is out.
- **X4 (buckets of one cycle).** GVT updates stay 4,990–5,010 per run. Direct sends at W 2,500 and at W 5,000 are each within ±10% of buckets of 500.
- **X5 (the controller).**
  - With buckets of 2,500 ps the direct-send controller's mean W is 2,500–5,000. It reaches at least 0.95 of direct W 2,500 at the same buckets.
  - With buckets of 500 it stays at 500 and reaches 0.60–0.75 of direct W 2,500.
  - PP 2,048's controller with buckets of 2,500 reaches at least 0.95 of V1's best PP 2,048 (19.3 / 48.0 M ev/s).
- **X6.** WPs 512 at buckets of 2,500 is 0.95–1.00 of direct sends at the same buckets.
- **X7 (trace, buckets of 500).**
  - 2–4 count waves per GVT update; mean wave duration 0.3–0.6 ms at 1 node and 0.6–1.0 ms at 4 nodes.
  - Waves run back to back: the gap from one wave's end to the next's start is under 10% of a wave.
  - PE 0's lead over GVT is at least 1,500 ps in at least half the waves.

**Reading the results** (fixed before the runs):
- **H1 is supported** if X2 holds while X3 holds (pass size matters, wave pace alone does not) and the waves take a small share of each cycle.
- **H2 is supported** if X3 fails (faster waves give faster cycles) or if waves × wave duration ≈ the cycle time with PEs at the window edge (X7).
- **Both may hold.** The trace then gives each a share of the cycle.
- No engine change follows from this job alone. A fix is designed only after the cause is established.

### §197 · V2 results: GVT rounds take 5–6% of each cycle, so GVT pace is ruled out; each cycle's own execution takes the rest, with every PE idle at least 20% of it; buckets of one clock period fix the controller (0.99 of the best fixed W) (2026-11-02; skx-dev batch job 3675628, 5 nodes)

> **Status: current.** Design and predictions in section 196. 7 min 34 s (skx copy 3675629 cancelled). Gate 45/45; every run finished. Summary `~/charades-data/vlsi/vdiag196_summary.py` (output `j3675628_summary.txt`); data and traces `~/charades-data/vlsi/j3675628/`.

**Rates** (direct sends unless noted; M committed ev/s, median of 2 reps; ÷ the reference, direct W 2,500, buckets of 500, batch 16; higher is better):

| arm | 1 node | ÷ ref | 4 nodes | ÷ ref |
|---|---|---|---|---|
| reference (V1's best arm) | 23.0 | 1.00 | 62.3 | 1.00 |
| `--batch=4` | 20.7 | 0.90 | 54.5 | 0.87 |
| `--batch=64` | 23.4 | 1.02 | 64.5 | 1.03 |
| `--gvt-wave-events=16` | 22.8 | 0.99 | 62.0 | 0.99 |
| `--wave-batch=4` | 22.7 | 0.99 | 62.3 | 1.00 |
| buckets of 2,500, W 2,500 | 23.0 | 1.00 | 62.2 | 1.00 |
| buckets of 2,500, W 5,000 | 24.5 | 1.07 | 62.1 | 1.00 |
| controller, buckets of 500 (mean W 500) | 20.5 | 0.89 | 59.8 | 0.96 |
| **controller, buckets of 2,500** (mean W 2,500) | 22.7 | **0.99** | 61.6 | **0.99** |
| controller, PP 2,048, buckets of 2,500 | 19.3 | 0.84 | 47.4 | 0.76 |
| WPs 512, buckets of 2,500, W 2,500 | 22.9 | 1.00 | 58.5 | 0.94 |

Every arm makes 4,999–5,008 GVT updates (one per clock cycle) at 2.0–3.4 count waves per update.

**The traces** (`--gvt-trace=1`, direct W 2,500, rep 1; middle 80% of waves):

| | 1 node, buckets of 500 | 1 node, buckets of 2,500 | 4 nodes, buckets of 500 | 4 nodes, buckets of 2,500 |
|---|---|---|---|---|
| count waves per GVT update | 2.41 | 2.42 | 2.11 | 2.11 |
| wave duration, median (ms) | 0.027 | 0.026 | 0.044 | 0.043 |
| time inside waves (% of the run) | 6.0 | — | 5.4 | — |
| gap after the cycle's last wave (ms, p75 / p90) | 0.87 / 1.27 | — | 1.67 / 2.07 | — |
| PE 0's lead over GVT at wave completion (ps) | 5,000 in every wave | 5,000 | 5,000 | 5,000 |
| slowest PE's lead (valid buckets, median) | 5 (the whole window) | 1 | 5 | 1 |

- **Each cycle has the same shape:** two waves back to back (about 0.05 ms at 1 node, 0.09 ms at 4) complete the cycle's buckets and GVT moves to the next clock edge. Then no wave runs for 0.6–2.4 ms. A wave starts only once every PE has passed the next cycle's buckets, so that gap is the cycle's own execution.
- **Every PE waits during that execution.** The least-blocked PE waits at the window about 20% of the run (V1 and V2), and the mean PE 62% (1 node) to 74% (4 nodes). If the busiest PE's work set the cycle time, that PE would rarely wait. So the cycle is set by dependencies among events, not by any PE's load.

**Predictions (section 196):**
- **X1 right.** One count per cell; every arm gives V1's balanced-layout digest (87c11aec… / 0c800d36…).
- **X2 wrong, in the opposite direction.** Batch 4 is 0.90 / 0.87 of batch 16 and batch 64 1.02 / 1.03. Shorter passes cost more than they save, so pass length is not what sets per-hop time.
- **X3 right.** `--gvt-wave-events=16` and `--wave-batch=4` are 0.99–1.00.
- **X4 right.** GVT updates 4,999–5,000; buckets of 2,500 give 1.00 at W 2,500 and 1.07 / 1.00 at W 5,000.
- **X5 right with buckets of 2,500, too pessimistic at 500.**
  - With buckets of 2,500 the direct-send controller settles at W 2,500 and reaches 0.99 of direct W 2,500.
  - With buckets of 500 it stays at W 500 but reaches 0.89 / 0.96, not 0.60–0.75. V1's 0.62–0.70 was PP's controller against direct sends.
  - PP's controller at buckets of 2,500 reaches 1.00 / 0.99 of V1's best PP.
- **X6 right at 1 node, just short at 4.** WPs 512 ÷ direct is 1.00 and 0.94.
- **X7 half right.**
  - Right: 2.4 / 2.1 waves per update, and PE 0 a full window ahead in every wave.
  - Wrong: waves last 0.027 / 0.044 ms, not 0.3–1.0, and they are not back to back. Most of each cycle has no wave running.

**Reading (section 196's rule):**
- **H2 (GVT pace) is out.** Faster waves change nothing (X3), and waves fill 5–6% of the run.
- **H1 in its pass-size form is out too (X2).**
- **What the data support:** each cycle's execution, about 0.95 ms at 1 node and 1.7 ms at 4, is spent in a chain of dependent events in which every PE waits at least 20% of the time. The circuit's levels behave like steps: each level's events wait for the previous level's messages, and the per-level spread across PEs and the hop time add up per level.
- **What sets each step's time is open.** Candidates: hops between the node's 2 processes (29% of messages); how quickly a PE waiting at the window picks up a new message; per-event cost.
- **Why Devastator gains from a wider window and Charades does not** is the other half of the gap. At W 10,000 Devastator runs 88% efficient and 2× faster. Charades (V1) runs 84% efficient at the same rate as W 2,500, with one PE then busy about 99% of the time (least-blocked share 1.0–1.3%).

**Consequences:**
- **For the VLSI scaling job:** buckets of one clock period (2,500 ps) make the frozen controller pick the best fixed W (0.99 of it at 1 and 4 nodes). This is a per-model setting, as every model's bucket size already is. The arms are direct sends and WPs 512 at W 2,500, and the controller, all with buckets of 2,500. PP 2,048 is dropped (0.76–0.84).
- **To find the step cost** (if the user wants it before the paper's VLSI numbers): one process per node (1 × 46 PEs) against two, which removes cross-process hops at 1 node; then a traced cycle that times the hops along one chain.
- **Claim 3's wording on VLSI** stands as in section 195 until the 1–32-node runs show whether Charades' smaller per-node loss (0.68 against 0.46 at 4 nodes) closes the gap.

### §198 · Why a Charades clock cycle takes 1.8× Devastator's at the same window (job V3 design, 2026-11-03; written before any runs)

> **Status: design.** User decision 2026-11-03: diagnose the gap before the 1–32-node VLSI job (any fix would change every VLSI number, and the engine freezes 2026-12-07). Script `~/charades-data/vlsi/vdiag198.slurm`, summary `vdiag198_summary.py` (both written before the run); `charades-vlsi` 5f6983a, which adds each PE's blocked time to `pe_stats.csv` (`blocked_s`; Mac VLSI change tier 15/15). **Job V3** submitted 2026-11-03 as 3677137 (skx-dev) and 3677138 (skx), the later starter to be cancelled.

**What V1 and V2 already say about the gap** (V1, section 195; M committed ev/s, higher is better; ms per clock cycle = run time ÷ 5,000, lower is better):

| | Charades, W 2,500 | Devastator, W 2,500 | Devastator, W 10,000 | Charades ÷ Devastator, same W 2,500 |
|---|---|---|---|---|
| 1 node, M ev/s (ms per cycle) | 22.9 (1.10) | 41.2 (0.61) | 45.0 (0.56) | 0.56 |
| 4 nodes, span 1 | 61.9 (1.86) | 82.6 (1.39) | 82.5 (1.39) | 0.75 |

- **Most of the gap is at the same window.** Devastator's wider window adds 1.09× at 1 node, 1.00× at 4 nodes and 1.12× at span 4. Section 197's "at W 10,000 Devastator runs 88% efficient and 2× faster" compared it with Charades at W 10,000, not with its own W 2,500; the wide-window part is about 10%, not 2×.
- **Both engines run the same layout** (one bin of chunks per worker) **on 2 processes × 23 workers per node.** So per-level load imbalance and the share of messages between processes are the same in both; what differs is how each engine runs and delivers events.
- **Going from 1 to 4 nodes adds nearly the same time per cycle in both engines:** 0.76 ms (Charades) and 0.78 ms (Devastator). Each copy also does 14% more work per cycle at 4 nodes (its ring inputs come from another copy). If that added time is common to both engines, the gap shrinks with node count because a shared cost dilutes it, not because Charades scales better per node (section 195's reading of 0.68 against 0.46).
- **At span 1 almost no circuit events cross nodes.** b19 has 18 ring inputs per copy, so a copy receives at most a few dozen pin changes per cycle from the previous copy, against about 28,700 events per copy per cycle; the nodes are otherwise coupled by GVT and the window.
- **V2 ruled out GVT pace and pass length** (section 197). Each cycle's execution is a chain of dependent events in which every PE waits at least 20% of the time.

**Hypotheses for the 1.8× at the same window:**
- **H3, per-event cost:** each event costs Charades more CPU time, and the cycle (a dependency-bound schedule over the same layout) stretches in proportion. October's PHOLD profile (section 23) measured 11,100 cycles per committed event for Charades against 5,300 for Devastator, before the fast paths (section 24, 1.28×): about 1.6× after them.
- **H4, hops between the node's 2 processes** (29% of messages) cost Charades more than Devastator.
- **H5, delivery and wake-up:** a message takes longer to reach, and be picked up by, the PE that runs it, within a process too.

**Runs** (b19 × N, one copy per node, span 1, balanced layout, direct sends, W 2,500, buckets of 2,500 ps, 5,000 cycles, 128 LPs per chare; 1-node and 4-node series side by side; 2 reps, rep 2 reversed):
- **Charades:**
  - 2 × 23 PEs per node (the reference; V2's best setting).
  - 1 × 46 PEs per node on the same cores (`+pemap 2-46:2,3-47:2`, `+lci_ndevices 23`): the same layout and digest, no hops between processes on a node (H4).
  - Each of the two with `--comm-stats=1`: send-to-receive latency within a process, between processes on the node and between nodes (mean, p50, p90, p99), and the time inside send calls (H4, H5).
  - 1 node only: W 10,000; one copy on a single PE, 500 cycles (H3).
- **Devastator:**
  - p2w23 / p8w23 at W 2,500: the same-job reference.
  - 1 node only: W 10,000; one copy on a single worker (p1w1, built in the job), 500 cycles (H3).
- **Rep 1 only:**
  - `--pe-stats=1 --gvt-trace=1` at W 2,500 (1 and 4 nodes) and W 10,000 (1 node): each PE's executed, committed and rolled-back events, blocked time and time in `execute()`.
  - perf (user cycles at 1,999 Hz, process 0) of both engines at 1 node, W 2,500. Data only: read if H3 holds, to rank what makes up Charades' per-event cost.
- Gate: the VLSI change tier on 2 nodes.

**Predictions:**
- **Y1.**
  - One count per cell: 125,998,590 (1 node) and 574,541,914 (4 nodes) in both engines.
  - Every Charades arm gives V1's digest (87c11aec… / 0c800d36…), 1 × 46 included, since the layout depends on PEs per node, not on processes.
  - The single-worker runs of the two engines commit the same count (no earlier value). Devastator is deterministic.
- **Y2 (same-job reference).** Charades ÷ Devastator at W 2,500 is 0.50–0.62 at 1 node and 0.68–0.82 at 4 nodes (V1: 0.56, 0.75). At W 10,000 (1 node) it is 0.45–0.56 (V1: 0.50).
- **Y3 (H3).** On a single worker, Charades ÷ Devastator is 0.50–0.70. Per-event cost then accounts for at least 0.6 of the 1-node gap (ln Y3 ÷ ln Y2). One copy on one core has a far larger working set than one bin per core, so this is a comparison between engines, not the per-event cost of the parallel run.
- **Y4 (H4).** 1 × 46 ÷ 2 × 23 is 0.95–1.15 at 1 node and at 4 nodes: hops between processes account for at most a quarter of the 1-node gap.
- **Y5 (H5).**
  - At 2 × 23, 1 node: median send-to-receive latency at most 10 µs within a process and between processes, and between processes at most 2× within. Along a chain of about 25 gate levels that is at most 0.25 ms of the 1.10 ms cycle.
  - `--comm-stats=1` costs at most 7% (rate at least 0.93 of the same layout without it).
- **Y6 (the added cost at 4 nodes).** Per clock cycle, 4 nodes minus 1 node is 0.6–0.95 ms for Charades 2 × 23, Charades 1 × 46 and Devastator alike (V1: 0.76, 0.78).
- **Y7 (wide window, per PE, 1 node).**
  - At W 2,500 every PE is blocked 15–90% of the run (V1: 20–85%).
  - At W 10,000 the least-blocked PE is blocked at most 3% (V1: 1.3%), executes at least 1.3× the mean PE's events, and its executed ÷ committed is at least 1.5, against at most 1.2 for the median PE: rollbacks keep it busy.
  - Charades W 10,000 ÷ W 2,500 is 0.95–1.02, Devastator's 1.05–1.12 (V1: 0.99, 1.09).

**Reading the results** (fixed before the runs):
- The share of the 1-node gap that per-event cost accounts for is s3 = ln Y3 ÷ ln Y2; the share that hops between processes account for is s4 = ln(1 × 46 ÷ 2 × 23) ÷ (−ln Y2).
- **If s3 + s4 ≥ 0.75**, the 1-node gap is accounted for. The next step is Charades' per-event cost (the perf profiles rank its parts against Devastator's) and, if s4 is material, a one-process launch for VLSI.
- **If s3 + s4 < 0.75**, the rest is in delivery and wake-up (H5, Y5). The next step is a trace of the hops along one chain, which needs new instrumentation.
- **If Y6 holds**, the 1–32-node job will show the gap shrinking by dilution, and only a lower per-event cost raises Charades' ratio at every node count. If Devastator's added time grows faster than Charades', the order can still change at scale, as on dragonfly.
- No engine change follows from this job alone; a fix is designed once the cause is established.

### §199 · V3 results: sends between the node's two processes cost each sending PE 2 µs and stall the heaviest senders; one process per node makes Charades 1.32× faster (1 node) and 1.28× (4 nodes), Charades ÷ Devastator 0.73 and 0.96; the cost added at 4 nodes is one copy's extra activity, the same in every engine (2026-11-03; skx-dev batch job 3677137, 5 nodes)

> **Status: current.** Design and predictions in section 198. 8 min 58 s (skx copy 3677138 cancelled). Gate 45/45; Devastator's p1w1 binary built in the job; every run finished. Summary `~/charades-data/vlsi/vdiag198_summary.py` (output `j3677137_summary.txt`); data, `pe_stats.csv` files and perf reports `~/charades-data/vlsi/j3677137/` (perf data files stay on Stampede3).

**Rates** (b19 × N, span 1, direct sends, buckets of 2,500 ps; M committed ev/s, median of 2 reps, higher is better; ms per clock cycle, lower is better):

| arm | 1 node | ms per cycle | 4 nodes | ms per cycle |
|---|---|---|---|---|
| Charades 2 × 23, W 2,500 (reference) | 23.1 | 1.093 | 60.2 | 1.910 |
| **Charades 1 × 46, W 2,500** | **30.5** (1.32× the reference) | **0.827** | **77.0** (1.28×) | **1.493** |
| Charades 2 × 23, W 10,000 | 22.6 | 1.113 | — | — |
| Charades with `--comm-stats=1` (2 × 23 / 1 × 46) | 22.4 / 30.1 | | 58.7 / 76.2 | |
| Devastator 2 × 23, W 2,500 | 41.6 | 0.606 | 80.5 | 1.427 |
| Devastator 2 × 23, W 10,000 | 45.1 | 0.559 | — | — |
| **Charades ÷ Devastator, W 2,500, Charades 2 × 23** | 0.56 | | 0.75 | |
| **Charades ÷ Devastator, W 2,500, Charades 1 × 46** | **0.73** | | **0.96** | |
| One copy, single worker, 500 cycles: Charades / Devastator | 0.64 / 1.60 (Charades ÷ Devastator 0.40; 1.57 / 0.63 µs per event) | | | |

**Where the 1 × 46 gain comes from** (1 node):
- **Busy time per executed event** ((100% − blocked share) × run time × PEs ÷ executed events) falls from 0.73 µs (2 × 23) to 0.45 µs (1 × 46), 35 PE-seconds over the run.
- **Send calls between the two processes** (`--comm-stats=1`, which times only sends that leave the process) take 15.5 M × 1.97 µs = 30.5 PE-seconds, 11.8% of all PE time: 87% of the busy time that 1 × 46 removes. Same-process events take the fast path, which `--comm-stats` does not time.
- **These sends stall the heaviest senders.** Remote sends per PE range from 2 thousand to 2.6 million (the layout balances events, not sends), and a PE's blocked share falls as its sends rise (correlation −0.74 at W 2,500, −0.75 at W 10,000, −0.77 at 4 nodes). The least-blocked PE at 2 × 23 is blocked 19–20%; at 1 × 46 every PE is blocked at least 49% (mean 69%).
- **Latency between processes** (send to receive handler): mean 14.5 µs, median in the 8–16 µs bucket, p90 ≤ 33 µs (1 node); 16.3 µs mean at 4 nodes.
- **Perf, process 0 at 2 × 23** (user cycles, including time spent spinning while blocked): network polling and sends take about 18% in Charades (psm2 7.6%, LCI 4.4%, libfabric psm2 provider 2.5%, Reconverse's LCI backend progress 3.3%) against 0.3% in Devastator, whose one master thread per process does all network work while its workers exchange events through shared-memory channels. Charades also spends 7.8% in `LPChare::process_cancel_q` and 6.9% in spin locks.

**The cost added at 4 nodes is one copy's extra work, not synchronization:**
- Copy 2 (node 2) commits 34.2% of all events, the other three copies 21.9–22.0% each, about the 1-node copy's count. Copy 2 does 1.56× their work, and within its node the busiest PE commits 2.51× the node's mean (other nodes: 1.12×), because the layout comes from a profile of one copy with its own inputs.
- Every engine runs the same inputs and the same layout, so this cost is the same in all of them (Y6). In the 1–32-node job, the most active copy will set every engine's pace.

**Predictions (section 198):**
- **Y1 right.** One count per cell (125,998,590 / 574,541,914) in both engines; every Charades arm, 1 × 46 included, gives V1's digest (87c11aec… / 0c800d36…); the two engines' single-worker runs both commit 12,309,428; Devastator deterministic.
- **Y2 right.** Charades ÷ Devastator at W 2,500 is 0.555 (1 node) and 0.747 (4 nodes); at W 10,000, 0.502.
- **Y3 wrong.** On a single worker Charades ÷ Devastator is 0.40, not 0.50–0.70. Its "share" of the gap is 1.56, more than the whole gap: with one copy's 231 k nets on one core, the working set dominates and the comparison does not measure the parallel per-event cost (the caveat in section 198).
- **Y4 wrong.** 1 × 46 ÷ 2 × 23 is 1.32 (1 node) and 1.28 (4 nodes), not 0.95–1.15. Hops between processes account for 0.47 of the 1-node gap and 0.85 of the 4-node gap.
- **Y5 half right.**
  - Right: `--comm-stats=1` costs 1–3% (0.97–0.99).
  - Wrong: the median latency between processes is in the 8–16 µs bucket (mean 14.5 µs), not at most 10 µs. Within a process it was not measured (fast path).
- **Y6 right.** 4 nodes minus 1 node per cycle: 0.82 ms (Charades 2 × 23), 0.67 ms (1 × 46), 0.82 ms (Devastator). The cause is copy 2's activity, not synchronization.
- **Y7 half right.**
  - Right: at W 2,500 PEs are blocked 20–85%. At W 10,000 the least-blocked PE is blocked 1.3%, the median PE's executed ÷ committed is 1.16, and W 10,000 ÷ W 2,500 is 0.98 (Charades) and 1.08 (Devastator).
  - Wrong: that PE (PE 18) executes 0.87× the mean PE's events with executed ÷ committed 1.003; rollbacks do not keep it busy, its sends do (2.0 M remote sends, among the most).

**Reading (section 198's rule):** s3 + s4 ≥ 0.75, but s3 (1.56) is not a usable share. The closure that holds is the 1 × 46 one: the measured send time between processes covers 87% of the busy time that one process per node removes, and the heaviest senders were the PEs that set the pace.

**Consequences:**
- **The process layout is a per-workload launch choice.** On VLSI (on-node and latency-bound) 1 × 46 is 1.28–1.32× 2 × 23. On remote-heavy Gaussian PHOLD in October (section 22, verbs, before psm2), 1 × 46 was 0.98× the old 2 × 24 layout while 2 × 23 was 1.26–1.35×. Before any paper number uses 1 × 46, Devastator gets the same choice (1 × 46 workers per node needs new p1w46 / p4w46 … binaries).
- **The remaining 1-node gap (0.73)** is in the chain's step time with every PE blocked at least 49%. The 2 × 23 profile points at per-PE network polling (about 18% of cycles), `process_cancel_q` and spin locks; a 1 × 46 profile is needed to say what remains once the sends between processes are gone.
- **Charades' wider window** may pay off at 1 × 46, where the heavy senders no longer set the pace; untested.
- **Before the 1–32-node job:** measure each copy's activity for N up to 32 offline (the busiest copy sets every engine's pace), and decide whether the workload keeps independent inputs per copy.

### §200 · One process per node against shared memory between the node's processes, in both engines; each copy's activity (job V4 and a Mac check, design, 2026-11-03; written before any runs)

> **Status: design.** User decisions 2026-11-03: a per-copy activity check on the Mac and a short job with Devastator at one process per node and Charades' 1 × 46 at wider windows; **the user added Charades runs on Charm++ built with `--enable-shmem`**. Builds and checks run first in job vbuild200 on skx compute nodes (LCI compiles with `-march=native`; the login nodes are Sapphire Rapids). Scripts `~/charades-data/vlsi/vbuild200.slurm`, `vdiag200.slurm`, `vdiag200_summary.py`. vbuild200 ran as 3677266; **job V4** submitted 2026-11-03 as 3677339 (skx-dev) and 3677340 (skx), the later starter to be cancelled, on Charades c7373b4 (section 201's fix). Charades 269c608 counts messages delivered through the runtime's shared-memory pool ("Shared-Memory Messages Received"); the model's `--copy-stats=1` prints each copy's committed pin changes plus evaluations.

**What the shared-memory runs use:**
- **`charm-pads-shmem`:** `charm-pads-exp`'s source (Charm++ 9d6a55780, Reconverse `pads-dest-device` 22871c6) and the same patched LCI source, built `--with-production --enable-shmem`. With `CMK_USE_SHMEM`, Charm++ sets up Reconverse's shared-memory pool (POSIX shared memory) at startup and sends each message for a PE in another process on the same host through it (`_tryIpcSend`), falling back to the network when a message exceeds the pool's block size or no block is free. Charades' tree `charades-shmem` builds against it.
- **Reconverse's `+ipc`:** the same pool, switched on at run time and used by Converse's send (`CmiSyncSendAndFree`), with the existing build. Included because it needs no rebuild.
- On the Mac (2 processes, tiny circuit) `+ipc` delivered 1,740 messages through the pool with the same committed count, and the VLSI change tier passed 15/15 at 2 × 2.

**Per-copy check (Mac, one process, 8 PEs, W 2,500, buckets of 2,500):** b19 × 4 over 5,000 cycles (V3's 4-node workload), and b19 × 4, 8, 16, 32 over 1,000 cycles.
- **P1.** 4 copies over 5,000 cycles commit 574,541,914, V3's 4-node count. Copy 2 is the most active, at least 1.5× the mean of the other three.
- **P2.** The most active copy's activity ÷ the mean copy's is at least 1.3 at 8, 16 and 32 copies over 1,000 cycles, and it does not shrink as copies are added.

**Job V4 runs** (b19 × N, span 1, direct sends, buckets of 2,500 ps, 5,000 cycles, `--copy-stats=1`; 1-node and 4-node series side by side; 2 reps, rep 2 reversed):
- **Charades:**
  - A: 2 × 23 PEs per node (reference), W 2,500.
  - B: 1 × 46 on the same cores, W 2,500 / 5,000 / 10,000.
  - C: 2 × 23 on `charades-shmem` (Charm++ `--enable-shmem`), W 2,500 / 5,000 / 10,000.
  - D: 2 × 23 with `+ipc`, W 2,500.
  - C with `--comm-stats=1` at W 2,500.
  - Rep 1, 1 node: `--pe-stats=1 --gvt-trace=1` for B and C at W 2,500; perf (process 0) of B and C.
- **Devastator:** 2 × 23 (p2w23 / p8w23) and 1 × 46 (p1w46 / p4w46, built in vbuild200), each at W 2,500 / 5,000 / 10,000.
- Gate: the VLSI change tier on 2 nodes (charades-vlsi). vbuild200 already ran it with the shared-memory tree on 1 node (2 × 2, 4 × 2) and 2 nodes, and with `+ipc` on 1 node, on the same binaries.

**Predictions:**
- **Z1.**
  - One count per cell (125,998,590 / 574,541,914) in both engines and every Charades build and layout; every Charades arm gives V1's digest (87c11aec… / 0c800d36…); Devastator deterministic.
  - Shared-memory messages: 0 for A and B. For C and D, at least 90% of V3's count of events between processes on a node (15.5 M at 1 node, 71.9 M at 4 nodes).
- **Z2 (Charm++ shared memory).** C ÷ A at W 2,500 is at least 1.15 at 1 node and at least 1.13 at 4 nodes (half or more of 1 × 46's gain). C ÷ B is 0.87–1.00: a send still copies the message into a shared block, and the receiver polls the pool.
- **Z3 (`+ipc`).** D is within ±5% of C.
- **Z4 (latency through the pool).** With `--comm-stats=1` on C, the mean latency between processes on a node is at most 7 µs (V3 through LCI: 14.5) and the mean send call at most 1 µs (V3: 1.97).
- **Z5 (Devastator's layout).** Devastator 1 × 46 ÷ 2 × 23, each at its best W, is 0.95–1.10 at 1 and 4 nodes. Its workers already hand messages to other processes through a master thread and GASNet's shared-memory transport. Then Charades ÷ Devastator, each at its best layout and W, is 0.68–0.80 at 1 node and 0.88–1.05 at 4 nodes.
- **Z6 (wider windows).** For B and C, the better of W 5,000 and W 10,000 ÷ W 2,500 is 1.00–1.10 (at 2 × 23 through LCI, V3: 0.98).
- **Z7 (per PE, 1 node, W 2,500).** The least-blocked PE is blocked at least 40% (V3 2 × 23: 20%); the correlation between blocked share and remote sends is at most 0.4 in size for B and 0.5 for C (V3 2 × 23: −0.74).
- **Z8 (copy activity).** Every Charades arm at 4 nodes prints the same per-copy activity as the Mac's 4-copy, 5,000-cycle run.

**Reading** (fixed before the runs):
- **If C is at least 0.95 of B**, shared memory between the node's processes gives Charades one process per node's gain while keeping one process per socket. VLSI uses it, and it is tested on the other applications before it becomes the default launch.
- **If C is below 0.90 of B**, the pool still costs on the send path. 1 × 46 is Charades' VLSI launch, with Devastator also at its best layout.
- Paper comparisons use each engine's best layout and W at each node count. This is a launch and runtime-build choice; the frozen engine does not change.
- The per-copy results decide whether the 1–32-node job keeps independent random inputs per copy.

### §201 · Builds, the shared-memory pool starved by Charades' message pool (fixed), and each copy's activity: one copy in 32 does 1.75× the work of the others (2026-11-03; skx-dev batch job vbuild200 3677266, 2 nodes; Mac)

> **Status: current.** Design and predictions in section 200. vbuild200: 8 min 30 s after a 3.5-minute `/work2` stall at start (skx copy 3677267 cancelled); log `/scratch/09863/rrao/charades-jobs/vbuild200_3677266.out`, outputs `$WORK/charades-runs/vbuild200/j3677266/`. Mac per-copy runs: `~/charades-data/vlsi/copies/` (logs, configs, `run.sh`).

**Builds (on c454-103, Xeon 8160):**
- `charm-pads-shmem`: `CMK_USE_SHMEM 1`, Release, LCI compiled from `charm-pads-exp`'s patched source (`LCI_SOURCE_DIR` points there); 2 minutes at `-j46`.
- `charades-shmem` (same commit as `charades-vlsi`) links `charm-pads-shmem`.
- Devastator `vlsi-p1w46` and `vlsi-p4w46` (ofi-psm2).
- Gates: the shmem tree on 1 node (2 × 2, 4 × 2) 30/30 and on 2 nodes 45/45; `charades-vlsi` with `+ipc` on 1 node 30/30.

**Smoke runs (b19, 1 node, 2 × 23, W 2,500; one run each, a preview):**

| run | M committed ev/s (higher is better) | ÷ reference | messages through the shared-memory pool |
|---|---|---|---|
| reference (`charades-vlsi`) | 22.3 | 1.00 | 0 |
| Charm++ `--enable-shmem` | 10.4 | 0.47 | 153,658 |
| Reconverse `+ipc` | 15.1 | 0.68 | 153,510 |

Committed count and digest as V1. About 1% of V3's 15.5 M messages between the node's processes went through the pool, and both runs were slower.

**Cause: Charades' message pool kept the pool's blocks.**
- A message from another process on the host arrives in a block of the receiving process's shared segment (8 MB by default), and `CmiFree` returns the block. `--msg-pool` (on by default, section 24) kept received event messages for reuse instead, up to 65,536 per PE, so the segment ran dry early.
- After that, each send tried 4 times for a block and then fell back to LCI.
- Mac check (b19, one copy, 2 processes × 4 PEs, 200 cycles, `+ipc`; Mac timings are not comparable, the per-copy runs shared the cores):

| | messages to the other process | through the pool | mean send call (µs) |
|---|---|---|---|
| message pool on (before the fix) | 634 k | 305 k | 190 |
| `--msg-pool=0` | 647 k | 649 k (all, and control messages) | 0.75 |
| message pool on, fixed (c7373b4) | 642 k | 644 k (all) | 3.6 |

- **Fix (charades c7373b4):** `remote_event_delete` never pools a message that sits in this process's shared segment (`CmiMsgToIpcBlock` on `coreIpcManager_`); freeing it returns the block. Messages within a process and from other nodes are pooled as before. Mac: VLSI change tier 15/15 at 1 × 4 and at 2 × 2 with `+ipc`; every model at 2 × 2 with `+ipc` 22/22. Both Stampede3 trees rebuilt at c7373b4.
- Job V4 runs on c7373b4 with the arms of section 200 unchanged; its predictions Z1–Z8 stand for the fixed path.

**Each copy's activity** (Mac, `--copy-stats=1`: committed pin changes plus evaluations; ÷ the median copy):

| copies, cycles | committed events | copy 2 ÷ median copy | other copies ÷ their mean | most active ÷ mean copy |
|---|---|---|---|---|
| 4, 5,000 | 574,541,914 (= V3, 4 nodes) | 1.758 | 0.999–1.001 | 1.478 |
| 4, 1,000 | 113,528,626 | 1.746 | 0.997–1.005 | 1.473 |
| 8, 1,000 | 213,421,408 | 1.749 | 0.997–1.006 | 1.598 |
| 16, 1,000 | 413,105,684 | 1.750 | 0.993–1.011 | 1.670 |
| 32, 1,000 | 812,409,570 | 1.749 | 0.990–1.011 | 1.708 |

- **Only copy 2 differs**, at every copy count, and it does so from the first 1,000 cycles. Its inputs (seed 1) put it in a mode with 1.75× the switching of every other copy; the other 31 copies agree within ±1.1%. It is a property of the inputs, not of the ring or the copy count, and it is the same in every engine.
- **With one copy per node, from 3 nodes on, node 2 does 1.75× the work of the others** and sets every engine's pace. At 1 and 2 nodes no copy is in that mode. Per-node rates from 1–2 nodes to 4 and more therefore fall in every engine for a reason that has nothing to do with the engine (section 199's 1 → 4-node added cost).

**Predictions (section 200):**
- **P1 right.** 4 copies over 5,000 cycles commit V3's 574,541,914; copy 2 is the most active, at 1.76× the mean of the other three.
- **P2 right.** The most active copy ÷ the mean copy is 1.60, 1.67 and 1.71 at 8, 16 and 32 copies, rising toward 1.75 as copies are added.

**Consequence for the 1–32-node job: user decision 2026-11-03, keep the workload** (one copy per node, inputs as they are) **and report the per-copy activity.** Every engine pays the most active copy alike. The paper states that from 3 nodes on one copy does 1.75× the work of the others, so per-node rates from 1–2 nodes to 4 and more fall in every engine for that reason. Runs at 4 nodes and more print `--copy-stats=1`. (Not chosen: several copies per node, which would dilute it to 1.19× at 4 per node and 1.09× at 8; a seed with no outlier, selected after the fact.)

### §202 · V4 results: one process per node is Charades' best VLSI layout (1.33× / 1.27×; 1.47× with W 5,000 at 1 node), Charades ÷ Devastator 0.77 / 0.95; shared memory between the node's processes now carries the messages but runs at 0.17–0.21×, because Reconverse's pool funnels each process's traffic through one locked queue and one locked allocator; Devastator at one process per node hangs (2026-11-03; skx-dev batch job 3677339, 5 nodes)

> **Status: current, incomplete.** Design and predictions in section 200; Charades c7373b4 (section 201's fix) in both trees. Gate 45/45. The job hit its 45-minute limit: all 12 Devastator runs at one process per node (p1w46, p4w46) stalled at the 300 s cap after printing their setup. Missing besides those: rep 2 of A and B at 4 nodes. Every other run finished. Summary `~/charades-data/vlsi/vdiag200_summary.py` (output `j3677339_summary.txt`); data and perf reports `~/charades-data/vlsi/j3677339/`.

**Rates** (b19 × N, span 1, direct sends, buckets of 2,500 ps; M committed ev/s, median of 2 reps (4 nodes A and B: 1 rep), higher is better; ÷ A at W 2,500):

| arm | 1 node | ÷ A | 4 nodes | ÷ A |
|---|---|---|---|---|
| A: 2 × 23, W 2,500 (LCI between processes) | 23.2 | 1.00 | 63.1 | 1.00 |
| **B: 1 × 46, W 2,500** | **30.8** | **1.33** | **80.0** | **1.27** |
| B: 1 × 46, W 5,000 | **34.2** | **1.47** | 75.4 | 1.19 |
| B: 1 × 46, W 10,000 | 30.6 | 1.32 | 69.1 | 1.10 |
| C: 2 × 23, Charm++ `--enable-shmem`, W 2,500 | 4.1 | 0.17 | 11.6 | 0.18 |
| C, W 5,000 / 10,000 | 4.5 / 4.2 | | 12.9 / 10.0 | |
| D: 2 × 23, `+ipc`, W 2,500 | 4.8 | 0.21 | 13.3 | 0.21 |
| Devastator 2 × 23, W 2,500 / 5,000 / 10,000 | 41.5 / **44.6** / 44.3 | | 83.6 / 83.2 / **83.8** | |
| Devastator 1 × 46 | stalled (6 of 6) | | stalled (6 of 6) | |
| **Charades' best ÷ Devastator's best** (each over layouts and W) | **0.77** | | **0.95** | |

**Shared memory between processes** (C and D):
- The pool now carries the messages: 14.7 M (C) and 12.9 M (D) at 1 node against V3's 15.5 M between processes; 67.0 M and 59.2 M of 71.9 M at 4 nodes.
- Through the pool a send call takes 15.8–16.2 µs (V3 through LCI: 1.97), 18% of PE time at 1 node, and delivery takes a mean of 275–437 µs, median in the 131–262 µs bucket (LCI: 14.5 µs, median 8–16 µs).
- **Why** (Reconverse 22871c6, `cmishmem.cpp`, `scheduler_registered.cpp`): each process's segment has one incoming queue (`shared->queue`) and one block heap, each guarded by an atomic exchange used as a lock. A sender that finds the queue held spins; a receiver that finds it held gives up for that scheduler pass. Every PE takes at most one block per pass. All 23 senders of the other process and all 23 receivers of this one meet on those atomics at about 3 M messages per second per node, so sends wait and blocks sit in the queue for hundreds of µs. This is the pool's design, not a setting. LCI over psm2 spreads the same traffic over 23 devices.
- Charm++'s `--enable-shmem` (C) is 15–19% slower than Reconverse's `+ipc` (D), which falls back to the network more often (83% through the pool against 93–95%).

**Devastator at one process per node:** p1w46 and p4w46 print their setup (layout, 5,120 LPs per rank) and then make no progress for 300 s, at every W and both node counts. p1w1 (V3) and p2w23 run. Its signal slots are an array of counters per thread, so 47 threads do not overflow a bit mask; the cause is unknown and needs an interactive session.

**Wider windows at 1 × 46:** W 5,000 gives 1.11× at 1 node (efficiency 96.4%), but 0.94× at 4 nodes, where copy 2's node sets the pace.

**Per PE (1 node, W 2,500):** at 1 × 46 the least-blocked PE is blocked 49.5% (2 × 23 in V3: 20%), but the PEs that send the most are still the busiest (correlation between blocked share and remote sends −0.85; the layout balances events, not sends). With C, −0.76 and 26.8%.

**Per-copy activity:** identical in all 16 Charades runs at 4 nodes and equal to the Mac's 4-copy run (copy 2 1.478× the mean).

**Predictions (section 200):**
- **Z1 half right.** One count and one digest per cell; Devastator deterministic. Pool messages: A and B 0; C 95% / 93% of V3's count between processes (right); D 83% / 82% (wrong, below 90%).
- **Z2 wrong.** C ÷ A is 0.17 / 0.18, not at least 1.15 / 1.13; C ÷ B is 0.13 / 0.15.
- **Z3 wrong.** D is 1.19× / 1.15× C, not within ±5%.
- **Z4 wrong.** Mean latency through the pool 275–437 µs, not at most 7 µs; send call 16 µs, not at most 1 µs.
- **Z5 half.** Devastator 1 × 46 hung, so its layout ratio is unmeasured. Charades' best ÷ Devastator's best (2 × 23) is 0.77 / 0.95, inside the predicted 0.68–0.80 / 0.88–1.05.
- **Z6 half.** At 1 node the better of W 5,000 / 10,000 ÷ W 2,500 is 1.11 (B) and 1.11 (C), just above 1.00–1.10. At 4 nodes it is 0.94 for B (wrong) and 1.11 for C.
- **Z7 half.** B's least-blocked PE is blocked 49.5% (right, at least 40%), C's 26.8% (wrong). The correlation is −0.85 (B) and −0.76 (C), not at most 0.4 / 0.5 in size.
- **Z8 right.** Same per-copy activity in every run, as on the Mac.

**Reading (section 200's rule):** C is far below 0.90 of B, so **1 × 46 is Charades' VLSI launch**, with Devastator also at its best layout, which needs its 1 × 46 hang understood first. Charm++'s shared memory between processes is not usable at this message rate until Reconverse's pool has per-destination queues and an allocator that senders do not share; that is runtime work.

### §206 · Round 1's settings at 1 and 4 nodes in both engines, and lazy fossils on the other six workloads (job V5 design, 2026-11-03; written before any runs)

> **Status: design; submitted 2026-11-03 as 3678312 (skx-dev; stopped at its own pre-run checks, which wrongly required a VLSI binary in the paper's tree, which predates VLSI; the corrected checks pass on the login node) and again as 3678365 (skx-dev) and 3678366 (skx), before the Devastator diagnosis below (skx-dev had 42 jobs pending; the idev waits on skx), so without Devastator 1 × 46, which follows in its own job if the diagnosis fixes it.** User decision 2026-11-03: go ahead with section 205's next steps. Script `$WORK/charades-runs/v5gap206.slurm` (copy in `~/charades-data/vlsi/`); 5 nodes (the 4-node series and the 1-node series side by side), 2 reps, arm order reversed in rep 2. Trees: `charades-perf` at 5b06d09 (code 512a0b1: the cancel-queue skip, `--fossil-lazy`) on `charm-pads-perf` (Reconverse `pads-perf` with the new pool, section 205), `charades-perfshm` (the same code on Charm++ `--enable-shmem`), and the paper's tree `charades-phaseb` (e1fbdc4, `charm-pads-exp`) for reference. Gate: the change tier on 2 nodes for VLSI, Simple PHOLD, traffic and dragonfly with `--fossil-lazy=1`.

**Devastator at one process per node** (section 202: p1w46 and p4w46 print their setup and stall). On the Mac, a p1w46 VLSI build (GASNet smp conduit, b14, W 2,500) runs and commits the same count as p1w24, with both `opnew=libc` and Devastator's own allocator. The hang is therefore specific to Stampede3: the psm2 conduit, thread pinning (Devastator pins thread t to the t-th CPU of the process's mask), or the launch. It is diagnosed on a 1-node idev (gdb backtraces of every thread).

**Part A: VLSI** (b19 × N, one copy per node, span 1, `--chunk=512`, 5,000 cycles, direct sends, buckets of 2,500 ps unless noted, `--copy-stats=1 --commit-digest=1 --blocked-time=1`):

| arm | layout | settings |
|---|---|---|
| R | 1 × 46 | W 5,000, eager fossils, batch 16 (round 1 before lazy fossils) |
| L | 1 × 46 | `--fossil-lazy=1 --batch=32`, W 2,500 / 5,000 / 10,000 |
| Lc | 1 × 46 | as L, the frozen controller (`--ctl=3 --ctl-bracket=1`), buckets of 5,000 ps |
| I | 2 × 23, Reconverse `+ipc` | as L, W 5,000 |
| S | 2 × 23, Charm++ `--enable-shmem` | as L, W 5,000 |
| N | 2 × 23 over LCI | as L, W 5,000 |
| Devastator | 2 × 23 (and 1 × 46 if it runs) | W 2,500 / 5,000 / 10,000 |

**Part B: lazy fossils on the other workloads** (`charades-perf`, 2 × 23 over LCI, the paper's launch; job N's sizes, htram settings and buckets; dragonfly 13 × 4 routers at 1 node and 16 × 10 at 4, generating 150,000 ns):

| workload | htram | W grid (first = best fixed W in job N / F5) |
|---|---|---|
| phase-changing PHOLD | PP 512 | 100, 150 |
| σ 100 | PP 2,048 | 300, 500 |
| σ 2,000 | PP 512 | 300, 500 |
| uniform | WPs 512 | 300, 500 |
| traffic | PP 2,048 | 500, 750 |
| dragonfly | WPs 512 | 10,000, 20,000 |

Each workload runs eager and lazy fossils at both W and under the frozen controller (6 runs), plus `+ipc` with lazy fossils at the first W, plus the paper's tree at the first W: 8 runs per workload, rep and node count.

**Predictions:**
- **F1.** One committed count per workload and node count over every Charades arm (lazy, `+ipc`, `--enable-shmem`, controller, the paper's tree), with one digest where digests are on; Devastator's VLSI count equals Charades'.
- **F2 (VLSI, 1 node).** L at W 5,000 runs 37–39.5 M ev/s (section 204: 38.1). Charades' best ÷ Devastator's best is 0.82–0.88.
- **F3 (VLSI, 4 nodes).** L at W 5,000 ÷ R is 1.08–1.15. Charades' best W is 5,000. Charades' best ÷ Devastator's best (2 × 23) is 1.00–1.12 (V4: 0.95).
- **F4 (layouts).** At 1 node, I ÷ L (W 5,000) is 0.83–0.90, S is within ±3% of I, and N ÷ L is 0.58–0.66. At 4 nodes, I ÷ L is 0.85–0.95.
- **F5.** The controller (Lc) reaches at least 0.95 of the best fixed W at both node counts.
- **F6 (lazy fossils elsewhere).** At each workload's best fixed W, lazy ÷ eager is 0.97–1.03 at both node counts, and the best W of the two does not move. These workloads advance GVT every few hundred µs, so each update commits few events per PE; VLSI advances it once per clock cycle.
- **F7.** The new tree with eager fossils ÷ the paper's tree at the same W is 1.00–1.04 (the cancel-queue skip, about 8 chares per PE).
- **F8.** `+ipc` ÷ LCI with lazy fossils at the first W is 0.98–1.08: htram already combines the events sent between the node's processes.
- **F9.** If Devastator runs at 1 × 46, its best there ÷ its best at 2 × 23 is 0.95–1.10.

**What follows:**
- `--fossil-lazy=1` becomes the default if lazy ÷ eager is at least 0.98 in every Part B cell (median of the 2 reps, best W and controller, both node counts). Otherwise it stays a per-model setting, reported with VLSI as the bucket width is.
- Charades' VLSI launch is the best of L, I and S per node count. Devastator gets the same choice between 1 × 46 and 2 × 23, or the paper says its 1 × 46 could not be run and why.
- If F3 holds, the VLSI scaling job (1–32 nodes, three engines) follows with these settings. The 1-node gap goes to an event-level trace of clock cycles in Charades (where each cycle's wall time goes along its chain of dependent events), designed in its own section before it runs.

### §207 · Where a VLSI clock cycle's wall time goes: an event-level trace of Charades at 1 × 46 (design, 2026-11-03; written before any Stampede3 trace runs)

> **Status: design.** Section 205's second next step. Tool: `--event-trace-from=<ts> --event-trace-to=<ts>` (new; off by default) and `scripts/stampede3/event_trace.py`. Mac: change tier 30/30 on VLSI and Simple PHOLD at 1 × 4 and 2 × 2 with the hooks built in; a traced b14 run (4 PEs, W 5,000, lazy fossils) reads back with every event's chain resolved.

**What is recorded.** For each event whose timestamp is in the range, each PE writes a record of its send (with the sending event's identity), its arrival in the receiver's pending heap, each forward execution (start and length) and each rollback. While the range is open the PE also records its scheduler passes (start, length, events executed, blocked by the window; a run of passes that executed nothing is one record) and its GVT updates. The records go to `event_trace_<pe>.bin` at the end. Wall times compare only between PEs of one process, so trace runs use 1 × 46 on 1 node.

**What the script computes.** For each clock period inside the range, it takes the committed event of that period whose final execution ends last and follows it back through the events that sent it, up to one period earlier. Each hop splits into the parent's forward up to the send, transit (send to the child's arrival in the heap; a hop to another PE includes the wait in that PE's input buffer), and queue (heap to the child's final execution). Transit and queue are split again by what the receiving PE did meanwhile: executing events with a later timestamp than the child ('later'), executing earlier ones ('earlier'), the rest of passes that executed events ('pass': the engine's per-event work outside `forward`), passes blocked by the window, empty passes, and time between passes ('outside': Converse scheduling, messages, GVT, eager fossils). The cycle's wall time is taken from PE 0's GVT updates.

**Runs (idev, 1 node; b19 × 1, 1 × 46, `--fossil-lazy=1 --batch=32`, buckets of 2,500 ps):** W 5,000 and W 2,500, each traced over cycles 2,000–2,040 and once untraced; Devastator's per-cycle time from the same W (V4: 0.57 ms at W 5,000, 2 × 23).

**Hypotheses for the remaining 1-node gap (Charades 0.66 ms per cycle at W 5,000, Devastator 0.57):**
- **H1, ahead work:** an event sent to another PE waits in its input buffer while that PE finishes a batch of up to 32 later-timestamp events, because the input buffer is drained once per pass. Over a chain of tens of hops between PEs at about 13 µs each, this alone could take most of a cycle.
- **H2, the busiest PEs:** chain events wait in the heap behind earlier-timestamp events on PEs carrying more than their share of the cycle's events.
- **H3, per-pass machinery:** time between passes (re-enqueuing `execute()` through Charm++, the Converse sweep, network polling) and the engine's per-event work outside `forward`.

**Predictions:**
- **T1.** Tracing costs at most 10% of the rate.
- **T2.** At W 5,000 the last event's chain has 20–80 hops, of which at least half go to another PE.
- **T3 (H1).** Transit is the largest part of the chain (at least 40%), and most of it is 'later' plus 'pass' on the receiving PE. At W 2,500 the 'later' share is smaller than at W 5,000.
- **T4.** 'blocked' plus 'empty' is under 15% of the chain at W 5,000: the chain's events are at the frontier, so their receivers are rarely held by the window.

**What follows:**
- T3 right: a frontier event's arrival should preempt the batch. Check the input buffer with one relaxed load per event and drain only when it is not empty (the drain after every event of section 204 paid an exchange per event and lost 6%), or end a pass early when the input buffer holds an event earlier than the next one in the heap.
- 'earlier' dominates (H2): the layout, which balances events per PE but not sends or chain position.
- 'outside' or 'pass' dominates (H3): the scheduler loop. Run passes inside one Converse handler instead of re-enqueuing `execute()` as a message each pass, and cut the engine's per-event work.

### §208 · V5 results: Charades equals Devastator at 4 nodes (1.00) and is 0.85 of it at 1 node; one process per node stays Charades' VLSI launch; lazy fossils lose 4–6% on Gaussian and uniform PHOLD and stay a VLSI setting; on VLSI the controller sits at one bucket, so the bucket width sets W (2026-11-03; skx-dev batch job 3678365, 5 nodes)

> **Status: current.** Design and predictions in section 206.
> - **Job:** gate 60/60; all 224 runs finished in 20 minutes (skx copy 3678366 cancelled). The first submission (3678312) stopped at its own pre-run checks (section 206). Devastator 1 × 46 not run.
> - **Data:** `~/charades-data/vlsi/j3678365/`; summary `~/charades-data/vlsi/v5gap206_summary.py` (output `j3678365_summary.txt`).
> - **Counts (F1 right):** one committed count per cell over every arm and both engines (VLSI 125,998,590 at 1 node, 574,541,914 at 4); one digest per VLSI node count and per traffic and dragonfly cell; Devastator deterministic.

**Part A, VLSI** (b19 × N; M committed ev/s, median of 2 reps (each rep after the slash), higher is better; ms per clock cycle, lower is better):

| arm | 1 node | ms / cycle | 4 nodes | ms / cycle |
|---|---|---|---|---|
| R: 1 × 46, eager fossils, batch 16, W 5,000 | 34.24 (34.15 / 34.33) | 0.736 | 67.20 (59.29 / 75.10) | 1.734 |
| L: 1 × 46, lazy fossils, batch 32, W 2,500 | 33.20 | 0.759 | **81.91 (82.67 / 81.15)** | 1.403 |
| L, W 5,000 | **37.34 (37.72 / 36.95)** | 0.675 | 69.08 (71.19 / 66.96) | 1.665 |
| L, W 10,000 | 35.85 | 0.703 | 59.50 (64.85 / 54.15) | 1.947 |
| Lc: L with the controller, buckets of 5,000 ps (W 5,000 in every round) | 36.68 | 0.687 | 74.76 | 1.537 |
| I: 2 × 23, `+ipc`, as L at W 5,000 | 32.06 | 0.786 | 63.14 | 1.820 |
| S: 2 × 23, Charm++ `--enable-shmem`, as I | 31.98 | 0.788 | 63.24 | 1.817 |
| N: 2 × 23 over LCI, as I | 22.83 | 1.104 | 58.84 | 1.953 |
| Devastator 2 × 23, W 2,500 | 40.25 | 0.626 | **81.85 (81.15 / 82.55)** | 1.404 |
| Devastator, W 5,000 | 42.98 | 0.586 | 46.95 (77.80 / **16.11**) | 4.305 |
| Devastator, W 10,000 | **43.80 (43.95 / 43.64)** | 0.575 | 81.42 | 1.411 |
| **Charades' best ÷ Devastator's best** | **0.853** | | **1.001** | |

- **At 1 node** the gap is section 204's: 37.3 against 43.8 M ev/s, 0.675 against 0.575 ms per cycle.
- **At 4 nodes** both engines run 1.40 ms per cycle at W 2,500. The node holding copy 2 (1.75× the median copy's activity, section 201) sets both engines' pace. Wider windows lose for Charades here (W 5,000 0.84 of W 2,500), and the 4-node reps of R, L W 10,000 and Devastator W 5,000 differ by up to 4.8× (Devastator 77.8 against 16.1). Only W 2,500 repeats within 2% in both engines.
- **Layouts:** sending between the node's two processes through the new pool gives 0.86 (1 node) and 0.91 (4 nodes) of one process per node, against 0.61 / 0.85 over LCI. Charm++'s `--enable-shmem` and Reconverse's `+ipc` are within 0.3% of each other. **One process per node stays Charades' VLSI launch.**
- **The controller on VLSI:** its W was 5,000 ps (one bucket) in every round of all four runs, as it was 2,500 with buckets of 2,500 (section 205). Its smallest W is one bucket and it never widens from there, so on VLSI the bucket width sets W. Buckets of 5,000 ps give 0.98 of the best fixed W at 1 node (best W 5,000) and 0.91 at 4 nodes (best W 2,500). Buckets of 2,500 would give about 0.89 at 1 node and 1.00 at 4.

**Part B, lazy fossils elsewhere** (2 × 23 over LCI; median M committed ev/s of 2 reps at the better of the two W; ratios higher is better):

| workload | nodes | eager | lazy ÷ eager, best W / controller | eager ÷ the paper's tree (first W) | `+ipc` ÷ LCI, lazy (first W) |
|---|---|---|---|---|---|
| phase-changing PHOLD | 1 | 38.53 | 0.977 / 1.038 | 0.998 | 1.099 |
| | 4 | 116.12 | 1.058 / 0.965 | 0.964 | 1.007 |
| σ 100 | 1 | 45.63 | **0.951** / 0.953 | 0.994 | 1.002 |
| | 4 | 178.72 | **0.954** / 0.956 | 1.032 | 1.003 |
| σ 2,000 | 1 | 37.77 | **0.945** / 0.943 | 1.003 | 1.008 |
| | 4 | 138.80 | **0.939** / 0.943 | 1.005 | 1.020 |
| uniform | 1 | 39.99 | **0.943** / 0.957 | 0.998 | 1.032 |
| | 4 | 121.04 | **0.848** / 0.970 | 1.003 | 1.117 |
| traffic | 1 | 66.62 | 0.979 / 0.963 | 1.058 | 1.041 |
| | 4 | 252.19 | 1.008 / 0.999 | 1.048 | 0.985 |
| dragonfly | 1 | 38.96 | 1.013 / 0.998 | 1.061 | 1.072 |
| | 4 | 111.04 | 1.003 / 0.955 | 1.032 | 0.971 |

- **Lazy fossils lose 4–6% on Gaussian and uniform PHOLD** at both node counts, in both reps, at the best W and under the controller. The share of time blocked at the window rises with them at W 300: from 14.4 to 17.7% (σ 100, 1 node), 15.9 to 19.4% (σ 2,000), 17.1 to 22.8% (uniform); at 4 nodes 18.1 to 21.3%, 22.5 to 27.1%, 23.6 to 39.9%. Uniform at 4 nodes includes one lazy run at 89.0 with 48% blocked (the other rep 116.4, 31%). On traffic, dragonfly and phase-changing PHOLD they are within −4% to +6%.
- **The new tree with eager fossils against the paper's tree** is 0.96–1.06: unchanged on PHOLD, 1.03–1.06 on traffic and dragonfly.
- **`+ipc` with htram** is 0.97–1.12 of LCI: up to 1.10 at 1 node (phase-changing PHOLD) and within ±3% on most cells. Uniform at 4 nodes (1.117) is set against the slow lazy run above (against its other rep, 0.99).

**Predictions (section 206):**
- **F1 right.**
- **F2 right:** L at W 5,000 37.3 M ev/s; Charades ÷ Devastator 0.853.
- **F3 one part of three:** Charades ÷ Devastator at 4 nodes is 1.001 (inside 1.00–1.12, at its edge). But L ÷ R at W 5,000 is 1.03, not 1.08–1.15 (R's reps 59.3 / 75.1), and Charades' best W is 2,500, not 5,000.
- **F4 right:** I ÷ L 0.859 / 0.914, S ÷ I 0.997 / 1.002, N ÷ L 0.611 at 1 node.
- **F5 half:** 0.98 at 1 node; 0.91 at 4 nodes, where the controller's one bucket (5,000) is not the best W.
- **F6 wrong:** lazy ÷ eager is 0.94–0.95 on three of six workloads, not 0.97–1.03.
- **F7 half:** 0.96–1.06, not 1.00–1.04; outside it on traffic and dragonfly (above) and phase-changing PHOLD at 4 nodes (below).
- **F8 mostly right:** 10 of 12 cells inside 0.98–1.08.
- **F9 not run.**

**What follows (section 206's rules):**
- **`--fossil-lazy` stays off by default** and is a VLSI setting, reported with it as the bucket width is. The paper's other numbers are unchanged; the new tree is within 0.96–1.06 of the paper's tree on them.
- **One process per node is Charades' VLSI launch** at 1 and 4 nodes. Devastator needs the same choice, which waits on its 1 × 46 hang.
- **VLSI's bucket width (the controller's W):** 2,500 ps for the scaling runs. From 4 nodes on, copy 2's node sets the pace and W 2,500 is best in both engines, and runs at W 5,000 vary up to 4.8× between reps there.
- **F3 did not clearly hold**, and the 1-node gap (0.85) is unchanged by this job. Section 207's trace runs next. The VLSI scaling job waits on the trace and on Devastator 1 × 46.

### §209 · Devastator's 1 × 46 hang was PSM2 pinning every thread to core 0; at the same layout the engines are level (Charades 37.3, Devastator 37.6 M ev/s), and Devastator's two-process gain is socket locality, to which Charades is nearly insensitive; the trace finds no ahead-work delay (2026-11-03; idev 3678539, c454-032)

> **Status: current.** Section 207's trace design and section 206's Devastator question. Scripts `$WORK/charades-runs/{devap1.sh, dvq.sh, cmp1n.sh, cyc.py}`; data `~/charades-data/vlsi/idev3678539/` (traces themselves left on Stampede3, `cmp1n/et2/`). b19 × 1, 1 node; every run commits 125,998,590 events (Charades digest 87c11aec… in every run).

**The Devastator hang.** At 1 × 46 (`-c 48`) all 48 threads of the process ran on CPU 0 (`ps -L`: PSR 0, 2.1% CPU each; every thread's affinity `0`). Devastator pins thread t to the t-th CPU of the mask it reads at start-up, and that mask held only CPU 0. PSM2, under GASNet's ofi conduit, binds a process that is bound to the whole node to one core near the adapter, so every thread inherited core 0. A process bound to a socket's 24 cores (2 × 23) is left alone. With `HFI_NO_CPUAFFINITY=1` (PSM2's switch to turn this off) the run takes 3.3 s at W 5,000. 2 × 23 does not change with it (44.2 / 44.1 without, 43.5 / 43.0 with), so earlier Devastator numbers stand. Round 1's single-worker rate (1.59, `-c 24`) also stands; bound to the whole node, p1w1 has its two threads on one core.

**Devastator's layouts** (M committed ev/s, 2 reps, higher is better):

| Devastator | W 2,500 | W 5,000 | W 10,000 |
|---|---|---|---|
| 1 × 46 (`HFI_NO_CPUAFFINITY=1`) | 34.6 / 35.9 | 37.8 / 37.4 | 36.7 / 38.3 (later 38.5 / 38.2) |
| 2 × 23, each process on one socket | 40.1 / 40.5 | 42.7 / 43.1 | 43.7 / 43.6 (later 44.3 / 44.1, 43.7 / 43.6) |
| 2 × 23, each process on cores 0–23 / 24–47 (both sockets) | | | **28.4 / 28.1** |

- **Its best layout is 2 × 23:** 1 × 46 is 0.87 of it (F9 wrong: 0.95–1.10). So V5's comparison, Charades at 1 × 46 against Devastator at 2 × 23, has each engine at its best layout at 1 node. The 4-node comparison (p4w46) needs a batch run with `HFI_NO_CPUAFFINITY=1`.
- **At the same layout the engines are level:** Devastator 1 × 46 runs 37.6 (W 5,000), Charades 1 × 46 37.3 (V5).
- **Devastator's 2 × 23 gain is socket locality.** Spreading each process over both sockets costs it 0.65×, more than 1 × 46 does. Its threads exchange events through shared-memory queues, and those queues are slow across sockets.
- **Charades is nearly insensitive to it.** At 1 × 46 with the PEs alternating sockets (`+pemap 2-47`, so neighbouring PEs in the layout sit on different sockets), Charades runs 36.0 / 35.9, against 37.3 / 37.5 with each socket's PEs in a block: 0.96×.
- **Reading:** Devastator at 1 × 46 pays a large cross-socket cost and still equals Charades. Kept within a socket, Devastator does about 1.16× Charades' work per unit time. The remaining 1-node gap is Charades' own work per event and per pass, not the layout.

**The trace** (Charades 1 × 46, `--fossil-lazy=1 --batch=32`, W 5,000, cycles 2,000–2,040):
- **T1 wrong.** The run's overall rate does not move with the trace (37.39 / 37.06 against 37.39 / 36.84 untraced), but that was the wrong test: the traced range is under 1% of the run. Per `--gvt-trace=1`, the traced cycles took 1.40 ms against 0.665 untraced. Growing the trace buffer mid-range stalled PEs; allocating it before the run (`--event-trace-max`, charades 4844b20) brings the traced cycles to 0.829 / 0.814 ms against 0.639 / 0.644 untraced, so the trace still adds about 28% inside its range (timer reads, at 24.7 ns each, and the records). The breakdown below carries that inflation, mostly in 'pass'.
- **T2 half:** the chain of each cycle's last event has 27–31 hops (mean 29.7); the share that crosses PEs was not computed.
- **T3 wrong.** Transit (send to the receiver's heap) is 14% of the chain and 'later' (the receiver executing later-timestamp events) 1–2%. Ahead work is not the delay.
- **T4 wrong.** 'blocked' is 25–27% of the chain (16% counting only the period's own chain).

| share of the chain (2 traces, `--back 1`; `--back 0` in brackets) | |
|---|---|
| queue (in the receiver's heap until its final execution) | 85% / 85% (79%) |
| transit | 14% / 14% (20%) |
| receiver executing earlier or equal-timestamp events | 36% / 33% (39%) |
| receiver in a pass, not executing (the engine's per-event work outside `forward`; trace cost included) | 34% / 36% (40%) |
| receiver blocked by the window | 25% / 27% (16%) |
| receiver between passes | 2% |

**Profile** (Charades 1 × 46, lazy fossils, batch 32, W 5,000; user cycles of the process, spinning while blocked included): the runtime takes 37% (`libreconverse`), Charades and the model 55%, libc 7%.
- **Runtime per pass:** network progress with nothing to receive 13.9% (`comm_backend::progress`); re-enqueuing `execute()` as a Charm++ message about 5% (`CkSendMsgBranch`, `CkAllocSysMsg`, `_processHandler`, `CmiCallHandler`); Converse queue polling about 6%; mutex lock and unlock 2.7%.
- **Engine per event:** fast-path drain 4.5%, `event_alloc` 4.1%, `remote_event_delete` 3.8%, `execute_me` 3.8%, `fossil_me` 2.6%, `fp_push` 1.8%, glibc free and malloc 2.6%.
- `CmiNodeBarrier` (3.9%) and `clcg4::seed` (1.5%) are setup, as in section 204.

**What follows:**
- **Paper fairness:** Devastator's best layout is two processes per node at 1 node. Its 4-node 1 × 46 runs go into the VLSI scaling job with `HFI_NO_CPUAFFINITY=1`.
- **Closing the 1-node gap means cutting Charades' work per event and per pass, not changing the layout.** In order of the profile:
  1. A pass that does not poll the network when the run has one process, or polls it every k passes.
  2. Running passes in a loop inside one Converse handler instead of re-sending `execute()` to itself as a message.
  3. Fewer allocations and frees per event (the message pool and `event_alloc`).
- Each is to be measured on its own, with section 207's trace and `--gvt-trace=1` cycle times, before the next.

### §212 · VLSI at 1–32 nodes in three engines, each at its best launch (job VS design, 2026-11-03; written before any runs)

> **Status: design.** User decision 2026-11-03: queue the scaling job now, and work on round 3 (per-event work) on the Mac while it waits. Script `$WORK/charades-runs/vscale212.slurm` (copy in `~/charades-data/vlsi/`); its pre-run checks pass on the login node. Trees:
> - Charades `charades-perf` at 5b14290 on `charm-pads-perf`. That is Reconverse `pads-perf` (the pool rewrite and round 2's commits), which is not yet on a published branch.
> - Devastator's VLSI binaries are built from `charades-vlsi`'s model header, as in V1 and vbuild200. The 1 × 46 binaries for 2, 8, 16 and 32 nodes are built inside the jobs, on a node the runs do not use at that time.
> - ROSS as in V1.
>
> Gate: the change tier on 2 nodes, VLSI, with `--fossil-lazy=1`.

**Why now.** Section 209 left two things before the VLSI scaling job: Devastator at one process per node, now fixed with `HFI_NO_CPUAFFINITY=1`, and the 1-node gap. Round 2 (section 211) did not move the gap. At 4 nodes the engines are already level (1.00, section 208). Round 3 continues on the Mac in parallel. If it pays, only Charades' cells are rerun.

**Workload.** b19 × N, one copy per node, span 1, `--chunk=512`, 5,000 clock cycles (end 12,500,000 ps). From 3 nodes on, node 2 holds the copy that does 1.75× the work of the others and sets every engine's pace (section 201; reported as it is, user decision 2026-11-03). `--copy-stats=1` on every Charades run.

**Arms (each engine at its best launch):**

| engine | layout per node | arms |
|---|---|---|
| Charades | 1 process × 46 PEs, direct sends, `--fossil-lazy=1 --batch=32`, buckets of 2,500 ps, `--localalloc` launch | the frozen controller (`--ctl=3` bracketed); W 2,500; W 5,000 |
| Devastator | 2 processes × 23 workers, each on one socket | W 2,500 / 5,000 / 10,000 |
| | 1 × 46, `HFI_NO_CPUAFFINITY=1` | W 2,500 / 5,000 / 10,000 |
| ROSS | 46 ranks, optimistic, `--read-buffer=1`, GVT interval 64 | batch 8 with `--max-opt-lookahead` 2,500 and 5,000; batch 2 with 5,000 (V1's best at 1 and 4 nodes) |

**Jobs:**
- **a** (skx-dev, 16 nodes): the 8-, 4-, 2- and 1-node series side by side, then 16 nodes alone. 3 reps. The engines are interleaved per rep, and engine and arm order are reversed in even reps.
- **big** (skx, 32 nodes): 32 nodes, 5 reps (32-node reps vary more; section 188).
- Each stream starts with one short Charades run (500 cycles) to warm the file system. An arm of Devastator or ROSS that hits its cap in rep 1 is skipped after that. Caps: Charades and Devastator 300 s, ROSS 240 s.
- Estimate: about 60 minutes for a and 50 for big.

**What is known** (M committed ev/s, higher is better):

| | 1 node | 4 nodes |
|---|---|---|
| Charades 1 × 46 | 37.3 (W 5,000) | 81.9 (W 2,500) |
| Devastator 2 × 23 | 43.8 (W 10,000) | 81.9 (W 2,500) |
| Devastator 1 × 46 | 37.6–38.5 | not run |
| ROSS | 3.3 | 7.8 |

The per-node rate at 4 nodes ÷ at 1 is 0.55 for Charades and 0.47 for Devastator.

**Predictions:**
- **S1. Counts.** At each node count, every run of every engine commits the same events. Charades has one digest per node count, and Devastator reports itself deterministic.
- **S2. Charades' best ÷ Devastator's best** (each over its layouts and W; higher is better):
  - 0.82–0.88 at 1 node;
  - 0.83–0.98 at 2;
  - 0.95–1.05 at 4;
  - 0.95–1.10 at 8, 16 and 32.

  From 3 nodes on, node 2 paces both engines (V5: both 1.40 ms per cycle at 4 nodes). Neither engine sends much between nodes on this layout: only the ring's links between copies cross nodes.
- **S3. Devastator's best layout is 2 × 23 at every node count.** Its 1 × 46 is 0.82–0.95 of it: the socket-locality gain (section 209) applies on every node, including the pacing one. 1 × 46 runs at every node count.
- **S4. Charades' best fixed W** is 5,000 at 1 and 2 nodes and 2,500 from 4 nodes on.
  - The controller runs at W 2,500 in every round and is within ±3% of W 2,500 in every cell.
  - That makes it 0.97 or more of the best fixed W from 4 nodes on, and 0.86–0.92 at 1 and 2 nodes.
- **S5. Rep spread.**
  - At W 2,500, reps stay within ±5% in both engines at every node count.
  - At W 5,000, at least one cell at 4–32 nodes varies by more than 20% between reps, in some engine.
- **S6. Scaling** (per-node rate at 32 nodes ÷ at 1, each engine at its best; 1.0 is perfect):
  - Charades 0.40–0.52; Devastator 0.35–0.47; Charades' is the higher.
  - From 4 to 32 nodes the pacing copy stays the same, so the further loss is GVT and the ring's messages: 0.80–0.95 per node in both engines.
- **S7. ROSS.** Charades ÷ ROSS is 5–9 at every node count (V1: 6.9–7.9). ROSS's best is batch 8 with 2,500 from 4 nodes on.

**What follows:**
- **The paper.** VLSI goes into the applications table with these cells. Charades is reported with its controller, and the bucket width (2,500 ps) and lazy fossils as VLSI's settings. Devastator is reported with its better layout per node count. The paper states the per-copy activity.
- **If round 3 gains at least 3% on the 1-node VLSI rate:** Charades' arms are rerun on the new tree at all node counts in a Charades-only job.
- **If S6 fails for Charades** (it loses more per node than Devastator from 4 to 32 nodes): `--gvt-trace=1` cycle times at 4 and 32 nodes, to separate GVT pace from the pacing node.
- **Before the paper's runs are final:** the Reconverse `pads-perf` commits are published.

### §214 · VS results at 1–16 nodes: Charades ÷ Devastator 0.84 / 0.91 / 0.99 / 0.97 / 0.89; one count per cell; from 4 nodes on Devastator's clock cycle stays at 1.38–1.41 ms while Charades' grows from 1.39 to 1.57 ms (2026-11-03; skx-dev batch job 3679723, 16 nodes)

> **Status: current for 1–16 nodes; 32 nodes (job big, 3679725) pending.** Design and predictions in section 212.
> - **Job:** gate 27/27; 41 minutes (skx copy 3679724 cancelled). Devastator's 1 × 46 binaries for 2, 8 and 16 nodes were built in the job, in 81 s. Every run finished.
> - **Data:** `~/charades-data/vlsi/vscale212/a_j3679723/`; summary `~/charades-data/vlsi/vscale212_summary.py`.
> - **Counts (S1 right at 1–16 nodes):** one committed count per node count over all three engines (125,998,590 / 252,049,665 / 574,541,914 / 1,078,843,202 / 2,087,384,844); one Charades digest per node count; Devastator deterministic in every run.

**Each engine at its best** (M committed ev/s, median of 3 reps, higher is better; ms per clock cycle, lower is better):

| nodes | Charades (1 × 46) | Devastator (2 × 23) | ROSS | Charades ÷ Devastator | Charades ÷ ROSS | ms per cycle, Charades / Devastator |
|---|---|---|---|---|---|---|
| 1 | 38.30 (W 5,000) | 45.65 (W 10,000) | 3.38 (batch 2, 5,000) | **0.839** | 11.3 | 0.658 / 0.552 |
| 2 | 78.03 (W 5,000) | 85.91 (W 10,000) | 5.63 (batch 2, 5,000) | **0.908** | 13.9 | 0.646 / 0.587 |
| 4 | 82.55 (W 2,500) | 83.43 (W 2,500) | 7.94 (batch 8, 2,500) | **0.989** | 10.4 | 1.392 / 1.377 |
| 8 | 149.84 (W 2,500) | 155.28 (W 10,000) | 14.22 (batch 8, 2,500) | **0.965** | 10.5 | 1.440 / 1.390 |
| 16 | 265.23 (W 2,500) | 297.09 (W 10,000) | 26.04 (batch 8, 2,500) | **0.893** | 10.2 | 1.574 / 1.405 |

**Other quantities** (higher is better; per-node rate ÷ at 1 node, 1.0 is perfect):

| nodes | Devastator 1 × 46 ÷ 2 × 23 (each at its best W) | Charades' controller ÷ W 2,500 | controller ÷ Charades' best fixed W | per-node rate ÷ at 1 node, Charades / Devastator / ROSS |
|---|---|---|---|---|
| 1 | 0.857 | 0.968 | 0.873 | 1 / 1 / 1 |
| 2 | 0.849 | 0.988 | 0.764 | 1.019 / 0.941 / 0.833 |
| 4 | 0.796 | 0.979 | 0.979 | 0.539 / 0.457 / 0.587 |
| 8 | 0.814 | 0.984 | 0.984 | 0.489 / 0.425 / 0.526 |
| 16 | 0.843 | 0.989 | 0.989 | 0.433 / 0.407 / 0.482 |

- **At 1–2 nodes** Devastator leads by its two-process layout, as section 209 found (its one-process layout is 0.85 of it).
- **At 4 nodes the engines are level.** Node 2 holds the copy that does 1.75× the work, and it paces both engines at about 1.38 ms per cycle.
- **From 4 to 16 nodes** Devastator's cycle time stays at 1.38–1.41 ms, still paced by node 2. Charades' grows from 1.39 to 1.44 to 1.57 ms, and its blocked share rises from 79.5% to 81.5% to 83.8%. Charades keeps 0.80 of its per-node rate from 4 to 16 nodes, against Devastator's 0.89. Charades' window is one bucket, one clock period, so each cycle waits for a GVT advance, and the advance takes longer on more nodes. Devastator's asynchronous GVT does not hold its cycle this way. Neither cause is measured yet.
- **Devastator's 1 × 46** is 0.80–0.86 of its 2 × 23 at every node count; 2 × 23 is its best layout throughout.
- **Rep spread:**
  - Charades W 2,500 at 4 nodes: one rep 0.89 of the others (73.75 against 82.6–83.2);
  - Devastator 2 × 23 W 10,000 at 8 nodes: one rep at 0.34 (52.9 against 155);
  - every other arm within 1.09.
- **ROSS** with its window runs 3.4–26 M ev/s. Charades is 10–14× faster, about 1.5× V1's ratio because Charades has sped up since then (V1: 22 M ev/s at 1 node on 2 × 23).

**Predictions (section 212), 1–16 nodes:**
- **S1 right.**
- **S2 four of five:** 0.839 (1 node), 0.908 (2), 0.989 (4), 0.965 (8) inside their ranges; 0.893 at 16 nodes, under 0.95–1.10.
- **S3 mostly right:** 2 × 23 is Devastator's best layout at every node count; 1 × 46 is 0.80–0.86 of it, under 0.82 at 4 and 8 nodes.
- **S4 mostly right:**
  - best fixed W is 5,000 at 1–2 nodes and 2,500 from 4 on;
  - the controller is 0.97–0.99 of W 2,500 everywhere and 0.98–0.99 of the best fixed W from 4 nodes on;
  - but 0.76, not 0.86–0.92, at 2 nodes.
- **S5 wrong:** W 2,500 strayed beyond ±5% once (Charades, 4 nodes). The run that strayed by more than 20% was Devastator at W 10,000, not W 5,000.
- **S6 waits on 32 nodes.** At 16 nodes Charades' per-node rate ÷ at 1 node (0.433) is still above Devastator's (0.407), but from 4 nodes on Charades loses more per node.
- **S7 wrong:** Charades ÷ ROSS is 10–14, not 5–9. ROSS's best is batch 8 / 2,500 from 4 nodes on, as predicted.

**What follows:**
- Job big (32 nodes) completes the table.
- Section 212's S6 rule applies already: `--gvt-trace=1` cycle times at 4 and 16–32 nodes, to split Charades' growing cycle time into GVT advance and execution. One process per node with W at one clock period makes each cycle wait for a GVT round. That is a GVT-pace question, as on PHOLD at 32 nodes (sections 78–84), not a per-event one.
- Round 3 (section 213) is measured separately; its 3% rule for rerunning the Charades cells stands.

### §226 · VS2 at 32 nodes (big2): Charades ÷ Devastator on VLSI falls to 1.05 (per rep 0.96–1.07); from 16 to 32 nodes Charades' clock cycle grows by 14%, almost all of it the count wave in flight, while Devastator's cycle stays flat (2026-11-04; skx batch job 3679976, 32 nodes)

> **Status: current.** Design and predictions in section 216; 1–16 nodes in section 217.
> - **Job:** 53 minutes; gate 27/27; no run failed or hit the cap. One old-tree run (W 2,500, rep 4) took 142 s of wall time against about 25 s, with a normal execution time (9.82 s): the delay came before the simulation started. Devastator 2 × 23 at W 2,500, rep 1, ran 34.2 s against 7.8–9.0 s in the other reps; it stays in the median, which it does not move.
> - **Data:** `~/charades-data/vlsi/vscale216/big2_j3679976/` (with `job.out`). `vscale216_summary.py` now also prints per-rep ratios; output for 1–32 nodes (this job, a2 and job a) in `vscale216_big2_summary.txt`.
> - **Counts (Q1 right):** 4,104,430,712 committed events in all three engines, both Devastator layouts and both Charades trees. Round 3 and the old tree share the digest (6331beff…).

**Every arm at 32 nodes** (M committed ev/s, median of 5 reps, higher is better; max ÷ min over the reps, 1.00 is no spread):

| engine | arm | M ev/s | max ÷ min |
|---|---|---|---|
| Charades, round 3 (1 × 46) | W 2,500 | **603.59** | 1.19 |
| | the controller (holds W 2,500) | 561.48 | 1.21 |
| | W 5,000 | 550.93 | 1.03 |
| Charades, old tree (1 × 46) | W 5,000 | 504.23 | 1.09 |
| | the controller | 448.08 | 1.02 |
| | W 2,500 | 431.59 | 1.08 |
| Devastator 2 × 23 | W 10,000 | **576.93** | 1.01 |
| | W 5,000 | 565.77 | 1.08 |
| | W 2,500 | 467.08 | 4.41 (1.17 without rep 1) |
| Devastator 1 × 46 | W 10,000 | 462.69 | 1.04 |
| ROSS | batch 8, GVT interval 64, window 2,500 ps | 40.50 (efficiency 75%) | 1.02 |

**VLSI at 1–32 nodes, each engine at its best arm** (M committed ev/s, median of 3 reps, 5 at 32; Charades round 3 at 1 × 46, Devastator 2 × 23 in the same allocation; ratios higher is better for Charades; ms per clock cycle lower is better):

| nodes | Charades | Devastator | **Charades ÷ Devastator** (ratio of medians) | Charades ÷ Devastator per rep | Charades' controller ÷ Devastator | ms per cycle, Charades / Devastator |
|---|---|---|---|---|---|---|
| 1 | 61.76 (W 5,000) | 45.26 (W 10,000) | **1.365** | 1.358–1.381 | 1.136 | 0.408 / 0.557 |
| 2 | 108.18 (W 5,000) | 85.43 (W 10,000) | **1.266** | 1.263–1.277 | 0.908 | 0.466 / 0.590 |
| 4 | 103.33 (W 2,500) | 83.75 (W 2,500) | **1.234** | 1.215–1.234 | 1.210 | 1.112 / 1.372 |
| 8 | 192.31 (W 2,500) | 149.05 (W 10,000) | **1.290** | 1.274–1.293 | 1.272 | 1.122 / 1.448 |
| 16 | 351.41 (the controller) | 295.49 (W 5,000) | **1.189** | 1.175–1.197 | 1.189 | 1.188 / 1.413 |
| 32 | 603.59 (W 2,500) | 576.93 (W 10,000) | **1.046** | 0.958–1.065 | 0.973 | 1.360 / 1.423 |

- **At 32 nodes the engines are level:** Charades ÷ Devastator is 0.958 / 1.058 / 1.044 / 0.972 / 1.065 in reps 1–5 (engines interleaved in each rep). Charades leads by 1.19–1.37 at 1–16 nodes.
- **From 16 to 32 nodes Charades' cycle grows from 1.188 to 1.360 ms (+14%); Devastator's from 1.413 to 1.423 ms (+0.7%).** Per-node rate from 16 to 32 nodes (1.0 is perfect): Charades 0.859, Devastator 0.976. From 4 to 32 nodes: Charades 0.730, Devastator 0.861. (The old tree: 0.951 from 16 to 32 and 0.764 from 4 to 32, its 16-node cell from job a.)
- **Round 3 ÷ the old tree at 32 nodes: 1.197** (each at its best arm, same allocation).
- **Devastator 1 × 46 ÷ 2 × 23: 0.80** at 32 nodes.
- **Charades ÷ ROSS: 14.9** (ROSS's best of three settings, with its window).

**The cycle split** (`--gvt-trace=1`, W 2,500, cycles 1,000–4,000; about two count waves per cycle; one run per node count; the 32-node traced run ran at 609 M ev/s, among the fast reps):

| nodes | ms per cycle | count wave in flight, ms per cycle | ms per wave | between waves, ms per cycle |
|---|---|---|---|---|
| 4 | 1.172 | 0.149 (12.7%) | 0.073 | 1.023 |
| 8 | 1.111 | 0.169 (15.2%) | 0.083 | 0.941 |
| 16 | 1.173 | 0.215 (18.3%) | 0.106 | 0.958 |
| 32 | 1.284 | 0.319 (24.8%) | 0.157 | 0.965 |

- **From 16 to 32 nodes the traced cycle grows 0.111 ms, and the wave in flight grows 0.104 ms of it (94%).** The time between waves, set by node 2's busiest copy, grows 0.007 ms.
- From 4 to 32 nodes the wave in flight grows 0.170 ms while the time between waves shrinks 0.058 ms; the waves account for more than the cycle's whole growth (0.112 ms).
- Each wave takes 0.157 ms at 32 nodes, against 0.073 ms at 4 and 0.106 ms at 16. At W one clock period each cycle needs a GVT advance, so the wave's latency is on every cycle's path. Devastator's best window at 32 nodes is four periods (W 10,000).
- **Not measured here:** why each wave takes longer at 32 nodes. Section 228 answers it from this data: two thirds of the growth is slow waves that come with the 32-node allocation.
- The untraced W 2,500 cycle grows more than the traced one (+0.172 ms against +0.111 ms from 16 to 32 nodes). The traced run is one fast run and counts only cycles 1,000–4,000; the medians include the slow reps below.

**The spread at W 2,500.** At one clock period both engines vary between reps at 32 nodes: Charades 518–615 M ev/s (1.19), Devastator 454–529 M ev/s without its outlier (1.17). Their wider windows are steady (Charades W 5,000 1.03, Devastator W 10,000 1.01). At 1–16 nodes Charades' W 2,500 varied by 1.01–1.04. Our reading, not tested: at W one period each cycle waits for every PE's contribution to the wave, so a delay on any of the 32 nodes delays the cycle, and a wider window lets PEs run past it.

**The controller at 32 nodes.**
- It holds W at 2,500 in every run (its range from the delay histogram is one bucket, as at 1–16 nodes), so it runs the same window as the W 2,500 arm.
- **It runs at 0.90–1.00 of W 2,500 in each rep (median 0.935), slower in all five.** At 1–16 nodes it was 0.97–1.02 per rep. Arm order alternates between reps (the controller first in odd reps, last in even), so order does not explain it.
- It adds no count waves (10,110–10,192 against 10,130–10,138 per run). Its PEs' blocked spells at the window are longer in every rep (mean 69–87 µs against 67–83 µs).
- **Not measured here:** where the controller's extra time goes. Section 228: slow stretches; its steady cost is nil.
- Against the best arm at 32 nodes it is 0.930, inside claim 2's 0.91–1.03; Charades' controller ÷ Devastator is 0.973.

**Predictions (section 216), now with 32 nodes:**
- **Q1 right** at 32 nodes as well.
- **Q2 five of six:** round 3 ÷ the old tree at 32 nodes is 1.197, inside 1.15–1.50.
- **Q3 wrong at 32 nodes, narrowly:** 1.046, not at least 1.05; per rep 0.96–1.07. Right at 1–16 nodes.
- **Q4** covered 4 → 16 nodes only. From 4 to 32 nodes Charades' per-node rate is 0.730 against Devastator's 0.861.
- **Q5 right at 32 nodes:** from 16 to 32 the count wave's growth is 94% of the traced cycle's growth, and from 4 to 32 it is more than all of it. From 4 to 16 (section 217) the split was within the trace's noise.

**What follows:**
- **F5's VLSI row is complete:** Charades ÷ Devastator 1.37 / 1.27 / 1.23 / 1.29 / 1.19 / 1.05 at 1 / 2 / 4 / 8 / 16 / 32 nodes, one committed count per cell in all three engines.
- **The paper says where VLSI's scaling stops:** at W one clock period Charades needs a GVT advance every cycle, and from 16 to 32 nodes the count wave's latency is what grows. Section 216 named this as the design limit; this job measures it.
- Making the wave faster at 32 nodes and beyond (the user's 64–256-node goal) would start with why a wave takes 0.157 ms. Not scheduled: the user's decision.

### §228 · Why VLSI's lead shrinks at 32 nodes, from data already taken: two thirds of the cycle's growth is slow count waves that come with the 32-node allocation, one third the waves' cross-process time; the controller has no steady cost; a wider window is immune but slower (2026-11-05; offline, no new runs; jobs VS2 a2 3679974 and big2 3679976, PHOLD jobs E16 3660089 and E 3660196)

> **Status: current.** Reads section 226's data further and answers its two "not measured" items: why a wave takes longer at 32 nodes, and the controller's 0.90–1.00.
> - **Script:** `~/charades-data/vlsi/vs2_offline228.py` (run in `vscale216/`); output `vs2_offline228.txt`.
> - **Sources:** PE 0's wave records (`--gvt-trace=1`, cycles 1,000–4,000) and every run's progress lines (wall time every 64 GVT advances, that is 64 clock cycles). GVT code read at 8a34d51; it is unchanged since the runs' tree (ae0dbd3) apart from held-event bookkeeping, which is off by default.

**How a clock cycle uses the GVT at W one period** (`src/gvt/bucketed.C`):
- **Per advance:** one start reduction (a minimum over all PEs) and two count waves. At 32 nodes the traced run made 5,182 start reductions and 10,198 count waves for 5,000 advances.
- **Why two:** a bucket completes only when every PE had passed it at the previous wave, and that wave's received total equals this wave's sent total.
- **One wave:**
  - Each PE writes its counts into its process's slot. The last of the 46 PEs combines them, and the process joins a reduction across processes: a tree with fan-out 4, so 1, 2, 2 and 3 levels at 4, 8, 16 and 32 processes (section 117).
  - The result is broadcast back down the tree. Each PE picks it up at the top of its next scheduler pass. On VLSI the PEs sit blocked at the window during the waves, so a pass takes about 0.5 µs.
- **One hop** is a node-level message. It runs when a PE that polls the receiving LCI device gets to it: about 4 µs on the network, the rest waiting (section 118).

**Per-wave latency at PE 0** (µs, lower is better; one traced run per node count; the three middle columns are medians; the last column counts waves over 2× the median):

| nodes | median | mean | inside the process (start → combined) | across processes (combined → result) | pickup | slow waves (share of wave time) |
|---|---|---|---|---|---|---|
| 4 | 67.5 | 73.5 | 26.4 | 41.5 | 1.9 | 0.4% (15%) |
| 8 | 83.9 | 83.4 | 23.9 | 60.8 | 1.6 | 0.8% (4%) |
| 16 | 107.1 | 106.4 | 22.8 | 82.5 | 1.5 | 0.9% (4%) |
| 32 | 127.3 | 156.9 | 25.5 | 100.6 | 1.5 | **7.8% (25%)** |

- **All of the steady growth is across processes:** 42 → 101 µs from 4 to 32 nodes. The part inside the process (23–26 µs) and the pickup (1.5–1.9 µs) stay flat.
- **From 16 to 32 nodes the traced cycle grows 0.111 ms** (section 226):
  - waves of at most twice the median add 31 µs per cycle (15 µs per wave, about 2 per cycle), as the tree gains a level;
  - the slow waves, new at 32 nodes, add 71 µs per cycle;
  - the time between waves adds 7 µs.
  - So about two thirds of the growth is slow waves.

**The slow waves come with the allocation, not with the node count.** PHOLD σ 100 (both jobs before `--localalloc`):

| allocation | nodes in the run | slow waves (share of wave time) |
|---|---|---|
| 16-node skx-dev (job E16, 2 runs) | 16 | 0.9% (5–6%) |
| 32-node skx (job E, 1 run) | 16 of the 32 | 4.2% (19%) |
| 32-node skx (job E, 2 runs) | 32 | 4.6–10.8% (17–34%) |

- Sections 154 and 162 traced these on PHOLD. Each stretched wave has one slow hop; the slow hops are spread over many node pairs, with no receive overflow and no transmit wait. `--localalloc` removed the TLB-shootdown bursts, but the slow hops remained (section 166).
- VS2's 16-node cell ran on skx-dev and its 32-node cell on skx, so section 226's 16 → 32 comparison crosses allocations.

**The slow waves cluster into slow stretches, and only a one-period window feels them.** Fast level is the 10th percentile of ms per cycle over the 64-cycle intervals; slow stretches are the intervals above 1.1× the fast level, counting only the excess (round 3; lower is better for both):

| nodes | W 2,500: fast level, slow-stretch share | controller (holds W 2,500) | W 5,000 |
|---|---|---|---|
| 1 | 0.459–0.464, 0.0–0.2% | 0.469–0.470, 0% | 0.378–0.383, 0% |
| 4 | 1.070–1.098, 0% | 1.081–1.097, 0.0–1.2% | 1.442–1.481, 0% |
| 8 | 1.061–1.089, 0.0–0.2% | 1.077–1.100, 0.0–0.5% | 1.450–1.473, 0% |
| 16 | 1.103–1.122, 0.0–2.7% | 1.105–1.123, 0% | 1.433–1.464, 0% |
| 32 | 1.209–1.345, **0.0–11.3%** | 1.216–1.277, **3.1–19.2%** | 1.377–1.438, 0.0–1.9% |

- **The controller has no steady cost.**
  - Its fast level equals W 2,500's at every node count.
  - At 32 nodes, with the slow stretches removed, its runs take 6.13–6.51 s against 6.09–6.69 s at W 2,500 (GVT 64 to the last progress line; with them, 6.36–7.82 s against 6.22–7.47 s).
  - Section 226's 0.90–1.00 is slow stretches: 3–19% of its run time against 0–11% at W 2,500.
  - Five reps cannot tell whether the controller's runs draw more stretches or met more by chance. It ran first among the Charades runs in the odd reps, where its ratios were lowest.
- **A window two periods wide is almost immune** (0–1.9%): PEs run on while an advance is late. Devastator shows the same: at 32 nodes its W 2,500 varies 1.17× between reps (without one outlier), its W 10,000 1.01×.
- **The slow stretches set the spread between reps** at W 2,500 (section 226: 1.19×).

**Why a wider window does not fix it.** W 5,000's cycle stays at 1.38–1.48 ms from 4 to 32 nodes, as flat as Devastator's 1.37–1.45, but it is 1.29–1.37× W 2,500's at 4–16 nodes and 1.13× at 32 (median cycle):

| nodes | W 2,500: rolled back (M), lowest PE's blocked share | W 5,000: the same |
|---|---|---|
| 4 | 8.7, 23.9% | 14.1, 1.8% |
| 16 | 31.6, 30.5% | 36.9, 3.1% |
| 32 | 61.9, 39.8% | 66.2, 8.0% |

- At W 5,000 the busiest PE almost never waits, and more events are rolled back. From 3 nodes on, copy 2 does 1.75× the median copy's work and sets the pace in every engine (section 201). A wider window lets that copy's PEs execute further ahead, so more of its work is rolled back.
- Not measured: how much of the extra rolled-back work lands on copy 2's PEs.

**What this means:**
- **Diagnosis needs no 32-node run.** At W one period the cycle waits for every GVT advance. Each advance takes a start reduction and two count waves, each crossing the process tree.
- **The engine's own share of the 16 → 32-node growth is small.** Typical waves add 31 µs per cycle, about 2.6% of the cycle. Most of the growth is slow waves, a property of the 32-node allocation (PHOLD shows them on 16 nodes of such an allocation). Earlier PHOLD work found no engine-side cause for them (sections 154, 162, 166).
- **The obvious GVT changes are already tried.**
  - Two waves per advance follow from the four-counter rule as implemented: a PE contributes to wave k+1 only after reading wave k's result (section 49).
  - A wider window does not change that either: W 5,000 still makes two waves per advance (9,983 for 4,995 at 32 nodes).
  - On PHOLD, asking ahead (section 60), flat and 8-ary trees, recursive doubling, contributing at once, smaller batches and `--wave-batch` moved throughput by −12% to +6% (sections 52, 60, 118, 120, 162).
- **What helps is tolerance:** a window wider than one period does not feel slow advances. On VLSI it costs 1.29–1.37× per cycle at 4–16 nodes and 1.13× at 32 (median cycle), because the busiest copy's PEs run ahead and roll back.
  - Untested: whether a window between one and two periods (for example 3,750 ps) keeps most of the tolerance at less cost. Its steady cost can be measured at 4–16 nodes; its tolerance only in a 32-node allocation.
- **A run is needed only to confirm the allocation effect on VLSI** (16 nodes inside a 32-node allocation). F1's paper-grade 32-node job can carry it at no extra cost.
- **For the paper:** report the medians with their spread (Charades ÷ Devastator 1.05 at 32 nodes; per rep 0.96–1.07). Say that a one-period window makes each clock cycle wait for a GVT advance, and that slow advances in 32-node allocations account for the spread.

### §233 · Where Charades' cost of running ahead goes on VLSI: each PE's time at W 2,500 / 3,750 / 5,000, and three switches that could move it (job RA design, 2026-11-05; written before any runs)

> **Status: done; results in section 234.** User decision 2026-11-05: cancel VW (3684509, cancelled before it started) and run this job instead. It carries VW's W 3,750 question (section 229); W 3,125 is dropped.
> - **Script:** `$WORK/charades-runs/rahead233.slurm` (copy in `~/charades-data/vlsi/`), skx-dev plus an skx copy, 16 nodes, 50 minutes, `-x c455-081`. Login-node checks pass. Resubmitted 2026-11-05 as 3686450 (skx-dev) and 3686451 (skx); the copy that starts second is cancelled.
> - **First submission (3685764 skx-dev, 3685765 skx) produced nothing.** The script kept its arm list in a bash array named `ARMS`, which is also `ctl_sweep.sh`'s variable. Bash does not export arrays, so every `ctl_sweep.sh` call ran its default arms (W 25–500 and the controller arms); the W 25–500 runs stalled at the 300 s cap. 3685764 was cancelled at 49 minutes, after the gate (27/27) and the warm-up runs; the skx copy was cancelled before it started. Fixed: the array is `RUN_ARMS`, and each run's CSV must hold one run at the W asked for, or that stream stops. Checked on the Mac against a stub `ctl_sweep.sh` (arms, order, options and the traced rep's flags per run). The failed run's directory is kept as `rahead233/failed_j3685764_default_arms`.
> - **Code:** VS2's binaries (tree `charades-r3`, ae0dbd3, round 3), so the defaults compare directly with sections 217 and 228. No code change: every switch and record below exists in that tree.
> - **Mac check** (VLSI test `tiny.bench`, 1 × 4, W 200): the defaults, `--fossil-lazy=0 --gvt-wave-events=0`, and both with `--gvt-trace=5 --pe-stats=1 --comm-stats=1` (one at `--batch=8`) all commit 15,489 events with one digest (104b07b9…), and the traced runs write every per-PE file.

**Why.** Running ahead costs Charades on VLSI only once copy 2 is in the run. Copy 2's inputs give it 1.75× the switching of every other copy (section 201), and it is on node 2 from 3 nodes up. VS2, round 3, 3 reps (in the second column, below 1 means W 5,000 is faster):

| nodes | W 5,000 ÷ W 2,500, run time (per rep) | the least-blocked PE: share of the run waiting at the window, W 2,500 / W 5,000 (%) | the least-blocked PE: time not waiting per cycle, W 2,500 → W 5,000 (ms, median rep) |
|---|---|---|---|
| 1 (no copy 2) | 0.84–0.85 | 41–43 / 22–24 | 0.28 → 0.31 |
| 2 (no copy 2) | 0.72–0.74 | 54 / 30 | 0.29 → 0.33 |
| 4 | 1.33–1.35 | 24–25 / 1.8–1.9 | 0.84 → 1.47 |
| 8 | 1.32–1.34 | 26–27 / 2.3–2.5 | 0.82 → 1.47 |
| 16 | 1.24–1.27 | 30–33 / 3.0–3.1 | 0.83 → 1.45 |

- **At 1–2 nodes** a PE that runs ahead works about 12% longer per cycle and no PE runs out of waiting, so W 5,000 is faster.
- **From 4 nodes on** the least-blocked PE (presumably on copy 2's node; not recorded per PE) works 0.84 ms per cycle at W 2,500, three times the 1-node figure for 1.75× the copy's work. At W 5,000 it stops waiting, and its working time grows by about 0.6 ms per cycle, 75%. That PE then sets the cycle.
- **Over the whole run** (4 nodes), W 5,000 executes 0.9% more events: rolled back 8.7 → 14.1 M, anti-messages 6.9 → 8.8 M, rollbacks caused by anti-messages 1.73 → 3.49 M. Spread over 184 PEs, that is about 6 extra events per PE per cycle, too few for +0.6 ms. On one PE it would be about 1,100 per cycle, which is enough. Section 228 had no per-PE counts.
- **Devastator** is flat: 83.7 / 83.4 / 82.7 M ev/s at W 2,500 / 5,000 / 10,000 on 4 nodes (median of 3). It is not rerun here: it has no per-PE accounting.
- **The payoff, if running ahead were free:** a W 5,000 cycle at the least-blocked PE's W 2,500 working time (0.84 ms) would be 1.32× W 2,500's at 4 nodes, and a window two periods wide is the one that does not feel the 32-node slow waves (section 228).

**Hypotheses for the least-blocked PE's extra 0.6 ms per cycle:**
- **H1, its own speculation:** GVT trails it by about a period, so it runs events of the next cycle before the current cycle's late inputs reach it, then rolls them back. Its executed and rolled-back counts grow.
- **H2, costlier events:** the same events, each slower: more pending events, more anti-messages to cancel, more pushes into its input buffer. Its event-loop time per executed event grows.
- **H3, work that W 2,500 hid in waiting:** lazy commits run on passes blocked at the window and are counted as waiting (`optimistic.C`, `collect_fossils_step`). The same goes for the cancel queue and count-wave handling. At W 5,000 this work lands on the PE's working time.
- **H4, GVT pace:** a PE that always has work holds its count-wave contribution until it has executed 128 events (`--gvt-wave-events`, `bucketed.C` `send_counts`).
  - My estimate before this design was about 0.4 ms per cycle.
  - On re-reading, a PE that waits 1.8–3.1% of the run rarely waits for an advance, so its direct cost should be small.
- **H5, pickup delay:** an input from another PE waits until the PE finishes its batch of 32. Section 209 found this ahead work to be 1–2% of a cycle's chain, but at 1 node, where running ahead is cheap.

**Runs** (VS2's launch and sizes):
- b19 × N, one copy per node, 1 × 46, buckets of 2,500 ps, 5,000 cycles, direct sends.
- `--blocked-time=1 --commit-digest=1 --copy-stats=1`, plus `--pe-stats=1` on every run.
- **Windows:** W 2,500, 3,750 and 5,000, each with four settings:
  - **D:** VS2's settings (`--fossil-lazy=1 --batch=32`, `--gvt-wave-events` at its default 128).
  - **G:** `--gvt-wave-events=0`. A PE contributes to a count wave as soon as it reads the previous result. Tests H4.
  - **E:** `--fossil-lazy=0`. A PE commits everything below the new GVT as the GVT arrives. Tests H3's commits.
    - Lazy commits are one chare per pass that ends short of a full batch. A PE that always fills its batch never runs them until the fourth GVT, and `--fossil-chares=40` would not change that.
  - **GE:** both.
- **W 5,000 only:** B8 (`--batch=8`): a PE drains its input buffer every 8 events instead of every 32. Tests H5.
- **13 arms per rep.** Arm order is reversed in rep 2, and each node set gets a warm-up run.
  - **4 nodes:** three untraced reps and one traced rep, each on its own 4 nodes, side by side.
  - **16 nodes:** three untraced reps, then the traced rep.
- **Traced rep:** `--gvt-trace=5 --comm-stats=1`.
  - **Time in `execute()` per PE**, split into the event loop, sends, input-buffer drains, polling, the cancel queue, rollbacks and commits at GVT arrival (`exec_parts_<pe>.csv`). Lazy commit steps are not timed separately; in E runs every commit is timed.
  - **Count-wave records:** every 4th wave, each PE's contribution, how long it held it and why (`gvt_rec_<pe>.csv`).
  - **Send latency** between PEs of the same process (`--comm-stats`).
  - Files are gzipped. At 16 nodes only node 2's PEs (92–137) and PE 0 keep `gvt_rec`.
- **Gate:** VS2's change tier on 2 nodes (VLSI).
- **About 30 minutes:** the gate 3, the 4-node runs 6, the 16-node runs 20.

**Measures:**
- Run time and M committed ev/s.
- From `pe_stats.csv`, per PE: events executed, committed and rolled back; full and window-blocked passes; time blocked; time in `execute()` (traced rep only).
- **The least-blocked PE** in each run: its time per cycle, split into waiting at the window, the event loop, the other parts of `execute()`, and time outside `execute()`.

**Predictions:**
- **RA1. Counts:** every run commits VS2's count with VS2's digest: 574,541,914 (0c800d36…) at 4 nodes, 2,087,384,844 (377d0771…) at 16.
- **RA2. The defaults reproduce VS2:** W 5,000 ÷ W 2,500 run time within 5% of 1.33–1.35 (4 nodes) and 1.24–1.27 (16 nodes).
- **RA3 (section 229's VW3):** W 3,750's run time under D is 1.10–1.30× W 2,500's, and its rolled-back count lies between theirs.
- **RA4. Where the time goes (H1),** on the least-blocked PE, traced rep, D, W 5,000 against W 2,500:
  - it is on node 2 in every run, and it executes at least 1.3× the mean of node 2's PEs (the layout was balanced on one copy's activity profile, and copy 2's mode need not follow it);
  - it executes at least 15% more events per cycle, most of the increase rolled back;
  - its event-loop time per executed event changes by less than 15% (H2 small);
  - commits at GVT arrival, the cancel queue, polling and time outside `execute()` together are under a quarter of its extra time (H3 small).
- **RA5. GVT pace (H4):** G is within ±5% of D at every W and node count. At W 2,500 every PE waits each cycle and already contributes at once; V2 found `--gvt-wave-events=16` at 0.99–1.00 there (section 197).
- **RA6. Commits (H3):**
  - E is 0.88–0.97 of D at W 2,500 (lazy commits were 1.09× at 1 node, section 204).
  - E is within ±5% of D at W 5,000 (V5: eager at W 5,000 on 4 nodes was 0.97 of lazy, on the older tree at batch 16, section 208).
  - GE behaves like E.
- **RA7. Pickup (H5):** B8 is within ±5% of D at W 5,000. Shorter passes cost on VLSI at W 2,500 (batch 4: 0.87–0.90 of batch 16, section 197).

**What follows:**
- **RA4 right:** the cost of running ahead is the speculation of the PE that sets GVT. A window measured from GVT cannot hold that PE back, since its own work sets GVT. Two options would be designed separately: a narrower window for the PEs that GVT waits on, or spreading copy 2's work differently.
- **RA4 wrong, toward H2:** profile the least-blocked PE at W 5,000 against W 2,500.
- **RA5 wrong** (G at least 1.05× D at W 3,750 or 5,000): the 128-event rule is on VLSI's path at wider windows. It is a default for every workload. Any change must be measured on PHOLD at its best windows and land before the freeze (2026-12-07).
- **RA6 wrong** (E at least 1.05× D at W 5,000): change the lazy rule so that a PE that always fills its batch still commits. This is VLSI-only.
- **RA7 wrong** (B8 at least 1.05× D): end a pass early when the input buffer holds an event earlier than the next one in the heap (one of section 207's follow-ons).
- **Section 229's rule stands:** if W 3,750 in any setting costs at most 5% against W 2,500 at 16 nodes, F1's 32-node job runs it beside W 2,500 to measure its tolerance to slow advances.

### §234 · RA results: the cost of running ahead on VLSI was the lazy commit rule; with eager commits W 5,000 runs at 0.97–1.03 of W 2,500's speed (lazy: 0.75–0.79), and from 3 nodes up one PE carries copy 2's extra work and sets every cycle (2026-11-05; skx-dev batch job 3686450, 16 nodes)

> **Status: current.** Design and predictions in section 233.
> - **Job:** 33 minutes; gate 27/27; every run finished. The skx copy 3686451 was cancelled before it started. The first submission (3685764) ran the wrong arms (section 233).
> - **Data:** `~/charades-data/vlsi/rahead233/j3686450/`; summary `~/charades-data/vlsi/rahead233_summary.py`, output `rahead233_summary.txt`.
> - **Counts (RA1 right):** all 104 measured runs (warm-ups aside) commit VS2's count with VS2's digest: 574,541,914 (0c800d36…) at 4 nodes and 2,087,384,844 (377d0771…) at 16.

**Run time against VS2's best** (each arm's run time ÷ the same rep's D at W 2,500; lower is better; range over 3 reps; D at W 2,500 runs 5.53–5.74 s at 4 nodes and 5.96–6.01 s at 16):

| setting | 4 nodes: W 2,500 / 3,750 / 5,000 | 16 nodes: W 2,500 / 3,750 / 5,000 |
|---|---|---|
| D (VS2's: lazy commits, batch 32) | 1 / 1.29–1.32 / 1.32–1.33 | 1 / 1.24–1.39 / 1.27–1.29 |
| G (`--gvt-wave-events=0`) | 0.96–1.00 / 1.28–1.33 / 1.31–1.32 | 0.99–1.01 / 1.24–1.25 / 1.26–1.29 |
| **E (`--fossil-lazy=0`, eager commits)** | 0.98–1.00 / 0.98–1.27 / **1.01–1.04** | 1.04–1.08 / **0.94–0.97** / **0.97–0.99** |
| GE (both) | 0.97–0.99 / **0.98–0.99** / **1.00–1.01** | 1.04–1.07 / 0.95–1.21 / **0.98–0.99** |
| B8 (`--batch=8`) | — / — / 1.44–1.47 | — / — / 1.38–1.53 |

- **Eager commits remove the cost of running ahead.** At the same W, E is 1.28–1.33× D's speed at W 5,000. Against VS2's best (D at W 2,500), E at W 5,000 runs at 0.97–0.99 at 4 nodes and 1.02–1.03 at 16; E at W 3,750 at 1.03–1.06 at 16.
  - **Medians:** at 16 nodes, E at W 5,000 runs 5.82 s (358.7 M committed ev/s) against 6.00 s (347.9) for D at W 2,500.
- **At W 2,500 eager commits cost** 0.93–0.96 of lazy at 16 nodes and nothing at 4. There, lazy commits fill the PEs' waits.
- **The count-wave rule does not matter:** G is within ±5% of D in every rep-cell but one, where D's own rep was slow.
- **Shorter passes cost 8–17%** at W 5,000.
- **Slow reps:** three of the 24 W 3,750 runs (D 16 nodes rep 2, E 4 nodes rep 1, GE 16 nodes rep 3) took 1.11–1.32× as long as their other reps. Each had the same events and rollbacks, and the busiest PE simply took 1.12–1.30× longer per cycle. No W 5,000 run of E or GE did this; the cause was not measured.
- **W 3,750 rolls back the most:** 20.7 M at 4 nodes against 8.8 (W 2,500) and 14.0 (W 5,000); 69.0 M at 16 against 31.7 and 37.2 (D, median).

**One PE sets the cycle from 3 nodes up.** Events executed per PE per clock cycle (D, W 2,500, rep 1; the same in every arm within 2%):

| | 4 nodes | 16 nodes |
|---|---|---|
| copy 2's node (node 2): mean PE / busiest PE (rank 13) | 867 / 2,141 (2.47×) | 867 / 2,144 (2.47×) |
| every other node: mean PE / busiest PE (rank 16) | 556–557 / 647–649 (1.16–1.17×) | 556–557 / 647–650 (1.16–1.17×) |

- **PE 105 (node 2, rank 13) is the least-blocked PE in every one of the 104 runs.** It runs 3.3× the events of any other node's busiest PE. Copy 2's extra switching (section 201) falls mostly on the nets that layout puts on this one PE. The layout was balanced on one copy's activity profile.
- **It does not speculate.** It rolls back 1–3 events per cycle in every arm, at every W.
- **All three engines put the same nets on each PE** (section 193). So in each engine one rank runs these 2,141 events per cycle, and that rank sets VLSI's pace from 3 nodes up.

**Where PE 105's time goes** (traced rep, µs per clock cycle; the trace inflates times by about 30%; "working" is time not waiting at the window; commits at GVT arrival are timed inside the result pickup):

| nodes | arm | total | waiting | working | event loop (µs per event) | input-buffer drains | commits at GVT arrival | outside `execute()` |
|---|---|---|---|---|---|---|---|---|
| 4 | D, W 2,500 | 1,453 | 312 | 1,141 | 869 (0.41) | 227 | 32 | 91 |
| 4 | D, W 5,000 | 1,819 | 32 | 1,787 | 1,089 (0.51) | 341 | 281 | 45 |
| 4 | E, W 2,500 | 1,407 | 329 | 1,078 | 810 (0.38) | 231 | 105 | 145 |
| 4 | E, W 5,000 | 1,447 | 30 | 1,417 | 877 (0.41) | 327 | 138 | 40 |
| 16 | D, W 2,500 | 1,498 | 383 | 1,115 | 833 (0.39) | 238 | 0 | 136 |
| 16 | D, W 5,000 | 1,857 | 55 | 1,802 | 1,100 (0.51) | 341 | 285 | 50 |
| 16 | E, W 5,000 | 1,489 | 55 | 1,434 | 891 (0.42) | 326 | 145 | 52 |

- **How lazy commits fail here.**
  - With `--fossil-lazy=1`, a PE commits one chare's events per pass that ends short of a full batch (`optimistic.C`). At W 2,500, PE 105 waits every cycle, and those passes do its commits.
  - At W 3,750 and 5,000 it never ends a pass short. It commits nothing until the fourth GVT update, then commits four cycles of events at once inside the update.
- **That backlog costs PE 105 about 370 µs per cycle in the trace** (D against E at W 5,000, 4 nodes):
  - The commits themselves: 281 against 138 µs. Committing four cycles at once costs about twice as much per event as committing each cycle at its GVT.
  - Every event runs slower: 0.51 against 0.41 µs in the event loop.
- **With eager commits, running ahead trades PE 105's waits for work:**
  - Its waits (312–383 µs) go.
  - Its commits (105–145 µs) and drains (+100 µs) now come on its working time. At W 2,500 the commits were partly done by lazy steps while it waited, and the drains hold events other PEs sent ahead.
  - The net is about level at 4 nodes. At 16 nodes, where waves take longer and W 2,500's waits are larger, it is 2–3% faster.
- **Devastator commits at every GVT step, at any window** (`~/pdes-baselines/devastator/src/devastator/pdes.cxx:838`). That is why its run time does not depend on W.
- **Send latency between PEs of a process** (traced, 4 nodes, D) is not the cause: mean 12.5 µs at W 2,500, 15.0 at W 5,000.

**Predictions (section 233):**
- **RA1 right.**
- **RA2 right:** D's W 5,000 ÷ W 2,500 run time is 1.32–1.33 at 4 nodes and 1.27–1.29 at 16, within 5% of VS2's.
- **RA3 wrong:** W 3,750 costs as much as W 5,000 under D (1.29–1.32 and 1.24–1.39, not 1.10–1.30), and it rolls back the most, not between the two.
- **RA4 wrong in its main claim:**
  - Right: the least-blocked PE is on node 2 in every run, and it executes 2.39–2.47× node 2's mean (at least 1.3× predicted).
  - Wrong: its executed count does not grow (2,141 per cycle in every arm), and it rolls back 1–3 events per cycle.
  - Wrong: its time per event grows 24–31% under D, not under 15%.
  - Wrong: commits at GVT arrival are about 40% of its extra working time, not under a quarter.
- **RA5 right.**
- **RA6 wrong:**
  - At W 2,500, E is 1.00–1.02× D at 4 nodes and 0.93–0.96 at 16 (predicted 0.88–0.97).
  - At W 5,000, E is 1.28–1.33× D (predicted within ±5%). My re-reading of V5 for the design (section 233) led me away from this suspect, but its eager arm differed in batch size and tree.
  - GE behaves like E (right).
- **RA7 wrong, in the other direction:** B8 is 0.83–0.92 of D at W 5,000.

**What follows** (decisions for the user):
- **VLSI's setting.** Eager commits at W 5,000 match or beat VS2's best at 4–16 nodes. A window two periods wide should also not feel the 32-node slow waves (section 228: 0–1.9% for W 5,000), which cost W 2,500 up to 11% of a run there (the controller up to 19%). Options:
  - **(a) Eager commits and W 5,000 from 4 nodes up.** Round 1 found lazy commits 1.09× at 1 node (older tree), so the setting would differ by node count.
  - **(b) Change the lazy rule** so that a PE that ends a GVT round with commits left commits them all at the next update (one round, not four). This would give one setting for every node count. It needs a code change: VLSI-only, before the freeze.
  - **(c) Keep VS2's setting and report it.**
  - Under (a) or (b), F1's 32-node job measures the steady rate and the slow-wave tolerance.
- **The controller on VLSI.** It sits at one bucket (section 208). With buckets of 2,500 ps under eager commits it would run at 0.93–0.96 of lazy at 16 nodes. A W 5,000 setting needs buckets of 5,000 ps, untested on round 3.
- **The workload.** From 3 nodes up, VLSI's cycle is one PE's 2,141 events in every engine. The paper should say so; it is a sharper form of section 201's 1.75× copy. Laying out each copy by its own activity would remove it, but changes the workload in all three engines. The user kept the workload on 2026-11-03, before this was known.

### §235 · VLSI's commit setting and its controller row: lazy commits that cannot pile up, eager commits, and the controller with buckets of 5,000 ps, at 1–16 nodes (job VC design, 2026-11-05; written before any runs)

> **Status: done; results in section 236.** User decisions 2026-11-05, on section 234's four questions:
> 1. **A switch for how long lazy commits may wait**, tested beside eager commits.
> 2. **F1's 32-node job runs the chosen setting at W 5,000 beside W 2,500.**
> 3. **The VLSI controller row is tested with buckets of 5,000 ps.**
> 4. **The workload stays.** The paper states that from 3 nodes up one PE sets VLSI's pace in every engine.
>
> - **Code** (charades 609212b, on GitHub):
>   - `--fossil-rounds=N` (default 4, the constant it replaces): the GVT updates a lazy round may stay unfinished before everything below the new GVT is committed at once; 0 commits at every update.
>   - `--fossil-finish=1` (default 0): a GVT update first completes the unfinished round, at the GVT that round started from, then starts the next. This is section 234's "commits at the next update". With `--fossil-rounds=1` the busy PE still carries two to three cycles of commits into each bulk commit, so both are tested in this one job.
>   - Test configs `bucket_window_lazy`, `_lazy_rounds1`, `_lazy_finish`. Mac: change tier on them 99/99, one digest. A temporary print showed that the default bulk-commits at 4 unfinished rounds, `--fossil-rounds=1` at 1, and `--fossil-finish=1` never; it was then removed.
> - **Tree:** `charades-r4` at 609212b on `charm-pads-perf`, built on the login node (`$WORK/charades-runs/build_r4.sh`). The binary links `charm-pads-perf` and holds round 3's markers.
> - **Script:** `$WORK/charades-runs/vcommit235.slurm` (copy in `~/charades-data/vlsi/`), skx-dev plus an skx copy, 16 nodes, 45 minutes, `-x c455-081`. Login-node checks pass. Submitted 2026-11-05 as 3686688 (skx-dev) and 3686689 (skx); the copy that starts second is cancelled. Checked on the Mac against a stub `ctl_sweep.sh`: each run gets its arm, bucket and commit options, and rep 2 runs in reverse.

**Commit settings:**
- **L:** lazy commits as in VS2 and RA (`--fossil-lazy=1`, 4 rounds).
- **E:** eager commits (`--fossil-lazy=0`).
- **R1:** lazy commits, `--fossil-rounds=1`.
- **F:** lazy commits, `--fossil-finish=1`.

**Arms** (b19 × N, one copy per node, 1 × 46, `--batch=32`, 5,000 cycles, direct sends, `--pe-stats=1`):
- L at W 2,500 and W 5,000; E, R1 and F at W 5,000; all with buckets of 2,500 ps.
- The frozen controller (`--ctl=3`, bracketed):
  - with buckets of 2,500 ps under L (VS2's VLSI controller row);
  - with buckets of 5,000 ps under E, R1 and F. Its window cannot go below one bucket, and on VLSI it stays there (section 208), so it runs at W 5,000 with GVT advancing in steps of two clock periods.
- 9 arms, 3 reps, arm order reversed in rep 2, a warm-up run per node set.
- 1, 2, 4 and 8 nodes side by side (nodes 0 / 1–2 / 3–6 / 7–14), then 16 nodes. About 30 minutes.
- **Gate:** VS2's change tier on 2 nodes (VLSI) with lazy commits, and the three lazy-commit configs. An unknown flag aborts a run, so the gate also checks that the binary takes the new flags.

**Why 1–2 nodes:** there W 5,000 is the best fixed window, and today's controller row (buckets of 2,500, held at W 2,500) runs at 0.83 (1 node) and 0.72 (2 nodes) of it (VS2, run time). VS2 compared the controller only with W 2,500 (0.98–1.01).

**Predictions** (run-time ratios within a rep; "speed" means the inverse of run time, higher is better):
- **VC1. Counts:** every run at a node count commits VS2's count and digest: 125,998,590 (87c11aec…), 252,049,665 (0002eae9…), 574,541,914 (0c800d36…), 1,078,843,202 (089e4484…) and 2,087,384,844 (377d0771…) at 1, 2, 4, 8 and 16 nodes.
- **VC2. L reproduces VS2 and RA within 5%:** at 4–16 nodes W 5,000 runs at 0.75–0.79 of W 2,500's speed; at 1–2 nodes W 5,000 is the faster window (VS2: 1.17–1.39× W 2,500).
- **VC3. E at W 5,000** runs at 0.97–1.03 of L at W 2,500 at 4–16 nodes (section 234). At 1 node it runs at 0.90–0.97 of L at W 5,000: round 1 found lazy commits 1.09× there, and its PEs wait 22–24% of the run, time that lazy commits use.
- **VC4. F at W 5,000** is within ±3% of E at 4–16 nodes, because the busy PE then commits one cycle per update, as E does. It is within ±3% of L at W 5,000 at 1–2 nodes, where every PE finishes its rounds while it waits. So F at W 5,000 is within 3% of the best arm at every node count.
- **VC5. R1 at W 5,000** lies between E and L at 4–16 nodes, at 0.85–0.99 of E's speed: the busy PE still commits two to three cycles at once every third update.
- **VC6. The controller with buckets of 5,000 ps** under E or F is at least 0.93 of the best fixed arm at every node count. At 1–2 nodes that is above today's controller row (0.72–0.83). V5 (older tree, lazy) found 0.98 at 1 node and 0.91 at 4.
- **VC7. Today's controller row** (L, buckets of 2,500) is 0.98–1.01 of L at W 2,500 at every node count (VS2).

**What follows:**
- **VLSI's setting** for F1's 32-node job and the paper:
  - F at W 5,000 if VC4 holds: one setting at every node count;
  - otherwise R1 if it is within 3% of E at 4–16 nodes;
  - otherwise E at W 5,000 from 4 nodes up, with L at W 5,000 at 1–2 nodes.
- **The VLSI controller row** uses buckets of 5,000 ps under that setting if VC6 holds. Otherwise the paper reports that the controller is bound to one bucket on VLSI and shows its row with buckets of 2,500 ps.
- **Lazy commits stay a VLSI setting.** They cost 4–6% on Gaussian and uniform PHOLD (section 208), and nothing here changes that.

### §236 · VC results: eager commits at W 5,000 are VLSI's best setting at 1, 2 and 16 nodes and within 3–5% of it at 4 and 8; lazy commits no longer pay anywhere, `--fossil-finish` included; the controller cannot reach W 5,000 on VLSI, because it tries windows only inside the remote-delay range (2026-11-06; skx-dev batch job 3686688, 16 nodes)

> **Status: current.** Design and predictions in section 235.
> - **Job:** 23 minutes. Both gates passed 27/27; the second ran the three lazy-commit configs, so the binary takes the new flags. The job started in `/tmp` after an I/O error on `/work2`; the script uses absolute paths. The skx copy 3686689 was cancelled before it started.
> - **Data:** `~/charades-data/vlsi/vcommit235/j3686688/`; summary `~/charades-data/vlsi/vcommit235_summary.py`, output `vcommit235_summary.txt`.
> - **Counts (VC1 right):** all 135 runs commit VS2's count with VS2's digest at each node count.

**Speed ÷ the best fixed arm of the same rep** (higher is better; range over 3 reps; median run time in s in brackets; L lazy as VS2, E eager, R1 `--fossil-rounds=1`, F `--fossil-finish=1`; buckets of 2,500 ps unless noted):

| arm | 1 node | 2 nodes | 4 nodes | 8 nodes | 16 nodes |
|---|---|---|---|---|---|
| L, W 2,500 (VS2's setting from 4 nodes up) | 0.75–0.76 (2.47) | 0.65–0.66 (3.18) | **1** (5.55) | **1** (5.56) | 0.98 (5.95) |
| L, W 5,000 (VS2's setting at 1–2 nodes) | 0.89–0.90 (2.07) | 0.89–0.90 (2.32) | 0.74 (7.53) | 0.74–0.76 (7.42) | 0.76–0.77 (7.62) |
| **E, W 5,000** | **0.99–1.00** (1.85) | **1** (2.07) | 0.77–0.97 (5.87) | 0.97–0.99 (5.69) | **1** (5.84) |
| R1, W 5,000 | 0.94–0.95 (1.96) | 0.93–0.97 (2.17) | 0.80–0.82 (6.83) | 0.81–0.83 (6.86) | 0.83–0.85 (6.97) |
| F, W 5,000 | 0.96–1.00 (1.91) | 0.98–1.00 (2.09) | 0.87–0.90 (6.36) | 0.89–0.92 (6.19) | 0.91–0.92 (6.34) |
| controller, buckets of 2,500, L (VS2's row) | 0.74–0.75 (2.51) | 0.64 (3.25) | 0.83–0.98 (5.72) | 0.97–1.00 (5.64) | 0.94–0.96 (6.14) |
| controller, buckets of 5,000, E | 0.83–0.85 (2.22) | 0.74–0.75 (2.78) | 0.89–0.90 (6.23) | 0.89–0.90 (6.23) | 0.87–0.89 (6.57) |
| controller, buckets of 5,000, R1 | 0.82–0.83 (2.25) | 0.74–0.76 (2.77) | 0.77–0.79 (7.14) | 0.78–0.80 (7.09) | 0.79–0.80 (7.36) |
| controller, buckets of 5,000, F | 0.80–0.83 (2.29) | 0.73–0.76 (2.77) | 0.79–0.81 (6.96) | 0.82 (6.76) | 0.82–0.84 (7.02) |

- **Eager commits at W 5,000 against VS2's setting at each node count** (speed, higher is better):
  - 1.11–1.12 at 1 and 2 nodes (against L at W 5,000);
  - 0.95–0.97 at 4 nodes (one rep 0.77, below), 0.97–0.99 at 8, 1.02–1.03 at 16 (against L at W 2,500).
- **Lazy commits no longer pay anywhere.** At 1–2 nodes, where round 1 found them 1.09× at W 5,000 (section 204, before round 3), eager commits are now 1.11–1.12×. Why it reversed is not measured.
- **The later the busy PE commits, the slower the run.** At 4–16 nodes, PE 105's working time per cycle is:
  - E 1.09–1.12 ms;
  - F 1.20–1.26;
  - R1 1.31–1.37;
  - L 1.45–1.49.
  - `--fossil-finish` commits one cycle per update, as eager does, but one update late, and that costs 5–11% (F ÷ E 0.89–0.95 per rep at 4–16 nodes, leaving out E's slow rep).
- **One slow rep:** E at W 5,000, 4 nodes, rep 2, ran 7.27 s against 5.69 and 5.87, with the same events, rollbacks and GVT counts; PE 105 took 1.28× longer per cycle.
  - It is the fourth such rep (section 234 had three at W 3,750), and the other arms of that rep on the same nodes were normal.
  - At W ≥ 3,750 one PE runs without waiting, so anything that slows its core shows in full. Cause not measured.

**The controller on VLSI.**
- **It never moves.** With buckets of 2,500 ps its window was 2,500 in all 1,379 rounds of the 1-node rep 1 (`--ctl-log=1`). It reported "59 trials, 19 kept", yet every trial ran at 2,500.
- **The cause is in `measured_clamp` (`controller.C:464`).** A trial window is held between the 1st and 99th percentiles of the remote-send delay (ts minus the sender's time). It is then raised to at least one bucket.
  - On VLSI every remote delay is under one bucket (section 192), so every trial lands on one bucket.
  - The controller's range assumes a wider window pays only by admitting more of the delays. On VLSI a wider window pays by letting PEs run on while a GVT advance is late (section 228), which the range leaves out.
- **Buckets of 5,000 ps do not fix it.** They hold the window at 5,000, but GVT then advances once every two clock periods.
  - The least-blocked PE waits 23–32% of the run again, against 2–4% at W 5,000 with buckets of 2,500.
  - Two to three times as many events roll back (4 nodes, E: 33.6 M against 15.9 M; 16 nodes: 108 M against 40 M).
  - It runs at 0.74–0.90 of the best fixed arm.

**Predictions (section 235):**
- **VC1 right.**
- **VC2 right:** L's W 5,000 ÷ W 2,500 speed is 0.73–0.79 at 4–16 nodes and 1.17–1.38 at 1–2.
- **VC3 half:**
  - Right at 8 and 16 nodes (0.97–0.99 and 1.02–1.03 of L at W 2,500), and at 4 nodes in two reps of three (0.95–0.97, just under 0.97).
  - Wrong at 1 node: E is 1.11–1.12× L at W 5,000, not 0.90–0.97.
- **VC4 wrong:** F is 0.89–0.95 of E at 4–16 nodes, not within ±3%. At 1–2 nodes it is 1.08–1.13× L at W 5,000, not within ±3%.
- **VC5 half:** R1 lies between E and L, but at 0.82–0.85 of E's speed per rep at 4–16 nodes, leaving out E's slow rep (0.85–0.99 predicted).
- **VC6 wrong:** the controller with buckets of 5,000 ps runs at 0.74–0.90 of the best fixed arm, not at least 0.93.
- **VC7 mostly wrong, narrowly:** VS2's controller row is 0.96–1.00 of L at W 2,500 at 2–16 nodes, with one rep at 0.83 at 4 nodes (0.98–1.01 predicted). It is 0.98–0.99 at 1 node.

**What follows** (decisions for the user):
- **VLSI's setting:** eager commits, which is the engine's default (no `--fossil-lazy`), at W 5,000 with buckets of 2,500 ps, at every node count. It is the best fixed arm or within 3–5% of it everywhere, apart from the one slow rep.
  - `--fossil-lazy`, `--fossil-rounds` and `--fossil-finish` stay in the code, off and unused.
  - The VLSI row of the paper (sections 217 and 226) used lazy commits and needs rerunning, with Devastator in the same allocation.
  - F1's 32-node job runs the new setting beside W 2,500 (decision 2 of section 235).
- **The controller row on VLSI:**
  - Its trial range could reach at least two buckets, for example `max(99th percentile of delay, 2 × bucket)`. Whether that bound would bind on the other seven workloads needs each one's delay percentiles, which the controller logs do not print. On PHOLD and traffic, buckets of 8 sit far below delays of hundreds; dragonfly is to be checked. It is a change to the frozen controller.
  - Or the paper reports the frozen controller held at one bucket on VLSI, with the reason above.

### §238 · The paper's VLSI row with VLSI's new setting: eager commits at W 5,000, the widened controller and Devastator in one allocation, at 1–16 nodes (job VS3 design, 2026-11-06; written before any runs)

> **Status: done; results in section 239.** User decisions 2026-11-06 (section 236): VLSI switches to eager commits at W 5,000, the controller's trial range reaches two buckets (section 237), and the VLSI row is rerun at 1–16 nodes with Devastator in the same allocation and a check on the slow reps.
> - **Tree:** `charades-r5` at charades 85a2aad on `charm-pads-perf` (`$WORK/charades-runs/build_r5.sh`): round 3, eager commits by default, `--ctl-reach-buckets=2`. Devastator's 2 × 23 binaries as in VS2.
> - **Script:** `$WORK/charades-runs/vscale238.slurm` (copy in `~/charades-data/vlsi/`), skx-dev plus an skx copy, 16 nodes, 50 minutes, `-x c455-081`. Login-node checks pass. Submitted 2026-11-06 as 3688291 (skx-dev) and 3688292 (skx); the copy that starts second is cancelled. Checked on the Mac against stubs for `ctl_sweep.sh`, Devastator and the node sampling: arm order, options per run, and which node is sampled.

**Arms** (b19 × N, one copy per node, 5,000 cycles, direct sends):
- **Charades,** 1 × 46, `--batch=32`, buckets of 2,500 ps, `--pe-stats=1`:
  - **E, W 5,000:** eager commits (the new setting);
  - **E, W 2,500;**
  - **L, W 2,500:** lazy commits, VS2's setting from 4 nodes up, for continuity;
  - **the controller** (`--ctl=3`, bracketed, reach 2 buckets), eager commits.
- **Devastator** 2 × 23 at W 2,500, 5,000 and 10,000, launched as in VS2.
- 3 reps; engines interleaved per rep, engine and arm order reversed in rep 2; a warm-up run per node set.
- 8, 4, 2 and 1 nodes side by side (nodes 0–7 / 8–11 / 12–13 / 14), then 16 nodes. About 30 minutes.
- **Gate:** VS2's change tier on 2 nodes (VLSI), eager commits. A gate that ran no test now fails.

**The slow reps.** Four reps so far ran about 1.3× long: PE 105 (copy 2's node, rank 13) took longer per cycle with the same events (sections 234, 236).
- `+pemap` pins rank 13 to core 28.
- From 4 nodes up, the job reads `/proc/stat` and `/proc/interrupts` on copy 2's node before and after each Charades run: each core's user, system, interrupt and softirq time, and each interrupt's count per core.

**Predictions** (Charades rates are M committed ev/s; ratios are speed, higher is better):
- **VS3-1. Counts:** every Charades run commits VS2's count with VS2's digest at each node count, and every Devastator run commits the same count.
- **VS3-2. Devastator reproduces VS2** within 5% at its best window: 45.3 / 85.4 / 83.8 / 149.1 / 295.5 M ev/s at 1 / 2 / 4 / 8 / 16 nodes.
- **VS3-3. Charades' E at W 5,000 ÷ L at W 2,500** is within 5% of job VC: 1.31–1.34 (1 node), 1.52–1.55 (2), 0.95–0.97 (4), 0.97–0.99 (8), 1.02–1.03 (16).
- **VS3-4. Charades ÷ Devastator,** each at its best fixed arm: 1.44–1.60 (1 node), 1.34–1.48 (2), 1.17–1.30 (4), 1.22–1.36 (8), 1.15–1.28 (16). That is VS2's 1.37 / 1.27 / 1.23 / 1.29 / 1.19 times VC's gain at each node count, within 5%.
- **VS3-5. The controller:**
  - Its trials pass the delay range ("Trials past it" above 0) in every run.
  - Its time-weighted mean W is at least 3,750 at 1, 2 and 16 nodes.
  - It reaches at least 0.90 of Charades' best fixed arm at 1–2 nodes (today's row: 0.64–0.75) and at least 0.95 at 4–16.
- **VS3-6. Eager ÷ lazy commits at W 2,500:** 0.93–1.02 (section 234: 1.00–1.02 at 4 nodes, 0.93–0.96 at 16).
- **VS3-7. Slow reps:**
  - If a Charades run at 4–16 nodes takes at least 1.15× its arm's median, core 28 shows at least twice the system, interrupt and softirq time, or the interrupts, of that arm's other reps.
  - If no rep is slow, the job measures only how often they occur.

**What follows:**
- **The paper's VLSI row at 1–16 nodes** becomes this job's: each engine at its best fixed arm, with Charades' controller beside it. The 32-node cell comes from F1's job, with the same arms.
- **If VS3-5 holds,** the VLSI controller row is the frozen controller with eager commits.
- **If VS3-7 finds a cause on core 28** (an interrupt, or another process), the fix depends on what it is, for example moving that interrupt or that rank. If it finds none, the slow reps are reported as spread between reps.

### §239 · VS3 results: with eager commits at W 5,000 Charades ÷ Devastator on VLSI is 1.51 / 1.40 / 1.26 / 1.30 / 1.25 at 1–16 nodes; the widened controller runs at 0.95–1.02 of Charades' best fixed arm at every node count (before: 0.64–0.75 at 1–2 nodes); no slow rep in 36 runs (2026-11-06; skx-dev batch job 3688291, 16 nodes)

> **Status: current for 1–16 nodes; 32 nodes are in F1's job.** Design and predictions in section 238. This replaces section 217's VLSI row at 1–16 nodes.
> - **Job:** 18 minutes; gate 27/27; every run finished. The skx copy 3688292 was cancelled before it started.
> - **Data:** `~/charades-data/vlsi/vscale238/j3688291/`; summary `~/charades-data/vlsi/vscale238_summary.py`, output `vscale238_summary.txt`.
> - **Counts (VS3-1 right):** at every node count, every Charades run commits VS2's count with VS2's digest, and every Devastator run commits the same count (deterministic).

**Rates** (M committed ev/s, median of 3; higher is better):

| nodes | Charades E, W 5,000 | Charades E, W 2,500 | Charades L, W 2,500 (VS2's) | Charades controller (E) | Devastator W 2,500 | Devastator W 5,000 | Devastator W 10,000 |
|---|---|---|---|---|---|---|---|
| 1 | **69.06** | 51.67 | 53.42 | 66.72 | 41.45 | 44.84 | **45.69** |
| 2 | **122.11** | 79.73 | 80.42 | 115.65 | 67.74 | 79.77 | **87.05** |
| 4 | 102.85 | **105.96** | 104.60 | 105.13 | **84.50** | 82.47 | 82.98 |
| 8 | 192.15 | 185.39 | 193.30 | **195.95** | 142.68 | 146.12 | **148.74** |
| 16 | 364.54 | 338.91 | 353.24 | **369.01** | 288.42 | **292.89** | 291.03 |

**Charades ÷ Devastator** (higher is better; each engine at its best fixed arm, per rep and as a ratio of medians; and Charades' controller against Devastator's best window):

| nodes | best fixed ÷ best fixed, per rep | ratio of medians | VS2 (section 217) | controller ÷ Devastator's best, per rep | controller ÷ Charades' best fixed arm, per rep |
|---|---|---|---|---|---|
| 1 | 1.51–1.53 | **1.51** | 1.37 | 1.45–1.47 | 0.95–0.97 |
| 2 | 1.38–1.41 | **1.40** | 1.27 | 1.33–1.34 | 0.95–0.96 |
| 4 | 1.25–1.27 | **1.26** | 1.23 | 1.23–1.27 | 0.99–1.01 |
| 8 | 1.30 | **1.30** | 1.29 | 1.29–1.32 | 0.99–1.01 |
| 16 | 1.24–1.26 | **1.25** | 1.19 | 1.25–1.26 | 0.99–1.02 |

- **Charades' best fixed arm** is eager commits at W 5,000 at 1, 2 and 16 nodes. At 4 and 8 nodes, W 2,500 (eager or lazy) and W 5,000 are within 3% of each other.
  - Against VS2 (section 217) Charades' best rises 1.12× at 1 node, 1.13× at 2 and 1.04× at 16, and holds at 4 and 8.
  - **Devastator reproduces VS2 within 2%** (VS3-2 right): 45.7 / 87.0 / 84.5 / 148.7 / 292.9 against 45.3 / 85.4 / 83.8 / 149.1 / 295.5 M ev/s.
- **The controller:**
  - Its trials passed the delay range in every run (54–132 per run). The least 0.99 quantile of delay was 27.8 ps, under a bucket of 2,500, as expected.
  - Its time-weighted mean W was 3,561–4,250 at 1 node, 4,600–4,632 at 2, 2,838–4,405 at 4, 3,084–3,285 at 8 and 3,403–4,260 at 16.
  - It is the fastest Charades arm at 8 and 16 nodes by median.
- **Per-node rate from 4 to 16 nodes** (each at its best; 1.0 is perfect): Charades 0.858, Devastator 0.867. From 4 to 8: 0.917 and 0.886.
- **Eager ÷ lazy commits at W 2,500:** 0.96–0.98 (1 node), 0.97–1.00 (2), 1.00–1.02 (4), 0.96 (8), 0.95–0.99 (16).
- **No slow rep:** all 36 Charades runs at 4–16 nodes ran within 0.98–1.03 of their arm's median.
  - PE 105's working time per cycle was steady within each arm: 1.07–1.10 ms at W 5,000, 0.78–0.80 at W 2,500 with eager commits.
  - Core 28 on copy 2's node took 7,000–8,900 interrupts per run, mostly the local timer, and 8–12 jiffies of system time, the same in every rep.
  - So this job learns only that the slow reps are not every-run events. Earlier jobs had 4 in about 60 runs at W ≥ 3,750, in other allocations.

**Predictions (section 238):**
- **VS3-1 right.**
- **VS3-2 right.**
- **VS3-3 right:** E at W 5,000 ÷ L at W 2,500 is 1.28–1.32 / 1.50–1.53 / 0.97–0.99 / 0.97–1.01 / 1.01–1.06.
- **VS3-4 right at every node count:** 1.51–1.53 / 1.38–1.41 / 1.25–1.27 / 1.30 / 1.24–1.26 per rep.
- **VS3-5 mostly right:**
  - Its trials pass the delay range in every run.
  - It reaches 0.95–0.97 of Charades' best at 1–2 nodes (at least 0.90 predicted) and 0.99–1.02 at 4–16 (at least 0.95).
  - Its mean W reaches 3,750 in 7 of 9 runs at 1, 2 and 16 nodes, not all 9 (3,561 at 1 node rep 2, 3,403 at 16 nodes rep 3).
- **VS3-6 right.**
- **VS3-7:** no slow rep occurred, so the job could not test it.

**What follows:**
- **The paper's VLSI row at 1–16 nodes** is this job's. Charades ÷ Devastator is 1.51 / 1.40 / 1.26 / 1.30 / 1.25 (each at its best fixed arm), or 1.46 / 1.33 / 1.24 / 1.32 / 1.26 with Charades' controller. It was 1.37 / 1.27 / 1.23 / 1.29 / 1.19.
- **32 nodes:** F1's job runs these four Charades arms and Devastator's three windows. The 32-node slow waves cost W 2,500 up to 11% (section 228), so W 5,000 and the controller should gain more there.
- **The VLSI controller row** is the frozen controller with eager commits and `--ctl-reach-buckets=2`.
- **The slow reps stay open.** Every 32-node run in F1 can sample copy 2's node the same way at no cost.

## Earlier

Superseded or historical sections, in the order they were written. Their numbers came from an older stack, launch or setting, or a later section replaced them; each says which.

### §216 · VLSI at 1–32 nodes with round 3, a cycle-time trace per node count, and one process against two per node on the other workloads (job VS2 design, 2026-11-03; written before any runs)

> **Status: design.** Section 212's rule: round 3 gained 1.64× at 1 node (section 215), more than 3%, so the Charades cells are rerun on the new tree.
> - **Script:** `$WORK/charades-runs/vscale216.slurm` (copy in `~/charades-data/vlsi/`).
> - **Trees:** `charades-r3` at ae0dbd3 (round 3's code, b0b4ed4, plus `ctl_sweep.sh` keeping each run's `gvt_trace.csv`; the binaries built for job 3679892 are unchanged); `charades-perf` (5b14290) for job a's tree; Devastator and ROSS as in job VS.
> - **Job big (3679725, still pending) is cancelled.** big2 replaces it and runs everything big would have plus the new tree, so the 32-node cells come from one allocation.
> - **Submitted 2026-11-03:** a2 as 3679974 (skx-dev) and 3679975 (skx), the later starter to be cancelled; big2 as 3679976 (skx). Pre-run checks pass on the login node.

**Arms:**
- **Charades with round 3** (1 × 46, `--fossil-lazy=1 --batch=32`, buckets of 2,500 ps): the controller, W 2,500, W 5,000; 3 reps (5 at 32 nodes).
- **Once per node count**, W 2,500 with `--gvt-trace=1`. PE 0 then records each count wave's start and result. With W one bucket (one clock period), each cycle splits into the wave in flight and the time between a result and the next wave's start.
- **Devastator 2 × 23** at W 2,500 / 5,000 / 10,000 in the same allocation. Its 1 × 46 and ROSS only in big2: job a measured them at 1–16 nodes, and neither layout nor engine was close.
- **big2 only:** Charades on job a's tree (`charades-perf`), the same arms, for the 32-node cell of the old series.
- **Layout check** (a2, the 1- and 4-node series after their VLSI reps):
  - round 3 at 1 × 46 against 2 × 23 over LCI;
  - σ 100 (PP 2,048, W 300), uniform (WPs 512, W 300), traffic (PP 2,048, W 500), dragonfly (WPs 512, W 10,000);
  - V5's sizes, 2 reps.

**Jobs:**
- **a2** (skx-dev, 16 nodes): 1-, 2-, 4- and 8-node series side by side, then 16; about 25 minutes.
- **big2** (skx, 32 nodes, 5 reps): builds Devastator's 32-node 1 × 46 binary first if it is missing; about 55 minutes.

**Predictions:**
- **Q1. Counts.** Each node count commits job a's count in every engine and tree. Round 3's digest equals the old tree's at each node count.
- **Q2. Round 3 ÷ the old tree** (each at its best arm; job a for 1–16 nodes, big2 for 32): 1.55–1.75 at 1 and 2 nodes; 1.15–1.50 at 4–32 nodes. From 4 nodes on node 2's work paces each cycle, and the wait for each cycle's GVT advance does not shrink with per-event cost.
- **Q3. Charades ÷ Devastator** (same allocation, each at its best): at least 1.25 at 1 and 2 nodes; at least 1.05 at 4–32 nodes.
- **Q4. Scaling.** Charades' per-node rate from 4 to 16 nodes falls to 0.70–0.85 (job a: 0.80). The fixed GVT cost per cycle is now a larger share of a shorter cycle. Devastator stays at 0.85–0.95.
- **Q5. The trace.** From 4 to 16 (and 32) nodes, at least 60% of the growth in Charades' cycle time is the count wave in flight (start to result), not the time between waves.
- **Q6. Layout.** With glibc contention gone, round 3 at 1 × 46 is at least 0.95 of 2 × 23 on at least two of the four workloads at 1 node. Section 78's 0.71–0.87 was on the old tree, with the pool's misses going to glibc. At 4 nodes, where 1 × 46 sends all of a node's off-node events through one process's htram, it is 0.85–1.10.

**What follows:**
- The VLSI row of the paper's applications table uses round 3's cells, if Q1 holds.
- If Q5 holds, the next step on VLSI scaling is the GVT advance: a wave per clock cycle is the design limit at W one period.
- If Q6 finds 1 × 46 ahead on the other workloads, their launch changes. That would mean rerunning the paper's tables (with round 3's 1.16–1.18 on PHOLD as well), which the user decides.

### §217 · VS2 results at 1–16 nodes: with round 3 Charades ÷ Devastator is 1.37 / 1.27 / 1.23 / 1.29 / 1.19; the count waves take 13–19% of each clock cycle; one process per node is level with two at 1 node on the other workloads but 0.59–0.86 of it at 4 (2026-11-03; skx-dev batch job 3679974, 16 nodes)

> **Superseded (2026-11-07):** the paper table now comes from §239 at 1–16 nodes.

> **Status: current for 1–16 nodes; 32 nodes (big2, 3679976) in section 226.** Design and predictions in section 216.
> - **Job:** gate 27/27; 18 minutes (skx copy 3679975 cancelled). Every run finished.
> - **Data:** `~/charades-data/vlsi/vscale216/a2_j3679974/`; summary `~/charades-data/vlsi/vscale216_summary.py` (output `vscale216_a2_summary.txt`).
> - **Counts (Q1 right):** at every node count, job a's count in both engines. Round 3's digest equals the old tree's (87c11aec…, 0002eae9…, 0c800d36…, 089e4484…, 377d0771…).

**Each engine at its best** (M committed ev/s, median of 3 reps, higher is better; ms per clock cycle, lower is better; Devastator 2 × 23 from this allocation, the old tree from job a):

| nodes | Charades, round 3 | Charades, old tree (job a) | Devastator | round 3 ÷ old | **Charades ÷ Devastator** | ms per cycle, round 3 / old / Devastator |
|---|---|---|---|---|---|---|
| 1 | 61.76 (W 5,000) | 38.30 | 45.26 (W 10,000) | 1.613 | **1.365** | 0.408 / 0.658 / 0.557 |
| 2 | 108.18 (W 5,000) | 78.03 | 85.43 (W 10,000) | 1.386 | **1.266** | 0.466 / 0.646 / 0.590 |
| 4 | 103.33 (W 2,500) | 82.55 | 83.75 (W 2,500) | 1.252 | **1.234** | 1.112 / 1.392 / 1.372 |
| 8 | 192.31 (W 2,500) | 149.84 | 149.05 (W 10,000) | 1.283 | **1.290** | 1.122 / 1.440 / 1.448 |
| 16 | 351.41 (the controller) | 265.23 | 295.49 (W 5,000) | 1.325 | **1.189** | 1.188 / 1.574 / 1.413 |

- **The controller** (buckets of 2,500 ps) is 0.98–1.01 of W 2,500 at every node count. It is Charades' best arm at 16 nodes.
- **Per-node rate from 4 to 16 nodes** (1.0 is perfect): round 3 0.850, old tree 0.803, Devastator 0.882. Charades still loses a little more per node than Devastator, but from a 1.23× lead.
- **The cycle split** (`--gvt-trace=1`, W 2,500, cycles 1,000–4,000; about two count waves per cycle; the traced runs are within 5% of the untraced W 2,500 cycle times):

| nodes | ms per cycle | count wave in flight | between waves |
|---|---|---|---|
| 1 | 0.466 | 0.059 (12.7%) | 0.407 |
| 2 | 0.617 | 0.115 (18.6%) | 0.502 |
| 4 | 1.172 | 0.149 (12.7%) | 1.023 |
| 8 | 1.111 | 0.169 (15.2%) | 0.941 |
| 16 | 1.173 | 0.215 (18.3%) | 0.958 |

- From 4 to 16 nodes, the waves add 0.066 ms per cycle. The untraced W 2,500 cycle grows by 0.076 ms (1.112 → 1.188). So the growth is about the size of the waves' growth.
- Most of each cycle, 0.94–1.02 ms from 4 nodes on, is execution between waves, set by node 2's busiest copy.

**Layout, round 3 at 1 × 46 ÷ 2 × 23 over LCI** (M committed ev/s, median of 2; above 1 favours one process; one count per cell):

| workload | 1 node: 1 × 46 / 2 × 23 | ratio | 4 nodes: 1 × 46 / 2 × 23 | ratio |
|---|---|---|---|---|
| σ 100, PP 2,048, W 300 | 51.48 / 54.26 | 0.949 | 179.18 / 211.95 | 0.845 |
| uniform, WPs 512, W 300 | 44.85 / 46.63 | 0.962 | 96.25 / 137.35 | 0.701 |
| traffic, PP 2,048, W 500 | 77.37 / 76.12 | 1.016 | 250.54 / 291.96 | 0.858 |
| dragonfly, WPs 512, W 10,000 | 57.31 / 44.39 | 1.291 | 71.34 / 121.40 | 0.588 |

- **At 1 node** one process per node is within 5% of two on PHOLD and traffic, and 1.29× on dragonfly. Before the glibc fix, section 78 found 0.71–0.87.
- **At 4 nodes two processes per node win** by 1.17–1.70×. Off-node events go through htram, and one process per node puts a node's whole stream through one process's buffers. That is unlike VLSI, whose copies exchange few events across nodes.
- **The paper's launch for these workloads stays 2 × 23.**

**Predictions (section 216):**
- **Q1 right.**
- **Q2 four of five:** 1.61 at 1 node and 1.25–1.33 at 4–16 inside their ranges; 1.39 at 2 nodes, under 1.55–1.75.
- **Q3 right:** 1.37 and 1.27 at 1 and 2 nodes (at least 1.25); 1.19–1.29 at 4–16 (at least 1.05).
- **Q4 right at its edge:** round 3's per-node rate from 4 to 16 nodes is 0.850 (0.70–0.85); Devastator's 0.882 (0.85–0.95).
- **Q5 half:** the waves' growth from 4 to 16 nodes (0.066 ms) is about 87% of the untraced cycle's growth (0.076 ms). But the traced cycles themselves did not grow (1.172 → 1.173), so the split is within the trace's noise.
- **Q6 half:** right at 1 node (0.95–1.29, all four at least 0.95); wrong at 4 nodes (0.59–0.86, not 0.85–1.10).

**What follows:**
- big2 adds the 32-node cell (all three engines, both Charades trees).
- **The VLSI row of the paper's table uses round 3** (Charades ÷ Devastator 1.19–1.37 at 1–16 nodes).
- **The paper's other tables** were measured on the paper's tree. Round 3 is 1.16–1.18× on PHOLD at 2 × 23 (section 215), and the launch stays 2 × 23. Rerunning them on round 3 is the user's decision.

### §229 · A VLSI window between one and two clock periods: its steady cost at 4–16 nodes (job VW design, 2026-11-05; written before any runs)

> **Status: superseded by section 233 before it ran.** Section 228's untested idea. User decision 2026-11-05: a separate small job, apart from F4. Submitted as 3684509 (skx), cancelled before it started (user decision 2026-11-05): job RA (section 233) runs W 3,750 beside W 2,500 and 5,000 with per-PE records, and keeps this section's rule for F1.
> - **Script:** `$WORK/charades-runs/vwin229.slurm` (copy in `~/charades-data/vlsi/`), skx, 16 nodes, 40 minutes. skx rather than skx-dev, because F4 holds the skx-dev slot.
> - **Code:** the binaries of job VS2 (tree `charades-r3`, ae0dbd3, round 3), so W 2,500 here compares directly with section 217.

**Why.** At W one clock period (2,500 ps), every cycle waits for a GVT advance, and in 32-node allocations slow advances cost 0–19% of a run (section 228). At W 5,000 the slow advances do not show (0–1.9%), but each cycle is 1.29–1.37× longer at 4–16 nodes: the busiest copy's PEs run a whole period ahead and roll back. A window of 1.25 or 1.5 periods lets PEs run on into the next cycle by a quarter or a half period while an advance is late. That may keep part of the tolerance at less of the cost.

**What this job measures:** only the steady cost, which 4–16 nodes show. Tolerance to slow advances needs a 32-node allocation (section 228), so it is tested only if the steady cost is small (below).

**Runs** (VS2's launch and sizes: b19 × N, one copy per node, 1 × 46 PEs, `--fossil-lazy=1 --batch=32`, buckets of 2,500 ps, 5,000 cycles, direct sends):
- W 2,500, 3,125, 3,750 and 5,000 ps; 3 reps, arm order reversed in rep 2; a warm-up run per node count.
- 4 nodes (nodes 0–3) and 8 nodes (nodes 4–11) side by side, then 16 nodes.
- Gate: VS2's change tier on 2 nodes (VLSI).

**Measures:** M committed ev/s; ms per cycle, as the median and as the fast level (10th percentile over 64-cycle intervals, as in section 228); events rolled back; the lowest PE's blocked share; committed count and digest.

**Predictions:**
- **VW1:** every run at a node count commits VS2's count with VS2's digest (4 nodes 574,541,914; 8 nodes 1,078,843,202; 16 nodes 2,087,384,844).
- **VW2:** W 2,500 and W 5,000 reproduce section 228 within 5%: W 5,000's cycle is 1.29–1.37× W 2,500's.
- **VW3:** W 3,750's cycle is 1.10–1.30× W 2,500's at 4–16 nodes, and it rolls back more events than W 2,500 and fewer than W 5,000.
- **VW4:** W 3,125's cycle is 0.97–1.10× W 2,500's.

**What follows:**
- If W 3,125 or W 3,750 costs at most 5% per cycle against W 2,500 at 16 nodes, F1's 32-node job runs it beside W 2,500 to measure its tolerance to slow advances.
- Otherwise the idea closes. The paper reports VLSI's 32-node spread as section 228 describes.
