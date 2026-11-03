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
   hand-tuned window (0.91–1.03), where any single fixed window, a
   rollback-target rule (0.31 on dragonfly) and Devastator's efficiency hill
   climb fail somewhere.
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
| F2 | aggregation ablation: direct sends, eager flush (`--agg-policy=0`), deadline flush, by σ; events per message and messages per event | 1 | 12, 28, 36 (4 nodes, older stack) | rerun at 4 and 16 nodes |
| F3 | the PADS'19 static hold and opportunistic (eager) aggregation as baselines | 1, 2 | open issue 1 (hold cutoff); `bucket_hold` config | missing |
| F4 | robustness: each policy ÷ the best fixed W per workload (controller, best single fixed W, Devastator's rule in Charades, Devastator's own window), and each policy's worst case | 2 | 181, 185 (frozen rule, quantile rule, fixed grids; 7 workloads, 4 and 16 nodes) | have for Charades' rules; Devastator's rule in Charades and Devastator's own window still to run (item 4) |
| F5 | applications: traffic, dragonfly and VLSI (b19 × N) at 1–32 nodes, three engines | 3 | 168–172, 175, 177 (ports, counts, sizes); 188, 189, 194 (traffic and dragonfly, 1–32 nodes) | traffic and dragonfly have (2026-11-02; Charades ÷ Devastator 0.94–2.03 dragonfly, 1.02–1.08 traffic; ÷ ROSS 1.7–4.3, ROSS without its window); VLSI after V1 (item 3) |
| F6 | where a wider window's cost goes: blocked time and GVT wave period by W | 2, 4 | 176 (4/16 nodes), 184 (16/32 nodes) | have |
| T2 | what scaling took: each fix and its gain | 4 | 21, 26, 24, 50, 88–90, 111, 161, 164, 152 | have; one table |

## Work left, in order

Each item is a job or a code change. Nothing outside this list gets Stampede3
time without a reason written here first.

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
     - **VLSI (V1, RESULTS.md 195), balanced layout:** Charades ÷ Devastator 0.51 (1 node), 0.75 (4 nodes), 0.55 (span 4); ÷ ROSS 6.9–7.9 with ROSS's window. Charades makes one GVT update per clock cycle and waits at the window 44–75%. htram loses to direct sends (PP 0.65–0.83). The controller is held at W 500 ps (0.62–0.70 of the best arm). Diagnostic V2 (RESULTS.md 197): GVT pace is ruled out (GVT rounds fill 5–6% of each cycle). Each cycle's execution is a chain of dependent events with every PE waiting ≥ 20%. Buckets of one clock period (2,500 ps) make the controller pick the best fixed W (0.99). V3 (RESULTS.md 199): most of the gap is at the same W (Devastator's wider window adds only 1.08×). Sends between the node's two processes cost the sending PE 2 µs each and stall the heaviest senders; one process per node (1 × 46) makes Charades 1.32× / 1.28× faster, Charades ÷ Devastator 0.73 (1 node) / 0.96 (4 nodes). The cost added at 4 nodes is one copy's 1.56× activity, the same in every engine. Per-copy activity (RESULTS.md 201): copy 2 alone does 1.75× the median copy at 4–32 copies, so from 3 nodes on one node sets every engine's pace. **User decision 2026-11-03: keep the workload and report this in the paper** (per-node rates from 1–2 nodes to 4+ fall in every engine for that reason). Shared memory between processes (user's addition): Charm++ `--enable-shmem` and Reconverse `+ipc` were starved by Charades' message pool, fixed in c7373b4; job V4 (RESULTS.md 200) compares 1 × 46, shared memory and 2 × 23 in Charades and 1 × 46 against 2 × 23 in Devastator. Open: the remaining 1-node gap (per-PE network polling ~18% of cycles at 2 × 23).
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
   - Plus `--agg-scope=1` (htram for other processes only) on traffic and PHOLD. On traffic, aggregation gains 1.36–1.38× while htram sends only 0.72% of events to other processes (RESULTS.md 187). The gain is most likely the same-process path, and the paper cannot call it network aggregation until this arm separates the two.
   - Devastator's own adaptive window, run on the PHOLD workloads.
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
- **Charades ÷ ROSS:** 2.4–5.3× everywhere.
- **Aggregation, best htram ÷ best direct** (4 nodes, older stack): 2.27 (σ 100) to 4.01 (uniform).
- **Controller (frozen rule) ÷ best fixed W, 7 workloads at 4 and 16 nodes (section 185):**
  - 0.91–1.03 in every cell;
  - steady PHOLD 0.93–1.03, traffic 0.95–0.97, dragonfly 1.00–1.03, phase-changing PHOLD 0.91–0.95;
  - worst case 0.91, against 0.31 for the quantile rule and 0.54 for any single PHOLD window.
- **Devastator's own window ÷ its best fixed W:** 0.06–0.28 at σ ≥ 1,000 (older stack).
