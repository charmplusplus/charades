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
2. **A global-view optimism window that needs no tuning.** It is set from a
   histogram of remote-send delays carried on the GVT's own count waves.
   Across regimes it stays near the best hand-tuned window, where any single
   fixed window, and Devastator's efficiency hill climb, fail somewhere.
3. **Evaluation at 1–32 nodes (up to 1,472 cores) against Devastator
   (PADS'24) and ROSS.** The workloads are Gaussian PHOLD and two applications
   (traffic, dragonfly), with the same committed events in all three engines.
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
| 4 The window controller | 1 | delay histogram on count waves, the quantile rule, its bounds, start-up |
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
| F4 | robustness: each policy ÷ the best fixed W per workload (controller, best single fixed W, Devastator's rule in Charades, Devastator's own window), and each policy's worst case | 2 | 32–34, 36, 40 (older stack); 173, 176 (current, steady workloads only); 177 (dragonfly: 0.29–0.41) | missing on the current stack; needs the dragonfly fix |
| F5 | applications: traffic and dragonfly at 1–32 nodes, three engines | 3 | 168–172, 175, 177 (ports, counts, sizes) | missing (all inputs ready) |
| F6 | where a wider window's cost goes: blocked time and GVT wave period by W | 2, 4 | 176 (4/16 nodes), L32 pending | have at 4/16 nodes |
| T2 | what scaling took: each fix and its gain | 4 | 21, 26, 24, 50, 88–90, 111, 161, 164, 152 | have; one table |

## Work left, in order

Each item is a job or a code change. Nothing outside this list gets Stampede3
time without a reason written here first.

1. **Controller on dragonfly.**
   - **Status, 2026-11-01:** job D (RESULTS.md 179) found that start-up is not the cause: both of the quantile rule's bounds misfire on dragonfly (0.33–0.40 and 0.78–0.87 of the best W).
   - The user chose the hybrid rule: `--ctl=3` (main 0e158d5), where the delay histogram gives the scale and measured PE time per committed event picks W.
   - Job M (RESULTS.md 180; 3669193 skx-dev / 3669194 skx) tests it on seven workloads at 4 and 16 nodes. The gate below applies to it.
   - The original plan for this item, kept for the record:
   - Start W from the delay histogram's quantile instead of the smallest window, or let W grow faster in the first updates.
   - Then a dragonfly W sweep at 1 and 4 nodes on long runs: W 2,500–20,000 ps and the controller. One skx-dev job.
   - **Gate:** the controller reaches at least 0.9 of the best W.
2. **Job L32 (queued, 32 and 16 nodes).**
   - If the lowest blocked share again marks the best W, and the controller misses it at 32 nodes, try one blocked-time rule in one job.
   - Otherwise the controller is final.
3. **Ablation and robustness on the current stack (F2, F3, F4).** 4 and 16 nodes, skx-dev; about 2 jobs.
   - Workloads: lookahead 10 and 100 × σ 100, σ 2,000 and uniform; phase-changing PHOLD; traffic; dragonfly.
   - Arms: direct, eager and deadline aggregation; the PADS'19 hold over a cutoff sweep; a fixed W grid; the controller; Devastator's rule in Charades.
   - Devastator's own adaptive window, run on the PHOLD workloads.
4. **Engine freeze, 2026-12-07.**
   - **Defaults already set:** per-LP rollback, `--agg-pp-alloc=1`, ring input buffers, `numactl --localalloc` launch (Charades only), 23 LCI devices, `+mempool_remote_free`.
   - **Open until the freeze:** the controller (items 1–2).
5. **Paper-grade runs, 2026-12-08 to 2027-01-05.**
   - F1 at 1–32 nodes, three engines; 5 reps at 32.
   - F5 at 1–32 nodes, three engines.
   - F2 and F4 on the final defaults, if items 1–3 used earlier ones.
6. **Writing.**
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
- **Controller ÷ best fixed W:**
  - 0.96–1.03 at 4–16 nodes on PHOLD (section 176);
  - 1.02–1.11 on phase-changing PHOLD (older stack);
  - 0.29–0.41 on dragonfly (section 177; to fix).
- **Devastator's own window ÷ its best fixed W:** 0.06–0.28 at σ ≥ 1,000 (older stack).
