# PADS 2027 paper: claims, figures and the work left

Written for: Ritvik and the Claude sessions working on Charades. It steers the
work until the paper is submitted. `RESULTS.md` stays the lab notebook: every
number and job lives there, and this file points into it.

**Deadline:** SIGSIM PADS 2027, second call, 2027-01-22. 10-page ACM full
paper, double-blind (check whether references count toward the 10 pages). The
IPDPS revision is due 2027-01-18, the same week.

**Framing (user decision, 2026-11-01).** Aggregation is the performance
contribution. The controller is the robustness contribution: it makes that
performance available without tuning the optimism window for each workload.

## Claims

1. **GVT-safe event aggregation for message-driven Time Warp.** Remote events
   go through a node-aware aggregation library (htram). Buffered events count
   as in transit for the bucketed GVT. A deadline policy flushes an event once
   GVT plus the window reaches its timestamp. Anti-messages and GVT traffic
   bypass the buffers. The committed events are identical to direct sends.
2. **A global-view optimism window that needs no tuning.** Every PE's
   elapsed time and committed events are summed on the GVT's own count waves.
   The window moves toward the lowest PE time per committed event, and each
   trial is judged against measurements before and after it. A histogram of
   remote-send delays, carried on the same waves, gives the starting window
   and its range. Across regimes and applications it stays near the best
   hand-tuned window (0.83–1.03 on the current tree, RESULTS.md 230), where
   any single fixed window (0.52), a rollback-target rule (0.31 on dragonfly),
   Devastator's efficiency hill climb in Charades (0.13) and Devastator's own
   window (0.09, or not finishing) fail somewhere.
3. **Evaluation at 1–32 nodes (up to 1,472 cores) against Devastator
   (PADS'24) and ROSS.** The workloads are Gaussian PHOLD and three applications
   (traffic, dragonfly, gate-level VLSI), with the same committed events in all three engines.
   Charades is fastest where communication is remote-heavy, the regime
   Devastator names as its weakness.
4. (Within the implementation section, not a headline.) What it took to scale
   an SMP message-driven engine:
   - a consistent cut for the bucketed GVT with several PEs per process;
   - per-LP rollback;
   - count waves combined per process;
   - OS effects such as automatic NUMA balancing.

**What the paper does not claim.** On steady workloads the controller ties a
well-chosen fixed window; its value is that nobody has to choose one. It is
not faster than the best fixed window on those workloads.

## Outline (10 pages)

| section | pages | content |
|---|---|---|
| 1 Introduction | 1 | remote-heavy optimistic PDES; Devastator's open regime; the claims |
| 2 Background and prior work | 1 | Time Warp, GVT, optimism control (Elastic Time, Ferscha, Mikida & Kale PADS'19 hold, Devastator), aggregation (PADS'98 local rate, TramLib) |
| 3 Aggregation in Time Warp | 1.5 | in-transit accounting, deadline flush, anti-message bypass, flush rules, correctness |
| 4 The window controller | 1 | sums on count waves; measured cost (busy + blocked PE time per committed event); bracketed trials; the delay histogram for scale and range; why a rollback target fails (dragonfly) |
| 5 Implementation | 0.75 | Charades on Reconverse, htram modes, fast paths, the scaling fixes (claim 4) |
| 6 Evaluation | 4 | figures below |
| 7 Conclusion | 0.25 | |

## Figures and tables

Status:
- **have**: current numbers exist;
- **rerun**: data exist on older defaults, and the paper-grade run uses the final ones;
- **missing**: never measured.

| id | shows | supports | source in RESULTS.md | status |
|---|---|---|---|---|
| T1 | committed events equal in all three engines, every workload and node count | 1, 3 | 142–143 (40 cells), 169–172, 177 | have; repeat in the final runs |
| F1 | weak scaling 1–32 nodes, Gaussian PHOLD σ 100 to uniform and lookahead 10, three engines (M ev/s, and Charades ÷ each) | 3 | 142–143, 153 (A2r), 166 (N32 launch) | rerun on final defaults; 5 reps at 32 nodes (32-node runs vary ±14% between reps) |
| F2 | aggregation ablation: direct sends, eager flush (`--agg-policy=0`), deadline flush, by σ; events per message and messages per event | 1 | 223 (job ABL, round 3, 4 and 16 nodes, PHOLD and traffic) | have: deadline ÷ direct 2.1–3.3 on PHOLD, 1.4 on traffic; eager ÷ deadline down to 0.61 (uniform, 16 nodes) |
| F3 | the PADS'19 static hold and opportunistic (eager) aggregation as baselines | 1, 2 | 223 (eager), 225 (hold, 4 and 16 nodes) | have. Eager ÷ deadline down to 0.61; the PADS'19 hold (its own release rule; job F3R, 225) reaches at most 1.02 of no hold with the fast path on (0.83–1.02), and 0.30–0.40 (PHOLD) and 0.67–0.72 (traffic) of deadline htram |
| F4 | robustness: each policy ÷ the best fixed W per workload (controller, best single fixed W, Devastator's rule in Charades, Devastator's own window), and each policy's worst case | 2 | 181, 185 (frozen rule, quantile rule, fixed grids; 7 workloads, 4 and 16 nodes) | have (job F4, RESULTS.md 230; 7 workloads at 4 and 16 nodes, current tree): controller 0.83–1.03 (0.92–1.03 in 12 of 14 cells); Devastator's rule in Charades 0.13–0.84; Devastator's own window 0.09–0.83, not finishing on 2 workloads; one PHOLD window 0.52–0.55. Phase-changing PHOLD at 16 nodes: rep 2 hit by an episode on the machine, replaced by job F4R (RESULTS.md 232; controller 0.95–0.96) |
| F5 | applications: traffic, dragonfly and VLSI (b19 × N) at 1–32 nodes, three engines | 3 | 168–172, 175, 177 (ports, counts, sizes); 188, 189, 194 (traffic and dragonfly, 1–32 nodes) | traffic and dragonfly have (2026-11-02; Charades ÷ Devastator 0.94–2.03 dragonfly, 1.02–1.08 traffic; ÷ ROSS 1.7–4.3, ROSS without its window); VLSI on round 3 at 1–32 nodes (RESULTS.md 217, 226: Charades ÷ Devastator 1.19–1.37 at 1–16 nodes, 1.05 at 32, per rep 0.96–1.07) |
| F6 | where a wider window's cost goes: blocked time and GVT wave period by W | 2, 4 | 176 (4/16 nodes), 184 (16/32 nodes) | have |
| T2 | what scaling took: each fix and its gain | 4 | 21, 26, 24, 50, 88–90, 111, 161, 164, 152 | have; one table |

## Work left, in order

Each item is a job or a code change. Nothing outside this list gets Stampede3
time without a reason written here first.

**Runtime for the paper's runs since V5 (job 3678365):** `charm-pads-perf` on Stampede3 is Charm++ 9d6a55780 with Reconverse at 75719d5. Its source tree is identical to `origin/pads-perf` (bab3df1), published 2026-11-04 without a PR. The shared-memory pool rewrite from that branch is upstream PR charmplusplus/reconverse#319 (RESULTS.md 218–219). Upstream Reconverse with current Charm++ runs Charades at about half this stack's rate; the cause is not measured (RESULTS.md 219).

1. **Controller: DONE, frozen 2026-11-01 (RESULTS.md 185).**
   - **The rule:** the measured rule, bracketed (`--ctl=3`, `--ctl-bracket=1`, main b67e32d). The delay histogram gives the starting scale and range. W moves toward lower PE time per committed event, and a trial is kept only if it beats the base measured before and after it.
   - **Jobs M and N, 7 workloads at 4 and 16 nodes:**
     - the frozen rule is 0.91–1.03 of the best fixed W in every cell;
     - the quantile rule falls to 0.31 (dragonfly), the unbracketed rule to 0.87, any single PHOLD window to 0.54.
   - **Weakest workload:** phase-changing PHOLD (0.91–0.95). The rule holds W in the best band there; the loss is the cost of measuring. The paper states it as the limit.
   - **History:** RESULTS.md 177–185. The quantile rule's bounds encoded PHOLD facts (179). The hybrid was the user's choice (180). The bracket was the one allowed change (182).
1a. **Traffic's committed count varied between runs: FIXED (RESULTS.md 183).**
   - `PendingHeap::erase` reordered equal-timestamp events (code from 2015); up to 1 multi-process run in 11 differed, with direct sends and htram alike.
   - Fixed and verified on the Mac (60/60 runs equal the sequential run's digest); job N checks it on Stampede3.
   - Every paper run of traffic and dragonfly carries `--commit-digest`, and T1 compares digests, not only counts.
2. **Job L32: CLOSED into item 1 (RESULTS.md 184).**
   - At 32 nodes the best fixed W is 400 for σ 100 and σ 2,000, and the lowest blocked share marks it (11 of 12 cells with L16).
   - The quantile rule reaches 0.87–0.96 of it on σ 100.
   - The measured rule is the rule this item called for, so no separate blocked-time rule.
   - F1's 32-node runs check that it finds W 400.
3. **Applications at 1–32 nodes, three engines (F5, T1): next.** Moved ahead of the ablation and out of the paper-grade block on 2026-11-02 (user decision). About 3–4 jobs.
   - **Status 2026-11-02:**
     - Traffic and dragonfly are done at 1–32 nodes (F5a, F5b, F5c; RESULTS.md 188, 189, 194), with one count per cell in all three engines.
     - Charades ÷ Devastator: dragonfly 0.94 at 1 node, rising to 2.03 at 32; traffic 1.02–1.08. Per-node rate 16→32: Charades 0.90 and 0.99, Devastator 0.80 and 0.95.
     - The controller is 0.95–1.10 of the best fixed W per rep at 32 nodes. On traffic it follows the best W as it widens from 500 to 1,000.
     - Open: ROSS's optimism window (`--max-opt-lookahead`) was never tried, so Charades ÷ ROSS (1.7–4.3) is against ROSS's best without one.
     - **VLSI (V1, RESULTS.md 195), balanced layout:** Charades ÷ Devastator 0.51 (1 node), 0.75 (4 nodes), 0.55 (span 4); ÷ ROSS 6.9–7.9 with ROSS's window. Charades makes one GVT update per clock cycle and waits at the window 44–75%. htram loses to direct sends (PP 0.65–0.83). The controller is held at W 500 ps (0.62–0.70 of the best arm). Diagnostic V2 (RESULTS.md 197): GVT pace is ruled out (GVT rounds fill 5–6% of each cycle). Each cycle's execution is a chain of dependent events with every PE waiting ≥ 20%. Buckets of one clock period (2,500 ps) make the controller pick the best fixed W (0.99). V3 (RESULTS.md 199): most of the gap is at the same W (Devastator's wider window adds only 1.08×). Sends between the node's two processes cost the sending PE 2 µs each and stall the heaviest senders; one process per node (1 × 46) makes Charades 1.32× / 1.28× faster, Charades ÷ Devastator 0.73 (1 node) / 0.96 (4 nodes). The cost added at 4 nodes is one copy's 1.56× activity, the same in every engine. Per-copy activity (RESULTS.md 201): copy 2 alone does 1.75× the median copy at 4–32 copies, so from 3 nodes on one node sets every engine's pace. **User decision 2026-11-03: keep the workload and report this in the paper** (per-node rates from 1–2 nodes to 4+ fall in every engine for that reason). Shared memory between processes (user's addition): Charm++ `--enable-shmem` and Reconverse `+ipc` were starved by Charades' message pool, fixed in c7373b4; job V4 (RESULTS.md 200) compares 1 × 46, shared memory and 2 × 23 in Charades and 1 × 46 against 2 × 23 in Devastator. V4 (RESULTS.md 202): one process per node is Charades' best VLSI layout (1.33× / 1.27×); Charades ÷ Devastator 0.77 (1 node) / 0.95 (4 nodes), each at its best. Shared memory between processes (Charm++ `--enable-shmem`, `+ipc`) runs at 0.17–0.21×: Reconverse's pool has one locked queue and allocator per process. Closing the gap (user decision 2026-11-03; RESULTS.md 203–205, 208): skipping the empty cancel-queue walk, lazy fossil collection (`--fossil-lazy=1`, a VLSI setting: it loses 4–6% on Gaussian and uniform PHOLD), batch 32, and Reconverse's shared-memory pool rewritten (2 × 23 through it 0.86 / 0.91 of 1 × 46). V5 (RESULTS.md 208): Charades ÷ Devastator **0.85 (1 node) / 1.00 (4 nodes)**, each at its best. On VLSI the controller sits at one bucket, so the bucket width sets W (2,500 ps for scaling: best at 4 nodes in both engines). Devastator's 1 × 46 hang (RESULTS.md 209) was PSM2 binding the whole-node process to one core; with `HFI_NO_CPUAFFINITY=1` it runs at 0.87 of its 2 × 23, so Charades 1 × 46 against Devastator 2 × 23 is each at its best layout (1 node; 4 nodes still to run). At the same layout the engines are level; Devastator's two-process gain is socket locality, which Charades barely depends on. Round 2 (RESULTS.md 211): skipping the network poll and running passes back to back (`--pass-loop`) change nothing (1.00 / 1.01); the per-pass work runs while PEs wait, and the earlier 13.9% network share was setup. Job VS (RESULTS.md 214, 1–16 nodes, before round 3): Charades ÷ Devastator 0.84 / 0.91 / 0.99 / 0.97 / 0.89 at 1 / 2 / 4 / 8 / 16 nodes. One count per cell in all three engines; Charades ÷ ROSS 10–14. From 4 nodes on, Devastator's cycle stays at 1.38–1.41 ms while Charades' grows from 1.39 to 1.57 ms. **Round 3 (RESULTS.md 213, 215; charades b0b4ed4, the new defaults): Charades at 1 × 46 runs 61.8 M ev/s against 37.6, 1.64×, and 1.35× Devastator's 1-node best.** Most of it (1.42×) is the message pool's spare list: in one-process runs pool misses went to glibc and freed memory another thread allocated. Round 3 also gains 1.16–1.18 on PHOLD at 2 × 23. Job VS2 (RESULTS.md 217): **with round 3, Charades ÷ Devastator on VLSI is 1.37 / 1.27 / 1.23 / 1.29 / 1.19 at 1 / 2 / 4 / 8 / 16 nodes**, with Devastator measured in the same allocation, and **1.05 at 32 nodes** (job big2, RESULTS.md 226; per rep 0.96–1.07, one count in all three engines). From 16 to 32 nodes Charades' clock cycle grows by 14% and Devastator's stays flat. 94% of Charades' growth is the count wave in flight: at W one clock period every cycle needs a GVT advance, and a wave takes 0.157 ms at 32 nodes against 0.106 at 16. Section 228 (offline): two thirds of that growth is slow waves that come with the 32-node allocation (PHOLD shows them on 16 nodes of a 32-node allocation, not in a 16-node one), one third the cross-process tree gaining a level. The controller's 0.90–1.00 at 32 nodes is the same slow stretches; its steady cost is nil. The engine's own share of the 16 → 32 growth is about 2.6% of the cycle, and the GVT changes that could cut it were tried on PHOLD without gain (sections 52, 60, 118, 120, 162). A window wider than one period is immune to the slow waves but costs 1.13–1.37× per cycle on VLSI. Count waves take 13–19% of each clock cycle. One process per node is level with two at 1 node on PHOLD and traffic, and 1.29× on dragonfly, but 0.59–0.86 of it at 4 nodes, so those workloads keep 2 × 23. Running ahead costs Charades only once copy 2 is in the run: W 5,000 ÷ W 2,500 run time is 0.72–0.85 at 1–2 nodes and 1.24–1.35 at 4–16, where the least-blocked PE stops waiting and works 0.84 → 1.47 ms per cycle. Devastator is flat across W. Job RA (RESULTS.md 233–234): that cost was the lazy commit rule. The busiest PE never ends a pass short at W ≥ 3,750, so its commits wait four GVT updates, then cost twice as much and slow every event. With eager commits (`--fossil-lazy=0`), W 5,000 runs at 0.97–0.99 (4 nodes) and 1.02–1.03 (16 nodes) of the W 2,500 setting, and a two-period window should not feel the 32-node slow waves. From 3 nodes up one PE (node 2, rank 13) runs 2,141 events per cycle, 3.3× any other node's busiest PE, and sets the cycle in every engine (same nets per PE); the paper should say so. **Decided 2026-11-05 (RESULTS.md 234–235):**
       - VLSI's commit setting comes from job VC (RESULTS.md 236): **eager commits, the engine default, at W 5,000** (buckets of 2,500 ps). They are the best fixed arm at 1, 2 and 16 nodes and 0.95–0.99 of it at 4 and 8; lazy commits no longer pay anywhere, including `--fossil-finish` (0.89–0.95 of eager). The VLSI row (RESULTS.md 217, 226) used lazy commits and is to be rerun with Devastator in the same allocation.
       - F1's 32-node job runs that setting at W 5,000 beside W 2,500.
       - The VLSI controller row: buckets of 5,000 ps lose (0.74–0.90 of the best fixed arm; GVT every two periods). The frozen controller cannot reach W 5,000 with buckets of 2,500: its trials stay inside the 1st–99th percentile of remote delay, under one bucket on VLSI (`controller.C:464`). Today's row is 0.64–0.75 of the best fixed arm at 1–2 nodes. **Decided 2026-11-06 (RESULTS.md 236):** VLSI switches to eager commits at W 5,000; the controller's trial range is widened to at least two buckets (a change to the frozen controller, before 2026-12-07); the VLSI row is rerun at 1–16 nodes with Devastator in the same allocation, the widened controller and one traced rep for the slow reps (PE 105's core and interrupts).
       - The workload stays, and the paper states that from 3 nodes up one PE (node 2, rank 13; 2,141 events per cycle, 3.3× any other node's busiest PE) sets VLSI's pace in every engine. **Open (user decision):** whether the paper's PHOLD, traffic and dragonfly tables are rerun on round 3, and on which layout.
   - **Why first:**
     - Traffic and dragonfly have never run above 16 nodes. At 32 nodes PHOLD needed changes no smaller run showed (NUMA balancing, best W 400); a problem found after the freeze would leave no time to fix it.
     - Claim 3 rests on them, and the evidence so far is mixed: dragonfly gains only 1.06–1.10× from aggregation at 1 and 4 nodes (RESULTS.md 179), and traffic sends little across the network. The results set how claim 3 is worded.
     - Section 6 can then be written around them in December.
   - **Paper-grade now.** The paths these runs use are already final: the frozen controller, the defaults in item 5 and the heap fix. If a change before the freeze touches them, the affected cells are rerun in item 6.
   - **Jobs:**
     - Calibration (skx-dev, 1 and 4 nodes): Devastator's W grid and ROSS's settings on both applications, never swept. Charades' best fixed W is known (dragonfly 10,000–20,000 ps, traffic 500).
     - 1–16 nodes (skx-dev, 16 nodes): the series side by side, as in A1.
     - 32 nodes (skx): 16 nodes side by side on the two halves, then 32 nodes; 5 reps at 32.
   - **Arms:** Charades' controller and its best fixed W, and direct sends at that W (aggregation's gain on the applications); Devastator over its W grid; ROSS's better of optimistic and conservative.
   - **Checks:** every Charades run with `--commit-digest`. T1 compares counts across engines and digests within Charades.
   - **VLSI, added 2026-11-02** (advisor's suggestion; user's choice of gate-level simulation and of b19 × N): copies of ITC'99's b19 (231 k nets) joined in a ring, one copy per node (RESULTS.md 190).
     - **Why b19 × N:** b19 alone gives 10 messages per PE per cycle at 32 nodes, too little work; one copy per node keeps each PE near 5,000 gates.
     - **Status:** model and ports in all three engines. V0 (RESULTS.md 192): one count in every engine, but the file-order layout put every flip-flop on one PE (9.8× the mean load), so its rates measured one PE. Balanced layout since 2026-11-02 (`--chunk=512`, RESULTS.md 193: busiest PE 1.04× the mean, the same nets per PE in all three engines). Calibration V1 on it, then 1–32 nodes.
     - **Open from V0:** the controller holds W at 500 ps on VLSI (0.85–0.90 of the best fixed W; every remote delay is under one bucket); to recheck on the balanced layout. ROSS's runs need its window (`--max-opt-lookahead`), which no run used before V1; the F5 ROSS grids on traffic and dragonfly lack it too.
     - **Beyond 32 nodes (user's goal):** 64–256 nodes once 32 is solid. That needs Devastator builds past 32 nodes, and dragonfly shapes if the other applications go too.
   - **Sizes** (RESULTS.md 177; about 10 s at the 1-node rate): dragonfly arrival 500 ns, generating 300,000 ns; traffic end 12,000,000. ROSS takes 2–5× as long, which sets the job lengths.
4. **Ablation and robustness on the current stack (F2, F3, F4).** 4 and 16 nodes, skx-dev; about 2 jobs.
   - Workloads: lookahead 10 and 100 × σ 100, σ 2,000 and uniform; phase-changing PHOLD; traffic; dragonfly.
   - Arms: direct, eager and deadline aggregation; the PADS'19 hold over a cutoff sweep; a fixed W grid; the controller; Devastator's rule in Charades.
   - ~~`--agg-scope=1` on traffic and PHOLD~~ **dropped 2026-11-04** (RESULTS.md 187, correction, and 222). The local fast path, on by default, keeps events for the same process out of htram with direct sends and htram alike. So htram only carries events to other processes, and traffic's 1.36–1.40× is aggregation of those events (8.2 M messages become 0.69 M), not a same-process effect.
   - Devastator's own adaptive window, run on the PHOLD workloads.
   - **Status 2026-11-04:** user decision: F2 and F3 on PHOLD and traffic, plus ROSS's window (`--max-opt-lookahead`) on traffic and dragonfly; job ABL (RESULTS.md 222–223).
     - F2 is done (4 and 16 nodes).
     - F3's eager arm is done. The hold arms used the code's default release (at the event's bucket), not PADS'19's (all held events at the next GVT), and all hit the cap; they need a rerun.
     - F3 rerun (job F3R, RESULTS.md 224): PADS'19's release rule; cutoffs scaled to the mean delay (PADS'19 counts them in buckets of width 1 and gives no delays); no hold with the fast path off as the hold's reference; the release loop's scan of every remaining bucket fixed (8a34d51); ROSS's dragonfly window down to 625 ps.
       - **Done (job F3R, RESULTS.md 225), 4 and 16 nodes.** The hold reaches 0.83–1.02 of no hold with the fast path on. It turns the fast path off (worth up to 1.33× on σ 100), and beside a window it changes little (0.90–1.06). Without a window, cutoffs up to one mean delay cost PHOLD 1.4–5.6×; on traffic they gain 1.09–1.10× at 4 nodes and are level at 16.
       - ROSS's best dragonfly window is 2,500 ps at 1 node and 5,000 at 4 (7,500 untried). Charades ÷ ROSS with it is 2.98–3.05.
     - ROSS's window: 1.13–1.19× ROSS on traffic, 1.35–1.48× on dragonfly, where the best value is the grid's edge (5,000 ps; extend to 2,500 and 1,250). Charades ÷ ROSS with it: traffic 1.75–1.90, dragonfly 3.0–3.2 (1 and 4 nodes); F5's ratios were against ROSS without a window.
     - F4 designed (job F4, RESULTS.md 227; user decision 2026-11-05: prepare F4): job N's seven workloads at 4 and 16 nodes on the current tree; Charades' fixed W grid, frozen controller and Devastator's rule in Charades (`--ctl=2` from one bucket), against Devastator's fixed W grid and its own window, in one allocation. Submitted 2026-11-05 as 3684492 (skx-dev) and 3684493 (skx).
       - **Done (job F4, RESULTS.md 230).** Controller 0.83–1.03 of the best fixed W; its baselines fall to 0.13 (Devastator's rule in Charades), 0.09 or not finishing (Devastator's own window) and 0.52 (one PHOLD window). Every cell commits one count in both engines. Phase-changing PHOLD at 16 nodes, whose rep 2 was hit by an episode on the machine, was rerun clean (job F4R, RESULTS.md 232): controller 0.95–0.96, Devastator's rule in Charades 0.40–0.44.
5. **Engine freeze, 2026-12-07.**
   - **Defaults already set:** per-LP rollback, `--agg-pp-alloc=1`, ring input buffers, `numactl --localalloc` launch (Charades only), 23 LCI devices, `+mempool_remote_free`.
   - **Frozen 2026-11-01:** the controller (`--ctl=3`, bracketed; item 1). The pending heap fix (item 1a) is in.
6. **Paper-grade runs, 2026-12-08 to 2027-01-05.**
   - F1 at 1–32 nodes, three engines; 5 reps at 32.
   - F5 cells only where a change before the freeze touched the paths they use (item 3).
   - F2 and F4 on the final defaults, if items 1–4 used earlier ones.
7. **Writing.**
   - Sections 1–5 in December, while the runs go.
   - Section 6 in January, finished by 2027-01-15, before the IPDPS revision.

**Cut** (out of this paper unless a reviewer-facing need appears):
- the PADS'98 local-rate aggregation arm (cite it);
- further GVT-wave tuning;
- the late rank 0 at σ 100 (sections 84–103);
- glibc no-trim;
- `--agg-auto` and flush-ahead (dropped in 76 and 139);
- anti-messages through htram.

## Numbers to quote today (to be replaced by the paper-grade runs)

Ratios: Charades ÷ the other (higher is better for Charades).
- **Charades ÷ Devastator at 32 nodes** (A2r, section 153; old launch):
  - 0.89 (σ 100), 1.04 (σ 500), 1.14 (σ 1,000), 1.24 (σ 2,000), 1.39 (σ 4,000), 1.66 (uniform);
  - lookahead 10: 0.99 (σ 500), 1.11 (σ 2,000);
  - 44 of 48 cells ahead over 1–32 nodes.
- **Charades ÷ ROSS:** 2.4–5.3× on PHOLD, against ROSS without its window (ROSS's window is untested on PHOLD). On the applications, against ROSS with its window, at 1 and 4 nodes: traffic 1.75–1.90, dragonfly 2.98–3.05 (sections 223, 225).
- **VLSI, Charades ÷ Devastator with round 3** (sections 217, 226; each at its best arm): 1.37 / 1.27 / 1.23 / 1.29 / 1.19 / 1.05 at 1 / 2 / 4 / 8 / 16 / 32 nodes; at 32 nodes 0.96–1.07 per rep. Charades ÷ ROSS 14.9 at 32 nodes.
- **The PADS'19 hold** (section 225): at most 1.02 of no hold with the fast path on (0.83–1.02), and 0.30–0.40 (PHOLD) and 0.67–0.72 (traffic) of deadline htram.
- **Aggregation, deadline htram ÷ direct sends, each at its better fixed W** (job ABL, round 3; section 223): 2.11 / 2.85 / 3.31 / 1.44 at 4 nodes and 2.20 / 2.87 / 2.65 / 1.37 at 16 (σ 100 / σ 2,000 / uniform / traffic).
- **Controller (frozen rule) ÷ best fixed W, 7 workloads at 4 and 16 nodes (job F4, section 230; current tree):**
  - 0.83–1.03; 0.92–1.03 in 12 of 14 cells; phase-changing PHOLD 0.83–0.88 at 4 nodes, 0.95–0.97 at 16 (F4 rep 1 and job F4R, section 232);
  - against, in the same job: Devastator's rule in Charades 0.13–0.84; Devastator's own window 0.09–0.83, not finishing within 120 s on phase-changing PHOLD and σ 2,000 at 4 nodes; one window for all PHOLD 0.52 (W 300) or 0.55 (W 100).
  - Jobs M and N (sections 181, 185; older tree): 0.91–1.03; the quantile rule 0.31 on dragonfly.
- **Charades ÷ Devastator, each at its best fixed W, on job F4's seven workloads** (round 3, short runs): 1.13–2.01 at 4 and 16 nodes.
