# The PADS'19 hold (F3)

Mikida and Kale's hold of events past a cutoff, run as a baseline beside the window. Part of the Charades results: the current paper tables are on the front page, [../RESULTS.md](../RESULTS.md), and every section's date, job, status and file is in [INDEX.md](INDEX.md). Sections keep the numbers (§N) they had in the single RESULTS.md they came from (split 2026-11-07); "section N" anywhere means §N.

| § | date | status | section |
|---|---|---|---|
| 224 | 2026-11-04 | design (results in 225) | F3 rerun: the PADS'19 hold with PADS'19's release rule, cutoffs scaled to the mean delay, and ROSS's dragon… |
| 225 | 2026-11-04 | current | F3R results: the PADS'19 hold never beats no hold with the fast path on by more than 2%; without a window i… |

## Current

Current findings, and designs with their results, in the order they were written.

### §224 · F3 rerun: the PADS'19 hold with PADS'19's release rule, cutoffs scaled to the mean delay, and ROSS's dragonfly window below 5,000 ps (job F3R design, 2026-11-04; written before any runs)

> **Status: design.** Reruns section 222's F3 arms, which used the wrong release rule (section 223). User decision 2026-11-04: submit the rerun, 4 nodes first, 16 nodes only where the 4-node runs finish.
> - **Code:** charades 8a34d51, tree `charades-f3`, on `charm-pads-perf`. It is round 3's engine plus one fix to the hold, below.
> - **Mac check on this code:** change tier 48/48 on Simple PHOLD and traffic with `bucket`, `bucket_hold`, `bucket_hold_early` and the new `bucket_hold_pads19` (PADS'19's rule, cutoff 4).

**The hold's release loop scanned every remaining bucket.**
- With PADS'19's rule (`--gvt-clear-buckets=0 --gvt-clear-lag=0`), every GVT advance looped over every bucket from GVT to the end of the run, mostly empty lists.
- Traffic at 4 nodes has 1.5 M buckets of 8 and about 95,000 GVT advances per run (job ABL's direct arms), so each PE would check about 10¹¹ lists. PHOLD has 256,000 buckets and about 31,000 advances.
- PADS'19 keyed held events by offset from GVT, which bounds the scan, so the cost is this implementation's, not the method's.
- GVT never passes a held event's bucket (a held event counts as sent, not received), so 8a34d51 stops the scan at the highest bucket holding an event. Nothing else changes.
- Its cost before the fix was estimated from these counts, not measured.

**The cutoffs are scaled to the mean delay.**
- PADS'19 counts the cutoff (2, 4, 8, 16) in buckets of width 1. Its runs cover about 1,024 time units: Table 1 shows about 1,024 GVT advances of one bucket at width 1, and 128 at width 8. It does not give PHOLD's delays, so its cutoffs have no fixed size in our time units.
- Section 223's Mac cutoffs of 2–16 buckets of 8 are 16–128 time units, against a mean delay of 1,000 (lookahead 100). They hold nearly every remote event.
- This job sweeps the cutoff in mean delays instead: K = 16, 128 and 512 buckets of 8, that is 128, 1,024 and 4,096 time units, or 0.13, 1 and 4 mean delays. Traffic has the same lookahead and mean.

**The hold turns the local fast path off** ("Local fast path: off, it does not support --gvt-adaptive-buckets"), so same-process events travel as messages. No hold with `--local-fast-path=0` is therefore the hold's own reference, beside Charades' default.

**Mac runs behind this design** (PHOLD σ 100, 1,024 LPs, END 256,000, **2 processes × 2 PEs**, run one after another; M committed ev/s, higher is better):

| arm | M ev/s | events rolled back |
|---|---|---|
| no window, fast path on (3 runs) | 1.03–1.06 | 50,743–94,623 |
| no window, fast path off (2 runs) | 0.93–0.94 | 42,103–92,418 |
| W 250, fast path on | 1.04 | 1,149 |
| W 250, fast path off | 0.90 | 1,062 |
| no window, PADS'19 hold, cutoff 16 buckets (0.13 mean delays) | 0.10 | 22.2 M |
| the same, cutoff 128 (1 mean delay), 2 runs | 0.15 | 10.4–10.5 M |
| the same, cutoff 256 (2 mean delays) | 0.23 | 6.37 M |
| the same, cutoff 512 (4 mean delays), 2 runs | 0.90–0.91 | 34,097–42,605 |
| the same, cutoff 1,024 (8 mean delays) | 0.93 | 58,357 |

- All runs commit 3,934,451 events.
- **Correction to section 223's Mac table:** those runs used 2 × 4 PEs, these 2 × 2, so the two tables cannot be compared. Within section 223's table, the hold without a window (fast path off) was compared against no hold with the fast path on. At 2 × 2 the fast path is worth 1.11–1.16×, and the hold at cutoffs up to 2 mean delays is still 4–9× slower than no hold with the fast path off.

**Script:** `$WORK/charades-runs/f3r224.slurm` (copy in `~/charades-data/abl/`), skx-dev, 16 nodes, 1 h 55 min. Launch and workloads as in section 222 (2 × 23, pemap, 23 LCI devices, `+mempool_remote_free`, `numactl --localalloc`, `--blocked-time=1 --ctl-log=1 --commit-digest=1`; PHOLD σ 100, σ 2,000 and uniform at END 2,048,000; traffic at END 12,000,000; buckets of 8). 2 reps, arm order reversed in rep 2. Cap 150 s per Charades run, 300 s per ROSS run.
1. **Gate**, 2 nodes: change tier on Simple PHOLD and traffic with `bucket_hold_pads19`, `bucket_hold`, `bucket_nofastpath` and `bucket_window`.
2. **4 nodes**, side by side:
   - nodes 0–3: σ 100, then traffic;
   - nodes 4–7: σ 2,000, then uniform;
   - nodes 8–11: ROSS's dragonfly window and Charades' dragonfly controller at 4 nodes;
   - node 12: the same at 1 node.
3. **16 nodes:** the four workloads. The hold without a window at cutoffs 16 and 128 runs only where all its 4-node runs finished.

**Arms per workload and rep.** All Charades arms send directly, without htram, as PADS'19 did. W B is the better fixed window for direct sends in section 223: 400 on PHOLD, 1,000 on traffic.

| arm | hold | fast path | window |
|---|---|---|---|
| fp | none | on (Charades' default) | none (W 0) and W B |
| nofp | none | off | none and W B |
| hold16, hold128, hold512 | PADS'19's rule, cutoff 16 / 128 / 512 buckets | off (the hold turns it off) | none, as in PADS'19 |
| hold16w, hold128w | PADS'19's rule, cutoff 16 / 128 | off | W B |

**ROSS's dragonfly window** at 1 and 4 nodes, 2 reps, as in section 222: none, and `--max-opt-lookahead` 625, 1,250, 2,500 and 5,000 ps. Charades' dragonfly controller (WPs 512, buckets of 1,000 ps) runs alongside for the ratio.

**Measures:** M committed ev/s, events rolled back, remote and anti-message sends, events held and held events cancelled in the sender, blocked share.

**Predictions:**
- **F3R1:** within each workload and node count, every arm commits the same events with the same digest, the hold included.
- **F3R2:** fast path off ÷ on, with no hold and at the same window, is 0.80–0.98 at 4 nodes. It is lowest on σ 100, where most events stay in the process, and highest on uniform.
- **F3R3:** without a window, the hold at cutoffs 16 and 128 runs at 0.05–0.3 of no hold with the fast path off, and rolls back at least 50× more events. Some of these runs may hit the cap. At cutoff 512 it holds under 5% of remote events and runs at 0.95–1.02 of no hold with the fast path off.
- **F3R4:** beside W B, the hold at cutoffs 16 and 128 runs at 0.95–1.02 of W B with the fast path off.
- **F3R5:** on every workload, no hold arm beats the best arm without it (fast path on, no window or W B) by more than 2%. The hold's best is at most 0.5 of deadline htram (section 223) on σ 2,000 and uniform, and at most 0.75 on σ 100 and traffic.
- **F3R6:** with the fast path on, no window runs at 0.90–1.02 of W B on PHOLD, and at 0.80–0.97 on traffic, which rolls back more as W grows (section 223).
- **F3R7:** ROSS's best dragonfly window lies between 1,250 and 5,000 ps. With it, ROSS runs 1.35–1.6× faster than without one. Charades ÷ ROSS's best is 2.7–3.2 at 1 and 4 nodes.

### §225 · F3R results: the PADS'19 hold never beats no hold with the fast path on by more than 2%; without a window it costs PHOLD up to 5.6× and gains traffic up to 1.10× at 4 nodes; beside a window it changes little; ROSS's best dragonfly window is 2,500–5,000 ps, and Charades ÷ ROSS is 2.98–3.05 (2026-11-04; skx-dev batch job 3683036, 16 nodes)

> **Status: current.** Design and predictions in section 224. 48 minutes; gate 48/48; no run failed, hit the cap or was skipped, so every hold cutoff also ran at 16 nodes. Data, `f3r_summary.py` and `f3r_summary.txt` in `~/charades-data/abl/` (the job is in `f3r/j3683036`). All Charades arms send directly, as PADS'19 did.
> - **Counts:** within each workload and node count, all 18 Charades runs commit the same events with the same digest, the hold included. ROSS commits the same count as Charades on dragonfly at 1 and 4 nodes.

**The hold against no hold** (M committed ev/s, mean of 2 reps; higher is better). The hold turns the fast path off, so its own reference is no hold with the fast path off. W B is 400 on PHOLD and 1,000 on traffic. Cutoffs are in buckets of 8 time units: 16, 128 and 512 are 0.13, 1 and 4 mean delays.

| workload | nodes | no hold, fast path on: none / W B | no hold, fast path off: none / W B | hold, no window: cutoff 16 / 128 / 512 | hold beside W B: cutoff 16 / 128 | **best hold ÷ best no hold, fast path on** | best hold ÷ deadline htram (section 223) |
|---|---|---|---|---|---|---|---|
| σ 100 | 4 | 80.1 / **95.7** | 61.6 / 77.4 | 11.2 / 42.3 / 60.0 | 80.1 / 76.5 | **0.84** | 0.40 |
| σ 2,000 | 4 | 49.9 / **55.0** | 45.6 / 49.5 | 20.3 / 25.3 / 44.4 | 47.8 / 49.6 | **0.90** | 0.32 |
| uniform | 4 | 39.2 / **40.6** | 37.3 / 39.9 | 10.1 / 12.4 / 37.6 | 36.0 / 40.2 | **0.99** | 0.30 |
| traffic | 4 | 187.6 / **200.7** | 164.8 / 182.7 | 179.0 / 181.1 / 164.6 | 190.6 / 188.3 | **0.95** | 0.67 |
| σ 100 | 16 | 314.8 / **373.9** | 236.6 / 303.3 | 46.9 / 98.1 / 241.6 | 311.3 / 302.2 | **0.83** | 0.38 |
| σ 2,000 | 16 | 190.5 / **210.5** | 174.1 / 193.7 | 66.8 / 86.9 / 172.8 | 183.5 / 191.3 | **0.91** | 0.32 |
| uniform | 16 | 129.5 / 143.9 | 131.0 / 144.6 | 35.1 / 40.8 / 128.9 | 136.9 / **146.6** | **1.02** | 0.38 |
| traffic | 16 | 723.5 / **774.0** | 641.1 / 716.7 | 612.1 / 640.1 / 629.5 | 761.2 / 744.1 | **0.98** | 0.72 |

**Ratios to the hold's own reference** (no hold, fast path off, same window; higher is better for the hold):

| workload | nodes | no window: cutoff 16 / 128 / 512 | W B: cutoff 16 / 128 | events rolled back (M), no window: no hold / cutoff 16 / 128 / 512 | share of remote sends held, no window: cutoff 16 / 128 / 512 |
|---|---|---|---|---|---|
| σ 100 | 4 | 0.18 / 0.69 / 0.97 | 1.03 / 0.99 | 414 / 2,021 / 610 / 385 | 1.00 / 1.00 / 0.73 |
| σ 2,000 | 4 | 0.45 / 0.56 / 0.98 | 0.96 / 1.00 | 76 / 817 / 595 / 83 | 1.00 / 0.97 / 0.05 |
| uniform | 4 | 0.27 / 0.33 / 1.01 | 0.90 / 1.01 | 42 / 1,772 / 1,323 / 38 | 1.00 / 0.99 / 0.03 |
| traffic | 4 | **1.09 / 1.10** / 1.00 | 1.04 / 1.03 | 744 / 576 / 544 / 726 | 1.00 / 1.00 / 0.78 |
| σ 100 | 16 | 0.20 / 0.41 / 1.02 | 1.03 / 1.00 | 1,705 / 8,758 / 4,793 / 1,383 | 1.00 / 1.00 / 0.79 |
| σ 2,000 | 16 | 0.38 / 0.50 / 0.99 | 0.95 / 0.99 | 352 / 4,147 / 2,853 / 370 | 1.00 / 1.00 / 0.18 |
| uniform | 16 | 0.27 / 0.31 / 0.98 | 0.95 / 1.01 | 260 / 7,655 / 6,839 / 293 | 1.00 / 1.00 / 0.06 |
| traffic | 16 | 0.95 / 1.00 / 0.98 | 1.06 / 1.04 | 3,009 / 3,326 / 3,015 / 3,126 | 1.00 / 1.00 / 0.85 |

- **The hold never beats Charades' default** (no hold, fast path on, the better of no window and W B) by more than 2%: 0.83–1.02. Two things hold it back:
  - **It turns the fast path off.** The fast path is worth 1.23–1.33× on σ 100 (fast path off ÷ on 0.75–0.81), 1.08–1.14× on σ 2,000 and traffic, and nothing on uniform at 16 nodes.
  - **A window already does its job.** Beside W B, the hold is 0.90–1.06 of no hold.
- **Without a window, on PHOLD, a cutoff of up to one mean delay costs 1.4–5.6×** (0.18–0.69) and rolls back 1.5–42× more events. Senders run far ahead of GVT, so nearly every remote event lands past the cutoff and is held. A held event goes out at the next GVT advance, to a receiver that has run ahead of it. At 4 mean delays the hold holds 3–79% of remote events and is level (0.97–1.02).
- **On traffic without a window the hold gains 1.09–1.10× at 4 nodes** (cutoffs 16 and 128), with 23–27% fewer events rolled back. It is level at 16 nodes (0.95–1.00). It still runs at 0.90 of no hold with the fast path on at W 1,000.
- **Against htram the hold is far behind:** its best is 0.30–0.40 of deadline htram on PHOLD and 0.67–0.72 on traffic (htram from job ABL, section 223, same engine).
- PADS'19 reported +18% on PHOLD Combo and +70% on dragonfly. Those were non-SMP runs on Blue Waters, with other PHOLD settings. We did not run its PHOLD Combo or dragonfly configurations.
- **Not investigated:** why holding reduces rollbacks on traffic at 4 nodes but raises them on PHOLD.

**ROSS's dragonfly window** (`--max-opt-lookahead`, ps; ROSS optimistic, batch 2, GVT interval 64; M committed ev/s, mean of 2 reps, efficiency in parentheses):

| nodes | none | 625 | 1,250 | 2,500 | 5,000 | best ÷ none | Charades controller | **Charades ÷ ROSS's best** |
|---|---|---|---|---|---|---|---|---|
| 1 | 9.84 (70.7%) | 9.89 (100%) | 12.23 (100%) | **13.70** (99.6%) | 13.09 (93.6%) | 1.39 | 41.80 | **3.05** |
| 4 | 28.69 (63.0%) | 25.77 (100%) | 34.40 (100%) | 40.11 (99.6%) | **42.25** (96.0%) | 1.47 | 125.86 | **2.98** |

- At 1 node, ROSS's best is now 2,500 ps, inside the grid. At 4 nodes it is still 5,000; section 223 found that 10,000 and above change nothing, so 7,500 is the only value left untried.
- Below 2,500 ps ROSS slows down. At 625 and 1,250 ps every event it executes is committed (100% efficiency), but it waits at the window.
- This job agrees with job ABL: ROSS at 5,000 ps 42.25 against 41.28, Charades' controller 125.86 against 123.67 at 4 nodes. **Charades ÷ ROSS with its window on dragonfly is 2.98–3.05** at 1 and 4 nodes. It replaces section 223's provisional 3.0–3.2.

**Predictions (section 224):**
- **F3R1 right.**
- **F3R2 mostly right.** Fast path off ÷ on is lowest on σ 100 and highest on uniform, as predicted. σ 100 without a window (0.75–0.77) is below the range, and uniform at 16 nodes (1.00–1.01) is above it.
- **F3R3 half right.**
  - Cutoffs 16 and 128 run at 0.18–0.69 of no hold on PHOLD; only 2 of 6 cells at 4 nodes fall in the predicted 0.05–0.3.
  - Events rolled back rise 1.5–42×, not at least 50×: at this scale no hold without a window already rolls back a lot.
  - On traffic the hold gains 1.09–1.10 at 4 nodes instead of losing.
  - At cutoff 512, the rate (0.97–1.02) is right. The held share is under 5% only on σ 2,000 and uniform at 4 nodes; it is 73–85% on σ 100 and traffic.
- **F3R4 mostly right:** 10 of 16 cells are in 0.95–1.02. Cutoff 16 is 0.90 on uniform at 4 nodes. On σ 100 (cutoff 16) and traffic (both cutoffs) the hold is 1.03–1.06.
- **F3R5 right:** the hold reaches at most 1.02 of the best no-hold arm. Its best is 0.30–0.38 of deadline htram on σ 2,000 and uniform, and 0.38–0.72 on σ 100 and traffic.
- **F3R6 mostly right:** no window ÷ W B with the fast path on is 0.90–0.96 on σ 2,000 and uniform and 0.93 on traffic, in range. σ 100 is 0.84, below the range: without a window it rolls back more events than it commits.
- **F3R7 right:** the best window is 2,500 (1 node) and 5,000 ps (4 nodes); best ÷ none is 1.39 and 1.47; Charades ÷ ROSS's best is 3.05 and 2.98.
