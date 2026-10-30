# Charades results: every measurement toward PADS 2027

Every number from every run: Stampede3 runs in order (each design, written before its runs, followed by its results), then baseline checks on the Mac and the LCI transport work. Raw CSVs and logs stay where each section says (`$WORK/charades-runs/` on Stampede3; copies of recent ones in `~/charades-data/`). Goals, build notes, open issues and next steps are in `CONTEXT.md`.

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
- Write new designs and results at the end of "Stampede3 runs, in order", with a status line.
- **Renamed 2026-10-27: "inbox" is now "input buffer"** (charades 80521a6, htram 699c3a9), in this file and in the code. Jobs before then ran with the old spellings: `--agg-inbox` and `--agg-inbox-mode` (now `--agg-input-buffer`, `--agg-input-buffer-mode`), test configs `agg_inbox*` and `agg_noinbox_*` (now `agg_inputbuf*`, `agg_noinputbuf_*`), htram's `HTramInbox`, `drainInbox` and `htram_inbox_mode`, and the fast path's `FpInbox`.

## Current numbers

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

> **Default change, 2026-10-29 (main 9d08fbd):** per-LP rollback inside a chare (`--rollback-unit=1`, section 152) is the default. A straggler rolls back only its own LP, not every later event of the chare's LPs: 3.5–15× fewer events rolled back at W 400, throughput unchanged (−1.6% to +2.2%). Every table above and below used chare rollback (`--rollback-unit=0`). Full test matrix 13,345/13,345 on the Mac.

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

## Re-read, 2026-10-28: repeats and dropped threads

Sections 1–128 were re-read before planning sections 129 onward.

**Repeats.**
- **Sections 116–120 repeated section 54.** Section 54 (job 3636110) had already found that faster GVT advances do not make the run faster, because the slowest PE sets the pace. Sections 116–120 then spent three jobs on the cross-process reduction (per-hop times, trees, `--wave-batch`) before reaching the same conclusion in section 120. Smaller batches had also lost in section 54 (0.88–0.98), as `--wave-batch` did again.
- **Section 126's thinning question was half answered by section 78.** There, one process per node made uniform's messages 3.7× fuller and was still 0.78–0.87× as fast; it was confounded by one process spanning both sockets. Section 126's same-layout perturbation settled it.
- **Section 126's smaller buffers extend section 66.** That section swept buffers of 128, 512 and 2,048 (WPs 128 ≈ WPs 512 on uniform at 16 nodes); sizes 16 and 32 are new.

**Dropped threads, still open:**
- ~~`flushDue` misses PP shared buffers whose events are due~~ (section 80, "Next" item 2). **Wrong, corrected in section 137:** `flushDue` does send them. Their events go out at the update that makes them due and lose a race to PEs that open their window at once. It costs PP 512 0.03–0.13% of events, worth 3–5% at σ ≥ 2,000 on 16 nodes. Sending those events early doubles messages and costs more (section 139). Closed; defaults unchanged.
- **Fewer destinations for uniform's receives** (section 107, "Next" item 3: per-socket buffers or two-hop routing). Never tried, though section 78's one-process-per-node result argues against expecting much.
- **glibc no-trim** (section 95) is still a candidate, not part of the launch.
- **Rank 0 late at σ 100** (sections 88–103): open, with no explanation beyond the lower-edge effect.
- **Reconverse's `+backend_poll_thread` hang** (section 25) was never reported upstream.

## Index of runs

| # | date | job | run | status |
|---|---|---|---|---|
| 1 | 2026-10-19 | 3615231 | First Stampede3 measurements | historical |
| 2 | 2026-10-19 | 3615917 | Optimism window sweep | historical |
| 3 | 2026-10-20 | 3620576 | Per-message cost and scaling | historical |
| 4 | 2026-10-20 | 3621217 | Aggregation through htram | superseded |
| 5 | 2026-10-20 | 3621758 | Deadline flush policy | historical |
| 6 | 2026-10-20 | — | Window controller | design |
| 7 | 2026-10-20 | 3622528 | Window controller, first Stampede3 results | superseded |
| 8 | 2026-10-20 | 3623246 | Waste floor, controller cost, horizon margin | superseded |
| 9 | 2026-10-20 | 3623246 | Two speeds of the bucketed GVT | historical |
| 10 | 2026-10-21 | 3624457 | Two GVT speeds: cause and fix | historical |
| 11 | 2026-10-21 | — | Gaussian PHOLD σ sweep | design |
| 12 | 2026-10-21 | 3624866 | Gaussian PHOLD σ sweep, results | superseded |
| 13 | 2026-10-21 | — | Controller on the GVT's count waves | design |
| 14 | 2026-10-21 | — | External baselines, Mac feasibility | historical |
| 15 | 2026-10-21 | 3625507 | Controller on the GVT's count waves, results | superseded |
| 16 | 2026-10-21 | same job as above | ROSS on Stampede3, first runs | historical |
| 17 | 2026-10-21 | — | Controller step 2: cost-aware target and floor guard | design |
| 18 | 2026-10-21 | 3626068 | Controller step 2, results | superseded |
| 19 | 2026-10-21 | same job as above | Three engines on Gaussian PHOLD, 4 nodes | superseded |
| 20 | 2026-10-21 | 3626388 | Three engines: the gaps filled | superseded |
| 21 | 2026-10-21 | 3626643 | Production runtime build | historical |
| 22 | 2026-10-21 | 3626832 | Runtime settings on the production build | historical |
| 23 | 2026-10-21 | 3626915 | Profile: where Charades spends its time against Devastator | superseded |
| 24 | 2026-10-21 | 3627053 | Per-event fast paths | historical |
| 25 | 2026-10-21 night | 3627274 | Runtime tuning | superseded |
| 26 | 2026-10-22 | 3628343, 3628358 | Native psm2 through a patched LCI | current |
| 27 | 2026-10-22 | — | Gaussian PHOLD σ sweep on the fast stack | design |
| 28 | 2026-10-22 | 3628587 | Gaussian PHOLD σ sweep on the fast stack, results | superseded |
| 29 | 2026-10-22 | — | Floor-aware controller, `--ctl-floor` | design |
| 30 | 2026-10-22 | 3628811 | Floor-aware controller, results | provisional |
| 31 | 2026-10-22 | — | Phase-changing PHOLD and traffic characterisation | design |
| 32 | 2026-10-22 | 3628935 | Phase-changing PHOLD and traffic, results | superseded |
| 33 | 2026-10-22 | — | Devastator's own window on phase-changing PHOLD | design |
| 34 | 2026-10-22 | 3629361 | Devastator's own window on phase-changing PHOLD, results | superseded |
| 35 | 2026-10-22 | — | Full-node reruns | design |
| 36 | 2026-10-22/23 | 3629783, 3629781 | Full-node reruns, results | current |
| 37 | 2026-10-23 | — | Controller level, `--agg-scope`, σ 100 profile | design |
| 38 | 2026-10-23 | 3632385 | Controller level, `--agg-scope`, σ 100 profile, results | current |
| 39 | 2026-10-23 | — | Controller: an aggregation bound, cheaper bookkeeping, a faster start | design |
| 40 | 2026-10-23 | 3633379 | Controller: an aggregation bound, cheaper bookkeeping, a faster start, results | current |
| 41 | 2026-10-23 | — | Scaling check at 16 and 32 nodes | design |
| 42 | 2026-10-23 | — | Three engines at 4 nodes, paper grade | design |
| 43 | 2026-10-24 | 3633769, 3633770 | Scaling check at 16 and 32 nodes, results | current |
| 44 | 2026-10-24 | — | Window sweep at 16 and 32 nodes | design |
| 45 | 2026-10-24 | 3635596 | Window sweep at 16 and 32 nodes, results: 16 nodes | current |
| 46 | 2026-10-24 | — | GVT round cost at 4 and 16 nodes | design |
| 47 | 2026-10-24 | 3635612 | GVT round cost at 4 and 16 nodes, results | current |
| 48 | 2026-10-24 | 3635622 | Where a reduction's time goes, one node | current |
| 49 | 2026-10-24 | — | GVT count waves combined per process, `--gvt-node-waves` | design |
| 50 | 2026-10-24 | 3635736 | GVT count waves combined per process, results | current |
| 51 | 2026-10-24 | — | The cross-process part of a GVT advance: allreduce by recursive doubling | design |
| 52 | 2026-10-24 | 3635974 (3635873) | The cross-process part of a GVT advance, results | current |
| 53 | 2026-10-24 | — | What makes a process late to a count wave: batch size and wave holding | design |
| 54 | 2026-10-24 | 3636110 (3636097) | What makes a process late to a count wave, results | current |
| 55 | 2026-10-24 | — | Which PE is slow, and why | design |
| 56 | 2026-10-24 | 3636151 | Which PE is slow, and why, results | current |
| 57 | 2026-10-24 | — | Do htram's buffers hold GVT back at scale? | design |
| 58 | 2026-10-24 | 3636185 | Do htram's buffers hold GVT back at scale?, results | current |
| 59 | 2026-10-24 | — | Count waves that ask about every bucket up to the window | design |
| 60 | 2026-10-24 | 3636197 | Count waves that ask about every bucket up to the window, results | current |
| 61 | 2026-10-24 | — | Same-process events by pointer (`--local-fast-path`) | design |
| 62 | 2026-10-24 | 3636369 | Same-process events by pointer, results | current |
| 63 | 2026-10-24 | — | Where the fast path loses at σ 2,000, and with WPs | design |
| 64 | 2026-10-24 | 3636435 | Where the fast path loses at σ 2,000, and with WPs, results | current |
| 65 | 2026-10-24 | — | Which htram mode and buffer for which workload (fast path on) | design |
| 66 | 2026-10-25 | 3636522 (16 nodes), 3638303 (4 nodes) | Which htram mode and buffer for which workload, results | current |
| 67 | 2026-10-25 | — | The 16-node gaps with wider windows (uniform, lookahead 10) | design |
| 68 | 2026-10-25 | 3638330 | The 16-node gaps with wider windows, results | current |
| 69 | 2026-10-25 | — | Choosing htram automatically (`--agg-auto`), and LPs per chare at lookahead 10 | design |
| 70 | 2026-10-25 | — | Why `--agg-auto` differs from the fixed setting it chose | design |
| 71 | 2026-10-25 | 3638610, 3638739 | Why `--agg-auto` differs, results: an idle htram instance changes the pace of blocked passes | current |
| 72 | 2026-10-25 | — | `--agg-auto` with one active instance, and pausing blocked passes | design |
| 73 | 2026-10-25 | 3638798 | Pausing blocked passes, results; memory layout as the cause, design | current / design |
| 74 | 2026-10-25 | 3638859 | Memory layout: heap pads, results; padded shared atomics, design | current / design |
| 75 | 2026-10-25 | 3638897 | Padded shared atomics, results; `--agg-auto` without the second instance, design | current / design |
| 76 | 2026-10-25 | 3638968 (16 nodes), 3638969 (4 nodes) | `--agg-auto` without the second instance, results: the PP 2,048 gain is not aggregation | current |
| 77 | 2026-10-25 | — | Weak scaling 1–16 nodes in one allocation; one process per node | design |
| 78 | 2026-10-25 | 3639098 | Weak scaling 1–16 nodes in one allocation, results: time per GVT advance, not aggregation, limits Charades | current |
| 79 | 2026-10-25 | — | Where a GVT advance's time goes at scale; PP 2,048's allocation vs its limit; the horizon margin | design |
| 80 | 2026-10-25 | 3639554 | Where a GVT advance's time goes at scale, results: a slow node sets the pace; PP 2,048's allocation, not its limit, gives 1.12–1.14×; margin 8 stays | current |
| 81 | 2026-10-25 | — | The allocator behind `--agg-pp-limit`'s gain; the slow node in both engines; where a wider window's cost goes | design |
| 82 | 2026-10-25 | 3639812 | The allocator, the slow node in both engines, a wider window's cost, results: c455-081 is slow only with the network, and it hurts Devastator more | current |
| 83 | 2026-10-25 | — | Where a wider window's cost goes, on a clean allocation | design |
| 84 | 2026-10-25 | 3640064 | Where a wider window's cost goes, on a clean allocation, results: the slowest process is usually late because of its rank 0 | current |
| 85 | 2026-10-25 | — | What rank 0 does while it is late: wave-aligned timers and a per-thread perf profile | design |
| 86 | 2026-10-25 | 3640203 | What rank 0 does while it is late, results: nothing extra on average; ranks 0 and 1 are late as a pair | current |
| 87 | 2026-10-26 | — | Late ranks 0 and 1: the LCI device they poll, or the PSM2 receive thread? | design |
| 88 | 2026-10-26 | 3641728 | Late ranks, results: rank 0 is late at every device count; rank 1 only because it shares rank 0's device; 23 devices is 1.03–1.07× faster | current |
| 89 | 2026-10-26 | — | Is rank 0 preempted? Per-thread scheduler statistics; and 23 devices at 16 nodes | design |
| 90 | 2026-10-26 | 3641766, 3641785 | Rank 0 takes page faults, not preemption; 23 devices is 1.21× at 16 nodes | current |
| 91 | 2026-10-26 | — | Rank 0's page faults: where from, and do malloc settings stop them? Charades (23 devices) against Devastator at 16 nodes | design |
| 92 | 2026-10-26 | 3641910, 3641926 | Results: malloc settings 1.06–1.08×, but rank 0's faults come from system calls; Charades ahead of Devastator in all 8 workloads at 16 nodes | current |
| 93 | 2026-10-26 | — | Rank 0's system calls; and the 1/4/16-node series on 23 devices, with glibc no-trim at 16 nodes | design |
| 94 | 2026-10-26 | 3642143 | Rank 0's system calls, results: not the cause | current |
| 95 | 2026-10-26 | 3642157 | 1/4/16 nodes on 23 devices, results: Charades leads in 22 of 24 cells; glibc no-trim 1.055× for Charades, 0.25–0.53× for Devastator | current |
| 96 | 2026-10-26 | — | Rank 0's faults: perf against /proc in the same run, a lighter sampler, and memory bound to the socket | design |
| 97 | 2026-10-26 | 3642578 | Rank 0's faults, results: an artifact of my /proc sampler; rank 0 is late without it, and takes one shared lock 10× as often | current |
| 98 | 2026-10-26 | — | Naming the lock rank 0 takes 10× as often | design |
| 99 | 2026-10-26 | 3642782 | The lock, results: Reconverse's per-PE message pool, fought over by the process-edge ranks because each drains the other's network messages | current |
| 100 | 2026-10-26 | — | Late rank 0: edge traffic or the rank? Rotated LP blocks, and sending on the destination PE's device | design |
| 101 | 2026-10-26 | 3643113 | Late rank 0, results: the lateness follows the lower-edge LPs, not the rank or the device; sending on the destination device does not help | current |
| 102 | 2026-10-26 | — | htram flush order: rotating start and earliest timestamp first | design |
| 103 | 2026-10-26 | 3643408, 3643609 | htram flush order, results: no effect; the lower edge stays late | current |
| 104 | 2026-10-26 | — | Why one PE holds up each GVT advance at uniform and σ 2,000: per-PE wave records, and fewer events per wave | design |
| 105 | 2026-10-26 | 3643687 | Per-PE wave records, results: at uniform the late PE is slowed by receiving many small messages; `--gvt-wave-events=32` is 1.04–1.06× at 16 nodes | current |
| 106 | 2026-10-26 | — | `--gvt-wave-events` 32 / 64 / 128 at 1, 4 and 16 nodes; what an htram receive costs | design |
| 107 | 2026-10-26 | 3645244 | Wave events and receive cost, results: 128 stays; a receive's fixed cost is its input buffer pushes, which slow from 0.17 to 0.70 µs each as receives get frequent | current |
| 108 | 2026-10-27 | — | Cheaper input buffer pushes: padded mutex input buffers and lock-free rings | design |
| 109 | 2026-10-27 | 3646589 | Input buffer modes, results: lock-free rings make uniform 1.08–1.21× faster at 16 nodes (a push 0.73 → 0.17 µs); σ 2,000 with the controller 0.97× | current |
| 110 | 2026-10-27 | — | Rings against the mutex input buffer on all 8 scaling workloads, before making rings the default | design |
| 111 | 2026-10-27 | 3647086 | Rings on all 8 workloads, results: no cell below 0.98, uniform 1.08–1.21×; rings are the default | current |
| 112 | 2026-10-27 | — | Freeing another PE's message without its pool lock (`+mempool_remote_free`) | design |
| 113 | 2026-10-27 | 3647310 | `+mempool_remote_free`, results: freeing a received message 1.45 → 0.30 µs; uniform 1.02–1.06× at 16 nodes; gate rerun needed (harness) | current |
| 114 | 2026-10-27 | 3647898 | Correctness gate for `+mempool_remote_free`, results: 231/231; the flag joins the Stampede3 launch | current |
| 115 | 2026-10-27 | — | What paces GVT at σ 2,000: events in transit or the late PE's work; GVT bucket size; horizon margin with wider windows | design |
| 116 | 2026-10-27 | 3649213 | What paces GVT at σ 2,000, results: neither transit nor a growing straggler; the cross-process reduction (34 → 70 µs) is the whole 4→16-node loss | superseded in part (120) |
| 117 | 2026-10-27 | — | Where the cross-process reduction's 70 µs goes: Charades' own process tree with per-hop times; a flat tree; smaller scheduler passes | design |
| 118 | 2026-10-27 | 3649717 | Where the reduction's time goes, results: a hop's network time is about 4 µs; the rest is waiting for a PE to run the message. Fewer hops do not help | current |
| 119 | 2026-10-27 | — | Shorter scheduler passes only while a count wave is in flight (`--wave-batch`) | design |
| 120 | 2026-10-27 | 3650537 | `--wave-batch`, results: the floor falls by 27 µs but the advance does not; the floor was never on the critical path. The late PE's 128 events pace each advance | superseded in part (121) |
| 121 | 2026-10-27 | — | Closure check: 78% of σ 2,000's 4→16-node loss is in the first 10% of waves, which sections 116–120 left out; a warm-up test and long runs | design |
| 122 | 2026-10-27 | 3650843 | Warm-up and long runs, results: in 4× longer runs σ 2,000 scales at 0.96–0.97 and σ 4,000's loss is all start-up; warm-up pings do nothing; uniform's loss is steady | current |
| 123 | 2026-10-27 | — | Charades and Devastator on long runs, 1 / 4 / 16 nodes: σ 2,000, σ 4,000, uniform | design |
| 124 | 2026-10-27 | 3650921 | Both engines on long runs, results: Charades leads Devastator 1.33–1.98×, scales as well at σ ≥ 2,000 (0.93), and its controller is within 2% of its best W on 16 nodes | current |
| 125 | 2026-10-27 | — | Uniform's steady loss: thinner htram messages or more destinations? A buffer-size perturbation on 4 nodes | design |
| 126 | 2026-10-27 | 3651140 | Uniform's buffer perturbation, results: thinning explains only 16% of the loss; 45% is inside `execute()`, which the timers do not split | current |
| 127 | 2026-10-28 | — | Splitting `execute()` on uniform at 4 and 16 nodes, against σ 4,000 as a control | design |
| 128 | 2026-10-28 | 3652542 | `execute()` split, results: on uniform the event handlers and sends do not grow; half of `execute()`'s rise is applying each GVT result | current |
| 129 | 2026-10-28 | — | Charades and Devastator on long runs, 1 / 4 / 16 nodes: the other five workloads | design |
| 130 | 2026-10-28 | 3652595 | The other five workloads on long runs, results: Charades ahead in 14 of 15 cells (level in the 15th), scales as well or better in 4 of 5; its controller is its best setting or within 1% | current |
| 131 | 2026-10-28 | — | Is applying a GVT result on uniform's critical path? A known delay in that step, and its parts | design |
| 132 | 2026-10-28 | 3652815 | The GVT-result step, results: on 16 nodes it is fully on the critical path, and the GVT-time flush is 97% of its rise | current |
| 133 | 2026-10-28 | — | Where an htram message's 2.9 µs goes: htram, Charm++, Reconverse and LCI | design |
| 134 | 2026-10-28 | 3652869 | An htram message's cost, results: 92–95% is the LCI backend's send call, which polls the network after every post | current |
| 135 | 2026-10-28 | — | The post and the network poll inside each send, and skipping the poll (`+lci_send_progress 0`) | design |
| 136 | 2026-10-28 | 3652896 | The poll inside each send, results: it does useful work; skipping it costs uniform 6% on 16 nodes, and the time moves into allocating the next buffer | current |
| 137 | 2026-10-28 | 3639554, 3650921, 3652595 (existing logs) | PP's late held events: a race at each GVT update, not a missed flush | current |
| 138 | 2026-10-28 | — | Sending what the next GVT will make due before it is published (`--agg-flush-ahead`), against holding the window back (`--diag-window-lag-ns`) | design |
| 139 | 2026-10-28 | 3653291 | Flush ahead and window lag, results: sending early removes the late events but doubles messages; the race costs PP 512 3–5% on 16 nodes; the capped setting no longer helps | current |
| 140 | 2026-10-28 | — | Paper-grade scaling, 1–32 nodes: the plan; A0, ROSS tuning | design |
| 141 | 2026-10-28 | 3653550 | A0, ROSS tuning, results (batch 16 / GVT interval 64, and conservative); A1 and A2 design | current / design |
| 142 | 2026-10-28 | 3653803 | A1a, weak scaling 1–16 nodes, group a: Charades leads Devastator in 19 of 20 cells and ROSS 2.4–4.9×; same events in all three engines; σ 1,000 on 1 node needs PP 512 | current |
| 143 | 2026-10-28 | 3654651 | A1b, weak scaling 1–16 nodes, group b; all eight workloads at 1–16 nodes: Charades ahead of Devastator in 38 of 40 cells, 2.4–5.3× ROSS, scales best in 6 of 8 | current |
| 144 | 2026-10-29 | 3653806 | A2, 32 nodes: a noisy allocation (every engine slower, Charades most; rep spread up to 3.6×; not placement: job 3633770 was as spread and quiet), not used; A2r design (job 3657016), 32 nodes alone, plus traced runs at 16 and 32 nodes | not for use / design |
| 145 | 2026-10-29 | 3657717 | Why Charades rolls back more than Devastator at the same window: htram against direct sends against Devastator, W 400–1,600 (job R) | design |
| 146 | 2026-10-29 | 3657717 | Job R results: not the hold; Charades makes 5–120× more stragglers than Devastator at the same W with direct sends too; a wider W absorbs 2/3 of a GVT delay | current |
| 147 | 2026-10-29 | 3657892 | The rollback unit: 16, 4 and 1 LPs per chare at lookahead 100, W 400–1,600 (job L) | design |
| 148 | 2026-10-29 | 3657892 | Job L results: 1 LP per chare cuts rollbacks 5–23× (below Devastator's at σ 2,000 and uniform; σ 100 has a second cause); wider W still slower because the flush deadline follows W; 4 LPs per chare free at W 400 | current |
| 149 | 2026-10-29 | 3658017 | A wide window with the flush deadline held at 408, 4 and 1 LPs per chare, plus a GVT delay (job H) | design |
| 150 | 2026-10-29 | 3658017 | Job H results: held deadline gives 2–12× bigger messages and 3× less GVT-delay sensitivity; 1.12× at σ 2,000 with 1 LP per chare, a loss on uniform (held stragglers); W and h need setting together | current |
| 151 | 2026-10-29 | 3658328 | Per-LP rollback inside a chare (`--rollback-unit=1`): implementation, a bug found on the Mac (rollback inside a forward handler), job P design | design |
| 152 | 2026-10-29 | 3658328 | Job P results: per-LP rollback gives 1 LP per chare's rollbacks (3.5–15× fewer at W 400) at no cost; held deadline 1.09× at σ 2,000 (new best) but 0.89–0.92× σ 100, 0.68–0.70× uniform; GVT delay not absorbed at W 800 | current |
| 153 | 2026-10-29 | 3657016 | A2r, 32 nodes: Charades leads in 6 of 8 (44 of 48 cells at 1–32) but loses more per node 16→32 than Devastator everywhere (0.72–0.87 against 0.80–0.98); start-up transient at σ 100, per-wave work on uniform, controller at W ~300 | current |
| 154 | 2026-10-29 | — | Section 153's start-up transient is a slow cross-process reduction (300–410 µs a wave against 110), in episodes of seconds that also occur mid-run; job E design (counters, thread usage, start delay, tree hops) | design |

## Stampede3 runs, in order

### QD poll fix on the Mac (2026-10-19)

> **Status: historical.** The reason for Reconverse PR #290 (`idle-progress-poll`).

**Why `idle-progress-poll` matters.** Reconverse's default scheduler polled the
network ~40 times per idle sweep before raising idle conditions. Quiescence
detection waits on those conditions every hop, so with one PE per process a QD
round took 10.7 ms instead of 0.39 ms on the Mac (libfabric TCP, a `kevent`
per poll). Synchronous GVT and the conservative scheduler use QD every round:
Charades conservative `long` went from 70 s to 4.1 s. On Stampede3
(Omni-Path, verbs) the cost per poll is far lower, but the fix still gives
3–4× (see "First Stampede3 measurements").

### First Stampede3 measurements (2026-10-19, idev job 3615231, 2 skx nodes)

> **Status: historical.** Debug (-O0) runtime on verbs, 1 PE per process. Its point stands: the QD fix gives 3–4× on Stampede3.

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

> **Status: historical.** Debug (-O0) runtime on verbs, before the bucketed-GVT fixes and aggregation.

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

> **Status: historical.** Debug (-O0) runtime on verbs. The go/no-go evidence for aggregation; its per-message costs are from the slow runtime.

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

> **Status: superseded.** Debug (-O0) runtime on verbs. Current aggregation factors: "Full-node reruns, results".

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

> **Status: historical.** Debug (-O0) runtime on verbs. The policy chosen here (horizon = W + margin) is still the default.

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

> **Status: design.** Design, written before any runs.

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

> **Status: superseded.** Debug (-O0) runtime on verbs.

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

> **Status: superseded.** Debug (-O0) runtime on verbs. The waste floor is handled by `--ctl-floor=2` ("Floor-aware controller").

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

> **Status: historical.** A GVT bug (Debug (-O0) runtime on verbs); fixed in the next section.

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

> **Status: historical.** The fix for the two GVT speeds (Debug (-O0) runtime on verbs).

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

> **Status: design.** Design, written before any runs.

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

> **Status: superseded.** Debug (-O0) runtime on verbs, 2 × 8 PEs per node. Rerun on the fast stack, then on full nodes ("Full-node reruns, results").

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

> **Status: design.** Implementation notes.

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

### Controller on the GVT's count waves, results (2026-10-21, idev job 3625507, 4 skx nodes)

> **Status: superseded.** Debug (-O0) runtime on verbs, 2 × 8 PEs per node. The shared reduction it chose is still the default.

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

### Controller step 2: cost-aware target and floor guard (design, 2026-10-21; written before the runs)

> **Status: design.** Design, written before the runs.

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

> **Status: superseded.** Debug (-O0) runtime on verbs, 2 × 8 PEs per node. Still the evidence that a PE-time target (`--ctl-cost=1`) misses a rollback's indirect cost.

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

> **Status: superseded.** Charades on the Debug (-O0) runtime on verbs; Devastator with xorshift. Superseded by "Full-node reruns, results".

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

> **Status: superseded.** Charades on the Debug (-O0) runtime on verbs; Devastator with xorshift. Superseded by "Full-node reruns, results".

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

> **Status: historical.** The switch from the Debug to the production runtime (verbs).

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

> **Status: historical.** Production runtime, verbs. Its launch settings (2 × 23 PEs per node, `+pemap`) are still used.

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

> **Status: superseded.** Production runtime on verbs, before the fast paths and psm2. Current profile: "Controller level, `--agg-scope`, σ 100 profile, results".

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

> **Status: historical.** Production runtime, verbs. The three fast paths are the default.

Three changes from the profile's ranked list (charades 4bb324b, htram 50acab7 on `pdes`), each behind a switch. **All three are the default since the same day** (user decision; the input buffer turns itself off under `--sched-park`, other GVTs and the conservative scheduler); test configs `bucket_avl` and `agg_noinputbuf_bucket_pp` keep the old paths covered. Not yet re-run with the new defaults:
- `--agg-input-buffer=1` (htram `setInputBufferDelivery` / `drainInputBuffer`): a PP/WPs node receive puts each PE's share of a node message in that PE's input buffer (a mutex-protected vector in the `HTramRecv` node group) instead of sending it a `receivePerPE` message; the optimistic scheduler drains it at the start of every iteration, and the receiving PE's own share is delivered in place. Only with the bucketed GVT (which counts each event when its chare receives it, so an event in an input buffer is in transit) and the optimistic scheduler; refused with `--sched-park`. QD-based GVTs would not see input buffer items.
- `--event-index=1`: received events indexed for cancellation by an open-addressing hash per chare (`collections/event_hash.h`; linear probing, tombstones, key (ts, event_id, src_lp)) instead of the AVL tree. Same insert-or-annihilate contract.
- `--msg-pool=1`: event messages (`RemoteEvent`) recycled through a per-PE pool (`remote_event_new` / `remote_event_delete` in event.C) on the hot paths: model sends, htram delivery, fossil frees, `agg_send`. Capacity is read from the envelope; reused messages are marked unused so they can be sent again.

Tests (Mac): change tier on the new configs 60/60; input buffer configs repeated 10× on 2×2, 1×4, 2×4: 360/360; existing aggregation configs 84/84; engine tier 484/484. Committed counts identical in every Stampede3 run below.

**Throughput** (production runtime, 2 × 23 PEs per node pinned, `+lci_ndevices 4`, Gaussian σ 2,000; M committed events/s, median of 3; higher is better):

| configuration | full nodes, W 250 | ÷ base | 64 PEs high slack, W 250 | 64 PEs low slack, W 50 |
|---|---|---|---|---|
| base (all off) | 43.7 | 1.00 | 20.7 | 14.2 |
| hash index only | 48.7 | 1.11 | | |
| message pool only | 48.9 | 1.12 | | |
| input buffer only | 45.2 | 1.03 | | |
| all three | **56.0** | **1.28** | **27.3** (1.32×) | **17.6** (1.24×) |

With all three on full nodes (2 runs each; ÷ W 250 at 56.9): W 175 0.93, W 350 0.85; controller ε 0.003 51.7 (0.91, mean W 309), ε 0.001 39.7 (0.70, pinned at W 110 near the floor). So ε 0.003 stays the default.

**Gap to Devastator** (each at its best fixed W; Devastator ÷ Charades, lower is better for Charades): full nodes ~100 / 56 = **1.8×** (was 2.2×); 64 cores high slack 54.2 / 27.3 = **2.0×** (was 2.6×); low slack 52.5 / 17.6 = **3.0×** (was 3.7×). A longer full-node run (end 2,048,000) reached 61.0 M ev/s.

**Profile with all three** (one process, DWARF stacks): about 8,300 cycles and 9,200 instructions per committed event (was 11,100 / 12,100; Devastator ~5,300 / 7,500). The AVL tree is gone; fossil collection is down to 6%; event execution is 26% of PE time (the model's forward work ~8%). What remains is mostly communication: LCI/libfabric progress 15%, sends through the node queue (`CkSendMsgNodeBranch` → `CldNodeEnqueue`, PP's node messages) 7%, `issueAm` 7.6%, mutexes 8% (libfabric CQ, node queue), Converse queue polling and TLS ~6%.

### Runtime tuning (2026-10-21 night, idev job 3627274, 4 skx nodes)

> **Status: superseded.** Production runtime, verbs. Superseded by native psm2 (next section).

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

> **Status: current.** Current transport settings (psm2, 64 KB packets, 16 devices). Devastator ran xorshift.

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

> **Status: design.** Design, written before any runs.

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

> **Status: superseded.** 2 × 8 PEs per node (16 of 48 cores). Superseded by "Full-node reruns, results".

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
  - Not the fast paths: `--agg-input-buffer=0` 0.21–0.24, `--event-index=0` 0.20–0.27, `--msg-pool=0` 0.21–0.26, against 0.24–0.28.
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

> **Status: design.** Design, written before any runs.

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

> **Status: provisional.** 2 × 8 PEs per node. The defaults it set (`--ctl-floor=2`, ε 0.001) are still the defaults; its ratios were not rerun on full nodes.

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

> **Status: design.** Design, written before any runs.

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

> **Status: superseded.** 2 × 8 PEs per node. Superseded by "Full-node reruns, results" (stages A and C).

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

### Devastator's own window on phase-changing PHOLD (design, 2026-10-22; written before any runs)

> **Status: design.** Design, written before any runs.

**Why.** Our hill climb (`--ctl=2`) is a reimplementation of Devastator's rule, and it reached only 0.24–0.38 of the best fixed W on phase-changing PHOLD with htram. A reviewer can call that a strawman. The fair arm is Devastator's own adaptive window (`global_status_state::update()`), in its own engine, on the same workload.

**Bench.** `~/pdes-baselines/devastator/bench/phold-gauss.cxx` gains Charades' phase options: `--phase-length`, `--alt-lookahead`, `--alt-mean`, `--alt-remote`, with Charades' defaults and checks. An event executed at time t uses the alternate parameters when (t / phase length) is odd, as in `alt_phase()` in `models/phold/simple/phold.C`.
- Mac check (`--rng=clcg4`, 1,024 LPs, 15 start events, end 4,000; threads world, 4 ranks): committed counts equal Charades' sequential run in all three configs, with 1,786–11,976 events rolled back:

  | remote | lookahead / mean | alt lookahead / alt mean | phase length | Charades committed | Devastator committed |
  |---|---|---|---|---|---|
  | 0.5 | 10 / 200 | 100 / 1,000 | 500 | 140,491 | 140,491 |
  | 1.0 | 10 / 200 | 100 / 1,000 | 500 | 141,289 | 141,289 |
  | 0.25 | 5 / 100 | 50 / 1,000 | 300 | 174,194 | 174,194 |

- Configs without phases still give the reference counts (29,338 and 152,687).
- The updated bench is in `devastator-phold-gauss.patch` and `devastator-bench/`.

**Runs** (one 4-node interactive allocation).
- Workload as in "Phase-changing PHOLD and traffic characterisation": `phases:10:200:100:1000:<remote>:32000` at remote 0.5 and 1.0, end time 256,000, 128 LPs per rank (8,192 LPs), 15 start events.
- Devastator: GASNet ofi-psm2, 8 processes × 8 workers (64 ranks, plus a service thread per process), its own xorshift RNG.
  - Arms: its adaptive window (the default), and fixed W (`deva_static_look_dt`) 50, 100, 250, 500, 1,000, 2,000.
  - 3 reps each.
- Charades in the same allocation, as an anchor against node variance: htram PP 256, the controller (default) and fixed W 50 and 100 (the best fixed W in job 3628935), 3 reps, same launch as job 3628935.
- Metrics: committed events/s (higher is better); each engine's arms ÷ its own best fixed W; efficiency; Devastator's window statistics (mean, geometric mean, minimum, maximum).

**Predictions:**
1. Devastator's adaptive window reaches 0.5–0.8 of its own best fixed W, a smaller loss than our reimplementation's 0.24–0.38 in Charades. Its rollbacks are cheap, so a window that overshoots costs it less. On steady Gaussian PHOLD at 64 cores it reached 0.66–0.69.
2. Devastator's best fixed W is larger than Charades' best (≥ 250 against 50–100), for the same reason.
3. Devastator's best fixed W is 1.1–1.4× Charades' best fixed W, the steady-workload gap at 64 cores.
4. Charades' controller beats Devastator's adaptive window in committed events/s at both remote shares.

### Devastator's own window on phase-changing PHOLD, results (2026-10-22, idev job 3629361, 4 skx nodes)

> **Status: superseded.** 2 × 8 PEs per node; Devastator with xorshift. Superseded by "Full-node reruns, results" (stage A).

**Runs.** `$WORK/charades-runs/phase_deva.sh`, then `phase_anchor.sh`, back to back. Devastator rows are in `$WORK/charades-runs/phase_deva/results.txt` (one `.out` per run); Charades CSVs in `phase_anchor/`. Devastator rebuilt on the node (ofi-psm2, 8 × 8; the binary before the phase options is kept as `phold-gauss-p8w8.pre-phases`).
- 40 of 42 Devastator runs ok. Fixed W 2,000 at remote 1.0 stalled twice (reps 2 and 3, killed at the 180 s cap); rep 1 finished at 62% efficiency. All 18 Charades runs ok.
- Committed counts are identical within each engine and workload: Devastator 93,588,382 (remote 0.5) and 93,596,142 (1.0) with its own RNG; Charades 93,585,342 and 93,611,686 (clcg4; within 0.02%).
- Runs are short: Devastator drains in 1.4–3.4 s, Charades in 2.0–2.9 s.

**Devastator** (M committed events/s, median of 3; ÷ its own best fixed W; higher is better):

| arm | remote 0.5 | ÷ best | efficiency | remote 1.0 | ÷ best | efficiency |
|---|---|---|---|---|---|---|
| **adaptive window (its default)** | 52.4 | **0.77** | 82.5% | 33.9 | **0.70** | 77.7% |
| fixed W 50 | 46.3 | 0.68 | 99.97% | 34.9 | 0.72 | 99.9% |
| fixed W 100 | 55.8 | 0.82 | 99.7% | 41.4 | 0.85 | 99.0% |
| fixed W 250 | **67.9** | 1.00 | 98.5% | **48.5** | 1.00 | 94.5% |
| fixed W 500 | 66.4 | 0.98 | 95.4% | 45.0 | 0.93 | 87.9% |
| fixed W 1,000 | 60.7 | 0.89 | 90.0% | 34.3 | 0.71 | 72.5% |
| fixed W 2,000 | 54.9 | 0.81 | 86.2% | 27.5 (1 of 3; 2 stalled) | 0.57 | 62.1% |

- Its window swings over the whole range in both workloads: minimum 1 in every run. At remote 0.5 it runs away to the 2⁵⁸ clamp (geometric mean 10¹¹–10¹⁴): high-slack phases keep efficiency above 95%, so it doubles every epoch and runs unbounded until a low-slack phase collapses it. At remote 1.0 its geometric mean is 260–340 (mean 650–990, maximum 17,000–39,000).
- At remote 1.0 it does no better than fixed W 50.

**Charades in the same allocation** (htram PP 256; M committed events/s, median of 3; ÷ the better of W 50 and W 100, which were the best fixed W in job 3628935; higher is better):

| arm | remote 0.5 | ÷ best | remote 1.0 | ÷ best |
|---|---|---|---|---|
| **controller (default)** | 46.7 | **1.10** | 38.3 | **1.09** |
| fixed W 50 | 41.5 | 0.98 | 35.0 | 1.00 |
| fixed W 100 | 42.5 | 1.00 | 32.3 | 0.92 |

These reproduce job 3628935 (46.1 and 38.1; 1.08) within 1–2%.

**Across engines** (ratios of medians):

| | remote 0.5 | remote 1.0 |
|---|---|---|
| adaptive policy ÷ the engine's own best fixed W: Charades controller / Devastator window (higher is better) | 1.10 / 0.77 | 1.09 / 0.70 |
| Charades best fixed W ÷ Devastator best fixed W (speedup; higher is better for Charades) | 0.63 | 0.72 |
| Charades controller ÷ Devastator best fixed W (speedup; higher is better for Charades) | 0.69 | 0.79 |
| Charades controller ÷ Devastator adaptive window (higher is better for Charades) | 0.89 | 1.13 |

**Predictions:**
1. Right: Devastator's window reaches 0.77 and 0.70 of its best fixed W (predicted 0.5–0.8).
2. Right: its best fixed W is 250 in both (predicted ≥ 250).
3. Right at remote 1.0 (1.38); wrong at remote 0.5 (1.60, predicted 1.1–1.4). The gap on phase-changing PHOLD is larger than on steady Gaussian PHOLD at 64 cores.
4. Right at remote 1.0 (1.13×); wrong at remote 0.5 (0.89×).

**What this means:**
- **Our reimplementation understated Devastator's rule.** In its own engine the hill climb reaches 0.70–0.77 of the best fixed W, against 0.24–0.38 for the same rule in Charades with htram, and 0.98–0.99 in Charades with direct sends. The rule's thresholds (quarter below 33% efficiency, double above 95%) tolerate waste that is cheap in Devastator and expensive in Charades with htram, where a rolled-back event costs 6.5–30 committed events. The paper should report Devastator's own window as the baseline, and present the in-Charades hill climb only as evidence that the rule's thresholds don't transfer across transports.
- **The controller's claim holds against the fair baseline.** On the same workload, each engine's adaptive policy against its own best fixed W: our controller is 1.09–1.10, Devastator's window 0.70–0.77. Its window leaves 1.3–1.4× on the table; ours gains 9–10% over any fixed W.
- **Absolute throughput still favours Devastator** at its best fixed W (1.27–1.46× our controller). Its adaptive window, as shipped, is beaten by Charades' controller only at remote 1.0.
- **Next, if the framing goes this way:** port the controller into Devastator (`global_status_state::update()`). It would need Devastator's own ε, since its best W runs at 94.5–98.5% efficiency where Charades' runs at about 99.7%. If it recovers most of the 1.3–1.4×, that is the cleanest evidence for the controller, independent of engine.

### Full-node reruns (design, 2026-10-22; written before any runs)

> **Status: design.** Design, written before any runs.

**Why.** Every result from "Gaussian PHOLD σ sweep on the fast stack" through "Devastator's own window on phase-changing PHOLD" ran 2 × 8 PEs per node, 16 of 48 cores. That layout was inherited from early debugging and kept for comparability; there is no defensible reason for it in the paper. Only the psm2 gap to Devastator (0.97×) and a few controller anchors were measured on full nodes. Full nodes change what the controller sees: about 3× the events per node, more events stay on the node, bigger htram messages. **Full nodes are now the default** (`ctl_sweep.sh`, 2026-10-22): 2 processes × 23 PEs per node (one core per process free), `+pemap 2-46:2,3-47:2`, psm2 with 64 KB packets, `+lci_ndevices 16`, htram PP 512, margin 8, `charades-exp`. The 2 × 8 results above are provisional until these reruns replace them. Also new: the blocking-GVT arm gets the bucket config's event pool (`--buffer-size=655360`), so it no longer needs the per-run workaround from the traffic runs.

**Setup.** 4 nodes, 184 PEs, 128 LPs per PE (23,552 LPs), 15 start events, 3 reps interleaved. Charades controller = the defaults (ε 0.001, `--ctl-floor=2`). Devastator: ofi-psm2, 8 processes × 23 workers (184 ranks, plus a service thread per process), 128 LPs per rank, its own RNG; rebuilt with the phase options. Stages in priority order, so a short allocation still finishes the most important one:
- **A. Phase-changing PHOLD**, both engines: `phases:10:200:100:1000:<remote>:32000`, remote 0.5 and 1.0, end 256,000. Charades, htram and direct: blocking GVT; fixed W 25, 50, 100, 250; controller; hill climb from W 250. Devastator: adaptive; fixed W 50, 100, 250, 500, 1,000, 2,000.
- **B. Gaussian σ sweep**, both engines. High slack (lookahead 100 / mean 1,000, end 512,000): σ 100, 500, 1,000, 2,000, 4,000, uniform remote 1.0. Low slack (10 / 200, end 128,000): σ 500, 2,000, uniform remote 1.0. Charades, htram and direct: blocking GVT; fixed W 50, 100, 250, 500 (low slack 25, 50, 100, 250); controller; hill climb from W 250. Devastator: adaptive; fixed W 250, 500, 1,000, 2,000 (low slack 50, 100, 200, 500).
- **C. Traffic**, Charades only: 23,552 intersections, 15 cars each. 128 × 184 uniform and congested (half the cars in 32 × 32 corner blocks), and 5,888 × 4 (one row per node, as 2,048 × 4 was), at high slack (end 512,000) and low slack (end 128,000). Arms as in job 3628935.

**Predictions:**
- A1. With htram, Charades' controller reaches 0.95–1.05 of its best fixed W. It gains less than at 2 × 8 (1.09–1.10), because on steady full-node runs it settled above the best W (0.87).
- A2. Devastator's adaptive window reaches ≤ 0.5 of its best fixed W. On full nodes at σ 2,000 it collapsed to 0.004 (job 3626388).
- A3. Devastator's best fixed W ÷ Charades' best fixed W is 0.9–1.3 (parity on steady high slack; phases include low slack).
- A4. Charades' controller beats Devastator's adaptive window by ≥ 1.5× at both remote shares.
- B1. Aggregation (best htram ÷ best direct) is 2–5× and grows with the off-node share; larger than at 2 × 8 (1.9–3.4×), since more PEs share each node's htram buffers.
- B2. With htram the controller reaches ≥ 0.85 of the best fixed W everywhere; with direct sends ≥ 0.95.
- B3. The hill climb in Charades reaches ≤ 0.4 with htram.
- B4. Devastator's adaptive window reaches ≤ 0.3 of its best fixed W at high slack. Charades' controller beats it in committed events/s in every workload.
- B5. Devastator best ÷ Charades best: 0.8–1.3 at high slack, 1.1–1.6 at low slack.
- C1. htram ÷ direct stays ≤ 1.2 on every traffic workload, and the controller reaches ≥ 0.9.

### Full-node reruns, results (2026-10-22/23, idev jobs 3629783 (skx-dev) and 3629781 (skx), 4 nodes)

> **Status: current.** Current (full nodes, production runtime, psm2). Devastator ran xorshift: with CLCG4 it is 10% slower at σ 100 and 2% at σ 2,000 ("Controller level, `--agg-scope`, σ 100 profile, results").

**Runs.** `$WORK/charades-runs/full_rerun.sh` (job 3629783: stage A reps 1–2) and `full_rerun2.sh` via `chain_skx.sh` (job 3629781: stage A rep 3 again, then B and C). CSVs and Devastator `results.txt` in `$WORK/charades-runs/full/` (copied to `~/charades-data/full/`); summaries by `policy_summary.py` and `deva_summary.py` (new).
- A `/work2` outage on 2026-10-22 (logins hung at shell startup; no TACC notice) stalled job 3629783 for about an hour. Its rep 3 was cut off and rerun whole in job 3629781; reps 1–2 agree with rep 3 within a few percent.
- Charades: 609 of 615 runs ok. The 6 stalls are all fixed W 250 with htram at low slack (σ 500 and 2,000, every rep): a rollback storm, as at 2 × 8.
- Devastator: 172 of 191 runs ok. The 19 stalls (cap 120 s for stage A reps 1–2, 60 s after) are its adaptive window (11) and fixed W 1,000–2,000 on phases (8). A stall bounds the rate at about committed ÷ cap: ≤ 3 M ev/s at high slack, ≤ 2–4.5 on phases. Medians below are over the runs that finished, so they overstate the adaptive window where it also stalled.
- Committed counts are identical across arms within each engine and workload.

**A. Phase-changing PHOLD** (M committed events/s, median of 3; ÷ the engine's own best fixed W, higher is better):

| arm | remote 0.5 | ÷ best | remote 1.0 | ÷ best |
|---|---|---|---|---|
| Charades controller, htram | 78.7 | **1.04** | 65.0 | **1.08** |
| Charades best fixed W, htram | 75.3 (W 100) | 1.00 | 60.5 (W 100) | 1.00 |
| Charades W 250, htram | | 0.65 | | 0.45 |
| Charades hill climb, htram | 27.1 | 0.36 | 36.1 | 0.60 |
| Charades blocking GVT, htram | 41.9 | 0.56 | 26.7 | 0.44 |
| Charades controller, direct | 38.4 | 0.95 | 24.3 | 0.99 |
| Charades best fixed W, direct | 40.2 (W 250) | 1.00 | 24.6 (W 100) | 1.00 |
| Devastator adaptive window | 18.5 (1 of 3; 2 stalled) | **0.18** | 10.1 (1 of 3; 2 stalled) | **0.17** |
| Devastator best fixed W | 101.4 (W 250) | 1.00 | 60.1 (W 100) | 1.00 |

- Charades' speedup over Devastator (Charades ÷ Devastator, higher is better for Charades): best fixed W ÷ best fixed W 0.74 (remote 0.5), 1.01 (1.0); Charades controller ÷ Devastator best fixed W 0.78, 1.08.
- Charades controller ÷ Devastator adaptive: 4.3× and 6.4× over the runs that finished; the stalled runs make it larger.
- Predictions: A1 right at remote 0.5 (1.04), just above the range at 1.0 (1.08); A2 right (0.17–0.18); A3 right at 1.0 (0.99), wrong at 0.5 (1.35); A4 right (≥ 4.3×).

**B. Gaussian σ sweep** (M committed events/s, median of 3; higher is better). Ratios are ÷ the engine's own best fixed W:

| workload | Charades htram: best fixed W | controller (÷, mean W) | hill climb | blocking | Charades direct: best | controller ÷ | htram ÷ direct | Devastator: best fixed W | adaptive (÷; ok of 3) | Charades speedup over Devastator, best ÷ best | Charades controller ÷ Devastator adaptive |
|---|---|---|---|---|---|---|---|---|---|---|---|
| σ 100, high slack | 121.9 (W 250) | 104.0 (0.85, 348) | 0.17 | 0.53 | 53.8 | 1.01 | 2.27 | 188.9 (W 1,000) | 152.3 (0.81; 3) | 0.65 | 0.68 |
| σ 500 | 118.1 (250) | 101.5 (0.86, 337) | 0.22 | 0.54 | 39.0 | 1.02 | 3.03 | 154.2 (1,000) | 98.5 (0.64; 2) | 0.77 | 1.03 |
| σ 1,000 | 114.5 (250) | 98.0 (0.86, 347) | 0.24 | 0.55 | 37.8 | 1.01 | 3.03 | 130.3 (1,000) | 36.1 (0.28; 1) | 0.88 | 2.71 |
| σ 2,000 | 108.5 (250) | 94.3 (0.87, 346) | 0.32 | 0.52 | 33.9 | 0.96 | 3.20 | 106.7 (1,000) | 7.7 (0.07; 1) | 1.02 | 12.3 |
| σ 4,000 | 98.4 (250) | 84.9 (0.86, 371) | 0.35 | 0.50 | 28.2 | 0.97 | 3.49 | 79.6 (1,000) | 11.2 (0.14; 3) | 1.24 | 7.58 |
| uniform remote 1.0 | 100.6 (250) | 84.2 (0.84, 381) | 0.33 | 0.46 | 25.1 | 0.97 | 4.01 | 69.6 (500) | 7.2 (0.10; 3) | 1.45 | 11.7 |
| σ 500, low slack | 96.0 (50) | 88.3 (0.92, 55) | 0.33 | 0.58 | 39.1 | 0.98 | 2.46 | 152.7 (200) | 101.3 (0.66; 3) | 0.63 | 0.87 |
| σ 2,000, low slack | 80.7 (50) | 77.7 (0.96, 56) | 0.50 | 0.62 | 33.2 | 0.96 | 2.43 | 99.9 (200) | 6.2 (0.06; 1) | 0.81 | 12.5 |
| uniform 1.0, low slack | 68.7 (50) | 62.9 (0.92, 52) | 0.47 | 0.35 | 25.1 | 0.96 | 2.74 | 65.2 (100) | 11.2 (0.17; 3) | 1.05 | 5.62 |

- **Charades is faster than Devastator in the remote-heavy regime**: σ ≥ 2,000 and uniform, at both slack levels except σ 2,000 low slack: Charades' speedup over Devastator's best fixed W is 1.02–1.45. Devastator is faster where communication is mostly local: Charades' speedup is 0.63–0.88 at σ ≤ 1,000 and at low-slack σ 500 and 2,000. That is the crossover the paper is about: Devastator's weak regime is Charades' strong one, and aggregation (2.3–4.0×, growing with the off-node share) is what moves it.
- **Charades' controller against Devastator's own window**: Charades' speedup is 2.7–12.5× from σ 1,000 up and at low-slack σ 2,000 and uniform, where Devastator's window collapses (0.06–0.28 of its best, and stalls). Devastator's window holds up only where communication is local: σ 100 (0.81, Charades controller 0.68× of it), σ 500 (0.64; Charades 1.03×), low-slack σ 500 (0.66; Charades 0.87×).
- **The controller's own gap is back on full nodes with htram at high slack: 0.84–0.87 of the best fixed W**, everywhere W 250 is best. W settles at 337–381. By `policy_summary.py`'s fit, a rolled-back event costs 13–29 committed events between W 250 and W 500 (6.5–30 at 2 × 8 on the fast stack), and 50–86 between W 250 and the controller's W. That the controller's extra rollbacks cost more than W 500's is unexplained (a guess, not checked: they are the ones that hold GVT back). With direct sends the controller is 0.96–1.02; at low slack with htram 0.92–0.96. This is the main open problem for the controller.
- Predictions: B1 right (2.3–4.0×, grows with off-node share); B2 wrong for htram at high slack (0.84–0.87, ≥ 0.85 in only 5 of 6) and right for direct (0.96–1.02); B3 right at high slack (0.17–0.35), wrong at low slack (0.33–0.50); B4 wrong at σ 100 and 500 (0.81, 0.64) and right elsewhere (≤ 0.28), and Charades' controller does not beat Devastator's window at σ 100 or low-slack σ 500; B5 mixed (in range at σ 1,000–4,000 and low-slack σ 500/2,000; outside at σ 100 and 500 (Devastator faster) and uniform (Charades faster)).

**C. Traffic** (Charades; M committed events/s, median of 3; events leaving their chare as % of committed):

| workload | leaving chare | best htram | best direct | htram ÷ direct | controller ÷ best fixed W, htram / direct | hill climb, htram | blocking, htram |
|---|---|---|---|---|---|---|---|
| 128 × 184 uniform | 20.1% | 102.8 (W 500) | 75.8 (W 500) | 1.36 | 0.97 / 0.98 | 0.30 | 0.47 |
| 128 × 184 congested | 19.6% | 52.6 (W 250) | 45.8 (W 250) | 1.15 | 0.95 / 0.94 | 0.41 | 0.34 |
| 5,888 × 4, high slack | 2.3% | 211.4 (W 500) | 206.3 (W 1,000) | 1.02 | 0.90 / 0.90 | 0.65 | 0.27 |
| 5,888 × 4, low slack | 2.3% | 204.6 (W 250) | 202.8 (W 100) | 1.01 | 0.92 / 0.93 | 0.87 | 0.27 |

- With 184 rows on 184 PEs every north–south move leaves its chare, so the 128-column grid now sends a fifth of its events off-chare and aggregation helps (1.36×). Congestion halves throughput (52.6 against 102.8), unlike at 2 × 8 (1.2×).
- Prediction C1: wrong for aggregation at 128 × 184 uniform (1.36 > 1.2), right elsewhere; the controller's ≥ 0.9 holds (0.90–0.98).

**What changes:**
- The 2 × 8 conclusions about the controller on phase-changing PHOLD (1.04–1.08) and its robustness with direct sends hold on full nodes.
- The cross-engine story is better than at 2 × 8: parity or better against Devastator's best fixed W in the remote-heavy regime, and an order of magnitude against its adaptive window there.
- The full-node htram high-slack gap (0.84–0.87) is now the controller's weakest result, and it is in the workloads the paper leads with. Fixing it (a rollback-cost-aware target, or calibrating on GVT-limiting rollbacks) is the next controller task.

### Controller level, `--agg-scope`, σ 100 profile (design, 2026-10-23; written before any runs)

> **Status: design.** Design, written before any runs.

**Why.** Two gaps remain on full nodes (Charades' speedup; higher is better for Charades):
- The controller with htram at high slack: 0.84–0.87 of the best fixed W.
- Best fixed W ÷ Devastator's best fixed W where traffic is local: 0.63–0.88.

**Stage A, level or dynamics.** In the full-node sweep, throughput peaks sharply at W 250: W 100 reaches 0.52–0.58 of it and W 500 0.68–0.84. The controller settles at a mean W of 337–381. If a fixed W at that mean is as slow as the controller, the controller's target (ε 0.001) is set too permissively on full nodes. If the fixed W is faster, the problem is how W moves between waves.
- Workloads: high slack (lookahead 100, mean 1,000, end 512,000) at σ 100, σ 2,000 and uniform remote 1.0.
- Arms, htram PP 512: fixed W 200, 250, 300, 350, 400; controller at ε 0.001 (the default), 0.0005 and 0.0003.
- 3 reps, interleaved.

**Stage B, `--agg-scope`.** With `--agg-scope=1`, events to PEs in the same process go as direct Charm++ messages and only events to other processes go through htram. Estimated shares of events by destination, Gaussian over LP ids with 128 LPs per PE, 23 PEs per process, 2 processes per node:

| σ | leave their PE | leave their process | leave their node |
|---|---|---|---|
| 100 | 55% | 2.7% | 1.3% |
| 500 | 90% | 13.5% | 6.7% |
| 1,000 | 95% | 27% | 14% |
| 2,000 | 97% | 50% | 27% |
| 4,000 | 99% | 72% | 50% |

Where Charades loses to Devastator (σ ≤ 1,000), most traffic stays in the process. There, Devastator does a lock-free queue insert and Charades goes through htram.
- Workloads: high-slack σ 100 and 2,000 at W 250; low-slack σ 500 at W 50.
- Arms: scope 0 against 1, plus direct sends.
- 3 reps, interleaved.

**Stage C, profile at σ 100.** perf on node 0 for Charades (W 250, PP 512, end 4,096,000, so that the run outlasts the sample) and Devastator (W 1,000). Collected: counters, LBR call stacks, and one DWARF capture of one Charades process.

**Predictions:**
- A1. A fixed W at the controller's mean (300–400) runs within 5% of the controller, so the problem is the target, not the dynamics.
- A2. On the finer grid the best fixed W is 200–300, and W 250 stays within 5% of it.
- A3. ε 0.0005 brings the mean W to 250–300 and the controller to 0.92–0.97 of the best fixed W. ε 0.0003 overshoots at σ 100, falling below W 200.
- B1. At σ 100, `--agg-scope=1` reaches ≤ 0.6 of scope 0. Same-process Charm++ messages are the expensive part, since htram over direct is 2.27× at σ 100, where 1.3% of events leave the node. At σ 2,000 scope 1 reaches 0.7–0.9, and at low-slack σ 500 ≤ 0.6.
- C1. At σ 100, same-process delivery takes ≥ 25% of Charades' PE time: htram insert, input buffer drain and its mutex, the node queue and per-PE messages. LCI and libfabric progress take < 10%. Cycles per committed event: Charades 1.4–1.7× Devastator.

### Controller level, `--agg-scope`, σ 100 profile, results (2026-10-23, idev job 3632385, 4 skx nodes)

> **Status: current.** Current.

**Runs.** All scripts are in `$WORK/charades-runs/` and write to `diag1/` (copied to `~/charades-data/diag1/`):
- `diag1.sh`: the three designed stages.
- Follow-ups in the same allocation:
  - `diag1b.sh`: W traces.
  - `diag1c.sh`: RNG and pollers.
  - `diag1d.sh` to `diag1i.sh`: controller variants.

The variants ran on `$WORK/charades-ctl`, a worktree of `charades-exp` with three new options: `--ctl-alpha-gain`, `--ctl-warm` and `--ctl-w-gain`. Every option defaults to the old behaviour.

All runs finished; there were no stalls. M committed events/s, median of 3 unless noted; higher is better. Full nodes, htram PP 512, high slack (lookahead 100, mean 1,000), end 512,000 (about 1.9 s) unless noted.

A build mistake, fixed before any run used it: the new tree's copied `config.mk` pointed at `charades-exp/src`, so its first build compiled into `charades-exp`'s library. The `charades-exp` binary used by every run here (built 2026-10-22 11:36) was never relinked. Its library was rebuilt from its own sources, and contains no new symbols.

**A. Fixed W around the peak, and the controller** (÷ fixed W 250; higher is better):

| arm | σ 100 | σ 2,000 | uniform |
|---|---|---|---|
| W 200 | 0.92 | 0.90 | 0.93 |
| W 250 (M ev/s) | 1.00 (121.6) | 1.00 (107.4) | 1.00 (102.4) |
| W 300 | 0.98 | 0.98 | 0.99 |
| W 350 | 0.94 | 0.96 | 0.94 |
| W 400 | 0.85 | 0.91 | 0.88 |
| controller ε 0.001 (mean W) | 0.84 (347) | 0.88 (345) | 0.83 (374) |
| ε 0.0005 | 0.87 (323) | 0.88 (321) | 0.85 (348) |
| ε 0.0003 | 0.89 (306) | 0.90 (308) | 0.86 (327) |

- The peak is flat from W 250 to 300 and falls on both sides. Below it the window caps throughput: at W 100 the run needs about twice the GVT rounds. Above it, rollbacks grow fast: rolled-back events rise from 0.003–0.9% of executed at W 250 to 1.3–2.4% at W 500.
- **A1 wrong.** A fixed W at the controller's mean runs 6–10% faster than the controller (σ 100: W 350 gives 0.94 against the controller's 0.84 at mean 347).
- **A2 right.** W 250 stays the best on the finer grid.
- **A3 wrong.** Lowering ε moves the mean W only from about 345 to about 307, and gains 2–5%.

**Where the controller loses** (follow-ups; ÷ fixed W 250 or 300 in the same job):
- **Its bookkeeping costs 4–5%.**
  - With the controller running but W fixed (`dry:300`), throughput is 0.95–0.96 of fixed W 300.
  - Sending the histogram on every 32nd count wave (`--ctl-hist-waves=32`) instead of every 8th recovers 1–2%; coarse bins (`--ctl-hist-coarse=1`) recover about the same.
  - The counters that ride on every wave are not the cost: `drysep`, with no counters on the waves, costs the same.
  - About 2–3% remains with neither histogram nor decisions (`--ctl-hist-waves` and `--ctl-interval` set to 10⁶). That is the per-event part: a histogram bin per remote send, a timer on every 16th forward event and on each rollback. It is not located further.
- **Startup.** α starts at 1 and falls at most 1.25× per fold. For the first ~25 folds, about 95 ms or 5% of a 1.9 s run, W sits at 110–200 and runs at half speed. `--ctl-warm=4` (α jumps to the waste seen) does not help: W then overshoots, giving 0.82–0.86.
- **W moves between rounds.** Rollbacks are bursty, 90 to 2,700 per round, so α and W swing: W runs 260–460 from round to round (p10–p90 273–415 at σ 2,000).
  - Even at ε 0.0001 (mean W 265–276, inside the flat peak) the controller reaches only 0.89–0.91.
  - Slower calibration (`--ctl-alpha-gain=0.1`) gains 1–3%.
  - Damping W (`--ctl-w-gain=0.3`) loses 2–4%. At 0.1 the start from W 8 never finishes, giving 0.42–0.48. Both W-damping settings are worse.
- **Long runs** (end 4,096,000, about 15 s, 2 reps; ÷ fixed W 250):

| arm | σ 100 | σ 2,000 | uniform |
|---|---|---|---|
| controller as shipped (ε 0.001) | 0.86 | 0.92 | 0.88 |
| ε 0.001, coarse histogram every 32nd wave | 0.88 | 0.95 | 0.91 |
| ε 0.0003, coarse histogram every 32nd wave | **0.93** | **0.98** | **0.94** |
| fixed W 300 | 1.00 | 1.03 | 0.99 |

  In 15 s runs, the start matters less and the cheaper histogram plus ε 0.0003 closes most of the gap: 0.93–0.98 of W 250, or 0.93–0.95 of the better of W 250 and 300. The 1.9 s runs of the paper sweeps understate every adaptive arm by a few percent.

**B. `--agg-scope`** (÷ htram for all remote events; higher is better):

| workload | htram for all (M ev/s) | scope 1: same-process events direct | all events direct |
|---|---|---|---|
| σ 100, W 250 | 120.3 | 0.84 | 0.46 |
| σ 2,000, W 250 | 107.4 | 0.80 | 0.30 |
| σ 500 low slack, W 50 | 96.9 | 0.88 | 0.41 |

**B1 wrong.** Same-process Charm++ messages are not the expensive part: sending them directly costs 12–20%. At σ 100 only 2.7% of events leave their process, yet sending those directly instead of through htram is most of the drop from 0.84 to 0.46. The 2.27× of htram over direct sends at σ 100 is mostly the off-process events. Per event, an off-process direct send costs far more than a same-process one.

**C. Profile at σ 100** (perf on node 0, W 250; Devastator at W 1,000):
- Per committed event: Charades about 4,000 cycles and 4,850 instructions; Devastator about 3,170 and 3,920. Charades ÷ Devastator: 1.27× the cycles (**C1 wrong**, below 1.4).
- At σ 2,000 two days ago (before psm2 and PP 512), Charades took 8,300 cycles and Devastator 5,300.
- Charades' PE time (inclusive):
  - event execution 38%, of which the model's forward handler is 15%, including `log` and `sin` from the CLCG4 Gaussian and exponential draws;
  - network progress polled by every PE 13%;
  - htram delivery (input buffer drain, `Aggregator::deliver`, `recv_remote_event`) 11%;
  - sends 9%;
  - GVT count waves 7.5%, including fossil collection 4%.
- Devastator: `drain` 21%, malloc/free about 17%, thread-channel reaping 9%, event execution 7.6%.
- **C1 wrong for same-process delivery too.** No single runtime path dominates.
- **Fewer network pollers is slower.** `+backend_poll_thread` 2 and 4 reach 0.98–0.99 of all PEs polling at σ 100, and 0.95 at σ 2,000.

**RNG fairness.** Devastator's default generator is xorshift; Charades uses CLCG4, and Devastator's `--rng=clcg4` gives it identical committed counts. With CLCG4, Devastator runs at 0.90 of its xorshift rate at σ 100 (168.6 against 185.9 M ev/s) and 0.98 at σ 2,000 (104.2 against 106.3). Every Devastator number above "Full-node reruns, results" used xorshift. With the same generator, Charades' speedup over Devastator at σ 100 is 0.71 (120 ÷ 168.6), not 0.65. **Paper comparisons should run Devastator with `--rng=clcg4`.**

**Validation: can ε 0.0003 become the default?** (`diag1i.sh`; short runs as in the full-node reruns; ÷ the workload's best fixed W in the same job; higher is better)

| workload | ε 0.001 (as shipped) | ε 0.001, histogram every 32nd wave | ε 0.0003, histogram every 32nd wave |
|---|---|---|---|
| phases, remote 0.5, htram | 1.00 | 0.97 | 0.94 |
| phases, remote 1.0, htram | 1.08 | 1.08 | 1.01 |
| low slack σ 500, htram | 0.92 | 0.92 | 0.92 |
| low slack σ 2,000, htram | 0.96 | 0.95 | 0.94 |
| low slack uniform, htram | 0.95 | 0.98 | 0.91 |
| high slack σ 2,000, direct | 0.97 | 0.97 | 0.95 |
| high slack uniform, direct | 0.96 | 0.96 | 0.96 |

**No.** ε 0.0003 gains about 5% with htram at high slack, and loses 2–7% on phases and at low slack. The histogram every 32nd wave is within noise in short runs: −3% to +3%.

**What this means:**
- The controller's gap at high slack with htram has three parts, and none is fixed by tuning:
  - **Bookkeeping, 4–5%**: 1–2% from the histogram, about 2–3% per event and not yet located.
  - **The start**: about 2.5% of a 1.9 s run.
  - **The target**: the rolled-back share that suits a regime differs between regimes, by about 3× between high slack with htram and the rest.
- The same ε cannot suit high slack with htram, where a rolled-back event costs 13–29 committed events between W 250 and 500, and phases or low slack. The target has to scale with what a rolled-back event costs in each regime. Measuring that cost as PE time failed before (`--ctl-cost=1`, step 2), because most of a rollback's cost is GVT held back. **The next controller step is a target that measures that indirect cost**, for example from how GVT advance per round responds to the rolled-back share across rounds. Design it before running anything.
- Cheap and safe now: none of today's changes is a default. `--ctl-alpha-gain` stays as an option at 0.25. `--ctl-warm` and `--ctl-w-gain` were removed after measuring worse.
- For the paper: run headline workloads longer than 1.9 s. In 15 s runs every adaptive arm gains a few percent and the noise is smaller.

### Controller: an aggregation bound, cheaper bookkeeping, a faster start (design, 2026-10-23; written before any runs)

> **Status: design.** Written before any runs. Every number in "What the data says" comes from logs of jobs 3629781 and 3632385; no new runs.

**Why.** The user's goal (2026-10-23) is to make Charades the best implementation in as many cases as possible. The controller is where Charades loses most against itself. Its ratio to the best fixed W on full nodes:
- 0.84–0.87 with htram at high slack (the σ sweep);
- 0.92–0.96 with htram at low slack;
- 0.90–0.97 on traffic.

With direct sends it is fine (0.96–1.02), and it leads every fixed W on phase-changing PHOLD (1.04–1.08). "Controller level, …, results" showed the high-slack gap is bookkeeping (4–5%), the start (about 2.5% of a 1.9 s run), and a waste target ε whose right value differs between regimes.

**What the data says.**
1. **Throughput can't steer the window directly; it is too noisy.** Per-round committed events/s from the W traces (job 3632385) vary by a coefficient of variation of 0.15 per round and 0.09–0.12 over 8-round blocks (about 16 ms). Comparing adjacent blocks cancels little: the difference has a standard deviation of 0.08–0.15. So telling a 4% gradient from noise at 2σ needs 15–60 block pairs, 0.5–1.5 s, which is most of a run. A throughput-seeking outer loop is ruled out.
2. **Time blocked at the window is throughput seen from the idle side.** Batches ending blocked by the window (σ 100, millions): W 200 217, W 250 178, W 300 175, W 350 204, W 400 247. The count is U-shaped, with its minimum at the best W: above the knee, GVT slows and PEs block again. Not a monotone signal.
3. **With htram, a larger W mostly costs aggregation, not rollbacks.** Uniform remote 1.0, high slack, job 3632385, rep 1:

| fixed W | 200 | 250 | 300 | 350 | 400 | controller ε 0.001 |
|---|---|---|---|---|---|---|
| events shipped urgently (count) | 35 | 998 | 23,809 | 236,065 | 825,434 | 823,089 |
| htram messages (M) | 1.16 | 1.23 | 1.36 | 1.77 | 2.58 | 2.54 |
| events per htram message | 157 | 148 | 134 | 103 | 71 | 72 |
| rolled back (% of executed, median of 3) | 0.55 | 0.90 | 1.09 | 1.15 | 1.18 | 1.11 |
| M committed events/s | 96.1 | 101.1 | 100.9 | 94.9 | 89.5 | 87.1 |

   From W 250 to 400 the rolled-back share barely moves, while messages double. The controller, which targets waste, can't see this cost.
4. **The urgency count does not carry over.** At low slack (lookahead 10, mean 200, job 3629781, rep 1), urgent events rise steadily with W: σ 2,000: W 25 2.2 M, W 50 5.0 M, W 100 12.3 M; best W 50. There is no knee at the best W, so a fixed budget on urgent sends tuned at high slack would pick about W 25 at low slack.
5. **The best fixed W sits at about the same quantile of the send-delay distribution, with htram on PHOLD.** PHOLD's send delay is lookahead + Exp(mean − lookahead); traffic's is lookahead + Exp(mean). F is that delay's CDF, and r is remote sends per executed event (from the CSVs).

| workload, full nodes | best fixed W | F(best W) | r | r · F(best W) |
|---|---|---|---|---|
| htram, high slack (lookahead 100, mean 1,000), σ 100–uniform | 250 (300 within 2%) | 0.15 (0.20) | 0.93–1.0 | 0.14–0.20 |
| htram, low slack (lookahead 10, mean 200) | 50 | 0.19 | 1.0 | 0.19 |
| htram, traffic 128 × 184, uniform / congested | 500 / 250 | 0.33 / 0.14 | 0.20 | 0.066 / 0.027 |
| htram, traffic 5,888 × 4 | 500–1,000 | ≥ 0.33 | 0.023 | ≥ 0.008 |
| direct, high slack | 250 (σ ≤ 500), 500 (σ ≥ 1,000) | 0.15–0.36 | 0.93–1.0 | 0.14–0.36 |
| direct, low slack | 50–100 | 0.19–0.38 | 1.0 | 0.19–0.38 |

   With htram on PHOLD, r · F(best W) is 0.14–0.20 at both slack levels. On traffic r · F at the best W is far lower, and there the waste bound, not aggregation, should bind. Direct sends tolerate a larger W, so the bound should apply only with aggregation.

**Design.**
1. **An aggregation bound** (`--ctl-agg-kappa=κ`; default 0 = off until measured; applies only with htram and the deadline policy).
   - The quantile rule now takes q = min(κ / r, ε / (r · α)), so W = F⁻¹(q).
   - In words: of the remote events a PE sends, at most κ per executed event may fall inside the window. With the deadline policy those events are flushed as soon as they come due, at each GVT update or at once, rather than waiting to fill a buffer. Larger W means more such flushes and smaller messages (finding 3).
   - Like the straggler bound, it bounds r · F(W). It is uncalibrated: no α, so no α noise and no slow start while it binds. It follows phase changes through the histogram, as now.
   - The waste bound stays as the safety cap against rollback storms, and it is the one that binds where few events are remote (traffic) or without htram.
   - Mean W predicted for κ 0.17 (from F⁻¹, before the waste cap): high slack 268 (σ 100: 281), low slack 45; phases at remote 1.0: 45 in the low-slack phase and 268 in the high; at remote 0.5 (r = 0.5): 89 and 474.
   - The finalize report gets the share of rounds in which each bound bound.
2. **Cheaper bookkeeping.**
   - The forward-event timer (every 16th event) and the rollback timers feed only κ of the experimental `--ctl-cost=1`. They now run only under it.
   - The histogram every 32nd count wave (`--ctl-hist-waves=32`) is measured against every 8th as an arm. Not a default yet.
3. **A faster start.** `--ctl-alpha-init` (default 1, as now) starts α lower, so the waste bound doesn't hold W at 110–200 for the first ~25 folds. Arm: 0.003 (α settles at 0.003–0.006 at high slack in the traces).

**Experiment** (one 4-node allocation, full nodes, htram PP 512 unless noted, 3 reps interleaved, end times as in "Full-node reruns"):
- Workloads:
  - htram, high slack: σ 100, σ 2,000, uniform;
  - htram, low slack: σ 500, σ 2,000, uniform;
  - phase-changing PHOLD at remote 0.5 and 1.0;
  - traffic 128 × 184 uniform and congested;
  - direct sends: high-slack σ 2,000 and uniform, and low-slack uniform.
- Arms:
  - the best fixed W and its neighbours as anchors;
  - the controller as shipped (ε 0.001);
  - `--ctl-cost=0` timers gated (the new build), otherwise as shipped;
  - κ 0.13, 0.17 and 0.22, each with ε 0.001;
  - κ 0.17 with the histogram every 32nd wave and α starting at 0.003 (the full proposal);
  - `dry:` at the best W, the cost check.
- Then 15 s runs (end × 8) of the anchors, the shipped controller and the full proposal on the three high-slack workloads.

**Predictions:**
- P1. With the timers gated, the dry run costs ≤ 3% (it was 4–5%), and ≤ 1.5% with the histogram every 32nd wave.
- P2. κ 0.17 with ε 0.001 reaches ≥ 0.95 of the best fixed W with htram at both slack levels; κ 0.13 and 0.22 stay ≥ 0.90 (the optimum is broad in q).
- P3. The full proposal:
  - htram high slack: 0.95–1.0 in short runs, ≥ 0.97 in 15 s runs;
  - low slack: 0.95–1.0;
  - phases: ≥ 1.04 (it was 1.04–1.08), possibly lower at remote 0.5 if W 474 in the high-slack phase is too wide;
  - traffic: within 2% of the shipped controller (the waste bound binds there);
  - direct sends: unchanged within 2% (κ applies only with htram).
- P4. Mean W with κ 0.17: high slack 260–300, low slack 40–55.
- P5. The κ bound binds in ≥ 80% of rounds on htram PHOLD at remote 1.0, and in ≤ 20% on traffic.

**What would change the plan.**
- If κ helps at high slack but costs at low slack (or the reverse), the quantile that suits each differs, and κ needs a model of how aggregation cost scales with the delay distribution rather than a constant.
- If the full proposal loses on phases at remote 0.5, scaling by 1/r is wrong for mixed self/remote traffic.
- Dragonfly, run after this, tests κ on a model it was not fitted to.

### Controller: an aggregation bound, cheaper bookkeeping, a faster start, results (2026-10-23, idev job 3633379, 4 skx nodes)

> **Status: current.** The revised controller tested here (κ 0.20, sparse waves, histogram every 32nd wave) is the default since these runs.

**Runs.** Scripts in `$WORK/charades-runs/`, run back to back in one allocation; CSVs in `ctl2/` (copied to `~/charades-data/ctl2/`, summaries by `summ.py` there):
- `ctl2.sh`: every designed arm, 3 reps, then 15 s runs (end 4,096,000), 2 reps.
- `ctl2b.sh`: perf of the controller's cost, then κ 0.20 with and without a lower starting α, 3 reps.
- `ctl2c.sh`: the controller's cost with sparse waves (new option, 9063017), then the revised controller against the old one on every htram group, 3 reps.
- `ctl2d.sh`: the revised controller with direct sends (3 reps) and in 15 s runs (2 reps).

Builds:
- Old: `charades-exp` (fe3a4ac, the controller as shipped).
- New: `charades-ctl` at 7ad0f97, plus the sparse-waves patch for `ctl2c` and `ctl2d`.

Setup: full nodes (2 × 23 PEs per node), htram PP 512 unless noted. Workloads:
- PHOLD with lookahead 100 and mean delay 1,000 (end 512,000), or lookahead 10 and mean delay 200 (end 128,000);
- phase-changing PHOLD (end 256,000);
- traffic 128 × 184 (end 512,000).

No run failed or stalled. Ratios are median rate ÷ the median rate of the best fixed W in the same workload and script; higher is better. Mean W in parentheses.

**1. The designed arms** (`ctl2.sh`):

| workload (htram) | best fixed W (M ev/s) | old controller | new build, κ off | κ 0.13 | κ 0.17 | κ 0.22 | full proposal (κ 0.17, histogram every 32nd wave, α from 0.003) | controller computing, W pinned at the best W |
|---|---|---|---|---|---|---|---|---|
| lookahead 100, mean 1,000, σ 100 | 122.1 (W 250) | 0.84 (346) | 0.84 | 0.90 (232) | 0.95 (276) | 0.89 (333) | **0.97** (280) | 0.94 |
| σ 2,000 | 108.8 (250) | 0.87 (339) | 0.87 | 0.88 (223) | 0.93 (264) | 0.91 (318) | **0.97** (268) | 0.93 |
| uniform remote 1.0 | 105.1 (250) | 0.81 (383) | 0.80 | 0.86 (222) | 0.91 (264) | 0.88 (317) | **0.94** (267) | 0.90 |
| lookahead 10, mean 200, σ 500 | 97.5 (50) | 0.93 (56) | 0.94 | 0.83 (37) | 0.90 (46) | **0.95** (57) | 0.93 (46) | 0.95 |
| σ 2,000 | 84.6 (50) | 0.93 (56) | 0.95 | 0.80 (37) | 0.91 (45) | **0.97** (57) | 0.93 (46) | 0.94 |
| uniform remote 1.0 | 69.1 (50) | 0.95 (54) | 0.97 | 0.84 (37) | 0.89 (45) | **0.97** (54) | 0.93 (46) | 0.96 |
| phase-changing, remote 0.5 | 79.9 (100) | 1.02 (120) | 1.03 | 1.07 (108) | 1.04 (118) | 1.01 (118) | 1.05 (126) | 0.96 |
| phase-changing, remote 1.0 | 60.4 (100) | 1.12 (96) | 1.10 | 0.98 (59) | 1.07 (73) | 1.13 (91) | 1.07 (78) | 0.98 |
| traffic, congested | 52.5 (250) | 0.94 (253) | 0.96 | 0.96 | 0.94 | 0.94 | **0.86** (488) | 0.89 |
| traffic, uniform | 103.5 (500) | 0.96 (464) | 0.97 | 0.99 | 0.98 | 0.98 | **0.92** (799) | 0.94 |

The same with direct sends (κ does not apply): old 0.98, 0.98, 0.98; full proposal 0.99, 0.98, 1.00 (lookahead 100 σ 2,000 and uniform; lookahead 10 uniform).

How often κ set W (κ 0.17): 97–98.5% of updates on PHOLD at remote 1.0, 10% on phase-changing PHOLD at remote 0.5, none on traffic.

15 s runs (÷ fixed W 250 in the same runs): old 0.84, 0.86, 0.89; full proposal 0.95, 0.99, 0.98 (σ 100, σ 2,000, uniform).

**2. What the controller's machinery costs.**
- **Gating the timers changed nothing** (the "new build, κ off" column matches the old controller).
- **perf** (fixed W 250 against the same with the controller computing, σ 2,000, end 4,096,000; node 0):
  - 111.9 against 105.1 M ev/s (0.94); about 6% more cycles per committed event.
  - The controller's own code is about 1%: the delay histogram 0.33%, the window computation 0.16%, allocation and reduction sends about 0.5%.
  - The rest is spread over what PEs do while waiting: network progress +0.7 points (self), htram's deadline flushes +0.5, idle flushes, queue polling. So the count waves had slowed.
- **Sparse waves** (`--ctl-sparse-waves=1`, 9063017): the counters ride only on the wave that ends a round. Controller computing with W pinned at 250, ÷ fixed W 250:

| | σ 100 | σ 2,000 | uniform |
|---|---|---|---|
| counters every wave, histogram every 8th (before) | 0.95 | 0.95 | 0.94 |
| sparse waves, histogram every 8th | 0.96 | 0.95 | 0.95 |
| sparse waves, histogram every 32nd | 0.96 | 0.98 | 0.98 |

**3. κ 0.20, with the histogram every 32nd wave** (`ctl2b.sh`; with and without α starting at 0.006):

| workload (htram) | κ 0.20 | κ 0.20, α from 0.006 |
|---|---|---|
| lookahead 100, mean 1,000: σ 100, σ 2,000, uniform | 0.91, 0.92, 0.92 (W 283–296) | 0.96, 0.94, 0.92 |
| lookahead 10, mean 200: σ 500, σ 2,000, uniform | 0.96, 0.98, 0.98 (W 50–51) | 0.97, 0.96, 0.99 |
| phase-changing, remote 0.5 / 1.0 | 0.98 / 1.11 | 1.00 / 1.14 |
| traffic, congested / uniform | 0.97 / 1.00 | 0.94 / 0.98 |

**4. The revised controller** (κ 0.20, sparse waves, histogram every 32nd wave; α from 1), same-job comparison with the old one (`ctl2c.sh`, `ctl2d.sh`):

| workload | best fixed W (M ev/s) | old controller | revised controller |
|---|---|---|---|
| htram, lookahead 100, mean 1,000, σ 100 | 121.6 (W 250) | 0.84 (W 350) | **0.94** (298) |
| σ 2,000 | 108.0 (300) | 0.88 (342) | **0.94** (285) |
| uniform remote 1.0 | 102.7 (250) | 0.84 (370) | **0.94** (283) |
| htram, lookahead 10, mean 200, σ 500 | 97.4 (50) | 0.94 (55) | **0.98** (51) |
| σ 2,000 | 82.6 (50) | 0.96 (56) | 0.97 (50) |
| uniform remote 1.0 | 68.2 (50) | 0.94 (53) | **0.98** (51) |
| htram, phase-changing, remote 0.5 | 80.7 (100) | 1.02 (117) | 1.02 (117) |
| remote 1.0 | 61.1 (100) | 1.08 (96) | **1.11** (87) |
| htram, traffic congested | 52.5 (250) | 0.93 (250) | **0.98** (238) |
| traffic uniform | 102.5 (500) | 0.98 (464) | **1.01** (440) |
| direct, lookahead 100, σ 2,000 | 33.8 (500) | 0.98 | 0.98 |
| direct, uniform remote 1.0 | 25.2 (500) | 0.97 | 0.97 |
| direct, lookahead 10, σ 500 | 40.4 (50) | 0.98 | 0.98 |
| direct, lookahead 10, uniform | 25.0 (100) | 0.97 | 0.98 |

15 s runs (÷ fixed W 250 in the same runs): **0.95, 0.98, 0.97** (σ 100, σ 2,000, uniform; W 299–314), against 0.84–0.89 for the old controller earlier in the job.

The revised controller is at least as good as the old one in all 14 workloads. Its worst case rises from 0.84 to 0.94 of the best fixed W.

**Predictions:**
- P1. **Wrong.** Gating the timers did nothing; the cost was slower count waves. Sparse waves with the histogram every 32nd wave cut it to 2–4%.
- P2. **Partly wrong.** κ 0.17 reached 0.91–0.95 with lookahead 100 (≥ 0.95 in 1 of 3) and 0.89–0.91 with lookahead 10. κ 0.13 fell to 0.80–0.90. A too-small window costs more with short delays. With short delays the best κ is about 0.22; with long ones about 0.17.
- P3. Right for lookahead 100 (0.94–0.97; 0.95–0.99 in 15 s runs), phases (1.05, 1.07) and direct sends. **Wrong for lookahead 10** (0.93, not 0.95–1.0) **and traffic** (0.86 and 0.92, not within 2%). The low starting α left traffic's window at 488–799 while α climbed back. Dropping it, and κ 0.20, fixed both.
- P4. Right: mean W with κ 0.17 was 264–280 (lookahead 100) and 45–46 (lookahead 10).
- P5. Right: κ set W in 97–98.5% of updates on PHOLD at remote 1.0 and in none on traffic.

**What this means:**
- **Aggregation, not waste, limits the window with htram.** A bound on how many remote sends per executed event fall inside the window takes the controller from 0.81–0.88 to 0.94 of the best fixed W with long delays, and helps every other htram workload.
- **κ 0.20 is a compromise.** With long delays it holds W at about 285 against a best of 250 (0.94). With short delays it holds W at 50, the best. A κ that adapts to how aggregation cost grows with W would close the remaining 6%.
- **Not adopted:**
  - The lower starting α helps with long delays and hurts traffic.
  - Warm start and W damping were already dropped.
  - Time spent in the first rounds remains a cost in short runs.
- **Defaults since these runs** (charades, after 9063017): `--ctl-agg-kappa=0.20`, `--ctl-sparse-waves=1`, `--ctl-hist-waves=32`. The old paths stay covered by the test configs `agg_ctl_floor_bucket_pp` (κ off) and `ctl_quantile_shared` (counters every wave). The finalize report now counts how often κ set W per update, not per round: with the histogram every 32nd wave, only one round in four recomputes W.

### Scaling check at 16 and 32 nodes (design, 2026-10-23; written before any runs)

> **Status: design.** Written before any runs.

**Why.** Nothing above 8 nodes has run since the go/no-go (job 3620576, Debug runtime). The controller (κ 0.20), htram PP 512 and `+lci_ndevices 16` were all tuned at 4 nodes. This check asks whether anything breaks or degrades at 16 and 32 nodes before the paper's scaling runs; it is not a source of paper numbers. Those wait for the 4-node comparison below to settle the settings.

**Setup.** Batch jobs on skx: one of 16 nodes (runs at 4 and 16 nodes, so the job has its own 4-node reference) and one of 32 nodes (runs at 32). Script `$WORK/charades-runs/scale/scale.slurm`; output in `$WORK/charades-runs/scale/`. Two reps, interleaved.
- Weak-scaled Gaussian PHOLD, lookahead 100, mean delay 1,000, end time 512,000, 15 start events, 128 LPs per PE or rank. Full nodes: 2 processes × 23 PEs per node (Devastator 2 processes × 23 workers; ROSS 46 ranks per node, so all three engines have the same LPs and commit the same events). σ is in LP ids and LPs per node stay constant, so σ 100 and σ 2,000 keep their off-node share as nodes are added; uniform remote 1.0 goes from 75% off-node at 4 nodes to 94% at 16 and 97% at 32.
- Charades `charades-main` (eef0778, the revised controller as default), native psm2, htram PP 512:
  - htram, σ 100, σ 2,000, uniform: the controller (ε 0.001) and fixed W 150, 250, 400 (W 250 was best at 4 nodes).
  - direct sends, σ 2,000: the controller and fixed W 250, 500.
  - `+lci_ndevices` 8 and 32 against the default 16: htram, σ 2,000, W 250.
- Devastator (ofi-psm2, `--rng=clcg4`), rebuilt for 32 and 64 processes: σ 100 at W 1,000; σ 2,000 at W 500 and 1,000 (its best at 4 nodes).
- ROSS optimistic (`--read-buffer=1`, default batch and GVT interval), σ 2,000.

**Measures.** Weak-scaling efficiency: M committed events/s per node at N nodes ÷ the same at 4 nodes (higher is better; 1.0 is perfect). Also the controller ÷ the best fixed W, events per htram message, GVT rounds per second, and Charades' speedup over each engine.

**Predictions:**
- S1. Every run finishes, apart from excessive-rollback stalls at fixed W 400. No startup or GVT hangs.
- S2. Charades with htram at σ 100 and σ 2,000: weak-scaling efficiency ≥ 0.85 at 16 and 32 nodes; events per htram message within 20% of 4 nodes, since each node still sends to the same few neighbours.
- S3. Uniform: efficiency 0.4–0.7. Each process now sends to 32–64 others instead of 8, so each destination buffer fills 4–8× more slowly; events per htram message fall below half of 4 nodes'.
- S4. The best fixed W stays 250 at σ 100 and σ 2,000. The controller reaches ≥ 0.90 of the best fixed W there, and 0.80–1.0 at uniform, where κ was not tested at this many destinations.
- S5. Devastator: weak-scaling efficiency ≥ 0.85 at σ 100 and ≥ 0.75 at σ 2,000. Charades' speedup over Devastator at σ 2,000 (each at its best measured W) stays 0.9–1.2, as at 4 nodes (1.03).
- S6. ROSS: efficiency 0.7–1.0 at σ 2,000. Charades' speedup over ROSS is 3–6.
- S7. Direct sends: efficiency ≥ 0.8 at σ 2,000; the controller ≥ 0.95 of the best fixed W.
- S8. No `+lci_ndevices` setting beats 16 by more than 5% at 16 nodes; at 32 nodes, 32 devices may gain a few percent.

### Three engines at 4 nodes, paper grade (design, 2026-10-23; written before any runs)

> **Status: design.** Written before any runs.

**Why.** The cross-engine numbers in "Current numbers" have three known faults: Devastator ran its xorshift RNG (10% faster than CLCG4 at σ 100), ROSS has not been rerun since job 3626388 and was never tuned, and the 1.9 s runs understate adaptive windows, which spend their first rounds finding W. This run replaces them with numbers to quote.

**Setup.** One interactive allocation of 4 skx nodes (idev on skx, 4 h), script `$WORK/charades-runs/cmp4/cmp4.sh`, output `$WORK/charades-runs/cmp4/`. Full nodes, 23,552 LPs (128 per PE or rank), 15 start events. Three reps, reps outermost so a cut-off job still has whole reps.
- **Run length**: about 1.3 × 10⁹ committed events per run, 10–25 s for Charades. End times: lookahead 100 / mean delay 1,000 at 4,096,000; lookahead 10 / mean delay 200 at 768,000; phase-changing PHOLD (alternating between the two every 32,000) at 2,048,000.
- **Workloads**: lookahead 100 / mean delay 1,000 at σ 100, 500, 1,000, 2,000, 4,000 and uniform remote 1.0; lookahead 10 / mean delay 200 at σ 500, 2,000 and uniform; phase-changing PHOLD at remote 0.5 and 1.0. Eleven in all.
- **Charades** (`charades-main`, eef0778; native psm2, PP 512): with htram, the controller and fixed W around the best from job 3629781 (lookahead 100: 200, 250, 300; lookahead 10: 25, 50, 100; phases: 50, 100, 250). With direct sends, as the aggregation ablation, at σ 100, σ 2,000, uniform and lookahead-10 uniform: the controller and fixed W 250 and 500 (lookahead 10: 50, 100).
- **Devastator** (ofi-psm2, 8 processes × 23 workers, `--rng=clcg4`): its adaptive window (capped at 90 s; a stall bounds the rate) and fixed W 250, 500, 1,000, 2,000 (lookahead 10: 100, 200, 400; phases: 100, 250, 500).
- **ROSS** (optimistic, `--read-buffer=1`, 46 ranks per node): first a tuning sweep at σ 2,000, end 512,000: `--batch` 4, 16, 64 × `--gvt-interval` 16, 64, 256, plus the best setting at 48 ranks per node with 24,576 LPs, to measure what the 46-rank layout costs ROSS per core. Then the best setting on every workload except phases, which its model doesn't have.

**Measures.** M committed events/s, medians of 3; Charades' speedup over each engine (Charades ÷ the other, each at its best, higher is better for Charades); each adaptive policy ÷ its engine's best fixed W; committed counts equal across the three engines in each workload.

**Predictions:**
- C1. Charades' speedup over Devastator, both at their best fixed W: 0.65–0.80 at σ 100; 0.75–0.95 at σ 500–1,000; 1.0–1.15 at σ 2,000; 1.2–1.6 at σ 4,000 and uniform; 0.6–1.1 with lookahead 10; 0.7–1.05 on phases. That is the full-node pattern with CLCG4's 2–10% added to Charades' side.
- C2. Charades' controller ÷ its best fixed W ≥ 0.95 in every workload; ≥ 1.0 on phases.
- C3. Devastator's adaptive window ÷ its best fixed W: ≤ 0.3 from σ 1,000 up and on phases, 0.6–0.9 at σ 100 and 500. Longer runs do not rescue it, because its failure is a collapsed window, not a slow start.
- C4. Charades' controller ÷ Devastator's best fixed W ≥ 0.95 in the five workloads where C1 predicts Charades leads.
- C5. ROSS tuning moves ROSS by ≤ 20% over its defaults; 46 against 48 ranks per node changes its per-core rate by ≤ 5%.
- C6. Charades' speedup over ROSS (both at their best) is 2.5–4.5 in every workload, highest at uniform.
- C7. Aggregation (Charades best htram ÷ best direct) 2.2–4.0, as in job 3629781.

### Scaling check at 16 and 32 nodes, results (2026-10-24, batch jobs 3633769 (16 nodes, runs at 4 and 16) and 3633770 (32 nodes))

> **Status: current.** First runs above 8 nodes on the current stack. Short runs (end 512,000, 1.5–8 s), 2 reps; the fixed-W grid (150, 250, 400) turned out too narrow at scale, so Charades' "best fixed W" at 16 and 32 nodes is a lower bound.

**Runs.** `$WORK/charades-runs/scale/scale.slurm`; CSVs, `deva/results.txt`, `ross/results.txt` copied to `~/charades-data/scale/`; summary `scale_summary.py`. Devastator built for 32 and 64 processes inside the jobs (1 and 4 min). Committed counts are identical across the three engines at every node count.
- Failures: every `+lci_ndevices 32` run aborts at startup (`PSM2 can't open hfi unit: 0 (err=23)`, then LCI's `ofi_device_impl_t` assert): 2 processes × 32 psm2 endpoints exceed the node's hfi1 contexts. An abort, not a hang.
- Two 4-node runs (rep 1, σ 100, the controller and W 150) hit the 120 s cap. They were the job's first two launches; rep 2 of the same runs took 1.6–2.0 s of execution. Most likely a cold start from `$WORK`, but the rep-1 logs were overwritten by rep 2 (both are labelled `r1` by `ctl_sweep.sh`), so this is not confirmed.

**Charades with htram** (M committed events/s, median of 2; per node; weak-scaling efficiency = per-node rate ÷ the 4-node per-node rate, higher is better):

| workload | nodes | best fixed W (W) | per node | efficiency | controller (÷ best; mean W) | events per htram message, best W |
|---|---|---|---|---|---|---|
| σ 100 (1.4% off-node) | 4 | 123.2 (250) | 30.8 | 1.00 | 113.1 (0.92; 296) | 214 |
| | 16 | ≥ 404.1 (400) | 25.3 | ≥ 0.82 | 345.7 (0.86; 291) | 140 |
| | 32 | ≥ 644.4 (400) | 20.1 | ≥ 0.65 | 521.2 (0.81; 284) | 139 |
| σ 2,000 (27% off-node) | 4 | 106.8 (250) | 26.7 | 1.00 | 101.9 (0.95; 284) | 118 |
| | 16 | ≥ 324.9 (400) | 20.3 | ≥ 0.76 | 287.1 (0.88; 274) | 79 |
| | 32 | ≥ 494.8 (400) | 15.5 | ≥ 0.58 | 444.5 (0.90; 278) | 74 |
| uniform (75 / 94 / 97% off-node) | 4 | 102.5 (250) | 25.6 | 1.00 | 93.5 (0.91; 282) | 149 |
| | 16 | ≥ 144.6 (400) | 9.0 | ≥ 0.35 | 126.2 (0.87; 281) | 14 |
| | 32 | ≥ 209.8 (400) | 6.6 | ≥ 0.26 | 175.4 (0.84; 278) | 8 |

**Why Charades loses efficiency: GVT round latency, and aggregation at many destinations.**
- At fixed W 250 every run needs the same number of GVT rounds (about 8,300), so it is paced by how fast rounds complete. Rounds per second at σ 100: 5,681 (4 nodes), 3,796 (16), 2,824 (32); at σ 2,000: 4,932, 3,307, 2,510. Execution time grows in proportion (σ 100: 1.47, 2.18, 2.92 s). Efficiency stays at 99.9–100% even at W 400, so a wider window would help further: the best W at 16 and 32 nodes is above the grid.
- The controller does not follow. The aggregation bound κ 0.20 holds W at 274–291 at every node count, which was right at 4 nodes and too narrow at 16 and 32.
- Uniform: events per htram message collapse from 149 to 14 and 8. Each process sends to 32–64 others; buffers flush on the deadline (h = W) long before they fill.

**Direct sends and LCI devices** (σ 2,000):

| nodes | direct best (W) | efficiency | controller ÷ best | htram ÷ direct | 8 devices ÷ 16 (htram W 250) |
|---|---|---|---|---|---|
| 4 | 33.7 (500) | 1.00 | 0.97 | 3.17 | 0.99 |
| 16 | 119.9 (500) | 0.89 | 0.92 | 2.71 | 0.92 |
| 32 | 218.4 (500) | 0.81 | 0.93 | 2.27 | 0.95 |

**Across engines** (Charades' speedup = Charades best fixed W ÷ the other, higher is better for Charades; Charades' numbers are lower bounds at 16 and 32 nodes):

| workload | nodes | Charades | Devastator, W 1,000 (efficiency) | ROSS (efficiency) | speedup over Devastator | speedup over ROSS |
|---|---|---|---|---|---|---|
| σ 100 | 4 | 123.2 | 169.2 (1.00) | – | 0.73 | – |
| | 16 | ≥ 404.1 | 657.8 (0.97) | – | ≥ 0.61 | – |
| | 32 | ≥ 644.4 | 1,245.0 (0.92) | – | ≥ 0.52 | – |
| σ 2,000 | 4 | 106.8 | 105.1 (1.00) | 26.3 (1.00) | 1.02 | 4.06 |
| | 16 | ≥ 324.9 | 363.7 (0.86) | 95.2 (0.90) | ≥ 0.89 | 3.41 |
| | 32 | ≥ 494.8 | 724.3 (0.86) | 170.7 (0.81) | ≥ 0.68 | 2.90 |

Devastator's W 1,000 beat W 500 at σ 2,000 at every node count.

**Predictions:**
- S1. Partly wrong: no hangs, but every 32-device run aborts (psm2 contexts), and two cold-start launches hit the cap.
- S2. **Wrong.** Efficiency ≥ 0.82 / 0.65 at σ 100 and ≥ 0.76 / 0.58 at σ 2,000 (16 / 32 nodes), not ≥ 0.85; events per message at σ 100 fell by a third (at W 400 against W 250; at equal W they are unchanged).
- S3. Wrong in degree: uniform efficiency 0.35 / 0.26, below 0.4–0.7; events per message fell more than predicted (149 → 8).
- S4. **Wrong.** The best fixed W moves from 250 to at least 400; the controller reaches 0.81–0.90.
- S5. Devastator's efficiency right (0.92–0.97 at σ 100, 0.86 at σ 2,000); Charades' speedup at σ 2,000 wrong (≥ 0.89 / ≥ 0.68, not 0.9–1.2).
- S6. ROSS efficiency right (0.90 / 0.81); speedup 3.41 / 2.90, at and just below the range.
- S7. Direct efficiency right (0.89 / 0.81); controller 0.92–0.93, below the predicted ≥ 0.95.
- S8. Right for 8 devices (0.92–0.99 of 16); 32 devices could not run.

**What this means:**
- **At scale, Charades is paced by GVT round latency, not by rollbacks.** Two fixes, in order: (1) the controller should widen W when rounds are the limit; κ, which bounds aggregation cost, keeps W near its 4-node value; (2) make GVT rounds faster at 1,000+ PEs (round time roughly doubles from 4 to 32 nodes).
- **Uniform traffic at many destinations defeats per-destination buffering.** This needs routing through intermediate nodes (as TRAM's virtual topologies do) or a deadline that grows with the number of destinations.
- **The cross-engine picture at 4 nodes does not hold at 32 yet.** At σ 2,000 Charades goes from parity with Devastator to at least 0.68 of it. The next step is a W sweep beyond 400 at 16 and 32 nodes, to find the true best W before changing the controller.

### Window sweep at 16 and 32 nodes (design, 2026-10-24; written before any runs)

> **Status: design.** Written before any runs.

**Why.** In the scaling check the best fixed W at 16 and 32 nodes was the widest tested (400), so Charades' rate there is a lower bound. At W 250 every run needs about 8,300 GVT rounds at any node count, and rounds slow from about 175 µs (4 nodes) to 355 µs (32), so a wider W should hide round latency. This sweep finds the best W before the controller is changed.

**Setup.** Same layout and workloads as the scaling check (weak-scaled Gaussian PHOLD, lookahead 100, mean delay 1,000, end 512,000; σ 100, σ 2,000, uniform). `$WORK/charades-runs/wsweep/wsweep.slurm`; 16 nodes on skx-dev, 32 nodes on skx (separate jobs). Two reps, cap 60 s per run.
- Charades with htram: fixed W 400, 600, 800, 1,200; the controller as default (κ 0.20); the controller with the aggregation bound off (`--ctl-agg-kappa=0`, the waste bound alone).
- Devastator (`--rng=clcg4`): W 1,000 and 2,000 at σ 100 and σ 2,000, in case its best W also moves.
- Per-rep log directories (the scaling check's logs were overwritten between reps).

**Predictions:**
- W1. The best fixed W is 600–800 at 16 nodes and 800–1,200 at 32 for σ 100 and σ 2,000; at the best W at least 99.5% of executed events commit.
- W2. The best W beats W 400 by 1.1–1.3× at 32 nodes. Charades' weak-scaling efficiency at σ 2,000 rises to 0.7–0.8 at 32 nodes, and its speedup over Devastator there to 0.8–0.95.
- W3. Uniform: the best W also grows, but gains ≤ 1.2× over W 400, since aggregation, not rounds, limits it.
- W4. The controller with κ off sits wider than the default and reaches 0.9–1.0 of the best fixed W at σ 100 and σ 2,000; the default stays at 0.8–0.9.
- W5. Devastator's best W stays 1,000, or moves to 2,000 for a gain of ≤ 10%.

### Window sweep at 16 and 32 nodes, results: 16 nodes (2026-10-24, batch job 3635596 on skx-dev)

> **Status: current** for 16 nodes. The 32-node job (3635597, skx) is still queued; its results will go in their own section.

**Runs.** `$WORK/charades-runs/wsweep/wsweep.slurm`; CSVs and `deva/results.txt` copied to `~/charades-data/wsweep/`; summary `wsweep_summary.py 16`. 2 reps; all runs finished except W 1,200 at σ 100 and σ 2,000 (both reps hit the 60 s cap: excessive rollbacks). Weak-scaling efficiency uses the 4-node rates from job 3633769 (per node, best fixed W).

**16 nodes** (M committed events/s, median of 2; higher is better; in parentheses: % of executed events committed, events per htram message):

| arm | σ 100 | σ 2,000 | uniform |
|---|---|---|---|
| W 250 (job 3633769) | 331.9 | 288.3 | 129.7 |
| **W 400** | **407.6** (99.99%, 144) | **326.0** (99.92%, 79) | 147.3 (99.25%, 14) |
| W 600 | 259.6 (96.91%, 48) | 299.6 (99.30%, 31) | **158.4** (97.97%, 11) |
| W 800 | 32.2 (87.33%, 25) | 216.9 (95.77%, 21) | 152.9 (93.66%, 9) |
| W 1,200 | stalled | stalled | 115.5 (78.94%, 6) |
| controller, default (÷ best; mean W) | 348.7 (0.86; 291) | 281.7 (0.86; 276) | 128.2 (0.81; 280) |
| controller, κ off (÷ best; mean W) | 319.4 (0.78; 370) | 286.4 (0.88; 430) | 135.3 (0.85; 374) |
| Devastator W 1,000 / W 2,000 | 661.2 / 640.5 | 380.1 / 351.0 | – |
| Charades' speedup over Devastator (best ÷ best) | 0.62 | 0.86 | – |
| Charades weak-scaling efficiency at its best W | 0.83 | 0.76 | 0.39 |

**What it says:**
- **A wider window does not recover the lost efficiency.** The best W at 16 nodes is about 400 (σ 100 and σ 2,000) and 600 (uniform), and the peak is sharp: from W 400 to 600 at σ 100, the committed share falls only from 99.99% to 96.91%, yet throughput falls by 36%, and events per htram message drop from 144 to 48. Past the best W, rollbacks and lost aggregation together cost more than the slower GVT rounds.
- So the efficiency lost from 4 to 16 nodes (0.83 at σ 100, 0.76 at σ 2,000) has to come back from faster GVT rounds or cheaper communication, not from the window.
- The controller is 0.81–0.86 of the best fixed W with κ and 0.78–0.88 without. Turning κ off lets it go wider (mean W 370–430) but loses at σ 100.

**Predictions (16 nodes):**
- W1. **Wrong.** The best W is about 400 at σ 100 and σ 2,000, not 600–800; W 800 already costs 33–92%.
- W3. Right: at uniform the best W grows to 600 and gains 1.08× over W 400.
- W4. **Wrong.** With κ off the controller reaches 0.78–0.88, not 0.9–1.0; the default stays at 0.81–0.86.
- W5. Right: Devastator's W 2,000 is 0.92–0.97 of its W 1,000.
- W2 is about 32 nodes; pending.

### GVT round cost at 4 and 16 nodes (design, 2026-10-24; written before any runs)

> **Status: design.** Written before any runs.

**Why.** At W 250 every run needs about 8,300 GVT advances at any node count, and they slow from about 175 µs each at 4 nodes to 260 µs at 16 and 355 µs at 32; a wider window does not hide it (window sweep, 16 nodes). An advance is made of count waves: every PE contributes a tuple reduction (sent and received counts per bucket, plus the minimum buckets passed), the result is broadcast, and each PE contributes the next wave when it handles the result. A wave's time is therefore the reduction itself plus how late the slowest PE answers. This splits the two.

**Setup.** One skx-dev job, 16 nodes, 30 min: `$WORK/charades-runs/gvtprobe/gvtprobe.slurm`, output in `$WORK/charades-runs/gvtprobe/`. Full-node layout and psm2 as in every recent run.
- **A. Reduction alone**: `tools/redbench` (new; charades repo) runs back-to-back waves shaped like the GVT's (8 buckets: a 16-int sum plus an int minimum, result broadcast to the group, next wave on receipt), 20,000 waves after 1,000 warm-up, at 1, 2, 4, 8 and 16 nodes, 2 reps. It reports time per wave and PE 0's contribute-to-result latency (median, p90, p99). On the Mac (2 processes × 2 PEs) it takes 67 µs per wave.
- **B. Waves in Charades**: `--gvt-trace=1` (PE 0 records each wave's start and end, buckets asked, completed; every PE's time in `execute()`), σ 100 and σ 2,000 at W 250 and W 400, 4 and 16 nodes, 2 reps.
- **C. One knob**: 16 nodes, σ 2,000, W 400, `--gvt-wave-events` 0 (contribute at once) against the default 128, 2 reps.

**Predictions:**
- G1. The reduction alone takes 30–80 µs per wave at 1–4 nodes and grows by at most 2× to 16 nodes.
- G2. In Charades, a wave takes 2–4× the reduction alone at the same node count, and the excess (PEs answering late) accounts for most of the growth in wave time from 4 to 16 nodes.
- G3. Buckets completed per wave, and waves per GVT advance, are about the same at 4 and 16 nodes.
- G4. `--gvt-wave-events=0` changes the 16-node rate by less than 10%.

### GVT round cost at 4 and 16 nodes, results (2026-10-24, batch job 3635612 on skx-dev)

> **Status: current.**

**Runs.** `$WORK/charades-runs/gvtprobe/gvtprobe.slurm`; outputs, traces and CSVs copied to `~/charades-data/gvtprobe/`; summary `probe_summary.py`. Every run finished; the two reps agree within 4%.

**A. The reduction alone** (`tools/redbench`, µs per back-to-back wave, median of 2; lower is better):

| nodes (PEs) | 1 (46) | 2 (92) | 4 (184) | 8 (368) | 16 (736) |
|---|---|---|---|---|---|
| µs per wave | 71.8 | 98.7 | 109.3 | 139.9 | 161.5 |
| PE 0's latency, median / p99 (µs) | 70 / 88 | 95 / 123 | 104 / 141–432 | 130 / 484 | 142 / 514 |

**B. Waves in Charades** (`--gvt-trace=1`; medians of 2; each row is one run's medians):

| run | M ev/s | GVT advances | waves per advance | µs per advance (mean) | wave seen by PE 0, median µs | PE 0's delay before contributing, median µs | buckets completed per wave | time in `execute()` % | batches blocked by the window % |
|---|---|---|---|---|---|---|---|---|---|
| 4 nodes, σ 100, W 250 | 121.9 | 8,342 | 1.00 | 178 | 72 | 90 | 7.7 | 60 | 94 |
| 4 nodes, σ 2,000, W 250 | 100.7 | 8,333 | 1.00 | 216 | 73 | 121 | 7.7 | 56 | 95 |
| 4 nodes, σ 2,000, W 400 | 98.1 | 7,030 | 1.00 | 262 | 160 | 51 | 9.1 | 56 | 95 |
| 16 nodes, σ 100, W 250 | 333.8 | 8,278 | 1.00 | 262 | 187 | 7 | 7.7 | 57 | 97 |
| 16 nodes, σ 100, W 400 | 408.9 | 5,781 | 1.00 | 306 | 214 | 11 | 11.1 | 62 | 95 |
| 16 nodes, σ 2,000, W 250 | 292.9 | 8,306 | 1.00 | 297 | 198 | 9 | 7.7 | 55 | 97 |
| 16 nodes, σ 2,000, W 400 | 331.6 | 5,756 | 1.00 | 379 | 243 | 17 | 11.1 | 57 | 96 |

**C.** 16 nodes, σ 2,000, W 400: `--gvt-wave-events=0` 326.4 against 331.6 M ev/s with the default 128 (0.98): no effect.

**What it says:**
- **Every GVT advance is one count wave**, completing about 7.7 buckets at W 250 at both node counts, and 95–97% of scheduler batches end blocked by the window. PEs spend 55–62% of their time in `execute()`; the rest is mostly waiting for GVT.
- **At 16 nodes, a GVT advance is the reduction's latency.** PE 0 answers each wave within 7–17 µs, then waits 187–243 µs for the result, close to the reduction alone at 16 nodes (162 µs; more under load). At 4 nodes the reduction is partly hidden: PE 0 is still finishing a batch for 90–121 µs before it contributes, and then waits only 72 µs.
- **The reduction is slow even inside one node**: 72 µs for 46 PEs in 2 processes. A spanning tree over 46 PEs is about 3 levels up and 3 down, so this is roughly 12 µs per hop through Reconverse's scheduler and messaging. It then grows by about 20 µs per doubling of nodes.
- **So the lever for scale is reduction latency in Reconverse** (or a GVT path that doesn't go through a general group reduction): if a wave took 30–50 µs at 16 nodes, an advance would take roughly 100 µs instead of 260–300, and PEs that now sit blocked by the window 97% of the time would run. That estimate assumes nothing else becomes the limit.

**Predictions:**
- G1. **Wrong** on the level (72–162 µs, not 30–80); right that it grows by at most 2× from 4 to 16 nodes (1.48×).
- G2. **Wrong.** At 16 nodes a wave is 1.2–1.5× the reduction alone, and PE 0 answers at once; the growth is the reduction, not PEs answering late. At 4 nodes PE 0's late answer (90–121 µs) is as large as the wave.
- G3. Right: one wave per advance and 7.7 buckets per wave at W 250 at both node counts.
- G4. Right: 0.98.

### Where a reduction's time goes, one node (2026-10-24, skx-dev batch job 3635622, plus the Mac)

> **Status: current.** No design section: a short diagnostic follow-up to "GVT round cost", run the same morning. A larger follow-up (job 3635628: reduction modes, PEs per process, 4 and 16 nodes, `perf`) never ran: the job was killed at startup (signal 53, no output) while `/work2` hung on skx-dev compute nodes (an `ssh node hostname` to a fresh allocation also hung).

**Runs.** `tools/redbench` gained a ping-pong mode (`-p PEER`: round trips of a one-int group message between PE 0 and PE PEER) and reduction modes (`-m`: 0 the GVT's tuple, 1 one int, 2 the 16-int array). `$WORK/charades-runs/gvtprobe/hop.slurm`; copied to `~/charades-data/gvtprobe/hop/`. One skx node, psm2, `+lci_ndevices 16`; 2 reps, which agree within 4% except one noted. The first launch of the job (one process, rep 1) stalled at startup for 120 s; its rep 2 ran normally.

**Message hops** (round trip, µs, mean of 100,000; lower is better):

| | round trip |
|---|---|
| 1 process × 23 PEs, PE 0 ↔ PE 1 | 2.11 |
| 2 processes × 23 PEs, PE 0 ↔ PE 1 (same process) | 2.96–3.02 |
| same, `+backend_poll_thread 23` (one network poller per process) | 2.75–2.86 |
| same, `+backend_poll_freq 1` | 2.59–2.63 |
| same, `+lci_ndevices 1` | 3.12–3.23 |
| 2 processes, PE 0 ↔ PE 23 (other process, same node) | 9.18–9.19 (median 7.63) |

**Reductions shaped like a GVT count wave** (µs per wave; lower is better):

| | µs per wave |
|---|---|
| 2 processes × 1 PE | 7.1–7.2 |
| 1 process × 23 PEs | 26.5–26.9 |
| 2 processes × 23 PEs | 71.0–71.4 |
| same, `+backend_poll_thread 23` | 72.3, 79.7 |
| same, `+backend_poll_freq 1` | 71.0–72.4 |

On the Mac (one process, 8 PEs): the GVT's tuple 7.9 µs per wave, one int 5.1, the 16-int array without a tuple 5.3. On the Mac with 2 processes everything is slow (a same-process round trip 27 µs against 0.6 with one process): every PE's loop spends about half its time in libfabric tcp's `kevent` progress call; that is the Mac's tcp provider, not what Stampede3's psm2 does.

**What it says:**
- **Message hops are cheap on Stampede3**: about 1.5 µs within a process and 4–5 µs between the two processes of a node; network polling settings change neither.
- **The reduction's cost is its shape.** Charm++'s group reduction (`CkReductionMgr::init_TopoTree`) is flat within a process: every PE but the first sends its contribution straight to the process's first PE, which receives and combines 22 messages one after another. The result comes back through Reconverse's `CmiForwardMsgToPeers`, also flat: the first PE allocates and sends one copy per local PE (22 `CmiAlloc` + `memcpy` + push; its own comment: "FIXME: now it's just a flat p2p send!! When node size is large, it should also be sent in a tree"). That is about 44 serial message operations on one PE per wave per process, about 1.2 µs each: 26.5 µs for one process of 23 PEs.
- **Two processes cost far more than one plus a hop** (71 µs against 26.5 + 7). Not yet explained; the profile that would have shown it is in the job that did not run.
- In Charades the first PE of each process is also executing events, so its 44 operations per wave wait behind its batches.
- **The GVT's tuple adds about half on top of a plain sum** (Mac, 8 PEs), which Charades can avoid on its own.

**Fixes, in order of reach:** (1) Charades: combine each process's counts in shared memory (atomic adds into a per-process buffer; the last PE in contributes once per process) and publish the result through shared memory, so the cross-process reduction has 2 members per node instead of 46 and no PE handles 44 messages per wave; drop the tuple. (2) Reconverse: a tree for the local fan-out (the FIXME), and a node-aware local fan-in in Charm++'s reduction manager. (1) needs no runtime change.

### GVT count waves combined per process, `--gvt-node-waves` (design, 2026-10-24; written before any code or runs)

> **Status: design.** Written before any code or runs.

**Why.** At 16 nodes a GVT advance is one count wave and takes about as long as the reduction under it ("GVT round cost"), and that reduction is slow because of its shape ("Where a reduction's time goes"): each process's first PE receives and combines 22 contributions, then allocates and sends 22 copies of the result, one after another, and the GVT's tuple message adds about half again. Charades can avoid all of it without runtime changes, the way `--agg-input-buffer` already avoids per-PE htram messages.

**Design** (`--gvt-node-waves=1`; bucketed GVT only; off under `--sched-park`, like `--agg-input-buffer`, since parked PEs do not poll):
1. **Contribute into shared memory.** A new nodegroup `NodeWaves` holds, per process, one slot per PE and an arrival counter. A PE's wave contribution (sent and received counts for the buckets asked, buckets passed, and the controller's counters and histogram when it sends them) becomes one flat array of 64-bit integers written to its own slot; it then increments the arrival counter.
2. **The last PE in combines.** The PE that brings the counter to the process's PE count sums the slots (minimum for buckets passed), resets the counter, and hands the combined array to its process's `NodeWaves` branch (one local message), which contributes it to a nodegroup reduction.
3. **No tuple.** The cross-process reduction uses one custom reducer over the flat array (sum everywhere except one minimum), registered at startup like the statistics reducer.
4. **The result comes back once per process** (a nodegroup broadcast). The handler copies it into the process's shared result and bumps a generation counter.
5. **PEs pick it up where they already look for work**: at the top of `execute()`, next to the htram input buffer drain, a PE that is waiting on a wave checks the generation counter and, if it moved, runs the existing `check_counts` logic on the shared result. That logic is unchanged, so every PE still makes the same decision from the same sums.
- Correctness: a PE contributes to wave k+1 only after it has read wave k's result, as now (Mattern's four-counter rule needs exactly that); the slots and the result buffer are reused safely because no PE can contribute to wave k+1, or a result k+1 exist, before every PE of the process has read result k. Committed counts must equal the message path's.
- The start reduction (once per run) is unchanged.

**Gate.** Mac: `test.py --tier change` and the bucketed configs with `--gvt-node-waves=1` (with and without htram, with the controller on the count waves), `--repeat 20` on two of them; committed counts equal to the message path.

**Then on Stampede3** (when `/work2` works on compute nodes again): `--gvt-trace=1` runs at 4 and 16 nodes, σ 100 and σ 2,000, W 250 and 400, both paths, 2 reps.

**Predictions:**
- N1. At 16 nodes a wave (seen by PE 0) drops from 187–243 µs to at most 80 µs, and a GVT advance from 262–379 µs to at most 130.
- N2. At 16 nodes the best fixed W gains 30–60% (σ 100 and σ 2,000), and weak-scaling efficiency at σ 2,000 rises from 0.76 to at least 0.9. At 4 nodes the gain is 5–15%, since there the wave is partly hidden behind PE 0's batches.
- N3. Committed counts are identical to the message path in every run.
- N4. With cheaper rounds, the best W at 16 nodes moves back toward 250–300.

### GVT count waves combined per process, results (2026-10-24, skx-dev batch job 3635736, 16 nodes)

> **Status: current.** Short runs (end 512,000), 2 reps; the two paths ran from the same binary (`$WORK/charades-nw`: eef0778 plus the `gvt-node-waves` change), interleaved.

**Runs.** `$WORK/charades-runs/nodewaves.slurm`; CSVs, traces and `summary.md` in `~/charades-data/nodewaves/`. All 40 measured runs finished (the job's first launch, a warm-up, hit the cap: the usual cold start). **Committed counts are identical between the two paths in every workload.**

**Results** (medians of 2; M committed events/s, higher is better; µs per GVT advance, lower is better):

| run | message path: M ev/s | µs per advance | per-process waves: M ev/s | µs per advance | gain |
|---|---|---|---|---|---|
| 4 nodes, σ 100, W 250 | 122.6 | 177 | **162.4** | 131 | 1.32 |
| 4 nodes, σ 100, W 400 | 104.6 | 235 | 141.6 | 171 | 1.35 |
| 4 nodes, σ 2,000, W 250 | 105.4 | 205 | **135.8** | 156 | 1.29 |
| 4 nodes, σ 2,000, W 400 | 99.2 | 254 | 118.3 | 213 | 1.19 |
| 16 nodes, σ 100, W 250 | 329.8 | 265 | 467.3 | 181 | 1.42 |
| 16 nodes, σ 100, W 400 | 400.4 | 308 | **469.7** | 224 | 1.17 |
| 16 nodes, σ 2,000, W 250 | 291.7 | 299 | **373.8** | 227 | 1.28 |
| 16 nodes, σ 2,000, W 400 | 315.8 | 397 | 365.0 | 311 | 1.16 |
| 16 nodes, controller, σ 100 (mean W) | 346.6 (292) | 297 | 450.7 (296) | 209 | 1.30 |
| 16 nodes, controller, σ 2,000 (mean W) | 288.9 (277) | 338 | 366.2 (275) | 252 | 1.27 |

- **Best against best: 1.29–1.32× at 4 nodes and 1.17–1.18× at 16.** At 16 nodes the best W moves back to 250 (σ 2,000) or ties 250 and 400 (σ 100), and the controller reaches 0.96 and 0.98 of the best fixed W, up from 0.86.
- A GVT advance takes 131–156 µs at 4 nodes (was 177–205) and 181–227 µs at 16 at W 250 (was 265–299). At 16 nodes most of what remains is the reduction across the 32 processes.
- **Against Devastator** (its rates from earlier jobs with the same end time, 3633769 and 3635596, so indicative only; Charades ÷ Devastator, higher is better for Charades): 4 nodes σ 100 0.96 (was 0.73), σ 2,000 1.29 (was 1.02); 16 nodes σ 100 0.71 (was 0.62), σ 2,000 0.98 (was 0.86).
- Weak-scaling efficiency from 4 to 16 nodes, each path against its own 4-node rate: σ 100 0.72, σ 2,000 0.69. It looks lower than before only because the 4-node rate rose more.

**Predictions:**
- N1. **Wrong.** At 16 nodes a wave seen by PE 0 is 116–179 µs (not ≤ 80) and an advance 181–311 µs (not ≤ 130): combining within processes removed about a third, and the cross-process reduction remains.
- N2. **Wrong both ways.** 16 nodes gain 17–18% best against best (not 30–60%); 4 nodes gain 29–32% (not 5–15%). The per-process combine matters as much at 4 nodes, where PE 0 used to spend its time handling 44 messages per wave.
- N3. Right: identical committed counts.
- N4. Right: the best W at 16 nodes is back to 250 (σ 2,000) or 250–400 (σ 100).

**Default since 2026-10-24** (user decision): `--gvt-node-waves=1`. The message path stays reachable with `=0` and is covered by the `*_msgwaves` test configs. Mac gate for the switch: every bucketed config 612/612 (quick shapes), engine tier 940/942 with the 2 non-passes caused by a second `lcrun` I started during the run, both 20/20 when rerun alone.

**What this means:** `--gvt-node-waves` is the largest single gain since psm2, and it is free of any runtime change. The cross-engine numbers in "Current numbers" (message path) understate Charades by about 1.3× at 4 nodes; the paper-grade comparison should be rerun with it on. What is left at 16 nodes is the reduction across processes (32 members, about 180–230 µs per advance), next to try: a flatter or wider tree across processes, or contributing as soon as a process is complete rather than through an entry method.

### The cross-process part of a GVT advance: allreduce by recursive doubling (design, 2026-10-24; written before any runs on Stampede3)

> **Status: design.** Written before the Stampede3 runs; the Mac numbers below are the only measurements so far.

**Why.** With `--gvt-node-waves` a run is still paced by GVT advances (95–97% of scheduler batches end blocked by the window), and an advance takes 131–156 µs at 4 nodes and 181–227 µs at 16. What is left in it: the slowest PE of each process contributing, one local message to the process's `NodeWaves` branch, Charm++'s nodegroup reduction across processes and its broadcast back, and the PEs noticing the result. The nodegroup reduction goes up a tree and back down; an allreduce by recursive doubling (in round r every process swaps its partial sums with process me XOR 2^r; after log2 P rounds every process has the total) has no separate broadcast and half the depth. On the Mac (lcrun, tcp), `tools/redbench` (new modes `-m 3`: nodegroup reduction and broadcast, one contribution per process; `-m 4`: recursive doubling) gives 19.6 against 15.5 µs per wave with 2 processes and 54.0 against 30.9 with 4.

**Design** (`--gvt-wave-allreduce=1`; with `--gvt-node-waves`; needs a power-of-two process count, else the nodegroup reduction is used):
- The last PE in a process hands the combined array to its `NodeWaves` branch as now; that branch runs the allreduce with `[exclusive]` nodegroup entry methods, buffering a partner's message that arrives a round (or a wave) early, and publishes the total exactly as the reduction result is published now. Integer sums and one minimum are exact, so every process gets the same result.
- `--gvt-trace=1` also records, for PE 0's process, when its last PE arrived and when the result was published, to split an advance into gathering, crossing processes, and pickup.

**Runs** (one skx-dev job, 16 nodes): `redbench -m 3` and `-m 4` at 1, 2, 4, 8 and 16 nodes; Charades σ 100 and σ 2,000 at W 250, 4 and 16 nodes, `--gvt-wave-allreduce` 0 and 1, traced, 2 reps.

**Predictions:**
- A1. `redbench`: recursive doubling takes at most 60% of the nodegroup reduction's time at 8 and 16 nodes.
- A2. In Charades at 16 nodes, crossing processes is at least half of an advance with the nodegroup reduction; with the allreduce an advance drops from 181–227 µs to 110–150, and throughput rises 15–35%. At 4 nodes the gain is 5–15%.
- A3. Committed counts are identical.

### The cross-process part of a GVT advance, results (2026-10-24, skx-dev batch job 3635974; benchmark also from the cancelled job 3635873)

> **Status: current.** Short runs (end 512,000), 2 reps, W 250 unless noted. Job 3635840 died at startup on a node with a hanging `/work2` (signal 53, no output); job 3635873 was cancelled when `redbench -m 4` hung, a bug in `redbench` (a partner's first message taken before the process had started the wave), fixed and rerun in 3635974, which excluded the suspect nodes. Charades' allreduce already had the guard `redbench` lacked.

**Runs.** `$WORK/charades-runs/allreduce.slurm`, `allreduce2.slurm`; copied to `~/charades-data/allreduce/`; `scripts/stampede3/advance_split.py` (new) splits each advance from the trace. All Charades runs finished; committed counts are identical between the two paths in every workload.

**The reduction across processes alone** (`redbench`, µs per wave, lower is better; nodes = physical nodes, 2 processes each):

| nodes | 1 | 2 | 4 | 8 | 16 |
|---|---|---|---|---|---|
| nodegroup reduction (`-m 3`) | 10.9 | 22.4 | 27.8 | 40.3 | 49.4–49.7 |
| recursive doubling (`-m 4`) | 5.8–6.0 | 12.6 | 20.4 | 29.5 | 40.7–42.8 |

**A GVT advance, split** (PE 0's view; µs, means over waves, medians of 2; M committed events/s):

| run | M ev/s | µs per advance | PE 0 contributes → its process combined | combined → result | result → PE 0 picks it up | picks up → contributes again |
|---|---|---|---|---|---|---|
| 4 nodes, σ 100: nodegroup / allreduce | 160.5 / 160.8 | 133 / 132 | 20 / 20 | 86 / 87 | 4 / 4 | 23 / 21 |
| 4 nodes, σ 2,000 | 133.1 / 133.5 | 159 / 159 | 40 / 41 | 93 / 90 | 5 / 6 | 20 / 22 |
| 16 nodes, σ 100 | 465.0 / 445.2 | 182 / 191 | 13 / 13 | 152 / 165 | 4 / 3 | 13 / 10 |
| 16 nodes, σ 2,000 | 373.3 / 371.4 | 227 / 228 | 23 / 26 | 185 / 183 | 5 / 4 | 14 / 14 |
| 16 nodes, controller, σ 100 | 435.2 / 423.0 | 216 / 222 | 14 / 11 | 179 / 194 | 5 / 3 | 15 / 11 |
| 16 nodes, controller, σ 2,000 | 364.4 / 373.1 | 254 / 245 | 24 / 27 | 204 / 193 | 6 / 6 | 17 / 18 |

**What it says:**
- **Crossing processes is 75–85% of an advance, but the reduction is not what takes the time.** In the runs it takes 152–204 µs at 16 nodes against 41–50 µs for the same reduction alone, and 86–93 µs against about 25 at 4 nodes. The rest is waiting for the slowest process to finish gathering its own PEs; the allreduce cannot shorten that, and it changes throughput by 0.96–1.02.
- PE 0's own process gathers in 13–41 µs and picks the result up in 3–6 µs, so the slow processes are elsewhere; what holds a process back is not yet measured. Candidates: a PE busy in a 16-event batch when the result arrives, and a PE holding its contribution until it has run 128 events (`--gvt-wave-events`).

**Predictions:**
- A1. **Wrong.** Recursive doubling is 0.73 (8 nodes) and 0.84 (16) of the nodegroup reduction, not ≤ 0.6.
- A2. Crossing is more than half of an advance (right), but the allreduce does not shorten it (**wrong**): no throughput gain at 4 or 16 nodes.
- A3. Right: identical committed counts.

**Decision:** `--gvt-wave-allreduce` stays as an option, off. Next: what makes a process late, tried first with existing settings (`--gvt-wave-events=0`; `--batch` 4 and 8), traced, at 4 and 16 nodes.

### What makes a process late to a count wave: batch size and wave holding (design, 2026-10-24; written before any runs)

> **Status: design.** Written before any runs.

**Why.** Crossing processes takes 152–204 µs of a 16-node advance while the reduction itself takes about 50 ("The cross-process part of a GVT advance, results"): the wave waits for the slowest process to gather its PEs. A PE runs a wave's result and contributes to the next only between scheduler batches (16 events by default), and it holds its contribution until it has run 128 events since its last one unless it ran out of work (`--gvt-wave-events`).

**Runs** (one skx-dev job, 16 nodes, excluding the nodes suspected of the `/work2` hang): σ 100 and σ 2,000, W 250, `--gvt-trace=1`, 4 and 16 nodes, 2 reps; arms: default (batch 16, wave events 128); `--gvt-wave-events=0`; `--batch 8`; `--batch 4`; `--batch 4 --gvt-wave-events=0`.

**Predictions:**
- K1. If late PEs are what the wave waits for, `--batch 4` cuts the combined → result time at 16 nodes by at least 30% and raises throughput by at least 10%; the extra scheduler passes cost at most 5% at 4 nodes.
- K2. `--gvt-wave-events=0` alone changes throughput by less than 5%.

### What makes a process late to a count wave, results (2026-10-24, skx-dev batch job 3636110)

> **Status: current.** Short runs (end 512,000), W 250, 2 reps. The first submission (3636097) died at startup like 3635628 and 3635840 (signal 53, no output), on nodes that had run fine an hour before, so the `/work2` hang is not tied to particular nodes; this job wrote its own output to `$SCRATCH` and started at once. Two runs hit the cap (the warm-up launch and one 4-node default run, whose rep 2 stands in).

**Runs.** `$WORK/charades-runs/late2.slurm`; copied to `~/charades-data/late/`. Committed counts are identical across arms.

**Throughput and advances** (M committed events/s, medians of 2, higher is better; µs per GVT advance):

| arm | 4 nodes σ 100 | 4 nodes σ 2,000 | 16 nodes σ 100 | 16 nodes σ 2,000 |
|---|---|---|---|---|
| default (batch 16, wave events 128) | 165.5 (128 µs) | 129.7 (164) | 458.3 (185) | 370.2 (229) |
| `--gvt-wave-events=0` | 164.7 (80) | **137.1** (111) | **466.6** (152) | **381.6** (185) |
| `--batch 8` | 155.3 (136) | 127.3 (166) | 447.7 (188) | 361.7 (233) |
| `--batch 4` | 145.8 (145) | 121.7 (174) | 428.6 (196) | 335.6 (251) |
| `--batch 4 --gvt-wave-events=0` | 129.4 (54) | 114.2 (78) | 409.0 (123) | 357.4 (157) |

**What it says:**
- **Faster waves do not make the run faster.** Contributing at once (`--gvt-wave-events=0`) cuts the time per advance by 18–38%, but the run then needs 20–60% more advances (16 nodes σ 2,000: 8,543 → 10,213; 4 nodes σ 100: 8,350 → 13,649), each moving GVT less: throughput changes by −0.5% to +6%.
- **The slowest PE sets the pace.** In every arm PE 0 leads GVT by the whole window (250), while the buckets every PE has passed reach only about 22 past GVT (about 180 of simulated time): one PE lags the rest by about 70, and GVT cannot pass it. Each wave completes about 7.5 buckets in every default arm, at 4 and 16 nodes alike.
- Smaller batches cost more than they save (more scheduler passes): 0.88–0.98.
- So from here, cheaper GVT advances buy little at W 250. What makes the slowest PE slow is the open question: more events in its range, events reaching it late, or its core doing other work (htram's node-level receives and `NodeWaves` combining run on whichever PE takes them).

**Predictions:**
- K1. **Wrong.** `--batch 4` is slower everywhere (0.88–0.94).
- K2. Right at 16 nodes (+2–3%) and at 4 nodes σ 100 (−0.5%); just outside at 4 nodes σ 2,000 (+6%).

### Which PE is slow, and why (design, 2026-10-24; written before any runs)

> **Status: design.** Written before any runs.

**Why.** At W 250 GVT waits for the slowest PE, which trails the window's edge by about 70 of simulated time while the rest sit at it ("What makes a process late", results). New option `--pe-stats=1` (charades 8a8abfa): PE 0 writes each PE's executed, committed and rolled-back events, remote sends, and how its scheduler batches ended (full, blocked by the window, out of events) to `pe_stats.csv`. A PE that is rarely blocked by the window is one the others wait for.

**Runs** (skx-dev, 16 nodes, job output on `$SCRATCH`): σ 100 and σ 2,000, W 250, 4 and 16 nodes, `--pe-stats=1 --gvt-trace=1`, 2 reps.

**Predictions:**
- S1. The PEs least often blocked by the window are the first PE of each process (rank 0), which also runs htram's node-level receives and the `NodeWaves` combine.
- S2. Executed events per PE vary by at most 5% around the mean: load imbalance is not the cause.

### Which PE is slow, and why, results (2026-10-24, skx-dev batch job 3636151)

> **Status: current.** Short runs (end 512,000), W 250, 2 reps, all 8 finished; `scripts/stampede3/pe_summary.py`; data `~/charades-data/pestats/`.

| run | executed per PE: max ÷ mean, min ÷ mean | window-blocked batches per PE: mean, least | rank 0 vs other ranks (mean blocked) |
|---|---|---|---|
| 4 nodes σ 100 | 1.010, 0.990 | 330–451 K, 153–219 K | 275–357 K vs 332–456 K |
| 4 nodes σ 2,000 | 1.003, 0.997 | 524–525 K, 396–443 K | 481–484 K vs 526 K |
| 16 nodes σ 100 | 1.013, 0.988 | 937–941 K, 696–738 K | 880–886 K vs 939–943 K |
| 16 nodes σ 2,000 | 1.004–1.005, 0.996 | 1,170–1,244 K, 1,015–1,061 K | 1,128–1,196 K vs 1,172–1,246 K |

- **S2 right:** events are balanced to ±1.3%.
- **S1 right in tendency, but it is not the explanation.** Rank 0 (the first PE of each process) is blocked by the window 4–21% less often than other ranks, and most of the ten least-blocked PEs are rank 0; but even the least-blocked PE is blocked hundreds of thousands of times. No PE is busy while the others wait.
- So the lag of the slowest PE's position behind the window's edge (about 70 of simulated time) is not a slow core. The traces say each wave completes about half the buckets it asks about because their sent and received totals do not yet match: events sent into them have not arrived. One candidate is htram PP's per-node buffer, which goes out only when it fills (512 items) or on a full flush, not when a due event is in it.

### Do htram's buffers hold GVT back at scale? (design, 2026-10-24; written before any runs)

> **Status: design.** Written before any runs.

**Runs** (skx-dev, 16 nodes, output on `$SCRATCH`): σ 100 and σ 2,000, W 250, 4 and 16 nodes, `--gvt-trace=1`, 2 reps; aggregation PP 512 (default), PP 128, PP 64, WPs 512, direct sends.

**Predictions:**
- H1. Buckets completed per wave rise from about 7.5 with PP 512 to at least 10 with WPs 512 or direct sends.
- H2. At 16 nodes, smaller PP buffers or WPs beat PP 512 by at least 10% at σ 2,000; at 4 nodes PP 512 stays best.

### Do htram's buffers hold GVT back at scale?, results (2026-10-24, skx-dev batch job 3636185)

> **Status: current.** Short runs (end 512,000), W 250, 2 reps; two runs hit the cap (the warm-up launch and one 4-node PP 512 run, whose rep 2 stands in); data `~/charades-data/aggbuf/`. Committed counts are identical across arms.

| nodes, σ | PP 512 (default) | PP 128 | PP 64 | WPs 512 | direct sends |
|---|---|---|---|---|---|
| 4, σ 100: M ev/s (µs per advance) | 158.0 (135) | 157.7 (134) | 145.2 (146) | **164.5** (129) | 58.7 (367) |
| 4, σ 2,000 | **126.1** (170) | 122.0 (174) | 112.0 (189) | 111.0 (191) | 32.2 (662) |
| 16, σ 100 | 454.5 (186) | 530.0 (159) | 513.6 (164) | **566.3** (149) | 174.6 (492) |
| 16, σ 2,000 | **371.1** (228) | 329.9 (256) | 311.9 (271) | 316.8 (268) | 103.4 (825) |

**Buckets completed per wave: 7.5 in every arm, direct sends included**, with 22.4–22.9 buckets passed by every PE.

**What it says:**
- **H1 wrong: htram's buffers are not what holds GVT back.** Direct sends, which buffer nothing, complete exactly as many buckets per wave.
- **The cause is the bucketed GVT's own bookkeeping.** A wave asks about the buckets the previous result left open (valid − completed), and a bucket can complete only if every PE had passed it at the previous wave and that wave reported its counts; so completed ≤ asked − completed last time. In steady state completed = asked ÷ 2 and asked = valid − completed, so **completed = valid ÷ 3**: 22.5 ÷ 3 = 7.5, as measured in every run since the traces began (W 400: 11.1 of about 33). GVT trails the buckets every PE has passed by about two waves by construction, which is why PEs sit blocked at the window's edge.
- H2 mixed: at 16 nodes σ 100, WPs 512 is 1.25× PP 512 and PP 128 1.17×; at σ 2,000 PP 512 stays best (PP 128 0.89, WPs 0.85). Not pursued until the GVT change below.

### Count waves that ask about every bucket up to the window (design, 2026-10-24; written before any code or runs)

> **Status: design.** Written before any code or runs.

**Change** (`--gvt-ask-ahead=A`): a wave reports counts for max(valid − completed, A) buckets (capped at the buckets left) instead of valid − completed. With A at least the window in buckets, the previous wave has always reported counts for every bucket all PEs had passed, so a bucket can complete one wave after every PE passed it and its counts match, instead of about three. Mattern's four-counter rule is unchanged: a bucket still completes only when it was passed by every PE at the previous wave and the previous wave's received total equals this wave's sent total. Cost: 2A integers per contribution instead of about 30 (A = 33 at W 250: 66).

**Gate.** Mac change tier on the bucketed configs with `--gvt-ask-ahead` set, `--repeat 20` on two; committed counts equal to the default.

**Predictions:**
- G1. Buckets completed per wave rise from 7.5 to at least 12 at W 250 (the bound is valid ÷ 2 ≈ 11 if valid stays at 22.5, more if PEs then pass further).
- G2. Throughput rises at least 1.3× at 4 and 16 nodes with htram (PP 512), since runs are paced by GVT advances; less with direct sends, which are slower per event.
- G3. With faster GVT the best W moves down.
- G4. Committed counts identical.

### Count waves that ask about every bucket up to the window, results (2026-10-24, skx-dev batch job 3636197)

> **Status: current.** Short runs (end 512,000), 2 reps, all measured runs finished (the warm-up launch hit the cap as usual); data `~/charades-data/askahead/`. Committed counts are identical with and without the option.

| nodes, σ, arm | ask-ahead off: M ev/s (buckets per wave) | `--gvt-ask-ahead=-1` | on ÷ off |
|---|---|---|---|
| 4, σ 100, W 250 | 160.0 (7.5) | 156.4 (8.4) | 0.98 |
| 4, σ 100, W 400 | 138.2 (8.5) | 129.5 (8.7) | 0.94 |
| 4, σ 100, controller | 152.8 (8.0) | 137.9 (8.3) | 0.90 |
| 4, σ 2,000, W 250 | 131.8 (7.5) | 133.1 (8.5) | 1.01 |
| 4, σ 2,000, W 400 | 113.1 (8.9) | 104.4 (9.2) | 0.92 |
| 4, σ 2,000, controller | 129.0 (7.9) | 121.3 (8.5) | 0.94 |
| 16, σ 100, W 250 | 456.2 (7.5) | 480.2 (8.7) | 1.05 |
| 16, σ 100, W 400 | 468.8 (9.4) | 451.0 (9.9) | 0.96 |
| 16, σ 100, controller | 458.3 (8.3) | 440.2 (9.1) | 0.96 |
| 16, σ 2,000, W 250 | 375.6 (7.5) | 387.6 (8.9) | 1.03 |
| 16, σ 2,000, W 400 | 357.5 (10.1) | 358.2 (11.3) | 1.00 |
| 16, σ 2,000, controller | 368.5 (8.2) | 353.6 (9.5) | 0.96 |

(Buckets per wave here = 64,000 buckets ÷ GVT advances.)

**What it says:**
- The bookkeeping cap was real (completed rises from exactly valid ÷ 3), but lifting it moves completion only from 7.5 to 8.4–8.9 buckets per wave, and throughput by −10% to +5%. Once every passed bucket can be asked about, most still do not complete in the next wave: their sent and received totals do not match yet, so events sent into them are still in transit. Why they are, at this lag, is not measured.
- **G1 wrong** (8.4–8.9, not ≥ 12); **G2 wrong** (0.90–1.05, not ≥ 1.3); G3 not tested; **G4 right** (identical counts).
- `--gvt-ask-ahead` stays as an option, off (default 0).

**Where the GVT work stands.** Combining waves per process (`--gvt-node-waves`) gained 1.17–1.32×. Everything tried after it on the GVT side (allreduce across processes, contributing at once, smaller batches, asking ahead) moves throughput by −12% to +6%. The largest gain seen since is not on the GVT side: htram WPs 512 instead of PP 512 at 16 nodes and σ 100 (1.25×; 0.85× at σ 2,000).

### Same-process events by pointer (`--local-fast-path`) (design, 2026-10-24; written before any code or runs)

> **Status: design.** Written before any code or runs.

**Why.** At σ 100, Charades takes 1.27× Devastator's cycles per committed event, and that ratio is the whole gap there (speedup 0.71–0.77 at 4 nodes; 0.71 with PP 512 at 16). The profile puts 20% of PE time in sends (9%) and htram delivery (11%: input buffer drain, `Aggregator::deliver`, `recv_remote_event`), and 97% of events at σ 100 stay in their process (128 LPs per PE, 16 per chare: 8 chares per PE, so most events go to another chare on the same PE or a neighbouring PE). Every one of them is copied into a 64 B htram item, buffered, flushed, copied out into a new message, indexed in the receiver's hash so an anti-message can find it, and removed from the hash at commit. Devastator hands a same-process event to its receiver as a pointer and cancels it by pointer.

**Change.** With `--local-fast-path=1`, an event for a chare on another PE of the same process, or on another chare of the same PE, skips htram and Charm++ messages:
- **Send.** As now up to `produce()` (GVT bucket counts, `far`, controller delay sample). The sender then pushes the message pointer onto the destination PE's input buffer: a lock-free multi-producer list per PE (one compare-and-swap per event), or a plain vector when the destination is the sender's own PE. The sender's event stays in its parent's caused-by list as now, marked sent, and keeps the message pointer as its handle.
- **Receive.** At the start of every `execute()` (beside `poll()` and `agg_drain()`), the PE takes its whole input buffer with one exchange, restores send order, and for each message does what `recv_remote_event` does (`consume()`, straggler statistics, `recv_local_event`) except the hash insert. The receiver's event is stored in the message, so the message pointer finds it.
- **Cancel.** The sender pushes a small anti-message carrying the target message pointer into the same input buffer. One sender's pushes arrive in order, so the event always arrives before its anti-message, and nothing needs indexing. The target is still alive: the receiver frees it only when it commits (its timestamp is below GVT, so its sender can no longer roll back the event that sent it) or when this anti-message arrives.
- **GVT.** Unchanged: an event is counted sent at `produce()` and received when drained, so one waiting in an input buffer is in transit, exactly as with htram's input buffers. As with `--agg-input-buffer`, only with the bucketed GVT and the optimistic scheduler, not with `--sched-park`, load balancing, or event holding (`--gvt-adaptive-buckets`); elsewhere the option is refused.
- **Same chare**: unchanged (already by pointer). **Other processes**: unchanged (htram or direct).
- Statistics: "Process Sends (fast path)" and "Process Anti Sends (fast path)", counted within Remote Sends and Anti Event Sends as before.

**Gate.** Mac change and engine tiers with new `*_fastpath` configs: committed counts equal to the expected counts, `--repeat 20` on two, multi-process and multi-PE (lcrun 2 × 4 PEs).

**Predictions** (4 and 16 nodes, PP 512, best fixed W and the controller, σ 100 and 2,000):
- F1. σ 100, 4 nodes: 1.10–1.20× (most of the 20% send and delivery time is same-process; Charades ÷ Devastator from 0.77 to about 0.9).
- F2. σ 2,000: 1.03–1.10× (more events leave the process).
- F3. Fewer htram messages per committed event (same-process items leave htram), and efficiency equal or higher (same-process events are no longer held by the deadline policy).
- F4. Committed counts identical.
- F5. At 16 nodes the gain is smaller than at 4, since runs there are paced by GVT advances rather than per-event cost.

### Same-process events by pointer, results (2026-10-24, skx-dev batch job 3636369)

> **Status: current.** Short runs (end 512,000), 2 reps (medians), htram PP 512 for events to other processes, `--gvt-node-waves` (default); data `~/charades-data/fastpath/` (`fp_summary.py`). All 48 runs finished; committed counts identical with the fast path off and on. Mac: change tier 108/108 on six new `*_fastpath` configs, engine tier 1408/1408 including `--repeat 20` of `bucket_window_fastpath` and `agg_deadline_bucket_pp_fastpath`.

| nodes, σ, arm | off: M ev/s | on: M ev/s | on ÷ off (higher is better) | µs per GVT advance, off / on (lower is better) | events per htram message, off / on | remote sends by pointer |
|---|---|---|---|---|---|---|
| 4, σ 100, W 250 | 163.1 | 165.2 | 1.01 | 129 / 128 | 203 / 38 | 97% |
| 4, σ 100, W 400 | 136.9 | 156.6 | 1.14 | 176 / 156 | 139 / 26 | 97% |
| 4, σ 100, controller | 150.2 | 165.1 | 1.10 | 151 / 136 | 192 / 35 | 97% |
| 4, σ 2,000, W 250 | 130.4 | 126.4 | 0.97 | 162 / 168 | 117 / 74 | 50% |
| 4, σ 2,000, W 400 | 116.7 | 115.1 | 0.99 | 215 / 221 | 71 / 45 | 50% |
| 4, σ 2,000, controller | 128.2 | 123.1 | 0.96 | 174 / 182 | 107 / 69 | 50% |
| 16, σ 100, W 250 | 455.3 | 540.2 | 1.19 | 186 / 157 | 193 / 39 | 97% |
| 16, σ 100, W 400 | 461.6 | 563.7 | 1.22 | 229 / 184 | 107 / 27 | 97% |
| 16, σ 100, controller | 441.9 | 541.8 | 1.23 | 213 / 173 | 185 / 37 | 97% |
| 16, σ 2,000, W 250 | 362.9 | 362.5 | 1.00 | 233 / 234 | 116 / 74 | 50% |
| 16, σ 2,000, W 400 | 361.1 | 357.5 | 0.99 | 313 / 319 | 62 / 44 | 50% |
| 16, σ 2,000, controller | 352.5 | 347.2 | 0.98 | 261 / 266 | 107 / 69 | 50% |

Best ÷ best (each arm set at its best W): 4 nodes σ 100 1.01, σ 2,000 0.97; 16 nodes σ 100 1.22, σ 2,000 1.00. The 4-node σ 2,000 drop (2–5%) is in both reps; at 16 nodes it is within the rep spread. Efficiency is equal or slightly higher with the fast path (99.84–99.99%). GVT advances per run are unchanged (W sets them).

**What it says:**
- **The per-event saving shows only where a GVT advance waits on work.** At 4 nodes and W 250 both arms sit at the same advance time (129 µs, the round itself), so the cheaper events buy nothing; at W 400, under the controller, and everywhere at σ 100 on 16 nodes, an advance waits for the slowest process's work, and the fast path cuts it by 10–21%.
- **σ 100 at 16 nodes: 1.19–1.23×.** Against Devastator's rates from earlier jobs with the same end time (3633769, 3635596; indicative only), Charades ÷ Devastator moves at 16 nodes from 0.71 to about 0.88 at σ 100 and stays at about 0.98 at σ 2,000; at 4 nodes about 0.97 (σ 100) and 1.25 (σ 2,000).
- **σ 2,000: no gain, 3% loss at 4 nodes.** Half the remote events still leave the process, and the advance time rises by 5–8 µs. Not yet explained; candidates: contended pushes onto input buffers (22 producers per input buffer), messages read from another core's cache instead of copied in bulk, or htram's off-process buffers filling more slowly once same-process items leave them (74 instead of 117 events per message).
- **F1 partly wrong** (best ÷ best 1.01 at 4 nodes; 1.10–1.14 only off the best W); **F2 wrong** (0.97–1.00); **F3 right** (htram carries only off-process events; efficiency equal or higher); **F4 right**; **F5 wrong**: the gain is larger at 16 nodes, where advances wait on work, not smaller.
- `--local-fast-path` stays off by default until the σ 2,000 loss is understood.

### Where the fast path loses at σ 2,000, and with WPs (design, 2026-10-24; written before any runs)

> **Status: design.** Written before any runs.

**Questions.** (1) Why the fast path costs 3% at σ 2,000 on 4 nodes, where half the remote events go by pointer. (2) Whether htram WPs 512, which was 1.25× PP 512 at 16 nodes σ 100 before the fast path, still helps now that htram carries only off-process events. (3) Charades ÷ Devastator in the same job, same end time.

**New in the code** (Mac change tier 72/72 on `*_fastpath` and `*_fastpath_pe`):
- `--local-fast-path=2`: by pointer only to other chares on the sender's own PE (no atomics); events to other PEs of the process go through htram as before.
- "Input Buffer Push Retries (fast path)": pushes that failed their compare-and-swap because another PE pushed first.

**Job** (skx-dev, 16 nodes, 2 reps, end 512,000, W 250 / W 400 / controller, σ 100 and 2,000, 4 and 16 nodes): fast path 0, 1, 2 with PP 512, and 1 with WPs 512; Devastator at W 500 and 1,000 (`--rng=clcg4`).

**Predictions:**
- P1. Mode 2 recovers the σ 2,000 loss (≥ 1.00 of off) and keeps most of the σ 100 gain at 16 nodes (≥ 1.10), i.e. the cross-PE input buffer is the cost at σ 2,000.
- P2. Push retries are below 5% of pushes, so contention is not the cause; the cost is reading messages from another core's cache.
- P3. WPs 512 with the fast path beats PP 512 with the fast path at 16 nodes σ 100 (≥ 1.05), and loses at σ 2,000 as before.
- P4. Charades ÷ Devastator at 16 nodes σ 100: 0.85–0.90.

### Where the fast path loses at σ 2,000, and with WPs, results (2026-10-24, skx-dev batch job 3636435)

> **Status: current.** Short runs (end 512,000), 2 reps (medians); data `~/charades-data/fp2/`. 94 of 96 Charades runs finished. The two that did not (fast path off, 4 nodes, σ 100, rep 1, W 250 and W 400) printed nothing before the 60 s cap: a cold start on nodes the 4-node warm-up had not touched, not the code under test (rep 2 and job 3636369 cover both). Later jobs warm every node. Committed counts identical across all four variants.

**÷ fast path off with PP 512** (higher is better):

| nodes, σ, arm | off: M ev/s | on (PP) | this PE only (PP) | on + WPs 512 | µs per GVT advance: off / on / PE only / WPs | input buffer push retries per push (on) |
|---|---|---|---|---|---|---|
| 4, σ 100, W 250 | 164.5 | 1.04 | 1.02 | 1.01 | 129 / 124 / 127 / 128 | 1.2% |
| 4, σ 100, W 400 | 137.7 | 1.15 | 1.12 | 1.19 | 175 / 154 / 157 / 148 | 1.2% |
| 4, σ 100, controller | 150.3 | 1.08 | 1.02 | 1.11 | 151 / 139 / 148 / 137 | 1.2% |
| 4, σ 2,000, W 250 | 132.7 | 0.97 | 0.98 | 0.85 | 160 / 164 / 164 / 187 | 2.8% |
| 4, σ 2,000, W 400 | 116.7 | 0.98 | 1.00 | 0.92 | 215 / 222 / 214 / 245 | 2.7% |
| 4, σ 2,000, controller | 127.3 | 0.99 | 0.99 | 0.87 | 177 / 178 / 178 / 203 | 2.8% |
| 16, σ 100, W 250 | 448.3 | 1.23 | 1.05 | 1.33 | 188 / 154 / 179 / 141 | 1.3% |
| 16, σ 100, W 400 | 448.0 | 1.29 | 1.08 | 1.35 | 236 / 179 / 220 / 170 | 1.2% |
| 16, σ 100, controller | 447.8 | 1.23 | 1.04 | 1.35 | 210 / 168 / 202 / 152 | 1.2% |
| 16, σ 2,000, W 250 | 375.2 | 0.97 | 1.01 | 0.89 | 225 / 231 / 224 / 253 | 2.9% |
| 16, σ 2,000, W 400 | 372.9 | 1.01 | 0.99 | 0.89 | 303 / 297 / 306 / 355 | 2.8% |
| 16, σ 2,000, controller | 367.5 | 0.97 | 1.00 | 0.87 | 251 / 257 / 251 / 291 | 2.9% |

**Charades ÷ Devastator, same job, same end time** (each at its best tested setting; Devastator W 500 or 1,000 with `--rng=clcg4`; higher is better for Charades):

| nodes, σ | Devastator (M ev/s) | Charades, fast path off, PP | fast path, PP | fast path, WPs |
|---|---|---|---|---|
| 4, σ 100 | 171.7 | 0.96 (164.5) | **1.00** (171.5) | 0.97 (166.2) |
| 4, σ 2,000 | 104.2 | 1.27 (132.7) | 1.24 (129.3) | 1.09 (113.3) |
| 16, σ 100 | 661.0 | 0.68 (448.3) | 0.87 (577.1) | **0.91** (604.7) |
| 16, σ 2,000 | 368.8 | 1.02 (375.2) | 1.02 (377.5) | 0.91 (334.2) |

**What it says:**
- **Contention is not the σ 2,000 cost** (P2 right): 2.8% of pushes retry. Sending by pointer only within the PE recovers σ 2,000 (0.98–1.01) but keeps only 1.04–1.08 of the 1.23–1.29 at 16 nodes σ 100 (**P1 wrong**): most of the σ 100 gain is events to other PEs of the process. The σ 2,000 loss is small (0–3%) and, with both modes near 1.00 at 16 nodes, close to the rep spread.
- **WPs with the fast path** is the best Charades at 16 nodes σ 100: 1.35× fast path off, 1.05× fast path with PP (**P3 right**), and loses 8–15% at σ 2,000 as before. The htram mode should follow locality.
- **Against Devastator** (**P4 right**): parity at 4 nodes σ 100 (1.00), ahead at σ 2,000 (1.24 at 4 nodes, 1.02 at 16), behind only at 16 nodes σ 100 (0.87 with PP, 0.91 with WPs; was 0.68).
- With PP, the fast path's best ÷ best: 1.04 (4 nodes σ 100), 0.97 (4 nodes σ 2,000), 1.29 (16 nodes σ 100), 1.01 (16 nodes σ 2,000).

### Which htram mode and buffer for which workload (fast path on) (design, 2026-10-24; written before any runs)

> **Status: design.** Written before any runs.

**Why.** With the fast path (now the default, 7df59d9), htram carries only events that leave their process. WPs 512 is 1.05× PP 512 at 16 nodes σ 100 but 0.85–0.92 at σ 2,000; before the fast path, PP 128 was 1.17× PP 512 at 16 nodes σ 100. The best setting follows locality and scale, so map it, then choose it automatically.

**Grid** (fast path on, end 512,000 high slack / 128,000 low slack, 2 reps):
- htram: PP and WPs × buffers 128, 512, 2,048 events.
- Workloads: lookahead 100 / mean 1,000 at σ 100, 500, 1,000, 2,000, 4,000 and uniform remote 1.0 (arms W 250, W 400, controller); lookahead 10 / mean 200 at σ 500 and 2,000 (arms W 50, W 100, controller).
- 4 nodes (skx, batch) and 16 nodes (skx-dev, batch), run as two jobs at once. Each starts with a warm-up launch on every node.
- Devastator in the same jobs, `--rng=clcg4`, W 500 and 1,000 (high slack), W 100, 200, 400 (low slack).

**Predictions:**
- S1. WPs beats PP (each at its best buffer) at 16 nodes for σ ≤ 500, PP wins for σ ≥ 2,000; at 4 nodes PP is best or tied everywhere.
- S2. The best buffer shrinks with locality: 128 at σ 100–500 on 16 nodes, 512 or 2,048 for σ ≥ 2,000 and uniform.
- S3. The best (mode, buffer) beats PP 512 by ≥ 5% in at least 4 of the 16 (workload, nodes) cells and by ≤ 2% elsewhere.
- S4. A rule on the share of events that leave the process (known from σ, LPs per process and the mapping) picks a setting within 3% of the best in every cell.

### Which htram mode and buffer for which workload, results (2026-10-24/25; 16 nodes: skx-dev batch job 3636522; 4 nodes: skx-dev batch job 3638303)

> **Status: current.** The 4-node job (resubmitted to skx-dev after waiting on skx; the skx copy 3636758 was cancelled unstarted) also ran W 600 (lookahead 100) and W 200 (lookahead 10); its 384 runs all finished. Short runs, 2 reps (medians), fast path on (default); data `~/charades-data/hsel/` (`hsel_summary.py n16`). All 288 measured runs finished (both warm-up launches hit the cap, as intended). Committed counts identical across all six htram settings in every workload. Both engines ran slower in this allocation than in job 3636435 (Charades PP 512 σ 100: 545 against 577; Devastator: 582 against 661), so engines are compared only within a job.

**16 nodes, each setting at its best arm, ÷ PP 512** (higher is better):

| workload | PP 512 (M ev/s) | PP 128 | PP 2,048 | WPs 128 | WPs 512 | WPs 2,048 | best (arm) | best ÷ PP 512 | Devastator best (M ev/s) | Charades best ÷ Devastator |
|---|---|---|---|---|---|---|---|---|---|---|
| lookahead 100, σ 100 | 545.4 | 0.99 | **1.09** | 1.04 | 1.05 | 1.06 | PP 2,048 (W 250) | 1.09 | 581.8 | 1.02 |
| σ 500 | 499.8 | 0.95 | **1.07** | 0.99 | 1.01 | 1.01 | PP 2,048 (controller) | 1.07 | 506.9 | 1.06 |
| σ 1,000 | 456.8 | 0.97 | **1.08** | 0.96 | 0.97 | 1.00 | PP 2,048 (controller) | 1.08 | 433.0 | 1.14 |
| σ 2,000 | 355.8 | 0.93 | 0.70 | 0.89 | 0.93 | 0.93 | PP 512 (W 400) | 1.00 | 366.0 | 0.97 |
| σ 4,000 | 297.3 | 0.96 | 0.71 | 0.88 | 0.88 | 0.88 | PP 512 (W 400) | 1.00 | 289.5 | 1.03 |
| uniform remote 1.0 | 161.4 | 0.99 | 0.94 | **1.12** | 1.11 | 1.09 | WPs 128 (W 400) | 1.12 | 192.0 | 0.94 |
| lookahead 10, σ 500 | 396.8 | 1.01 | **1.08** | 1.02 | 1.06 | 1.07 | PP 2,048 (W 50) | 1.08 | 498.1 | 0.86 |
| lookahead 10, σ 2,000 | 268.6 | 0.96 | 0.93 | 0.99 | 0.98 | 0.99 | PP 512 (W 100) | 1.00 | 348.7 | 0.77 |

**What it says (16 nodes):**
- **PP 2,048 wins wherever most events stay in the process** (σ ≤ 1,000, both slack levels: 1.07–1.09×) and **collapses at σ ≥ 2,000** (0.70): efficiency falls to 95–98.6% (W 400: 95.3%), since its larger per-process buffers fill rarely and events wait until they arrive late, while messages carry no more events than with 512 (75 against 74).
- **WPs wins only with uniform traffic** (1.09–1.12×), where every htram message is small anyway (12–15 events with 31 destination processes).
- **S1 wrong** (PP, not WPs, is best at σ ≤ 500; WPs wins only uniform); **S2 wrong** (the best buffer grows with locality: 2,048 at σ ≤ 1,000, 512 at σ ≥ 2,000); **S3 right at 16 nodes** (≥ 5% in 5 of 8 workloads, 0% in the other 3).
- **Against Devastator (same job):** ahead or level at σ 100 to 4,000 (0.97–1.14); behind with uniform traffic (0.94, but every Charades setting was best at W 400, the largest tested; an earlier sweep put uniform's best near 600) and at lookahead 10 (0.86 at σ 500, 0.77 at σ 2,000; there too the best arm was the largest W tested for σ 2,000, W 100, while Devastator's best was W 200).
- Next for these runs: the W grid must reach 600 (uniform) and 200 (lookahead 10) at 16 nodes before those two gaps can be read (at 4 nodes neither wider W won).

**4 nodes, each setting at its best arm, ÷ PP 512** (higher is better):

| workload | events leaving the process | PP 512 (M ev/s) | PP 128 | PP 2,048 | WPs 128 | WPs 512 | WPs 2,048 | best ÷ PP 512 | Devastator best (M ev/s) | Charades best ÷ Devastator |
|---|---|---|---|---|---|---|---|---|---|---|
| lookahead 100, σ 100 | 2.7% | 166.0 | 1.01 | 1.04 | 1.02 | 1.04 | **1.05** | 1.05 | 169.5 | 1.02 |
| σ 500 | 13.5% | 149.9 | 0.98 | **1.03** | 1.00 | 1.02 | **1.03** | 1.03 | 144.7 | 1.07 |
| σ 1,000 | 27% | 138.6 | 1.00 | **1.07** | 1.01 | 1.03 | 1.04 | 1.07 | 124.6 | 1.18 |
| σ 2,000 | 50% | **129.6** | 0.98 | 0.81 | 0.89 | 0.90 | 0.91 | 1.00 | 103.0 | 1.26 |
| σ 4,000 | 72% | **109.4** | 0.99 | 0.88 | 0.83 | 0.83 | 0.85 | 1.00 | 78.5 | 1.39 |
| uniform remote 1.0 | 87% | 117.0 | **1.02** | 0.99 | 0.73 | 0.72 | 0.73 | 1.02 | 68.0 | 1.76 |
| lookahead 10, σ 500 | 13.5% | 129.3 | 1.01 | 1.03 | **1.04** | **1.04** | 1.03 | 1.04 | 142.2 | 0.95 |
| lookahead 10, σ 2,000 | 50% | 92.0 | 1.00 | 1.02 | 1.00 | **1.05** | 0.99 | 1.05 | 96.6 | 1.00 |

(Events leaving the process: remote sends not handed over by pointer ÷ events executed, from the PP 512 runs; the same at 16 nodes except uniform, 97%.)

**Both scales:**
- **Large PP buffers where events stay in the process.** PP 2,048 is 1.03–1.09× PP 512 wherever at most 27% of events leave the process, and 0.70–0.88 from 50% up. Its shared per-process buffers hold events until they are due instead of filling; held events then meet the flush-versus-GVT-update race (a receiver may already have run past an event sent the moment it becomes due), which costs little when few events leave the process and a lot when half do (efficiency 95–98.6% at σ 2,000 on 16 nodes).
- **WPs where messages are small anyway.** WPs wins where PP 512's messages carry about 20 events or fewer (uniform on 16 nodes: 15; lookahead 10, σ 2,000 on 4 nodes: 20) and loses badly where they are large (uniform on 4 nodes: 114 events per message, WPs 0.72).
- **A rule** on two quantities the run can measure — the share of events leaving the process (f) and PP 512's events per htram message (m): PP 2,048 if f ≤ 0.3; else WPs 512 if m < 25; else PP 512. In all 16 cells it is within 2% of the best tested setting (lowest: 0.98, lookahead 10 σ 2,000 at 16 nodes), against PP 512's 0.89–1.00. The f threshold sits between two measured points (0.27, where PP 2,048 wins, and 0.50, where it loses badly), so it is the least certain part.
- **Against Devastator** (same jobs): at 4 nodes Charades is ahead or level in 7 of 8 workloads (1.00–1.76; 0.95 at lookahead 10 σ 500); at 16 nodes in 5 of 8 (0.97–1.14 at lookahead 100, σ 100–4,000; behind with uniform traffic, 0.94, and at lookahead 10, 0.86 and 0.77).
- **S1 wrong** (WPs is not the low-σ winner at 16 nodes; the mode follows message size, not locality); **S2 wrong** (the best buffer grows with locality); **S3 right** (≥ 5% in 8 of 16 cells, under 5% in the rest); **S4 right in form** (a two-quantity rule is within 2% everywhere), but measured, not yet run as an automatic choice.


### The 16-node gaps with wider windows (uniform, lookahead 10) (design, 2026-10-25; written before any runs)

> **Status: design.** Written before any runs.

**Why.** At 16 nodes Charades trails Devastator with uniform traffic (0.94) and at lookahead 10 / mean 200 (0.86 at σ 500, 0.77 at σ 2,000), but in both its best arm was the widest window tested (W 400; W 100 at σ 2,000), while Devastator's best was W 1,000 and W 200. Are these gaps real?

**Job** (skx-dev, 16 nodes, 2 reps, fast path on, short runs, each node warmed first):
- Uniform remote 1.0 (lookahead 100 / mean 1,000): W 400, 600, 800, 1,000 and the controller; PP 512 and WPs 512. Devastator W 500, 1,000, 2,000.
- Lookahead 10 / mean 200, σ 500 and 2,000: W 50, 100, 150, 200, 300 and the controller; PP 512, PP 2,048 and WPs 512. Devastator W 100, 200, 400, 800.

**Predictions:**
- G1. Uniform: Charades' best W is 600–800, and Charades ÷ Devastator rises to at least 1.00.
- G2. Lookahead 10: the best W is 150–200; Charades ÷ Devastator rises to at least 0.95 at σ 500 and 0.90 at σ 2,000.
- G3. The controller reaches at least 0.90 of the best fixed W in all three workloads; if not, its bound (κ) holds W too low at 16 nodes.

### The 16-node gaps with wider windows, results (2026-10-25, skx-dev batch job 3638330)

> **Status: current.** 16 nodes, short runs, 2 reps (medians), fast path on; data `~/charades-data/gaps16/`. All 92 measured runs finished (the first warm-up launch hit the cap, as intended); committed counts identical across settings.

**Uniform remote 1.0** (lookahead 100 / mean 1,000; M committed events/s, efficiency %):

| W | PP 512 | WPs 512 | Devastator |
|---|---|---|---|
| 400 | 158.7 (99.0) | 178.2 (99.2) | — |
| 500 | — | — | 174.5 (98.0) |
| 600 | **162.9** (97.0) | **180.0** (97.0) | — |
| 800 | 146.7 (89.2) | 151.3 (87.9) | — |
| 1,000 | 120.3 (77.9) | 122.8 (75.7) | **178.3** (92.6) |
| 2,000 | — | — | 131.0 (72.7) |
| controller | 139.9 (W 279) | 160.9 (W 287) | — |

**Lookahead 10 / mean 200** (M committed events/s, efficiency %):

| W | σ 500: PP 512 | σ 500: PP 2,048 | σ 500: WPs 512 | σ 500: Devastator | σ 2,000: PP 512 | σ 2,000: WPs 512 | σ 2,000: Devastator |
|---|---|---|---|---|---|---|---|
| 50 | 373.7 (99.98) | **413.5** (99.99) | 397.4 (99.99) | — | 254.3 (99.95) | 251.1 (99.96) | — |
| 100 | 317.0 (98.96) | 289.3 (98.84) | 311.1 (98.92) | 449.8 (99.95) | 250.5 (98.36) | **255.0** (98.56) | 304.0 (99.54) |
| 150 | 208.9 (94.50) | 209.0 (94.44) | 206.7 (94.38) | — | 150.8 (89.66) | 162.0 (90.75) | — |
| 200 | 123.6 (85.85) | 125.0 (85.97) | 118.8 (85.18) | **480.0** (99.72) | 91.2 (74.05) | 120.3 (80.40) | **340.2** (96.94) |
| 300 | 121.1 (77.25) | 123.0 (77.08) | 131.2 (78.50) | — | 28.5 (32.49) | 69.4 (55.33) | — |
| 400 | — | — | — | 449.8 (97.81) | — | — | 282.3 (85.90) |
| controller | 365.5 (W 51) | 405.0 (W 52) | 391.0 (W 51) | — | 246.6 (W 50) | 246.7 (W 51) | — |

**Charades best ÷ Devastator best** (higher is better): uniform **1.01** (WPs 512, W 600; was 0.94 with W ≤ 400); lookahead 10 σ 500 **0.86**, σ 2,000 **0.75** (unchanged).

**What it says:**
- **Uniform: the gap was the window grid** (**G1 right**): best W 600, and WPs 512 beats PP 512 by 1.10×, as the rule says (15 events per PP message). The controller stops at W 279–287 (κ bound), 0.89 of the best fixed W with WPs (**G3 wrong** here).
- **Lookahead 10: the gap is real** (**G2 wrong**): wider W makes Charades much worse, not better. At the same W, Charades rolls back far more than Devastator: W 200 at σ 500 runs at 85.9% efficiency against Devastator's 99.7%; at σ 2,000, 74% against 97%. The controller is right to sit at W 50 (0.97–0.98 of the best fixed W, **G3 right** at lookahead 10).
- **Likely cause: the rollback unit.** Devastator rolls back one LP (its PHOLD registers each LP as its own rollback domain); Charades rolls back a whole chare, 16 LPs here, so a straggler undoes every later event of 16 LPs. When stragglers are rare (lookahead 100) this costs little; at lookahead 10 it multiplies the waste and caps W. Test: fewer LPs per chare, which the fast path now makes cheap (events between chares on a PE no longer go through messages or htram).

### Choosing htram automatically (`--agg-auto`), and LPs per chare at lookahead 10 (design, 2026-10-25; written before any runs)

> **Status: design.** Written before any runs.

**`--agg-auto=1`** (branch `agg-auto`, 9fe32b3): the run starts on PP with `--agg-buffer`. After `--agg-auto-advances` GVT advances (default 128), every PE adds to one reduction the events that left its process, all its sends, and PP's items and messages; every PE applies the same choice from the sums: PP with `--agg-auto-buffer` (2,048) if at most `--agg-auto-share` (0.3) of events leave their process; else WPs 512 if PP messages carry fewer than `--agg-auto-msg` (25) events; else stay. PP resizes live (it never fills the per-PE buffers `setBufferSize` rebuilds, and its shared buffers are allocated at htram's largest size); WPs is a second htram instance made at startup, and flushes, input buffer drains and statistics cover both, so what PP still holds goes out. Mac: forced configs `agg_auto_bigpp`, `agg_auto_wps`, `agg_auto_stay` (decision after 4 advances) 20 repeats each at 1 × 4 and 2 × 2 PEs, all three choices exercised, 1,200/1,200; engine tier with 10 repeats of `agg_deadline_bucket_pp` and `agg_auto_wps` 1,490/1,490.

**LPs per chare.** Charades rolls back a whole chare per straggler. On the Mac (1 process × 8 PEs, lookahead 10 / mean 200, σ 500), efficiency at W 100 rises from 62.8% (16 LPs per chare) to 82.4% (4) and 95.1% (1), but at W 50, where little rolls back, 1 LP per chare is 0.87× 16 (every scheduler pass visits every chare for cancellations, and fossil collection visits every chare per GVT advance).

**Job** (16 nodes on skx-dev, 4 nodes on skx, 2 reps, short runs, fast path on):
- All 8 workloads of section 66; PP 512, PP 2,048, WPs 512 and `--agg-auto` (from PP 512), same arms as there plus W 600 at lookahead 100.
- Lookahead 10, σ 500 and 2,000, PP 512: 4 and 1 LPs per chare at W 50, 100, 200 and the controller.

**Predictions:**
- A1. `--agg-auto` chooses what the rule says in every cell (PP 2,048 at σ ≤ 1,000 and lookahead 10 σ 500; WPs for uniform at 16 nodes and lookahead 10 σ 2,000 at 4 nodes; PP 512 elsewhere).
- A2. `--agg-auto` is within 3% of the best fixed setting in every cell, and at least PP 512's rate everywhere.
- A3. At 16 nodes, lookahead 10, fewer LPs per chare raises efficiency at W 100–200 but the best throughput stays within ±5% of 16 LPs per chare at W 50 (the scheduler's per-chare passes offset the saved rollbacks).

### Why `--agg-auto` differs from the fixed setting it chose (design, 2026-10-25; written before any runs)

> **Status: design.** Written before any runs.

**Why.** In job 3638610 (16 nodes; results to be written up with the 4-node job) `--agg-auto` chose as the rule says in every run, but its rate differs from the fixed setting it chose, both ways and consistently across reps with interleaved order: after switching live to PP 2,048 at σ 100, 0.82 of fixed PP 2,048 (505 against 613 M ev/s at W 250); staying on PP 512 at σ 2,000, 1.07 of fixed PP 512 (394 against 368). htram's message counts and GVT advances match the fixed runs; time per GVT advance does not (σ 100: 164 against 135 µs). What `--agg-auto` adds besides the decision is a second, idle htram instance (WPs) that every PE flushes and drains on every pass. On the Mac (2 × 4 PEs, σ 2,000) the second instance changes nothing (2.49–2.56 against 2.54–2.63 M ev/s).

**Job** (16 nodes, skx-dev; σ 100 and 2,000, W 250, 3 reps, variants in shuffled order each rep): A fixed PP 512; B fixed PP 2,048; C `--agg-auto` from PP 512 that never decides (`--agg-auto-advances` 10⁹); D the same from PP 2,048; E `--agg-auto` from PP 512 deciding as usual.

**Predictions:**
- I1. C = A and D = B within 3%: the second instance is not the cause.
- I2. E at σ 100 below B by more than 5%: the live switch leaves PP slower than starting at 2,048, through something not yet identified.

### Why `--agg-auto` differs, results: an idle htram instance changes the pace of blocked passes (2026-10-25, skx-dev batch jobs 3638610 and 3638739)

> **Status: current.** 16 nodes, short runs, fast path on, htram ce2108f (PP limit fix). Job 3638610 (`--agg-auto` against fixed settings, 8 workloads, 2 reps): all 245 runs finished, including the canary of the three cases that crashed or hung in job 3638431 before the fix; committed counts identical. Job 3638739 (isolation, σ 100 and 2,000, W 250, 3 reps in shuffled order): all 34 runs finished. Data `~/charades-data/auto3/`, `~/charades-data/iso/`.

**Earlier failures.** Job 3638371: all 60 `--agg-auto` runs aborted with "Argument parse error" (the code was not in the patch sent to Stampede3; Stampede3 now runs pushed commits). Job 3638431: every run that switched PP live from 512 to 2,048 crashed (2) or hung (11): each PE judged its process's shared PP buffers full by its own buffer size, so while PEs disagreed one sent a buffer another was still copying into. Fixed in htram ce2108f (a shared buffer's limit is fixed when it is installed; PP buffers grow but never shrink live).

**Decisions (job 3638610).** In every run `--agg-auto` chose what the rule says from what it measured over 128 GVT advances: PP 2,048 at σ 100–1,000 and lookahead 10 σ 500 (2–26% of events leaving the process); WPs for uniform and where PP messages carried under 25 events; PP 512 otherwise. **A1 right.**

**But its rate differs from the fixed setting it chose. Isolation (job 3638739; M committed events/s, medians of 3, W 250, higher is better):**

| variant | σ 100 | σ 2,000 |
|---|---|---|
| A: fixed PP 512 | 543.5 | 356.5 |
| C: A + `--agg-auto` that never decides (an idle WPs instance) | 486.6 (0.90 of A) | 415.3 (1.16 of A) |
| B: fixed PP 2,048 | 629.3 | 253.7 |
| D: B + an idle WPs instance | 539.3 (0.86 of B) | 256.0 (1.01 of B) |
| E: `--agg-auto` deciding (σ 100: PP 2,048; σ 2,000: PP 512) | 514.8 | 405.4 |

- **The idle second instance is the cause** (**I1 wrong**). It carries no event; all it adds is a flush and an input buffer check on every scheduler pass, most of which are window-blocked spins. That moves the time per GVT advance both ways: at σ 100, 157 → 174 µs (slower passes pick up GVT results later); at σ 2,000 with PP 512, 238 → 203 µs (faster). The live switch itself is not the cause (**I2 wrong**: E is within the spread of D at σ 100).
- **So blocked PEs spinning flat out slow everyone down when traffic is heavy.** At σ 2,000, half of all events cross the network, and 23 PEs per process spinning (each pass polls the network and flushes) costs the PEs doing that work more than they gain. A deliberate pause when blocked could be worth up to about 1.16× there, and costs at σ 100, so it would have to follow the traffic too.
- **Fixed in `--agg-auto`** (e4b34c5 on `agg-auto`): only the instance in use is flushed; a switch to WPs flushes PP once; the second instance's input buffer is drained only after the switch. Added `--blocked-pause-ns` (diagnostic) to measure the pause directly.

### `--agg-auto` with one active instance, and pausing blocked passes (design, 2026-10-25; written before any runs)

> **Status: design.** Written before any runs.

**Jobs** (fast path on, short runs, each starting with warm-ups on every node):
- 16 nodes (skx-dev): σ 100 and 2,000 at W 250, 3 reps, variants in shuffled order: fixed PP 512; fixed PP 2,048; `--agg-auto`; PP 512 with `--blocked-pause-ns` 250, 500, 1,000, 2,000, 4,000; PP 2,048 with 500 and 2,000.
- 4 nodes (skx): all 8 workloads with PP 512, PP 2,048, WPs 512 and `--agg-auto` (section 69's grid), plus σ 100 and 2,000 PP 512 with pauses of 500 and 2,000 ns.

**Predictions:**
- P1. `--agg-auto` is within 3% of the fixed setting it chooses in every cell (σ 100: PP 2,048; σ 2,000: PP 512).
- P2. At σ 2,000 a pause of 500–2,000 ns gives PP 512 at least 1.10× at 16 nodes; at σ 100 every pause is slower.
- P3. At 4 nodes the pause matters less (fewer, faster GVT rounds), within ±5% at both σ.

### Pausing blocked passes, results; memory layout as the cause, design (2026-10-25; skx-dev batch job 3638798; design written before the layout runs)

> **Status: current (pause results), design (layout).** 16 nodes, W 250, 3 reps in shuffled order, all 64 runs finished; data `~/charades-data/pause/`.

**Pause results** (M committed events/s, medians; ÷ the same setting without a pause; higher is better):

| setting | σ 100 | σ 2,000 |
|---|---|---|
| PP 512 | 550.6 | 365.2 |
| PP 512, pause 250 / 500 / 1,000 / 2,000 / 4,000 ns | 0.98 / 0.99 / 1.02 / 1.00 / 0.98 | 0.98 / 0.99 / 0.98 / 0.97 / 0.98 |
| PP 2,048 | 611.0 | 251.6 |
| PP 2,048, pause 500 / 2,000 ns | 1.00 / 0.99 | 1.01 / 1.00 |
| `--agg-auto` (one active instance, e4b34c5) | 503.6 (0.82 of PP 2,048, which it chose) | 391.6 (1.07 of PP 512, which it kept) |

- **P2 wrong:** pausing blocked passes changes nothing (±2%). **P1 wrong:** `--agg-auto` still differs from its choice exactly as before, although it no longer flushes or drains the idle instance. So it is not what the idle instance does on each pass but that it exists: making it allocates tens of MB per process (its node buffers are sized for htram's largest buffer) and per PE before the scheduler, the LPs and the event pools are made, so every later allocation lands elsewhere.
- **Section 71's explanation (the pace of blocked passes) is withdrawn.**

**Hypothesis: throughput depends on memory layout by up to ±15%.** Likely mechanism: false sharing between hot shared atomics, e.g. htram's PP counters (`get_idx`, `done_count`, `min_key`: packed `std::atomic` arrays, one per destination node, 16 to a cache line, written by all 23 PEs of a process). If so, earlier A/B results that changed allocation (new groups, larger structures) carry layout effects of this size.

**Layout job** (16 nodes, skx-dev, σ 100 and 2,000, W 250, 3 reps in shuffled order): PP 512 and PP 2,048 with `CHARADES_PAD_KB` 0, 1, 4, 16, 64, 1,024 and 32,768 (each PE allocates and touches that much at startup, before any group; nothing else changes).

**Predictions:**
- L1. Rates move with the pad by more than the rep spread: at least 8% between the best and worst pad in some cell.
- L2. If L1 holds, padding htram's PP atomics to a cache line each makes the rates insensitive to the pad (within 3%), at or above the best padded rate.

### Memory layout: heap pads, results; padded shared atomics, design (2026-10-25; skx-dev batch job 3638859; design written before the padded runs)

> **Status: current (pads), design (padded atomics).** 16 nodes, W 250, 3 reps in shuffled order, all 84 runs finished; data `~/charades-data/layout/`.

**Pads** (`CHARADES_PAD_KB` per PE; M committed events/s, medians; best ÷ worst pad):

| setting | 0 | 1 | 4 | 16 | 64 | 1,024 | 32,768 KB | best ÷ worst |
|---|---|---|---|---|---|---|---|---|
| σ 100, PP 512 | 528 | 521 | 519 | 516 | 518 | 528 | 534 | 1.04 |
| σ 100, PP 2,048 | 579 | 583 | 588 | 577 | 580 | 579 | 583 | 1.02 |
| σ 2,000, PP 512 | 338 | 343 | 345 | 349 | 349 | 348 | 345 | 1.03 |
| σ 2,000, PP 2,048 | 248 | 252 | 246 | 247 | 247 | 253 | 247 | 1.03 |

- **L1 wrong as tested**: 2–4%, within the rep spread. But the test was weak: every pad was a whole number of KB, so no object moved relative to its cache line (false sharing cannot change), and pads past glibc's mmap threshold (128 KB) do not move the heap at all. What it shows is that heap position as such does not matter.

**Padded build** (Charades branch `pad` 6d19d3a on top of `agg-auto`, htram branch `pdes-pad` b6d9b18 on top of `pdes`): PP's per-destination shared counters (`get_idx`, `done_count`, `min_key`, `pp_limit`) and htram's per-PE input buffers each on their own cache line; Charades' `NodeWaves::gen` (polled by every PE on every pass, and the object's last field, so sharing a line with whatever was allocated next) and `arrived` on lines of their own. Mac: 360/360 each (10 repeats).

**Job** (16 nodes, skx-dev, σ 100 and 2,000, W 250, 3 reps in shuffled order): unpadded and padded builds × {PP 512, PP 512 + idle second instance (`--agg-auto` never deciding), PP 2,048, PP 2,048 + idle second instance}.

**Predictions:**
- L2. In the padded build the idle second instance changes nothing (within 3%), and each setting runs at or above the better of its two unpadded variants.
- L3. If L2 fails, the cause is outside the structures padded (e.g. LCI or Reconverse internals), and `--agg-auto` should make its WPs instance only when chosen.

### Padded shared atomics, results; `--agg-auto` without the second instance, design (2026-10-25; skx-dev batch job 3638897; design written before the next runs)

> **Status: current (padding), design (next).** 16 nodes, W 250, 3 reps in shuffled order; 48 measured runs finished (the two warm-ups hit the cap, as intended); committed counts identical. Data `~/charades-data/layout2/`.

**M committed events/s, medians** (higher is better; "+ idle instance" = `--agg-auto` that never decides):

| setting | unpadded | padded |
|---|---|---|
| σ 100, PP 512 | 549.8 | 546.5 |
| σ 100, PP 512 + idle instance | 473.6 (0.86) | 487.2 (0.89) |
| σ 100, PP 2,048 | 604.1 | 601.0 |
| σ 100, PP 2,048 + idle instance | 548.1 (0.91) | 560.8 (0.93) |
| σ 2,000, PP 512 | 363.0 | 356.3 |
| σ 2,000, PP 512 + idle instance | 405.7 (1.12) | 400.9 (1.13) |
| σ 2,000, PP 2,048 | 252.3 | 251.0 |
| σ 2,000, PP 2,048 + idle instance | 258.7 (1.03) | 257.7 (1.03) |

- **L2 wrong.** Padding changes nothing (padded ÷ unpadded 0.98–1.02), and the idle instance moves PP just as much in the padded build. The cause is not false sharing on these atomics, not per-pass work (section 73), and not heap position (section 74). It remains unexplained; candidates left are inside the runtime (the extra groups' creation, Charm/Reconverse or LCI state, allocation inside CmiAlloc). It matters for reading results: **any change that adds a group or a large allocation can move 16-node throughput by ±10% for reasons unrelated to what it changes**, so such changes need this isolation check before their gains are trusted.
- The padding branches (Charades `pad`, htram `pdes-pad`) stay unmerged.

**`--agg-auto` without the second instance** (15dd755 on `agg-auto`): it now chooses only between PP 512 and PP 2,048 (live resize, safe since htram ce2108f); WPs needs `--agg-auto-wps=1`. That keeps the larger gain (PP 2,048: 1.03–1.11× PP 512 at σ ≤ 1,000 at both scales) and gives up WPs where it won (uniform at 16 nodes 1.10–1.16×; lookahead 10 σ 2,000 at 4 nodes 1.05×). Mac: forced configs 10 repeats each, 480/480.

**Jobs**: 16 nodes (skx-dev) and 4 nodes (skx): the 8 workloads of section 66 with PP 512, PP 2,048 and `--agg-auto`, 2 reps.

**Predictions:**
- V1. `--agg-auto` chooses PP 2,048 at σ ≤ 1,000 and lookahead 10 σ 500, and PP 512 elsewhere.
- V2. It is within 3% of the fixed setting it chose in every cell (no second instance now), so at least PP 512's rate everywhere and 1.03–1.11× it where it switches.

### `--agg-auto` without the second instance, results: the PP 2,048 gain is not aggregation (2026-10-25; skx-dev batch jobs 3638968 (16 nodes) and 3638969 (4 nodes))

> **Status: current (16 nodes).** Charades `agg-auto` 198eabd, htram ce2108f. 8 workloads × {PP 512, PP 2,048, `--agg-auto`} × windows, 2 reps; 183 runs ok, the 2 warm-ups hit the cap as intended; the canary passed; committed counts identical in every workload. Data `$WORK/charades-runs/auto5/n16/`, summary `~/charades-data/auto5/auto_summary.py` (its "choice" column is wrong; decisions below are read from each run's own log).

**M committed events/s, each setting at its best window, median of 2** (higher is better):

| workload | share leaving the process (f) | `--agg-auto` chose | PP 512 | PP 2,048 ÷ PP 512 | `--agg-auto` ÷ PP 512 | `--agg-auto` ÷ the setting it chose |
|---|---|---|---|---|---|---|
| σ 100 | 0.02–0.03 | PP 2,048 | 527.9 | 1.10 | 1.04 | 0.95 |
| σ 500 | 0.11–0.13 | PP 2,048 | 492.4 | 1.07 | 1.00 | 0.93 |
| σ 1,000 | 0.22–0.25 | PP 2,048 | 460.0 | 1.07 | 1.01 | 0.94 |
| σ 2,000 | 0.41–0.47 | PP 512 | 359.0 | 0.69 | 1.00 | 1.00 |
| σ 4,000 | 0.56–0.68 | PP 512 | 304.9 | 0.72 | 1.00 | 1.00 |
| uniform | 0.75–0.92 | PP 512 | 166.3 | 0.96 | 1.00 | 1.00 |
| lookahead 10, σ 500 | 0.11–0.13 | PP 2,048 | 391.9 | 1.07 | 1.01 | 0.95 |
| lookahead 10, σ 2,000 | 0.42–0.47 | PP 512 | 267.8 | 0.94 | 1.01 | 1.01 |

- **V1 right.** Every run decided as predicted, after 128 GVT advances (about 2% of the run).
- **V2 wrong.** Where it switches to PP 2,048 it gets 0.93–0.95 of PP 2,048, almost none of the gain.
- **Why: PP 2,048's gain at σ ≤ 1,000 does not come from aggregation.** At the same window, PP 512 and PP 2,048 send the same number of messages with the same events per message (σ 100, W 250: 499,353 vs 497,388 messages, 39.3 vs 39.5 events per message; σ 500: 73.7 vs 74.0; σ 1,000: 87.1 vs 87.5), at the same efficiency and the same GVT advance count. Every "buffer full" send at σ 100 is a PE sending its 16-event local buffer while the shared buffer is being sent (17,642 vs 14,988), not a shared buffer filling. Growing the limit live therefore changes nothing, which is what `--agg-auto` shows. What PP 2,048 changes at startup is allocation sizes (each PE's initial buffers are allocated at the buffer size), so this is most likely the startup-layout effect of section 75 (±10% at 16 nodes from groups or allocations), not a better aggregation setting. Not yet tested.
- **PP 2,048's loss at σ ≥ 2,000 is real and is a deadline-policy gap.** *(Corrected in section 137: `flushDue` does send the shared buffers; their events lose a race at the update that makes them due, and at σ 4,000 part of the loss is something else.)* At σ 2,000, W 250: events held past their due time by htram rise from 233,332 to 1,948,172 (8×), urgent sends from 1,955 to 175,108, and efficiency drops from 99.92% to 98.63% (94–95% at W 400–600), with events per message about the same (74 vs 78). With a larger limit, shared buffers that previously went out when full now wait, and `flushDue` does not send them by their deadline. PP 512 has the same gap at a smaller scale (233,332 held events at σ 2,000 against 57,475 at σ 100).
**4 nodes (job 3638969; 185 runs ok, canary passed, committed counts identical), same layout as the 16-node table:**

| workload | PP 512 (M ev/s) | PP 2,048 ÷ PP 512 | `--agg-auto` ÷ PP 512 | `--agg-auto` ÷ the setting it chose |
|---|---|---|---|---|
| σ 100 | 169.2 | 1.01 | 0.96 | 0.95 |
| σ 500 | 147.9 | 1.04 | 1.02 | 0.98 |
| σ 1,000 | 141.5 | 1.02 | 0.99 | 0.97 |
| σ 2,000 | 127.1 | 0.84 | 0.99 | 0.99 |
| σ 4,000 | 111.5 | 0.88 | 1.00 | 1.00 |
| uniform | 117.0 | 0.99 | 1.02 | 1.02 |
| lookahead 10, σ 500 | 132.4 | 1.00 | 0.97 | 0.97 |
| lookahead 10, σ 2,000 | 93.0 | 1.03 | 1.01 | 1.01 |

- Decisions are the same as at 16 nodes (PP 2,048 at σ ≤ 1,000 and lookahead 10 σ 500), read from each run's log; the summary script's choice column is wrong here too.
- At 4 nodes, PP 2,048's gain is only 1.00–1.04 (1.03–1.11 in section 66). At W 250 it sends the same events per message as PP 512 (σ 100: 38.3 vs 38.0; σ 1,000: 87.6 vs 87.7), so the gain is not aggregation here either.
- The loss at σ ≥ 2,000 is smaller than at 16 nodes but the same kind: 0.84 and 0.88, with efficiency 99.93 → 99.22% (σ 2,000) and 99.78 → 99.21% (σ 4,000), at about the same events per message.
- `--agg-auto` is 0.95–1.02 of the setting it chose; V2 (within 3%) fails only at σ 100 (0.95) and σ 1,000 (0.97, borderline).

- **Consequences.**
  - `--agg-auto` does not become the default. Its rule is right, but the gain it picks is not one a live switch can get.
  - The selection rule of section 66 (PP 2,048 where ≤ 0.3 of events leave the process) rests on a 1.03–1.11× that is probably layout, not aggregation; treat it as unexplained until the isolation test below.
  - Next (one short skx-dev job): (1) PP 2,048's allocation with PP 512's limit (start at 2,048, `pp_size` 512), against both, at σ 100 and σ 2,000; (2) find why `flushDue` misses shared buffers whose events are due, and fix it; the fix may also help PP 512 at σ ≥ 2,000.

### Weak scaling 1–16 nodes in one allocation; one process per node (design, 2026-10-25; written before any runs)

> **Status: design.** Job script `$WORK/charades-runs/scale.slurm`; output `$WORK/charades-runs/scale/j<job>/`.

**Why.** The 4→16-node efficiencies so far (Charades 0.38–0.86, Devastator 0.71–0.92) compare jobs from different allocations, which differ by up to ±0.1, and have no 1, 2 or 8-node points. One allocation gives the curve's shape and shows where Charades starts losing. The second part tests the cheapest remedy for aggregation thinning: one process per node halves the destination processes and should double events per htram message.

**Setup.** One 16-node allocation, Charades `agg-auto` 198eabd (fast path on; `--agg-auto` off), htram `pdes` ce2108f.
- N = 16, 8, 4, 2, 1 nodes (in that order, inside each rep), 2 reps; full nodes, 2 × 23 PEs per node, 128 LPs per PE, so the problem grows with N.
- The 8 workloads of section 66: lookahead 100, mean 1,000, σ 100, 500, 1,000, 2,000, 4,000 and uniform remote 1.0 (end time 512,000); lookahead 10, mean 200, σ 500 and 2,000 (end time 128,000).
- Charades: PP 512 and PP 2,048 with W 250, 400, 600 and the controller (ε 0.001); lookahead 10: W 50, 100, 200 and the controller. WPs 512 for uniform and lookahead 10 σ 2,000 (where it won in section 66).
- Devastator: W 500 and 1,000 (lookahead 100); W 100, 200, 400 (lookahead 10); clcg4. The 1, 2 and 8-node binaries are rebuilt at the start of the job from the source the 4 and 16-node ones came from (the old 1-node binary predates the phases change; kept as `.pre-scale`).
- Then at 16 nodes, 2 reps: one process of 46 PEs per node (`+pemap 2-47`) against two of 23, for σ 2,000, σ 4,000, uniform and lookahead 10 σ 2,000, PP 512 and PP 2,048.
- Last, `--comm-stats=1` at 16 nodes (σ 2,000 and uniform, PP 512, W 250 and 600): send-call time and send-to-receive latency.

**Measures.** Each engine at its best setting per (workload, N). Weak-scaling efficiency: M committed events/s per node at N ÷ the same at 4 nodes, and ÷ 1 node (higher is better; 1.0 is perfect). The 1-node point has no network traffic and the 2-node point little at σ ≤ 1,000, so ÷ 4 nodes is the main measure. Also events per htram message, GVT advances per second, and Charades' speedup (Charades ÷ Devastator).

**Predictions:**
- S1. 4→16-node efficiency in one allocation lies within ±0.1 of the cross-allocation numbers: Charades about 0.85 at σ ≤ 1,000, 0.7 at σ 2,000 and 4,000, 0.4 uniform; Devastator 0.85–0.92, uniform 0.7.
- S2. Charades loses efficiency at every doubling from 4 nodes on where traffic is spread (σ ≥ 2,000, uniform), and the loss per doubling grows; at σ ≤ 1,000 the 8→16 step costs < 10%.
- S3. Events per htram message for uniform fall about as 1 ÷ (destination processes): the 16-node value is 0.4–0.6 of the 8-node one.
- S4. Charades' speedup over Devastator falls with N on σ ≥ 2,000 and uniform: above 1 at 1–4 nodes, below 1 at 16.
- S5. One process per node doubles events per htram message (1.7–2.3×) at uniform and σ ≥ 2,000. It is 1.10–1.30× two processes per node on uniform, 1.0–1.15× on σ 2,000 and 4,000, and within 5% at lookahead 10 (GVT-bound there). The risk is contention on PP's process-wide buffers with 46 PEs sharing them.

### Weak scaling 1–16 nodes in one allocation, results: time per GVT advance, not aggregation, limits Charades (2026-10-25; skx-dev batch job 3639098)

> **Status: current.** Design and predictions in section 77. 822 Charades and 180 Devastator runs, all ok, none capped; 1:19 elapsed. Data `~/charades-data/scale/j3639098/` (CSVs and Devastator `results.txt`), summary `~/charades-data/scale/scale_summary.py`.

**M committed events/s per node, each engine at its best setting, median of 2** (higher is better; efficiency = per-node rate at 16 nodes ÷ the same at 4 or 1 node, 1.0 perfect):

| workload | engine | 1 node | 2 nodes | 4 nodes | 8 nodes | 16 nodes | 16 ÷ 4 nodes | 16 ÷ 1 node |
|---|---|---|---|---|---|---|---|---|
| σ 100 | Charades | 47.7 | 45.1 | 41.4 | 37.9 | 38.3 | 0.93 | 0.80 |
| σ 100 | Devastator | 41.7 | 42.6 | 42.6 | 42.4 | 41.7 | 0.98 | 1.00 |
| σ 500 | Charades | 41.4 | 40.4 | 38.7 | 35.7 | 34.9 | 0.90 | 0.84 |
| σ 500 | Devastator | 38.6 | 38.9 | 35.2 | 35.1 | 32.4 | 0.92 | 0.84 |
| σ 1,000 | Charades | 40.5 | 38.0 | 36.6 | 34.6 | 32.6 | 0.89 | 0.81 |
| σ 1,000 | Devastator | 37.6 | 34.4 | 30.2 | 29.6 | 25.9 | 0.86 | 0.69 |
| σ 2,000 | Charades | 38.9 | 35.7 | 31.9 | 27.7 | 22.7 | 0.71 | 0.58 |
| σ 2,000 | Devastator | 30.6 | 27.0 | 26.4 | 25.3 | 23.9 | 0.91 | 0.78 |
| σ 4,000 | Charades | 39.0 | 35.3 | 28.2 | 23.8 | 19.5 | 0.69 | 0.50 |
| σ 4,000 | Devastator | 29.5 | 21.4 | 20.2 | 20.1 | 18.8 | 0.93 | 0.64 |
| uniform | Charades | 41.6 | 36.9 | 29.7 | 16.0 | 11.9 | 0.40 | 0.29 |
| uniform | Devastator | 30.2 | 20.8 | 17.6 | 15.0 | 12.0 | 0.68 | 0.40 |
| lookahead 10, σ 500 | Charades | 37.3 | 35.5 | 33.5 | 29.0 | 27.2 | 0.81 | 0.73 |
| lookahead 10, σ 500 | Devastator | 39.0 | 39.2 | 36.7 | 32.6 | 31.9 | 0.87 | 0.82 |
| lookahead 10, σ 2,000 | Charades | 32.3 | 27.0 | 24.0 | 21.0 | 17.1 | 0.71 | 0.53 |
| lookahead 10, σ 2,000 | Devastator | 29.6 | 25.5 | 24.8 | 24.2 | 22.6 | 0.91 | 0.77 |

**Charades' speedup (Charades ÷ Devastator, each at its best; higher is better):**

| workload | 1 node | 2 nodes | 4 nodes | 8 nodes | 16 nodes |
|---|---|---|---|---|---|
| σ 100 | 1.14 | 1.06 | 0.97 | 0.89 | 0.92 |
| σ 500 | 1.07 | 1.04 | 1.10 | 1.02 | 1.08 |
| σ 1,000 | 1.08 | 1.11 | 1.21 | 1.17 | 1.26 |
| σ 2,000 | 1.27 | 1.32 | 1.21 | 1.10 | 0.95 |
| σ 4,000 | 1.32 | 1.65 | 1.40 | 1.19 | 1.04 |
| uniform | 1.38 | 1.77 | 1.69 | 1.07 | 0.99 |
| lookahead 10, σ 500 | 0.96 | 0.91 | 0.91 | 0.89 | 0.85 |
| lookahead 10, σ 2,000 | 1.09 | 1.06 | 0.97 | 0.87 | 0.76 |

**Charades at a fixed setting (PP 512; W 250, lookahead 10 W 50): µs per GVT advance, and events per htram message** (lower µs is better; efficiency 99.75–100% and about 8,500 advances in every cell, 11,400 at lookahead 10):

| workload | 1 node | 2 nodes | 4 nodes | 8 nodes | 16 nodes |
|---|---|---|---|---|---|
| σ 100 | 112 µs, 47 | 119, 37 | 129, 38 | 139, 39 | 151, 39 |
| σ 2,000 | 137, 163 | 149, 95 | 167, 74 | 195, 74 | 233, 75 |
| σ 4,000 | 137, 157 | 151, 146 | 188, 68 | 222, 61 | 286, 61 |
| uniform | 129, 148 | 145, 126 | 177, 114 | 330, 39 | 563, 15 |
| lookahead 10, σ 2,000 | 155, 26 | 184, 21 | 216, 20 | 249, 21 | 313, 21 |

**One process per node (46 PEs) ÷ two (2 × 23), 16 nodes, best window** (higher is better): σ 2,000 0.71 (PP 512) and 0.78 (PP 2,048); σ 4,000 0.73 and 0.71; uniform 0.78 and 0.87; lookahead 10 σ 2,000 0.78 and 0.80. Events per message at uniform rose 3.7× (11.6 → 42.5, PP 512), yet the rate fell.

- **S1 right.** In one allocation, 4→16-node efficiency is Charades 0.93, 0.90, 0.89, 0.71, 0.69, 0.40, 0.81, 0.71 and Devastator 0.98, 0.92, 0.86, 0.91, 0.93, 0.68, 0.87, 0.91, all within 0.1 of the cross-allocation numbers (Charades slightly better here).
- **S2 right.** For σ ≥ 2,000 and uniform, Charades loses at every doubling, and the loss per doubling grows (σ 2,000: 0.92, 0.89, 0.87, 0.82). At σ ≤ 1,000 the 8→16 step costs 0–6%.
- **S3 roughly right, slightly worse.** Uniform, PP 512, W 250: 16-node events per message ÷ 8-node = 15.1 ÷ 38.6 = 0.39 (predicted 0.4–0.6). From 4 to 8 nodes it falls further than the destination count alone predicts (114 → 39, 0.34, against 7 ÷ 15 = 0.47).
- **S4 mostly right.** Charades' speedup falls with N at σ ≥ 2,000 and uniform, from 1.27–1.77 at 1–4 nodes to 0.95–1.04 at 16 nodes. Only σ 2,000 goes clearly below 1 (σ 4,000 1.04, uniform 0.99). Charades stays ahead at 16 nodes at σ 500 (1.08) and σ 1,000 (1.26). Lookahead 10 is behind from 2–4 nodes on.
- **S5 wrong.** One process per node is 0.71–0.87 of two. It does make messages larger (uniform 3.7×), but it is slower. One 46-PE process spans both sockets, so NUMA effects on the shared buffers, the per-process GVT and the input buffers may explain it; it is not a fix on this machine as is.
- **The main finding: at Gaussian σ, Charades' scaling loss is time per GVT advance, not aggregation.** From 4 to 16 nodes at a fixed setting, events per message (σ 2,000: 74, 74, 75), efficiency and the advance count stay the same, while µs per advance grows 167 → 195 → 233 (σ 4,000: 188 → 286). Even at σ 100, where 2–3% of events leave the process, µs per advance rises 112 → 151 from 1 to 16 nodes, which is Charades' whole 0.80 there; Devastator is flat (1.00) on the same workload. Aggregation thinning is the cause only for uniform (114 → 39 → 15 events per message, 177 → 330 → 563 µs per advance).
- **Why Devastator escapes it.** Its best window grows to W 1,000 at 8–16 nodes (500 at 1–2), so each GVT advance covers 2.5–4× more simulated time than Charades' best (W 250–400). Charades cannot widen W as cheaply (rollbacks cost more, section 68).
- **Plan change.** GVT advance cost at scale moves ahead of aggregation thinning. Next: break µs per advance into its parts at 4 and 16 nodes (reduction latency vs waiting for the slowest PE vs blocked passes). Then either cut that cost or make wider windows affordable.

### Where a GVT advance's time goes at scale; PP 2,048's allocation vs its limit; the horizon margin (design, 2026-10-25; written before any runs)

> **Status: design.** Charades branch `scale-diag` (off `agg-auto`), htram `pdes` with `initPPLimit`. Job script `$WORK/charades-runs/diag.slurm`; output `$WORK/charades-runs/sdiag/j<job>/`.

**Why.** Section 78: at Gaussian σ, Charades' loss from 4 to 16 nodes is all in µs per GVT advance (σ 2,000: 167 → 233), and section 76: PP 2,048's gain at low σ is not aggregation, while its loss at σ ≥ 2,000 comes from events held past their deadline. Earlier work (memory, jobs 3635974–3636197) found that the cross-process wait is waiting for the slowest process, not the reduction, on PE 0's view only.

**New instrumentation** (off by default):
- `--gvt-trace=2`: with `--gvt-node-waves` (the default), every process writes `gvt_waves_<process>.csv`, one row per count wave, all on its own clock: when its first and its last PE contributed, the last PE's rank, and when the result was published there. Per process and wave: *work* = last contribution − previous result (how long until its slowest PE was ready), *spread* = last − first, *wait* = result − last contribution. Per wave across processes: the advance time = result − previous result (the same for every process, up to broadcast skew), the *reduction floor* = the smallest wait (the slowest process waits only for the reduction and broadcast), and the *straggler cost* = the largest work − the median work. No clocks are compared across nodes.
- `--agg-pp-limit=N` (diagnostic): PP's shared buffers are capped at N events while every buffer stays allocated at `--agg-buffer` (htram `initPPLimit`). Mac: test configs `agg_pp_limit`, `bucket_gvt_trace2`.

**Job** (16 nodes, skx-dev; PP 512, W 250, margin 8 unless noted):
- A. N = 16, 8, 4 nodes; σ 100, σ 2,000, uniform; `--gvt-trace=2 --pe-stats=1`, each against an untraced run; 3 reps.
- B. 16 nodes, σ 100 and σ 2,000: PP 512, PP 2,048, PP 2,048 capped at 512; 3 reps.
- C. 16 nodes, σ 100, 2,000, 4,000; PP 512 and PP 2,048; W 250 and 400; margins 8, 32, 64, 128 (the horizon is W + margin); 2 reps.

**Predictions:**
- A1. The trace costs ≤ 3% (traced ÷ untraced ≥ 0.97).
- A2. From 4 to 16 nodes the reduction floor grows by ≤ 30 µs (to 40–80 µs at 16 nodes), and the straggler cost grows by more: it is most of the increase in advance time at σ 2,000 and σ 100.
- A3. The slowest process changes from wave to wave (no process is the last in more than 20% of waves at 16 nodes), and within it the spread (last − first PE) is most of its work, with no fixed last rank.
- B1. At σ 100, PP 2,048 capped at 512 is within 3% of PP 2,048 (the gain is the allocation, a layout effect); at σ 2,000 it is within 3% of PP 512 (the loss follows the limit).
- C1. A larger margin cuts events held past their deadline at σ ≥ 2,000, and PP 2,048 at margin 64–128 recovers to ≥ 0.95 of PP 512 at margin 8. PP 512 gains ≤ 5% at σ ≥ 2,000; at σ 100 every margin is within 2%.

### Where a GVT advance's time goes at scale; PP 2,048's allocation vs its limit; the horizon margin, results (2026-10-25; skx-dev batch job 3639554)

> **Status: current.** Design and predictions in section 79. Charades `scale-diag` 00b1944, htram 6a5cc0c. 171 runs, all ok; canary passed (32 trace files); 15 min. Data `~/charades-data/sdiag/j3639554/` (CSVs, `gvt_waves_*.csv`, `pe_stats.csv`), summary `~/charades-data/sdiag/sdiag_summary.py`.

**A. GVT advance breakdown, PP 512, W 250** (µs, mean over waves 10%–95% of the run, median of 3 reps; lower is better):

| workload | nodes | traced ÷ untraced | advance | reduction floor | median process work | slowest process work | straggler cost (slowest − median) | spread inside the slowest process | most often slowest process (share of waves, 3 reps) |
|---|---|---|---|---|---|---|---|---|---|
| σ 100 | 4 | 0.98 | 130 | 34 | 29 | 96 | 67 | 86 | 6/6/6 (0.76) |
| σ 100 | 8 | 1.04 | 137 | 44 | 20 | 91 | 69 | 83 | 0/6/9 (0.45) |
| σ 100 | 16 | 0.98 | 158 | 50 | 13 | 106 | 93 | 99 | 22/22/22 (0.55) |
| σ 2,000 | 4 | 0.92 | 181 | 35 | 39 | 145 | 107 | 131 | 6/3/6 (0.76) |
| σ 2,000 | 8 | 1.06 | 178 | 43 | 42 | 141 | 99 | 130 | 2/6/0 (0.38) |
| σ 2,000 | 16 | 1.00 | 228 | 52 | 27 | 174 | 147 | 163 | 22/22/22 (0.46) |
| uniform | 4 | 0.99 | 182 | 30 | 66 | 152 | 86 | 138 | 0/6/6 (0.29) |
| uniform | 8 | 1.04 | 319 | 44 | 85 | 273 | 192 | 236 | 10/6/14 (0.15) |
| uniform | 16 | 1.01 | 535 | 50 | 93 | 482 | 389 | 430 | 22/13/22 (0.06) |

(Work = a process's last PE contribution − the previous result there; reduction floor = the smallest wait from last contribution to result, i.e. the slowest process's; spread = last − first PE contribution in that process.)

- **A1 right, with noise.** Traced ÷ untraced is 0.92–1.06 (median 1.00); one cell (4 nodes, σ 2,000) is below 0.97.
- **A2 right.** From 4 to 16 nodes the reduction floor grows 16–20 µs (to 50–52 µs). The rest of the growth is the straggler cost: σ 2,000 +40 µs of the +47 µs, σ 100 +26 of +28, uniform +303 of +353. The slowest process's time is mostly the spread among its own PEs (its last PE comes 86–163 µs after its first; uniform 430).
- **A3 wrong: the slowest process is not random; at 16 nodes it is one slow node.** Process 22 was slowest in 46–55% of waves in all three reps at σ 100 and σ 2,000. `pe_stats` shows why: both processes on that node (allocation index 11, **c455-081**) execute the same events as every other process (to 0.1%) but spend 4–8% more time doing it (µs per event ÷ median: process 22 1.07–1.08, process 23 1.02–1.05, every other process ≤ 1.05 and mostly ≤ 1.01), and are rarely window-blocked (0.57 of the median's blocked passes). So a node about 6% slower per event sets the pace of every advance. With a tight window (W 250), the whole job runs at the slowest node's speed; the chance of having such a node grows with the node count, which is part of the 4→16-node loss and would hit any Charades run on that node. At 4 nodes process 6 was slowest in 76% of waves without being slower per event (1.00), so there the cause is something else (not yet explained).
- **The last PE inside the slowest process is often rank 0** (σ 100: 0.70 at 4 nodes, 0.36 at 16; less at higher σ), the PE that also does process-level work (node-group entry methods, htram node receives).

**B. PP 2,048's allocation with PP 512's limit, 16 nodes, W 250** (M committed events/s, median of 3; in parentheses events per htram message, efficiency %; higher is better):

| workload | PP 512 | PP 2,048 | PP 2,048 capped at 512 | capped ÷ PP 512 | capped ÷ PP 2,048 |
|---|---|---|---|---|---|
| σ 100 | 516.5 (39.4, 99.98) | 589.7 (39.5, 99.98) | 586.7 (39.5, 99.98) | 1.14 | 0.99 |
| σ 2,000 | 339.2 (74.0, 99.93) | 246.6 (77.7, 98.66) | 378.6 (74.6, 99.93) | 1.12 | 1.54 |

- **B1 right, and it is a free 12–14%.** Allocating the buffers at 2,048 gives the gain (1.14 at σ 100, 1.12 at σ 2,000) with PP 512's messages and efficiency; the 2,048 limit gives the loss at σ 2,000. Capped is the best setting at both σ. The mechanism is unknown: in PP each PE's own `msgBuffers` (allocated at the buffer size, 32 destinations × 2,048 × ~72 B ≈ 4.7 MB per PE) are not used to send, so this is a side effect of the allocation (heap layout or the allocator's behaviour for the 1.2 MB shared buffers allocated at every send), like the unexplained ±10% of section 75. It has to be understood before it becomes a default.

**C. Horizon margin, 16 nodes** (M committed events/s, median of 2; ÷ PP 512 at margin 8 and the same W; higher is better):

| workload | W | setting | margin 8 | 32 | 64 | 128 |
|---|---|---|---|---|---|---|
| σ 100 | 250 | PP 512 | 527.3 (1.00) | 528.1 (1.00) | 510.9 (0.97) | 455.2 (0.86) |
| σ 100 | 250 | PP 2,048 | 577.5 (1.10) | 564.3 (1.07) | 485.4 (0.92) | 498.2 (0.94) |
| σ 100 | 400 | PP 512 | 538.2 (1.00) | 530.1 (0.99) | 512.1 (0.95) | 472.6 (0.88) |
| σ 100 | 400 | PP 2,048 | 531.0 (0.99) | 558.0 (1.04) | 547.0 (1.02) | 487.2 (0.91) |
| σ 2,000 | 250 | PP 512 | 343.2 (1.00) | 334.6 (0.97) | 279.9 (0.82) | 224.9 (0.66) |
| σ 2,000 | 250 | PP 2,048 | 245.5 (0.72) | 388.5 (1.13) | 299.5 (0.87) | 214.1 (0.62) |
| σ 2,000 | 400 | PP 512 | 346.5 (1.00) | 326.4 (0.94) | 296.9 (0.86) | 256.4 (0.74) |
| σ 2,000 | 400 | PP 2,048 | 239.8 (0.69) | 257.9 (0.74) | 263.8 (0.76) | 234.0 (0.68) |
| σ 4,000 | 250 | PP 512 | 295.4 (1.00) | 270.1 (0.91) | 228.0 (0.77) | 192.3 (0.65) |
| σ 4,000 | 250 | PP 2,048 | 206.9 (0.70) | 220.9 (0.75) | 196.9 (0.67) | 177.7 (0.60) |
| σ 4,000 | 400 | PP 512 | 293.2 (1.00) | 283.5 (0.97) | 252.6 (0.86) | 204.6 (0.70) |
| σ 4,000 | 400 | PP 2,048 | 211.2 (0.72) | 225.2 (0.77) | 224.2 (0.76) | 195.3 (0.67) |

- **C1 mostly wrong.** A larger margin does remove the late events (efficiency 98.7 → 99.95–100% at σ 2,000), but it sends events sooner and messages shrink (σ 2,000, W 250: 74 → 61 → 36 → 12 events per message), which costs more than the rollbacks it saves: PP 512 loses 3–35% at σ ≥ 2,000 and up to 14% at σ 100. PP 2,048 recovers only in one cell (σ 2,000, W 250, margin 32: 1.13, which is about the allocation gain of B). **Margin 8 stays the default**; the PP 2,048 lateness is better fixed by the cap (B) than by sending early.

**Consequences.**
- The 4→16-node loss at Gaussian σ splits into a growing reduction floor (+16–20 µs per advance) and a growing straggler cost (+26–40 µs), and here much of the straggler cost was one node ~6% slower per event. Next: (1) find the allocation mechanism behind B (allocator settings such as `MALLOC_MMAP_THRESHOLD_`/`MALLOC_TOP_PAD_` on PP 512, against the capped setting; and whether htram's 1.2 MB per-send shared-buffer allocation is the cause), then make the winner the default; (2) make Charades tolerate a slow PE or node: a window that lets processes drift further apart (Devastator's W 1,000 does this), or less work on rank 0; (3) check whether c455-081 is slow on its own (a single-node benchmark) before treating "slow node" as a general effect.

### The allocator behind `--agg-pp-limit`'s gain; the slow node in both engines; where a wider window's cost goes (design, 2026-10-25; written before any runs)

> **Status: design.** Same build as section 80 (Charades `scale-diag`, htram 6a5cc0c). Job script `$WORK/charades-runs/diag2.slurm`, submitted with `-w c455-081` so the slow node is in the allocation; output `$WORK/charades-runs/sdiag2/j<job>/`. Devastator's `run_phold.sh` gained `SRUN_EXTRA` (extra srun options, used for `-x <node>`); a 15-node binary (p30w23) is built at the start of the job.

**Parts** (16 nodes, PP 512, W 250 unless noted):
- N. One-node speed of each of the 16 nodes: Charades on one node at a time (`srun -w`), σ 100 and σ 2,000, 2 reps.
- M. glibc allocator settings on PP 512, σ 100 and σ 2,000, 3 reps: none; `MALLOC_MMAP_THRESHOLD_=16 MB` (fixed, so htram's ~1.2 MB shared buffers, allocated at every send, come from the heap instead of mmap/munmap); `MALLOC_TOP_PAD_=256 MB` (the heap grows in large steps); both with `MALLOC_TRIM_THRESHOLD_=1 GB`. Against PP 2,048 capped at 512, with and without the mmap setting.
- S. Both engines on 15 nodes, without c455-081 and with it (another node left out instead), σ 100 and σ 2,000; Charades W 250 and 400, Devastator W 500 and 1,000; 3 reps, alternating.
- W. Per-process wave traces (`--gvt-trace=2 --pe-stats=1`) at W 250, 400, 600, σ 100 and σ 2,000, 2 reps.

**Predictions:**
- N1. c455-081 is 4–8% slower than the median node on one node, and no other node is more than 3% slower.
- M1. One allocator setting brings PP 512 to within 3% of the capped setting, and adds ≤ 2% on top of the capped setting (the same mechanism). If neither does, the cause is heap layout rather than allocation churn.
- S1. Leaving out the slow node speeds Charades up by 4–10% and Devastator by 0–5%. Every engine pays up to the slow node's own slowdown; Charades pays more because its window leaves the slowest PEs little room.
- W1. From W 400 to W 600 at σ 100, throughput falls ≥ 10%, and more than half of that is longer advances (µs per advance) rather than more advances or the time to re-execute rolled-back events: rollbacks hold the GVT back.

### The allocator, the slow node in both engines, a wider window's cost, results: c455-081 is slow only with the network, and it hurts Devastator more (2026-10-25; skx-dev batch job 3639812)

> **Status: current.** Design and predictions in section 81. 132 Charades and 24 Devastator runs, all ok; the 15-node Devastator binary built; 12 min. Data `~/charades-data/sdiag/j3639812/`, summary `~/charades-data/sdiag/sdiag2_summary.py`. Allocation: c454-[012-013], c455-[033-034,041-044,081-082,091-094,101-102].

**N. One-node speed** (Charades alone on each node, M committed events/s ÷ the median node, 2 reps): every node is within 0.975–1.009 of the median. c455-081 is 0.993 (σ 100) and 1.001 (σ 2,000). **N1 wrong: c455-081 is not slow on its own.**

**S. 15 nodes without c455-081 ÷ with it** (the "with" set leaves out c455-102 instead; M committed events/s, median of 3; higher means the node costs more):

| engine | workload | W | without | with | without ÷ with |
|---|---|---|---|---|---|
| Charades | σ 100 | 250 | 511.4 | 491.5 | 1.040 |
| Charades | σ 100 | 400 | 531.7 | 499.3 | 1.065 |
| Charades | σ 2,000 | 250 | 347.0 | 332.5 | 1.044 |
| Charades | σ 2,000 | 400 | 349.5 | 340.8 | 1.026 |
| Devastator | σ 100 | 500 | 610.2 | 535.9 | 1.139 |
| Devastator | σ 100 | 1,000 | 625.9 | 530.3 | 1.180 |
| Devastator | σ 2,000 | 500 | 312.9 | 299.5 | 1.045 |
| Devastator | σ 2,000 | 1,000 | 358.7 | 339.7 | 1.056 |

- **S1 wrong in direction.** The node costs Charades 3–7% and Devastator 5–18%. Devastator is hurt more, most at σ 100.
- **c455-081 is slow only in multi-node runs.** Alone it is normal; in every 16-node run of this job and of job 3639554 its processes are the busiest (µs per event ÷ median 1.06–1.08; process 16 here, process 22 there: c455-081 in both allocations). With nothing to send off-node it is fine, so the likely cause is its network path (its Omni-Path adapter, link or switch port). That would also explain why Devastator, whose one master thread per process does all of its communication, suffers more.
- **Earlier 16-node jobs with c455-081:** 3636522 (htram selection at 16 nodes, section 66, and its same-job Devastator comparison), 3638330 (16-node gaps, section 68), 3638371, 3638859, 3638968 (`--agg-auto` at 16 nodes), 3639554 (section 80). The one-allocation scaling series (3639098, section 78) did not have it. Numbers from those jobs are lower than a clean allocation would give, by up to ~7% for Charades and up to ~18% for Devastator; same-job ratios between Charades settings are affected less. **From now on 16-node jobs are submitted with `-x c455-081`.**

**M. Allocator settings, 16 nodes, W 250** (M committed events/s, median of 3; ÷ PP 512 with no setting; events per message and efficiency did not change, 39/74 and 99.92–99.98%):

| workload | PP 512 | + fixed mmap threshold 16 MB | + 256 MB top pad | PP 2,048 capped at 512 | capped + fixed mmap threshold |
|---|---|---|---|---|---|
| σ 100 | 520.4 | 503.2 (0.97) | 543.8 (1.04) | 574.8 (1.10) | 553.1 (1.06) |
| σ 2,000 | 350.2 | 341.3 (0.97) | 361.8 (1.03) | 374.7 (1.07) | 385.5 (1.10) |

- **M1 wrong.** No allocator setting matches the capped setting. Making the 1.2 MB shared buffers come from the heap costs 3%; a large heap top pad gives about 40% of the capped gain (1.03–1.04). The capped setting gives 1.07–1.10 again (1.12–1.14 in section 80, in a different allocation). The gain is real and repeatable, partly about how the heap grows, and still not fully explained.

**W. Wider windows, 16 nodes, PP 512** (median of 2; µs from the per-process traces; this allocation includes c455-081, whose process was the busiest in every run):

| workload | W | M ev/s | efficiency % | GVT advances | µs per advance | reduction floor µs | straggler cost µs | rolled back (M events) |
|---|---|---|---|---|---|---|---|---|
| σ 100 | 250 | 514.0 | 99.98 | 8,522 | 159 | 47 | 97 | 0.12 |
| σ 100 | 400 | 529.1 | 99.95 | 7,060 | 187 | 47 | 123 | 0.33 |
| σ 100 | 600 | 469.1 | 99.77 | 6,370 | 235 | 50 | 163 | 1.65 |
| σ 2,000 | 250 | 346.4 | 99.93 | 8,522 | 225 | 47 | 148 | 0.53 |
| σ 2,000 | 400 | 353.1 | 99.88 | 6,374 | 298 | 54 | 202 | 0.92 |
| σ 2,000 | 600 | 309.8 | 98.99 | 5,298 | 421 | 56 | 312 | 7.40 |

- **W1 right.** From W 400 to 600 at σ 100, throughput falls 11%: advances fall 10% but each takes 26% longer, and the straggler cost accounts for 40 of the 48 µs added per advance. Re-executing the extra 1.3 M rolled-back events takes about 2 ms of PE time per PE, under 0.2% of the run. At σ 2,000 the same: −12%, advances −17%, µs per advance +41%, straggler cost +110 of +123 µs. So a wider window's cost is the straggler cost per advance, not re-execution.
- Part of that growth is structural: a wider window means more work per advance, and a straggler's lag scales with it (W 250 → 400 at σ 100: work per advance ×1.21, straggler cost ×1.27). From 400 to 600 the straggler cost grows faster than the work per advance (×1.33 against ×1.11), which is the rollbacks' share. This allocation's straggler was the network-slow node, so the split needs repeating on a clean allocation.

**Consequences.**
- The earlier explanation that Charades pays more for a slow node because of its tight window is wrong for this node: Devastator pays more. The question I answered before this job ("why is the slow node not a problem for Devastator?") had a false premise; we had not measured it.
- Next on the window: repeat W on a clean allocation (`-x c455-081`). If the straggler cost still dominates and grows faster than work per advance, attack what makes one process lag within an advance (rank 0's process-level work, per-process receive handling), before in-buffer cancellation.

### Where a wider window's cost goes, on a clean allocation (design, 2026-10-25; written before any runs)

> **Status: design.** Part W of section 81 repeated with `-x c455-081`, 3 reps: 16 nodes, PP 512, σ 100 and σ 2,000, W 250, 400, 600, `--gvt-trace=2 --pe-stats=1`. Same build (`charades-diag`). Job script `$WORK/charades-runs/diag3.slurm`.

**Predictions:**
- C1. No process is consistently the busiest: the busiest process's µs per event is ≤ 1.03× the median, and a different process is busiest in different runs.
- C2. µs per advance is lower than in section 82 at every W (no slow node), and from W 400 to 600 the straggler cost still accounts for more than half of the added µs per advance.
- C3. From W 400 to 600 the straggler cost grows faster than the work per advance (the ratio of advances), the share that rollbacks add.

### Where a wider window's cost goes, on a clean allocation, results: the slowest process is usually late because of its rank 0 (2026-10-25; skx-dev batch job 3640064)

> **Status: current.** Design and predictions in section 83. 18 traced runs, all ok (the two warm-ups hit the cap, as intended on fresh nodes); 5 min; allocation c454-[021-022,091-092,094,101-102], c455-[002-004,011,071-072,091-093], without c455-081. Data `~/charades-data/sdiag/j3640064/`, summary `~/charades-data/sdiag/sdiag3_summary.py`.

**16 nodes, PP 512** (median of 3; µs from the per-process traces, mean over waves; higher M ev/s is better, lower µs is better):

| workload | W | M ev/s | efficiency % | GVT advances | µs per advance | reduction floor µs | straggler cost µs | rolled back (M events) |
|---|---|---|---|---|---|---|---|---|
| σ 100 | 250 | 542.4 | 99.98 | 8,537 | 151 | 51 | 82 | 0.12 |
| σ 100 | 400 | 558.6 | 99.96 | 7,016 | 178 | 50 | 107 | 0.32 |
| σ 100 | 600 | 509.7 | 99.78 | 6,195 | 221 | 51 | 146 | 1.58 |
| σ 2,000 | 250 | 362.3 | 99.93 | 8,550 | 209 | 51 | 122 | 0.51 |
| σ 2,000 | 400 | 359.7 | 99.87 | 6,366 | 291 | 56 | 189 | 0.93 |
| σ 2,000 | 600 | 318.5 | 99.07 | 5,168 | 419 | 58 | 304 | 6.77 |

- **C1 right (one exception).** The busiest process's µs per event is 1.006–1.020× the median and it is a different process in each run, except one run (σ 100, W 250, rep 1: process 5 at 1.071).
- **C2 right.** Without c455-081, every cell is faster than in section 82 (σ 100: 542 vs 514 at W 250; µs per advance 151 vs 159), and the straggler cost is most of what W 600 adds (σ 100: 39 of 43 µs; σ 2,000: 115 of 128).
- **C3 right.** The straggler cost grows faster than the work per advance at every step: σ 100, W 400 → 600: ×1.36 against ×1.13; σ 2,000: ×1.61 against ×1.23 (and W 250 → 400: ×1.30 vs ×1.22, ×1.55 vs ×1.34). The reduction floor is flat (50–58 µs). Even at W 250 the straggler cost is 54–58% of an advance.

**Who is late inside the slowest process** (from the last PE's rank in each wave, all 3 reps):

| workload | W | rank 0 is the slowest process's last PE | rank 0 is any process's last PE | the slowest process's first PE contributes after (µs) |
|---|---|---|---|---|
| σ 100 | 250 | 0.62 | 0.11 | 8 |
| σ 100 | 400 | 0.80 | 0.14 | 9 |
| σ 100 | 600 | 0.74 | 0.16 | 13 |
| σ 2,000 | 250 | 0.31 | 0.07 | 10 |
| σ 2,000 | 400 | 0.29 | 0.08 | 17 |
| σ 2,000 | 600 | 0.22 | 0.07 | 25 |

With 23 PEs per process, chance is 0.04. So in the process that holds an advance up, one PE, usually rank 0, comes 100–300 µs after the others.

**Two causes, from `pe_stats`** (σ 100, W 250 / 400, rep 1; rolled-back events per PE, and window-blocked passes ÷ rank 11's):
- **The process edges.** Rolled-back events per PE: rank 0 1,596 / 1,209, rank 22 1,788 / 2,248, ranks 1 and 21 166–772, inner ranks 0–258. At σ 100 events go to nearby LPs, so almost all of a process's cross-process events come into its first and last PEs. Those events go through htram and arrive late (held until due), so those PEs roll back 35–50× more often than inner PEs. Rank 0 is also less often idle (0.88–0.95 of rank 11's window-blocked passes), so it is behind. (Rank 22 is more often idle, 1.15–1.19.)
- **Rank 0's process-level work.** At σ 2,000 rollbacks are even across ranks (1,072–1,666), yet rank 0 is still the slowest process's last PE 22–31% of the time, against 4% by chance, and has the highest µs per event of the inner and edge ranks it was compared with (1.449 vs 1.411–1.438, except rank 22). Rank 0 is where process-level work lands (node-group entry methods; which PE handles htram's node-level receives and the count-wave reduction in Reconverse is to be checked).

**Consequences.** The window's cost and much of the 4→16-node loss come from one late PE per advance, and that PE is predictable: rank 0, and at low σ the process-edge PEs. Two fixes follow, each testable in one short job:
1. **Take process-level work off rank 0.** Each process has one free core (2 × 23 PEs on 48 cores). Put the node-level receive and reduction handling there, like Devastator's master thread, or spread it across PEs. First find which PE runs what (a short trace of node-group entry methods by rank).
2. **Process edges at low σ:** send the few cross-process events of low-σ workloads early or directly instead of holding them until due (at σ 100 only 2–3% of events leave the process), or lay out LPs so a process's edge traffic is spread over its PEs.

### What rank 0 does while it is late: wave-aligned timers and a per-thread perf profile (design, 2026-10-25; written before any runs)

> **Status: design.** Charades `scale-diag` e2806de, htram b25ab15. Job script `$WORK/charades-runs/diag4n4.slurm`, **4 nodes** with `-x c455-081` (a 16-node version, job 3640188, was cancelled before it started: the late rank 0 is a per-process effect already seen at 4 nodes in section 80, and 4 nodes cost a quarter of the node-hours; one 16-node run can size the effect later).

**Why.** Section 84: the slowest process holds an advance up because one PE, usually rank 0, contributes 100–300 µs after the others; at σ 100 the process-edge PEs roll back 35–50× more, and at σ 2,000 rank 0 is still last 22–31% of the time with even rollbacks. Reconverse does not single rank 0 out by default (every PE polls; the 23 PEs share the 16 devices in pairs, so ranks 0 and 1 share device 0).

**Tools.** Profilers measure where cycles go, not when work happens, and count idle spinning as work (they misled once before; memory "Reconverse idle cycles are free"). Projections does not see Charades' `[notrace]` entry methods and must stay short under Reconverse. So:
- `--gvt-trace=3` (new): every rank's contribution delay after the previous result, in every wave (`gvt_ranks_<process>.csv`); for ranks 0, 1, 11, 21, 22 of every process, every 10th wave, cumulative time in input buffer drains (htram and fast path, including the rollbacks they cause), rollbacks, GVT result polls, node-group GVT handlers, htram node receives (a new htram hook) and the scheduler loop, with the time and events executed (`gvt_pe_<pe>.csv`). What a PE did between two snapshots that is in none of these is outside Charades: Converse scheduling, network progress, other entry methods.
- perf: `perf record -e cycles:u` on process 0 only (16-node runs), reported per thread and symbol; node-0 thread ids are printed so threads map to ranks.

**Runs.** σ 100 and σ 2,000, PP 512; traced at W 250 and 400 with untraced pairs, 2 reps; perf at W 400, 2 reps.

**Predictions:**
- T1. `--gvt-trace=3` costs ≤ 3% (traced ÷ untraced ≥ 0.97).
- T2. Rank 0's contribution delay is above the process median in most waves (not only in a few), and rank 1's is the second highest at σ 2,000 (the shared device).
- T3. Per snapshot interval, rank 0's extra time over rank 11 is mostly drains and rollbacks at σ 100 (≥ 50%), and mostly outside Charades at σ 2,000 (≥ 50%).
- P1. In perf, rank 0's thread has a larger share of its samples in LCI and Reconverse progress and queue functions than rank 11's (≥ 1.5×).

### What rank 0 does while it is late, results: nothing extra on average; ranks 0 and 1 are late as a pair (2026-10-25; skx-dev batch job 3640203, 4 nodes)

> **Status: current.** Design and predictions in section 85. 4 nodes (c455-081 excluded), 22 runs, all ok; perf ran on the compute nodes; 4 min. Summary `~/charades-data/sdiag/sdiag4_summary.py` (perf part also `sdiag4_perf.py`; this perf version sorts threads with `--sort pid`, not `tid`).

- **T1 roughly right.** Traced ÷ untraced 0.95–1.00 (median 0.97); 4 of 8 pairs are below 0.97.
- **T2 right, with a twist: ranks 0 and 1 are late, as a pair.** The slowest process's last PE (share of waves): σ 100, W 250: rank 1 0.68, rank 0 0.14; W 400: rank 0 0.57, rank 1 0.22, rank 22 0.11; σ 2,000: rank 0 0.28–0.32, rank 1 0.11–0.14. Mean contribution delay after the previous result: ranks 0 and 1 22–32 µs, the others 12–25 µs (σ 100, W 250: 22 and 27 against about 16). At 4 nodes the process-edge rank 22 matters much less than at 16.
- **T3 wrong: rank 0 does no extra work on average.** Per PE, averaged over 10-wave intervals, ranks 0, 1, 11, 21 and 22 spend the same time in every category to within about 1 µs per wave (σ 100, W 250: scheduler loop 108–110, drains 19–20, GVT polls 8.5–9.4, rollbacks ≤ 0.2, node-group GVT handlers ≤ 0.3, htram node receives ≤ 0.5, outside Charades 17–18 µs per wave; σ 2,000 alike), and execute the same events.
- **P1 wrong.** Over the whole run, rank 0's thread differs from rank 11's only in start-up and shutdown work it does as the process's main thread: psm2 `ips_proto_disconnect` (7–10% of its samples), `printf` of the final statistics, `memset`, `__mpn_divrem`. Its network share (0.14–0.16) is within the spread of other ranks across reps (0.04–0.23). One hint: a kernel address (0xffffffffa2000b80, likely the return from an interrupt; the profile is user-space only, `perf_event_paranoid` 2) takes 1.1–1.3% of rank 0's samples and none of rank 11's.

**What this means.** Ranks 0 and 1 are late in individual waves, not busier overall: short, occasional delays. Their work is the same as every other rank's, so the cause is probably outside the process: interrupts or other OS activity on the cores they run on. With `+pemap 2-46:2,3-47:2`, ranks 0 and 1 of the two processes on a node sit on cores 2, 4 (socket 0) and 3, 5 (socket 1), next to the two free cores 0 and 1.

**Addendum (same day, topology job 3640225 on c454-082, and the traces above split by socket).** An skx node: 2 × Xeon Platinum 8160 (24 cores each, no SMT), 2 NUMA nodes (node 0 = even cores, 94.7 GB; node 1 = odd cores, 96.8 GB; distance 10/21), L3 33 MB per socket. The Omni-Path adapter hfi1_0 is on NUMA node 0. irqbalance runs with OPA's exact hint policy: the adapter's busiest interrupts are its receive contexts kctxt1 and kctxt2 on cores 2 and 4, and send-DMA engines sdma0–15 on cores 6–36 (sdma0/1 on cores 6 and 8 the busiest); socket 1 takes none. Under our `+pemap`, cores 2 and 4 are ranks 0 and 1 of the socket-0 process. **But ranks 0 and 1 are late just as often in the socket-1 processes** (cores 3 and 5, no adapter interrupts): σ 100, W 250: last-PE share rank 1 0.31 (socket 0) vs 0.36 (socket 1); W 400: rank 0 0.35 vs 0.22, rank 1 0.01 vs 0.21; mean delays alike. So the lateness follows the rank, not the core: it is in the software (ranks 0 and 1 share LCI device 0; rank 0 is the main thread), not the adapter's interrupts. The reversed-pemap test is therefore not needed. One socket effect remains: at σ 2,000 the slowest process is on socket 0 (the adapter's socket) in 65% of waves.

**Superseded next step:** (1) record `/proc/interrupts` and the IRQ affinity of the hfi1 (Omni-Path) interrupts on the compute nodes, before and after a run; (2) the same traced runs with a reversed `+pemap` (rank 0 on core 46/47, rank 22 on core 2/3): if the lateness follows the core, it is the OS or interrupts, and the fix is to keep those cores free; if it follows the rank, it is in the software.

**Upper bound on fixing it** (same traces; mean over waves of the slowest PE's contribution delay after the previous result, all processes; lower is better):

| workload | W | all ranks (µs) | without ranks 0, 1 (µs) | without ranks 0, 1, 22 (µs) |
|---|---|---|---|---|
| σ 100 | 250 | 99 | 50 (−50%) | 49 (−50%) |
| σ 100 | 400 | 118 | 48 (−59%) | 37 (−69%) |
| σ 2,000 | 250 | 136 | 108 (−21%) | 107 (−22%) |
| σ 2,000 | 400 | 187 | 145 (−23%) | 143 (−23%) |

This is the tail of each advance, not the whole advance (130–220 µs here), and it assumes the other ranks would not take rank 0's place as the slowest PE.

### Late ranks 0 and 1: the LCI device they poll, or the PSM2 receive thread? (design, 2026-10-26; written before any runs)

> **Status: design.** Charades `scale-diag` e2806de (unchanged), htram b25ab15. Job script `$WORK/charades-runs/diag5.slurm`, 4 nodes with `-x c455-081`.

**What the code says** (Reconverse ff33b56 `src/comm_backend/lci2/comm_backend_lci2.cpp`; LCI ca88ce2c `src/network/ofi/backend_ofi.cpp`):
- Each PE thread is bound to device `rank / ceil(23 / ndevices)`. At 16 devices that is 2 per device, so ranks 0 and 1 share device 0 (and ranks 2 and 3 share device 1, and so on, with rank 22 alone on device 11). Each thread polls only its own device, under a per-device trylock.
- LCI exchanges endpoint addresses per device, so device *i* of one process talks only to device *i* of another. A message lands on the receiver's device with the **sender's** device index. Node-level messages (htram node messages, the GVT exchange) are no exception: they go out on the sending PE's device. So there is no routing of node-level traffic to device 0, and the hypothesis I gave before reading the code (node-level messages all land on device 0) is wrong.
- What does single out device 0: it is the first endpoint each process opens (rank 0, the main thread, opens all of them in `init()`). PSM2 starts its receive thread (`PSM2_RCVTHREAD`, on by default; the "async" thread in the section 86 perf profile, with no user-space samples) for the first endpoint. That thread wakes on adapter interrupts and progresses the endpoint under its lock, so it competes with ranks 0 and 1 for device 0. I have not read the PSM2 source to confirm that the thread is first-endpoint-only.
- A side effect of per-device polling: a message on device *k* is received only when one of device *k*'s 2 threads polls, even if the other 21 PEs are idle.

**Runs.** σ 100 and σ 2,000 at W 400, PP 512. Five arms: `+lci_ndevices` 16 (as now), 23, 8 and 4 (device 0 polled by ranks 0–1, 0, 0–2 and 0–5), and 16 with `PSM2_RCVTHREAD=0`. Each arm traced (`--gvt-trace=3`) with an untraced pair, 2 reps, interleaved; 40 runs.

**Predictions:**
- D1. The late set is device 0's threads: at 23 devices only rank 0 is late (rank 1 like the rest); at 8, ranks 0–2; at 4, ranks 0–5, each less late than ranks 0 and 1 are at 16.
- D2. With `PSM2_RCVTHREAD=0`, ranks 0 and 1 are no later than the median rank (share of waves above their process median ≤ 0.55, against 0.54–0.67 now), and the mean slowest-PE delay falls by at least half the upper bound above.
- D3. Throughput (untraced, M ev/s) with `PSM2_RCVTHREAD=0` is at least 1.05× the 16-device default at σ 100, and at least 1.02× at σ 2,000. Device counts other than 16 are within ±5% of it (as found earlier on verbs).
- If D1 holds and D2 fails, the cause is on device 0 but is not the receive thread; next is to read PSM2 and LCI for other per-endpoint work. If D1 fails (ranks 0 and 1 stay late at every device count), the cause is tied to the ranks themselves; next is the Charm++ and Reconverse work that rank 0 does as the main thread, and why rank 1 joins it.

### Late ranks, results: rank 0 is late at every device count; rank 1 only because it shares rank 0's device; 23 devices is 1.03–1.07× faster (2026-10-26; skx-dev batch job 3641728, 4 nodes)

> **Status: current.** Design and predictions in section 87. 4 nodes (c454-004, c454-012, c454-044, c455-082), 42 runs, all ok; 6 min. Summary `~/charades-data/sdiag/sdiag5_summary.py`, output and CSVs in `~/charades-data/sdiag/j3641728/`.

**Throughput** (untraced, M committed events/s, mean of 2 reps; ratio = arm ÷ 16 devices, higher is better):

| arm | σ 100 (M ev/s) | ratio | σ 2,000 (M ev/s) | ratio |
|---|---|---|---|---|
| 16 devices (default) | 162.4 | 1.000 | 115.5 | 1.000 |
| 23 devices (one per PE) | 167.4 | **1.030** | 123.8 | **1.072** |
| 8 devices | 154.5 | 0.951 | 108.3 | 0.938 |
| 4 devices | 152.0 | 0.936 | 97.2 | 0.842 |
| 16 devices, `PSM2_RCVTHREAD=0` | 163.3 | 1.005 | 115.0 | 0.996 |

The two reps of each arm are within 1.7% of each other, and the 23-device reps do not overlap the 16-device ones.

**Late ranks** (traced; mean contribution delay after the previous result, µs, lower is better; "rest" = median over ranks not on device 0 and not 22; last-PE share = how often the rank is the slowest process's last PE):

| arm | σ 100: r0 / r1 / r2 / rest | σ 100: r0 last-PE share | σ 2,000: r0 / r1 / r2 / rest | σ 2,000: r0 last-PE share | σ 2,000: slowest-PE delay (µs) |
|---|---|---|---|---|---|
| 16 devices (r0–1 on device 0) | 23 / 18 / 12 / 12 | 0.60 | 33 / 28 / 25 / 24 | 0.28 | 188 |
| 23 devices (r0 alone) | 25 / **13** / 12 / 12 | 0.74 | 29 / **23** / 24 / 24 | 0.18 | 166 |
| 8 devices (r0–2) | 25 / 15 / 13 / 12 | 0.79 | 34 / 27 / 29 / 26 | 0.29 | 196 |
| 4 devices (r0–5) | 26 / 16 / 14 / 12 | 0.77 | 37 / 30 / 29 / 29 | 0.24 | 225 |
| 16, `PSM2_RCVTHREAD=0` | 24 / 18 / 12 / 12 | 0.64 | 35 / 31 / 24 / 24 | 0.36 | 185 |

- **D1 half right.** Rank 1 is late only when it shares a device with rank 0: alone on its device (23 devices) it is as early as the rest. The other ranks that share device 0 at 8 or 4 devices are only slightly late (ranks 2–5: 0–2 µs above the rest). **Rank 0 is late at every device count** (23–26 µs at σ 100 against 12 for the rest) and is the slowest process's last PE in 60–79% of waves at σ 100. So the cause is rank 0 itself; rank 1 is late because it shares rank 0's device. A guess for that link, not tested: rank 0 sometimes stalls while it holds device 0's progress lock, and rank 1's polls fail the trylock until rank 0 releases it.
- **D2 wrong.** Turning the PSM2 receive thread off changes nothing: ranks 0 and 1 are as late, and throughput is 0.996–1.005×.
- **D3 wrong for the receive thread, but 23 devices is faster:** 1.03× at σ 100 and 1.07× at σ 2,000, with the slowest-PE delay at σ 2,000 down from 188 to 166 µs. Fewer devices are slower: 0.94–0.95× at 8 and 0.84–0.94× at 4. Earlier, on verbs at 2 × 23 PEs, 23 devices was 0.93–0.94× of 8 devices ("Runtime settings on the production build"); on psm2 it is now the best. This is 4 nodes only.
- **Code reading, for the next step.** Reconverse opens the network devices (`comm_backend::init`, `convcore.cpp:478`) in the main thread before any PE thread exists, and Charm++ pins each PE later (`CmiInitCPUAffinity`, `ck-core/init.C:1691`). Any helper thread that LCI, PSM2 or libfabric starts after rank 0 is pinned inherits rank 0's core and can preempt it. The section 86 perf profile shows two non-PE threads in process 0 ("async" and an unnamed one), and a kernel return address in 1.1–1.3% of rank 0's samples and none of rank 11's. The per-thread scheduler statistics in `/proc/<pid>/task/<tid>/schedstat` record time spent waiting on a run queue, which would show such preemption directly; they need no privileges.

### Is rank 0 preempted? Per-thread scheduler statistics; and 23 devices at 16 nodes (design, 2026-10-26; written before any runs)

> **Status: design.** Charades `scale-diag` e2806de (unchanged), htram b25ab15. Two jobs, both with `-x c455-081`: `$WORK/charades-runs/diag6.slurm` (4 nodes) and `dev23.slurm` (16 nodes). Whichever skx-dev job finishes first, a job still waiting on skx moves to skx-dev.

**Job A, 4 nodes: is rank 0 preempted?** Section 88 points at rank 0 itself, and the code shows Reconverse opens the network devices in the main thread before Charm++ pins the PEs. A wrapper (`schedwrap.sh`, `schedsample.py`) runs each process and, every 0.5 s, reads from `/proc` for each of its threads: name, allowed cores, last core, time running, time waiting on a run queue, time slices, voluntary and involuntary context switches, page faults, user and system time; and each CPU's interrupt and softirq time. The sampler runs on the process's free core (core 0 or 1). Threads map to ranks by their pinned core (`+pemap 2-46:2,3-47:2`). Runs: σ 100 and σ 2,000 at W 400, 16 and 23 devices, `--gvt-trace=3`, each with an unwrapped untraced pair (overhead check), 2 reps.

**Predictions (A):**
- S1. Rank 0 waits on the run queue at least 3× as long per second as the median PE, and involuntary switches show the same; at least one non-PE thread is allowed on, or last ran on, rank 0's core.
- S2. Rank 1's wait is at the median at both device counts.
- S3. Interrupt and softirq time on rank 0's core is no higher than on other PE cores of the same socket (socket 1 gets no adapter interrupts at all).
- If S1 fails, rank 0 is not preempted: it is running something else. Next would be timing Charm++ and Converse work inside rank 0's scheduler loop.

**Job B, 16 nodes: 23 devices as default?** The 8 workloads of the scaling series (σ 100, 500, 1,000, 2,000, 4,000 and uniform at lookahead 100 / mean 1,000; σ 500 and 2,000 at lookahead 10 / mean 200), PP 512, the controller (ε 0.001) and one fixed W (400, or 100 at lookahead 10), `+lci_ndevices` 16 and 23, 3 reps interleaved; 96 runs.

**Predictions (B):**
- B1. 23 devices ÷ 16 devices (M committed events/s, median of 3, higher is better) is ≥ 1.03 in at least 6 of the 8 workloads with the controller, and below 0.98 in none.
- B2. The gain is larger at 16 nodes than at 4 (more remote traffic per PE, so per-device sharing costs more).

### Rank 0 takes page faults, not preemption; 23 devices is 1.21× at 16 nodes (2026-10-26; skx-dev batch jobs 3641766, 4 nodes, and 3641785, 16 nodes)

> **Status: current.** Design and predictions in section 89. Job A 3641766 (c455-001 to c455-004): 16 runs, all ok (the two warm-up runs stalled, as first launches on fresh nodes do). Job B 3641785 (16 nodes, c455-081 excluded; moved from skx to skx-dev when skx-dev came free): 96 runs, all ok; the first warm-up failed on a `/work2` read error loading `libreconverse.so` (section 81's file-system problem). Summaries `~/charades-data/sdiag/sdiag6_summary.py`, `dev23_summary.py`; output and data in `~/charades-data/sdiag/j3641766/` and `~/charades-data/dev23/j3641785/`.

**Job A: what rank 0's thread does** (per thread, from `/proc`, 20–90% of each run, mean over the 8 processes; 2 reps agree; W 400):

| | σ 100, 16 devices: rank 0 | σ 100: ranks 2–21 | σ 100, 23 devices: rank 0 | σ 2,000, 16 devices: rank 0 | σ 2,000: ranks 2–21 |
|---|---|---|---|---|---|
| time in the kernel (share of wall time) | **0.17–0.22** | 0.001 | **0.30–0.32** | 0.011–0.014 | 0.008–0.009 |
| minor page faults per s | **18,000–26,000** | 180–200 | **47,000–48,000** | 310–360 | 190 |
| voluntary / involuntary context switches per s | 111 / 106–110 | 2 / 1–3 | 118–122 / 108–109 | 92–109 / 4 | 102–117 / 3–4 |
| run-queue wait (ms per s) | 4.2–4.8 | 0.06–0.5 | 4.4 | 0.1 | 0.05–0.14 |

- **S1 right in form, wrong in mechanism.** Rank 0 waits on the run queue 4–5 ms per second (0.5%) and is switched out about 110 times a second involuntarily, far more than the other ranks. But the other threads are not what takes its time: the two non-PE threads per process (PSM2's "async" and an unnamed one) are allowed on every core of their socket, ran mostly on the free core, and used at most 0.15% of a core. What sets rank 0 apart is **page faults: 18,000–48,000 a second against about 200 for every other rank, and 17–32% of its time in the kernel, at σ 100 only.** At σ 2,000 rank 0 looks like every other rank.
- **S2 right.** Rank 1 is like the others in every statistic.
- **S3 right.** Interrupt and softirq time on rank 0's core is 2.5–10 ms per s, as on the other socket-0 cores (socket medians 2.5–9.9).
- **What this means.** Only rank 0 is the process's main thread, and in glibc only the main thread allocates from the main arena, which grows and shrinks the heap with `brk`. Freeing memory at the top of that heap past the trim threshold (128 KB by default, raised dynamically) gives the pages back, and the next allocation faults them in again. The other threads' arenas evidently do not churn this way. 20,000–48,000 faults a second is 80–190 MB of fresh pages a second. That is probably also why section 80's allocation effects (PP buffers allocated at 2,048 but capped at 512: 1.07–1.14×; a malloc top pad recovering about 40% of it) were real but unexplained: they change rank 0's heap pattern. Untested so far: which allocations churn, and why at σ 100 and not at σ 2,000. At σ 2,000 rank 0 is still late in 22–31% of waves (section 84), so that lateness has a different, smaller cause.

**Job B: 23 devices against 16 at 16 nodes** (M committed events/s, median of 3; ratio = 23 ÷ 16, higher is better; PP 512; max ÷ min across reps ≤ 1.07 everywhere, ≤ 1.04 in 27 of 32 cells):

| workload | controller: 16 / 23 devices | ratio | fixed W: 16 / 23 devices | ratio |
|---|---|---|---|---|
| lookahead 100, mean 1,000, σ 100 (W 400) | 548.5 / 615.6 | 1.12 | 573.3 / 638.0 | 1.11 |
| σ 500 | 511.4 / 561.2 | 1.10 | 499.3 / 557.5 | 1.12 |
| σ 1,000 | 468.4 / 504.0 | 1.08 | 460.9 / 510.5 | 1.11 |
| σ 2,000 | 361.0 / 402.6 | 1.12 | 360.6 / 431.7 | 1.20 |
| σ 4,000 | 297.5 / 378.2 | 1.27 | 302.5 / 424.4 | 1.40 |
| uniform remote 1.0 | 142.3 / 207.8 | 1.46 | 161.0 / 231.3 | 1.44 |
| lookahead 10, mean 200, σ 500 (W 100) | 399.5 / 471.4 | 1.18 | 371.1 / 388.1 | 1.05 |
| lookahead 10, σ 2,000 | 249.0 / 354.6 | 1.42 | 274.3 / 344.6 | 1.26 |

- **B1 right:** 1.08–1.46 with the controller (geometric mean 1.21), ≥ 1.03 in 8 of 8 and never below; fixed W 1.05–1.44 (1.20).
- **B2 right:** at 4 nodes it was 1.03–1.07 (section 88). The gain grows with the share of remote traffic (uniform and σ 4,000 the most), so per-device sharing costs more the more messages a PE receives. **23 devices (one per PE) is the new default launch.**
- **Against Devastator, provisionally** (Devastator from job 3639098, a different allocation; Charades here searched only the two arms above at PP 512, against a wider grid in 3639098, so this understates Charades): Charades ÷ Devastator at 16 nodes would move from 0.92 / 1.08 / 1.26 / 0.95 / 1.04 / 0.99 / 0.85 / 0.76 to about 0.96 / 1.08 / 1.23 / 1.13 / 1.41 / 1.20 / 0.92 / 0.98 (rows in the order above, best of the two arms). That is ahead or level in 6 of 8 workloads instead of 3. It needs a same-allocation run with Devastator before it goes in the current numbers.

### Rank 0's page faults: where from, and do malloc settings stop them? And Charades (23 devices) against Devastator at 16 nodes, same allocation (design, 2026-10-26; written before any runs)

> **Status: design.** Charades `scale-diag` e2806de (unchanged), htram b25ab15, `+lci_ndevices 23`. Job C `$WORK/charades-runs/diag7.slurm` (4 nodes), job D `cmp16.slurm` (16 nodes), both `-x c455-081`; same rule as section 89 for moving between skx and skx-dev.

**Job C, 4 nodes.** σ 100 and σ 2,000 at W 400, PP 512. Three glibc malloc arms through `GLIBC_TUNABLES`:
- `m0`: the defaults.
- `mtrim`: no heap trimming (trim threshold 1 GB, top pad 64 MB). Setting these also stops glibc raising the mmap threshold, which stays at 128 KB.
- `mall`: no trimming, and an mmap threshold of 32 MB, so large blocks come from the heap instead of `mmap`/`munmap` each time.

Each arm runs with the `/proc` sampler and `--gvt-trace=3`, plus an untraced, unwrapped pair for throughput; 2 reps. Then one run per workload at `m0` with `perf record -e page-faults:u` (every 100th fault, DWARF call stacks) on process 0, reported per thread and by calling function.

**Predictions (C):**
- C1. In perf, rank 0's faults come from glibc's heap growth after a trim (`sysmalloc`/`brk`) or from freshly mmapped blocks, called from Charades or htram allocations. Other ranks fault little.
- C2. `mall` brings rank 0's faults to within 2× of the other ranks' (about 200 per s) and its kernel time below 2%, at σ 100. `mtrim` does that only if the cause is trimming rather than `mmap` churn.
- C3. With `mall`, rank 0 stops being the late rank at σ 100: mean contribution delay within 3 µs of the median rank, and the slowest process's last PE in under 30% of waves (60–79% now).
- C4. Throughput with `mall` is ≥ 1.05× `m0` at σ 100 and within ±2% at σ 2,000. No arm raises the other ranks' faults.

**Job D, 16 nodes.** The current-numbers comparison redone in one allocation with 23 devices: Charades over PP 512 and PP 2,048 × W 250/400/600 and the controller (lookahead 10: W 50/100/200), plus WPs 512 for uniform and lookahead 10 σ 2,000; Devastator (p32w23, CLCG4) over W 500/1,000/2,000 (lookahead 10: 100/200/400; W 2,000 is new, because its best W was at the top of the grid at 16 nodes). 3 reps, interleaved.

**Predictions (D):**
- D1. Charades ÷ Devastator (each at its best, median of 3, higher is better) ≥ 1.0 in at least 6 of 8 workloads. The two below 1.0 are σ 100 and lookahead 10 σ 500 (provisional 0.96 and 0.92 in section 90).
- D2. Charades at its best is at least 1.10× its 16-node numbers in job 3639098 at σ ≥ 2,000, uniform and lookahead 10 σ 2,000.

### Results: malloc settings 1.06–1.08×, but rank 0's faults come from system calls; Charades ahead of Devastator in all 8 workloads at 16 nodes (2026-10-26; skx-dev batch jobs 3641910, 4 nodes, and 3641926, 16 nodes)

> **Status: current.** Design and predictions in section 91. Job C 3641910 (c454-094, c454-101 to c454-103): 28 runs, all ok. Job D 3641926 (16 nodes, c455-081 excluded; moved to skx-dev when it came free): 215 of 218 Charades runs ok, all 108 Devastator runs ok. Of the 3 others, one is the first warm-up (the usual stall on fresh nodes) and two are lookahead 10 σ 500 at PP 2,048 in rep 2. One of those Slurm aborted before launch; the other's simulation finished normally in 1.65 s but its step took 206 s in all. Neither is a Charades hang. Summaries `~/charades-data/sdiag/sdiag7_extra.py`, `sdiag6_summary.py`, `cmp16_summary.py`; output and data in `~/charades-data/sdiag/j3641910/` and `~/charades-data/cmp16/j3641926/`.

**Job C: glibc malloc settings, 4 nodes, 23 devices, W 400** (untraced M committed events/s, mean of 2 reps, which agree within 0.7%; ratio = arm ÷ defaults, higher is better):

| arm | σ 100 (M ev/s) | ratio | σ 2,000 (M ev/s) | ratio |
|---|---|---|---|---|
| defaults (`m0`) | 167.6 | 1.000 | 125.3 | 1.000 |
| no trim (`mtrim`) | 181.5 | **1.083** | 132.2 | **1.055** |
| no trim, mmap threshold 32 MB (`mall`) | 180.0 | 1.074 | 133.1 | 1.062 |

| σ 100, per thread (`/proc`, 2 reps) | rank 0, `m0` | rank 0, `mtrim` / `mall` | ranks 2–21, `m0` | ranks 2–21, `mtrim` / `mall` |
|---|---|---|---|---|
| minor page faults per s | 37,000–45,000 | 15,000–16,000 / 10,000 | 220 | 67 / 59 |
| time in the kernel | 0.25–0.30 | 0.23 / 0.22 | 0 | 0 / 0 |
| mean contribution delay (µs) | 22 | 19 / 18 | 12 | 9 / 9 |
| rank 0 is the slowest process's last PE | 53% | 49% / 47% | | |

- **C1 wrong.** `perf record -e page-faults:u` counts only faults taken in user mode. In steady state rank 0 takes about 400–1,600 of those a second, against 37,000–45,000 in `/proc`. So nearly all of rank 0's faults are taken inside the kernel, during system calls (for instance while the kernel pins or copies user memory), not when glibc grows its heap. Over the whole run, the faults perf did see are mostly PSM2 opening and closing its endpoints in the main thread.
- **C2 wrong.** The malloc settings cut rank 0's faults by 2.5–4× and every other rank's by about 3.5×, but rank 0's kernel time stays at 22–23%.
- **C3 wrong at σ 100:** rank 0 is still the late PE about half the time. At σ 2,000 `mtrim` made rank 0 ordinary (last PE 4% against 22%; mean delay 22 µs against 21 for the rest), but `mall` did not (20%); with 2 reps that is not settled.
- **C4 right at σ 100 (1.07–1.08×), and better than predicted at σ 2,000 (1.06×, predicted ±2%).** The gain is broad: every rank faults less and contributes earlier (rest of the ranks 12 → 9 µs at σ 100), not only rank 0.
- **Not yet default:** 4 nodes only. `mtrim` is the simpler of the two and is as good.

**Job D: Charades (23 devices) against Devastator at 16 nodes, one allocation** (M committed events/s, median of 3, each engine at its best setting; ratio = Charades ÷ Devastator, higher is better for Charades):

| workload | Charades (M ev/s) | Charades setting | Devastator (M ev/s) | Devastator W | **Charades ÷ Devastator** | same ratio in job 3639098 (16 devices) | Charades ÷ its 3639098 best |
|---|---|---|---|---|---|---|---|
| lookahead 100, mean 1,000, σ 100 | 702.3 | PP 2,048, W 400 | 661.9 | 1,000 | **1.06** | 0.92 | 1.15 |
| σ 500 | 622.7 | PP 2,048, controller | 523.5 | 1,000 | **1.19** | 1.08 | 1.12 |
| σ 1,000 | 579.1 | PP 2,048, controller | 446.1 | 1,000 | **1.30** | 1.26 | 1.11 |
| σ 2,000 | 435.4 | PP 512, W 400 | 381.9 | 1,000 | **1.14** | 0.95 | 1.20 |
| σ 4,000 | 421.8 | PP 512, W 400 | 301.1 | 1,000 | **1.40** | 1.04 | 1.35 |
| uniform remote 1.0 | 280.2 | WPs 512, W 400 | 197.7 | 1,000 | **1.42** | 0.99 | 1.47 |
| lookahead 10, mean 200, σ 500 | 560.5 | PP 2,048, W 50 | 512.0 | 200 | **1.09** | 0.85 | 1.29 |
| lookahead 10, σ 2,000 | 414.6 | WPs 512, W 50 | 360.1 | 200 | **1.15** | 0.76 | 1.52 |

- **D1 right, and better than predicted:** Charades leads in all 8 workloads (1.06–1.42×), not 6. Before the device change it led in 3.
- **D2 right:** 1.20–1.52× its job-3639098 numbers at σ ≥ 2,000, uniform and lookahead 10 σ 2,000, and 1.11–1.29× elsewhere. Some of that is allocation-to-allocation difference; Devastator's numbers moved by −1% to +8% between the two jobs.
- **Devastator's grid is adequate now:** its best W is 1,000 everywhere at lookahead 100 (W 2,000 is 4–30% slower) and 200 at lookahead 10, both inside the grid.
- **Charades' controller at 16 nodes:** 1.00 of the best fixed W at σ ≤ 1,000, 0.97–0.98 at uniform and lookahead 10, but **0.87–0.90 at σ 2,000 and 4,000.** That is the open gap at scale.

### Rank 0's system calls; and the 1/4/16-node series on 23 devices, with glibc no-trim at 16 nodes (design, 2026-10-26; written before any runs)

> **Status: design.** Charades `scale-diag` e2806de (unchanged), htram b25ab15, `+lci_ndevices 23`. Job E `$WORK/charades-runs/diag8.slurm` (4 nodes), job F `scale23.slurm` (16 nodes), both `-x c455-081`; same rule as section 89 for moving between skx and skx-dev.

**Job E, 4 nodes: which system calls rank 0 makes.** Process 0 runs under `strace -f -ff -tt -T` (one file per thread, with each call's duration), with `--gvt-trace=3` so thread ids map to ranks. Runs:
- σ 100 with the glibc defaults;
- σ 100 with no-trim (`mtrim`, section 92);
- σ 2,000 with the defaults.

2 reps, plus an untraced run without strace. strace slows every system call it sees, so these runs are for identifying the calls, not for timing the simulation.

**Predictions (E):**
- E1. Between 30% and 90% of the run, at σ 100, rank 0 makes at least 50× as many system calls a second as the median rank. Most of its time in them goes to calls into the Omni-Path driver (`ioctl` or `writev` on `/dev/hfi1_*`, which pin memory for large transfers) or to memory calls (`mmap`, `munmap`, `madvise`). The other ranks make few of either.
- E2. At σ 2,000 rank 0's calls look like the other ranks'.

**Job F, 16 nodes: the scaling table on the new launch.** Weak scaling at 1, 4 and 16 nodes in one allocation, 3 reps. The grids are those of job 3639098: Charades over PP 512 and PP 2,048 × W 250/400/600 and the controller (lookahead 10: W 50/100/200), plus WPs 512 for uniform and lookahead 10 σ 2,000; Devastator over W 500/1,000 (and 2,000 at 16 nodes; lookahead 10: 100/200/400). In each rep, at 16 nodes, no-trim (`mtrim`) runs for both engines: Charades at W 400 (lookahead 10: W 50) and the controller for each aggregation setting, Devastator at W 1,000 (lookahead 10: 200).

**Predictions (F):**
- F1. With 23 devices, Charades ÷ Devastator at 1 and 4 nodes is at least the job-3639098 ratio in every workload, and Charades leads in at least 6 of 8 at each node count.
- F2. Charades' 4→16 node weak-scaling efficiency improves at σ ≥ 2,000 and uniform: at least 0.85 at σ 2,000 (0.71 before) and at least 0.60 for uniform (0.40 before).
- F3. `mtrim` ÷ defaults at 16 nodes is ≥ 1.03 for Charades in at least 6 of 8 workloads, and within ±3% for Devastator.

### Rank 0's system calls, results: not the cause (2026-10-26; skx-dev batch job 3642143, 4 nodes)

> **Status: current.** Design and predictions in section 93 (job E). 4 nodes (c455-081 excluded), 10 runs, all ok; strace output 106 MB in `$WORK/charades-runs/sdiag8/j3642143/`. Summary `~/charades-data/sdiag/sdiag8_summary.py`, output `~/charades-data/sdiag/j3642143/summary.txt`. Job F is still queued.

- **E1 wrong.** Over the whole run rank 0 makes 19–31× as many system calls a second as the median rank at σ 100. But binned in time, nearly all of them are start-up and shutdown, in the main thread: about 6,600 `openat`/`read`/`close` of `/sys/devices/system/cpu/...` files (the CPU topology probe) before the PEs start, and `munmap`/`sched_yield` at exit. **While the simulation runs (about 1.2 s under strace), rank 0 makes about 900 `futex` calls a second and a handful of `brk`, against about 250 `futex` calls for rank 11; no calls into the Omni-Path driver and almost no memory calls.** strace times all of rank 0's calls at under 1% of its time.
- **E2 right:** at σ 2,000 every PE makes about 2,200 calls a second (mostly `futex`, plus `writev` to the hfi1 device and `process_vm_readv` for same-node transfers), and rank 0 is like the rest once start-up is excluded.
- **What this leaves.** Rank 0 at σ 100 spends 17–32% of its time in the kernel and takes 18,000–48,000 minor faults a second (`/proc`, sections 90 and 92). Those are not in system calls (strace), and `perf record -e page-faults:u` saw only 400–1,600 user-mode faults a second (section 92). One of the two measurements is misleading, or the faults come from a kernel mechanism neither sees directly. The leading candidate: automatic NUMA balancing is on (`kernel.numa_balancing` = 1, checked on a login node). It periodically unmaps a process's pages to see which node touches them, and charges the scan and the hinting faults to the threads that run into them. Its address-space walk starts at the lowest addresses, where the main thread's `brk` heap sits. Not yet tested; two other open possibilities are that the `/proc` sampler itself causes the faults on the main thread, or that perf undercounts them.
- The extra `futex` calls (about 3.5× the median rank) are lock waits. A plausible source is glibc's main-arena lock: memory rank 0 allocates is freed by other PEs, which must take that arena's lock.

### 1/4/16 nodes on 23 devices, results: Charades leads in 22 of 24 cells; glibc no-trim is 1.055× for Charades and 0.25–0.53× for Devastator (2026-10-26; skx-dev batch job 3642157, 16 nodes)

> **Status: current.** Design and predictions in section 93 (job F). 16 nodes (c455-081 excluded; moved to skx-dev when it came free), 1 h 9 min. 756 Charades runs ok. Two 1-node runs reached the 60 s cap: lookahead 10, σ 2,000, W 200 at PP 512 and PP 2,048 in rep 1. All Devastator runs ok. Summary `~/charades-data/scale23/scale23_summary.py`, output and data in `~/charades-data/scale23/j3642157/`.

**Weak scaling, each engine at its best setting** (M committed events/s, median of 3; Charades ÷ Devastator, higher is better for Charades; efficiency = per-node rate at 16 ÷ at 4 nodes, 1.0 is perfect):

| workload | Charades 1 / 4 / 16 nodes | Devastator 1 / 4 / 16 nodes | **Charades ÷ Devastator 1 / 4 / 16** | same, job 3639098 (16 devices) | efficiency 4→16, Charades / Devastator | same, job 3639098 |
|---|---|---|---|---|---|---|
| lookahead 100, mean 1,000, σ 100 | 48.4 / 178.1 / 704.4 | 41.4 / 171.3 / 663.0 | **1.17 / 1.04 / 1.06** | 1.14 / 0.97 / 0.92 | 0.99 / 0.97 | 0.93 / 0.98 |
| σ 500 | 42.0 / 159.9 / 619.0 | 38.6 / 147.4 / 519.8 | **1.09 / 1.08 / 1.19** | 1.07 / 1.10 / 1.08 | 0.97 / 0.88 | 0.90 / 0.92 |
| σ 1,000 | 40.7 / 152.2 / 579.4 | 37.6 / 128.0 / 442.8 | **1.08 / 1.19 / 1.31** | 1.08 / 1.21 / 1.26 | 0.95 / 0.86 | 0.89 / 0.86 |
| σ 2,000 | 39.5 / 134.3 / 434.1 | 30.6 / 104.8 / 380.3 | **1.29 / 1.28 / 1.14** | 1.27 / 1.21 / 0.95 | 0.81 / 0.91 | 0.71 / 0.91 |
| σ 4,000 | 39.3 / 120.5 / 421.4 | 29.3 / 81.2 / 297.9 | **1.34 / 1.48 / 1.41** | 1.32 / 1.40 / 1.04 | 0.87 / 0.92 | 0.69 / 0.93 |
| uniform remote 1.0 | 42.4 / 133.8 / 276.8 | 30.1 / 70.6 / 194.6 | **1.41 / 1.90 / 1.42** | 1.38 / 1.69 / 0.99 | 0.52 / 0.69 | 0.40 / 0.68 |
| lookahead 10, mean 200, σ 500 | 38.2 / 145.8 / 562.8 | 39.0 / 149.4 / 514.4 | **0.98 / 0.98 / 1.09** | 0.96 / 0.91 / 0.85 | 0.97 / 0.86 | 0.81 / 0.87 |
| lookahead 10, σ 2,000 | 33.6 / 116.3 / 414.5 | 29.6 / 98.6 / 360.9 | **1.14 / 1.18 / 1.15** | 1.09 / 0.97 / 0.76 | 0.89 / 0.91 | 0.71 / 0.91 |

- **F1 mostly right.** At 1 node every ratio is at or above the old one; at 4 nodes 6 of 8 are, and the other two are 0.02 below (σ 500, 1,000). Charades leads in 7 of 8 workloads at 1 and 4 nodes and 8 of 8 at 16; the one exception is lookahead 10, σ 500 (0.98 at 1 and 4 nodes).
- **F2 wrong on the thresholds, right in direction.** Charades' 4→16 efficiency rose at every workload: σ 2,000 0.71 → 0.81 (predicted ≥ 0.85), σ 4,000 0.69 → 0.87, uniform 0.40 → 0.52 (predicted ≥ 0.60). At σ ≥ 2,000 Devastator still scales better (0.91–0.92); Charades' lead there comes from its higher rate per node.
- The 16-node numbers agree with job 3641926 to within 1% for both engines.
- Charades' best setting: PP 512 at W 250 on 1 node; PP 2,048 at σ ≤ 1,000 and lookahead 10 σ 500 from 4 nodes on; WPs 512 for uniform at 16 nodes and lookahead 10 σ 2,000 from 4. Devastator's best W: 500–1,000 (lookahead 10: 100–200), always inside its grid.
- **Controller ÷ best fixed W:** 0.95–1.03 everywhere except σ 2,000 and 4,000 at 16 nodes (0.92, 0.86).

**glibc no-trim (`trim_threshold` 1 GB, `top_pad` 64 MB) ÷ defaults at 16 nodes**, same arm, median of 3 each (higher is better):
- **Charades: 1.021–1.099 over 36 cells, geometric mean 1.055, ≥ 1.03 in 33** (F3 right). Best no-trim ÷ best defaults per workload: 1.035–1.086.
- **Devastator: 0.25–0.53 (geometric mean 0.38). F3 wrong for Devastator, badly.** The setting is harmful to it, not neutral. A likely reason, untested: glibc gives each thread's arena heaps of at most 64 MB, and a 64 MB top pad asks for that much headroom on every extension, so a program whose worker threads allocate a lot keeps creating and dropping heaps. Each engine keeps its own best: Charades with no-trim, Devastator with the defaults. A smaller pad, or the trim threshold alone, may be better for both; not tested.
- With no-trim, Charades' 16-node lead would be about 5% larger than in the table above (not rerun as one table).

### Rank 0's faults: perf against /proc in the same run, a lighter sampler, and memory bound to the socket (design, 2026-10-26; written before any runs)

> **Status: design.** Charades `scale-diag` e2806de (unchanged), htram b25ab15, `+lci_ndevices 23`, glibc defaults. Job G `$WORK/charades-runs/diag9.slurm` (4 nodes, skx and skx-dev, the copy that starts second cancelled), wrapper `gwrap.sh`, sampler `schedsample.py` (new light mode: `/proc/<pid>/task/*/stat` only, every 1 s).

**Why.** Section 94 left a conflict: `/proc` says rank 0 takes 18,000–48,000 minor faults a second at σ 100 and spends 17–32% of its time in the kernel, but strace finds almost no system calls, and a sampled `perf record -e page-faults:u` saw 400–1,600 user-mode faults a second. Three explanations: automatic NUMA balancing (on, on the login node), the `/proc` sampler itself, or perf undercounting.

**Runs** (σ 100, W 400, PP 512, `--gvt-trace=3`, 2 reps):
- `plain`: no wrapper.
- `fullperf`: the full sampler on every process, and `perf record -e page-faults:u -c 1` (every user-mode fault, no stacks) on process 0.
- `light`: the light sampler.
- `numa`: memory bound to the process's own socket (`numactl --membind`) with the light sampler. A bound policy also exempts the memory from NUMA-balancing migration.
- At σ 2,000: `light` and `numa`.
- Untraced throughput pairs, plain and `numa`, at both σ.
- The job also records each node's `numa_balancing` and transparent-huge-page settings.

**Predictions:**
- G1. In `fullperf`, perf's user-mode fault count for rank 0 between 30% and 90% of the run is at least half of `/proc`'s minor-fault count for the same thread and window. That would mean the faults are ordinary user-mode faults and the earlier sampled profile undercounted.
- G2. With the light sampler, rank 0 still takes at least 20× the median rank's faults and spends at least 10% of its time in the kernel, so the sampler is not the cause.
- G3. With `numa`, rank 0's faults fall to within 3× of the median rank's and its kernel time below 2%. Rank 0 is no longer the late rank: the slowest process's last PE in under 30% of waves (about 50% now). Throughput is ≥ 1.05× plain at σ 100 and within ±2% at σ 2,000.
- G4. `numa_balancing` is 1 on the compute nodes.

### Rank 0's faults, results: an artifact of my /proc sampler; rank 0 is late without it, and takes one shared lock 10× as often (2026-10-26; skx-dev batch job 3642578, 4 nodes)

> **Status: current.** Design and predictions in section 96. 4 nodes (c455-014, c455-021, c455-042, c455-043), 22 runs, all ok; 4 min. Summary `~/charades-data/sdiag/sdiag9_summary.py`, output `~/charades-data/sdiag/j3642578/summary.txt`. **This corrects sections 90 and 92:** rank 0's 18,000–48,000 faults a second and 17–32% kernel time there were caused by the full `/proc` sampler, not by Charades. The throughput results of those sections (23 devices; glibc no-trim) came from runs without the sampler and stand.

- **G1 right.** With every user-mode fault recorded (`-c 1`), perf and `/proc` agree per thread over the whole run (perf ÷ `/proc` 1.00–1.02 for ranks 0, 1, 11 and 22). The faults are ordinary user-mode faults; the earlier sampled profile (section 92, every 100th fault with DWARF stacks) undercounted them.
- **G2 wrong.** With the light sampler (one `stat` read per thread per second), rank 0 at σ 100 takes about 490 faults a second and spends 0.3% of its time in the kernel, against 3,700 and 5% next to the full sampler in this job, and 18,000–48,000 and 17–32% in sections 90 and 92. The full sampler reads `status` and `schedstat` for every thread every 0.5 s. Something in that, for the main thread, makes it fault. I have not found the mechanism and will not use that sampler again.
- **G3 wrong.** Binding memory to the socket (`numactl --membind`, which also exempts it from NUMA-balancing migration) leaves rank 0 as late as before. The slowest process's last PE is rank 0 in 74% of waves, against 71% plain; its mean delay is 25 µs against 11–12 for the rest. Throughput 1.020× at σ 100, 1.001× at σ 2,000.
- **G4 right:** `numa_balancing` = 1 on all four nodes; transparent huge pages `always`, defrag `madvise`.
- **Rank 0 is late with nothing attached** (`plain`): mean contribution delay 25 µs against 12 for the rest, last PE in 71% of waves at σ 100 (12% at σ 2,000).

**What is left, from the strace runs of section 94.** Between 1.45 and 2.55 s of the σ 100 run (the simulation phase under strace), rank 0 makes 620 `futex` calls on one address, 0x3e06600 (455 wakes, 165 waits). Every other PE makes 40–70 calls on that address. The address is in the main thread's `brk` heap, about 30 MB above its start, so the lock was allocated early by the main thread. It is a lock every PE takes, which rank 0 takes, and finds contended, about 10× as often as any other PE: mostly it is holding it while others wait. That would make rank 0 slow exactly when the lock is busy, without more work on average. `strace -k` (call stack for every system call) works on Stampede3 and would name the lock.

### Naming the lock rank 0 takes 10× as often (design, 2026-10-26; written before any runs)

> **Status: design.** Charades `scale-diag` e2806de (unchanged), htram b25ab15, `+lci_ndevices 23`, glibc defaults. Job H `$WORK/charades-runs/diag10.slurm` (4 nodes, skx-dev and skx, the copy that starts second cancelled), wrapper `skwrap.sh`: process 0 runs under `strace -f -ff -k -e trace=futex` (every lock call that enters the kernel, with its call stack, one file per thread). Runs: σ 100 at W 400, 2 reps, and σ 2,000 once, all with `--gvt-trace=3` so thread ids map to ranks.

**Predictions:**
- H1. The hot lock is not glibc's main-arena lock: that lock lives in libc's data segment, and the hot address (0x3e06600 in section 94) was in the `brk` heap. The new runs' hot address will also be in the heap. Its call stacks on rank 0 go through Reconverse or Charm++ code that delivers node-level messages (the node queue, or node-group entry methods such as htram's node receives and the GVT node waves), not through Charades' event code.
- H2. Rank 0 reaches the lock through a path the other PEs rarely take, for instance as the main thread or as the thread that drains a node-level queue first. The other PEs' calls on the same address come through the same functions, but about 10× less often.
- H3. At σ 2,000 rank 0's calls on that lock are within 2× of the median PE's.

### The lock, results: Reconverse's per-PE message pool, fought over by the process-edge ranks because each one drains the other's network messages (2026-10-26; skx-dev batch job 3642782, 4 nodes)

> **Status: current.** Design and predictions in section 98. 4 nodes (c454-043, c454-044, c454-103, c454-104), 5 runs, all ok; 5 min. Summary `~/charades-data/sdiag/sdiag10_summary.py` (plus an inline pool-ownership count, below), output `~/charades-data/sdiag/j3642782/summary.txt`.

**The hot lock is Reconverse's per-PE message-memory pool lock** (`mempool_malloc` and `mempool_free_thread` in `mempool.C`, under `CmiAlloc`/`CmiFree` in the LCI2 backend). Each PE has one; a PE's pool lock is the one hot address in its stacks, and rank 0's sits in the main thread's heap because rank 0 is the main thread.

Who contends at σ 100 (calls that reached the kernel in about 7 s under strace, process 0, rep 1):

| pool owner | contended calls on its lock | by rank (top 5) |
|---|---|---|
| rank 22 | 2,583 | r22 1,015, r0 733, r1 449, r2 49, r21 30 |
| rank 0 | 2,357 | r0 840, r22 634, r21 346, r2 41, r3 39 |
| next busiest (rank 8) | 174 | r8 110, then ≤ 9 each |

Contended allocations made while draining the network (`lci::progress_recv` → `CmiAlloc`): rank 0 601, rank 22 799, every other rank 0–9.

**Mechanism.**
- At σ 100 nearly all cross-process events go between the edge ranks of neighbouring processes: rank 22 of process p and rank 0 of process p+1 (section 84's process-edge effect).
- LCI delivers a message on the receiver's device with the **sender's** index (section 87). So messages sent by rank 22 of p land on device 22 of p+1 and are drained by rank 22 of p+1, though they are for its rank 0; messages for rank 22 are drained by rank 0.
- The draining PE allocates the receive buffer from its own pool. The destination PE frees it after delivery, which takes the owner's pool lock (`CkDeliverMessageFree` → `mempool_free_thread`), while the owner keeps allocating from the same pool. So ranks 0 and 22 (and their neighbours 1 and 21, which get some of the edge traffic) keep contending on each other's pools, and each does network-receive work for the other end of the process.

At σ 2,000 traffic spreads over every device and every pool sees similar contention: contended receive allocations run from 577 to 2,021 per rank, U-shaped, highest at the edges (ranks 0, 1, 21, 22: 1,602–2,021).

- **H1 half right.** It is not glibc's arena lock. It is not node-level message delivery either: it is Reconverse's message pool, reached from LCI's receive path on one side and from Charm++ message frees on the other.
- **H2 right in form.** Rank 0 reaches the lock through the network-receive path, which at σ 100 only the edge ranks take. But rank 22 does the same, about as much. Why rank 0, not rank 22, ends up the late PE is still open; at 16 nodes (section 84) rank 0 was also the usual late PE, while both edge ranks rolled back 35–50× more than the rest.
- **H3 right.** At σ 2,000 rank 0's pool is no more contended than other edge ranks' pools (rank 1's is the busiest).
- **Caveat.** strace records only lock calls that had to wait or wake; under strace the whole run is 2–5× slower; and the time in those calls is small (section 94: 7.5 ms/s for rank 0). The cost to rank 0 is more likely the uncontended lock traffic, cache-line transfers of the pool's lists between ranks 0 and 22, and the receive work for rank 22, than the futex time itself.

**Fixes to try (Reconverse branch, then 4 and 16 nodes):**
1. **Send on the destination PE's device.** In `issueAm`, pick the device by the destination PE's rank in its process, not by the sending thread. Node-level messages keep the sender's device. Then each PE drains its own messages, allocates them from its own pool and frees them locally. Cost: the send completes on another PE's device, so the send buffer is freed by that PE into the sender's pool. That is cross-thread again, but on the sending side, which htram aggregation makes rarer.
2. **Lock-free cross-thread frees in the mempool:** a free from another thread pushes onto an atomic list that the owner drains when it allocates. This helps σ 2,000 too, where every pool is contended.

### Late rank 0: edge traffic or the rank? Rotated LP blocks, and sending on the destination PE's device (design, 2026-10-26; written before any runs)

> **Status: design.** Charades `scale-diag` 3c7c529 (adds `--map-rotate`), htram b25ab15, Reconverse `pads-dest-device` 13ae1ac (adds `+lci_dest_device`; on Stampede3 only, as a patch on `pads-runtime` 78eedbf in `charm-pads-exp`). `+lci_ndevices 23`, glibc defaults. Job I `$WORK/charades-runs/diag11.slurm` (4 nodes, skx-dev and skx, the copy that starts second cancelled).

**Why.** Section 99: ranks 0 and 22 contend about equally on each other's message pools, but only rank 0 is badly late (mean delay 25 µs, against 14–15 for rank 22 and 12 for the middle ranks). Two candidate explanations:
- The edge traffic drives both, and something about rank 0 (main thread, device 0) makes it pay more.
- Rank 0 is late for a reason of its own.

**Changes (both off by default; one build serves every arm):**
- `--map-rotate=k` (Charades, diagnostic): within each process, rank r gets the LPs the block mapping gives rank (r − k) mod 23. With k = 11 the edge LPs sit on ranks 11 and 10, and rank 0 holds interior LPs. Committed events are unchanged (Mac: 81,667 with and without, direct sends and htram PP).
- `+lci_dest_device` (Reconverse): `CmiSyncSendAndFree` names the destination rank, and the LCI2 backend sends on the device that rank polls, so each PE drains its own messages and allocates and frees them in its own pool. The send then completes on another PE's device, which frees the buffer into the sender's pool. Node-level messages are unchanged.

**Runs.** σ 100 and σ 2,000 at W 400, PP 512. Four arms: `base`, `rot` (k = 11), `dd` (`+lci_dest_device`), and `ddrot`. Each arm traced (`--gvt-trace=3`) with an untraced pair, 2 reps, plus one smoke run of `dd` first.

**Predictions:**
- I1. With `rot` at σ 100, the late PE moves with the edge LPs: ranks 10 and 11 become the late ranks, and rank 0's mean delay comes within 3 µs of the middle ranks'. If rank 0 instead stays the most frequent last PE (over 40% of waves), the cause is rank 0 itself.
- I2. With `dd` at σ 100, rank 0's mean delay comes within 5 µs of the middle ranks', and throughput is ≥ 1.03× `base`. At σ 2,000, `dd` is within ±3% of `base`.
- I3. `ddrot` matches `dd` (no late ranks anywhere), within ±2% in throughput.

### Late rank 0, results: the lateness follows the lower-edge LPs, not the rank or the device; sending on the destination device does not help (2026-10-26; skx-dev batch job 3643113, 4 nodes)

> **Status: current.** Design and predictions in section 100. 4 nodes (c455-071, c455-072, c455-082, c455-083), 33 runs ok (the two warm-ups stalled, as first launches on fresh nodes do); the `+lci_dest_device` smoke run was ok. Summary `~/charades-data/sdiag/sdiag11_summary.py`, output `~/charades-data/sdiag/j3643113/summary.txt`.

**Lateness at σ 100** (traced; mean contribution delay after the previous result, µs, lower is better; "middle" = median of ranks 3–8 and 13–19; last PE = share of waves in which the rank is the slowest process's last PE):

| arm | r0 | r1 | r10 | r11 | r12 | r21 | r22 | middle | last PE | slowest-PE delay (µs) |
|---|---|---|---|---|---|---|---|---|---|---|
| base | **25** | 13 | 12 | 12 | 12 | 13 | 15 | 12 | r0 0.71, r22 0.10 | 111 |
| rot (edge LPs on r11, r10) | 15 | 13 | **17** | **20** | 15 | 12 | 12 | 12 | r11 0.36, r10 0.21, r0 0.15 | 115 |
| dd (`+lci_dest_device`) | **26** | 13 | 12 | 12 | 12 | 13 | 15 | 12 | r0 0.75, r22 0.11 | 112 |
| ddrot | 14 | 12 | **17** | **22** | 14 | 12 | 12 | 12 | r11 0.54, r10 0.23, r0 0.10 | 114 |

At σ 2,000: base r0 31 against 23 for the middle (last PE 0.25), rot r0 28 (0.14), dd r0 37 (0.41), ddrot r0 35 (0.33).

**Throughput** (untraced, M committed events/s, mean of 2 reps; ratio = arm ÷ base, higher is better): σ 100 base 166.9, rot 0.994, dd 0.987, ddrot 0.990; σ 2,000 base 123.6, rot 0.991, dd 0.963, ddrot 0.956.

- **I1 right, mostly.** With the LP blocks rotated, the lateness moves with the edge LPs to ranks 11 and 10 (last PE 0.36 and 0.21), and rank 0 drops from 25 to 15 µs (the middle is 12). It moves to rank 11 more than rank 10, and rank 11 holds the block that rank 0 holds unrotated: **the process's lower-edge LPs, the ones whose neighbours are in process p − 1.** The upper-edge LPs (rank 22 unrotated, rank 10 rotated) are less late. A small part stays with rank 0 (15 against 12 µs). The slowest-PE delay does not change (111 → 115 µs): moving the problem does not shrink it.
- **I2 wrong.** `+lci_dest_device` leaves rank 0 exactly as late (26 µs, last PE 0.75) and costs 1.3% at σ 100 and 3.7% at σ 2,000. So the cross-draining and pool contention of section 99 are real, but they are not what makes rank 0 late. Caveat: I did not check under strace that the flag rerouted the messages. The throughput change at σ 2,000 shows it changed something. The flag stays off.
- **I3 wrong** in the same way: `ddrot` behaves like `rot`.

**Why the lower edge.** Every htram flush loop (`flushDue`, `flushPending`, `tflush`, `flushStale`, `flushIdle`) scans destination processes in index order, 0 to N − 1. Process p's buffers toward p − 1 are therefore flushed before those toward p + 1 in every pass (except at the wrap-around). The events for process p's lower-edge LPs come from p − 1, whose buffer toward p (the higher index) goes out after its buffer toward p − 2. So the lower edge of every process gets its cross-process events later in each flush pass than the upper edge does. That would explain why the lower-edge rank is the late one. Not yet tested.

**Next:** flush in an order that does not favour low process indices: by earliest due timestamp, or starting each scan at the PE's own process and wrapping. Then measure whether the lower edge stops being late and whether the slowest-PE delay falls.

### htram flush order: rotating start and earliest timestamp first (design, 2026-10-26; written before any runs)

> **Status: design.** Charades `scale-diag` 64d2db8 (adds `--agg-flush-order`), htram `pdes` 8ed0252 (adds `htram_flush_order`), Reconverse `pads-dest-device` 13ae1ac with `+lci_dest_device` off (the same as `pads-runtime`). `+lci_ndevices 23`, glibc defaults. Job J `$WORK/charades-runs/diag12.slurm` (4 nodes, skx-dev and skx, the copy that starts second cancelled).

**Why.** Section 101: the late PE holds its process's lower-edge LPs, and every htram flush pass visits destination processes by index, so each process's buffer toward p + 1 always goes out after its buffer toward p − 1.

**Change.** `htram_flush_order` sets the order of `flushDue` (every mode) and of `tflush` and `flushPending` (PP):
- 0: by index (as before).
- 1: by index, starting one destination later on each pass.
- 2: earliest buffered timestamp first (the lower of the PE's local minimum key and the node's shared one).

Committed events are unchanged on the Mac (81,667 for all three at 2 × 4 PEs, and for 0 and 2 at 4 × 2 PEs).

**Runs.** σ 100 and σ 2,000 at W 400, PP 512. Arms `fo0`, `fo1`, `fo2`, each traced (`--gvt-trace=3`) with an untraced pair, 3 reps, interleaved.

**Predictions:**
- J1. With `fo2` at σ 100, the lower edge stops being late: rank 0's mean delay comes within 3 µs of the middle ranks', and no rank is the slowest process's last PE in more than 30% of waves.
- J2. With `fo2` at σ 100, the slowest-PE delay falls by at least 15% (111 µs with index order in section 101), and throughput is ≥ 1.03× `fo0`. At σ 2,000, `fo2` is ≥ 1.0×.
- J3. `fo1` removes the lower-edge bias as well (ranks 0 and 22 equally late), but gains less than `fo2`, because it is unbiased rather than urgent-first.

### htram flush order, results: no effect; the lower edge stays late (2026-10-26; skx-dev batch job 3643408 and idev job 3643609, 4 nodes)

> **Status: current.** Design and predictions in section 102.
> - **Batch job 3643408** (c454-044, c454-102, c454-104, c455-073): index order (`fo0`) and rotating start (`fo1`) ran, 25 runs ok. **Every earliest-timestamp run (`fo2`) crashed** within 2 s with SIGSEGV in `HTram::flushOrder`. My bug: the sort's comparator read the node's shared minimum keys, which other PEs update during the sort, so it was not a strict weak order and `std::stable_sort` ran off the end. It did not show on the Mac (2 and 4 processes). Fixed in htram `pdes` 3cb3d1e: read every key once into a vector, then sort by the copy.
> - **idev job 3643609** (c454-013, c454-021, c455-001, c455-011): the fix checked interactively, then all of job J. 37 runs ok; the first warm-up stalled as usual.
>
> Summary `~/charades-data/sdiag/sdiag12_summary.py`, outputs in `~/charades-data/sdiag/j3643609/` (the batch job's `fo0`/`fo1` agree with it).

**Throughput** (untraced, M committed events/s, mean of 3 reps; ratio = arm ÷ index order, higher is better):

| σ | index order (M ev/s) | rotating start | earliest timestamp |
|---|---|---|---|
| 100 | 167.5 | 0.972 (reps 167.8, 152.7, 167.8) | 0.987 |
| 2,000 | 125.1 | 1.001 | 0.997 |

The batch job agrees for `fo1` (0.995 and 0.998).

**Lateness at σ 100** (mean contribution delay after the previous result, µs; middle ranks 12): rank 0 is 25 / 24 / 25 µs with index / rotating / timestamp order. The slowest process's last PE is rank 0 in 70% / 64% / 71% of waves. The slowest-PE delay is 109 / 111 / 111 µs. At σ 2,000: rank 0 32 / 31 / 32 µs against 23, last PE 0.28 in every arm.

- **J1, J2 and J3 wrong.** Neither order changes which rank is late, by how much, or the throughput. The rotating start's one slow rep (152.7) is noise in a single run. The flush order is not why the lower-edge LPs are late; that leaves the order-of-flush explanation in section 101 refuted. The option stays at 0 (index order), and the timestamp order stays available, off by default.

**Where this leaves the late lower edge.** It follows the lower-edge LPs (section 101) and is not caused by:
- the core, socket or interrupts (section 86);
- NUMA placement (97);
- page faults, which were my sampler (97);
- system calls (94);
- the LCI device, whether by sharing (88) or by routing (101);
- message-pool contention (101);
- htram flush order (this section).

It costs at σ 100 up to −50% of the advance tail (section 86's bound) but **does not limit scaling now: σ 100's 4→16 node efficiency is 0.99 with 23 devices (section 95)**. Where Charades still scales worse than Devastator is σ ≥ 2,000 and uniform (0.81 and 0.52, against 0.91 and 0.69), and its controller gap there at 16 nodes (0.86–0.92); at σ 2,000 the lower-edge effect is smaller (−21 to −23% of the tail).

### Why one PE holds up each GVT advance at uniform and σ 2,000: per-PE wave records, and fewer events per wave (design, 2026-10-26; written before any runs)

> **Status: design.** Charades `scale-diag` ff3f4fd (adds `--gvt-trace=4`), htram `pdes` 3cb3d1e, Reconverse `pads-dest-device` 13ae1ac with `+lci_dest_device` off (the same as `pads-runtime`). `+lci_ndevices 23`, glibc defaults. Job K `$WORK/charades-runs/diag13.slurm` (16 nodes, skx-dev and skx, `-x c455-081`, the copy that starts second cancelled).

**Why.** Where Charades still scales worse than Devastator is σ ≥ 2,000 and uniform (4→16-node efficiency 0.81 and 0.52, against 0.91 and 0.69; section 95). Section 80 put most of the growth in time per GVT advance into the straggler cost: the slowest process's last PE contributes long after the others (uniform: +303 of +353 µs per advance from 4 to 16 nodes; the slowest process's own PEs 430 µs apart; σ 2,000: +40 of +47). At uniform the slowest process changes from wave to wave (no process slowest in more than 6% of waves), so this is not the lower-edge effect of sections 84–103, which needs locality. Nothing so far says what that last PE is doing.

**What a contribution waits for.** A PE joins a count wave when it picks up the previous wave's result (at the start of its next scheduler pass) and then either has executed `--gvt-wave-events` events (128) since its last contribution or ends a pass with nothing it may execute. At uniform, each PE executes about 140–150 events per wave (16 nodes, WPs 512, W 400: 278 M ev/s over 736 PEs, 6,473 waves in 2.6 s; 4 nodes: about 140), close to 128. So the last PE may simply be the one that still had events inside the window and ran 128 of them, while PEs that ran out of work joined at once.

**New instrumentation** (off by default): `--gvt-trace=4` adds, for every PE and every 4th wave (`gvt_rec_<pe>.csv`; all PEs sample the same waves), times in µs after the previous result was published in its process (on that process's clock):
- when the PE picked the result up, and when its last scheduler pass before that ended (so a late pickup splits into time still inside a pass and time outside one: other entry methods, network progress);
- when it contributed, and why: at pickup (idle or already past 128 events), or later (ran out of work, or reached 128 events);
- between pickup and contribution: scheduler time, input buffer drains, htram receive handlers, rollbacks, node-group GVT handlers, events executed;
- the buckets past GVT it had passed when it contributed (how far it had got in virtual time).

Mac: test config `bucket_gvt_trace4`, 6/6 (and trace 2/3 unchanged, 12/12).

**Runs** (W 400; uniform = remote 1.0, lookahead 100 / mean 1,000; σ 2,000 at the same lookahead and mean; 2 reps, interleaved):
- Traced (`--gvt-trace=4 --pe-stats=1`) with untraced pairs at 4 and 16 nodes: uniform with WPs 512 (its best at 16 nodes) and PP 512; σ 2,000 with PP 512.
- `--gvt-wave-events` 0 and 32 against the default 128, untraced, 16 nodes: uniform with WPs 512 and PP 512; σ 2,000 PP 512 with 32 only. (0 was tried at σ 100 and σ 2,000 in sections 47 and 54: advances 18–38% shorter but 20–60% more of them, throughput −2% to +6%; never at uniform.)

Summary per traced run, over the recorded waves at 10–95% of the run: in each wave the slowest process's last PE (the "late PE") against the median PE of the same process; its delay split into pickup (inside a pass / outside) and pickup → contribution (scheduler, drains, receives, rollbacks), its events, its time per event, its reason, the buckets it had passed; which ranks and processes are late.

**Predictions:**
- K1. At uniform on 16 nodes the late PE is spread out: no rank is the slowest process's last PE in more than 15% of waves, and no process is the slowest in more than 15%.
- K2. The late PE contributes on the event count (it reached 128) in at least 70% of waves, while the median PE of its process does so in at most 30%. Its pickup delay is at most 25% of its contribution delay. So it is late because it still had events to run, not because it was busy elsewhere.
- K3. Between pickup and contribution, the late PE's time per executed event is within 20% of the median PE's (it is late because it has more to do, not because each event costs more), and it reaches the same number of buckets passed as the median PE or fewer.
- K4. From 4 to 16 nodes, at least 70% of the growth in the late PE's delay is after pickup.
- K5. σ 2,000 at 16 nodes looks the same: the late PE reaches the event count in at least 60% of waves.
- K6. `--gvt-wave-events=32` is at least 1.03× the default at uniform on 16 nodes in both modes, and within ±3% at σ 2,000; `--gvt-wave-events=0` is 0.95–1.10× at uniform.
- K7. `--gvt-trace=4` costs at most 5% (traced ÷ untraced ≥ 0.95).

If K2 holds, the straggler cost at uniform is GVT waiting for the PE with the most work in the window, and the remedies are spreading that work (sharing it within a process) or pacing waves differently, not aggregation. If instead the late PE's time is in pickup or in drains and receives (K2 or K3 wrong), it is receive handling, and fewer, larger messages could help after all.

### Per-PE wave records, results: at uniform the late PE is slowed by receiving many small messages; `--gvt-wave-events=32` is 1.04–1.06× at 16 nodes (2026-10-26; skx-dev batch job 3643687, 16 nodes)

> **Status: current.** Design and predictions in section 104. 16 nodes (c454-021, c454-022, c454-042, c454-072, c455-022 to -024, c455-031 to -034, c455-041, c455-042, c455-094, c455-101, c455-102; 4-node runs on the first four), 35 runs ok (the first warm-up stalled, as first launches on fresh nodes do); 6 min. Summary `~/charades-data/sdiag/sdiag13_summary.py`, output `~/charades-data/sdiag/j3643687/summary.txt`.

**Throughput** (untraced, W 400, M committed events/s, mean of 2 reps; higher is better):

| workload | htram | 4 nodes | 16 nodes | 4→16 efficiency | traced ÷ untraced (4 / 16 nodes) |
|---|---|---|---|---|---|
| uniform | WPs 512 | 101.7 | 280.2 | 0.69 | 0.984 / 0.985 |
| uniform | PP 512 | 122.1 | 224.5 | 0.46 | 0.987 / 1.018 |
| σ 2,000 | PP 512 | 125.8 | 431.8 | 0.86 | 0.990 / 1.013 |

**`--gvt-wave-events` K ÷ the default 128, 16 nodes** (untraced, both reps in parentheses; higher is better):

| workload | htram | K 0 | K 32 |
|---|---|---|---|
| uniform | WPs 512 | 1.057 (296.7, 295.8 vs 279.4, 281.0) | 1.056 (298.0, 294.0) |
| uniform | PP 512 | 1.037 (233.5, 232.3 vs 224.8, 224.1) | 1.042 (232.0, 235.6) |
| σ 2,000 | PP 512 | — | 1.035 (444.4, 449.6 vs 429.3, 434.4) |

**The late PE against the median PE of its process** (the slowest process's last PE in each recorded wave, waves 10–95%, both reps, about 2,800–3,100 waves per cell; µs after the previous result in that process, lower is better; "by count" = share of waves in which it contributed because it had run 128 events since its last contribution):

| workload | nodes | PE | delay | pickup (in a pass + outside) | after pickup | of which: scheduler (incl. drains) | drains | htram receives | other, outside the scheduler | events after pickup | µs per event after pickup | by count |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| uniform, WPs | 4 | late | 209 | 8 + 9 | 192 | 133 | 35 | 47 | 12 | 79 | 2.44 | 1.00 |
| uniform, WPs | 16 | late | 339 | 22 + 28 | 288 | 159 | 53 | 102 | 27 | 61 | 4.74 | 0.97 |
| uniform, WPs | 16 | median | 78 | 2 + 2 | 75 | 7 | 1 | 2 | 66 | 2 | — | 0.31 |
| uniform, PP | 4 | late | 165 | 8 + 7 | 150 | 125 | 28 | 6 | 19 | 87 | 1.72 | 0.98 |
| uniform, PP | 16 | late | 387 | 13 + 32 | 343 | 154 | 46 | 79 | 110 | 59 | 5.78 | 0.94 |
| σ 2,000, PP | 4 | late | 156 | 12 + 8 | 136 | 117 | 22 | 2 | 17 | 90 | 1.51 | 0.99 |
| σ 2,000, PP | 16 | late | 143 | 20 + 15 | 107 | 78 | 16 | 2 | 13 | 55 | 1.94 | 0.94 |

(The median PE contributes almost at once in every cell: delay 21–81 µs, 1–2 events after pickup. Its "other" time is mostly waiting for its next pass to end.)

**Cost of an htram receive** (ranks 0, 1, 11, 21, 22 of every process, from the `--gvt-trace=3` snapshots, waves 10–100%; µs per receive-handler call):

| workload | htram | 4 nodes | 16 nodes |
|---|---|---|---|
| uniform | WPs 512 | 10.3, 11.1 (30 events per message) | 8.3, 8.2 (12.4) |
| uniform | PP 512 | 5.7, 5.5 (75) | 7.5, 7.3 (13.8) |
| σ 2,000 | PP 512 | 3.7, 3.7 (50) | 3.7, 3.7 (50) |

- **K1 half right.** No rank is the late PE in more than 10% of waves at uniform. But one process is the slowest more often than 15% of the time: process 2 at 16 nodes with WPs (0.26), and processes 2 and 3 at 4 nodes (0.35, 0.32). Processes 2 and 3 are the second node in both runs (c454-022). They are not slower per event (`pe_stats`: every process is within 1.04× of the median), so this is not a slow node like c455-081. Not explained.
- **K2 right, with one detail.** The late PE contributes by count in 94–100% of waves, and its pickup takes 8–15% of its delay. The median PE contributes by count in 29–34% of waves, just over the 30% predicted. The count runs from the PE's last contribution: after pickup the late PE runs only 55–90 events, never 128. So it is late because it is busy after pickup, not because it was busy elsewhere first.
- **K3 wrong at uniform: the late PE is slower, not more loaded.** From 4 to 16 nodes it runs *fewer* events after pickup (WPs 79 → 61, PP 87 → 59) but takes longer per event (2.44 → 4.74 µs, 1.72 → 5.78). The extra time is receive work:
  - WPs: the late PE's delay grows by 130 µs. htram receive handlers +55, pickup +33, drains +18, other time outside the scheduler +15, the events themselves +8.
  - PP: it grows by 222 µs. Other time outside the scheduler +91, htram receives +73, pickup +30, drains +18. The 91 µs is outside Charades' timers: Converse scheduling, LCI progress, and receive-side work that the htram timer does not cover.
  - (The comparison with the median PE was not meaningful: it runs 1–2 events after pickup.)
- **Receive work is even over the run but uneven per wave.** Every rank spends about 2 µs per wave in htram receive handlers on average (WPs, 16 nodes: 0.2–10.4 per PE, no rank above 3). In a given wave, the late PE is the one that took about 100 µs of receives. With LCI, a message lands on the device with the sender's index, so which PE handles a receive depends on the sender's rank, which is effectively random at uniform.
- **K4 right.** 74% (WPs) and 87% (PP) of the growth in the late PE's delay is after pickup. But it is mostly receive work, not event execution.
- **K5 right, and σ 2,000 does not grow in this job.** The late PE contributes by count in 94% of waves. Its delay is 156 µs at 4 nodes and 143 at 16, with receives at 2 µs. This job's σ 2,000 efficiency is 0.86 (0.81 in section 95), so it has little loss left to explain.
- **K6 right for uniform, and better than predicted at σ 2,000.** K 32 gives 1.056 (WPs) and 1.042 (PP) at uniform, and 1.035 at σ 2,000 (predicted ±3%). K 0 gives about the same as 32 at uniform. All four reps are within ±1% of their pair. In section 25 (4 nodes, an older runtime and layout), K 64 was 0.77, so 32 needs checking at 1 and 4 nodes before it becomes the default.
- **K7 right.** Traced ÷ untraced is 0.984–1.018.

**What this means.**
- At uniform, the straggler cost at scale is receive handling of thin messages. Per call, a WPs receive costs about 10.6 µs at 30 events per message and 8.2 µs at 12.4. Fitting a fixed and a per-event cost to these two points gives about 6.5 µs per message plus 0.13 µs per event. So receive cost per event rises from about 0.35 µs to 0.66 µs as messages thin. PP is not consistent with a simple fixed-plus-per-event fit, because it mixes PEs' 16-event local sends with shared-buffer sends.
- So fewer, larger messages *would* help uniform, against section 80's reading. So would a cheaper per-message receive: what the 6.5 µs consists of is not yet measured. One candidate is pushes onto up to 23 PEs' input buffers per message.
- Separately, `--gvt-wave-events=32` is worth 3.5–5.6% at 16 nodes on all three workloads.

**Next:**
1. `--gvt-wave-events` 32 (and 64) against 128 at 1, 4 and 16 nodes across the scaling workloads, before changing the default.
2. Break down an htram receive at 16 nodes (unpacking, input buffer pushes per destination PE, allocation), to find the fixed cost.
3. Then compare cutting that cost with fewer destinations (one process per node with per-socket buffers, or two-hop routing).

### `--gvt-wave-events` 32 / 64 / 128 at 1, 4 and 16 nodes; what an htram receive costs (design, 2026-10-26; written before any runs)

> **Status: design.** Charades `scale-diag` 859fe1a (adds `recv_parts_<pe>.csv` under `--gvt-trace=3`), htram `pdes` 04457e0 (splits node-level receives into parts), Reconverse `pads-dest-device` 13ae1ac with `+lci_dest_device` off. `+lci_ndevices 23`, glibc defaults. Job L `$WORK/charades-runs/diag14.slurm` (16 nodes, skx-dev and skx, `-x c455-081`, the copy that starts second cancelled).

**Why.** Section 105: `--gvt-wave-events=32` was 1.035–1.056× the default 128 at 16 nodes on uniform and σ 2,000, but 64 was 0.77 at 4 nodes in section 25 (older runtime and layout), so the default should change only if smaller counts do not lose at 1 and 4 nodes or on other workloads. And at uniform the late PE is slowed by htram receives that cost about 6.5 µs per message plus 0.13 µs per event (a two-point fit), but what that fixed cost is made of is unknown.

**A. `--gvt-wave-events` K = 32, 64, 128.** The 8 workloads of the scaling series at 1, 4 and 16 nodes, PP 512:
- lookahead 100 / mean 1,000 (σ 100, 500, 1,000, 2,000, 4,000 and uniform): W 400 and the controller (ε 0.001);
- lookahead 10 / mean 200 (σ 500 and 2,000): W 50 and the controller;
- uniform also with WPs 512 (its best at 16 nodes), W 400 and the controller.

2 reps, interleaved over K; 324 runs.

**B. The cost of an htram receive.** `--gvt-trace=3` at 4 and 16 nodes, W 400: uniform with WPs 512 and PP 512, σ 2,000 with PP 512; 2 reps. Each PE writes its receives over the run, split into:
- allocating the sorted message;
- finding each item's rank and copying it;
- freeing the received message;
- handing the sorted message to the other PEs (one input buffer push, under that input buffer's lock, per PE that gets items);
- dropping the receiver's own reference;
- delivering its own items (Charades' callback).

It also writes the items received, the pushes made, and its input buffer drain time. The timers add 7 clock reads per receive.

**Predictions:**
- L1. At 16 nodes, K 32 is at least 1.02× K 128 in at least 6 of the 9 fixed-W cells and in at least 6 of the 9 controller cells. K 64 lies between them.
- L2. At 1 and 4 nodes, K 32 is within ±3% of K 128 in most cells, and no cell is below 0.95.
- L3. At lookahead 10 (11,400 advances at 16 nodes, against about 8,500), K 32 gains less than at lookahead 100 and stays within ±3%.
- **Decision rule:** K 32 becomes the default if its geometric mean over all cells is at least 1.02 at 16 nodes and at least 0.99 at 1 and at 4 nodes, with no cell below 0.95.
- R1. At uniform on 16 nodes with WPs, handing the message to other PEs is the largest part of a receive, at least 40% of its time.
- R2. Allocating, freeing the received message and dropping the reference together take at most 25%.
- R3. Delivering the PE's own items takes at most 20%.
- R4. Pushes per receive match the number of distinct PEs among the message's items: about 9.8 at 12.4 events per message (23 × (1 − (22/23)^12.4)) and about 17 at 30.
- R5. Time per receive matches section 105 (WPs, 16 nodes: 8.2 µs) within 15%.

### Wave events and receive cost, results: 128 stays; a receive's fixed cost is its input buffer pushes, which slow from 0.17 to 0.70 µs each as receives get frequent (2026-10-26; skx-dev batch job 3645244, 16 nodes)

> **Status: current.** Design and predictions in section 106. 16 nodes (c455-024, c455-031 to -034, c455-041 to -044, c455-082 to -084, c455-091, c455-101 to -103; 4- and 1-node runs on the first nodes), 338 runs, all ok; 23 min. Summary `~/charades-data/sdiag/sdiag14_summary.py`, output and CSVs in `~/charades-data/sdiag/j3645244/`.

**A. `--gvt-wave-events` K ÷ 128** (PP 512 unless marked WPs; M committed events/s at K 128, mean of 2 reps; ratios higher is better):

Fixed W (400; lookahead 10: 50):

| workload | 1 node: K 128 | 32 | 64 | 4 nodes: K 128 | 32 | 64 | 16 nodes: K 128 | 32 | 64 |
|---|---|---|---|---|---|---|---|---|---|
| σ 100 | 44.4 | 0.889 | 0.899 | 167.3 | 0.976 | 0.959 | 633.1 | 0.925 | 1.011 |
| σ 500 | 38.4 | 0.846 | 0.858 | 146.8 | 0.924 | 0.912 | 552.3 | 1.014 | 1.026 |
| σ 1,000 | 35.4 | 0.880 | 0.903 | 142.9 | 0.912 | 0.919 | 512.7 | 1.017 | 0.959 |
| σ 2,000 | 33.8 | 0.858 | 0.887 | 125.1 | 0.944 | 0.959 | 442.6 | 1.007 | 1.014 |
| σ 4,000 | 33.8 | 0.845 | 0.872 | 115.4 | 0.953 | 0.947 | 424.8 | 1.016 | 1.004 |
| uniform | 35.7 | 0.845 | 0.879 | 119.9 | 0.957 | 0.971 | 211.4 | 1.132 | 1.111 |
| uniform, WPs | 36.1 | 0.858 | 0.899 | 101.8 | 1.009 | 1.031 | 288.1 | 1.007 | 1.020 |
| lookahead 10, σ 500 | 38.0 | 0.891 | 0.940 | 144.3 | 1.027 | 1.014 | 482.7 | 1.033 | 1.040 |
| lookahead 10, σ 2,000 | 33.4 | 0.948 | 0.986 | 108.5 | 1.077 | 1.076 | 369.0 | 1.024 | 1.014 |
| **geometric mean** | | **0.873** | **0.902** | | **0.974** | **0.975** | | **1.018** | **1.021** |

Controller (ε 0.001):

| workload | 1 node: K 128 | 32 | 64 | 4 nodes: K 128 | 32 | 64 | 16 nodes: K 128 | 32 | 64 |
|---|---|---|---|---|---|---|---|---|---|
| σ 100 | 46.9 | 1.012 | 0.981 | 171.8 | 1.015 | 1.009 | 614.8 | 0.993 | 0.993 |
| σ 500 | 41.6 | 1.002 | 1.001 | 154.5 | 1.019 | 1.007 | 564.1 | 0.982 | 0.989 |
| σ 1,000 | 40.3 | 1.017 | 1.009 | 145.8 | 1.021 | 1.018 | 512.5 | 0.991 | 0.974 |
| σ 2,000 | 39.1 | 1.012 | 0.999 | 132.9 | 1.005 | 1.009 | 406.9 | 0.983 | 1.005 |
| σ 4,000 | 38.5 | 1.018 | 1.010 | 119.6 | 1.014 | 1.011 | 382.6 | 0.990 | 1.008 |
| uniform | 41.7 | 1.017 | 1.009 | 130.2 | 0.968 | 0.978 | 208.1 | 1.004 | 1.007 |
| uniform, WPs | 41.0 | 1.023 | 1.005 | 104.3 | 1.081 | 1.068 | 275.1 | 1.042 | 1.053 |
| lookahead 10, σ 500 | 37.8 | 0.997 | 1.002 | 141.5 | 1.020 | 1.010 | 460.9 | 1.034 | 1.043 |
| lookahead 10, σ 2,000 | 33.5 | 1.026 | 1.031 | 109.8 | 1.021 | 1.028 | 356.9 | 1.011 | 1.016 |
| **geometric mean** | | **1.014** | **1.005** | | **1.018** | **1.015** | | **1.003** | **1.009** |

- **L1 wrong.** At 16 nodes, K 32 is ≥ 1.02 in 3 of 9 fixed-W cells and 2 of 9 controller cells, not 6. The geometric mean is 1.018 at fixed W and 1.003 with the controller.
  - The cells section 105 measured gain less here: uniform WPs at W 400 is 1.007 against 1.056, and σ 2,000 is 1.007 against 1.035. Section 105's pairs agreed within 1%, so that gain depended on the allocation.
  - K 64 is not between 32 and 128 in several cells (σ 100: 0.925 / 1.011; σ 1,000: 1.017 / 0.959).
- **L2 wrong, badly at fixed W.** On 1 node every fixed-W cell loses with K 32 (0.845–0.948, geometric mean 0.873). At 4 nodes the geometric mean is 0.974 (minimum 0.912). With the controller K 32 is neutral to slightly better (1.014 on 1 node, 1.018 on 4). The controller adjusts the window, which presumably absorbs the shorter waves. Fixed W cannot.
- **L3 wrong.** Lookahead 10 gains as much or more than lookahead 100 at 4–16 nodes (1.02–1.08).
- **Decision: K 128 stays the default.** K 32 fails the rule on 1 node (0.873 at fixed W) and at 4 nodes (0.974). Its gains at 16 nodes are small (1.003–1.018) and partly allocation-dependent.

**B. What an htram receive costs** (all PEs over the whole run; µs per receive, mean of 2 reps; lower is better):

| workload, htram | nodes | items per receive | µs per receive | allocate | find rank and copy | free received message | **hand off to other PEs** | drop own reference | own items | pushes per receive | **µs per push** | receives per PE (run) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| uniform, WPs | 4 | 29.9 | 10.3 | 0.42 | 0.89 | 0.70 | **7.90** | 0.05 | 0.34 | 15.1 | **0.52** | 29,000 |
| uniform, WPs | 16 | 12.4 | 8.5 | 0.45 | 0.46 | 1.13 | **6.16** | 0.05 | 0.18 | 8.9 | **0.70** | 77,500 |
| uniform, PP | 4 | 76.2 | 5.8 | 0.37 | 1.77 | 0.60 | **2.20** | 0.05 | 0.77 | 10.5 | **0.21** | 11,500 |
| uniform, PP | 16 | 13.8 | 7.3 | 0.43 | 0.47 | 0.84 | **5.28** | 0.05 | 0.19 | 8.5 | **0.62** | 69,300 |
| σ 2,000, PP | 4 | 49.9 | 4.0 | 0.33 | 1.21 | 0.51 | **1.38** | 0.05 | 0.45 | 8.4 | **0.17** | 9,900 |
| σ 2,000, PP | 16 | 50.0 | 3.9 | 0.32 | 1.16 | 0.48 | **1.44** | 0.05 | 0.43 | 8.4 | **0.17** | 9,800 |

(The parts add up to within 0.06 µs of the measured total. Input buffer drains on the receiving PEs cost a further 0.31–0.49 µs per item.)

- **R1 right.** Handing the message to other PEs is 73% of a receive at uniform on 16 nodes with WPs (6.2 of 8.5 µs), 72% with PP.
- **R2 right.** Allocating, freeing the received message and dropping the reference together take 19% (1.6 µs). Freeing the received message grows from 0.70 to 1.13 µs at 16 nodes: this is the cross-thread free into another PE's message pool (section 99).
- **R3 right.** The PE's own items take 2%.
- **R4 roughly right, a little low.** Pushes per receive are 8.9 at 12.4 items (predicted 9.8, or about 9.3 without the PE's own share) and 15.1 at 29.9 (predicted 17).
- **R5 right.** 8.5 µs per receive against 8.2 in section 105.
- **The cost of a push depends on how often receives happen, not on the message.**
  - At about 10,000 receives per PE over the run (σ 2,000, either node count; uniform PP at 4 nodes), a push takes 0.17–0.21 µs.
  - At 29,000 it takes 0.52 µs; at 69,000–78,000, 0.62–0.70 µs.
  - Each push takes the destination input buffer's mutex, appends to its vector and stores its pending count. At uniform on 16 nodes, all 23 PEs of a process push into the same 23 input buffers while each owner drains its own. So the extra cost is contention and cache-line transfers on the input buffers, which grow with the receive rate.
  - Hand-offs take about 77,500 × 6.2 µs ≈ 0.48 s per PE in a run with 2.6 s of execution (WPs, uniform, 16 nodes), about 18% of each PE's time. And they land unevenly per wave, on whichever PE is the late one (section 105).

**What this means for the thinning question.** The fixed per-message cost of section 105 is almost entirely the per-PE hand-off. Its size is set by contention, not by the work itself. Two ways to cut it:
1. **Make a push cheap.** Use a lock-free input buffer: one single-producer queue per (receiving PE, destination PE) pair, which the owner polls, or a multi-producer list with one atomic exchange per push. Then a push is a cache-line write, not a contended mutex. If pushes return to about 0.2 µs, a uniform receive at 16 nodes drops from 8.5 to about 4 µs. That would save roughly 0.3–0.35 s of the 2.6 s per PE, with more in the late PE's waves.
2. **Fewer pushes per event:** larger messages, from fewer destinations. 2D routing gets this only at the cost of a second hop, which also pays a receive.

(1) is local to htram's receive path and keeps one hop, so it comes first.

### Cheaper input buffer pushes: padded mutex input buffers and lock-free rings (design, 2026-10-27; written before any runs)

> **Status: design.** Charades `scale-diag` 5bd80f6 (adds `--agg-input-buffer-mode`), htram `pdes` 2d9fd13 (adds `htram_input_buffer_mode`), Reconverse `pads-dest-device` 13ae1ac with `+lci_dest_device` off. `+lci_ndevices 23`, glibc defaults. Job M `$WORK/charades-runs/diag15.slurm` (16 nodes, skx-dev and skx, `-x c455-081`, the copy that starts second cancelled).

**Why.** Section 107: 72–73% of an htram receive at uniform on 16 nodes is handing the sorted message to the other PEs, one push per PE, and a push costs 0.17 µs when receives are rare but 0.70 µs when they are frequent. Each push locks the destination PE's input buffer mutex, appends to a vector and stores a count. The 23 input buffers of a process sit next to each other in one array, about 72 bytes each, so neighbouring PEs' input buffers share cache lines.

**Change** (`--agg-input-buffer-mode`, one build for every arm; mode 0 is the default and unchanged):
- **1, padded:** the same mutex input buffer, on its own cache lines. This separates false sharing from lock contention.
- **2, rings:** one single-producer ring of 256 slots per (sending rank, receiving rank) pair in a process.
  - A push writes a slot, stores the ring's tail and sets the receiver's pending flag. There is no lock and no read-modify-write.
  - The receiving PE clears its flag and scans its 23 rings when the flag is set.
  - A full ring falls back to the mutex input_buffers; `recv_parts_<pe>.csv` counts those overflows.
  - Each PE allocates its own padded input buffer or row of rings when input-buffer delivery starts. Until then senders use the old input buffer, so no message is lost at start-up.

Mac: the input buffer configs in all three modes, PP and WPs, every model, 108/108. Ring mode repeated 10 times at 2 processes × 4 PEs on PHOLD and dragonfly, 120/120.

**Runs** (3 reps, interleaved over modes):
- Throughput at 1, 4 and 16 nodes: σ 100, σ 2,000 and uniform with PP 512, plus uniform with WPs 512; W 400 and the controller (ε 0.001). Modes 0, 1 and 2.
- Receive breakdown (`--gvt-trace=3`) at 16 nodes, W 400: uniform with WPs 512 and PP 512, modes 0, 1 and 2.

**Predictions:**
- M1. Rings cut a push at uniform on 16 nodes (WPs) from about 0.70 µs to at most 0.25, and a receive from 8.5 µs to at most 5.
- M2. Rings are at least 1.05× mode 0 at uniform on 16 nodes (both htram modes, fixed W). They are at least 0.98× at σ 100 and σ 2,000 at every node count, and within ±2% on 1 node.
- M3. Padding alone recovers less than half the rings' gain at uniform on 16 nodes (a push still costs at least 0.45 µs): the cost is mostly lock contention, not false sharing.
- M4. Fewer than 0.1% of ring pushes overflow to the mutex input buffer.
- M5. Input buffer drains cost no more than 0.05 µs per item extra with rings (0.31–0.49 µs per item in section 107), although each non-empty drain scans 23 rings.

If M2 holds, rings become the default after the full Mac matrix.

### Input buffer modes, results: lock-free rings make uniform 1.08–1.21× faster at 16 nodes (a push 0.73 → 0.17 µs); σ 2,000 with the controller 0.97× (2026-10-27; skx-dev batch job 3646589, 16 nodes)

> **Status: current.** Design and predictions in section 108. 16 nodes (c454-044, c454-071 to -074, c455-001 to -004, c455-011 to -013, c455-032 to -034, c455-041; 4- and 1-node runs on the first nodes), 230 runs, all ok; 17 min. The receive breakdown ran 2 reps per mode, not 3. Summary `~/charades-data/sdiag/sdiag15_summary.py`, output and CSVs in `~/charades-data/sdiag/j3646589/`.

**Throughput by input buffer mode** (PP 512 unless marked WPs; M committed events/s with the mutex input buffer, mean of 3 reps; ratio = mode ÷ mutex input buffer, higher is better):

| workload | arm | 1 node: mutex | padded | rings | 4 nodes: mutex | padded | rings | 16 nodes: mutex | padded | rings |
|---|---|---|---|---|---|---|---|---|---|---|
| σ 100 | W 400 | 43.3 | 1.016 | 1.018 | 167.6 | 1.002 | 0.999 | 621.7 | 1.017 | 0.968 ¹ |
| σ 2,000 | W 400 | 33.4 | 1.008 | 1.012 | 124.8 | 1.005 | 1.003 | 435.8 | 1.010 | 1.005 |
| uniform | W 400 | 35.7 | 0.998 | 0.999 | 120.7 | 0.994 | 1.000 | 229.4 | 1.058 | **1.103** |
| uniform, WPs | W 400 | 36.1 | 0.995 | 0.991 | 100.7 | 1.110 | **1.135** | 280.4 | 1.149 | **1.212** |
| σ 100 | controller | 46.9 | 0.999 | 0.996 | 170.7 | 1.002 | 1.003 | 609.3 | 1.011 | 1.014 |
| σ 2,000 | controller | 38.7 | 1.005 | 0.996 | 132.3 | 0.997 | 0.997 | 406.0 | 0.990 | **0.972** ² |
| uniform | controller | 41.5 | 1.002 | 0.996 | 130.5 | 0.991 | 0.996 | 205.1 | 1.045 | **1.082** |
| uniform, WPs | controller | 40.9 | 1.010 | 1.008 | 102.9 | 1.121 | **1.173** | 269.5 | 1.128 | **1.195** |
| **geometric mean** | | | 1.004 | 1.002 | | 1.027 | 1.036 | | 1.050 | 1.065 |

¹ Reps 534, 634, 637 against 618, 623, 624: one slow rep; without it, 1.02.
² Reps 390, 393, 400 against 405, 405, 408: consistent.

**Receives at uniform, 16 nodes, W 400** (all PEs, whole run, mean of 2 reps; µs, lower is better; throughput higher is better):

| htram | input buffer | µs per receive | hand-off | free received message | µs per push | pushes per receive | ring overflows | drain µs per item | M committed ev/s |
|---|---|---|---|---|---|---|---|---|---|
| WPs | mutex | 8.83 | 6.56 | 1.09 | 0.738 | 8.9 | — | 0.347 | 277.3 |
| WPs | padded | 5.80 | 3.29 | 1.32 | 0.373 | 8.8 | — | 0.338 | 315.6 |
| WPs | rings | 4.15 | 1.52 | 1.43 | 0.171 | 8.9 | 0 | 0.342 | 336.0 |
| PP | mutex | 7.89 | 5.88 | 0.83 | 0.691 | 8.6 | — | 0.371 | 224.7 |
| PP | padded | 4.96 | 2.93 | 0.85 | 0.343 | 8.6 | — | 0.363 | 243.5 |
| PP | rings | 3.40 | 1.39 | 0.84 | 0.162 | 8.6 | 0 | 0.364 | 250.1 |

- **M1 right.** With rings a push costs 0.16–0.17 µs (from 0.69–0.74), about what it cost in section 107 when receives were rare. A receive costs 3.4–4.2 µs (from 7.9–8.8).
- **M2 mostly right.**
  - Rings are 1.10× (PP) and 1.21× (WPs) at uniform on 16 nodes with W 400, and 1.08× and 1.20× with the controller. They are also 1.14–1.17× at uniform with WPs on 4 nodes.
  - On 1 node every cell is within ±2%.
  - Two cells at 16 nodes are below the predicted 0.98:
    - σ 100 at W 400 (0.968) comes from one slow rep.
    - σ 2,000 with the controller (0.972) is consistent across reps. At W 400 the same workload is 1.005, and its receives are rare (about 10,000 per PE, section 107), so the push cost cannot explain it. Not yet explained.
- **M3 wrong: false sharing was the larger part.** Padding alone halves a push (0.74 → 0.37 µs) and gets 70% of the rings' gain at uniform with WPs (1.149 against 1.212). The rings remove most of the rest.
- **M4 right.** No ring overflowed.
- **M5 right.** Input buffer drains cost 0.34–0.36 µs per item in every mode.
- **What remains of a receive.** Freeing the received message, 0.8–1.4 µs, is now about a third of a receive. That is the cross-thread free into another PE's message pool (section 99), and it grows with throughput (WPs: 1.09 → 1.43 µs).
- **Scaling.** Uniform with WPs at W 400 now reaches 340 M events/s on 16 nodes, against 114 on 4. That is a 4→16-node efficiency of 0.74, up from 0.70 with the mutex input buffer in this job (cross-job figures, section 95: Charades 0.52, Devastator 0.69).

**Next:**
1. Rerun σ 2,000 and σ 100 at 16 nodes, rings against mutex, with the controller and W 400, 5 reps. This settles the 0.97×.
2. If it does not hold up, make rings the default after the full Mac test matrix.
3. Then the cross-thread free.

### Rings against the mutex input buffer on all 8 scaling workloads, before making rings the default (design, 2026-10-27; written before any runs)

> **Status: design.** Charades `scale-diag` 5bd80f6, htram `pdes` 2d9fd13 (as section 108). Job N `$WORK/charades-runs/diag16.slurm` (16 nodes, skx-dev and skx, `-x c455-081`, the copy that starts second cancelled).

**Why.** Section 109: rings gained 1.08–1.21× at uniform on 16 nodes, but σ 2,000 with the controller was 0.972× in three consistent reps, and σ 100 at W 400 had one slow rep. The full Mac test matrix is skipped (user decision, 2026-10-27). Before rings become the default, they need a wider performance check than three workloads.

**Runs.** The 8 workloads of the scaling series:
- lookahead 100 / mean 1,000: σ 100, 500, 1,000, 2,000, 4,000 and uniform, at W 400 and with the controller;
- lookahead 10 / mean 200: σ 500 and 2,000, at W 50 and with the controller;
- uniform also with WPs 512.

PP 512, `--agg-input-buffer-mode` 0 against 2, interleaved. 16 nodes with 5 reps, 4 nodes with 3 reps.

**Predictions:**
- N1. σ 2,000 with the controller at 16 nodes is within ±2% with rings: section 109's 0.972 was this allocation's, not the rings'.
- N2. Rings are at least 0.98× in every cell at 4 and 16 nodes. The geometric mean is at least 1.02 at 16 nodes and at least 1.00 at 4.
- **Decision rule:** rings become the default if no cell is below 0.97 with its reps consistent (no single slow rep). The Mac change-tier tests must pass with the new default.

### Rings on all 8 workloads, results: no cell below 0.98, uniform 1.08–1.21×; rings are the default (2026-10-27; skx-dev batch job 3647086, 16 nodes)

> **Status: current.** Design and predictions in section 110. 16 nodes (c454-074, c454-081 to -084, c454-091, c455-021 to -024, c455-031 to -034, c455-041, c455-042; 4-node runs on the first four), 290 runs, all ok; 22 min. Summary `~/charades-data/sdiag/sdiag16_summary.py`, output and CSVs in `~/charades-data/sdiag/j3647086/`.

**Rings ÷ mutex input buffer** (PP 512 unless marked WPs; M committed events/s with the mutex input buffer, mean of 5 reps at 16 nodes and 3 at 4 nodes; ratio higher is better):

| workload | 16 nodes, W: mutex | rings ÷ mutex | 16 nodes, controller: mutex | rings ÷ mutex | 4 nodes, W: mutex | rings ÷ mutex | 4 nodes, controller: mutex | rings ÷ mutex |
|---|---|---|---|---|---|---|---|---|
| σ 100 | 629.4 | 1.002 | 614.3 | 0.999 | 167.0 | 0.998 | 170.3 | 0.994 |
| σ 500 | 539.2 | 0.991 | 558.3 | 0.994 | 145.8 | 1.015 | 145.7 | 1.051 ¹ |
| σ 1,000 | 506.4 | 0.996 | 497.9 | 1.001 | 141.1 | 1.001 | 146.3 | 1.002 |
| σ 2,000 | 435.2 | 1.006 | 392.4 | 0.994 | 125.7 | 0.996 | 132.1 | 0.987 |
| σ 4,000 | 419.4 | 0.999 | 363.4 | 0.993 | 114.7 | 1.005 | 119.0 | 1.006 |
| uniform | 227.5 | **1.102** | 203.5 | **1.078** | 122.2 | 0.982 | 130.8 | 0.989 |
| uniform, WPs | 273.8 | **1.207** | 260.8 | **1.208** | 99.9 | **1.149** | 104.6 | **1.158** |
| lookahead 10, σ 500 | 466.9 | 1.015 | 454.6 | 0.999 | 143.6 | 1.007 | 138.7 | 1.014 |
| lookahead 10, σ 2,000 | 357.7 | 1.004 | 342.4 | 1.008 | 109.7 | 1.009 | 108.8 | 0.998 |
| **geometric mean** | | **1.034** | | **1.028** | | **1.017** | | **1.021** |

(W 400; lookahead 10: W 50. ¹ One slow mutex rep, 131 against 153 and 153.)

- **N1 right.** σ 2,000 with the controller at 16 nodes is 0.994 (section 109: 0.972). That was the allocation.
- **N2 right.** The lowest cell is 0.982 (uniform PP, 4 nodes, W; consistent reps), so every cell is at least 0.98. The geometric mean is 1.028–1.034 at 16 nodes and 1.017–1.021 at 4.
- **Decision: rings are the default** (`--agg-input-buffer-mode=2`, Charades `scale-diag`; section 110's rule met). The test configs that named rings explicitly now name the mutex input buffer (`agg_inputbuf0_bucket_pp`, `agg_inputbuf0_bucket_wps`), so it stays tested. Mac: every `agg_*` config on the change tier, without the full matrix (user decision).

### Freeing another PE's message without its pool lock (`+mempool_remote_free`) (design, 2026-10-27; written before any runs)

> **Status: design.** Reconverse `pads-remote-free` (on `pads-dest-device`; on Stampede3 commit 22871c6 in `charm-pads-exp/contrib/reconverse`, applied as a patch, not pushed), Charades `scale-diag` with rings as the default, htram `pdes` 2d9fd13. Job O `$WORK/charades-runs/diag17.slurm` (16 nodes, skx-dev and skx, `-x c455-081`, the copy that starts second cancelled).

**Why.** Section 109: with ring input buffers, freeing the received message is about a third of an htram receive (0.8–1.4 µs; WPs at uniform on 16 nodes: 1.09 → 1.43 µs as throughput rose). LCI allocates a receive buffer from the pool of the PE that drained the network. The PE that runs the htram receive frees it, and that PE is usually another PE. Every free takes the owning pool's lock and merges neighbouring free slots under it (section 99), so the lock and the pool's metadata move between cores.

**Change** (Reconverse, `+mempool_remote_free`, off by default):
- A PE freeing a block of another PE's pool pushes it onto that pool's lock-free stack with one compare-and-swap. The stack is linked through the block's first word, which is free once the message is freed.
- The owner takes the whole stack with one exchange (so no ABA problem) at its next allocation, under the lock it takes anyway, and frees each block there.
- Frees into the PE's own pool are unchanged.

The pool header grows by one pointer. Only Reconverse's LCI2 backend uses it.

**Runs** (rings on everywhere):
- **Correctness gate first, on 2 nodes:** `test.py --tier change --launcher srun` with `CHARADES_RUN_ARGS="+mempool_remote_free --agg-input-buffer-mode=2"` (Charades `test.py` now takes extra flags from it). Configs: sequential, blocking, bucket, bucket_window, conservative, agg_blocking_pp, agg_inputbuf_bucket_pp, agg_inputbuf_bucket_wps, agg_deadline_bucket_pp, agg_ctl_sparse_bucket_pp. Core model configs.
- **Throughput with and without the flag, 3 reps:** 1, 4 and 16 nodes; σ 100, σ 2,000 and uniform with PP 512, plus uniform with WPs 512; W 400 and the controller.
- **Receive breakdown (`--gvt-trace=3`), 2 reps:** 16 nodes, uniform with WPs 512 and PP 512, W 400.

**Predictions:**
- O1. Freeing the received message falls from 1.43 µs (WPs) and 0.84 µs (PP) per receive to at most 0.3.
- O2. With the flag, uniform on 16 nodes is at least 1.03× (both htram modes). Every other cell is at least 0.99×, and on 1 node within ±2%.
- O3. The correctness gate passes.

### `+mempool_remote_free`, results: freeing a received message 1.45 → 0.30 µs; uniform 1.02–1.06× at 16 nodes; gate rerun needed (2026-10-27; skx-dev batch job 3647310, 16 nodes)

> **Status: current.** Design and predictions in section 112. 16 nodes (c454-012, c454-022, c454-032, c454-042 to -044, c454-071, c454-073, c455-043, c455-044, c455-071 to -074, c455-082, c455-083; 4- and 1-node runs on the first nodes). Throughput and receive runs: 154, all ok; 15 min. This job ran before the input-buffer rename, with `--agg-inbox-mode=2` (now `--agg-input-buffer-mode=2`, the default). Summary `~/charades-data/sdiag/sdiag17_summary.py`, output and CSVs in `~/charades-data/sdiag/j3647310/`.
>
> **The correctness gate did not test anything.** All 168 runs aborted at start-up in LCI's ibv backend ("inline size 64 is too large (maximum 0)"). `test.py` ran without `scripts/stampede3/env.sh`, which selects the psm2 transport that `ctl_sweep.sh` uses. Rerun with it as job `gate18` (below).

**Throughput, ring input buffers, with ÷ without `+mempool_remote_free`** (PP 512 unless marked WPs; M committed events/s without it, mean of 3 reps; ratio higher is better):

| workload | arm | 1 node: without | with ÷ without | 4 nodes: without | with ÷ without | 16 nodes: without | with ÷ without |
|---|---|---|---|---|---|---|---|
| σ 100 | W 400 | 44.1 | 0.994 | 166.3 | 1.008 | 624.9 | 1.011 |
| σ 2,000 | W 400 | 34.0 | 0.995 | 125.2 | 1.010 | 443.6 | 1.000 |
| uniform | W 400 | 35.7 | 1.001 | 118.9 | 1.034 | 251.6 | 1.025 |
| uniform, WPs | W 400 | 36.0 | 1.007 | 111.5 | 1.006 | 339.6 | **1.046** |
| σ 100 | controller | 46.6 | 0.999 | 170.7 | 0.999 | 611.5 | 1.003 |
| σ 2,000 | controller | 38.7 | 0.995 | 128.2 | 1.032 ¹ | 408.7 | 0.983 ² |
| uniform | controller | 41.3 | 1.005 | 129.6 | 1.014 | 221.2 | 1.018 |
| uniform, WPs | controller | 41.3 | 1.004 | 120.7 | 1.030 | 323.4 | **1.063** |
| **geometric mean** | | | 1.000 | | 1.017 | | 1.018 |

¹ One slow rep without (122 against 132 and 131). ² Reps 395, 401, 410 against 410, 407, 409: the same cell was 0.972 for rings in section 109 and 0.994 in section 111, so it moves by about ±2% between jobs.

**Receives at uniform, 16 nodes, W 400** (mean of 2 reps; µs, lower is better):

| htram | `+mempool_remote_free` | µs per receive | hand-off | free received message | drain µs per item | M committed ev/s |
|---|---|---|---|---|---|---|
| WPs | off | 4.15 | 1.50 | 1.46 | 0.350 | 326.4 |
| WPs | on | 3.05 | 1.57 | **0.30** | 0.327 | 350.7 |
| PP | off | 3.43 | 1.41 | 0.85 | 0.368 | 249.4 |
| PP | on | 2.71 | 1.26 | **0.29** | 0.352 | 255.1 |

- **O1 right, just.** Freeing the received message costs 0.29–0.30 µs instead of 0.85–1.46, at the predicted bound of 0.3. A receive now costs 2.7–3.1 µs (8.8 with the mutex input buffer in section 109). Input-buffer drains also got slightly cheaper per item (0.350 → 0.327 with WPs): their reference drops free cross-thread too.
- **O2 partly right.**
  - Uniform with WPs on 16 nodes gains 1.046 and 1.063, as predicted. With PP it gains only 1.025 and 1.018, below the predicted 1.03.
  - Elsewhere every cell is at least 0.99 except σ 2,000 with the controller on 16 nodes (0.983), a cell that moves about ±2% between jobs.
  - On 1 node every cell is within ±1%.
- **O3 not yet tested** (see the status note).
- **Uniform's 4→16 node efficiency with WPs at W 400:** 350.7 ÷ (4 × 112.2) ≈ 0.78 in this job's receive runs and 0.79 in its throughput runs (355.2 ÷ 448.8). That compares with 0.70 with the mutex input buffer (section 109) and Devastator's 0.69 (section 95, another job).

**Next.** If the gate passes, adopt `+mempool_remote_free` in the Charades launch line on Stampede3. It is a Reconverse runtime flag, so Charades' code does not change. Making it Reconverse's default is a separate decision, because it changes a pool every Reconverse program uses.

### Correctness gate for `+mempool_remote_free`, rerun with the psm2 transport (design, 2026-10-27; written before the run)

> **Status: design.** Charades `main` 8344576 (after the input-buffer rename; ring input buffers are the default), htram `pdes` 699c3a9, Reconverse 22871c6. Job `gate18` `$WORK/charades-runs/gate18.slurm` (2 nodes, skx-dev and skx).

- Pass 1: `CHARADES_RUN_ARGS=+mempool_remote_free`, `test.py --tier change --launcher srun --nodes 2`, with `env.sh` and XPORT=psm2. Configs: sequential, blocking, bucket, bucket_window, conservative, agg_blocking_pp, agg_inputbuf_bucket_pp, agg_inputbuf_bucket_wps, agg_inputbuf0_bucket_pp, agg_deadline_bucket_pp, agg_ctl_sparse_bucket_pp. Core model configs, launches 1, 4 and 2 × 2.
- Pass 2: 2 processes × 23 PEs, 5 repeats, Simple and Imbalanced PHOLD: agg_inputbuf_bucket_pp, agg_inputbuf_bucket_wps, agg_ctl_sparse_bucket_pp. This puts 23 senders on the rings, which the Mac (at most 4 PEs per process) never did.
- **Prediction G1:** every run passes. Committed counts must match the sequential runs.

### Correctness gate for `+mempool_remote_free`, results: 231/231; the flag joins the Stampede3 launch (2026-10-27; skx-dev batch job 3647898, 2 nodes)

> **Status: current.** Design in section 113. 2 nodes (c454-081, c454-082); 8 min. Output `$WORK/charades-runs/gate18/j3647898/pass1.txt` and `pass2.txt`. A transient `/work2` I/O error at job start (Slurm could not `chdir` to the submit directory) affected no run.

- Pass 1 (change tier, launches 1, 4 and 2 × 2 on 2 nodes, every model's core configs): **186/186**.
- Pass 2 (2 processes × 23 PEs, 5 repeats, Simple and Imbalanced PHOLD; ring input buffers under their real load): **45/45**.
- **G1 right.**

**Decision.** `+mempool_remote_free` joins the Stampede3 launch line. It is the new default `EXTRA_ARGS` in `scripts/stampede3/ctl_sweep.sh` (`+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free`; the old default still said 16 devices). It needs a Reconverse with the `pads-remote-free` patch, which only `charm-pads-exp` on Stampede3 has. Whether to make it Reconverse's own default, and where to publish the `pads-*` runtime patches, is open.

### What paces GVT at σ 2,000: events in transit or the late PE's work; GVT bucket size; horizon margin with wider windows (design, 2026-10-27; written before any runs)

> **Status: design.** Charades `scale-diag` cedf3d7 (new trace fields), htram `pdes` 699c3a9, Reconverse 22871c6; the current launch (`+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free`, ring input buffers). Job P `$WORK/charades-runs/diag19.slurm` (16 nodes, skx-dev and skx, `-x c455-081`, the copy that starts second cancelled).

**Why.** σ ≥ 2,000 is where Charades still scales worse than Devastator: 4→16-node efficiency 0.81 at σ 2,000 against 0.91 (section 95). Matching 0.91 at the same 4-node rate needs about 12% more throughput on 16 nodes, roughly 25 µs off a 16-node GVT advance or 12% more simulated time per advance. What is known:
- The loss is time per advance (section 78).
- Most of an advance is the late PE (section 80). After pickup it runs about 55 events at 1.9 µs each (section 105).
- Faster reductions, earlier contributions, smaller batches, asking ahead and flush order moved throughput by −12% to +6% (sections 47–60, 103).
- Section 60: buckets that every PE had passed often did not complete in the next wave because events sent into them were still in transit.

Two explanations fit:
- **(a) Aggregation-paced.** htram holds an event until GVT nears its timestamp (the deadline policy, horizon W + margin 8). So each GVT step waits for: senders learn of the update → flush what is now due → the events arrive → the next wave counts them. The late PE is late because a burst of such events reached it late.
- **(b) Statistical.** The late PE simply has the most work inside the window. The maximum over 736 PEs grows with the PE count.

**New trace fields** (off unless traced):
- PE 0's `gvt_trace.csv`, per wave: how many buckets every PE had passed at the previous wave, and the events sent into the ones of them that did not complete but not yet received (the first such bucket, and all of them).
- `--gvt-trace=4`'s `gvt_rec_<pe>.csv`, per PE per recorded wave: events received since its previous contribution, how many were within one bucket of GVT, and their mean and least distance from GVT in buckets.

Mac: trace configs 54/54.

**Runs** (PP 512, 2 reps, interleaved):
- **A. Traced** (`--gvt-trace=4 --pe-stats=1`) with untraced pairs: σ 2,000 at W 400 on 4 and 16 nodes; at W 250 and 600 on 16 nodes.
- **B. GVT bucket size** 8 (default), 16 and 32: σ 2,000 and σ 4,000, W 400 and the controller, 4 and 16 nodes. Never varied before.
- **C. Horizon margin** 4, 8 and 16 with W 400 and 600: σ 2,000, 16 nodes. Section 80 varied the margin alone (8, 32, 64, 128), at W 250.

**Predictions:**
- P1. At 16 nodes, in at least half of the waves some bucket that every PE had passed at the previous wave stays open with events in transit. At 4 nodes, in fewer waves.
- P2. Since its previous contribution, the late PE has received at least 1.5× the events of the median PE of its process, and a larger share of them within one bucket of GVT.
- If P1 and P2 hold, GVT is aggregation-paced, and the fix is to send the events GVT will need next before it needs them (candidate (a)). If both are wrong, the straggling is statistical, and the fix is sharing work within a process (candidate (b)).
- P3. Bucket size 16 and 32 change throughput by less than 5% either way.
- P4. No margin and window pair in C beats margin 8 at W 400 by more than 3%.

### What paces GVT at σ 2,000, results: neither transit nor a growing straggler; the cross-process reduction (34 → 70 µs) is the whole 4→16-node loss (2026-10-27; skx-dev batch job 3649213, 16 nodes)

> **Status: superseded in part by section 120:** the measurements stand, but the conclusion that the reduction floor causes the 4→16-node loss is wrong (the floor overlaps the late PE's work). Design and predictions in section 115. 16 nodes (c454-013, c454-022, c454-032, c454-033, c454-072, c454-073, c454-084, c454-092, c454-093, c454-101, c455-004, c455-011, c455-031 to -033, c455-071; 4-node runs on the first four), 78 runs, all ok; 8 min. Current launch (`+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free`, ring input buffers). Summary `~/charades-data/sdiag/sdiag19_summary.py`, output and CSVs in `~/charades-data/sdiag/j3649213/`; the advance split below was computed inline from the `gvt_waves_*.csv` files, as in section 80.

**Throughput, σ 2,000, PP 512** (M committed events/s, mean of 2 reps; higher is better): W 400: 125.4 on 4 nodes and 442.5 on 16, a **4→16-node efficiency of 0.88** (0.81 in section 95 under the old launch; Devastator 0.91 there). On 16 nodes, W 250 is 403.8 (0.91× W 400) and W 600 is 392.2 (0.89×). Traced ÷ untraced: 0.95–0.99.

**A GVT advance, split** (µs, waves 10–95%, both reps; lower is better; definitions as in section 80):

| W | nodes | advance | reduction floor | median process work | slowest process work | straggler cost | spread inside the slowest process |
|---|---|---|---|---|---|---|---|
| 400 | 4 | 196 | 34 | 55 | 161 | 106 | 145 |
| 400 | 16 | 226 | **70** | 43 | 154 | **111** | 138 |
| 250 | 16 | 198 | 60 | 32 | 136 | 104 | 126 |
| 600 | 16 | 280 | 62 | 42 | 217 | 174 | 194 |

**Waves** (PE 0's trace): in every wave at every setting, all buckets that every PE had passed at the previous wave complete (W 400: 8.7 per wave on 4 nodes, 9.6 on 16). No passed bucket was ever left open with events in transit.

**The late PE against the median PE of its process** (W 400): the late PE contributes 157–159 µs after the result on both 4 and 16 nodes, after running 92 (4 nodes) or 54 (16 nodes) events since picking the result up. The median PE runs about 1 event and contributes after 21–23 µs. The late PE picks the result up later on 16 nodes (41 against 19 µs; it is in the middle of a scheduler pass). Since its previous contribution it has received 1.07× (4 nodes) to 1.24× (16 nodes) the events of the median PE. **None of either PE's arrivals came within one bucket of GVT**: they arrive on average about 160 buckets (1,300 time units) ahead of it. Rank 0 is the most frequent late PE (0.12–0.21 of waves; the lower-edge effect of sections 84–103).

**B. GVT bucket size** (÷ bucket 8, PP 512, mean of 2 reps; higher is better): 16 and 32 are 0.976–1.010 in all 16 cells (σ 2,000 and 4,000, W 400 and the controller, 4 and 16 nodes).

**C. Horizon margin × window** (σ 2,000, 16 nodes; ÷ margin 8 at W 400; higher is better):

| margin | W 400 | W 600 |
|---|---|---|
| 4 | 1.007 | 0.898 |
| 8 | 1.000 (438.6 M ev/s) | 0.896 |
| 16 | 0.996 | 0.886 |

Efficiency is 99.84–99.93% at W 400 and 99.0–99.1% at W 600. Events per message are 43–51 at W 400 and 25–27 at W 600.

- **P1 wrong.** GVT never waits on events in transit; every passed bucket completes in the next wave.
- **P2 wrong.** The late PE received only 1.07–1.24× the median PE's events, and none of them close to GVT. So GVT is not aggregation-paced (explanation (a) is out).
- **Explanation (b) is half right.** The straggler is real (about 110 µs of a 226 µs advance): one PE still has events inside the window while the rest are blocked by it. But **it no longer grows with the node count** (106 → 111 µs, slowest process work 161 → 154). In section 80, under the old launch, it grew by 40 µs.
- **What grows is the reduction floor: 34 → 70 µs, the whole +30 µs per advance from 4 to 16 nodes.** This is the slowest process's wait from its last PE's contribution to the published result: the combine across 32 processes and the result's way back. Section 52 found an all-reduce no faster than the nodegroup reduction (0.96–1.02×) when the straggler dominated. The straggler's growth is gone now, so the floor is what limits scaling.
- **P3 right.** Bucket size changes nothing (−2.4% to +1.0%).
- **P4 right.** The margin changes nothing at W 400 (±0.7%), and a wider window loses 10–11% at any margin.

**Next (withdrawn in section 120: the floor is not on the critical path).** Make the cross-process combine fast. A 32-process reduction of a few hundred bytes should take about 10–15 µs on Omni-Path, not 70.
1. Measure where the 70 µs goes, per hop: the message in flight, waiting for a PE to run the nodegroup handler (PEs run handlers only between scheduler passes of up to 16 events, about 30 µs), and combining.
2. Then reduce what dominates. If it is waiting for a PE, run GVT reduction messages promptly: check for them inside the execute loop, or give them to the free core each process already leaves idle. If it is hops, use fewer: the existing recursive doubling (`--gvt-wave-allreduce`, 5 hops), a two-level exchange (2 hops), or one all-to-all exchange of counts (1 hop, 31 small messages per process per wave).

### Where the cross-process reduction's 70 µs goes: Charades' own process tree with per-hop times; a flat tree; smaller scheduler passes (design, 2026-10-27; written before any runs)

> **Status: design.** Charades `scale-diag` (this commit: `--gvt-wave-tree`), htram `pdes` 699c3a9, Reconverse 22871c6; the current launch (`+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free`, ring input buffers). Job Q `$WORK/charades-runs/diag20.slurm` (16 nodes, skx-dev and skx, `-x c455-081`, the copy that starts second cancelled).

**Why.** Section 116: at σ 2,000 the reduction floor (the slowest process's wait from its last PE's contribution to the published result) grows from 34 µs on 4 nodes to 70 µs on 16, and that is the whole 4→16-node loss. A combine of a few hundred bytes across 32 processes should take about 10–15 µs on Omni-Path.

**How the reduction runs now.** The last PE of a process combines its PEs' counts and sends them to its own process's nodegroup handler (one hop through the node queue). The handler contributes to the Charm++ nodegroup reduction, which goes up a spanning tree of processes with fan-out 4 (`ST_RecursivePartition`, about 2 levels at 8 processes and 3 at 32). The result comes back down Reconverse's spanning-tree node broadcast. Every hop is a nodegroup message that waits until some PE of the receiving process runs it, and PEs run messages only between scheduler passes of up to 16 events (`--batch`, about 30 µs on the late PE). These hops are inside Charm++ and cannot be timed from Charades.

**New option `--gvt-wave-tree=k`** (with `--gvt-node-waves`; 0, the Charm++ reduction, stays the default):
- The processes form a k-ary tree rooted at process 0 (children of p are pk+1 … pk+k). The partial sums go up it in Charades' own messages and the result comes back down the same tree; k ≥ processes − 1 is one gather to process 0 and one scatter (2 hops).
- No hop to the process's own handler: the last PE in adds its process's sums itself, under a lock. Inputs from children are added by whichever PE runs their message.
- `--gvt-trace=2` writes `gvt_hops_<process>.csv`: every input (a child's sums, the parent's result, this process's own sums) with the sender's send time and this process's receive time, and when each process sent on. Clocks differ between nodes, so each parent–child pair's offset is taken offline from the fastest up and fastest down hop in windows of 200 waves (the two directions' fastest hops are assumed equal). A hop's time beyond its pair's fastest is time spent waiting for a PE to run it, or in network queues.
- `gvt_waves_<process>.csv` gains `handled_s`: when the process's handler took its own sums (the Charm++ path's first hop).

Mac: 54/54 on the tree configs (2, 3, 4 processes × 2 PEs; fan-out 2 and 64; bucketed, window, PP aggregation, controller, trace 2), and 252/252 on a 20-repeat pass. The job first runs the same configs through `test.py` on 2 nodes with the psm2 transport and stops if any fails.

**Runs** (σ 2,000, W 400, PP 512, 2 reps, interleaved; 4 and 16 nodes):
- **A. Reduction:** the Charm++ reduction; `--gvt-wave-tree=4` (about as deep as the Charm++ tree); `--gvt-wave-tree=64` (flat); `--gvt-wave-allreduce=1` (recursive doubling, 3 or 5 rounds). Each traced (`--gvt-trace=2`) and untraced.
- **B. Smaller passes:** `--batch` 4 and 8 (default 16) with the Charm++ reduction, untraced; traced at 16 nodes.
- **C. Other workloads, 16 nodes:** σ 4,000 (PP 512) and uniform (WPs 512), W 400 and the controller, the Charm++ reduction against the flat tree, untraced.

**Predictions:**
- P1. On the Charm++ path, the first hop (last PE → its process's handler) has a median under 3 µs at both node counts: the floor is in the cross-process hops.
- P2. With `--gvt-wave-tree=4` at 16 nodes, the median hop is at least twice its pair's fastest hop (fastest about 3–5 µs, median 8–15 µs): hops wait for a PE to run them.
- P3. The fan-out-4 tree's floor is within 15% of the Charm++ reduction's at 16 nodes, so its hops stand for the Charm++ ones.
- P4. The flat tree's floor at 16 nodes is at most 45 µs, and its throughput at least 1.05× the Charm++ reduction's (σ 2,000, 16 nodes); within ±3% at 4 nodes. In C, no cell below 0.97×.
- P5. If hops wait for PEs (P2), `--batch=4` lowers the 16-node floor by at least 10 µs; its throughput is within ±5% of batch 16, because every pass costs a scheduler turn.
- P6. Recursive doubling stays within ±4% of the Charm++ reduction (section 52).

If P2 and P4 hold, the fix is the flat tree (or a 2-level one) plus prompt handling of GVT messages; if hops are fast and the flat tree does not help, the floor is in the network or the send path, and the next step is timing Reconverse's send and receive of these messages.

### Where the reduction's time goes, results: a hop's network time is about 4 µs; the rest is waiting for a PE to run the message. Fewer hops do not help (2026-10-27; skx-dev batch job 3649717, 16 nodes)

> **Status: current.** Design and predictions in section 117. 16 nodes (c454-004, c454-023, c454-034, c454-041 to -043, c454-074, c454-081, c454-102, c454-104, c455-012, c455-014, c455-073, c455-074, c455-091, c455-092; 4-node runs on the first four), 62 runs, all ok; gate 54/54 on 2 nodes (psm2); 8 min. Summaries `~/charades-data/sdiag/j3649717/sdiag20_summary.py` and `sdiag20_crit.py`, with their output (`summary.txt`, `crit.txt`) and the CSVs. The traces stay in `$WORK/charades-runs/sdiag20/j3649717`.

**Throughput and a GVT advance, σ 2,000, W 400, PP 512** (mean of 2 reps; advance and floor in µs, waves 10–95%, from the traced runs; floor as in section 116):

| reduction | M ev/s, 4 nodes | M ev/s, 16 nodes | ÷ Charm++ reduction, 16 nodes (higher is better) | efficiency 4→16 | advance, 4 / 16 nodes (lower is better) | floor, 4 / 16 nodes (lower is better) |
|---|---|---|---|---|---|---|
| Charm++ reduction (default) | 126.3 | 443.6 | 1.000 | 0.88 | 194 / 223 | 32.8 / 71.8 |
| `--gvt-wave-tree=4` | 125.9 | 441.4 | 0.995 | 0.88 | 195 / 227 | 31.8 / 77.6 |
| `--gvt-wave-tree=64` (flat) | 123.8 | 379.4 | **0.855** | 0.77 | 198 / 253 | 26.5 / 54.8 |
| `--gvt-wave-allreduce=1` | 125.9 | 436.6 | 0.984 | 0.87 | 192 / 219 | 15.1 / 36.7 |

Traced ÷ untraced: 0.985–0.995. Recursive doubling's floor is not comparable with the others: the slowest process finds its partners' sums already waiting, so its own wait is short, but the other processes wait for its sums to spread through all 5 rounds. Its advance is the fair measure, and that is no better.

**Per hop, tree with fan-out 4** (µs, offset-corrected; lower is better):

| nodes | up: fastest / median / p90 | down: fastest / median / p90 | on the path the slowest process waits on, beyond the pair's fastest (mean): up / down |
|---|---|---|---|
| 4 | 3.9 / 14.0 / 29.0 | 3.9 / 7.5 / 20.1 | 13.0 / 6.8 |
| 16 | 4.0 / 12.7–15.4 / 25.8–30.3 | 4.0 / 7.8–8.3 / 20.6–21.6 | 16.5 / 7.1 |

- The ranges at 16 nodes are over the 3 tree levels; the level makes no difference.
- The first hop on the Charm++ path (last PE → its process's handler) takes 3.8–4.1 µs (median); with the tree it is 1.7 µs, a lock.
- Every PE of a process runs hops about equally often (each rank 0.04–0.05 of them).
- At 76–81% of tree nodes, the last input to arrive is the process's own PEs. The child's sums come last on the path from the slowest process to the root.

**What the hops add up to** (16 nodes, fan-out 4, 3 levels): 6 hops at about 4 µs is 24 µs of network time. The rest of the 72–78 µs floor is the critical path's up hops waiting about 16 µs each and its down hops about 7 µs each, plus the 2–4 µs first hop. Up hops wait longer because they arrive while the parent's PEs are still executing their passes. Down hops arrive when most PEs are blocked on the window and back in the scheduler often.

**Flat tree:** the root's 31 sends of the result take 45 µs from first to last (1.5 µs each, serially), and 31 children's sums arriving at one process wait longer (up median 18 µs). So the 2-hop tree loses 15% at 16 nodes.

**B. Smaller scheduler passes** (Charm++ reduction; ÷ batch 16; higher is better):
- **Batch 4:** 0.894 (4 nodes), 0.893 (16 nodes); 16-node floor **71.8 → 44.0 µs**, advance 223 → 241 µs.
- **Batch 8:** 0.932 (4 nodes), 0.960 (16 nodes); 16-node floor 51.3 µs, advance 222 µs.

The floor falls with the pass size, so the hops wait for a pass to end. But smaller passes on every PE cost more than they save.

**C. Flat tree ÷ Charm++ reduction, 16 nodes** (higher is better): σ 4,000 0.847 (W 400) and 0.910 (controller); uniform 0.998 and 0.956.

- **P1 half right.** The first hop is 3.8–4.1 µs, a little over 3. But it is a small part of the floor; the floor is in the cross-process hops.
- **P2 right.** Fastest hop about 4 µs, median up hop 13–15 µs (3.5×), median down hop 7.5–8 µs (2×).
- **P3 right.** The fan-out-4 tree's floor is 8% above the Charm++ reduction's (77.6 against 71.8 µs), at 0.995× the throughput. Its hops stand for the Charm++ ones.
- **P4 wrong.** The flat tree is 0.855× at 16 nodes and 0.98× at 4; C goes down to 0.847×. Serial sends and fan-in at the root cost more than the hops saved.
- **P5 right on the floor (−28 µs at batch 4), wrong on the throughput.** Batch 4 is 0.89× and batch 8 0.96×.
- **P6 right.** Recursive doubling: 0.984× (16 nodes), 0.996× (4 nodes).

**Next.** At 4 µs a hop, the 16-node floor would be about 26 µs instead of 72 µs, which is 20% of a 223 µs advance. Reconverse has no immediate messages and no communication thread: a message waits until the PE that polls its network device, and then some PE of the process, comes back to the scheduler. Candidates:
1. **Shorter passes only while a wave is in flight.** A PE whose process has contributed runs passes of 2–4 events until the result arrives. This is a Charades change of about 20 lines. Batch 4 everywhere cut the floor by 28 µs; this would pay the smaller passes' cost only during the wave, but only if the PEs that must run the hops are the ones taking shorter passes.
2. **Find which wait it is:** the device poll or the queue. Time stamp in Reconverse when the receiving PE takes the message off its device, against when the handler starts.
3. **Run GVT messages on the free core.** One core per process is unused (2 × 23 PEs on 2 × 24 cores). A Reconverse thread there could poll the devices and run messages marked immediate at once. This is the most complete fix, but the largest change.

### Shorter scheduler passes only while a count wave is in flight (`--wave-batch`) (design, 2026-10-27; written before any runs)

> **Status: design.** Charades `scale-diag` (this commit: `--wave-batch`, `--wave-batch-when`), htram `pdes` 699c3a9, Reconverse 22871c6; the current launch. Job R `$WORK/charades-runs/diag21.slurm` (16 nodes, skx-dev and skx, `-x c455-081`, the copy that starts second cancelled).

**Why.** Section 118: each hop of the cross-process reduction takes about 4 µs on the network but waits for a PE to come back to the scheduler. On the critical path, the wait is about 16 µs per up hop and 7 µs per down hop. `--batch=4` on every pass cut the 16-node floor from 72 to 44 µs but cost 11% overall.

**New option `--wave-batch=k`** (with `--gvt-node-waves`; 0, off, is the default): the scheduler pass is k events instead of `--batch` (16) while a count wave is in flight.
- `--wave-batch-when=0` (default): from when this process's combined sums are sent until its result is published. Every PE of the process has contributed by then, so every PE that could run a hop for it takes short passes. The process also takes short passes while it combines its children's sums, and when the result reaches it, its PEs pick the result up sooner.
- `--wave-batch-when=1`: from when this PE contributes until it runs the result. This also covers the PEs that contribute early and wait for the late PE of their own process.
- A short pass that runs all k events counts as full, so the idle flush and GVT trigger behave as with a full pass of 16.

Mac: 30/30 on the new configs and their bases (1×4, 2×2, 4×2), and 258/258 on a 20-repeat pass. The job first runs them through `test.py` on 2 nodes with the psm2 transport and stops if any fails.

**Runs** (2 reps, interleaved; Charm++ reduction unless stated):
- **A. σ 2,000, W 400, PP 512, 4 and 16 nodes, untraced:** batch 16 (the baseline); `--wave-batch` 2, 4 and 8 (when 0); `--wave-batch=4 --wave-batch-when=1`.
- **A'. Traced (`--gvt-trace=2`), 16 nodes:** the baseline, `--wave-batch=4` (both triggers), and `--gvt-wave-tree=4` with and without `--wave-batch=4` (for the per-hop times).
- **B. Other workloads, 16 nodes:** σ 100 and σ 4,000 (PP 512) and uniform (WPs 512), W 400 and the controller, the baseline against `--wave-batch=4`.

**Predictions:**
- P1. `--wave-batch=4` cuts the 16-node floor from about 72 µs to 50 µs or less.
- P2. Its throughput at 16 nodes (σ 2,000) is at least 1.04× the baseline, and at 4 nodes at least 1.00×. A wave is in flight for about a third of each advance, so a third of batch 4's 11% cost, about 4%, against a floor about 22 µs (10% of an advance) shorter.
- P3. `--wave-batch-when=1` is no better than when 0. Early PEs take short passes for most of the wave, which costs more and does not shorten the hops.
- P4. In the fan-out-4 tree, the critical-path up-hop wait falls from about 16 µs to 8 µs or less, and the down-hop wait from about 7 µs to 4 µs or less.
- P5. In B, no cell is below 0.98×.

If P1 and P2 hold, `--wave-batch` becomes the default at the best k and goes into the paper-grade rerun. If the floor falls but throughput does not rise, the short passes cost too much, and the next step is the free core (section 118, candidate 3).

### `--wave-batch`, results: the floor falls by 27 µs but the advance does not; the floor was never on the critical path. The late PE's 128 events pace each advance (2026-10-27; skx-dev batch job 3650537, 16 nodes)

> **Status: superseded in part by section 121:** the `--wave-batch` measurements and the count-paced advance stand; the late PE's steady loss is 4% of simulated time, not the 4→16-node loss, and the arrival-burst explanation fails (htram receives are 0.5–2.1 µs per wave). Design and predictions in section 119. 16 nodes (c454-014, c454-024, c454-033, c454-084, c454-091, c454-092, c454-103, c455-003, c455-004, c455-011, c455-014, c455-031 to -033, c455-043, c455-044; 4-node runs on the first four), 56 runs, all ok; 7 min. Gate 30/30 at the second try. The first attempt in this job, and job 3650177 before it, each lost one test to /work2 failing to read `liblci-ucx.so` (Input/output error); the job now reruns the gate once when that is the only failure. Summary `~/charades-data/sdiag/j3650537/sdiag21_summary.py`, output and CSVs alongside.

**A. Throughput, σ 2,000, W 400, PP 512, Charm++ reduction** (M committed ev/s, mean of 2 reps; ÷ batch 16; higher is better):

| pass size | 4 nodes | ÷ batch 16 | 16 nodes | ÷ batch 16 | efficiency 4→16 |
|---|---|---|---|---|---|
| batch 16 (default) | 127.0 | 1.000 | 443.8 | 1.000 | 0.87 |
| `--wave-batch=2` | 119.2 | 0.939 | 404.9 | 0.912 | 0.85 |
| `--wave-batch=4` | 122.5 | 0.965 | 414.2 | 0.933 | 0.85 |
| `--wave-batch=8` | 124.8 | 0.983 | 434.6 | 0.979 | 0.87 |
| `--wave-batch=4`, when 1 | 119.1 | 0.938 | 410.6 | 0.925 | 0.86 |

**A'. A GVT advance, 16 nodes, traced** (µs, waves 10–95%, both reps; lower is better):

| setting | advance | floor | critical-path wait per hop, up / down (mean) |
|---|---|---|---|
| batch 16 | 224 | 74.9 | — |
| `--wave-batch=4` | 226 | **47.9** | — |
| `--wave-batch=4`, when 1 | 231 | 39.4 | — |
| tree 4, batch 16 | 223 | 75.3 | 17.5 / 8.7 |
| tree 4, `--wave-batch=4` | 226 | 50.4 | **8.8** / 6.1 |

**B. `--wave-batch=4` ÷ batch 16, 16 nodes** (higher is better): σ 100 0.984 (W 400) and 0.956 (controller); σ 4,000 0.927 and 0.976; uniform 0.937 and 0.966.

- **P1 right.** The floor falls from 75 to 48 µs (39 µs with when 1).
- **P2 wrong.** Throughput falls: 0.933× at 16 nodes and 0.965× at 4. **The advance stays at 224–226 µs** although the floor is 27 µs shorter.
- **P3 right.** When 1 is no better (0.925×).
- **P4 right on the up hops** (17.5 → 8.8 µs). The down hops improve less (8.7 → 6.1 µs, prediction ≤ 4).
- **P5 wrong.** σ 4,000 and uniform at W 400 drop to 0.927–0.937×.

**Why the advance did not shrink: section 116's split was an accounting identity, not a critical path.** The late PE contributes by count, after 128 events since its previous contribution, in 93–99% of waves (section 116). So the time between its contributions, which is the advance, is the time it takes to run 128 events. The reduction runs while it keeps executing. A shorter floor means it picks the result up earlier, but it still contributes only after its 128th event. From section 116's records (job 3649213, W 400; assuming 128 events between contributions):

| nodes | advance (µs) | per event, overall (µs; lower is better) | per event before it picks up the result (µs) | per event after it picks up the result (µs) | arrivals per wave, late PE ÷ median PE |
|---|---|---|---|---|---|
| 4 | 196 | 1.53 | 1.56 (36 events) | 1.52 (92 events) | 1.07 |
| 16 | 226 | 1.77 | 1.48 (74 events) | **2.15** (54 events) | 1.24 |

So the 4→16-node loss is the late PE running its events more slowly after it picks up each result: 2.15 against 1.52 µs per event, about +30 µs per advance. That is when GVT has just advanced, the other PEs leave the window and send, and the late PE receives a burst (174 arrivals per wave on 16 nodes against 144 on 4). **The reduction floor is not the cause, and section 116's "Next" is withdrawn.** The section 116 numbers themselves stand. Section 118's per-hop times stand too: hops do wait for a PE, but that wait is hidden behind the late PE's work.

`--wave-batch` stays off (default 0). The option and `--gvt-wave-tree` remain as diagnostics.

**Next.** Find what slows the late PE after pickup on 16 nodes: receiving (the htram receive parts and input-buffer drains, `--gvt-trace=3`'s per-PE timers), rollbacks, or fossil collection, split by before and after pickup. Then make that PE cheaper, or give it less: the late PE is rank 0 in 15–18% of waves (the lower-edge effect, sections 84–103).

### Closure check: 78% of σ 2,000's 4→16-node loss is in the first 10% of waves, which sections 116–120 left out; a warm-up test and long runs (analysis of existing traces and design, 2026-10-27; written before any runs)

> **Status: design.** No new runs for the analysis: job 3649717's traced runs (`--gvt-trace=2`) and job 3649213's (`--gvt-trace=4`). Scripts `closure.py`, `startup.py`, `startup_split.py`, `startup_late.py`, `late_split.py` in `~/charades-data/sdiag/j3650537/` (copies in `$WORK/charades-runs`). Job S: Charades `scale-diag` (this commit: `--warmup-pings`), htram `pdes` 699c3a9, Reconverse 22871c6, the current launch; `$WORK/charades-runs/diag22.slurm` (16 nodes, skx-dev and skx, `-x c455-081`, the copy that starts second cancelled).

**Why the last three jobs went in a circle.** Sections 116–120 explained σ 2,000's 4→16-node loss (efficiency 0.88) from waves 10–95% of each run, and never checked that those waves hold the loss. They do not:

| σ 2,000, W 400, Charm++ reduction (job 3649717, traced, mean of 2 reps) | first 10% of waves (s) | waves 10–95% (s) | last 5% (s) | whole run, `exec_s` (s) |
|---|---|---|---|---|
| 4 nodes | 0.172 | 1.208 | 0.065 | 1.445 |
| 16 nodes | 0.336 | 1.254 | 0.063 | 1.655 |
| 16 − 4 nodes | **+0.164 (78% of the loss)** | +0.046 (22%) | −0.002 | +0.210 |

Waves 10–95% cover the same simulated time on 4 and 16 nodes (a 16-node wave completes 9.6 buckets against 8.7, and there are fewer of them). So their efficiency is 1.208 ÷ 1.254 = **0.96**. Section 120's "+30 µs per advance" overstated the steady loss for the same reason: per advance it is 15%, but per unit of simulated time it is 4%.

**The start-up waves.**
- **Shape:** on 16 nodes, the time above the steady median decays smoothly over the first ~1,000 waves, from 46–48 ms per 100 waves to 7–13 ms. It is not a few long stalls: waves over 1 ms hold only 18–25 ms. On 4 nodes it is 18–21 ms in the first 100 waves and 2–11 ms after. The flat and fan-out-4 trees look the same.
- **It is in the PEs' work, not the reduction.** In the first 200 waves on 16 nodes, the slowest process's last PE comes in 570–590 µs after the previous result, against 340 µs then 180 µs on 4 nodes. The spread inside that process is 550–570 µs; the floor stays at 50–80 µs.
- **The late PE is busy outside Charades' code.** First 10% of waves, job 3649213, `--gvt-trace=4`, µs from picking up the result to contributing:

| late PE | after pickup | event execution | htram receive handlers | everything else | events | per event in execution |
|---|---|---|---|---|---|---|
| 4 nodes, start-up | 187 | 107 | 2.0 | 78 | 80 | 1.33 |
| 4 nodes, steady | 140 | 120 | 2.1 | 18 | 92 | 1.30 |
| 16 nodes, start-up | 364 | 62 | 0.5 | **302** | 42 | 1.47 |
| 16 nodes, steady | 116 | 77 | 1.6 | 37 | 54 | 1.43 |

"Everything else" is time outside `execute()`, outside htram's receive handlers and outside the GVT nodegroup handlers. That is the runtime's own loop: network progress, message allocation and freeing, and any other messages. It is about 4× larger during start-up on 16 nodes than on 4, and it fades. Something warms up, and its cost grows with the number of processes. Candidates: the psm2 endpoints connecting to their peers on first use (each process has 23, so 736 on 16 nodes against 184 on 4), or the message pools growing.

Section 120's arrival-burst explanation also fails this check: the late PE spends 0.5–2.1 µs per wave in htram receives.

**Method, from now on.** A diagnosis must:
1. state what share of the measured loss it accounts for (closure);
2. be tested by a perturbation that moves the total by the predicted amount, before any fix is built.

Splits within part of a run (for example floor + work, or waves 10–95%) are descriptions, not causes.

**New option `--warmup-pings=N`** (diagnostic, 0 = off): before the clock starts, every PE sends N empty messages to every PE, under the quiescence that already gates the start. On 16 nodes that is 736 × 736 messages per round. This is a test, not a fix: it warms whatever the first messages between two PEs warm (connections, pools), whatever the mechanism. Mac: 48/48 (4 models, 1×1, 1×4, 2×2, 4×2).

**Runs** (σ 2,000, W 400, PP 512, Charm++ reduction, 2 reps, interleaved):
- **A. Warm-up:** `--warmup-pings` 0 and 1, 4 and 16 nodes, short runs (end time 512,000), untraced; and traced (`--gvt-trace=2`) on 16 nodes.
- **B. Long runs:** end time 2,048,000 (4× longer), `--warmup-pings` 0 and 1, 4 and 16 nodes, untraced; traced on 16 nodes without warm-up.
- **C. Closure on the other workloads,** short runs, traced (`--gvt-trace=2`), 4 and 16 nodes: uniform (WPs 512) and σ 4,000 (PP 512), W 400; untraced with `--warmup-pings` 0 and 1.

**Predictions:**
- P1. **Long runs:** if the start-up excess is a fixed cost (about 0.16 s), 4→16-node efficiency at 4× the length is 0.93–0.95 (from the table: (0.172 + 4 × 1.208 + 0.065) ÷ (0.336 + 4 × 1.254 + 0.063) = 0.94). If it stays at 0.90 or below, the excess is not a start-up cost.
- P2. **Warm-up:** if the start-up excess is warming connections or pools, `--warmup-pings=1` cuts the 16-node first 10% of waves from 0.34 s to 0.22 s or less, and short-run efficiency rises to 0.92 or more. If it does not, the pings do not warm what is slow. The next step is then a Reconverse-level split of the runtime's loop during start-up (network progress, allocation, other handlers), not a fix.
- P3. The pings run before the clock, so on 4 nodes `exec_s` changes by less than 2%.
- P4. **Closure on the other workloads:** σ 4,000's loss is also mostly in the first 10% of waves. Uniform's is mostly in waves 10–95%: its fixed input-buffer cost (sections 107–113) was a steady effect.

What follows from the results: if P1 holds, the paper-grade rerun's long runs already remove most of the σ 2,000 gap. Devastator must then be measured on the same long runs, because its own start-up is in its 0.91 too. If P2 holds as well, a warm-up phase (or eager connection) becomes part of Charades' start.

### Warm-up and long runs, results: in 4× longer runs σ 2,000 scales at 0.96–0.97 and σ 4,000's loss is all start-up; warm-up pings do nothing; uniform's loss is steady (2026-10-27; skx-dev batch job 3650843, 16 nodes)

> **Status: current.** Design and predictions in section 121. 16 nodes (c454-004, c454-012, c454-013, c454-024, c454-031, c454-032, c454-074, c454-081, c455-014, c455-021 to -023, c455-093, c455-094, c455-101, c455-102; 4-node runs on the first four), 48 runs, all ok; gate 24/24; 7 min. Summary `~/charades-data/sdiag/j3650843/sdiag22_summary.py`, with `summary.txt` and the CSVs.

**σ 2,000, W 400, PP 512** (M committed ev/s, mean of 2 reps; higher is better; `exec_s` in s, lower is better):

| run length | warm-up pings | 4 nodes | 16 nodes | efficiency 4→16 | `exec_s`, 4 / 16 nodes |
|---|---|---|---|---|---|
| short (end time 512,000) | 0 | 121.3 (125.6, 116.9) | 442.1 | 0.91 | 1.495 / 1.635 |
| short | 1 | 126.5 | 444.3 | 0.88 | 1.430 / 1.630 |
| **long (end time 2,048,000)** | 0 | 131.8 | **512.4** | **0.97** | 5.495 / 5.655 |
| long | 1 | 131.8 | 505.0 | 0.96 | 5.490 / 5.735 |

The short warm-up-0 cell's second 4-node rep (116.9) is slow; without it the short efficiency is 0.88 at both settings, as in sections 116–120. Long ÷ short (warm-up 0): 1.09× on 4 nodes, **1.16× on 16 nodes**.

**Where the 16 − 4-node difference sits** (traced, short runs, s; closure as in section 121):

| workload | whole run | first 10% of waves | waves 10–95% | last 5% | efficiency over waves 10–95% |
|---|---|---|---|---|---|
| σ 2,000 (section 121) | +0.210 | +0.164 (78%) | +0.046 (22%) | −0.002 | 0.96 |
| σ 4,000 | +0.110 | +0.109 (99%) | +0.004 (3%) | −0.002 | 1.00 |
| uniform (WPs 512) | +0.485 | +0.073 (15%) | **+0.391 (81%)** | +0.017 | 0.77 |

**Start-up shape.** On 16 nodes the decay is the same with and without pings, and in the long runs: the time above the steady median per 100 waves goes from about 50 ms to 9–14 ms over the first 1,000 waves. It is a fixed transient at the start of every run. In absolute terms it does not grow with run length: the 16 − 4-node `exec_s` difference is 0.14–0.20 s in short runs and 0.16–0.25 s in long ones.

**Warm-up on the other workloads** (short runs; pings ÷ none; higher is better): uniform 0.987 (4 nodes), 1.004 (16 nodes); σ 4,000 0.992, 0.990.

- **P1 right, and more so than predicted.** In long runs σ 2,000's efficiency is 0.96–0.97 (predicted 0.93–0.95): the start-up excess is a fixed cost, and long runs dilute it.
- **P2 wrong.** The pings change neither the start-up (0.339 → 0.333 s in the first 10% of waves) nor throughput (1.005× on 16 nodes). Whatever is slow at start-up is not warmed by one small message between every pair of PEs. That rules out connecting the network endpoints (every pair of PEs exchanged a message before the clock started). It does not rule out pools of large message buffers (htram's PP messages are about 37 KB; the pings were empty) or the model's own transient.
- **P3 right within noise.** On 4 nodes the pings' cell is 1.043× the no-ping cell, but only because of the slow rep; the first reps are equal (125.6).
- **P4 right.** σ 4,000's loss is all start-up (efficiency over waves 10–95%: 1.00). Uniform's is 81% steady-state (0.77 over waves 10–95%).

**What this changes.**
- **Short runs understate 16-node throughput by up to 16%,** and every scaling efficiency in this file from short runs is low for that reason. On long runs σ 2,000 and σ 4,000 already scale at 0.96–1.00. The paper-grade rerun must use long runs (end time 2,048,000 or more) for every engine. **Devastator's 0.91 (section 95) also came from short runs and includes its own start-up,** so it must be remeasured on the same long runs before any scaling comparison.
- **The start-up transient** (about 0.16 s on 16 nodes) matters only for short runs. Its cause is still unknown (large-buffer pools or the model's own transient). It stays open, behind the two items below.
- **The real steady-state scaling problem left is uniform** (0.77 over waves 10–95%).

**Next.**
1. Charades and Devastator on long runs at 1, 4 and 16 nodes, on σ 2,000, σ 4,000 and uniform: the scaling comparison that counts.
2. Uniform's steady loss, diagnosed with the method of section 121 (closure first, then a perturbation, then a fix).

### Charades and Devastator on long runs, 1 / 4 / 16 nodes: σ 2,000, σ 4,000, uniform (design, 2026-10-27; written before any runs)

> **Status: design.** Charades `scale-diag` 4e6d8b8 (defaults, current launch: `+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free`, ring input buffers), htram `pdes` 699c3a9, Reconverse 22871c6; Devastator as in section 95 (`$WORK/devastator/bin/ofi-psm2`, CLCG4, glibc defaults). Job T `$WORK/charades-runs/long23.slurm` (16 nodes, skx-dev and skx, `-x c455-081`, the copy that starts second cancelled).

**Why.** Section 122: short runs (end time 512,000) understate 16-node throughput by up to 16%, because every run starts with a fixed transient. On 4× longer runs σ 2,000 scales 4→16 at 0.96–0.97, not 0.88. Every scaling comparison so far, including Devastator's 0.91–0.92 at σ ≥ 2,000 (section 95), came from short runs.

**Runs.** Same grids as section 95, end time **2,048,000** for both engines, 3 reps, interleaved by rep and node count (16, 4, 1):
- **Charades:**
  - σ 2,000 and σ 4,000: PP 512 and PP 2,048 × W 250, 400, 600 and the controller (ε 0.001).
  - Uniform (remote 1.0): WPs 512 and PP 512 × the same arms.
- **Devastator:** W 500 and 1,000 (and 2,000 at 16 nodes), on the same three workloads.
- Each engine is reported at its best setting per cell (median of 3). Short-run reference: section 95 (job 3642157, the launch before ring input buffers and `+mempool_remote_free`).

**Predictions:**
- T1. **Charades:**
  - 4→16 efficiency at least 0.95 at σ 2,000 and σ 4,000 (short runs: 0.81, 0.87).
  - About 0.78 on uniform: its loss is 81% steady-state (section 122), so long runs dilute it only a little.
- T2. **Devastator:** its efficiency rises less than Charades', to 0.92–0.96 at σ 2,000 and 4,000 and about 0.72 on uniform (short: 0.91, 0.92, 0.69).
- T3. **Charades ÷ Devastator at 16 nodes:** at least 1.2 at σ 2,000 and σ 4,000, and at least 1.3 on uniform (short: 1.14, 1.41, 1.42).
- T4. **Charades' controller ÷ its best fixed W at 16 nodes:** at least 0.92 at σ 2,000 and 0.88 at σ 4,000 (short: 0.92, 0.86).

If T1 and T3 hold, Charades both scales as well as Devastator and leads it on these workloads, and the scaling gap at σ ≥ 2,000 was an artefact of run length. If T1 fails at σ 2,000 or σ 4,000, the start-up explanation of section 122 is incomplete.

### Both engines on long runs, results: Charades leads Devastator 1.33–1.98×, scales as well at σ ≥ 2,000 (0.93), and its controller is within 2% of its best W on 16 nodes (2026-10-27; skx-dev batch job 3650921, 16 nodes)

> **Status: current.** Design and predictions in section 123. 16 nodes (c454-012, c454-013, c454-031, c454-032, c454-034, c454-041, c455-014, c455-021 to -024, c455-082, c455-093, c455-094, c455-101, c455-102; 4-node runs on the first four, 1-node on the first), 45 min. 218 Charades runs and 63 Devastator runs, all ok. End time 2,048,000 for both engines, 3 reps. Summary `~/charades-data/long23/long23_summary.py`, with `summary.txt`, the CSVs and Devastator's `results.txt` in `~/charades-data/long23/j3650921/`.

**Each engine at its best setting** (M committed ev/s, median of 3; Charades ÷ Devastator, higher is better for Charades; efficiency 4→16 = per-node rate at 16 ÷ at 4 nodes, 1.0 is perfect):

| workload | Charades 1 / 4 / 16 nodes | Devastator 1 / 4 / 16 nodes | Charades ÷ Devastator 1 / 4 / 16 | short runs, section 95 | efficiency 4→16, Charades / Devastator | short runs |
|---|---|---|---|---|---|---|
| σ 2,000 | 39.4 / 139.9 / 518.9 | 29.6 / 102.0 / 366.8 | **1.33 / 1.37 / 1.41** | 1.29 / 1.28 / 1.14 | **0.93 / 0.90** | 0.81 / 0.91 |
| σ 4,000 | 38.8 / 130.8 / 486.8 | 28.4 / 78.1 / 291.2 | **1.37 / 1.67 / 1.67** | 1.34 / 1.48 / 1.41 | **0.93 / 0.93** | 0.87 / 0.92 |
| uniform | 42.3 / 135.4 / 363.3 | 29.6 / 68.4 / 190.9 | **1.43 / 1.98 / 1.90** | 1.41 / 1.90 / 1.42 | 0.67 / 0.70 | 0.52 / 0.69 |

The short-run columns are from section 95, under the launch before ring input buffers and `+mempool_remote_free`. So Charades' change from them mixes run length with those two improvements. Devastator's binary and settings are unchanged, so its change is run length alone.

**Best settings.**
- **Charades:** PP 512 at σ ≥ 2,000 (W 250 on 1 node, the controller on 4, W 400 on 16).
- **Uniform:** PP 512 up to 4 nodes, WPs 512 on 16. On 4 nodes, PP 512 is 135.4 against WPs 512's 123.2; on 16 nodes WPs 512 is 363.3 against PP 512's 293.6. Each mode's own 4→16 efficiency is 0.74 for WPs and 0.54 for PP.
- **Devastator:** W 500 on 1 node, 1,000 on 16 (uniform: 500 up to 4 nodes).

**Charades' controller ÷ its best fixed W:** 0.98–1.03 everywhere. On 16 nodes it is 0.98 at σ 2,000 and σ 4,000 (short runs: 0.92 and 0.86) and 0.99 on uniform.

**Spread over the 3 reps of the best 16-node cell:**
- σ 2,000: 518.9, 524.8 and 452.9 (one slow rep).
- σ 4,000: 1.020× from slowest to fastest; uniform: 1.007×.
- One Devastator rep was slow too: uniform, 4 nodes, W 1,000, 22.4 M ev/s against 68–69. Medians are unaffected.

- **T1 wrong on the thresholds.** Charades' efficiency is 0.93 at σ 2,000 and σ 4,000 (predicted ≥ 0.95), and 0.67 on uniform (predicted about 0.78). Section 122's 0.97 compared W 400 with W 400, but on 4 nodes the controller is 6% faster (139.9 against 131.8), and comparing best with best lowers the efficiency. Uniform's best 4-node setting (PP 512) loses much more by 16 nodes than WPs does.
- **T2 right in direction.** Devastator's efficiency hardly moves with run length: 0.90, 0.93 and 0.70, against 0.91, 0.92 and 0.69 on short runs. Its start-up cost is small.
- **T3 right.** Charades ÷ Devastator on 16 nodes is 1.41, 1.67 and 1.90.
- **T4 right, more than predicted.** The controller is 0.98–0.99 of the best fixed W on 16 nodes. The controller gap at 16 nodes (sections 95, 116) was mostly the short runs.

**What this changes.**
- On long runs Charades is ahead of Devastator in all 9 cells, by 1.33–1.98×.
- At σ ≥ 2,000 it now scales as well as Devastator (0.93 against 0.90–0.93).
- Uniform is the one workload where it still scales a little worse (0.67 against 0.70), though at 1.90× the throughput. That is section 125's question.
- The paper-grade rerun should use these long runs for every workload. The other five workloads of section 95 still have only short-run numbers.

### Uniform's steady loss: thinner htram messages or more destinations? A buffer-size perturbation on 4 nodes (analysis of existing traces and design, 2026-10-27; written before any runs)

> **Status: design.** Analysis from job 3650843's traced uniform runs (`--gvt-trace=2`, WPs 512, W 400, short runs; script `uni_steady.py` in `~/charades-data/sdiag/j3650843/`). Job U: Charades `scale-diag` 4e6d8b8 (defaults), htram 699c3a9, Reconverse 22871c6, the current launch; `$WORK/charades-runs/uni24.slurm` (16 nodes, skx-dev and skx, `-x c455-081`), submitted after job T (one job per dev queue).

**Closure.**
- **Uniform's 4→16-node loss is 81% steady-state** (section 122).
- **In the steady state, time per simulated bucket accounts for all of it:** 24.5 µs on 4 nodes against 31.8 µs on 16 (ratio 0.77, the steady efficiency). A 16-node wave completes more buckets (9.5 against 8.4) but takes longer (300 against 207 µs).
- **σ 4,000 has no steady loss:** 23.7 against 23.5 µs per bucket.

**What differs between them** (job 3650843, untraced, 2 reps):

| workload | events per htram message, 4 / 16 nodes (higher is better) | remote sends per committed event, 4 / 16 nodes | time per bucket, 4 / 16 nodes (µs; lower is better) |
|---|---|---|---|
| uniform (WPs 512) | 31.1 / **12.4** | 1.006 / 1.002 | 24.5 / 31.8 |
| σ 4,000 (PP 512) | 46.0 / 45.6 | 1.004 / 1.000 | 23.7 / 23.5 |

On 16 nodes a uniform event goes to one of 32 processes instead of 8. Each PE's per-destination buffers fill 4× more slowly and are flushed by the deadline policy with fewer events, so there are 2.5× as many messages per event (0.032 → 0.081). Two explanations fit:
- **(H1) Thinning:** each message has a fixed cost (sending, network progress, the receive's fixed part), and there are more messages per event. If H1 holds, the PE time per event (1.58 → 2.10 µs) implies about 10.6 µs of PE time per extra message.
- **(H2) More destinations:** the flush scans and per-destination bookkeeping grow with the number of destination buffers, whatever the message count.

**Perturbation.** Cap the WPs buffer on 4 nodes so that messages are as thin as on 16 nodes, without adding destinations. A buffer of 16 events allows at most 16 events per message (now 31). Runs (uniform, W 400, short runs, 2 reps):
- **A. 4 nodes:** WPs 512 (default), 64, 32 and 16, untraced. Also WPs 512 and 16 traced (`--gvt-trace=4`), for the late PE's time split.
- **B. 16 nodes:** WPs 512 and 16, untraced. Also WPs 512 traced (`--gvt-trace=4`).

**Predictions:**
- U1. Under H1, 4-node WPs 16 lowers throughput by at least 15% (time per bucket 24.5 → 28.8 µs or more). The slope, extra PE time per extra message, comes out at 10.6 µs ± 30%, so thinning would account for the whole 4→16 steady loss. Under H2, WPs 16 costs less than 5%.
- U2. WPs 32 and 64 on 4 nodes are within ±3% of WPs 512 (messages already carry about 31 events).
- U3. On 16 nodes, WPs 16 is within ±5% of WPs 512 (messages already carry about 12).

If U1 holds with the slope: uniform's loss is the per-message cost under thinning. The fixes are then:
- fewer, fuller messages at 16 nodes: aggregating by destination node through an intermediate PE (2-D routing), or a longer horizon for far destinations;
- or a cheaper message: its send and receive path, priced from the traced split.

If U1 fails, H2 is next: the cost per destination buffer.

### Uniform's buffer perturbation, results: thinning explains only 16% of the loss; 45% is inside `execute()`, which the timers do not split (2026-10-27; skx-dev batch job 3651140, 16 nodes)

> **Status: current.** Design and predictions in section 125. 16 nodes (c454-001, c454-002, c454-021, c454-043, c454-044, c454-073, c454-083, c454-084, c455-041, c455-042, c455-083, c455-084, c455-091, c455-092, c455-103, c455-104; 4-node runs on the first four), 20 runs, all ok; 5 min. Summaries `~/charades-data/uni24/uni24_summary.py` and `pe_split.py`, with `summary.txt`, `pe_split.txt` and the CSVs in `~/charades-data/uni24/j3651140/`.

**Buffer sizes** (uniform, W 400, short runs, mean of 2 reps; M committed ev/s, higher is better; PE time per committed event = PEs ÷ rate, lower is better):

| nodes | WPs buffer | M ev/s | ÷ WPs 512 | events per message | messages per event | PE time per event (µs) |
|---|---|---|---|---|---|---|
| 4 | 512 | 115.1 | 1.000 | 30.9 | 0.0325 | 1.598 |
| 4 | 64 | 115.6 | 1.004 | 30.8 | 0.0327 | 1.592 |
| 4 | 32 | 121.5 | **1.056** | 26.3 | 0.0382 | 1.514 |
| 4 | 16 | 111.3 | 0.967 | 15.4 | 0.0650 | 1.653 |
| 16 | 512 | 350.5 | 1.000 | 12.4 | 0.0811 | 2.100 |
| 16 | 16 | 365.5 | **1.043** | 11.4 | 0.0878 | 2.014 |

- **U1 wrong.** Twice the messages per event on 4 nodes (WPs 16) costs 3.3%: **1.7 µs of PE time per extra message**, against the 10.3 µs that thinning would need to explain the 4→16 loss. At that slope thinning accounts for **16%** of the rise in PE time per event from 4 to 16 nodes.
- **U2 half wrong.** WPs 64 is equal to 512, but **WPs 32 is 1.056× faster**.
- **U3 right, with a sign.** On 16 nodes WPs 16 is within ±5%, but faster: 1.043×.

A smaller buffer sends some events when it fills, before the deadline policy would. PEs then wait less on the window: window-blocked passes per committed event are 0.416 at WPs 512 and 0.358 at WPs 16 on 4 nodes. This is a separate, cheap gain to check on other workloads; it is not the scaling loss.

**Closure over all PE time** (traced runs, `--gvt-trace=4 --pe-stats=1`, WPs 512; µs of PE time per committed event, mean of 2 reps; lower is better):

| part | 4 nodes | 16 nodes | 16 − 4 | share | 4 nodes, WPs 16 |
|---|---|---|---|---|---|
| `execute()` without input-buffer drains | 1.045 | 1.291 | +0.246 | **45%** | 1.014 |
| input-buffer drains | 0.285 | 0.320 | +0.035 | 6% | 0.319 |
| htram receive handlers | 0.140 | 0.232 | +0.092 | 17% | 0.172 |
| everything else (runtime loop, idle) | 0.144 | 0.313 | +0.169 | 31% | 0.201 |
| **total** | 1.613 | 2.155 | +0.542 | 100% | 1.706 |

Per committed event, window-blocked passes rise from 0.416 to 0.549, and htram receives from 0.028 to 0.079 (31.0 → 12.3 items each). `execute()` without drains costs 1.037 µs per executed event on 4 nodes and **1.286 on 16**. The thinner messages of WPs 16 on 4 nodes raise the receives and the rest, but not `execute()`. So the largest piece, +0.246 µs in `execute()`, is not caused by message count.

**What `execute()` contains that grows with the number of processes** (untested; `execute()` is timed only as a whole):
- the idle flush, `agg_flush_idle()`, on every pass that is not full (0.55 per event on 16 nodes), which scans this PE's per-destination buffers: 32 destination processes on 16 nodes against 8 on 4;
- sends: the share of events to the PE's own process (the same-process fast path) falls from 1/8 to 1/32;
- cache footprint: the per-destination buffers touched per pass.

**Next.**
1. Split `execute()`: timers for the idle flush, for remote sends (htram insert), for the same-process fast path and for the event handlers. This closes the +0.246 µs.
2. Then a perturbation of whichever piece dominates, before any fix. For example, if it is the idle flush, flush only when the PE has gone idle k passes in a row, and check that the 16-node time moves by the predicted amount.

### Splitting `execute()` on uniform at 4 and 16 nodes, against σ 4,000 as a control (design, 2026-10-28; written before any runs)

> **Status: design.** Charades `scale-diag` (this commit: `--gvt-trace=5`), htram 699c3a9, Reconverse 22871c6, the current launch. Job V `$WORK/charades-runs/exec25.slurm` (16 nodes, skx-dev and skx, `-x c455-081`, the copy that starts second cancelled).

**Why.** Section 126: on uniform, `execute()` without input-buffer drains is 45% of the 4→16-node rise in PE time per committed event (+0.246 µs), and more messages do not explain it. `execute()` was timed only as a whole.

**New `--gvt-trace=5`:** each PE writes `exec_parts_<pe>.csv` over the run:
- inside `execute()`: the event loop, the idle flush (`agg_flush_idle`, which with the deadline policy runs htram's `flushDue` over every destination buffer), the cancel queue, the result pickup (`poll`) and the input-buffer drains;
- inside the event loop's sends: GVT counting (`produce`), the same-process fast path (hits and misses), the remote send (htram insert and any flush), and sends to the same chare;
- `iteration_end`, which runs outside the `execute()` timer.

On the Mac (2 processes × 2 PEs, uniform), the parts cover 99.9% of `execute()`. The timers add about 6 calls per pass and 4 per remote send, so traced runs are paired with untraced ones. Mac: trace configs 36/36.

**Runs** (W 400, short runs, 2 reps; `--gvt-trace=5 --pe-stats=1`, each with an untraced pair):
- uniform, WPs 512, 4 and 16 nodes;
- σ 4,000, PP 512, 4 and 16 nodes, as a control: it has no steady 4→16-node loss (section 122).

The event handlers' own time is the loop minus the sends.

**Predictions** (µs per committed event, 4 → 16 nodes, uniform):
- V1. **The idle flush** grows by at least 0.08 and is at least 30% of the +0.25 µs: it scans 32 destination buffers on 16 nodes against 8 on 4, on each of 0.42–0.55 non-full passes per committed event.
- V2. **A remote send costs within 10% the same** on 4 and 16 nodes (an htram insert is constant work). The send total grows only because fewer sends take the fast path: 1/8 of sends on 4 nodes against 1/32 on 16.
- V3. **The event handlers' time per executed event is within ±5%** on 4 and 16 nodes.
- V4. **Control:** on σ 4,000 no part grows by more than 0.03.
- V5. **Closure:** the timed parts cover at least 95% of `execute()`, and traced ÷ untraced is at least 0.90.

Whatever part carries most of the +0.25 µs then gets a perturbation before any fix. For example, if it is the idle flush: run the flush only every k-th non-full pass, and check that the 16-node time moves by the predicted amount.

### `execute()` split, results: on uniform the event handlers and sends do not grow; half of `execute()`'s rise is applying each GVT result (2026-10-28; skx-dev batch job 3652542, 16 nodes)

> **Status: current.** Design and predictions in section 127. 16 nodes (c454-002, c454-074, c454-081, c454-082, c454-102 to -104, c455-073, c455-074, c455-082 to -084, c455-091, c455-092, c455-103, c455-104; 4-node runs on the first four), 18 runs, all ok; gate 24/24; 5 min. Summary `~/charades-data/exec25/exec25_summary.py`, with `summary.txt` and the CSVs in `~/charades-data/exec25/j3652542/`.

**`execute()` split, uniform (WPs 512) and σ 4,000 (PP 512), W 400, short runs** (µs of PE time per committed event, mean of 2 reps, `--gvt-trace=5`; lower is better):

| part | uniform, 4 nodes | uniform, 16 nodes | uniform, 16 − 4 (share) | σ 4,000, 4 nodes | σ 4,000, 16 nodes | σ 4,000, 16 − 4 |
|---|---|---|---|---|---|---|
| event handlers (loop minus sends) | 0.502 | 0.498 | −0.004 (−1%) | 0.605 | 0.599 | −0.006 |
| remote sends, all parts | 0.322 | 0.332 | +0.010 (4%) | 0.369 | 0.365 | −0.003 |
| **applying the GVT result (`poll`)** | 0.289 | 0.426 | **+0.136 (52%)** | 0.165 | 0.163 | −0.002 |
| input-buffer drains | 0.283 | 0.315 | +0.033 (12%) | 0.260 | 0.258 | −0.003 |
| idle flush | 0.016 | 0.047 | +0.031 (12%) | 0.025 | 0.091 | +0.067 |
| cancel queue | 0.017 | 0.022 | +0.005 (2%) | 0.022 | 0.033 | +0.011 |
| untimed, including the timer calls | 0.172 | 0.225 | +0.052 (20%) | 0.190 | 0.244 | +0.054 |
| **`execute()`** | 1.602 | 1.865 | +0.264 | 1.636 | 1.754 | +0.119 |

Other figures:
- **Event handlers per executed event:** uniform 0.498 → 0.496 µs; σ 4,000 0.600 → 0.597.
- **One remote send** (htram insert, plus any flush it triggers): uniform 0.082 → 0.093 µs; σ 4,000 0.131 → 0.128.
- **Share of sends on the fast path:** uniform 0.124 → 0.031; σ 4,000 0.280 both.
- **One idle flush:** uniform 0.076 → 0.164 µs (0.21 → 0.29 per event); σ 4,000 0.090 → 0.198.
- **Timed share of `execute()`:** 0.86–0.89.
- **Traced ÷ untraced:** 0.85–0.90 (untraced: uniform 116.4 and 348.6, σ 4,000 117.2 and 428.3 M ev/s).

- **V1 wrong.** The idle flush grows by 0.031 (12%), not by at least 0.08 (30%), although each call costs twice as much on 16 nodes (more destination buffers to scan).
- **V2 about right.** A remote send costs 13% more on 16 nodes (predicted within 10%). The send total rises only 0.010.
- **V3 right.** The event handlers' time per event is unchanged.
- **V4 partly wrong.** σ 4,000's idle flush and untimed time grow too. Its whole 4→16 loss in short runs is start-up (section 122), and these are whole-run totals, so this growth is probably start-up; a long-run trace would show it. The GVT result step, which grows on uniform, does not grow on σ 4,000.
- **V5 wrong.** The timers cover 86–89% of `execute()` (predicted ≥ 95%) and cost 10–15% (predicted ≤ 10%). Most of the untimed part is the timer calls and the bookkeeping between them, which grow with the number of passes.

**What `poll` does when a result arrives** (`BucketGVT::poll` → `wave_done` → `gvt_done`):
- fossil collection over every LP on the PE;
- the GVT-time flush (`agg_flush_gvt`), which with the deadline policy runs htram's `flushDue`: every destination buffer holding an event now due is sent;
- the controller's update.

On uniform, a PE's events go to all 32 processes on 16 nodes against 8 on 4. So each GVT update sends up to 4× as many small messages from this step. Messages per committed event rise from 0.032 to 0.081. If all the extra messages went out here, the step's rise (+0.136) would mean about 2.8 µs per message, against 1.7 µs per extra message measured in section 126.

**Status of the uniform loss (+0.54 µs of PE time per committed event, 4 → 16 nodes, section 126):**
- **Not grown:** event handlers, sends.
- **Grown:**
  - applying the GVT result (+0.14);
  - htram receives (+0.09, section 126);
  - the runtime loop and idle outside `execute()` (+0.17, section 126);
  - input-buffer drains (+0.03);
  - the idle flush (+0.03).

Messages per event (section 126) can account for part of the receives and of the GVT result step. These totals are PE time, so they say where the time goes, not which part limits throughput.

**Next.**
1. Split `poll` into fossil collection, the GVT-time flush (with the messages it sends) and the rest. Use long runs, so start-up does not mix in.
2. Then a perturbation of the largest part. For the GVT-time flush, send the due buffers of far destinations less often. For fossil collection, collect every k-th GVT.

### Charades and Devastator on long runs, 1 / 4 / 16 nodes: the other five workloads (design, 2026-10-28; written before any runs)

> **Status: design.** Charades `scale-diag` 0cf5341 (defaults, current launch), htram 699c3a9, Reconverse 22871c6; Devastator as in sections 95 and 124. Job W `$WORK/charades-runs/long26.slurm` (16 nodes, skx-dev and skx, `-x c455-081`, the copy that starts second cancelled).

**Why.** Section 124 put σ 2,000, σ 4,000 and uniform on long runs. The other five workloads of section 95 have only short-run numbers, from the launch before ring input buffers and `+mempool_remote_free`. Section 122 showed that short runs misstate 16-node throughput by up to 16%. This is not a repeat: no earlier section ran these workloads on long runs (re-read, top of this file).

**Runs.** Section 95's grids, run 4× longer, 3 reps, interleaved by rep and node count (16, 4, 1):
- **Lookahead 100, mean 1,000, σ 100, 500 and 1,000:**
  - Charades: PP 512 and PP 2,048 × W 250, 400, 600 and the controller.
  - Devastator: W 500 and 1,000 (and 2,000 on 16 nodes).
  - End time 2,048,000.
- **Lookahead 10, mean 200, σ 500 and 2,000:**
  - Charades: PP 512 and PP 2,048 × W 50, 100, 200 and the controller; WPs 512 at σ 2,000.
  - Devastator: W 100, 200 and 400.
  - End time 512,000 (4× section 95's 128,000).
- The run time cap is 120 s for Charades and 300 s for Devastator. Section 95 had two 1-node cells at lookahead 10, σ 2,000, W 200 reach its 60 s cap; at 4× they will reach 120 s and be dropped (never the best setting there).

**Predictions** (section 95's short-run values in brackets):
- W1. **Charades ÷ Devastator is at least 1.0 in all 15 cells.** The narrowest is lookahead 10 σ 500 on 1 and 4 nodes [0.98].
- W2. **Charades' 4→16 efficiency is at least 0.95** at σ 100, 500, 1,000 and lookahead 10 σ 500 [0.95–0.99], and at least 0.92 at lookahead 10 σ 2,000 [0.89].
- W3. **Devastator's efficiency changes by at most 0.03 with run length** (as in section 124) [0.97, 0.88, 0.86, 0.86, 0.91].
- W4. **Charades' controller is within 5% of its best fixed W in every cell.**

With section 124, this completes the long-run version of the 8-workload table, the comparison the paper reports.

### The other five workloads on long runs, results: Charades ahead in 14 of 15 cells (level in the 15th), scales as well or better in 4 of 5; its controller is its best setting or within 1% (2026-10-28; skx-dev batch job 3652595, 16 nodes)

> **Status: current.** Design and predictions in section 129. 16 nodes, 1 h 24 min. 398 Charades runs and 117 Devastator runs, all ok (no cap reached). 3 reps. Summary `~/charades-data/long26/long26_summary.py`, with `summary.txt`, the CSVs and Devastator's `results.txt` in `~/charades-data/long26/j3652595/`.

**Each engine at its best setting** (M committed ev/s, median of 3; Charades ÷ Devastator, higher is better for Charades; efficiency 4→16 = per-node rate at 16 ÷ at 4 nodes, 1.0 is perfect):

| workload | Charades 1 / 4 / 16 nodes | Devastator 1 / 4 / 16 nodes | Charades ÷ Devastator 1 / 4 / 16 | short runs, section 95 | efficiency 4→16, Charades / Devastator | short runs |
|---|---|---|---|---|---|---|
| lookahead 100, mean 1,000, σ 100 | 47.6 / 181.4 / 683.1 | 42.0 / 169.1 / 640.1 | **1.14 / 1.07 / 1.07** | 1.17 / 1.04 / 1.06 | 0.94 / 0.95 | 0.99 / 0.97 |
| σ 500 | 42.2 / 164.0 / 607.1 | 38.5 / 142.9 / 496.0 | **1.10 / 1.15 / 1.22** | 1.09 / 1.08 / 1.19 | 0.93 / 0.87 | 0.97 / 0.88 |
| σ 1,000 | 40.9 / 155.3 / 554.1 | 37.0 / 123.6 / 428.1 | **1.11 / 1.26 / 1.29** | 1.08 / 1.19 / 1.31 | 0.89 / 0.87 | 0.95 / 0.86 |
| lookahead 10, mean 200, σ 500 | 38.6 / 149.7 / 561.5 | 39.0 / 141.5 / 492.6 | **0.99 / 1.06 / 1.14** | 0.98 / 0.98 / 1.09 | 0.94 / 0.87 | 0.97 / 0.86 |
| lookahead 10, σ 2,000 | 34.4 / 125.0 / 459.3 | 28.7 / 94.8 / 346.7 | **1.20 / 1.32 / 1.32** | 1.14 / 1.18 / 1.15 | 0.92 / 0.91 | 0.89 / 0.91 |

**Best settings.**
- **Charades:**
  - PP 512 on 1 node (W 250, W 50 at lookahead 10, or the controller).
  - PP 2,048 with the controller on 4 and 16 nodes at σ ≤ 1,000 and lookahead 10 σ 500.
  - WPs 512 at lookahead 10 σ 2,000 (W 50 or the controller).
- **Devastator:** W 500–1,000 (lookahead 10: 100–200).

**Charades' controller ÷ its best fixed W:** 0.99–1.03 in all 15 cells. It *is* the best setting in 8 of the 10 cells on 4 and 16 nodes.

**Spread over the 3 reps of the best 16-node cell:** 1.006–1.008×, except σ 100 at 1.037×.

**Long against short runs, 16 nodes.**
- **Both engines are 0–5% slower on long runs** at the low-σ workloads: σ 100, 683.1 against 704.4 (Charades) and 640.1 against 663.0 (Devastator); σ 1,000, 554.1 against 579.4 and 428.1 against 442.8.
- **On 4 nodes, Charades is 2–3% faster on long runs and Devastator 1–5% slower.** So Charades' low-σ efficiency drops (0.99 → 0.94 at σ 100) while Devastator's hardly changes.
- **Possible causes** (not tested):
  - Section 95 ran on a different allocation, under the launch before ring input buffers and `+mempool_remote_free`; efficiencies from different allocations have differed by up to ±0.1 (section 77).
  - Or something long runs do to both engines on 16 nodes.
- At σ ≥ 2,000 and lookahead 10, long runs raise Charades' efficiency (sections 122, 124 and this one: lookahead 10 σ 2,000, 0.89 → 0.92).

- **W1 right but for one cell.** Charades ÷ Devastator is at least 1.0 in 14 of 15 cells; lookahead 10 σ 500 on 1 node is 0.99 (level).
- **W2 wrong.** Charades' efficiency is 0.94, 0.93, 0.89 and 0.94 (predicted ≥ 0.95), and 0.92 at lookahead 10 σ 2,000 (right).
- **W3 right.** Devastator's efficiency moves by at most 0.02.
- **W4 right.** The controller is within 1% of the best fixed W, or better, everywhere.

**All eight workloads on long runs** (with section 124):
- **Charades ÷ Devastator:** 0.99–1.98 over 24 cells, at least 1.0 in 23. On 16 nodes it is 1.07–1.90.
- **4→16 efficiency, Charades against Devastator:**
  - Charades scales as well or better in 6 of 8 workloads: σ 500, 1,000, 2,000 and 4,000, and lookahead 10 σ 500 and σ 2,000.
  - It is slightly worse at σ 100 (0.94 against 0.95) and uniform (0.67 against 0.70).

### Is applying a GVT result on uniform's critical path? A known delay in that step, and its parts (design, 2026-10-28; written before any runs)

> **Status: design.** Charades `scale-diag` (this commit: `--diag-gvt-spin-ns`, and fossil collection, the GVT-time flush and the controller update timed under `--gvt-trace=5`), htram 699c3a9, Reconverse 22871c6, the current launch. Job X `$WORK/charades-runs/exec27.slurm` (16 nodes, skx-dev and skx, `-x c455-081`), after job W.

**Why.**
- **Section 128:** on uniform, applying each GVT result (`poll`) is the largest part of `execute()`'s 4→16-node rise: +0.136 µs of PE time per committed event, about 37 → 63 µs per PE per GVT update.
- **What sections 116–120 and 54 teach** (re-read note at the top): time a step takes is not throughput lost unless the step is on the critical path. Every PE applies each result, but most PEs are then blocked on the window anyway; only the PE that paces the advance matters.
- **So the first test is causal, not a split.** It adds a known delay to this one step and checks whether throughput falls as the critical path predicts.

**New `--diag-gvt-spin-ns=N`** (diagnostic, 0 = off): every PE busy-waits N ns each time it applies a GVT result. The split (`--gvt-trace=5`) adds:
- the time in fossil collection;
- the GVT-time flush (`agg_flush_gvt`), with the messages it sends;
- the controller's update;
- the number of results applied.

Mac: 36/36 (the trace and spin configs at 1×4, 2×2 and 4×2; committed counts unchanged by the spin).

**Runs** (uniform, WPs 512, W 400, long runs, end time 2,048,000, 2 reps):
- **A. Spin**, untraced: N = 0, 10,000 and 20,000 (0, 10 and 20 µs), on 4 and 16 nodes.
- **B. Split**, traced (`--gvt-trace=5 --pe-stats=1`), on 4 and 16 nodes.

**Predictions:**
- X1. **If the step is on the critical path** (the pacing PE applies each result once per advance, and its next contribution waits for that), every advance gets longer by N.
  - At 20 µs, throughput falls by about 20 ÷ 300 = 6–7% on 16 nodes and 20 ÷ 207 = 9–10% on 4 nodes (advances from section 125); 10 µs costs half that.
  - **If the step mostly overlaps waiting,** 20 µs costs under 2%.
- X2. **Of the step's 4→16-node rise,** the GVT-time flush is at least half: messages sent per GVT update per PE rise about 3× (to up to 32 destinations instead of 8). Fossil collection per committed event changes by under 10%.
- X3. **Closure:** the step's measured sensitivity times its 4→16 rise per advance gives the share of uniform's loss that this step explains. If X1's critical-path case holds, the rise of about 26 µs per update predicts about 25–30% of uniform's steady loss; a fix would then target the larger of its parts.

If X1's overlap case holds instead, this step is not worth fixing, and the next candidates are the htram receives and the runtime loop (section 126), tested the same way.

### The GVT-result step, results: on 16 nodes it is fully on the critical path, and the GVT-time flush is 97% of its rise (2026-10-28; skx-dev batch job 3652815, 16 nodes)

> **Status: current.** Design and predictions in section 131. 16 nodes (c454-021 to -023, c454-041 to -044, c454-071 to -073, c454-083, c454-084, c454-091 to -094; 4-node runs on the first four), 18 runs, all ok; gate 24/24; 7 min. Summary `~/charades-data/exec27/exec27_summary.py`, with `summary.txt` and the CSVs in `~/charades-data/exec27/j3652815/`.

**A. A known delay in the step** (uniform, WPs 512, W 400, long runs; M committed ev/s, mean of 2 reps; higher is better). The critical-path prediction is 1 ÷ (1 + delay ÷ µs per GVT update):

| nodes | no delay | 10 µs: measured / predicted | 20 µs: measured / predicted | µs per GVT update | measured ÷ predicted cost |
|---|---|---|---|---|---|
| 4 | 111.1 | 0.971 / 0.956 | 0.939 / 0.915 | 215 | 0.64 |
| 16 | 358.8 | **0.968 / 0.967** | **0.935 / 0.936** | 291 | **0.94** |

**B. The step split** (traced; µs per PE per GVT update; lower is better):

| nodes | the whole step | fossil collection | GVT-time flush | messages it sends | controller | other |
|---|---|---|---|---|---|---|
| 4 | 38.6 | 13.6 | 22.7 | 3.50 | 0.0 | 2.3 |
| 16 | 58.5 | 13.4 | **42.1** | **10.21** | 0.0 | 3.0 |
| 16 − 4 | +19.9 | −0.1 (−1%) | **+19.4 (97%)** | +6.71 | 0.0 | +0.6 (3%) |

- **The two points fit the GVT-time flush** as about 12.6 µs per update plus **2.9 µs per message** sent. (Section 134: this split is wrong. A message costs 6.6 µs on 4 nodes and 4.2 on 16, and sends are 95% of the flush on both.)
- **Per committed event,** the step is 0.300 µs of PE time on 4 nodes and 0.433 on 16 (section 128 had 0.289 and 0.426 on short runs).

- **X1: the critical-path case holds on 16 nodes.** Each microsecond added to the step adds a microsecond to the advance: 0.968 and 0.935 against predicted 0.967 and 0.936. On 4 nodes only about two thirds of it shows: some of the delay there falls on PEs that would have waited anyway.
- **X2 right.** The GVT-time flush is 97% of the step's rise: each PE sends 2.9× as many messages per update (10.2 against 3.5). Fossil collection does not change.
- **X3 right.** As a share of uniform's steady loss (24.5 → 31.8 µs per bucket, section 125), the step's rise per bucket is 31% if both node counts are equally sensitive, and 55% with the measured sensitivities (0.64 and 0.94).

**This is the first piece of uniform's 4→16-node loss that is both measured and shown to be on the critical path.**
- **What a fix is worth:** on 16 nodes, every microsecond taken out of the GVT-time flush shortens the advance by a microsecond.
- **At the limit:** bringing it back to its 4-node cost (−19.4 µs per update) would make uniform about 1.07× faster on 16 nodes (291 ÷ 272). Its WPs-to-WPs 4→16 efficiency would rise from about 0.74 to 0.79, and the best-to-best efficiency (section 124) from 0.67 to about 0.71, against Devastator's 0.70.

**Fix candidates** (not yet chosen; each would be checked against this prediction):
1. **A cheaper message.** About 2.9 µs of the sending PE's time per message: building the htram message, copying the items, and Charm++'s and Reconverse's send path. Time those parts first.
2. **Fewer messages from the PE that paces the advance.** At a GVT update, send only destinations holding events due before the next advance is likely to need them; leave the rest to buffer fills and idle flushes. Risk: the flush-versus-GVT-update race (`--ctl-floor`).
3. **Take the flush off the pacing PE.** A PE that still has events to run inside the window postpones its GVT-time flush to its next idle pass, or another PE of its process sends its buffers. Risk: the events it holds may then be what GVT waits for.

### Where an htram message's 2.9 µs goes: htram, Charm++, Reconverse and LCI (design, 2026-10-28; written before any runs)

> **Status: design.** Charades `scale-diag` (this commit), htram `pdes` (this commit: send timers), Reconverse branch `pads-send-timers` (diagnostic, local and on Stampede3 only; on `pads-remote-free`), the current launch. Job Y `$WORK/charades-runs/send28.slurm` (16 nodes, skx-dev and skx, `-x c455-081`).

**Why.** Section 132: on 16 nodes the GVT-time flush is on uniform's critical path and costs about 12.6 µs per update plus 2.9 µs per message. Option 1 (agreed 2026-10-28) is a cheaper message, so the first step is to find where those 2.9 µs go. No earlier section split htram's send path: section 3's per-message costs are from the old Debug runtime, and section 23's profile saw only message allocation (1.5%).

**New timers, under `--gvt-trace=5`, in `exec_parts_<pe>.csv`:**
- **htram** (every send site): sizing the envelope (`trim`), the Charm++ send call, and allocating the replacement buffer (`renewBuffer`, which allocates room for the whole buffer, about 37 KB at WPs 512).
- **Reconverse** (`CmiSyncNodeSendAndFree` to another process, found at run time with `dlsym`): the shared-memory attempt, LCI's `issueAm`, and the whole call.
- **Charm++'s own part** is the Charm++ send call minus Reconverse's.

On the Mac (uniform, 2 processes × 2 PEs, WPs 512 and 32): trim 0.02 µs, renew 0.10 µs whatever the buffer size, and the Charm++ send call 18 µs (the Mac's LCI path is slow, so that number means nothing for Stampede3). Mac: 90/90 on the trace and aggregation configs.

**Runs** (uniform, WPs 512, W 400, long runs, end time 2,048,000, 2 reps; `--gvt-trace=5 --pe-stats=1` with untraced pairs), on 4 and 16 nodes.

**Predictions:**
- Y1. **The Charm++ send call is at least 80% of a send;** trim and renew together are under 0.2 µs.
- Y2. **Inside it, LCI's `issueAm` is at least half;** the rest is Charm++'s own path and Reconverse's.
- Y3. **Closure:** sends × their measured cost account for the 2.9 µs per message of the GVT-time flush within 25%. The flush's 12.6 µs per update that does not scale with messages is not in the sends.
- Y4. **A send costs the same on 4 and 16 nodes within 15%:** what grows is how many there are.

Then the largest part gets a perturbation and a fix: for example, skipping one part's work and checking that the 16-node GVT-time flush, and throughput, move by the predicted amount (section 132: each µs off the flush is a µs off the advance on 16 nodes).

### An htram message's cost, results: 92–95% is the LCI backend's send call, which polls the network after every post (2026-10-28; skx-dev batch job 3652869, 16 nodes)

> **Status: current.** Design and predictions in section 133. 16 nodes (c454-004, c454-021 to -024, c454-031 to -034, c454-041 to -044, c454-071 to -073; 4-node runs on the first four), 10 runs, all ok; gate 24/24; 6 min. Summary `~/charades-data/send28/send28_summary.py`, with `summary.txt` and the CSVs in `~/charades-data/send28/j3652869/`.

**One htram send, split** (uniform, WPs 512, W 400, long runs; µs per send, mean over PEs and 2 reps; lower is better):

| part | 4 nodes | 16 nodes |
|---|---|---|
| sizing the envelope (`trim`) | 0.04 | 0.04 |
| Charm++'s own part of the send | 0.09 | 0.11 |
| Reconverse's shared-memory attempt (never used: 0% of sends) | 0.05 | 0.04 |
| **the LCI backend's `issueAm`** | **6.10** | **3.82** |
| allocating the replacement buffer (`renewBuffer`) | 0.24 | 0.18 |
| **a whole send** | 6.64 | 4.22 |

**The GVT-time flush:**
- 4 nodes: 24.4 µs per update and 3.48 messages, so 7.03 µs per message.
- 16 nodes: 43.8 µs per update and 9.87 messages, so 4.44 µs per message.
- Sends × their cost come to 95% of the flush on both node counts.

Traced ÷ untraced is 0.82–0.86 (untraced 115.2 and 356.0 M ev/s).

- **Y1 right.** The Charm++ send call is 96% of a send. The buffer allocation is cheap (0.2 µs) although it reserves the whole 37 KB buffer.
- **Y2 right, and more so.** LCI's `issueAm` is 96% of the Charm++ send; Charm++'s and Reconverse's own code take 0.1–0.15 µs.
- **Y3 right, but section 132's split was wrong.**
  - The flush is sends: 95% of it.
  - Section 132's fit of "12.6 µs per update + 2.9 µs per message" assumed a message costs the same on 4 and 16 nodes. It does not, so its fixed part was an artefact.
- **Y4 wrong.** A send costs 6.6 µs on 4 nodes and 4.2 on 16: 4-node messages carry 31 events (about 2.3 KB), 16-node ones 12 (about 0.9 KB).

**What `issueAm` does** (Reconverse `comm_backend_lci2.cpp`):
- It posts the message (`lci::post_am_x`).
- Then, after every post, not only on a retry, it calls `progress()`. That polls the PE's own LCI device and runs the handler for everything that has arrived: completed sends, and received messages, which it copies into Converse messages and queues.

So some or most of these 4–6 µs may be receive work, or the cost of a poll, done inside each send. The message size dependence fits either the post's copy into a packet or larger incoming messages being handled.

**Next.** Time the post and the progress call separately inside `issueAm`, count how often progress finds anything, and test `+lci_send_progress 0`, which skips the progress call after a successful post (section 135).

### The post and the network poll inside each send, and skipping the poll (`+lci_send_progress 0`) (design, 2026-10-28; written before any runs)

> **Status: design.** Charades `scale-diag` (this commit), htram `pdes` ed31d7e, Reconverse `pads-send-timers` (this commit: post and progress timed separately in `issueAm`, and `+lci_send_progress`), the current launch. Job Z `$WORK/charades-runs/send29.slurm` (16 nodes, skx-dev and skx, `-x c455-081`).

**Why.** Section 134: on 16 nodes, 3.8 µs of a message's 4.2 µs is the LCI backend's `issueAm`, which calls `progress()` after every post. Two explanations need different fixes:
- **(a) the poll itself is slow,** even when it finds nothing;
- **(b) it does real receive work** that the PE would have to do anyway, only earlier.

**New, in Reconverse `pads-send-timers`:**
- **Timers** for the time in `post_am_x` and in the `progress()` call after it, with how many progress calls completed something.
- **`+lci_send_progress 0`:** `issueAm` calls `progress()` only when a post must be retried, not after a successful one. The scheduler loop still polls the device as before.

It compiles on the Mac (standalone Release build); Charades: 24/24 on the trace configs.

**Runs** (uniform, WPs 512, W 400, long runs, 2 reps), on 4 and 16 nodes:
- `+lci_send_progress` 1 (default) and 0, traced (`--gvt-trace=5`) and untraced;
- then, on 16 nodes, σ 2,000 (PP 512) and σ 100 (PP 2,048, the controller), with 1 and 0, untraced, as a check that nothing else suffers.

**Predictions:**
- Z1. **Most of `issueAm` is the poll:** of 3.8 µs on 16 nodes, the post is under 1.5 µs and progress over 2.
- Z2. **If (a) holds** (most polls complete nothing and still cost), `+lci_send_progress 0` cuts a send to under 1.5 µs and the 16-node GVT-time flush from about 44 to under 20 µs per update. Since the flush is on the critical path (section 132), 16-node uniform then gains at least 6% (24 µs of a 291 µs advance); 4 nodes gain less.
- Z3. **If (b) holds** (most polls do receive work), the work moves to the scheduler loop on the same PE, and throughput changes by under 3% either way.
- Z4. On σ 2,000 and σ 100 at 16 nodes, `+lci_send_progress 0` is not below 0.98×.

If Z2 holds, `+lci_send_progress 0` (or Reconverse polling only when a post is retried) joins the Stampede3 launch after a correctness gate, as `+mempool_remote_free` did.

### The poll inside each send, results: it does useful work; skipping it costs uniform 6% on 16 nodes, and the time moves into allocating the next buffer (2026-10-28; skx-dev batch job 3652896, 16 nodes)

> **Status: current.** Design and predictions in section 135. 16 nodes (c454-021 to -024, c454-031 to -034, c454-041 to -044, c454-071 to -074; 4-node runs on the first four), 26 runs, all ok; gate 30/30 with `+lci_send_progress 0`; 8 min. Summary `~/charades-data/send29/send29_summary.py`, with `summary.txt` and the CSVs in `~/charades-data/send29/j3652896/`.

**Throughput, long runs** (M committed ev/s, mean of 2 reps; `+lci_send_progress 0` ÷ the default; higher is better):

| workload | nodes | default | poll skipped | ratio |
|---|---|---|---|---|
| uniform, WPs 512, W 400 | 4 | 112.3 | 111.7 | 0.995 |
| uniform, WPs 512, W 400 | 16 | 357.5 | 336.6 | **0.942** |
| σ 2,000, PP 512, W 400 | 16 | 488.0 | 492.5 | 1.009 |
| σ 100, PP 2,048, the controller | 16 | 679.6 | 669.1 | 0.985 |

**Inside a send, 16 nodes** (traced; µs per htram send; lower is better):

| part | default | poll skipped |
|---|---|---|
| LCI post (`post_am_x`; 1.06–1.13 posts per send, retries included) | 0.83 | 0.86 |
| the poll after the post (`progress()`; 2.82 µs per call, 55% of calls complete something) | 3.00 | — |
| **allocating the next buffer (`renewBuffer`)** | 0.18 | **2.62** |
| a whole send | 4.25 | 3.70 |
| GVT-time flush, per update (10 messages) | 44.5 | 39.0 |

**On 4 nodes:** post 1.46 µs and poll 4.81 µs (3.77 per call, 47% complete something), against the poll skipped: allocation 0.24 → **4.08** µs, and a whole send 6.55 → 5.83.

- **Z1 right.** The poll is most of the LCI send call: on 16 nodes the post is 0.8 µs and the poll 3.0 µs.
- **Z2 wrong.** Skipping the poll does not make a message cheap. The time moves into allocating the next 37 KB buffer (0.18 → 2.62 µs on 16 nodes, 0.24 → 4.08 on 4), so a send gets only 0.55–0.72 µs cheaper.
- **Z3 wrong in size.** Throughput does not stay within ±3%: uniform falls 5.8% on 16 nodes.
- **Z4 half right.** σ 2,000 1.009×, but σ 100 0.985×, below the 0.98 bar only within noise (its two reps differ by 3.7%).

**What it says.**
- **The poll after each send does useful work.** More than half the time it completes something: incoming messages, which other PEs are waiting for, and this PE's own completed sends.
- **Without it, the next buffer allocation gets expensive.** A likely reason, not tested: sent messages are returned to the memory pool only when their completion is processed, so the next 37 KB allocation no longer finds a block ready.
- **Bottom line:** of an htram message's 4.2 µs on 16 nodes, the send itself is about 0.8 µs. The rest is network progress, which has to happen somewhere, and doing it later costs more.
- **So option 1 (a cheaper message) has no cheap part left to cut** in Charm++, Reconverse's send or htram: they are 0.1–0.2 µs. What remains is LCI and psm2's poll and receive handling.
- `+lci_send_progress 0` stays off; it remains a diagnostic on the `pads-send-timers` branch.

**Next, if continued.** Split a poll's 2.8 µs into the cost of an empty poll and of handling what it finds (LCI's completion handlers, Reconverse's copy into a Converse message). If empty polls are most of it, a cheaper or less frequent poll is worth testing. If handling dominates, that is the receive path's cost per message, which only fewer messages would reduce.

### PP's late held events: a race at each GVT update, not a missed flush (analysis of existing data, 2026-10-28; no new job)

> **Status: current.** Corrects section 76 and the re-read's first dropped thread. Data: section 80C (job 3639554, 16 nodes, short runs, rep 1; logs in `$WORK/charades-runs/sdiag/j3639554/C_*`) and the long runs (jobs 3650921 and 3652595, rep 1, W 250 and 400; logs in `$WORK/charades-runs/long2[36]/j*/hi_*/ctl_sweep/logs/`).

**Why.** The re-read listed "`flushDue` misses PP shared buffers whose events are due" (section 76) as a thread that was dropped and never fixed. Before building a fix, this section checks the claim against the code and the logs already on disk.

**The claim repeated an error already corrected.**
- **Section 28 (2026-10-22) had found this race** and said explicitly that buffered events *are* re-checked at every update ("a first reading of this result said they were not; that was wrong"). It also showed margin 64 removes the late events at a cost in messages. Section 76 (2026-10-25) made the corrected claim again, and the re-read carried it forward.
- **The code.** htram's `flushDue` checks each shared buffer's minimum key and sends the buffer (`shipSharedPP`) when it is due. It has done so since htram f07aceb (2026-10-20), five days before section 76's job.
- **The counter.** Section 76's "events held past their due time" is `Held Stragglers`: stragglers that were *held* in an htram buffer when sent (not due then). It does not say how long they waited after becoming due.

**When they were sent.** Section 80C raised the horizon margin. That sends every event earlier by the extra margin, both when it is inserted and at every flush. On 16 nodes at W 250, GVT moves about 60 time units per update. An event sent k updates after it became due would survive any margin below about k × 60.

Held stragglers by margin (16 nodes, W 250, rep 1; % of committed events; lower is better):

| workload | setting | margin 8 | 32 | 64 | 128 |
|---|---|---|---|---|---|
| σ 2,000 | PP 2,048 | 1,903,856 (0.263%) | 129,023 (0.018%) | 1,136 | 2 |
| σ 2,000 | PP 512 | 231,416 (0.032%) | 8,782 (0.001%) | 688 | 9 |
| σ 4,000 | PP 2,048 | 2,174,101 (0.300%) | 277,704 (0.038%) | 3,019 | 10 |
| σ 4,000 | PP 512 | 702,545 (0.097%) | 31,742 (0.004%) | 2,107 | 9 |

- **Margin 64 (just above one GVT step) removes 99.7–99.9%.** So almost every late held event was sent at the update that made it due, not later. No shared buffer was skipped for a whole update.
- **Margin 32 already removes 87–96%.** So most late events have timestamps within about 24 time units above the previous horizon. Those are the first events a PE that waited at its window edge executes when the window opens.
- **PP 2,048 sends its shared buffers at nearly every update.** In the long runs on 1 node (2 processes), it sends 3.2 GVT-update messages per update against 0.9 for PP 512. PP 512's buffers fill at 512 and go out before most of their events are due; with a limit of 2,048 they rarely fill, so their events wait until due.

**The mechanism, from the code.**
- A scheduler pass first applies any new GVT (`gvt_manager->poll()`). That is also when this PE flushes its own buffers that the update made due.
- It then drains its input buffer and runs up to 128 events.
- So a PE that was blocked at its window edge learns the update within one short pass and starts executing from the old edge at once. The events that update made due only now leave their senders:
  - a busy sender learns of the update after its 128-event batch;
  - a shared buffer leaves with the first PE in its process to learn.
- Those events reach the receiver's input buffer after it has already run past them.

**Closure: does the race explain PP 2,048's loss?**
- **σ 2,000: yes, at W 250 on short runs.** *(Section 139: on long runs at W 400, a third of PP 2,048's late events were held through a whole update, so there it is not only the race.)*
  - Margin 32 removes 93% of PP 2,048's held stragglers and takes it from 251.5 to 384.2 M ev/s (+53%).
  - The same margin costs PP 512 4% (352.8 → 337.5), through 22% more messages.
  - So removing the late events is worth about +59% to PP 2,048, which puts it at about 1.1× PP 512. That is the capped setting's level (section 80B, 1.12). The race accounts for the whole loss.
  - In the long runs it is also 99.8–99.9% of PP 2,048's rollbacks: 1,522,030 of 1,525,046 timestamp rollbacks on 1 node, and 8,968,992 of 8,981,313 on 16 nodes (W 250).
- **σ 4,000: no.**
  - With margin 32, PP 2,048 has fewer held stragglers (0.038%) and higher efficiency (99.87%) than PP 512 at margin 8 (0.097%, 99.74%). Yet it is still 0.75 of PP 512's rate (229.2 against 306.6), with 23% more messages.
  - Margin 32 costs PP 512 12% at σ 4,000 (306.6 → 271.2), so the extra messages do not explain 0.75 either.
  - Something else makes the 2,048 limit slow at σ 4,000. That is not this thread.
- **σ ≤ 1,000 on 4 and 16 nodes:** PP 512 and PP 2,048 have the same held stragglers (0.007–0.07% of committed events) and the same efficiency. The gap appears only where PP 512's buffers fill before their events are due and PP 2,048's do not (for example σ 1,000 on 1 node: 0.22% against 0.003%).

**What the race costs the default (PP 512).**
- In the long runs on 16 nodes at σ ≥ 2,000, held stragglers are 0.03–0.13% of committed events (W 250–400), the most at σ 4,000 (efficiency 99.62–99.65%).
- Removing them with a larger margin costs more in messages than it saves (section 80C).
- What removing them is worth *without* the margin's extra messages is unknown. Section 138 measures it.

**New here, against sections 28, 80 and 116:** how much of PP 2,048's loss the race explains (all of it at σ 2,000, not at σ 4,000), and that at margin 8 most late events are within 24 time units of the previous horizon.

**Corrections.**
- Section 76: "`flushDue` does not send them by their deadline" is wrong. The shared buffers are sent at the update that makes them due, and their events lose a race to receivers that open their window at once.
- The re-read's first dropped thread is replaced by this section.

### Sending what the next GVT will make due before it is published (`--agg-flush-ahead`), against holding the window back (`--diag-window-lag-ns`) (design, 2026-10-28; written before any runs)

> **Status: design.** Charades `scale-diag` (this commit), htram `pdes` ed31d7e, Reconverse `pads-send-timers` 8b67e60 (no flags of its own set), the current launch. Job `$WORK/charades-runs/late30.slurm` (16 nodes, skx-dev and skx, `-x c455-081`).

**Why.** Section 137: held events go out at the GVT update that makes them due, and PEs waiting at their window edge run past them before they arrive.

**What was tried before:**
- A larger margin (sections 28, 80C and 116) removes the late events, but it sends earlier at insert and at every flush, which costs messages.
- Section 116 found that GVT at σ 2,000 with PP 512 is not paced by late arrivals: the late PE receives no events close to GVT. So PP 512 should gain little from removing the race.

Neither option below has been tried. Each removes the race without the larger margin's extra messages, one from each side:
- **Sender: send them before the update exists.** There are two moments when a PE knows the next GVT has not been published yet, and can send what it will make due:
  - **When it adds its counts to the next count wave.** The result cannot be published before every PE has done so. A busy PE contributes after 128 events.
  - **When it stops at its window edge.** It inserts nothing more until it learns the next GVT, so everything it holds that the next GVT will make due can go now. This moment matters most: a PE whose last pass was blocked contributes at once when it learns a GVT, *before* it runs its newly opened window. Most of its inserts therefore come after its contribution.
  - Either way the update's flush moves earlier instead of being repeated.
- **Receiver: open the window a little later.**
  - A PE that learns a new GVT keeps its old window edge for D µs, so the events the update made due arrive first.
  - That changes no message, so it tests the mechanism directly.
  - It may cost time if waiting PEs are on the critical path; σ 100, with almost nothing to remove, measures that cost.

**New options (all off by default):**
- **`--agg-flush-ahead=1|2`:**
  - Level 1: at each count-wave contribution, the PE first runs htram's `flushDue` with the horizon one GVT step ahead: GVT + the largest of its last 8 GVT steps + window + margin. These messages are counted as "htram Messages: Flush Ahead".
  - Level 2 adds the same horizon to idle flushes, which run after every pass that stopped at the window edge or ran out of events. These are counted as "Idle Flush", as before.
  - The insert-time urgency test and the flush at each update are unchanged; that flush finds less to send.
- **`--diag-window-lag-ns=D`:**
  - For D ns after a PE applies a new GVT, its window edge stays at the previous GVT + W.
  - Only the edge moves. Flushes, urgency, fossil collection and the GVT itself use the new GVT.
- **Held-straggler counts (always on; they run only when a held straggler arrives):**
  - µs since the receiving PE learned its latest GVT (bins 0–5, 5–10, 10–20, 20–50, 50–100, 100+);
  - ts minus the previous horizon (the GVT before + W + margin): below it (due a whole update earlier), then 0–8, 8–16, 16–32, 32–64, 64+;
  - how many arrived at a PE whose pass before that GVT stopped at its window edge.

Mac: test configs `agg_deadline_bucket_pp_flushahead` (level 2), `agg_deadline_bucket_pp_flushahead1`, `agg_deadline_bucket_wps_flushahead` (level 2) and `agg_deadline_bucket_pp_windowlag`; change tier 90/90 on the core models (five configs), committed counts unchanged. Every new option is off by default; the engine tier runs before any of them becomes a default.

**Runs** (long runs, end time 2,048,000, 3 reps; base = margin 8, the current launch):
- **A. 16 nodes:** σ 2,000 and σ 4,000 × PP 512 and PP 2,048 × W 400 (PP 512's best fixed W there in section 124) × {base, flush ahead (level 2), lag 50 µs}, plus PP 2,048 with level 1. 14 arms.
- **A′. 16 nodes, the capped setting:** PP 2,048 capped at 512 (`--agg-pp-limit=512`, sections 80B and 82), same workloads and W, {base, flush ahead}. This is what a repaired PP 2,048 has to beat.
- **B. 16 nodes, control:** σ 100, PP 2,048, W 250 × {base, flush ahead, lag 50 µs}.
- **C. 16 nodes, uniform:** WPs 512, W 400 × {base, flush ahead}. The GVT-time flush is on uniform's critical path (section 132).
- **D. 1 node:** σ 2,000, PP 512 and PP 2,048, W 250 × {base, flush ahead, lag 50 µs}.
- **Gate (2 nodes):** the three new configs plus `agg_deadline_bucket_pp`, `agg_bucket_pp` and `bucket_window`, Simple PHOLD.

**Predictions:**
- **F1. Where and when (base arms, σ ≥ 2,000):**
  - ≥ 85% of held stragglers are at most 32 past the previous horizon, and ≤ 5% are below it;
  - ≥ 60% arrive at a PE that was blocked at its window when it learned the latest GVT;
  - ≥ 70% arrive within 50 µs of that.
- **F2. The lag tests the mechanism:** lag 50 µs removes ≥ 70% of held stragglers in every σ ≥ 2,000 cell, within 15 points of the share F1 puts under 50 µs.
- **F3. Flush ahead (level 2):** removes ≥ 60% of held stragglers in every σ ≥ 2,000 cell, with htram messages per committed event within ±10% of the base. Level 1 removes less than half of what level 2 does, because blocked PEs contribute before they run their new window.
- **F4. Cost where there is nothing to remove (σ 100):**
  - flush ahead (level 2) ≥ 0.98 of the base;
  - lag 50 µs ≥ 0.95. A PE waiting at its window edge is ahead of the PE that paces each advance by about the straggler cost (93 µs at σ 100 in section 80), which is more than the lag.
- **F5. Value, 16 nodes:**
  - PP 2,048 with the better of the two is ≥ 1.25× its base at σ 2,000, and ≥ 1.10× at σ 4,000 (section 137's other loss caps it there);
  - PP 512 gains 0–4% at σ 2,000 and 0–8% at σ 4,000;
  - on 1 node, PP 2,048 gains ≥ 1.20×.
- **F6. Uniform:** flush ahead is 0.97–1.05× the base. The late PE contributes after its 128th event and flushes then, so most of the GVT-time flush stays on the critical path.
- **F7. The capped setting:** on this launch and on long runs it is 1.00–1.12× PP 512 (1.07–1.14 on short runs in sections 80B and 82). At σ 2,000, PP 2,048 with flush ahead is within 5% of it; at σ 4,000 it stays below it.

**Then:**
- **If F3 and F5 hold:** `--agg-flush-ahead` runs the full engine tier, then all eight workloads on long runs as a candidate default. After that, PP 2,048 and the capped setting are compared again at σ ≥ 2,000.
- **If F2 holds but F3 fails:** the mechanism is right but senders contribute too late. The µs bins say by how much.
- **If F2 fails:** the offset bins say where the late events come from.

### Flush ahead and window lag, results: sending early removes the late events but doubles messages; the race costs PP 512 3–5% on 16 nodes; the capped setting no longer helps (2026-10-28; skx-dev batch job 3653291, 16 nodes)

> **Status: current.** Design and predictions in section 138. 16 nodes (c454-001, -014, -023, -024, -044, -072, -082, -091, -092, c455-023, -071 to -074, -094, -101; 1-node runs on the first), 16 min. 87 runs, all ok; gate 42/42. Charades 6b37262. Summary `~/charades-data/late30/late30_summary.py`, with `summary.txt`, the CSVs and the job log in `~/charades-data/late30/j3653291/`. The 3 reps of every cell are within 2% of each other.

**Throughput** (long runs; M committed ev/s, median of 3; ÷ base, higher is better; "removed" = held stragglers removed against the base; messages = htram messages per committed event ÷ the base's):

| workload | nodes | setting | base | flush ahead (level 2) | ÷ base | removed | messages | lag 50 µs | ÷ base | removed |
|---|---|---|---|---|---|---|---|---|---|---|
| σ 2,000, W 400 | 16 | PP 512 | 482.2 | 440.7 | **0.914** | 97.8% | 2.01 | 497.5 | **1.032** | 95.2% |
| | 16 | PP 2,048 | 387.1 | 431.1 | 1.113 | 95.9% | 2.21 | 397.1 | 1.026 | 28.5% |
| | 16 | capped (2,048 allocated, 512 limit) | 462.1 | 446.9 | 0.967 | 97.8% | 1.95 | — | | |
| σ 4,000, W 400 | 16 | PP 512 | 446.5 | 395.0 | **0.885** | 98.6% | 2.33 | 468.1 | **1.048** | 92.8% |
| | 16 | PP 2,048 | 357.3 | 391.8 | 1.097 | 97.5% | 2.07 | 371.8 | 1.041 | 24.2% |
| | 16 | capped | 415.1 | 407.7 | 0.982 | 98.9% | 1.89 | — | | |
| σ 100, W 250 | 16 | PP 2,048 | 662.7 | 652.4 | 0.984 | 100% | 1.90 | 571.4 | **0.862** | 99.4% |
| uniform, W 400 | 16 | WPs 512 | 342.5 | 312.9 | **0.914** | 98.3% | 1.43 | — | | |
| σ 2,000, W 250 | 1 | PP 512 | 37.8 | 36.3 | 0.961 | 97.5% | 3.02 | 35.3 | 0.933 | 92.0% |
| | 1 | PP 2,048 | 30.9 | 34.8 | 1.127 | 96.0% | 5.29 | 30.1 | 0.975 | 49.3% |

Level 1 (at contributions only), PP 2,048, 16 nodes: 380.2 at σ 2,000 (0.982×, 74% removed) and 345.6 at σ 4,000 (0.967×, 84% removed), with 1.9× the messages.

**Where and when the late held events arrive** (base arms, 16 nodes, all 3 reps; shares of held stragglers):

| workload, setting | held stragglers, % of committed | at most 32 past the previous horizon | below it (due a whole update earlier) | arrived < 50 µs / ≥ 100 µs after the receiver learned its GVT | at a PE then blocked at its window |
|---|---|---|---|---|---|
| σ 2,000, PP 512 | 0.034% | 0.98 | 0.00 | 0.60 / 0.02 | 0.96 |
| σ 4,000, PP 512 | 0.11% | 0.97 | 0.00 | 0.24 / 0.05 | 0.96 |
| σ 2,000, capped | 0.033% | 0.98 | 0.00 | 0.59 / 0.02 | 0.95 |
| σ 100, PP 2,048 | 0.011% | 0.99 | 0.00 | 0.84 / 0.00 | 0.97 |
| uniform, WPs 512 | 0.20% | 0.99 | 0.00 | 0.00 / 0.95 | 0.97 |
| σ 2,000, PP 2,048 | 0.78% | 0.35 | 0.30 | 0.19 / 0.66 | 0.69 |
| σ 4,000, PP 2,048 | 0.76% | 0.42 | 0.27 | 0.16 / 0.65 | 0.72 |

**Predictions.**
- **F1:**
  - **Where:** right for PP 512, the capped setting, σ 100 and uniform. 97–99% of late events are at most 32 past the previous horizon, none are below it, and 95–97% reach a PE that was blocked at its window.
  - **When:** wrong. Within 50 µs is 60% at σ 2,000, 24% at σ 4,000 and 0% on uniform; uniform's arrive 100 µs or more after the update.
  - **PP 2,048:** wrong in both. A third of its late events were due a whole update earlier, and two-thirds arrive 100 µs or more after the receiver's GVT.
- **F2:** right for PP 512 (the lag removes 95% and 93%; 92% on 1 node). Wrong for PP 2,048 (28% and 24%; 49% on 1 node).
- **F3:** half right.
  - Level 2 removes 96–99% everywhere, but it does not keep messages within ±10%: it sends 1.9–2.3× the htram messages per event on 16 nodes, 1.4× on uniform, and 3–5× on 1 node. Most leave as "Flush Ahead" messages, at about twice the per-update count of the update flushes they replace.
  - Level 1 removes 74–84%, more than predicted.
- **F4:** half right. Flush ahead at σ 100 is 0.984; the lag costs 14% (0.862). A PE waiting at its window edge is on the critical path at σ 100.
- **F5:**
  - Wrong for PP 2,048: 1.113 at σ 2,000, 1.097 at σ 4,000 and 1.127 on 1 node, against ≥ 1.25, ≥ 1.10 and ≥ 1.20.
  - Right for PP 512 with the lag: +3.2% at σ 2,000 and +4.8% at σ 4,000. With flush ahead it loses 9–12%.
- **F6:** wrong. Flush ahead costs uniform 8.6%.
- **F7:** wrong. On this launch and on long runs the capped setting is 0.958 (σ 2,000) and 0.930 (σ 4,000) of PP 512. Its 1.07–1.14× in sections 80B and 82 (short runs, the launch before 23 devices, ring input buffers and `+mempool_remote_free`) is gone.

**What it says.**
- **The race costs the default (PP 512) about 3–5% at σ ≥ 2,000 on 16 nodes.**
  - The lag removes 93–95% of its late events with the same messages and gains 3.2% and 4.8%.
  - That is a lower bound on the race's cost, since the lag also costs something: 14% at σ 100, where there was nothing to remove, and 7% on 1 node.
- **Sending early removes the race but costs more than the race does.**
  - It doubles htram messages, and on 16 nodes messages cost more than the 0.03–0.2% of events the race rolls back. The margin did the same in sections 28 and 80C.
  - `--agg-flush-ahead` stays off.
- **The lag is not a default either.**
  - It helps where late events are frequent (σ ≥ 2,000 on 16 nodes) and costs 7–14% where they are not.
  - Only a lag that turns itself on from the measured rate of late held events could gain those 3–5%, on two workloads at 16 nodes. Not built.
- **The capped setting is no longer a candidate.** Its earlier gain did not survive the current launch and long runs.
- **PP 2,048's problem at σ ≥ 2,000 is not only the race.**
  - On long runs at W 400, a third of its late events were held through a whole update, and most arrive long after the receiver's GVT.
  - So its shared buffers do leave late, or take long to arrive, beyond the one-step race. Flush ahead fixes most of that (+10–11%), but PP 2,048 still trails PP 512 by 11–12%.
  - Not pursued: PP 512 is the setting at σ ≥ 2,000, and PP 2,048 wins only at σ ≤ 1,000, where the two have the same late events.

**Thread closed.** Defaults unchanged.

### Paper-grade scaling, 1–32 nodes: the plan; A0, ROSS tuning (design, 2026-10-28; written before any runs)

> **Status: design.** Charades `main` f57243e (`scale-diag` fast-forwarded into it). ROSS dc3a6a0 + `phold-gauss`, mvapich 3.0. Devastator 2c90067-era binaries (`$WORK/devastator/bin/ofi-psm2`, CLCG4). Job A0 `$WORK/charades-runs/ross31.slurm` (16 nodes, skx-dev and skx, `-x c455-081`).

**Decisions (the user, 2026-10-28):**
- Node counts 1, 2, 4, 8, 16 and 32. Charades against Devastator and ROSS on Gaussian PHOLD, then on traffic and dragonfly.
- Charades' number is its controller, with two fixed W beside it.
- Both models are ported to both other engines.
- glibc no-trim stays out of every launch.

**Phase A, Gaussian PHOLD:**
- **A0 (this section):** ROSS tuning. ROSS has only ever run with its default batch and GVT interval (sections 16, 43).
- **A1, 16 nodes:** 1/2/4/8/16 nodes.
- **A2, 32 nodes:** 16 and 32 nodes. Running 16 again gives the 16→32 step within one allocation; efficiencies from different allocations have differed by up to ±0.1 (section 77).
- **Common to A1 and A2:**
  - All 8 workloads, long runs (end time 2,048,000; 512,000 at lookahead 10), 3 reps, engines interleaved within each rep. Every cell checks that the engines committed the same number of events.
  - 128 LPs per PE or rank. Charades and Devastator run 2 processes × 23 per node, ROSS 46 ranks per node, so all three engines simulate the same LPs.
  - **Charades:** the controller, plus W 250 and 400 (lookahead 10: 50 and 100). The htram setting is fixed per workload from the 1/4/16 long runs: PP 2,048 at σ ≤ 1,000 and at lookahead 10 σ 500; PP 512 at σ 2,000 and σ 4,000. Uniform and lookahead 10 σ 2,000 run both PP 512 and WPs 512, because their best setting changes with node count.
  - **Devastator:** W 500, 1,000 and 2,000 (lookahead 10: 100, 200, 400), plus 4,000 at 32 nodes.
  - **ROSS:** A0's best setting for each workload.
- **Runtime frozen for A1 and A2:** Reconverse 22871c6 (`+mempool_remote_free`, as in the launch, without the diagnostic send timers), Charm++ 9d6a55780, htram `pdes` ed31d7e. Mac engine tier on `main` f57243e: 1,932/1,932.

**Phase B, traffic and dragonfly:**
- Both models need a change before they can be weak-scaled:
  - **Traffic:** cars leave at their destination, and routes grow with the grid, so the load per PE changes with scale. Cars need a new destination on arrival, or destinations within a fixed distance.
  - **Dragonfly:** each process sends 3,000 / arrive-rate messages and the network then drains. It needs a generation window as an option.
- Then: port both models to ROSS and Devastator, each checked for the same committed events as Charades on the Mac; size each model with Charades on Stampede3; then the same shape as A1 and A2.

**A0, ROSS tuning:**
- **Runs:**
  - Optimistic ROSS (`--synch=3 --read-buffer=1`): `--batch` 4, 16 and 64 × `--gvt-interval` 16, 64 and 256, plus conservative ROSS (`--synch=2`, the defaults).
  - Workloads: σ 100, σ 2,000, uniform, and lookahead 10 σ 2,000.
  - 4 and 16 nodes, end time 512,000 (128,000 at lookahead 10), 1 rep. At this end time ROSS's reps agree to within 2.5% (section 43).
  - 80 runs, about 30 minutes.
- **Predictions:**
  - **R1.** At 16 nodes on σ 2,000, the best optimistic setting is 1.1–1.5× ROSS's default (batch 16, GVT interval 16: 95.1 M ev/s in section 43).
  - **R2.** Conservative ROSS is at most 0.8× the best optimistic setting at lookahead 100 σ 2,000 and uniform, and at most 0.5× at lookahead 10.
  - **R3.** For at least 3 of the 4 workloads, the best setting at 4 nodes is within 3% of the best at 16 nodes. One setting per workload then serves every node count; otherwise A1 and A2 use the two best.
  - **R4.** With its best setting, ROSS at 16 nodes on σ 2,000 is at most a third of Charades' long-run 518.9 M ev/s (section 124).

### A0, ROSS tuning, results; A1 and A2, paper-grade weak scaling (A0 results and A1/A2 design, 2026-10-28; skx-dev batch job 3653550, 16 nodes; A1/A2 design written before their runs)

> **Status: current (A0) / design (A1, A2).** A0's design is in section 140. 80 runs, 40 minutes. One run (σ 100, 4 nodes, batch 4, GVT interval 16) printed full results and then hung on exit until the 400 s timeout; its numbers are used. Data and script in `~/charades-data/ross31/j3653550/`.

**ROSS, M committed ev/s** (higher is better; end time 512,000, 128,000 at lookahead 10; 1 rep):

| workload | nodes | conservative | b4/g16 | b4/g64 | b4/g256 | **b16/g16 (default)** | **b16/g64** | b16/g256 | b64/g16 | b64/g64 | b64/g256 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| σ 100 | 4 | **67.0** | 40.3 | 49.6 | 54.7 | 52.0 | 55.0 | 39.1 | 54.7 | 26.1 | 9.4 |
| | 16 | **227.2** | 128.0 | 170.0 | 195.9 | 175.1 | 199.7 | 119.2 | 185.6 | 86.1 | 23.3 |
| σ 2,000 | 4 | **30.0** | 21.6 | 25.9 | 27.5 | 26.8 | 29.6 | 28.9 | 29.5 | 26.9 | 1.0 |
| | 16 | 109.2 | 72.0 | 90.9 | 104.9 | 97.5 | 111.1 | 108.7 | **112.1** | 104.7 | 3.6 |
| uniform | 4 | 26.8 | 19.2 | 22.7 | 25.0 | 23.5 | 26.6 | 26.7 | **27.3** | 26.6 | 23.6 |
| | 16 | 93.9 | 64.6 | 82.0 | 91.9 | 86.0 | 98.8 | 101.2 | 101.1 | **102.8** | 3.0 |
| lookahead 10, σ 2,000 | 4 | 26.9 | 21.1 | 25.4 | 26.9 | 26.4 | **29.1** | 26.2 | 28.9 | 23.5 | 0.7 |
| | 16 | 94.1 | 71.4 | 92.1 | 103.0 | 96.1 | **108.4** | 94.4 | 106.4 | 87.4 | 2.5 |

(b = `--batch`, g = `--gvt-interval`; the other columns are optimistic with `--read-buffer=1`.) Every setting committed the same events within a workload.

- **R1 right.** Tuning is worth 1.06–1.20× over ROSS's default (1.15× at 16 nodes on σ 2,000).
- **R2 wrong.**
  - Conservative ROSS is ROSS's *fastest* mode at σ 100 (1.22× and 1.14× the best optimistic setting) and level at σ 2,000 (1.01, 0.97).
  - It is behind on uniform (0.98, 0.91) and at lookahead 10 (0.92, 0.87), less than predicted.
  - With 128 LPs per rank most σ 100 events stay on their rank, so conservative ROSS rarely waits.
- **R3 right.** Batch 16 / GVT interval 64 is the best setting or within 4% of it in every cell, at both node counts.
- **R4 right.** ROSS's best at 16 nodes on σ 2,000 (112.1) is 0.22 of Charades' long-run 518.9. The runs are of different lengths; A1 compares equal ones.
- Batch 64 with GVT interval 256 collapses (efficiency reported negative), so it is never used.

**Decision:** ROSS runs two arms in A1 and A2: optimistic batch 16 / GVT interval 64, and conservative. Each cell reports ROSS's better arm.

**A1 and A2: design.**
- **Jobs** (`$WORK/charades-runs/scale32.slurm`):
  - **A1a and A1b**, 16 nodes each: workload groups a (σ 100, σ 1,000, σ 4,000, lookahead 10 σ 2,000) and b (σ 500, σ 2,000, uniform, lookahead 10 σ 500). Each runs the 8-, 4-, 2- and 1-node series side by side on disjoint nodes of its allocation, then 16 nodes alone.
  - **A2**, 32 nodes: groups a and b at 16 nodes side by side on the two halves, then all eight workloads at 32 nodes.
  - Every job starts with a 2-node Charades gate. Each series starts with one discarded warm-up run.
- **Why run series side by side:**
  - It fits all five node counts into one allocation of under 2 hours, against about 4.5 hours one after another.
  - 1-node runs use no network. Runs on 2–8 nodes share only the fabric with the others, never a node.
  - Each series checks within itself that the engines committed the same events.
- **Arms, per workload and rep, interleaved:**
  - **Charades:** the controller (ε 0.001), plus W 250 and 400 (lookahead 10: 50 and 100), with the htram setting of section 140. Uniform and lookahead 10 σ 2,000 run both PP 512 and WPs 512.
  - **Devastator:** W 500, 1,000 and 2,000 (lookahead 10: 100, 200 and 400), plus 4,000 at 32 nodes; CLCG4.
  - **ROSS:** the two arms above, 46 ranks per node.
- **Runs:** long runs (end time 2,048,000; 512,000 at lookahead 10), 3 reps.

**Predictions:**
- **P1.** Every cell has the same committed events in all three engines.
- **P2.** At 1, 4 and 16 nodes, Charades ÷ Devastator is within ±0.07 of the long-run table (sections 124 and 130).
- **P3.** Each engine's per-node rate falls steadily with node count, so 2 and 8 nodes lie between their neighbours, with no step from running series side by side.
- **P4.** 16→32 nodes, per-node rate at 32 ÷ at 16:
  - Charades ≥ 0.85 on the Gaussian workloads;
  - Charades ≤ 0.85 on uniform, whose off-node share rises from 94% to 97%;
  - Devastator ≥ 0.88 on the Gaussian workloads.
- **P5.** Charades' controller is within 3% of its better fixed W at every node count, or better.
- **P6.** Charades ÷ ROSS (ROSS's better arm) is ≥ 3 at every node count on σ ≥ 1,000 and uniform, and ≥ 2.5 at σ 100.
- **P7.** Charades leads Devastator in at least 42 of the 48 workload × node-count cells.

### A1a, weak scaling 1–16 nodes, group a (σ 100, σ 1,000, σ 4,000, lookahead 10 σ 2,000), results (2026-10-28; skx-dev batch job 3653803, 16 nodes)

> **Status: current.** Design and predictions in section 141. 16 nodes (c454-024, -101, -102, c455-001, -012 to -014, -024, -031 to -034, -041 to -044), 53 minutes; gate 30/30.
> - 525 runs, all ok: Charades 225, Devastator 180, ROSS 120.
> - **Every cell has the same committed events in all three engines.**
> - The job log printed no Charades commit (a `git` error on the compute node). The tree was `main` 4331e65, with code identical to f57243e.
> - Summary `~/charades-data/scale32/scale32_summary.py`; data and `summary.txt` in `~/charades-data/scale32/scale32/a_j3653803/`.

**M committed ev/s, median of 3** (Charades: its controller; Devastator: its best W; ROSS: its better arm. C÷D and C÷R are Charades ÷ the other engine, higher is better):

| workload | nodes | Charades | Devastator (W) | ROSS (arm) | C÷D | C÷R |
|---|---|---|---|---|---|---|
| σ 100 | 1 | 45.9 | 41.6 (2,000) | 18.9 (cons.) | 1.10 | 2.42 |
| | 2 | 89.9 | 85.0 (500) | 33.5 (cons.) | 1.06 | 2.69 |
| | 4 | 172.8 | 167.2 (500) | 63.0 (cons.) | 1.03 | 2.74 |
| | 8 | 323.9 | 313.0 (1,000) | 117.3 (cons.) | 1.03 | 2.76 |
| | 16 | 674.5 | 647.9 (1,000) | 224.4 (cons.) | 1.04 | 3.01 |
| σ 1,000 | 1 | 36.2 ¹ | 36.4 (1,000) | 9.5 (cons.) | 0.99 ¹ | 3.82 |
| | 2 | 75.3 | 66.8 (1,000) | 17.8 (cons.) | 1.13 | 4.24 |
| | 4 | 148.4 | 122.3 (1,000) | 34.0 (cons.) | 1.21 | 4.37 |
| | 8 | 278.1 | 214.9 (1,000) | 64.3 (cons.) | 1.29 | 4.32 |
| | 16 | 557.5 | 429.9 (1,000) | 125.5 (cons.) | 1.30 | 4.44 |
| σ 4,000 | 1 | 37.0 | 28.1 (500) | 9.0 (cons.) | 1.32 | 4.10 |
| | 2 | 68.8 | 41.3 (500) | 14.1 (cons.) | 1.66 | 4.87 |
| | 4 | 126.7 | 75.9 (1,000) | 26.7 (cons.) | 1.67 | 4.75 |
| | 8 | 237.9 | 143.7 (1,000) | 51.7 (opt.) | 1.66 | 4.60 |
| | 16 | 462.9 | 288.7 (1,000) | 101.4 (opt.) | 1.60 | 4.56 |
| lookahead 10, σ 2,000 | 1 | 33.7 | 28.3 (100) | 8.5 (opt.) | 1.19 | 3.98 |
| | 2 | 62.2 | 48.6 (200) | 14.0 (opt.) | 1.28 | 4.44 |
| | 4 | 119.4 | 94.0 (200) | 27.1 (opt.) | 1.27 | 4.41 |
| | 8 | 230.0 | 179.3 (200) | 53.2 (opt.) | 1.28 | 4.33 |
| | 16 | 457.8 | 339.5 (200) | 103.6 (opt.) | 1.35 | 4.42 |

¹ With PP 2,048, which is 9% slower than PP 512 on 1 node at σ 1,000 (see below).

**Weak-scaling efficiency** (per-node rate ÷ the 1-node rate; 1.0 is perfect), Charades / Devastator / ROSS:

| workload | 2 nodes | 4 | 8 | 16 |
|---|---|---|---|---|
| σ 100 | 0.98 / 1.02 / 0.88 | 0.94 / 1.00 / 0.83 | 0.88 / 0.94 / 0.77 | 0.92 / 0.97 / 0.74 |
| σ 1,000 ¹ | 1.04 / 0.92 / 0.94 | 1.03 / 0.84 / 0.90 | 0.96 / 0.74 / 0.85 | 0.96 / 0.74 / 0.83 |
| σ 4,000 | 0.93 / 0.74 / 0.78 | 0.86 / 0.68 / 0.74 | 0.80 / 0.64 / 0.72 | 0.78 / 0.64 / 0.70 |
| lookahead 10, σ 2,000 | 0.92 / 0.86 / 0.83 | 0.88 / 0.83 / 0.80 | 0.85 / 0.79 / 0.78 | 0.85 / 0.75 / 0.76 |

**Charades' controller ÷ its better fixed W:** 0.97–1.02 in all 20 cells.

**Predictions (group a):**
- **P1 right.** The three engines committed the same events in all 20 cells.
- **P2 right in 11 of 12 cells.** Charades ÷ Devastator at 1/4/16 nodes is within ±0.07 of the long-run table. The exception, σ 1,000 on 1 node (0.99 against 1.11), is the htram setting.
- **P3 partly wrong.**
  - At σ 100, 8 nodes is below 16 nodes for both Charades (0.88 against 0.92) and Devastator (0.94 against 0.97). The 8-node series ran beside the 4- and 2-node ones; the 16-node series ran alone.
  - Elsewhere every engine declines steadily, apart from the σ 1,000 baseline.
  - A2's 16-node series also run side by side; set against A1's 16 nodes alone, they test whether that costs anything.
- **P5 right.** The controller is 0.97–1.02 of the better fixed W.
- **P6 right except σ 100 on 1 node.** That cell is 2.42, against ≥ 2.5. Elsewhere Charades ÷ ROSS is 2.69–3.01 at σ 100 and 3.82–4.87 on the other three workloads.
- **P7: on track.** Charades leads Devastator in 19 of 20 cells; the 20th is the σ 1,000 setting.

**A design error, and its fix.**
- **The error.** Section 140 fixed PP 2,048 for σ ≤ 1,000 at every node count. But section 130's long runs had PP 512 best *on 1 node* (σ 1,000: controller 40.5 with PP 512, 37.1 with PP 2,048), and PP 2,048 best only from 4 nodes up.
- **The effect.** Charades' 1-node σ 1,000 rate is understated by about 9%. That pushes its σ 1,000 efficiency above 1.0 (1.04 at 2 nodes) and puts Charades ÷ Devastator at 0.99 on 1 node.
- **Unaffected:** σ 100, σ 500 and lookahead 10 σ 500, where PP 512 and PP 2,048 are level on 1 node (within 0.5%).
- **The fix.** A1b (resubmitted as 3654651 / 3654652 before it started) adds a Charades-only σ 1,000 series with both PP 512 and PP 2,048 at every node count. Charades' σ 1,000 numbers will be taken from it, with the better setting at each node count, as the long-run tables did.

**Other observations:**
- **ROSS's better arm** is conservative at σ 100 and σ 1,000 at every node count, and at σ 4,000 up to 4 nodes. Elsewhere it is optimistic.
- **Devastator's largest loss is its first network step:** 1→2 nodes at σ 4,000 costs it 0.74, against Charades' 0.93.

### A1b, weak scaling 1–16 nodes, group b (σ 500, σ 2,000, uniform, lookahead 10 σ 500) and σ 1,000 with both htram settings, results; all eight workloads at 1–16 nodes (2026-10-28; skx-dev batch job 3654651, 16 nodes)

> **Status: current.** Design and predictions in section 141; the extra σ 1,000 series is explained in section 142. 16 nodes (c454-043, c455-003, -004, -011, -024, -031 to -033, -043, -044, -082, -083, -101 to -104), 59 minutes; gate 30/30.
> - Charades 0a212f0, with code identical to f57243e.
> - 615 runs, all ok: Charades 315, Devastator 180, ROSS 120.
> - **Every cell has the same committed events in all three engines.**
> - A1b's duplicate skx copy (3654652) was cancelled before it started.
> - Summaries `~/charades-data/scale32/scale32_summary.py` and `combine_a1.py` (A1a + A1b); data and `summary.txt` in `~/charades-data/scale32/scale32/b_j3654651/`.

**M committed ev/s, median of 3** (Charades: its controller; Devastator: its best W; ROSS: its better arm. C÷D and C÷R are Charades ÷ the other engine, higher is better):

| workload | nodes | Charades | Devastator (W) | ROSS (arm) | C÷D | C÷R |
|---|---|---|---|---|---|---|
| σ 500 | 1 | 40.1 | 38.9 (1,000) | 11.6 (cons.) | 1.03 | 3.47 |
| | 2 | 77.8 | 75.3 (1,000) | 20.9 (cons.) | 1.03 | 3.71 |
| | 4 | 156.1 | 144.3 (1,000) | 40.0 (cons.) | 1.08 | 3.90 |
| | 8 | 291.2 | 242.3 (1,000) | 76.4 (cons.) | 1.20 | 3.81 |
| | 16 | 600.1 | 503.5 (1,000) | 147.3 (cons.) | 1.19 | 4.08 |
| σ 2,000 | 1 | 37.6 | 29.7 (500) | 9.3 (cons.) | 1.27 | 4.05 |
| | 2 | 69.5 | 50.6 (1,000) | 14.6 (cons.) | 1.37 | 4.76 |
| | 4 | 134.4 | 100.0 (1,000) | 28.2 (cons.) | 1.34 | 4.77 |
| | 8 | 254.2 | 184.1 (1,000) | 53.6 (cons.) | 1.38 | 4.74 |
| | 16 | 494.1 | 366.9 (1,000) | 105.5 (opt.) | 1.35 | 4.68 |
| uniform | 1 | 40.5 (WPs) | 29.4 (500) | 9.3 (cons.) | 1.38 | 4.35 |
| | 2 | 72.7 (PP) | 38.9 (500) | 13.9 (cons.) | 1.87 | 5.24 |
| | 4 | 133.8 (PP) | 67.3 (500) | 25.1 (cons.) | 1.99 | 5.32 |
| | 8 | 207.3 (WPs) | 106.8 (1,000) | 47.9 (opt.) | 1.94 | 4.33 |
| | 16 | 355.2 (WPs) | 192.8 (1,000) | 92.9 (opt.) | 1.84 | 3.82 |
| lookahead 10, σ 500 | 1 | 37.0 | 39.0 (100) | 10.6 (cons.) | 0.95 | 3.51 |
| | 2 | 72.8 | 74.8 (200) | 19.0 (opt.) | 0.97 | 3.84 |
| | 4 | 144.9 | 142.4 (200) | 36.8 (opt.) | 1.02 | 3.94 |
| | 8 | 272.7 | 236.8 (200) | 70.9 (opt.) | 1.15 | 3.85 |
| | 16 | 565.8 | 495.9 (200) | 139.7 (opt.) | 1.14 | 4.05 |

**σ 1,000, Charades' controller with each htram setting** (M ev/s, median of 3, higher is better):

| nodes | 1 | 2 | 4 | 8 | 16 |
|---|---|---|---|---|---|
| PP 512 | **38.9** | 74.9 | 145.8 | **285.0** | 543.1 |
| PP 2,048 | 36.6 | 74.9 | **149.2** | 279.3 | **554.6** |
| A1a's PP 2,048 (job 3653803) | 36.2 | 75.3 | 148.4 | 278.1 | 557.5 |

The two allocations agree within 1.2% at every node count, so the σ 1,000 numbers below take Charades from this series (the better setting at each node count) and Devastator and ROSS from A1a.

**All eight workloads, 1–16 nodes** (A1a + A1b):

| workload | Charades ÷ Devastator at 1 / 2 / 4 / 8 / 16 nodes | Charades ÷ ROSS | efficiency 1→16, Charades / Devastator / ROSS | M ev/s at 16 nodes, Charades / Devastator / ROSS |
|---|---|---|---|---|
| σ 100 | 1.10 / 1.06 / 1.03 / 1.03 / 1.04 | 2.42–3.01 | 0.92 / **0.97** / 0.74 | 674.5 / 647.9 / 224.4 |
| σ 500 | 1.03 / 1.03 / 1.08 / 1.20 / 1.19 | 3.47–4.08 | **0.93** / 0.81 / 0.80 | 600.1 / 503.5 / 147.3 |
| σ 1,000 | 1.07 / 1.12 / 1.22 / 1.33 / 1.29 | 4.11–4.43 | **0.89** / 0.74 / 0.83 | 554.6 / 429.9 / 125.5 |
| σ 2,000 | 1.27 / 1.37 / 1.34 / 1.38 / 1.35 | 4.05–4.77 | **0.82** / 0.77 / 0.71 | 494.1 / 366.9 / 105.5 |
| σ 4,000 | 1.32 / 1.66 / 1.67 / 1.66 / 1.60 | 4.10–4.87 | **0.78** / 0.64 / 0.70 | 462.9 / 288.7 / 101.4 |
| uniform | 1.38 / 1.87 / 1.99 / 1.94 / 1.84 | 3.82–5.32 | 0.55 / 0.41 / **0.62** | 355.2 / 192.8 / 92.9 |
| lookahead 10, σ 500 | 0.95 / 0.97 / 1.02 / 1.15 / 1.14 | 3.51–4.05 | **0.95** / 0.79 / 0.83 | 565.8 / 495.9 / 139.7 |
| lookahead 10, σ 2,000 | 1.19 / 1.28 / 1.27 / 1.28 / 1.35 | 3.98–4.44 | **0.85** / 0.75 / 0.76 | 457.8 / 339.5 / 103.6 |

(Efficiency = per-node rate at 16 nodes ÷ the 1-node rate, 1.0 is perfect; bold = best of the three.)

**Predictions, both groups:**
- **P1 right.** The three engines committed the same events in all 40 cells.
- **P2 right in 24 of 24 cells,** once σ 1,000 on 1 node uses PP 512 (1.07 against 1.11). Charades ÷ Devastator at 1/4/16 nodes is within ±0.07 of the long-run table; σ 500 is at the edge on 1 and 4 nodes (−0.07). Ratios here run a little below the long-run table's, because Charades' number is now its controller rather than its best setting.
- **P3 partly wrong.**
  - At the low-σ workloads (σ 100, σ 500, lookahead 10 σ 500), 8 nodes is below 16 nodes for both Charades (0.88/0.92, 0.91/0.93, 0.92/0.95) and Devastator (0.94/0.97, 0.78/0.81, 0.76/0.79). Elsewhere every engine declines steadily.
  - Both engines dip together, so the cause is probably the 8-node series running beside the others, not either engine. A2 was meant to test that directly, with its 16-node series side by side, but could not (section 144).
- **P5 right in 39 of 40 cells.** The controller is 0.96–1.03 of the better fixed W; the exception is σ 2,000 on 1 node (0.96).
- **P6 right except σ 100 on 1 node** (2.42 against ≥ 2.5).
- **P7: 38 of 40 cells so far,** with A2's 32-node cells to come. The two cells where Charades trails are lookahead 10 σ 500 on 1 and 2 nodes (0.95 and 0.97).

**What it says:**
- **Charades is faster than Devastator in 38 of 40 cells,** by up to 1.99×, and 1.04–1.84× at 16 nodes. It is 2.4–5.3× faster than ROSS everywhere.
- **Charades scales best of the three in 6 of 8 workloads** from 1 to 16 nodes.
  - At σ 100, which barely communicates, Devastator scales better (0.97 against 0.92), though Charades is still 1.04× faster at 16 nodes.
  - On uniform, ROSS scales best (0.62) but runs at a quarter of Charades' rate.
- **Devastator's largest losses are at its first network step.** 1→2 nodes costs it 0.66 on uniform and 0.74 at σ 4,000, against Charades' 0.90 and 0.93.
- **Uniform from 4 to 16 nodes** is still Charades' weak spot: 0.66, against Devastator's 0.72. Section 124 found the same.

### A2, 32 nodes: a noisy allocation, so the 32-node point is rerun (A2 results and A2r design, 2026-10-29; skx batch job 3653806, 32 nodes; A2r design written before its run)

> **Status: not for use (A2) / design (A2r).** A2's design and predictions are in section 141.
> - **Placement:** 32 nodes over 15 racks (c476-091 to c500-033), against two racks (c454, c455) for each of A1's allocations.
> - **Timing:** ran 02:26–05:06 and was cancelled at its 2 h 40 min limit, 1 h 31 min into the 32-node series.
> - **Gate:** 29/30 at first. The failure was a /work2 read error, and the rerun passed 30/30.
> - **Completed:**
>   - the side-by-side 16-node series, 3 reps for both groups;
>   - at 32 nodes, rep 1 of all eight workloads;
>   - rep 2 of six workloads, plus part of uniform; lookahead 10 σ 500 got no rep 2;
>   - no rep 3.
> - **Committed events:** the same in every cell where all three engines finished.
> - **Failed runs:**
>   - ROSS uniform hit its 240 s timeout three times: 16 nodes conservative rep 1, and both arms of rep 1 at 32 nodes.
>   - ROSS σ 2,000, optimistic rep 2 at 16 nodes, printed results and then hit the timeout.
>   - Three Devastator runs at 32 nodes (σ 500 and σ 4,000, W 1,000) printed results but exited with code 1. They are left out.
> - **Data:** result files only, in `~/charades-data/scale32/scale32/big_j3653806/`. The 53,459 files of per-run output stay on /work2.

**Every engine ran slower and less evenly than in A1.** Median rate at 16 nodes in A2 ÷ in A1 (each engine's headline arm: Charades' controller, Devastator's best W, ROSS's better arm; below 1.00 means slower in A2):

| workload | Charades | Devastator | ROSS |
|---|---|---|---|
| σ 100 | 0.79 | 0.90 | 0.72 |
| σ 500 | 0.87 | 1.00 | 0.70 |
| σ 1,000 | 0.71 | 0.91 | 0.76 |
| σ 2,000 | 0.50 | 0.93 | 0.58 |
| σ 4,000 | 0.75 | 0.79 | 0.61 |
| uniform | 0.72 | 0.83 | 0.44 |
| lookahead 10, σ 500 | 0.69 | 0.91 | 0.71 |
| lookahead 10, σ 2,000 | 0.55 | 0.84 | 0.79 |

**Rep spread at 16 nodes** (max ÷ min over the 3 reps of one arm; 1.00 is perfectly repeatable, lower is better):
- **Charades:** 1.00–1.09 in A1, 1.04–3.56 in A2.
- **Devastator:** 1.00–1.08 in A1, apart from three single slow reps (88, 79 and 65 M ev/s); 1.06–1.85 in A2.

**32 nodes, median of 1–2 reps.** These numbers are recorded, not used: at 32 nodes Charades' runs of one workload span 2–4×.

M committed ev/s, higher is better; C÷D and C÷R are Charades' controller ÷ the other engine:

| workload | reps | Charades controller | Charades best fixed W | Devastator (W) | ROSS (arm) | C÷D | C÷R | Charades, every run, min–max |
|---|---|---|---|---|---|---|---|---|
| σ 100 | 2 | 441.6 | 990.2 (W 400) | 1,165.1 (1,000) | 237.9 (cons.) | 0.38 | 1.86 | 399–990 |
| σ 500 | 2 | 406.9 | 705.3 (W 400) | 767.0 (1,000) | 120.6 (cons.) | 0.53 | 3.37 | 372–960 |
| σ 1,000 | 2 | 403.5 | 651.7 (W 400) | 767.4 (1,000) | 114.2 (cons.) | 0.53 | 3.53 | 324–937 |
| σ 2,000 | 2 | 298.6 | 659.5 (W 400) | 475.2 (1,000) | 134.7 (opt.) | 0.63 | 2.22 | 239–817 |
| σ 4,000 | 2 | 363.3 | 553.8 (W 250) | 359.7 (500) | 98.8 (opt.) | 1.01 | 3.68 | 253–772 |
| uniform | 2, partial | 246.9 (WPs) | 241.1 (WPs, W 400) | 234.4 (1,000) | — (timed out) | 1.05 | — | 149–263 |
| lookahead 10, σ 500 | 1 | 512.5 | 465.9 (W 50) | 626.2 (400) | 82.0 (cons.) | 0.82 | 6.25 | 439–512 |
| lookahead 10, σ 2,000 | 2 | 486.2 | 479.2 (W 50) | 513.8 (200) | 92.3 (opt.) | 0.95 | 5.27 | 208–594 |

**What it says:**
- **The slow runs did the same work, only more slowly.** Across the reps of one arm (one workload, htram setting and node count):
  - **GVT count** varies by a median of 0.9% (at most 15%);
  - **events per message** by a median of 1.2% (at most 12%);
  - **efficiency** by a median of 0.07 points (at most 2.4, uniform).
  - Neither the GVT count nor events per message follows the rate (correlation 0.01).
  - Rate and execution time vary by a median of 1.50× and at most 3.56×. For example, σ 1,000 at W 400 on 32 nodes took 6.2 s against 15.8 s.
- **The cause is outside the engines:**
  - All three engines were hit in the same job.
  - Both 16-node halves were hit, so it is not one slow node.
  - This job and A1's differ in placement (15 racks against 2) and in time of day (02:26–05:06). One job cannot separate the two, or either from other jobs' traffic on the fabric.
  - **Added after the A2r submission: placement alone is unlikely.**
    - Job 3633770 (section 43; 2026-10-24, 07:49–07:58) ran on production skx nodes over 15 racks (c476–c506), as spread as A2.
    - Its Charades runs repeated well: rep spread over 16 settings at 32 nodes had a median of 1.014 and a maximum of 1.075. Those were short runs with 2 reps on an older stack.
    - Our own traffic is too small to congest the fabric. Uniform at 16 nodes sends about 1.5 GB/s per node (355 M ev/s × 94% off-node × about 70 B), 12% of a 100 Gb/s link. A leaf switch serves 28 nodes with 20 uplinks.
    - Extra switch hops cost about 0.2 µs, against a GVT step of about 200 µs. A1's allocations already spanned 3–4 leaf switches.
    - So the likelier cause is load from other jobs on shared links while A2 ran. A2's gate also hit a /work2 read error at 02:31.
    - `--contiguous` reduces how many shared links we cross, but does not avoid them.
- **Charades lost more than Devastator in all eight workloads:** 0.50–0.87 against 0.79–1.00. It lost about as much as ROSS, and more in 4 of 8.
  - A hypothesis, not tested here: section 78 found that time per GVT advance limits Charades at 16 nodes, and a GVT wave waits for its slowest message. Uneven message latency would therefore cost Charades the most.
  - If it holds, this is a robustness weakness to report, not just noise to avoid.
- **P3's side-by-side question is still open.** It asked whether running series side by side caused A1's 8-node dip. Placement changed together with side-by-side running, so this job cannot answer it.
- **The controller at 32 nodes is probably not special.**
  - On the five lookahead-100 Gaussian workloads it never reached the fast group: 0 of 10 runs, best 484 M ev/s. Fixed-W runs reached 737–990 in 10 of 20.
  - Over all 19 blocks (one workload, htram setting and rep) at 32 nodes it was the fastest arm in 5, second in 6 and third in 8. Chance gives about 6.3 each. At 16 nodes in the same job: 12, 9, 9.
  - Its window (291–315) lies between the fixed ones, and its counters match theirs.
  - It is always the first Charades run of a block, straight after ROSS. A2r also runs it last.
- **Predictions:** P1 right where checkable; P4 and P7 untestable here.

**A2r: design.**
- **Job:** `scale32.slurm n32`, run as `sbatch -p skx -N 32 -n 1536 -x c455-081 -t 03:15:00` (job 3657016).
  - Earlier submissions were cancelled before they started. 3657010 lacked the traced block below. 3656992 asked for `--contiguous`, which was dropped: placement alone is unlikely to be the cause (below), and `--contiguous` can lengthen the queue wait.
  - Stampede3's Slurm has no switch topology (`topology/flat`), so `--switches` does nothing.
  - **Acceptance:** rep spread ≤ 1.10 (Q2). Noisy reps are rerun.
- **Series:** 32 nodes alone, all eight workloads, 3 reps, engines interleaved, one discarded warm-up run.
- **Arms, as in A2, except:**
  - **Charades:** the controller runs a second time at the end of each block (tag `_qlast`; left out of the headline numbers).
  - **Devastator:** W 500, 1,000 and 2,000; lookahead 10: 100, 200 and 400. W 4,000 is dropped: in A2 it was never best, and it fell to 31–76 M ev/s at σ ≥ 2,000 and uniform.
  - **ROSS:** timeout 360 s.
  - **σ 1,000:** PP 2,048 only. A1b's PP 512 series (`g1000x`) is left out, because PP 2,048 was the better setting at 16 nodes.
- **Traced block, after the 3 reps:**
  - Charades W 400 with `--gvt-trace=2 --pe-stats=1` at σ 100 (PP 2,048), σ 2,000 (PP 512) and uniform (WPs 512).
  - First on 16 of the nodes, then on all 32: one run each, about 5 min.
  - Purpose: close the 16→32-node loss, which has never been broken down. Section 122 did this for 4→16 nodes.
  - Split it into start-up (first 10% of waves) and steady state. Then split the steady part into time per GVT advance and events per advance, and the advance into the spread between the first and last process to contribute and the rest.
- **Time:** about 40 min per rep with quiet runs (54 min for A2's rep 1, including 8 min of ROSS timeouts), so about 2 h 20 min with the gate and the traced block.

**Predictions** (A2r against A1's 16-node numbers, section 143):
- **Q1.** Dropped with `--contiguous`.
- **Q2.** Rep spread ≤ 1.10 for every Charades arm and for Devastator's best W in every workload, apart from single outlier reps as in A1.
- **Q3.** In each block the controller's first and last runs agree within 5%. The controller is 0.95–1.05 of its better fixed W (P5 at 32 nodes).
- **P4 as before.** Per-node rate at 32 nodes ÷ at 16 nodes (A1):
  - Charades ≥ 0.85 on the Gaussian workloads and ≤ 0.85 on uniform;
  - Devastator ≥ 0.88 on the Gaussian workloads.
- **P6 as before at 32 nodes.** Charades ÷ ROSS ≥ 3 on σ ≥ 1,000 and uniform, ≥ 2.5 at σ 100.
- **P7 as before.** Charades ahead of Devastator in at least 42 of 48 cells, which needs 4 of the 8 at 32 nodes.
  - More specifically: ahead at σ ≥ 500, uniform and lookahead 10 σ 2,000;
  - 0.90–1.10 at σ 100 and lookahead 10 σ 500.
- **Traced block** (16 → 32 nodes, same allocation):
  - **T1.** At σ 100 and σ 2,000, steady-state time per GVT advance (waves 10–95%) grows by 15–35%, and events per advance stay within ±5%. The per-node loss then matches the advance-time growth within 5 points (closure).
  - **T2.** Unlike 4→16 nodes on long runs, most of the 16→32 loss is steady: the first 10% of waves hold at most 40% of it.
  - **T3.** The growth is in the spread between the first and the last process to contribute to a wave, not in the reduction: the spread grows by at least as much as the advance.
  - **T4.** On uniform, events per htram message (WPs 512) fall by at least 1.6× (twice the destinations).

### Why Charades rolls back more than Devastator at the same window (design, 2026-10-29; written before any runs)

> **Status: design.** First step toward a scaling fix (section 144).

**Why.**
- Charades runs at its window edge. At 16 nodes 95–97% of scheduler batches end blocked by the window (section 47), so its rate follows the GVT update rate one for one (section 132). A late message or a rollback delays a GVT update, and every PE waits; a rollback's cost is mostly this (section 18).
- Devastator runs at W 1,000 with slack to spare.
- Charades can't widen W:
  - At σ 100 on 16 nodes it rolled back 3.1% of executed events at W 600 and 12.7% at W 800, losing 36% and 92% of W 400's rate (section 45, old stack).
  - Devastator rolls back 0.05% at W 1,000 (job 3653806).
- Setting the flush deadline below W was tried (section 5). Receivers ran past held events: 8% stragglers, 47–62% efficiency.
- So before any fix: why does Charades roll back so much more than Devastator at the same W?
  - **Hypothesis H (the hold):** htram's deadline policy sends each held event when GVT makes it due, which is the last moment before some receiver may need it. Any delay in that flush makes a straggler, and a wider W makes more events wait at that edge.
  - **Alternative H′:** Charades' own dynamics, such as coarse GVT steps (about 60 time units per update), let PEs drift apart within the window.
  - Direct sends separate the two: they hold nothing.

**Job R** (`$WORK/charades-runs/roll45.slurm`, 16 nodes; skx-dev copy 3657717 and skx copy 3657718, the later one to start is cancelled; frozen build 0a212f0):
- **Workloads:** σ 100 (htram PP 2,048), σ 2,000 (PP 512), uniform (WPs 512).
- **Run length:** end time 512,000, as section 45. 2 reps, arms interleaved.
- **Arms:**
  - **Charades with htram:** W 400, 600, 800. W 1,200 stalled in section 45.
  - **Charades with direct sends:** W 400, 800, 1,600.
  - **Devastator:** W 400, 800, 1,600 (CLCG4).
  - **GVT delay at σ 2,000:** Charades with htram at W 400 and W 800, with `--diag-gvt-spin-ns=20000` (20 µs on every GVT update). This tests whether a wider W absorbs late GVT updates.
- **Recorded:**
  - rolled-back share;
  - primary stragglers (timestamp rollback calls), split into held by htram, late (delay ≥ W) and the rest;
  - rollbacks caused by anti-messages;
  - events per htram message;
  - throughput.

**Predictions:**
- **R1.** With htram at W 800, Charades' rolled-back share is at least 5× Devastator's at W 800, at σ 100 and σ 2,000.
- **R2 (H).** With direct sends at W 800, Charades' rolled-back share is within 3× of Devastator's. So the excess comes from htram's hold.
- **R3 (H).** With htram at W 800, held stragglers are at least half of the primary stragglers.
- **R4.** With htram, W 800 is slower than W 400 at σ 100 and σ 2,000, as in section 45. With direct sends, W 800 is at least as fast as W 400.
- **R5.** The 20 µs GVT delay costs W 800 at most half the share it costs W 400.

**What follows:**
- **If H holds:** the fix is in when htram sends a held event. Send it ahead of the GVT update that makes it due, at a lower cost than `--agg-flush-ahead`, which doubled messages (section 139).
- **If H′ holds:** the fix is in the scheduler or the GVT step.

### Why Charades rolls back more than Devastator at the same window, results: not the hold; Charades' own engine makes 5–120× more stragglers (2026-10-29; skx-dev batch job 3657717, 16 nodes)

> **Status: current.** Design and predictions in section 145.
> - **Allocation:** 16 nodes (c454-101, -102, -104, c455-023, -024, -031, -033, -034, -041, -083, -084, -093, -101 to -104), 8 min, gate 30/30. The skx copy (3657718) was cancelled before it started.
> - **Runs:** 54, all ok. Every workload committed the same events in every run of all three engines.
> - **Data:** summary `~/charades-data/roll45/roll45_summary.py`, output in `j3657717/summary.txt`, with the CSVs, Devastator's `results.txt` and every Charades run log.

**Rolled back (% of executed events; lower is better) and M committed ev/s (higher is better), median of 2, end time 512,000:**

| workload | W | Charades htram | Charades direct | Devastator | M ev/s: Charades htram / direct / Devastator |
|---|---|---|---|---|---|
| σ 100 | 400 | 0.058 | 0.083 | 0.000 | 657.6 / 339.0 / 635.2 |
| | 600 | 0.478 | — | — | 551.5 / — / — |
| | 800 | 1.193 | 2.661 | 0.022 | 477.4 / 298.6 / 661.9 |
| | 1,600 | — | 9.597 | 0.309 | — / 303.8 / 656.6 |
| σ 2,000 | 400 | 0.155 | 0.152 | 0.062 | 430.2 / 204.7 / 300.7 |
| | 600 | 1.107 | — | — | 378.6 / — / — |
| | 800 | 4.098 | 3.678 | 0.737 | 282.1 / 188.0 / 357.6 |
| | 1,600 | — | 9.400 | 4.506 | — / 184.3 / 375.4 |
| uniform | 400 | 0.514 | 0.157 | 0.759 | 338.1 / 142.6 / 178.3 |
| | 600 | 2.824 | — | — | 298.7 / — / — |
| | 800 | 9.754 | 8.225 | 4.818 | 253.5 / 132.8 / 199.0 |
| | 1,600 | — | 8.815 | 17.825 | — / 131.6 / 166.1 |

**Primary stragglers with htram** (timestamp rollback calls per million executed events, and the share of them that htram held):

| workload | W 400 | W 600 | W 800 | direct sends, W 800 |
|---|---|---|---|---|
| σ 100 | 130 (68% held) | 484 (13%) | 887 (7%) | 1,347 |
| σ 2,000 | 389 (80%) | 937 (33%) | 2,502 (12%) | 2,153 |
| uniform | 2,068 (95%) | 3,042 (67%) | 5,060 (25%) | 3,791 |

Rollbacks caused by anti-messages are 0–0.2% of rollback calls at W 400 and 12–32% at W 800–1,600.

**Predictions:**
- **R1 right.** With htram at W 800, Charades rolls back 54× Devastator's share at σ 100 (1.19% against 0.022%) and 5.6× at σ 2,000.
- **R2 wrong, so H is out.** With direct sends at W 800, Charades rolls back 121× Devastator's share at σ 100 and 5.0× at σ 2,000. That is as much as with htram, or more.
- **R3 wrong.** At W 800 htram held only 7% (σ 100), 12% (σ 2,000) and 25% (uniform) of the primary stragglers. Held events dominate only at W 400, where stragglers are few (section 139's race).
- **R4 half right.** With htram, W 800 is 0.73× (σ 100) and 0.66× (σ 2,000) of W 400. With direct sends it is 0.88–0.93×, not faster.
- **R5 right.** The 20 µs delay on every GVT update costs W 400 8.6% at σ 2,000 (393.4 against 430.2) and W 800 2.8% (274.2 against 282.1). A wider window absorbs two thirds of a late update.

**What it says:**
- **Charades makes far more stragglers than Devastator at the same W, whatever the transport.** Primary stragglers grow steeply with W: with direct sends at σ 100, 91 per million executed events at W 400, 1,347 at W 800 and 3,872 at W 1,600. Devastator at σ 100 rolls back 0.31% at W 1,600, against Charades' 9.6%.
- **htram is not the cause.** At W 800 it rolls back less than direct sends at σ 100 (1.19% against 2.66%) and about as much elsewhere.
- **So the fix is in Charades' engine (H′), not in when htram sends.** At σ 100 almost all events stay inside the process (fast path), so the stragglers come from other PEs of the same process. Something lets PEs of a process drift much further apart within the window than Devastator's ranks do, or creates stragglers some other way. Candidates:
  - **A laggard PE.** Rank 0 and the edge ranks are known to be late (sections 85–101). A PE far behind sends into its neighbours' past.
  - **Equal timestamps.** A PE rolls back when an event arrives with ts equal to its LP's current time (`<=`), and integer timestamps make ties common.
  - **Lazy delivery inside the process.** Fast-path events wait in an input buffer until the receiver's next pass.
- **Why this is the scaling lever:** a wider window absorbs late GVT updates (R5), and that slack is what Devastator has. If Charades rolled back like Devastator, it could run at W 800–1,600 and keep its aggregation advantage.
- **At W 400 Charades is still ahead** of Devastator's best W on σ 2,000 (1.15×) and uniform (1.70×), and level at σ 100 (0.99×).

### The rollback unit: LPs per chare at lookahead 100 and wide W (design, 2026-10-29; written before any runs)

> **Status: design.** Follows section 146.

**Why.**
- Charades judges a straggler against its chare's time, not its LP's (`LP::get_current_time()` returns the owner chare's, lp.h:330). It also rolls back the whole chare. With 16 LPs per chare, an event is a straggler if it is earlier than the chare's latest event on any of its 16 LPs, and each straggler undoes every later event of all 16.
- Devastator registers each LP as its own rollback domain (section 68).
- **16 was never chosen by measurement.**
  - It first appears in our first Stampede3 script (`gvt_cost.sh`, 5ca0ac6, 2026-10-19), probably taken from the test harness's `wide` config (e7f3b38, a correctness test for wide chares). Every sweep since copied it.
  - Charades' own PHOLD and traffic test configs use 4.
  - Mikida's thesis (2019, ch. 3) leaves the grouping to the model, as ROSS does with kernel processes, whose purpose is cheaper fossil collection (one history per group). Its profile puts fossil collection at 12% of time.
  - The thesis's only tuned grouping is for locality: dragonfly runs best with one router and its terminal and MPI LPs per chare.
  - It does not discuss what the grouping costs in rollbacks.
- Section 68 suspected this at lookahead 10. On the Mac (lookahead 10, W 100), efficiency rose from 62.8% at 16 LPs per chare to 95.1% at 1 (section 69). The 16-node test was planned but never reported.
- **Rough model:** with exponential delays (mean 900 past the lookahead), an LP's latest event sits on average about 67 time units behind its chare's. So judging by LP removes most stragglers from senders that lag just past the lookahead. Each remaining rollback undoes about 1/16 of the events.
- Job R measured about 20 events rolled back per primary straggler at σ 100, W 800, direct sends.
- The Mac can't test it at lookahead 100: there, rollback shares at 16, 4 and 1 LPs per chare (2–5%) move with thread scheduling, not with the chare size.

**Job L** (`$WORK/charades-runs/lpc47.slurm`, 16 nodes; skx-dev copy 3657892 and skx copy 3657893, the later one to start is cancelled; frozen build 0a212f0):
- σ 100 (PP 2,048), σ 2,000 (PP 512), uniform (WPs 512).
- 16, 4 and 1 LPs per chare; W 400, 800, 1,600.
- End time 512,000, 2 reps, chare sizes interleaved.
- Compared with Devastator's numbers from job R (same nodes' partition, same settings).

**Predictions:**
- **L1.** At W 800, 1 LP per chare cuts the rolled-back share at least 10× against 16 at σ 100 and σ 2,000, to within 3× of Devastator's.
- **L2.** Primary stragglers per executed event fall at least 2× from 16 to 1 LP per chare at W 800, and events rolled back per straggler at least 4×.
- **L3.** With 1 LP per chare the best W is 800 or wider at σ 100 and σ 2,000. Its throughput there is within ±10% of 16 LPs per chare at W 400: the saved rollbacks against the extra scheduler and fossil-collection work per chare (0.87× on the Mac at lookahead 10, section 69).
- **L4.** 4 LPs per chare lies between the two in rolled-back share at every W.

**What follows:**
- **If L1 and L2 hold:** the fix is to roll back one LP inside a chare, judging stragglers by the LP's time. Chares stay large, keeping their scheduling cost, but roll back like Devastator. Then the window can widen.
- **If L1 fails:** the rollback unit is not the cause, and the next step is to trace where stragglers come from: the sender's lag and the depth behind the receiver.

### The rollback unit, results: one LP per chare cuts rollbacks 5–23× and beats Devastator's at σ 2,000 and uniform; a wider W is still slower, because the flush deadline follows it (2026-10-29; skx-dev batch job 3657892, 16 nodes)

> **Status: current.** Design and predictions in section 147.
> - **Allocation:** 16 nodes (c454-093, c455-002 to -004, -011 to -014, -021, -023, -024, -031, -101 to -104), 9 min, gate 30/30. The skx copy (3657893) was cancelled before it started.
> - **Runs:** 54, all ok. Every workload committed the same events in every run, and the same as Devastator in job R.
> - **Data:** summary `~/charades-data/lpc47/lpc47_summary.py`, output in `j3657892/summary.txt`, with the CSVs and every run log.

**Median of 2, htram, end time 512,000.** Rolled back (% of executed; lower is better), M committed ev/s (higher is better), events rolled back per rollback call, events per htram message:

| workload | W | 16 LPs per chare | 4 | 1 | Devastator (job R) |
|---|---|---|---|---|---|
| σ 100 | 400 | 0.054%, 665.7, 4.3, 35 | 0.017%, 664.7, 2.1, 34 | 0.004%, 597.0, 1.3, 33 | 0.000%, 635.2 |
| | 800 | 1.42%, 470.7, 12.2, 9 | 0.79%, 490.3, 5.4, 9 | 0.28%, 499.7, 2.5, 9 | 0.022%, 661.9 |
| | 1,600 | 5.14%, 301.5, 16.2, 7 | 5.18%, 352.8, 7.1, 4 | 2.00%, 333.3, 3.5, 6 | 0.31%, 656.6 |
| σ 2,000 | 400 | 0.144%, 430.9, 3.8, 49 | 0.038%, 429.8, 1.9, 49 | 0.009%, 411.0, 1.2, 48 | 0.062%, 300.7 |
| | 800 | 4.16%, 289.1, 13.2, 20 | 1.74%, 339.1, 6.5, 25 | 0.45%, 359.6, 2.7, 25 | 0.74%, 357.6 |
| | 1,600 | 71.7%, 23.1, 20.3, 4 | 17.5%, 113.8, 8.4, 7 | 5.65%, 196.8, 3.6, 13 | 4.51%, 375.4 |
| uniform | 400 | 0.535%, 335.3, 2.5, 13 | 0.133%, 338.0, 1.5, 13 | 0.035%, 322.5, 1.2, 13 | 0.76%, 178.3 |
| | 800 | 12.2%, 237.8, 14.3, 11 | 2.68%, 264.7, 6.5, 12 | 0.54%, 263.2, 2.7, 11 | 4.82%, 199.0 |
| | 1,600 | 16.9%, 116.1, 16.1, 2 | 19.7%, 135.5, 8.1, 3 | 11.0%, 184.2, 4.2, 8 | 17.8%, 166.1 |

**Primary stragglers per million executed events at W 800** (16 / 4 / 1 LPs per chare): σ 100 1,020 / 1,304 / 1,059; σ 2,000 2,606 / 2,088 / 1,513; uniform 5,780 / 2,886 / 1,706.

**Predictions:**
- **L1 right except at σ 100.** At W 800, 1 LP per chare cuts the rolled-back share against 16 by 9.2× at σ 2,000 (to 0.61× Devastator's) and 23× on uniform (0.11× Devastator's). At σ 100 the cut is only 5.1×, and Charades still rolls back 12.6× Devastator's share.
- **L2 half right.** Events rolled back per rollback call fall 4.9–5.3× from 16 to 1 LP per chare at W 800 in all three workloads. Primary stragglers fall 3.4× on uniform and 1.7× at σ 2,000, but not at all at σ 100.
- **L3 wrong.** With 1 LP per chare the best W is still 400 everywhere: W 800 is 0.84× (σ 100), 0.87× (σ 2,000) and 0.82× (uniform) of it. 1 LP per chare at W 400 is 0.90× of 16 at σ 100, 0.95× at σ 2,000 and 0.96× on uniform.
- **L4 mostly right.** 4 LPs per chare lies between 16 and 1, with three exceptions: W 1,600 on uniform (19.7%, above both), W 1,600 at σ 100 (5.18%, level with 16's 5.14%), and the straggler count at W 800, σ 100.

**What it says:**
- **The rollback unit was most of Charades' excess rollbacks at σ 2,000 and uniform.** With 1 LP per chare, Charades rolls back less than Devastator at the same W there.
- **Shallower rollbacks are most of the gain:** about 2.5 events undone per straggler instead of 12–14.
- **σ 100 has a second cause.** There the number of stragglers doesn't change with chare size: the LPs themselves have passed the event. Events at σ 100 mostly go to the same PE, which can't straggle (a PE runs its lowest event first), or to adjacent PEs. So adjacent PEs drift apart by more than the lookahead much more often than Devastator's ranks do.
- **A wider window still loses throughput, even with few rollbacks.** At σ 2,000 with 1 LP per chare, W 800 rolls back only 0.45% yet runs at 0.87× of W 400. Events per htram message halve (48 to 25), because the flush deadline follows W (h = W + 8). That is the other half of the coupling in section 145.
- **4 LPs per chare is a free improvement at W 400:** 1.00× of 16 at σ 100, 1.00× at σ 2,000, 1.01× on uniform, with 3–4× fewer rollbacks. 1 LP per chare costs 4–10% there: more chares for the scheduler and fossil collection.

**Next (section 149):**
- With rollbacks cheap, test the decoupling again: a wider W with the flush deadline held near 400.
- Section 5's failure of that setting (8% stragglers, 47–62% efficiency) was with 16-LP chares, where each straggler undid 12–20 events.

### A wide window with the flush deadline held: decoupling again, now that rollbacks are shallow (design, 2026-10-29; written before any runs)

> **Status: design.** Follows section 148.

**Why.**
- Charades' window is tied to its flush deadline (h = W + 8). A wider W therefore halves events per htram message (section 148) even when it barely rolls back, and stays slower than W 400.
- Holding h below W was tried in section 5: receivers ran past held events, giving 8% stragglers and 47–62% efficiency. But each straggler then undid a 16-LP chare (12–20 events). With 1 or 4 LPs per chare it undoes 1.2–2.7 (section 148).
- A wider window absorbs late GVT updates: a 20 µs delay cost W 400 8.6% and W 800 2.8% (section 146). That is the robustness we want at scale.

**Job H** (`$WORK/charades-runs/hor49.slurm`, 16 nodes; skx-dev copy 3658017 and skx copy 3658018, the later one to start is cancelled; frozen build 0a212f0; `--agg-horizon` already exists):
- **Workloads:** σ 100 (PP 2,048), σ 2,000 (PP 512), uniform (WPs 512).
- **Chare sizes:** 4 and 1 LPs per chare.
- **Arms, per chare size:**
  - W 400 with the default deadline (408);
  - W 800 with the default deadline (808);
  - W 800 and W 1,600 with the deadline held at 408 (`--agg-horizon=408`).
- **GVT delay at σ 2,000, 1 LP per chare:** W 400 (default deadline) and W 1,600 (held deadline), each with `--diag-gvt-spin-ns=20000`.
- End time 512,000, 2 reps.

**Predictions:**
- **H1.** With the deadline held at 408, events per htram message at W 800 and 1,600 stay within 15% of W 400's in every workload.
- **H2.** With 1 LP per chare and the held deadline, W 800 or W 1,600 is at least as fast as W 400 at σ 2,000 and uniform. At σ 100, where the second straggler cause remains, it is at most 5% slower.
- **H3.** Held-event stragglers rise, to at least half the primary stragglers at W 1,600 with the held deadline, but the rolled-back share stays below 2%.
- **H4.** The 20 µs GVT delay costs W 1,600 with the held deadline at most a third of what it costs W 400.

**What follows:**
- **If H2 and H4 hold:** the scaling fix is per-LP rollback inside a chare (LP-level speed at 16-LP chares' cost) plus a flush deadline set apart from the window. Then a 32-node test with the noise benchmark.
- **If H2 fails:** find out what the held deadline costs: late events from the senders, or the GVT.

### A wide window with the flush deadline held, results: much bigger messages and 3× less sensitivity to a late GVT update, but held events straggle; 1.12× at σ 2,000, a loss on uniform (2026-10-29; skx-dev batch job 3658017, 16 nodes)

> **Status: current.** Design and predictions in section 149.
> - **Allocation:** 16 nodes, 8 min, gate 30/30. The skx copy (3658018) was cancelled before it started.
> - **Runs:** 52, all ok. Every workload committed the same events in every run.
> - **Data:** summary `~/charades-data/hor49/hor49_summary.py`, output in `j3658017/summary.txt`, with every run log.
> - **Reproducibility:** 4 LPs per chare at W 400 reproduces job L within 1.8% (662.7 against 664.7 at σ 100; 437.6 against 429.8 at σ 2,000).

**Median of 2, htram, end time 512,000.** Rolled back (% of executed; lower is better), M committed ev/s (higher is better), primary stragglers per million executed events (share htram held), events per htram message. "W + 8" is the default deadline; "408" holds it there.

| workload | LPs per chare | W 400, W + 8 | W 800, W + 8 | W 800, 408 | W 1,600, 408 |
|---|---|---|---|---|---|
| σ 100 | 4 | 0.017%, **662.7**, 77 (53%), 34 | 0.73%, 477.1, 1,217 (3%), 10 | 3.45%, 438.4, 4,736 (55%), 120 | 49.3%, 104.2, 20,130 (19%), 418 |
| | 1 | 0.005%, 583.7, 34 (39%), 33 | 0.26%, 472.8, 960 (1%), 10 | 0.69%, 574.2, 2,969 (65%), 110 | 11.3%, 189.8, 15,502 (44%), 345 |
| σ 2,000 | 4 | 0.037%, 437.6, 203 (73%), 49 | 1.77%, 326.6, 2,067 (8%), 26 | 8.64%, 409.1, 12,337 (88%), 128 | 30.1%, 258.9, 23,196 (74%), 158 |
| | 1 | 0.009%, 399.6, 72 (65%), 47 | 0.47%, 343.9, 1,567 (3%), 25 | 2.26%, **445.7**, 7,986 (91%), 130 | 9.14%, 402.1, 20,753 (80%), 153 |
| uniform | 4 | 0.134%, **333.3**, 906 (90%), 13 | 2.65%, 267.6, 2,946 (28%), 11 | 44.8%, 121.7, 67,686 (99%), 27 | 63.1%, 68.8, 69,210 (98%), 41 |
| | 1 | 0.036%, 310.8, 309 (84%), 13 | 0.54%, 263.2, 1,684 (15%), 11 | 15.8%, 251.7, 70,847 (99%), 22 | 57.8%, 77.4, 139,028 (98%), 47 |

**20 µs on every GVT update** (σ 2,000, 1 LP per chare; M ev/s, with ÷ without, higher is better): W 400 with the default deadline 364.8 ÷ 399.6 = **0.913**; W 1,600 with the deadline at 408 389.8 ÷ 402.1 = **0.969**.

**Predictions:**
- **H1 wrong, in the good direction.** Messages did not just hold their size; they grew. Holding the deadline at 408 while W widens gives 3.3× W 400's events per message at σ 100 (110 against 33 at W 800, 1 LP per chare), 2.8× at σ 2,000 and 1.8× on uniform. PEs run further ahead, so each event waits longer in a buffer before it is due.
- **H2 right at σ 2,000 and σ 100, wrong on uniform.** With 1 LP per chare, W 800 with the deadline at 408 is 1.115× W 400 at σ 2,000 (1.02× the best setting of all, 4 LPs per chare at W 400). It is 0.98× at σ 100 and 0.81× on uniform.
- **H3 wrong.** Held events are most of the stragglers (44–99% at W 1,600), but the rolled-back share is far above 2%: 9–63% at W 1,600, and 0.7–45% at W 800.
- **H4 about right.** The GVT delay costs W 1,600 with the held deadline 3.1%, against 8.7% at W 400: 0.36 of it.

**What it says:**
- **Section 5's failure was mostly the rollback unit.** With 4 LPs per chare the held deadline still collapses (σ 2,000 W 1,600: 30% rolled back). With 1 LP per chare it works at σ 2,000 and is level at σ 100.
- **But the held deadline makes stragglers of held events, as section 5 said.** Receivers run past events their senders hold until the deadline. On uniform, where every event crosses processes, that is 99% of stragglers and 16% of events rolled back at W 800.
- **The tradeoff is a curve, not a switch.** Between "deadline = W" (small messages, few stragglers) and "deadline far below W" (big messages, many stragglers), the best point depends on the workload: about h = W/2 at σ 2,000, and h = W on uniform. Setting W and h together is the joint control of optimism and aggregation the paper argues for. The controller today sets only W, with h following.
- **For scale, the wide window is what matters.** It absorbs a late GVT update about 3× better. At 32 nodes GVT updates are slower and noisier (sections 144, 146), so the gain there should be larger than at 16.
- **Per-LP rollback is needed whatever the deadline.** 1 LP per chare costs 7–12% at W 400 against 4 (scheduler and fossil-collection visits). Rolling back one LP inside a 4- or 16-LP chare would keep 1 LP per chare's rollbacks at 4's cost.

**Next:**
- Implement per-LP rollback inside a chare. Correctness on the Mac (test tiers), then 16 nodes against 1 and 4 LPs per chare.
- Then grid h ∈ {408, W/2, W + 8} × W ∈ {400, 600, 800} at 16 and 32 nodes, with the GVT delay.
- The σ 100 residual (stragglers unchanged by chare size) is still open.

### Per-LP rollback inside a chare, `--rollback-unit=1` (implementation and design, 2026-10-29; design written before any runs)

> **Status: design.** Charades branch `lp-rollback`. Follows sections 148 and 150.

**Implementation.**
- A straggler is judged against its own LP's latest processed event, and only that LP's events at or after it are rolled back.
- Each processed event is also linked into its LP's chain (`Event::lp_prev`/`lp_next`; head and tail in `LPBase`). The chare's processed queue stays, in execution order, for migration.
- An anti-message rolls back the cancelled event's LP only.
- Fossil collection commits each LP's chain below GVT: the chare queue is no longer in time order.
- A migrated chare rebuilds the chains.
- **The option:** `--rollback-unit=0` is the chare (the default for now), 1 the LP.
- **Why it is safe:** LPs share no state; no model in the tree reaches another LP (`owner->`, `lp_structs`). An event one LP sent another is cancelled through its causality chain as before.
- **A bug found on the Mac:**
  - **Symptom:** dragonfly committed the wrong number of events without a window: 9–287 too many on its base config, 99–456 too few on its congested config, on 1, 4 and 2 × 2 PEs.
  - **Cause:** a send to an LP of the same chare is delivered at once (`tw_event_send`). Under per-LP rollback the receiving LP can be ahead of the sender, so the send can roll it back inside the sender's forward handler. The rollback then set the chare's current event to another event, and the handler's later sends took their time and causal parent from that.
  - **Fix:** a rollback inside a forward handler (`in_forward`) restores the running event.
  - **Under chare rollback:** the same can happen only with a zero-delay send, because a chare's processed events are never ahead of its running event.
- **Mac tests:**
  - Change tier: the six new configs (bucketed, bucketed with a window, htram PP with the deadline policy, the same with the deadline held at 500 below a window of 2,000, blocking, CD). All pass except CD at 4 PEs, which fails with and without the option. CD is on the harness's known-broken list (issue #11), and its config was dropped.
  - Engine tier with 20 repeats of the five per-LP configs (bucketed, bucketed with a window, htram PP, htram PP with the held deadline, blocking): **2,422/2,422** on the Mac. Commit df75cd2 on branch `lp-rollback`.

**Job P** (`$WORK/charades-runs/lprb51.slurm`, 16 nodes; skx-dev copy 3658328 and skx copy 3658329, the later one to start is cancelled; tree `charades-lprb`, a worktree at df75cd2 on the same Charm++, Reconverse and htram as job H):
- σ 100 (PP 2,048), σ 2,000 (PP 512), uniform (WPs 512); end time 512,000; 2 reps.
- **Arms per workload:**
  - Chare rollback: 16 LPs per chare at W 400 (the paper runs' setting); 4 LPs per chare at W 400 (the best setting so far).
  - Per-LP rollback at 16 and at 4 LPs per chare: W 400, W 800 with the default deadline, and W 800 with the deadline held at 408.
  - Reference: 1 LP per chare, chare rollback, W 800 with the deadline at 408 (job H's best at σ 2,000).
- **GVT delay at σ 2,000:** per-LP rollback at 4 LPs per chare, W 400 and W 800 with the deadline at 408, each with `--diag-gvt-spin-ns=20000`.

**Predictions:**
- **P1.** With per-LP rollback, the rolled-back share at 16 or 4 LPs per chare is within 1.5× of 1 LP per chare's (jobs L and H) at the same W and deadline, in every workload.
- **P2.** At W 400, per-LP rollback costs at most 2% against chare rollback at the same chare size.
- **P3.** The best per-LP setting is at least 1.05× today's best (4 LPs per chare, chare rollback, W 400) at σ 2,000, and within ±2% at σ 100 and uniform.
- **P4.** With per-LP rollback at 4 LPs per chare, the 20 µs GVT delay costs W 800 with the held deadline at most half what it costs W 400.

### Per-LP rollback inside a chare, results: 1 LP per chare's rollbacks at no cost; the held deadline is a new best at σ 2,000 but loses elsewhere, and a late GVT update costs as much as at W 400 (2026-10-29; skx-dev batch job 3658328, 16 nodes)

> **Status: current.** Design and predictions in section 151. Per-LP rollback became the default on these results (main 9d08fbd, 2026-10-29; full test matrix 13,345/13,345 on the Mac).
> - **Allocation:** 16 nodes, 8 min, gate 48/48 (including the three per-LP configs on 2 nodes). The skx copy (3658329) was cancelled before it started.
> - **Build:** `charades-lprb`, a worktree at df75cd2; the first build failed on a parallel-make race (`scheduler.decl.h` not yet generated) and was rebuilt serially.
> - **Runs:** 58, all ok. Every workload committed the same events in every run.
> - **Data:** summary `~/charades-data/lprb51/lprb51_summary.py`, output in `j3658328/summary.txt`, with every run log.

**Median of 2, htram, end time 512,000.** Rolled back (% of executed; lower is better), M committed ev/s (higher is better), and the rate ÷ 4 LPs per chare with chare rollback at W 400 (the best setting before; higher is better). "Chare" and "LP" are the rollback unit; "W + 8" and "408" the flush deadline.

| workload | LPs per chare, unit, deadline | W 400 | W 800 |
|---|---|---|---|
| σ 100 | 16, chare, W + 8 | 0.046%, 659.7, 0.97 | — |
| | 4, chare, W + 8 | 0.014%, **678.5**, 1.00 | — |
| | 16, LP, W + 8 | 0.004%, 674.4, 0.99 | 0.31%, 516.2, 0.76 |
| | 4, LP, W + 8 | 0.004%, 667.4, 0.98 | 0.28%, 514.3, 0.76 |
| | 16, LP, 408 | — | 0.69%, 622.0, 0.92 |
| | 4, LP, 408 | — | 0.72%, 604.8, 0.89 |
| | 1, chare, 408 | — | 0.68%, 567.3, 0.84 |
| σ 2,000 | 16, chare, W + 8 | 0.134%, 434.5, 1.00 | — |
| | 4, chare, W + 8 | 0.034%, 432.9, 1.00 | — |
| | 16, LP, W + 8 | 0.009%, 436.5, 1.01 | 0.40%, 369.3, 0.85 |
| | 4, LP, W + 8 | 0.009%, 430.8, 1.00 | 0.39%, 370.9, 0.86 |
| | 16, LP, 408 | — | 2.25%, 471.0, 1.09 |
| | 4, LP, 408 | — | 2.20%, **473.7**, 1.09 |
| | 1, chare, 408 | — | 2.21%, 452.1, 1.04 |
| uniform | 16, chare, W + 8 | 0.429%, **347.9**, 1.08 | — |
| | 4, chare, W + 8 | 0.136%, 321.9, 1.00 | — |
| | 16, LP, W + 8 | 0.056%, 333.4, 1.04 | 0.50%, 274.3, 0.85 |
| | 4, LP, W + 8 | 0.036%, 325.9, 1.01 | 0.49%, 272.2, 0.85 |
| | 16, LP, 408 | — | 22.8%, 218.9, 0.68 |
| | 4, LP, 408 | — | 21.1%, 226.8, 0.70 |
| | 1, chare, 408 | — | 15.9%, 249.6, 0.78 |

Events rolled back per rollback call at W 400: 3.7–4.0 (16, chare), 1.5–2.0 (4, chare), 1.2–1.3 (per-LP at 16 or 4).

**20 µs on every GVT update** (σ 2,000, 4 LPs per chare, per-LP rollback; with ÷ without, higher is better): W 400, deadline W + 8: 394.4 ÷ 430.8 = **0.915**. W 800, deadline 408: 430.6 ÷ 473.7 = **0.909**.

**Predictions:**
- **P1 right but for one cell.** Per-LP rollback at 16 or 4 LPs per chare rolls back within 1.5× of 1 LP per chare (jobs H and P) in 17 of 18 cells. The exception is uniform at 16 LPs per chare, W 400: 0.056% against 0.036%, 1.56×.
- **P2 right in 5 of 6 cells.** At W 400 per-LP rollback is −1.6% to +2.2% against chare rollback at the same chare size. The exception is uniform at 16 LPs per chare: −4.2% (333.4 against 347.9), which is near this workload's rep-to-rep spread, since 16 against 4 LPs per chare with chare rollback differs by 8% here and by 1% in job L.
- **P3 right at σ 2,000 and σ 100.** The best per-LP setting is 1.094× the old best at σ 2,000 (4 LPs per chare, W 800, deadline 408) and 0.994× at σ 100 (16 LPs per chare, W 400). On uniform it is 1.036× the old best but 0.958× 16 LPs per chare with chare rollback in this job.
- **P4 wrong.** The GVT delay costs W 800 with the held deadline 9.1%, against 8.5% at W 400. Job H's smaller cost (3.1%) was at W 1,600: a window of twice the deadline does not leave enough room to absorb a late update.

**What it says:**
- **Per-LP rollback does what 1 LP per chare did, at chare cost.** It cuts the rolled-back share at W 400 7.7–15× at 16 LPs per chare (σ 100: 0.046% to 0.004%; σ 2,000: 0.134% to 0.009%; uniform: 0.429% to 0.056%) and 3.5–3.8× at 4, and each rollback undoes 1.2–1.3 events. Throughput at W 400 is unchanged. It removes the reason section 45 found W 600–800 so costly, and it should become the default after the full test matrix.
- **The held deadline is a per-workload choice.** At σ 2,000 it is the best setting measured (1.09×). At σ 100 it loses 8–11%, and on uniform 30%, where held events made 98–99% of stragglers in job H. The controller has to set the deadline and the window together; today it sets only the window.
- **The robustness goal is not met yet.** A late GVT update still costs about what it costs at W 400. Only a window well beyond the deadline (W 1,600 with deadline 408 in job H) absorbed it, and that loses throughput on every workload but σ 2,000.
- **So per-LP rollback is a clean improvement, but not yet the scaling fix.** The next step is the 16→32-node breakdown in A2r (section 144), to see whether the 32-node loss is the GVT step, as at 16 nodes, before choosing between a wider window and faster GVT updates.

### A2r, 32 nodes, results: Charades leads in 6 of 8 but loses more per node from 16 to 32 nodes than Devastator everywhere; a start-up transient at σ 100, per-wave work on uniform (2026-10-29; skx batch job 3657016, 32 nodes)

> **Status: current.** Design and predictions in section 144.
> - **Allocation:** 32 nodes (c477-094 to c506-094, 13 racks), 18:45–20:01 (1 h 16 min), gate 30/30.
> - **Runs:** Charades 90 (plus 30 controller runs at the end of each block, `_qlast`), Devastator 72, ROSS 48, all ok. Every cell has the same committed events in all three engines.
> - **Traced block:** six runs, at 16 nodes (the first 16 of the allocation) and 32.
> - **Data:** `~/charades-data/scale32/scale32/n32_j3657016/`, with `combined_1_32.txt` (`combine_a2r.py`: A1a + A1b + A2r) and `trace_summary.txt` (`trace32_summary.py`).
> - **Corrected in section 154:** the traced block's "response" included the cross-process reduction (`handled_s` is when a process sent its counts). That inflates T3 and the uniform "+261 µs" line. The start-up transient is in the reduction, not in the processes' work.

**All eight workloads, 1–32 nodes:** the table at the top of Current numbers (from `combine_a2r.py`).

**Predictions:**
- **P1 right.** Same committed events in every 32-node cell.
- **P4 wrong for Charades, right for Devastator.** Per-node rate at 32 ÷ at 16 (A1):
  - Charades 0.81–0.87 on the Gaussian workloads; only σ 2,000 (0.87) reaches the predicted 0.85. Uniform is 0.72, which is ≤ 0.85 as predicted.
  - Devastator 0.93–0.98 on the Gaussian workloads (≥ 0.88 as predicted) and 0.80 on uniform.
- **P5 wrong at 32 nodes.** The controller is 0.93–0.95 of its better fixed W on the five lookahead-100 Gaussian workloads apart from σ 4,000 (0.97), and 0.95 on uniform. It holds W near 300 (the κ bound), while W 400 is best here. Lookahead 10: 0.99 and 1.06.
- **P6 right.** Charades ÷ ROSS at 32 nodes: 3.02 at σ 100, 4.14–4.52 at σ ≥ 1,000 and uniform.
- **P7 right.** Charades leads Devastator in 44 of 48 cells.
  - Of the narrower prediction: ahead at σ ≥ 500, uniform and lookahead 10 σ 2,000 (1.04–1.66), right.
  - Lookahead 10 σ 500 at 0.99 is within 0.90–1.10, right; σ 100 at 0.89 is just outside it.
- **Q2 right apart from single slow reps.** Median rep spread 1.04 (Charades arms) and 1.08 (Devastator). Some cells have one slow rep (Devastator σ 2,000, W 500: 603, 152, 597 M ev/s), which the median of 3 absorbs. Lookahead 10 σ 2,000 is the noisiest workload (Charades arms 1.34–2.17).
- **Q3: no position effect.** The controller's last run in a block ÷ its first: median 1.005, within ±5% in 22 of 30 blocks; the outliers (0.81–1.27) are in uniform and lookahead 10 σ 2,000. A2's "0 of 10 fast" (section 144) was noise.
- **Traced block (T1–T4), with a caveat.** Tracing (`--gvt-trace=2 --pe-stats=1`) cost 12–15% at σ 100 and 35–41% on uniform against untraced W 400 runs, and the 16-node σ 2,000 traced run was an outlier (first 10% of waves 3.6 s of 11.2 s). The traced ratios track the untraced ones: 16→32 per node at W 400, σ 100 0.88 traced against 0.90 untraced; uniform 0.69 against 0.77.
  - **T1 wrong.** At σ 100 the steady wave period grows 20% (169 to 203 µs), but events per wave per node also grow 15% (fewer waves).
  - **T2 wrong at σ 100, right on uniform.** At σ 100 the first 10% of waves hold all (110%) of the lost time. On uniform they hold 8%.
  - **T3 wrong.** The median process's response to a GVT result grows about as much as the wave (σ 100: +34 µs of +34; uniform: +261 of +291 µs). The spread between the median and the slowest process grows less (+21 and +80 µs).
  - **T4 just wrong.** Uniform events per htram message fall 1.50× (12.5 to 8.3), not ≥ 1.6×.

**Mean wave period by tenth of a traced run** (µs, PE 0's view; lower is better):

| run | 1st | 2nd | 3rd | 4th | 5th | 6th | 7th | 8th | 9th | 10th |
|---|---|---|---|---|---|---|---|---|---|---|
| σ 100, 16 nodes | 209 | 204 | 202 | 172 | 147 | 159 | 154 | 153 | 153 | 252 |
| σ 100, 32 nodes | **557** | **367** | 168 | 200 | 183 | 192 | 179 | 178 | 176 | 171 |
| uniform, 16 nodes | 446 | 386 | 350 | 365 | 439 | 370 | 449 | 341 | 317 | 987 |
| uniform, 32 nodes | 615 | 1,507 | 460 | 254 | 400 | 769 | 1,061 | 570 | 437 | 415 |

**What it says:**
- **Charades still leads at 32 nodes in 6 of 8 workloads, but its lead shrinks from 16 to 32 nodes everywhere,** by 0.11–0.24 in Charades ÷ Devastator (σ 100: 1.04 to 0.89; σ 2,000: 1.35 to 1.24; uniform: 1.84 to 1.66; lookahead 10 σ 2,000: 1.35 to 1.11). This is the scaling gap to close.
- **Three parts are visible:**
  - **A start-up transient that grows with node count.** At σ 100 on 32 nodes the first fifth of the waves take 2–3× their later period; at 16 nodes the first tenths are about 1.3× it. Section 122 found the same from 4 to 16 nodes and that 4× longer runs amortize it. At 32 nodes even these long runs (end time 2,048,000) last only about 6 s. The cause is still unknown: warm-up pings did nothing (section 122).
  - **On uniform, every process's work per wave grows** (median response +261 µs, 1.75×) as each process serves twice the destinations with thinner messages. Sections 125–132 found this from 4 to 16 nodes. The traced uniform run is too erratic for more detail.
  - **The controller stays near W 300** while W 400 is better at 32 nodes: it is 3–7% below W 400 on the lookahead-100 workloads, against within ±4% at 1–16 nodes. Per-LP rollback (section 152) makes wider W cheaper, so the κ bound can be revisited.
- **Next:** find the start-up transient (it is the largest part at σ 100 and a cost that grows with node count), and measure per-LP rollback with the controller at 32 nodes.

### Section 153's start-up transient is a slow cross-process reduction, in episodes of seconds; a diagnostic job (analysis of existing traces and design, 2026-10-29; written before any runs)

> **Status: design.**
> - **Analysis:** no new runs; A2r's six traced runs (job 3657016). Scripts `turn.py`, `epis.py`, `valid.py`, `steady.py`, `shape2.py` in `~/charades-data/scale32/episodes/`.
> - **Job E:** Charades `episode-diag` (this commit; per-LP rollback, now the default), htram, Reconverse and the launch as in A2r; `$WORK/charades-runs/episode54.slurm` (32 nodes, skx, `-x c455-081`).
> - **Job E16:** the same blocks at 16 nodes on skx-dev, without block C (`episode54.slurm n16`). It was added while job E waited for 32 skx nodes, to get the instruments' first data sooner; the predictions below are for 32 nodes.

**A correction to section 153.** In `gvt_waves_<p>.csv`, `handled_s` is when the process sent its combined counts (the first hop of the Charm++ path), not when it handled the previous result. Section 153's "response" (last PE in − the previous `handled_s`) therefore included the whole cross-process reduction. That inflates T3 ("the median process's response grows about as much as the wave") and the uniform "+261 µs" line. Measured properly:
- a process's **turnaround** is its counts sent − the previous result's arrival there;
- the **reduction** is the result's arrival − the counts sent, taken at the process that sent last (the smallest such gap).

Waves 10–95%, medians over waves (µs; lower is better):

| run | wave period, 16 / 32 nodes | slowest process's turnaround | reduction after the last process |
|---|---|---|---|
| σ 100 | 142 / 162 | 69 / 37 | **68 / 109** |
| σ 2,000 | 199 / 208 | 107 / 89 | 77 / 104 |
| uniform | 286 / 389 | 220 / 268 | 62 / 93 |

- **At σ 100 on 32 nodes the reduction is two thirds of a wave,** and it grows 68 → 109 µs from 16 nodes. The slowest process turns a wave around in 37 µs, and the median one in 23 µs. Most PEs are blocked at the window edge and contribute at once, so the reduction is on the critical path here. Section 120 found it was not at σ 2,000 on 16 nodes, where the late PE contributes only after its 128th event.
- **On uniform both parts grow:** the slowest turnaround by 1.22× (220 → 268 µs), not section 153's 1.75×, and the reduction by 31 µs.

**The start-up "transient" is the reduction, in episodes.** σ 100, 32 nodes, per 0.25 s of wall time from the first wave (µs; lower is better):

| wall time | waves | period | slowest turnaround | median turnaround | reduction after the last process |
|---|---|---|---|---|---|
| 0–0.25 s | 362 | 693 | 447 | 25 | 199 |
| 0.25–1.5 s (5 bins) | 442–515 each | 485–566 | 75–227 | 22–23 | 292–411 |
| 1.5–1.75 s | 260 | 973 | 529 | 23 | 390 |
| 1.75–2.0 s | 745 | 332 | 165 | 23 | 147 |
| 2.0–4.5 s (10 bins) | 1,156–1,511 each | 166–216 | 42–75 | 23–24 | 107–138 |

- **What it shows:**
  - Every process picks the result up within 10–15 µs, the median process contributes 22–25 µs later, and no process is consistently the last. That holds during the slow stretch as after it.
  - Inside the stretch nearly every wave is about 320 µs longer: the period's mode is 440–520 µs against 120–200 µs afterwards. It is not a mix of normal waves and stalled ones.
  - The stretch ends within 0.1 s, at 1.9 s of wall time. The 16-node run's slower patches also end by 2.0 s, though at a different wave count and simulated time.
- **Closure.** The waves' time above the steady median is 1.83 s on 32 nodes (1.40 s of it in the first 2 s) against 1.08 s on 16 nodes (0.61 s). The difference, 0.75 s, matches the 0.70 s by which the 32-node run is longer. So **the stretch is all of σ 100's 16→32-node loss in this pair.**
- **Not only at start-up.** The other traced runs show the same signature, a reduction of 300 µs to 9 ms while turnarounds stay normal, at other times:
  - σ 2,000 on 16 nodes: about 1,000 µs for the first 3.5 s, about 450 µs to 5 s, and about 400 µs from 6.5 to 8.5 s (the run's whole excess is 6.1 s);
  - uniform on 32 nodes: 6.6–8.9 ms from 3.0 to 5.0 s, mid-run (one wave took 269 ms);
  - steady state between episodes: 80–130 µs.
- **The untraced runs.** At 32 nodes the three untraced σ 100 W 400 runs took 4.74–5.05 s. That is consistent with the traced run's 5.78 s divided by the usual 1.135 tracing cost (5.09 s), so they probably had the stretch too; without it they would take about 3.9 s. They cannot show it, because they record no time course.

**Why a slow wave costs throughput in proportion.** A wave completes the buckets that every PE had passed at the previous wave and whose counts match; by construction that is about a third of the passed buckets (section 58). In the σ 100 32-node stretch every PE had passed 34–35 buckets beyond GVT, and PE 0 sat at the window edge (its lead was 400). Yet each wave completed 11.6 buckets, as in steady state (10.1–10.5). So GVT moves about 93 time units per wave however long the wave takes, and throughput falls with the wave period. Asking about every passed bucket (section 60) raised completion only to 8.4–8.9 per wave, because events were still in transit. A wider window does not absorb a slow wave either: at W 800 completion per wave rose only from 8.8 to 9.8 buckets (job P, 16 nodes).

**What could make the reduction slow for seconds.** Four candidates, and how job E tells them apart:
- **H1, kernel work on the PEs that must run the hops.** For example, first-touch page faults in the runtime's pools as traffic first reaches them (transparent huge pages are `always`). It would show as kernel time and minor faults in the stretched waves.
- **H2, something tied to process age.** Driver, OS or psm2 timers; automatic NUMA balancing, for instance, starts scanning a process 1 s after it starts. Starting the clock later would remove it.
- **H3, the fabric.** Back-pressure from other traffic, or receive-queue overflow and resends. It would show in the hfi1 counters.
- **H4, something specific to the Charm++ nodegroup reduction or to Reconverse's broadcast.** It would be absent with Charades' own process tree, `--gvt-wave-tree=4`; section 118 found that tree's hops stand for the Charm++ ones in steady state. The tree also records every hop, which locates the slow ones.

**New, for diagnosis only (branch `episode-diag`):**
- **Time-stamped progress lines.** They carry the wall time since the clock started, and "Simulation Starting" prints the Unix time. Untraced runs now show their own time course every 64 GVT advances, at no cost.
- **`--start-delay-ms=N`.** PE 0 starts the clock N ms after setup (`CcdCallFnAfter`); every PE sits in its scheduler meanwhile.
- **Thread usage per wave.** With `--gvt-trace=2` on Linux, each process's wave record adds its PEs' thread usage since their previous contribution, read with `getrusage(RUSAGE_THREAD)` once per PE per wave: minor faults and involuntary context switches (summed), user and kernel time (summed), and the largest kernel time with its rank.
- **`scripts/stampede3/hfi_sampler.py`.** One per node, on core 1, which no PE uses. Every 100 ms it records the Unix time and the hfi1 counters, plus a full dump of every counter at the start and end:
  - transmit wait and flow-stall ticks (back-pressure from the switch);
  - packets and words in and out;
  - the driver's receive-overflow counters (`DRIVER_EgrBufFull`, `DRIVER_EgrHdrFull`, `RcvOverflow`, `SeqDrop0`, and the per-context `RcvHdrOvr` summed).

  A login node read all 115 counter files in about 0.4 ms per sample.
- **Mac:** change tier 54/54, with a new config `agg_deadline_bucket_pp_diag` (start delay and `--gvt-trace=2`) next to its base and `bucket_window`; committed counts equal.

**Runs** (W 400, end time 2,048,000, 32 nodes unless stated, the sampler on unless stated; reps interleaved; a warm-up launch first):
- **A. Untraced, 3 reps:**
  - σ 100 (PP 2,048) four ways: with the Charm++ reduction (the default), with `--gvt-wave-tree=4`, with `--start-delay-ms=5000`, and with `--wave-batch=4`;
  - σ 2,000 (PP 512) and uniform (WPs 512), with the default reduction.
- **B. Traced (`--gvt-trace=2 --pe-stats=1`):**
  - σ 100 with the Charm++ reduction and with the tree, 2 reps each;
  - σ 2,000 and uniform with the tree, 1 rep each.
- **C. 16 nodes (the allocation's first 16):** σ 100, untraced (2 reps) and traced (1).
- **D. Devastator at W 1,000:** σ 100 and uniform, 2 reps.
- **E. Sampler off:** σ 100, untraced, 2 reps.

**Predictions:**
- E1. **Systematic at start-up.** At 32 nodes, σ 100 with the Charm++ reduction, the first 2 s of wall time run at least 2× slower per GVT advance than the rest, in all 3 untraced reps (from the progress lines). At 16 nodes it is at most 1.4×.
- E2. **In the reduction.** In the traced Charm++ runs, during the stretch the reduction after the last process is at least 2× its steady median, and the slowest turnaround at most 1.5× its own.
- E3. **The path (H4).** Either the tree has no stretch (at most 1.3×) and runs at least 1.1× the Charm++ reduction at σ 100, or its hop records put the excess somewhere specific:
  - on hops into at most 2 processes for at least 70% of each stretched wave's excess (a slow receiver);
  - or on most hops (the network, or every receiver).
- E4. **Kernel (H1).** If kernel work causes it, then during the stretch:
  - the critical-path process's kernel time per wave is at least 3× steady, and its rise is at least half the wave's excess;
  - minor faults per wave are at least 3× steady.
- E5. **Fabric (H3).** If the fabric causes it, transmit wait or a receive-overflow counter rises during the stretches on at least one node and is flat between them.
- E6. **Process age (H2).** With a 5 s start delay, the first 2 s run at most 1.3× the rest if the stretch is tied to process age, and are unchanged (at least 2×) if it is tied to the simulation's own start.
- E7. **`--wave-batch=4`** is at least 1.05× the default at 32 nodes σ 100. Here the reduction, not a PE's 128th event, is on the critical path (unlike σ 2,000 at 16 nodes, section 120).
- E8. **Sampler cost:** σ 100 without the sampler is within ±2% of the runs with it.

**What follows from the results:**
- **H1:** touch the pools before the clock starts, or when they are allocated; a start-up fix in Charades or Reconverse.
- **H2:** find the timer, and warm up that mechanism before the clock.
- **H3:** the fabric is not ours to fix. Make GVT tolerate a slow reduction instead: fewer sequential hops on the critical path, or count waves that overlap.
- **H4:** make the tree the default, or fix the Charm++ path.
- **E7 right:** the reduction latency at 32 nodes is worth attacking in steady state too: shorter passes while a wave is in flight at large node counts, or section 118's free-core poller.

## Baseline verification on the Mac

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

## LCI on native psm2 (PR uiuc-hpc/lci#214)

> **Status: current.** The patched LCI is what `charades-exp` runs on (see "Native psm2 through a patched LCI" for its effect on Charades).

**Benchmark.** `lci_bench_many2many_am`, 8-byte active messages, 2 Stampede3 nodes, one rank per node; message rate in M messages/s, all ranks aggregated; higher is better. Builds in `$WORK/lci_ab/{old,new,nits,fs}`; scripts `$WORK/charades-runs/lci_ab{,2}.sh`, `lci_hang{,2}.sh`, `lci_fs.sh`; outputs in `$WORK/charades-runs/lci_ab{,2}.log` and `$WORK/lci_ab/fs/*.out`; stacks of the hangs in `~/charades-data/lci_hang/`. Stampede3 runs libfabric 2.0.0 (Cornelis build 2174) and libpsm2 11.2.237.

**Review changes cost nothing** (job 3629781; 5 interleaved pairs at 8 threads): before review (77d16300) 3.47, after (9effa44a) 3.38, median of 5 each; paired ratio median 0.99. Every 23-thread run of both builds hung (timeout, 0 of 5 each).

**Fair-share receive cap** (job 3632240; 8c867a6c on top of the review fixes, against the review fixes alone; 3 runs each):

| threads (= LCI devices) | review fixes only | with the fair-share cap | ratio (higher is better) |
|---|---|---|---|
| 8 | 3.37, 3.40, 3.37 | 3.40, 3.39, 3.35 | 1.00 |
| 16 | 4.06, 4.02, 4.04 | 4.32, 4.20, 4.16 | 1.04 |
| 23 | hung 3 of 3 (23.6–23.9 M "no posted recvs" alerts, killed) | 4.21, 4.04, 4.11 (2 harmless alerts per rank at bind time) | — |

- **Reverted from the PR (2026-10-23, 16cbcaf2)** at the maintainer's request: out of scope, and LCI can't know how many devices will be created when it creates the first, so setting `net_max_recvs` is the upper layer's job (here, Reconverse). The cap stays on LCI branch `recv-fair-share` (c2241fd0); no follow-up PR yet.
- The 23-device hang was pool starvation: the default pool is 65,536 packets and each device posts up to 4,096 receives, so the first ~16 devices hold every packet and the rest post none. The cap is min(`net_max_recvs`, 7/8 × packets ÷ bound devices); nothing changes up to 14 devices.
- The other hang, 1 thread sending 4 M messages, is psm2's lack of receiver backpressure: the sender exhausts `PSM2_MQ_RECVREQS_MAX` (1 M unexpected messages), and raising it moves the abort to send descriptors. tcp finishes the same run. That is the benchmark's missing flow control, not LCI.
- LCI ctest on the Mac (ofi tcp): 25/25 on the psm2 build, 33/33 in a full build. Under `srun --mpi=pmi2` on Stampede3, the collective, loopback and cxx11 tests fail identically over tcp (a bootstrap `decode_value` assert): a launcher problem, separate from the PR.

## Plan history: the next-steps list as of 2026-10-21

> **Status: historical.** Moved from `CONTEXT.md` on 2026-10-23, when its list was rewritten. The numbers here summarise sections above, as of that date.

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
8. Dragonfly port: done 2026-10-23 (see open issue 4). Next: performance runs on Stampede3 after the controller work, with `--gvt-bucket-size=1000`.
