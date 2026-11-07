# Charades results: every measurement toward PADS 2027

This page holds the current paper tables. Every design and result, with its predictions, job IDs and status, is in a topic file under [`results/`](results/), listed below; [`results/INDEX.md`](results/INDEX.md) gives every section's number, date, job, status and file. Raw CSVs and logs stay where each section says (`$WORK/charades-runs/` on Stampede3; copies of recent ones in `~/charades-data/`). Goals, build notes and open issues are in `CONTEXT.md`; the paper's claims, figures and the work left are in `PAPER.md`.

**How to read it.**
- Rates are M committed events/s (millions per second), medians of the reps stated; higher is better.
- "÷ best fixed W" is an arm's rate over the best fixed optimism window in the same workload and job; higher is better.
- Cross-engine ratios from 2026-10-23 on are Charades' speedup (Charades ÷ the other; higher is better for Charades). Older sections often state Devastator ÷ Charades: check each table's header.
- Each section opens with a status:
  - **current**: the numbers to quote;
  - **provisional**: the decisions stand, but the numbers were not rerun on the current layout;
  - **superseded**: rerun on a faster runtime, transport or layout; kept for the record;
  - **historical**: a finding or fix whose numbers are from an older stack;
  - **design**: plans and predictions written before the runs.
- Stacks, in order: Debug runtime on verbs (through job 3626388) → production runtime (3626643) → fast paths, TLS and tuning on verbs (to 3627274) → native psm2 (3628343 on) → full nodes as the default (3629783 on). Before 3629783, most runs used 2 × 8 PEs per node.
- Devastator used its xorshift RNG in every run before job 3632385; it is about 10% faster than CLCG4 at σ 100.
- **Sections** are numbered §0, §1, … in the order they were written; "section N" or "RESULTS.md N" anywhere means §N, and [`results/INDEX.md`](results/INDEX.md) says which file holds it.
- **New work** gets the next § number and goes in the topic file it belongs to, under "Current", with a status line; add its row to `results/INDEX.md`. When it replaces an earlier section in a paper table, mark that one superseded in the index and in its status line, and move it under "Earlier".
- **Renamed 2026-10-27: "inbox" is now "input buffer"** (charades 80521a6, htram 699c3a9), in these files and in the code. Jobs before then ran with the old spellings: `--agg-inbox` and `--agg-inbox-mode` (now `--agg-input-buffer`, `--agg-input-buffer-mode`), test configs `agg_inbox*` and `agg_noinbox_*` (now `agg_inputbuf*`, `agg_noinputbuf_*`), htram's `HTramInbox`, `drainInbox` and `htram_inbox_mode`, and the fast path's `FpInbox`.

## Where everything is

Split on 2026-11-07 from one file of 11,400 lines and 249 sections; the text moved unchanged, and each section kept its number.

| file | what | sections |
|---|---|---|
| [results/phold.md](results/phold.md) | **PHOLD: performance and weak scaling.** Gaussian and uniform PHOLD in Charades, Devastator and ROSS: σ sweeps, full nodes, long runs, weak scaling from 1 to 32 nodes, and the paper runs F1. | 32 |
| [results/applications.md](results/applications.md) | **Traffic and dragonfly.** The two applications ported from Charades to ROSS and Devastator (phase B), the traffic count fix, and the paper runs F5 at 1–32 nodes. | 15 |
| [results/vlsi.md](results/vlsi.md) | **VLSI (b19 × N).** Gate-level simulation of copies of ITC'99's b19: the model and its layout, the gap to Devastator and how it closed, commits, and the paper's VLSI row. | 30 |
| [results/controller.md](results/controller.md) | **The optimism-window controller.** Every controller design and test: the delay-quantile rule, the aggregation bound, the measured-cost rule and its freeze, where the best window lies at scale, robustness (F4), and the controller's own cost (CC). | 37 |
| [results/aggregation.md](results/aggregation.md) | **Aggregation through htram.** Message cost, htram's modes and buffers, the deadline flush policy, choosing htram automatically, input buffers, PP's allocation and start-up, flush timing, and F2 (htram against direct sends). | 34 |
| [results/hold.md](results/hold.md) | **The PADS'19 hold (F3).** Mikida and Kale's hold of events past a cutoff, run as a baseline beside the window. | 2 |
| [results/engine.md](results/engine.md) | **The engine: GVT, rollback and per-event cost.** What paces the bucketed GVT at scale, rollback depth and unit, the same-process fast path, and the rounds that closed Charades' per-event gap to Devastator. | 53 |
| [results/runtime.md](results/runtime.md) | **Runtime, transport and the machine.** Reconverse builds and settings, native psm2 through LCI, LCI devices, the late-rank investigation, the message pool, NUMA balancing, shared memory between processes, and the slow node. | 43 |
| [results/baselines.md](results/baselines.md) | **ROSS and Devastator as baselines.** First runs and feasibility, ROSS's optimism window on PHOLD, and the Mac checks that both engines commit Charades' counts. | 3 |
| [results/methods.md](results/methods.md) | **Methods.** How runs are made and checked: run length and warm-up, and the flag check that keeps diagnostics out of timing runs. | 3 |
| [results/history.md](results/history.md) | The re-read of 2026-10-28 and the plan history | — |
| [results/INDEX.md](results/INDEX.md) | Every section by number, with its date, job, status and file | 252 |

## Current numbers

**Robustness of the window policies** (job F4b, section 251; F4's seven workloads at 4 and 16 nodes, current tree, no diagnostics; each policy ÷ the best fixed W of the same engine and rep, median of 3 reps; higher is better):

| policy | worst cell (median) | range over the 14 cells | where it fails |
|---|---|---|---|
| Charades' frozen controller | 0.92 | 0.92–1.03 (0.86–1.03 per rep); 0.96–1.03 in 13 of 14 | phase-changing PHOLD at 4 nodes (the cost of measuring) |
| Devastator's rule in Charades | 0.16 | 0.16–0.81 | σ 2,000 at 16 nodes; at most 0.46 on any PHOLD workload |
| Devastator's own window | did not finish | 0.09–0.84 where it finished | 120 s cap on phase-changing PHOLD and σ 2,000 at 4 nodes; out of memory on lookahead 10 at 16 nodes (2 of 3 reps); 0.09 on uniform at 4 nodes |
| one fixed window for the five PHOLD workloads | 0.51 (W 300), 0.55 (W 100) | | lookahead 10 (W 300), σ 100 (W 100) |

Every cell commits one count in both engines and one Charades digest, as F4. Charades ÷ Devastator, each at its best fixed W, is 1.16–2.00 on these short runs.

> **Being replaced (F5 on the final defaults, sections 240, 247).** 1–16 nodes are done without diagnostics (section 248): Charades ÷ Devastator 1.08 / 1.18 / 1.46 / 1.91 / 2.04 (dragonfly; 8 nodes 1.70 against Devastator's fastest rep) and 1.27 / 1.25 / 1.24 / 1.26 / 1.28 (traffic), ahead in all 10 cells; Charades ÷ ROSS with its window 2.93–3.13 (dragonfly) and 1.85–2.21 (traffic). The table below is rewritten when F5-32b adds the 32-node column.

**Applications, 1–32 nodes, three engines** (F5a 3673108, F5b 3673481, F5c 3673482; sections 188, 189 and 194; median of 3 reps, 5 at 32 nodes; Charades: its frozen controller; Devastator: best of three W; ROSS: best setting, **without its optimism window** (`--max-opt-lookahead`, not yet tried); one committed count per cell in all three engines):

| application | Charades ÷ Devastator at 1 / 2 / 4 / 8 / 16 / 32 nodes (higher is better) | Charades ÷ ROSS at 1 / 2 / 4 / 8 / 16 / 32 | per-node rate at 32 ÷ at 1, Charades / Devastator / ROSS (1.0 is perfect) | M ev/s at 32 nodes, Charades / Devastator / ROSS |
|---|---|---|---|---|
| dragonfly | **0.94** / 1.04 / 1.29 / 1.51 / 1.80 / 2.03 | 3.80 / 3.69 / 3.94 / 4.01 / 3.94 / 4.26 | **0.56** / 0.26 / 0.50 | 689.6 / 339.2 / 161.9 |
| traffic | 1.03 / 1.05 / 1.02 / 1.04 / 1.03 / 1.08 | 1.70 / 1.99 / 1.99 / 2.04 / 2.12 / 2.19 | **0.94** / 0.89 / 0.73 | 1,846.6 / 1,706.1 / 843.6 |

(Bold: below 1 in the ratio columns; best of the three in the efficiency column.) The controller is 0.95–1.05 of Charades' best fixed W per rep at 32 nodes. VLSI (b19 × N) at 1 and 4 nodes (V5, section 208): Charades (one process per node, lazy fossils, batch 32; its best W) ÷ Devastator (2 × 23, its best W) 0.85 / 1.00 (V1, section 195: 0.51 / 0.75; ÷ ROSS 6.9 / 7.9 then). Devastator at one process per node hung on Stampede3 because PSM2 pinned all its threads to one core; with `HFI_NO_CPUAFFINITY=1` it runs at 0.87 of its 2 × 23 at 1 node (section 209), so 0.85 compares each engine at its best layout. **Round 3 (sections 213, 215, 217, 226; charades b0b4ed4): Charades ÷ Devastator on VLSI is 1.37 / 1.27 / 1.23 / 1.29 / 1.19 / 1.05 at 1 / 2 / 4 / 8 / 16 / 32 nodes** (each at its best launch; at 32 nodes 0.96–1.07 per rep). From 16 to 32 nodes Charades' clock cycle grows by 14%, almost all of it the count wave in flight; Devastator's stays flat (section 226). Before round 3 it was 0.84 / 0.91 / 0.99 / 0.97 / 0.89 (section 214). **Section 234:** with eager commits (`--fossil-lazy=0`), W 5,000 runs at 0.97–1.03 of the W 2,500 setting above at 4–16 nodes, against 0.75–0.79 with lazy commits; from 3 nodes up one PE carries copy 2's extra work and sets every cycle in every engine. **§249 (current VLSI row at 1–16 nodes, without diagnostics; replaces §239):** with eager commits at W 5,000 and the widened controller (`--ctl-reach-buckets=2`), Charades ÷ Devastator is **1.51 / 1.44 / 1.27 / 1.29 / 1.24** at 1 / 2 / 4 / 8 / 16 nodes (each at its best fixed arm), or 1.45 / 1.36 / 1.27 / 1.30 / 1.26 with Charades' controller, which runs at 0.94–0.97 of Charades' best fixed arm at 1–2 nodes and 0.98–1.02 at 4–16. The 32-node cell comes from V32b (3690452, queued). Round 3 also runs PHOLD at 2 × 23 1.16–1.18× faster; the tables below predate it.

> **Being replaced (F1 on the final defaults, section 240).** 1–16 nodes are done (sections 242–243): Charades ÷ Devastator 1.08–2.25, ahead in all 40 cells (below: 38); Charades 1.08–1.23× faster than below, Devastator and ROSS unchanged; Charades ÷ ROSS 2.73–5.95; controller 0.930–1.032 of the better fixed W. The table below is rewritten when F1-32 adds the 32-node column.

**Paper-grade weak scaling, Charades against Devastator and ROSS, 1–32 nodes, all eight workloads** (jobs 3653803, 3654651 and 3657016, sections 142–143 and 153; long runs, 3 reps; Charades: its controller, the better htram setting at each node count, chare rollback (per-LP rollback came later, section 152); Devastator: its best of three W; ROSS: the better of optimistic batch 16 / GVT interval 64 and conservative; the same committed events in all three engines in every cell):

| workload | Charades ÷ Devastator at 1 / 2 / 4 / 8 / 16 / 32 nodes (higher is better) | Charades ÷ ROSS | efficiency 16→32, Charades / Devastator / ROSS (1.0 is perfect) | efficiency 1→32, C / D / R | M ev/s at 32 nodes, Charades / Devastator / ROSS |
|---|---|---|---|---|---|
| σ 100 | 1.10 / 1.06 / 1.03 / 1.03 / 1.04 / **0.89** | 2.42–3.02 | 0.82 / 0.96 / 0.82 | 0.75 / **0.93** / 0.60 | 1,107.2 / 1,242.2 / 366.1 |
| σ 500 | 1.03 / 1.03 / 1.08 / 1.20 / 1.19 / 1.04 | 3.47–4.08 | 0.81 / 0.93 / 0.89 | **0.76** / 0.75 / 0.71 | 977.1 / 936.1 / 261.4 |
| σ 1,000 | 1.07 / 1.12 / 1.22 / 1.33 / 1.29 / 1.14 | 4.11–4.43 | 0.84 / 0.94 / 0.89 | **0.75** / 0.70 / 0.74 | 927.8 / 812.4 / 223.2 |
| σ 2,000 | 1.27 / 1.37 / 1.34 / 1.38 / 1.35 / 1.24 | 4.05–4.77 | 0.87 / 0.94 / 0.90 | 0.71 / **0.73** / 0.64 | 857.9 / 690.6 / 189.9 |
| σ 4,000 | 1.32 / 1.66 / 1.67 / 1.66 / 1.60 / 1.39 | 4.10–4.87 | 0.84 / 0.97 / 0.90 | **0.65** / 0.62 / 0.63 | 774.3 / 558.9 / 182.3 |
| uniform | 1.38 / 1.87 / 1.99 / 1.94 / 1.84 / 1.66 | 3.82–5.32 | 0.72 / 0.80 / 0.66 | 0.39 / 0.33 / **0.41** | 508.7 / 306.8 / 122.8 |
| lookahead 10, σ 500 | 0.95 / 0.97 / 1.02 / 1.15 / 1.14 / 0.99 | 3.51–4.05 | 0.81 / 0.94 / 0.89 | **0.77** / 0.74 / 0.74 | 917.3 / 930.4 / 249.1 |
| lookahead 10, σ 2,000 | 1.19 / 1.28 / 1.27 / 1.28 / 1.35 / 1.11 | 3.98–4.44 | 0.81 / 0.98 / 0.86 | 0.69 / **0.74** / 0.66 | 741.7 / 666.7 / 178.0 |

(Bold: below 1 in the ratio column; best of the three in the 1→32 efficiency column.)

Charades is faster than Devastator in 44 of 48 cells and 2.4–5.3× faster than ROSS everywhere. At 32 nodes it leads in 6 of 8 workloads (1.04–1.66×), trails at σ 100 (0.89) and is level at lookahead 10 σ 500 (0.99). **But from 16 to 32 nodes Charades loses more per node than Devastator in every workload** (0.72–0.87 against 0.80–0.98), so it scales best from 1 to 32 nodes in only 4 of 8 workloads (6 of 8 from 1 to 16). Its controller is 0.93–0.97 of its best fixed W at 32 nodes on six workloads (0.96–1.03 at 1–16). Section 153 has the breakdown. These runs used chare rollback; per-LP rollback (section 152) came after them.

> **Launch change, 2026-10-30:** every Stampede3 run now goes through `numactl --localalloc` (`ctl_sweep.sh`'s `NUMA_WRAP`), so the kernel's automatic NUMA balancing skips our processes (section 164). At 16 nodes it gains 1.024–1.049×, and at 32 nodes 1.060× (σ 100), 1.124× (σ 2,000) and 1.028× (uniform), removing a dip 1.5–2.0 s after the clock starts (sections 164 and 166). Every table above used the default (balancing on), and so did Devastator and ROSS. Devastator does not gain from it (section 166), so each engine keeps its better launch in the paper-grade rerun.

> **Default change, 2026-10-29 (main 9d08fbd):** per-LP rollback inside a chare (`--rollback-unit=1`, section 152) is the default. A straggler rolls back only its own LP, not every later event of the chare's LPs: 3.5–15× fewer events rolled back at W 400, throughput unchanged (−1.6% to +2.2%). Every table above and below used chare rollback (`--rollback-unit=0`). Full test matrix 13,345/13,345 on the Mac.

> **Default change, 2026-10-30 (main d909989; needs htram `pdes` 42d347f):** htram PP's shared buffers are allocated at their own limit (`--agg-pp-alloc=1`, section 161), not at htram's largest size (about 1.2 MB per send). At 16 nodes that is 1.050× at σ 2,000 and 1.015× at σ 4,000 (PP 512), level at σ 100 and σ 1,000 (PP 2,048), and it removes most of PP's start-up ramp. Every table above and below used the old allocation. Mac engine tier 2,058/2,058.

**Charades and Devastator on long runs, 1 / 4 / 16 nodes, all eight workloads** (jobs 3650921 and 3652595, sections 124 and 130; end time 2,048,000, lookahead 10: 512,000; median of 3; each engine at its best setting: Charades over PP 512 and PP 2,048 (uniform: WPs 512 and PP 512; lookahead 10 σ 2,000: also WPs 512) × W 250/400/600 (lookahead 10: 50/100/200) and the controller; Devastator over W 500/1,000 (2,000 at 16 nodes; lookahead 10: 100/200/400), CLCG4; current launch):

| workload | Charades, 16 nodes (M ev/s) | Devastator, 16 nodes (M ev/s) | Charades ÷ Devastator, 1 / 4 / 16 nodes (higher is better) | efficiency 4→16, Charades / Devastator (1.0 is perfect) |
|---|---|---|---|---|
| lookahead 100, mean 1,000, σ 100 | 683.1 | 640.1 | 1.14 / 1.07 / 1.07 | 0.94 / 0.95 |
| σ 500 | 607.1 | 496.0 | 1.10 / 1.15 / 1.22 | 0.93 / 0.87 |
| σ 1,000 | 554.1 | 428.1 | 1.11 / 1.26 / 1.29 | 0.89 / 0.87 |
| σ 2,000 | 518.9 | 366.8 | 1.33 / 1.37 / 1.41 | 0.93 / 0.90 |
| σ 4,000 | 486.8 | 291.2 | 1.37 / 1.67 / 1.67 | 0.93 / 0.93 |
| uniform remote 1.0 | 363.3 | 190.9 | 1.43 / 1.98 / 1.90 | 0.67 / 0.70 |
| lookahead 10, mean 200, σ 500 | 561.5 | 492.6 | 0.99 / 1.06 / 1.14 | 0.94 / 0.87 |
| lookahead 10, σ 2,000 | 459.3 | 346.7 | 1.20 / 1.32 / 1.32 | 0.92 / 0.91 |

Charades is ahead in 23 of 24 cells (level, 0.99, at lookahead 10 σ 500 on 1 node) and scales as well or better in 6 of 8 workloads. Its controller is 0.98–1.03 of its best fixed W in every cell. The tables below are short runs.

> **Run length (2026-10-27, section 122):** the short runs below (end time 512,000) understate 16-node throughput by up to 16%: each run starts with a fixed transient of about 0.16 s on 16 nodes. In 4× longer runs σ 2,000 scales 4→16 at 0.96–0.97 and σ 4,000 at about 1.00. Devastator's efficiencies below come from the same short runs; both engines must be compared on long runs.
>
> **Launch changes since these numbers (2026-10-26/27):** `+lci_ndevices 23` (section 95), ring input buffers as Charades' default (section 111; uniform 1.08–1.21× at 16 nodes) and `+mempool_remote_free` (sections 113–114; Reconverse `pads-remote-free`, Stampede3 only). The tables below predate the last two; the paper-grade rerun will use all three.
>
> **As of 2026-10-25 (`main` 2369301).** Defaults: same-process fast path and `--gvt-node-waves` on, htram PP 512 with the deadline policy (horizon margin 8), full nodes (2 processes × 23 PEs per node, 128 LPs per PE), native psm2. Short runs (end time 512,000; 128,000 at lookahead 10; 1–4 s each) and 2 reps: the paper-grade rerun (3 reps, long runs) is still to do. Avoid Stampede3 node c455-081 (section 82).

> **Launch change, 2026-10-26:** `+lci_ndevices 23` (one device per PE) replaces 16: 1.08–1.46× at 16 nodes (geometric mean 1.21), 1.03–1.07× at 4 nodes (sections 88, 90). The 1–16 node table further down used 16 devices.

**Charades and Devastator, 1 / 4 / 16 nodes, one allocation, 23 devices** (job 3642157, section 95; c455-081 excluded; median of 3, short runs; each engine at its best setting: Charades over PP 512, PP 2,048 (WPs 512 for uniform and lookahead 10 σ 2,000) × W 250/400/600 and the controller (lookahead 10: W 50/100/200); Devastator over W 500/1,000 (2,000 at 16 nodes; lookahead 10: 100/200/400), CLCG4; glibc defaults for both):

| workload | Charades, 16 nodes (M ev/s) | Devastator, 16 nodes (M ev/s) | Charades ÷ Devastator, 1 / 4 / 16 nodes | efficiency 4→16, Charades / Devastator |
|---|---|---|---|---|
| lookahead 100, mean 1,000, σ 100 | 704.4 | 663.0 | 1.17 / 1.04 / 1.06 | 0.99 / 0.97 |
| σ 500 | 619.0 | 519.8 | 1.09 / 1.08 / 1.19 | 0.97 / 0.88 |
| σ 1,000 | 579.4 | 442.8 | 1.08 / 1.19 / 1.31 | 0.95 / 0.86 |
| σ 2,000 | 434.1 | 380.3 | 1.29 / 1.28 / 1.14 | 0.81 / 0.91 |
| σ 4,000 | 421.4 | 297.9 | 1.34 / 1.48 / 1.41 | 0.87 / 0.92 |
| uniform remote 1.0 | 276.8 | 194.6 | 1.41 / 1.90 / 1.42 | 0.52 / 0.69 |
| lookahead 10, mean 200, σ 500 | 562.8 | 514.4 | 0.98 / 0.98 / 1.09 | 0.97 / 0.86 |
| lookahead 10, σ 2,000 | 414.5 | 360.9 | 1.14 / 1.18 / 1.15 | 0.89 / 0.91 |

Charades leads in 22 of 24 cells (all but lookahead 10, σ 500 at 1 and 4 nodes, 0.98). Its controller is within 5% of its best fixed W everywhere except σ 2,000 and 4,000 at 16 nodes (0.92, 0.86). Candidate, not yet default: glibc no-trim (`GLIBC_TUNABLES=glibc.malloc.trim_threshold=1073741824:glibc.malloc.top_pad=67108864`) is 1.02–1.10× for Charades at 16 nodes (geometric mean 1.055) but 0.25–0.53× for Devastator, so it is a Charades-only launch setting (section 95). Still open: rank 0 late at σ 100 (sections 88–94), and Charades' weaker 4→16 efficiency at σ ≥ 2,000 and uniform.

**Charades and Devastator, 1–16 nodes, weak scaling, one allocation** (job 3639098, section 78; without c455-081). Each engine at its best setting per cell: Charades over PP 512, PP 2,048 (and WPs 512 for uniform and lookahead 10 σ 2,000) × W 250/400/600 and the controller (lookahead 10: W 50/100/200); Devastator over W 500/1,000 (lookahead 10: 100/200/400), CLCG4.

| workload | Charades, 4 nodes (M ev/s) | Devastator, 4 nodes | Charades' speedup, 1 / 4 / 16 nodes | Charades, 16 nodes | Devastator, 16 nodes | weak-scaling efficiency 4→16 nodes, Charades / Devastator |
|---|---|---|---|---|---|---|
| lookahead 100, mean 1,000, σ 100 | 165.6 | 170.4 | 1.14 / 0.97 / 0.92 | 612.8 | 667.2 | 0.93 / 0.98 |
| σ 500 | 154.8 | 140.8 | 1.07 / 1.10 / 1.08 | 558.4 | 518.4 | 0.90 / 0.92 |
| σ 1,000 | 146.4 | 120.8 | 1.08 / 1.21 / 1.26 | 521.6 | 414.4 | 0.89 / 0.86 |
| σ 2,000 | 127.6 | 105.6 | 1.27 / 1.21 / 0.95 | 363.2 | 382.4 | 0.71 / 0.91 |
| σ 4,000 | 112.8 | 80.8 | 1.32 / 1.40 / 1.04 | 312.0 | 300.8 | 0.69 / 0.93 |
| uniform remote 1.0 | 118.8 | 70.4 | 1.38 / 1.69 / 0.99 | 190.4 | 192.0 | 0.40 / 0.68 |
| lookahead 10, mean 200, σ 500 | 134.0 | 146.8 | 0.96 / 0.91 / 0.85 | 435.2 | 510.4 | 0.81 / 0.87 |
| lookahead 10, σ 2,000 | 96.0 | 99.2 | 1.09 / 0.97 / 0.76 | 273.6 | 361.6 | 0.71 / 0.91 |

(Rates are per-node medians × nodes; speedup = Charades ÷ Devastator, higher is better for Charades; efficiency = per-node rate at 16 ÷ at 4 nodes, 1.0 is perfect.) Charades leads at every scale at σ 500–1,000, leads at 1–4 nodes and falls to about level at 16 at σ ≥ 2,000 and uniform, and trails at lookahead 10 from 2–4 nodes on.

**Why Charades scales worse at σ ≥ 2,000** (sections 78–84):
- At Gaussian σ, events per htram message, efficiency and the number of GVT advances do not change from 4 to 16 nodes; the time per advance grows (σ 2,000, W 250: 167 → 233 µs). Aggregation thinning matters only for uniform (114 → 39 → 15 events per message at 4/8/16 nodes).
- Per advance at 16 nodes, the reduction itself is about 51 µs (34 µs at 4 nodes) and waiting for the slowest process is 54–58% of the advance even at W 250, growing faster than the work per advance as W widens. That is why a wider window does not pay: re-executing rolled-back events costs under 0.2% of the run.
- The late PE in the slowest process is usually rank 0 (62–80% of waves at σ 100, 22–31% at σ 2,000; chance 4%): the process-edge PEs (ranks 0 and 22) take the htram-held cross-process events and roll back 35–50× more at σ 100, and rank 0 carries process-level work.
- One process per node (46 PEs) is 0.71–0.87 of two (section 78). Horizon margins above 8 cost more than they save (section 80).

**Dropped (section 139):** htram buffers allocated at 2,048 but capped at 512 (`--agg-buffer=2048 --agg-pp-limit=512`) gave 1.07–1.14× PP 512 on short runs before the current launch (sections 80, 82); on the current launch and long runs they are 0.93–0.96×. `--agg-auto` picks its buffer correctly but does not deliver the gain (section 76).

**Older 4-node figures** (before the fast path and node waves; jobs 3629783, 3629781, 3632385; kept because the controller, aggregation and transport ratios below have not been remeasured on the current stack):

**Adaptive policies ÷ the engine's own best fixed W** (higher is better):

| policy | where | ratio |
|---|---|---|
| Charades controller (revised default, job 3633379), htram | lookahead 100, mean 1,000 (σ 100, σ 2,000, uniform) | 0.94 (15 s runs: 0.95–0.98) |
| | lookahead 10, mean 200 | 0.97–0.98 |
| | phase-changing PHOLD | 1.02, 1.11 |
| | traffic | 0.98–1.01 |
| Charades controller (revised), direct sends | lookahead 100 and 10 | 0.97–0.98 |
| Charades controller before 2026-10-23 (job 3629781), htram | lookahead 100 / lookahead 10 / phases / traffic | 0.84–0.87 / 0.92–0.96 / 1.04, 1.08 / 0.90–0.97 |
| Charades hill climb (Devastator's rule), htram | σ sweep | 0.17–0.50 |
| Devastator's own adaptive window | σ ≤ 500, both slack levels | 0.64–0.81 |
| | σ ≥ 1,000, both slack levels | 0.06–0.28 (stalls) |
| | phase-changing PHOLD | 0.17–0.18 (stalls) |

Charades' controller ÷ Devastator's adaptive window: 0.68–1.03 at σ ≤ 500 (both slack levels), 2.7–12.5× at σ ≥ 1,000.

**Aggregation** (best htram ÷ best direct, same workload; higher is better): high slack 2.27 (σ 100) rising to 4.01 (uniform); low slack 2.43–2.74; traffic 1.01–1.36.

**Transport** (job 3628358): psm2 ÷ verbs 1.50× on full nodes, 1.79–1.98× at 64 cores.

**Cost per committed event at σ 100** (perf, node 0): Charades about 4,000 cycles and 4,850 instructions; Devastator about 3,170 and 3,920 (1.27× the cycles).
