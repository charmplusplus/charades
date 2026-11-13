# Aggregation through htram

Message cost, htram's modes and buffers, the deadline flush policy, choosing htram automatically, input buffers, PP's allocation and start-up, flush timing, and F2 (htram against direct sends). Part of the Charades results: the current paper tables are on the front page, [../RESULTS.md](../RESULTS.md), and every section's date, job, status and file is in [INDEX.md](INDEX.md). Sections keep the numbers (§N) they had in the single RESULTS.md they came from (split 2026-11-07); "section N" anywhere means §N.

| § | date | status | section |
|---|---|---|---|
| 57 | 2026-10-24 | design | Do htram's buffers hold GVT back at scale? |
| 58 | 2026-10-24 | current | Do htram's buffers hold GVT back at scale?, results |
| 65 | 2026-10-24 | design | Which htram mode and buffer for which workload (fast path on) |
| 66 | 2026-10-25 | current | Which htram mode and buffer for which workload, results |
| 69 | 2026-10-25 | design | Choosing htram automatically (`--agg-auto`), and LPs per chare at lookahead 10 |
| 70 | 2026-10-25 | design | Why `--agg-auto` differs from the fixed setting it chose |
| 71 | 2026-10-25 | current | Why `--agg-auto` differs, results: an idle htram instance changes the pace of blocked passes |
| 72 | 2026-10-25 | design | `--agg-auto` with one active instance, and pausing blocked passes |
| 73 | 2026-10-25 | current / design | Pausing blocked passes, results; memory layout as the cause, design |
| 74 | 2026-10-25 | current / design | Memory layout: heap pads, results; padded shared atomics, design |
| 75 | 2026-10-25 | current / design | Padded shared atomics, results; `--agg-auto` without the second instance, design |
| 76 | 2026-10-25 | current | `--agg-auto` without the second instance, results: the PP 2,048 gain is not aggregation (2026-10-25; skx-de… |
| 102 | 2026-10-26 | design | htram flush order: rotating start and earliest timestamp first |
| 103 | 2026-10-26 | current | htram flush order, results: no effect; the lower edge stays late |
| 108 | 2026-10-27 | design | Cheaper input buffer pushes: padded mutex input buffers and lock-free rings |
| 109 | 2026-10-27 | current | Input buffer modes, results: lock-free rings make uniform 1.08–1.21× faster at 16 nodes (a push 0.73 → 0.17… |
| 110 | 2026-10-27 | design | Rings against the mutex input buffer on all 8 scaling workloads, before making rings the default |
| 111 | 2026-10-27 | current | Rings on all 8 workloads, results: no cell below 0.98, uniform 1.08–1.21×; rings are the default |
| 137 | 2026-10-28 | current | PP's late held events: a race at each GVT update, not a missed flush |
| 138 | 2026-10-28 | design | Sending what the next GVT will make due before it is published (`--agg-flush-ahead`), against holding the w… |
| 139 | 2026-10-28 | current | Flush ahead and window lag, results: sending early removes the late events but doubles messages; the race c… |
| 149 | 2026-10-29 | design | A wide window with the flush deadline held: decoupling again, now that rollbacks are shallow |
| 150 | 2026-10-29 | current | A wide window with the flush deadline held, results: much bigger messages and 3× less sensitivity to a late… |
| 156 | 2026-10-29 | design | σ 2,000's start-up ramp at 16 nodes: start delay, htram mode, and a profile split by time |
| 157 | 2026-10-29 | current | Job R16 results: σ 2,000's start-up ramp is htram PP's; the start delay, WPs and direct sends tell it apart… |
| 158 | 2026-10-29 | design | Does PP's start-up ramp follow glibc's handling of PP's per-send buffers? TLB shootdowns and two malloc set… |
| 159 | 2026-10-29 | current | Job A16 results: PP's start-up ramp is not the allocator (no TLB-shootdown rise, neither malloc setting rem… |
| 160 | 2026-10-29 | design | PP's shared buffers at their own limit (`--agg-pp-alloc=1`), and PP against WPs, on the four PP workloads a… |
| 161 | 2026-10-30 | current | Job P16 results: allocating PP's shared buffers at their own limit removes most of PP's start-up ramp and g… |
| 222 | 2026-11-04 | design | F2 and F3 on PHOLD and traffic, and ROSS's window on traffic and dragonfly |
| 223 | 2026-11-04 | current (F2, ROSS) / superseded (F3) | ABL results: htram's deadline flush is 2.1–3.3× direct sends on PHOLD and 1.4× on traffic; eager flush lose… |
| 256 | 2026-11-07 | design (results in 257) | Bundling at 32 nodes on the remote-heavy end, and fixed windows past F1's and F5's grids |
| 257 | 2026-11-08 | current | AG32 results: at 32 nodes bundling is 2.29× direct sends on uniform and 3.14× on σ 4,000; W 400 and traffic… |
| 267 | 2026-11-09 | design (results in 268) | Why uniform's messages shrink with node count, and per-process flushing in PP (`--agg-pp-local`): job PL16 |
| 268 | 2026-11-09 | current; superseded in part by 270 | PL16 results: one shared buffer per process makes uniform's messages 9× larger (111 events) but runs at 0.8… |
| 269 | 2026-11-09 | design (results in 270) | Where local 1's extra time goes: a profile, and PP's shared counters one destination per cache line |
| 270 | 2026-11-09 | current | PD16 results: with each destination's counters on their own cache line, local 1 runs at 1.41× its packed ra… |
| 271 | 2026-11-09 | design (results in 272) | Does padded local 1 keep its lead over WPs 512 on uniform at 64 nodes? |
| 272 | 2026-11-10 | current (inconclusive); superseded in part by 276 | L64 results: the machine ran at half speed, so the 64-node comparison is not usable; local 1 led WPs 512 in… |
| 273 | 2026-11-10 | design (results in 274) | L64 again, with P64's own binary as a control in every rep and a probe that stops the job on a slow machine |
| 274 | 2026-11-11 | current (stopped by its probe); superseded in part by 275 | L64b results: the probe stopped the job (P64's own binary at 0.52 of its P64 rate); both slow 64-node jobs… |
| 275 | 2026-11-11 | design (results in 276) | Can the job name a bad node? L64b again with a network record between runs |
| 276 | 2026-11-11 | current | L64b results: at normal speed, padded local 1 runs at 1.52× WPs 512 on uniform at 64 nodes (1.49× under the… |
| 277 | 2026-11-12 | design (results in 278 and later) | Padded local 1 as a candidate setting for uniform in the tables, 1–64 nodes |
| 278 | 2026-11-12 | current (1–16 nodes); superseded in part by 280 | UL results, 1–16 nodes: padded local 1 is 1.17× the table's setting on uniform at 16 nodes, but 0.61–0.80 o… |
| 279 | 2026-11-12 | design (results in 280) | Why local 1 loses at 1 node: a profile, and fewer copies into the shared buffer |
| 280 | 2026-11-12 | current | PF1 results: at 1 node, local 1 loses its time in the copy into the shared buffer, almost all of it on two… |
| 281 | 2026-11-12 | current | Charades' htram setting in each paper cell, 1–64 nodes |
| 282 | 2026-11-13 | current | UL at 32 and 64 nodes: both probes stopped their jobs (the fabric was congested: switch back-pressure about… |
| 3 | 2026-10-20 | historical | Per-message cost and scaling |
| 4 | 2026-10-20 | superseded | Aggregation through htram |
| 5 | 2026-10-20 | historical | Deadline flush policy |

## Current

Current findings, and designs with their results, in the order they were written.

### §57 · Do htram's buffers hold GVT back at scale? (design, 2026-10-24; written before any runs)

> **Status: design.** Written before any runs.

**Runs** (skx-dev, 16 nodes, output on `$SCRATCH`): σ 100 and σ 2,000, W 250, 4 and 16 nodes, `--gvt-trace=1`, 2 reps; aggregation PP 512 (default), PP 128, PP 64, WPs 512, direct sends.

**Predictions:**
- H1. Buckets completed per wave rise from about 7.5 with PP 512 to at least 10 with WPs 512 or direct sends.
- H2. At 16 nodes, smaller PP buffers or WPs beat PP 512 by at least 10% at σ 2,000; at 4 nodes PP 512 stays best.

### §58 · Do htram's buffers hold GVT back at scale?, results (2026-10-24, skx-dev batch job 3636185)

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

### §65 · Which htram mode and buffer for which workload (fast path on) (design, 2026-10-24; written before any runs)

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

### §66 · Which htram mode and buffer for which workload, results (2026-10-24/25; 16 nodes: skx-dev batch job 3636522; 4 nodes: skx-dev batch job 3638303)

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

### §69 · Choosing htram automatically (`--agg-auto`), and LPs per chare at lookahead 10 (design, 2026-10-25; written before any runs)

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

### §70 · Why `--agg-auto` differs from the fixed setting it chose (design, 2026-10-25; written before any runs)

> **Status: design.** Written before any runs.

**Why.** In job 3638610 (16 nodes; results to be written up with the 4-node job) `--agg-auto` chose as the rule says in every run, but its rate differs from the fixed setting it chose, both ways and consistently across reps with interleaved order: after switching live to PP 2,048 at σ 100, 0.82 of fixed PP 2,048 (505 against 613 M ev/s at W 250); staying on PP 512 at σ 2,000, 1.07 of fixed PP 512 (394 against 368). htram's message counts and GVT advances match the fixed runs; time per GVT advance does not (σ 100: 164 against 135 µs). What `--agg-auto` adds besides the decision is a second, idle htram instance (WPs) that every PE flushes and drains on every pass. On the Mac (2 × 4 PEs, σ 2,000) the second instance changes nothing (2.49–2.56 against 2.54–2.63 M ev/s).

**Job** (16 nodes, skx-dev; σ 100 and 2,000, W 250, 3 reps, variants in shuffled order each rep): A fixed PP 512; B fixed PP 2,048; C `--agg-auto` from PP 512 that never decides (`--agg-auto-advances` 10⁹); D the same from PP 2,048; E `--agg-auto` from PP 512 deciding as usual.

**Predictions:**
- I1. C = A and D = B within 3%: the second instance is not the cause.
- I2. E at σ 100 below B by more than 5%: the live switch leaves PP slower than starting at 2,048, through something not yet identified.

### §71 · Why `--agg-auto` differs, results: an idle htram instance changes the pace of blocked passes (2026-10-25, skx-dev batch jobs 3638610 and 3638739)

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

### §72 · `--agg-auto` with one active instance, and pausing blocked passes (design, 2026-10-25; written before any runs)

> **Status: design.** Written before any runs.

**Jobs** (fast path on, short runs, each starting with warm-ups on every node):
- 16 nodes (skx-dev): σ 100 and 2,000 at W 250, 3 reps, variants in shuffled order: fixed PP 512; fixed PP 2,048; `--agg-auto`; PP 512 with `--blocked-pause-ns` 250, 500, 1,000, 2,000, 4,000; PP 2,048 with 500 and 2,000.
- 4 nodes (skx): all 8 workloads with PP 512, PP 2,048, WPs 512 and `--agg-auto` (section 69's grid), plus σ 100 and 2,000 PP 512 with pauses of 500 and 2,000 ns.

**Predictions:**
- P1. `--agg-auto` is within 3% of the fixed setting it chooses in every cell (σ 100: PP 2,048; σ 2,000: PP 512).
- P2. At σ 2,000 a pause of 500–2,000 ns gives PP 512 at least 1.10× at 16 nodes; at σ 100 every pause is slower.
- P3. At 4 nodes the pause matters less (fewer, faster GVT rounds), within ±5% at both σ.

### §73 · Pausing blocked passes, results; memory layout as the cause, design (2026-10-25; skx-dev batch job 3638798; design written before the layout runs)

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

### §74 · Memory layout: heap pads, results; padded shared atomics, design (2026-10-25; skx-dev batch job 3638859; design written before the padded runs)

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

### §75 · Padded shared atomics, results; `--agg-auto` without the second instance, design (2026-10-25; skx-dev batch job 3638897; design written before the next runs)

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

### §76 · `--agg-auto` without the second instance, results: the PP 2,048 gain is not aggregation (2026-10-25; skx-dev batch jobs 3638968 (16 nodes) and 3638969 (4 nodes))

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

### §102 · htram flush order: rotating start and earliest timestamp first (design, 2026-10-26; written before any runs)

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

### §103 · htram flush order, results: no effect; the lower edge stays late (2026-10-26; skx-dev batch job 3643408 and idev job 3643609, 4 nodes)

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

### §108 · Cheaper input buffer pushes: padded mutex input buffers and lock-free rings (design, 2026-10-27; written before any runs)

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

### §109 · Input buffer modes, results: lock-free rings make uniform 1.08–1.21× faster at 16 nodes (a push 0.73 → 0.17 µs); σ 2,000 with the controller 0.97× (2026-10-27; skx-dev batch job 3646589, 16 nodes)

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

### §110 · Rings against the mutex input buffer on all 8 scaling workloads, before making rings the default (design, 2026-10-27; written before any runs)

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

### §111 · Rings on all 8 workloads, results: no cell below 0.98, uniform 1.08–1.21×; rings are the default (2026-10-27; skx-dev batch job 3647086, 16 nodes)

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

### §137 · PP's late held events: a race at each GVT update, not a missed flush (analysis of existing data, 2026-10-28; no new job)

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

### §138 · Sending what the next GVT will make due before it is published (`--agg-flush-ahead`), against holding the window back (`--diag-window-lag-ns`) (design, 2026-10-28; written before any runs)

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

### §139 · Flush ahead and window lag, results: sending early removes the late events but doubles messages; the race costs PP 512 3–5% on 16 nodes; the capped setting no longer helps (2026-10-28; skx-dev batch job 3653291, 16 nodes)

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

### §149 · A wide window with the flush deadline held: decoupling again, now that rollbacks are shallow (design, 2026-10-29; written before any runs)

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

### §150 · A wide window with the flush deadline held, results: much bigger messages and 3× less sensitivity to a late GVT update, but held events straggle; 1.12× at σ 2,000, a loss on uniform (2026-10-29; skx-dev batch job 3658017, 16 nodes)

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

### §156 · σ 2,000's start-up ramp at 16 nodes: start delay, htram mode, and a profile split by time (design, 2026-10-29; written before any runs)

> **Status: design.**
> - **Build:** Charades `episode-diag` (efff74e; the binary built from e6c5efc, as in E16), htram, Reconverse and the launch as in A2r.
> - **Job R16:** `$WORK/charades-runs/ramp56.slurm` (16 nodes, skx-dev, `-x c455-081`). It runs while job E (3660196) waits for 32 skx nodes.

**Why.** Section 155: at 16 nodes σ 2,000 loses 0.36–0.42 s in its first 2 s in every rep. The throughput ramps from 150 to 365 thousand simulated time units per wall second over the first 0.75 s. That is about 7% of a run, and section 122 found σ 4,000's whole 4→16-node loss was start-up. The ramp is in the slowest process's user-space work, not in the kernel and not in the reduction. Warm-up pings did not remove it (section 122).

**Runs** (W 400, end time 2,048,000, untraced, progress lines time-stamped; 3 reps, interleaved):
- **A.** σ 2,000 four ways: PP 512 (the setting in use); PP 512 with `--start-delay-ms=5000`; WPs 512; direct sends. Plus σ 4,000 with PP 512.
- **B.** σ 2,000 with PP 512 under `perf record -e cycles:u -F 1999` on process 0, every thread, 2 reps. `perf script` keeps each sample's time, thread and symbol. The clock start is taken as the first sample in an event handler.

**Predictions:**
- R1. **Start delay (E10 at 16 nodes).** If the ramp comes from the simulation's own start, the 5 s delay leaves it: at least 0.3 s lost in the first 2 s. If it comes from process age, at most 0.1 s.
- R2. **htram mode.** If PP's own start (its shared buffers and their allocation) causes the ramp, WPs 512 and direct sends lose at most half of PP 512's time in the first 2 s. If all three ramp alike, the cause is the runtime's message path or the model.
- R3. **σ 4,000** loses at least as much as σ 2,000 in its first 2 s.
- R4. **Profile, closure.** In process 0, compare the first 0.75 s after the clock start with 2–5 s, per unit of simulated time. The functions whose samples per unit of simulated time at least double hold at least 60% of the start's extra samples, and they are outside the model's event handlers.
- R5. **perf costs at most 5%** against the untraced PP 512 runs.

**What follows:**
- R1 says process age → the dip and the ramp are one mechanism; find the timer.
- R2 points at htram → pre-size or pre-touch PP's buffers.
- R4 names the functions. If they are the runtime's (LCI, psm2, Reconverse's pools), the fix is a warm-up of that path before the clock, or a change to it.

### §157 · Job R16 results: σ 2,000's start-up ramp is htram PP's; the start delay, WPs and direct sends tell it apart; the PEs wait rather than work (2026-10-29; skx-dev batch job 3660206, 16 nodes)

> **Status: current.** Design and predictions in section 156.
> - **Allocation:** c454-002 to c455-043 (16 nodes); 21:57–22:04. Gate 12/12; all 32 runs ok.
> - **Data:** `~/charades-data/scale32/episodes/r16_j3660206/` (`summary.txt` from `epi_summary.py`; profiles `perf/*.sym.gz` from `r16_perf.py`).
> - **Caveat:** the job's own `perf script` printed no symbols (`sym` needs `ip`), so the scripts were regenerated on a login node from the raw files.

**σ 2,000 (and σ 4,000), 16 nodes, W 400** (median of 3 reps; M ev/s, higher is better):

| arm | M ev/s | lost in the first 2 s (s; lower is better) | rest ÷ first 2 s |
|---|---|---|---|
| σ 2,000, PP 512 (the setting in use) | 484.4 | **0.36** (0.35–0.39) | 1.22 |
| σ 2,000, PP 512, 5 s start delay | 495.7 | 0.30 (0.29–0.33) | 1.18 |
| σ 2,000, WPs 512 | **500.1** | **0.05** (−0.01–0.10) | 1.03 |
| σ 2,000, direct sends | 200.6 | 0.01 | 1.01 |
| σ 4,000, PP 512 | 451.6 | 0.29 | 1.17 |
| σ 2,000, PP 512 under perf | 474.6 (0.98×) | 0.35 | 1.21 |

- **R1 right: the ramp comes from the simulation's start, not process age.** The 5 s delay leaves 0.30 of its 0.36 s (the 0.06 s difference is about the process-age dip of section 155).
- **R2 right: the ramp is PP's.** WPs 512 and direct sends lose 0.05 and 0.01 s. Without the ramp, PP 512 runs about 2% faster than WPs 512 here (5.62 against 5.74 s of steady running), but with it PP is 3% slower overall. Removing PP's ramp would make it the best setting by about 5%.
- **R3 wrong:** σ 4,000 loses 0.29 s, a little less than σ 2,000.
- **R5 right:** perf costs 2%.
- **R4 right in form, and it says the PEs wait.** Process 0, first 0.75 s after the clock start against 2–5 s, per unit of simulated time (both reps agree):
  - The start costs 32–33% more samples per unit of simulated time.
  - 94–95% of the excess is in functions whose cost at least doubles. Every one of them is what a PE runs when it has nothing to execute: htram's idle and deadline flush (`HTram::flushOrder` 5.5–5.9×, `flushDue` 4.9–5.6×, `agg_flush_idle` 5.7–6.8×); the scheduler loop (`OptimisticScheduler::execute`, `process_cancel_q`, `pollConverseThreadQueue`); network polling (`ips_ptl_poll`, `__psm2_mq_ipeek`, LCI progress); and locks.
  - The event handlers and event bookkeeping (`PHoldLP::forward`, `LPChare::execute_me`, `fp_push`, `remote_event_delete`) cost the same per unit of simulated time.
  - The excess is the same on all 23 threads (480–493 samples each).
  - So process 0's PEs do no more work at the start; they wait longer for each GVT advance.
- **What they wait for (E16's traced σ 2,000 run):**
  - At the start each wave completes as many buckets as later (11.0 against 8.7), and every PE has passed 33 buckets with PE 0 at the window edge (lead 386–399). But a wave takes 590 µs against 200.
  - The late process is a different one in nearly every wave (no process over 6% in the first 0.5 s), and inside it the gap from its first to its last PE's contribution is 484–503 µs, against 118 µs at 2–3 s.
  - That late PE is not faulting. The slowest process takes a median of 4 minor faults per wave at the start, and the 410 of 425 slow waves with fewer than 100 faults are as slow (484 µs) as the rest.
  - Section 121's per-PE records (job 3649213) put such a PE's extra time outside `execute()`, the htram receive handlers and the GVT handlers.
  - Packets sent at the start are about 15% smaller (2,600–2,700 against 3,000–3,150 bytes; hfi1 counters), not enough to explain 2.5× slower waves.
- **Not yet known:** what one PE per wave does for about 400 extra µs, only with PP and only in the first 0.75 s. Candidates within PP:
  - the shared per-process buffers being sent by whichever PE takes them at a GVT update, while every PE of the process tries at once (all PEs leave the window edge together at the start);
  - the first sends to each destination process.

  The per-PE records (`--gvt-trace=4`) with htram's flush and the GVT-result step timed per wave would split it. That is a small change, worth making only if PP stays the setting at σ ≥ 2,000 after job E.

### §158 · Does PP's start-up ramp follow glibc's handling of PP's per-send buffers? TLB shootdowns and two malloc settings (design, 2026-10-29; written before any runs)

> **Status: design.**
> - **Build:** Charades `episode-diag` (this commit adds TLB-shootdown, function-call and rescheduling interrupts from `/proc/interrupts` to `hfi_sampler.py`; the binary is unchanged).
> - **Job A16:** `$WORK/charades-runs/alloc58.slurm` (16 nodes, skx-dev, `-x c455-081`).

**Why.** Section 157 found that one random PE per wave is about 400 µs late in PP's first 0.75 s, with few page faults. One thing PP does that WPs does not: after every send of a process's shared buffer toward a destination process, the sending PE allocates a new one at htram's largest size. That is `BUFSIZE + LOCAL_BUFSIZE` = 16,400 items of about 72 B, about 1.2 MB, to carry about 3 KB (49 events a message at σ 2,000). At 16 nodes that is roughly 10 GB/s of allocation per process.
- How glibc serves this changes as a run starts. Blocks over the mmap threshold (128 KB at first) are mapped and unmapped each time, until a free raises the threshold; arena heaps then grow, and are trimmed when the top's free space passes the trim threshold.
- Unmapping or trimming touched memory interrupts every core running the process with a TLB shootdown. That would show as kernel time spread over all PEs with few faults, which is what E16 measured at the start: 5.8 against 1.7 µs of kernel time per PE per wave, about 3 ms per wave over 736 PEs.
- Sections 80 and 92 already found PP sensitive to allocation size (1.07–1.14×) and to trimming (1.055–1.083×), unexplained.

**Runs** (σ 2,000, W 400, end time 2,048,000, untraced, 3 reps interleaved, the sampler on every node):
- PP 512 (as now);
- WPs 512;
- PP 512 with `GLIBC_TUNABLES=glibc.malloc.mmap_threshold=33554432` (1.2 MB blocks come from the heap from the start; the threshold no longer moves);
- PP 512 with no trimming (`glibc.malloc.trim_threshold=1073741824:glibc.malloc.top_pad=67108864`; this also pins the mmap threshold at 128 KB, so every 1.2 MB block is mapped and unmapped).

This is a diagnosis; neither setting is a candidate for the paper's launch (section 140: glibc settings stay out of launches).

**Predictions:**
- A1. If allocator churn causes the ramp, TLB shootdowns per second over all nodes in PP 512's first 0.75 s are at least 3× its rate at 2–5 s, and at least 3× WPs 512's in the same window.
- A2. Then at least one of the two settings cuts PP's time lost in the first 2 s from about 0.36 s to at most 0.15 s, and its start-up TLB-shootdown rate falls with it.
- A3. If shootdowns do not rise at PP's start and neither setting moves the ramp, the allocator is not the cause, and the next step is section 157's per-wave timing of htram's flushes and the GVT-result step.

**What follows:** if A1 and A2 hold, the fix is in htram, not in the launch. PP would allocate each new shared buffer at its current limit (512 + 16 items, 38 KB) instead of htram's largest size, or reuse buffers, so no run depends on glibc's thresholds.

### §159 · Job A16 results: PP's start-up ramp is not the allocator (no TLB-shootdown rise, neither malloc setting removes it); no trimming makes PP 1.074× faster in steady state; WPs 512 is 1.047× PP 512 at 16 nodes (2026-10-29; skx-dev batch job 3660356, 16 nodes)

> **Status: current.** Design and predictions in section 158.
> - **Allocation:** c454-002 to c455-103 (16 nodes); 23:25–23:30. All 12 runs ok, with equal committed counts.
> - **Data:** `~/charades-data/scale32/episodes/a16_j3660356/` (`summary.txt` from `a16_summary.py`).
> - **Sampler gap:** the sampler's final flush was lost when its step was stopped, so the counters cover rep 1 and part of rep 2 (written every 60 s). The sampler should write more often; fixed for the next job.

**σ 2,000, W 400, 16 nodes** (median of 3 reps; M ev/s and ÷ PP 512, higher is better; lost time and interrupt rates, lower is better; interrupts summed over all 16 nodes, from rep 1 and the reps with data):

| arm | M ev/s | ÷ PP 512 | lost in the first 2 s (s) | TLB shootdowns/s, first 0.75 s / 2–5 s | function-call interrupts/s, same windows |
|---|---|---|---|---|---|
| PP 512 | 482.9 | 1.000 | 0.31 (0.30–0.33) | 9,100 / 20,100–21,000 | 10,000–10,600 / 21,000–22,200 |
| WPs 512 | 505.7 | **1.047** | **0.06** | 9,000 / 19,800–20,200 | 9,900–10,400 / 20,900–21,300 |
| PP 512, mmap threshold fixed at 32 MB | 488.1 | 1.011 | 0.37 | 7,700–7,800 / 24,400–25,100 | 8,700 / 25,600–26,000 |
| PP 512, no trimming | **518.6** | **1.074** | 0.26 | 8,700 / 23,600 | 10,300 / 24,500 |

- **A1 wrong.** TLB shootdowns per second at PP's start are lower than in its steady state (0.45×), and the same as WPs' (9,100 against 9,000). PP's 1.2 MB allocations cause no extra shootdowns.
- **A2 wrong.**
  - With the mmap threshold fixed, PP still loses 0.37 s.
  - With no trimming it loses 0.26 s, a little less than 0.31 s, but nowhere near the 0.15 s that would make the allocator the cause.
- **A3 right: the allocator is not the cause of the ramp.** Sections 155–158 leave one random PE per wave late by about 400 µs, in user space, only with PP, only in the first 0.75 s; why is still open.
- **Steady state, two findings for the settings:**
  - **No trimming makes PP 1.074× faster** (section 92 found 1.055–1.083× at 4 nodes). It is not shootdowns (the same rates), and fixing the mmap threshold gives only 1.011×. glibc settings stay out of the launch (section 140), but an htram change that makes PP's allocations cheaper could capture the same gain. `--agg-pp-alloc=1` (htram branch `pp-alloc-limit`, Charades `episode-diag`: shared buffers allocated at their own limit, about 38 KB instead of about 1.2 MB; Mac change tier with 10 repeats 720/720) is a candidate. Section 80 found larger PP allocations faster, so only a measurement can tell.
  - **WPs 512 is 1.047× PP 512** at σ 2,000 on 16 nodes (1.03× in job R16). PP was chosen for σ ≥ 2,000 in section 140; at 16 nodes WPs is now ahead and has no ramp. The choice must be checked at 32 nodes, where WPs' per-PE buffers fill more slowly.

### §160 · PP's shared buffers at their own limit (`--agg-pp-alloc=1`), and PP against WPs, on the four PP workloads at 16 nodes (design, 2026-10-29; written before any runs)

> **Status: design.**
> - **Build:** Charades `episode-diag` 02f2b91 (with `--agg-pp-alloc`), htram `pp-alloc-limit` 42d347f (`pdes` plus the option), Reconverse and the launch as in A2r. A new tree `$WORK/charades-alloc` built against `$WORK/htram-alloc`; `charades-lprb`, which job E uses, is unchanged.
> - **Job P16:** `$WORK/charades-runs/pp60.slurm` (16 nodes, skx-dev, `-x c455-081`).

**Why.**
- Section 159 found no trimming makes PP 512 1.074× faster at σ 2,000, with no rise in TLB shootdowns. One allocation pattern is PP's alone: a new shared buffer at htram's largest size, about 1.2 MB, at every send, for about 3 KB of events.
- `--agg-pp-alloc=1` allocates it at its own limit instead: 528 items, 38 KB, for PP 512; 2,064 items, 149 KB, for PP 2,048. Without glibc settings, it would remove whatever that pattern costs.
- Section 80 found larger PP allocations faster (147 KB against 37 KB, 1.07–1.14×), so the direction is not known in advance.
- WPs 512 was 1.03–1.047× PP 512 at σ 2,000 (sections 157 and 159). That needs checking on the other PP workloads.

**Runs** (16 nodes, W 400, end time 2,048,000, untraced, 3 reps interleaved). σ 100 and σ 1,000 with PP 2,048, and σ 2,000 and σ 4,000 with PP 512 (the settings in use), each three ways: PP as now; PP with `--agg-pp-alloc=1`; WPs 512.

**Predictions:**
- P1. If PP's steady-state cost comes from glibc's handling of its 1.2 MB per-send buffers, `--agg-pp-alloc=1` is at least 1.04× PP at σ 2,000 and σ 4,000. If section 80's "larger allocations are faster" holds instead, it is at most 0.97×.
- P2. The start-up ramp does not change with it (section 159: not the allocator): σ 2,000 still loses at least 0.25 s in its first 2 s.
- P3. WPs 512 is at least 1.0× PP 512 at σ 2,000 and σ 4,000, and PP 2,048 stays ahead of WPs 512 at σ 100 and σ 1,000 (section 140).

**What follows:**
- If P1's gain holds, `--agg-pp-alloc=1` becomes the default and is checked at 32 nodes.
- If WPs leads at σ ≥ 2,000 at 32 nodes too, the paper's setting for those workloads changes. Every workload's setting stays the same at every node count.

### §161 · Job P16 results: allocating PP's shared buffers at their own limit removes most of PP's start-up ramp and gains 1.05× at σ 2,000; PP with it leads WPs 512 on all four PP workloads (2026-10-29 to 30; skx-dev batch job 3660590, 16 nodes)

> **Status: current.** Design and predictions in section 160. 16 nodes, 23:59 (2026-10-29) to 00:06. Gate 18/18 (the new configs and the PP base, on 2 nodes, psm2). All 36 runs ok, with committed counts equal across the three arms of each workload. Data `~/charades-data/scale32/episodes/p16_j3660590/` (`summary.txt` from `p16_summary.py`).

**16 nodes, W 400** (median of 3 reps; M ev/s and ÷ PP, higher is better; time lost in the first 2 s, lower is better):

| workload (PP setting) | PP | PP, `--agg-pp-alloc=1` | ÷ PP | WPs 512 | ÷ PP | lost in the first 2 s (s): PP / alloc / WPs |
|---|---|---|---|---|---|---|
| σ 100 (PP 2,048) | 671.5 | 665.9 | 0.992 | 646.7 | 0.963 | 0.07 / 0.06 / 0.06 |
| σ 1,000 (PP 2,048) | 565.7 | 570.1 | 1.008 | 555.6 | 0.982 | 0.11 / 0.13 / 0.09 |
| σ 2,000 (PP 512) | 490.4 | **514.8** | **1.050** | 506.8 | 1.033 | **0.40 / 0.14** / 0.09 |
| σ 4,000 (PP 512) | 463.5 | 470.2 | 1.015 | 450.6 | 0.972 | **0.33 / 0.13** / 0.09 |

(σ 100 with the option: reps 633.9, 669.1, 665.9; the first is the outlier.)

- **P1 right at σ 2,000 (1.050×), wrong at σ 4,000 (1.015×, predicted at least 1.04).** At σ 100 and σ 1,000 (PP 2,048, where the buffer drops from 1.2 MB to 149 KB) the change is within the reps' spread.
- **P2 wrong, usefully: the ramp mostly goes.** σ 2,000 loses 0.14 s instead of 0.40 s, and σ 4,000 0.13 s instead of 0.33 s, near WPs' 0.09 s.
  - So PP's per-send 1.2 MB buffers do cause the ramp, although neither glibc setting removed it and TLB shootdowns did not rise (section 159).
  - What in the kernel or allocator makes many large buffers costly only in the first 0.75 s is not identified. One candidate is the per-thread heaps growing while every PE allocates at once (heap growth takes the process's memory-map lock).
  - The perturbation moved the cost by the amount it had to: 0.26 of σ 2,000's 0.31 s excess over WPs.
- **P3 half right.** WPs 512 is 1.033× PP 512 at σ 2,000 but 0.972× at σ 4,000. PP 2,048 stays ahead of WPs at σ 100 and σ 1,000. **With `--agg-pp-alloc=1`, PP is ahead of WPs on all four workloads** (σ 2,000: 514.8 against 506.8). So the settings in use stay, with the option on.

**What follows.** `--agg-pp-alloc=1` becomes the default:
- it is 1.050× and 1.015× where PP 512 is used, level where PP 2,048 is used, and removes most of the ramp;
- it needs htram `pp-alloc-limit` merged into `pdes`;
- it gets checked at 32 nodes in the next 32-node job.

### §222 · F2 and F3 on PHOLD and traffic, and ROSS's window on traffic and dragonfly (job ABL design, 2026-11-04; written before any runs)

> **Status: design.** PAPER.md item 4. User decision 2026-11-04: run F2 (aggregation ablation) and F3 (the PADS'19 hold and eager aggregation as baselines) on PHOLD and traffic only, and add ROSS's optimism window (`--max-opt-lookahead`) on traffic and dragonfly. F4 is not part of this job.
> - **Code:** round 3's engine (charades b0b4ed4 code; tree `charades-abl` at the commit of this section, which adds only statistics and an `AGG_POLICY` knob to `ctl_sweep.sh`), on `charm-pads-perf`, the paper's runtime.
> - **Mac checks on this code:** the hold (`bucket_hold`, `bucket_hold_early`) on PHOLD and traffic, 24/24 and then 128/128 with 8 repeats at 2 × 2 and 2 × 4; eager aggregation (`agg_bucket_pp`, `agg_bucket_wps`) 72/72 with 3 repeats.
>
> **The `--agg-scope=1` arm is dropped** (correction in section 187). The local fast path is on by default. It hands every event for another PE of the same process over by pointer, with direct sends and with htram alike. So htram only ever carries events to other processes, and `--agg-scope=1` changes nothing. F2's direct-against-htram comparison is therefore already a comparison of how events to other processes travel.
>
> **Script:** `$WORK/charades-runs/abl222.slurm` (copy in `~/charades-data/abl/`), skx-dev, 16 nodes. Launch as in F1 and F5 (2 × 23, pemap, 23 LCI devices, `+mempool_remote_free`, `numactl --localalloc`, `--blocked-time=1 --ctl-log=1 --commit-digest=1`). 2 reps, with arm order reversed in rep 2.
> 1. **Gate**, 2 nodes: Charades' change tier on Simple PHOLD and traffic with `bucket_hold`, `agg_bucket_pp`, `agg_ctl_measured_fast_bucket_pp` and `bucket_window`.
> 2. **4 nodes**, groups side by side:
>    - nodes 0–3: σ 100, then traffic;
>    - nodes 4–7: σ 2,000, then uniform;
>    - nodes 8–11: ROSS's window arms and Charades' controller at 4 nodes;
>    - node 12: the same at 1 node.
> 3. **16 nodes:** the four workloads.
>
> **Workloads** (paper sizes):
> - PHOLD, lookahead 100, mean 1,000, END 2,048,000, 128 LPs per PE, 16 per chare, buckets of 8: σ 100 (htram PP 2,048), σ 2,000 (PP 512), uniform (WPs 512).
> - Traffic: 64-wide grid, 16 cars per intersection, trip radius 3, END 12,000,000, 64 LPs per PE, buckets of 8, htram PP 2,048.
>
> **Arms per workload and rep** (fixed windows A and B: 250 and 400 on PHOLD, 500 and 1,000 on traffic):
>
> | figure | arm | transport | window |
> |---|---|---|---|
> | F2 | direct | direct sends | A, B, the controller |
> | F2, F3 | eager | htram, eager flush (`--agg-policy=0`: idle PEs and GVT updates flush everything) | A, B, the controller |
> | F2 | deadline | htram, deadline flush (`--agg-policy=1`, the default) | A, B, the controller |
> | F3 | PADS'19 hold | direct sends, `--gvt-adaptive-buckets=1`, cutoff K buckets (`--gvt-reserve-buckets`) | none (W 0), as in PADS'19 |
>
> - The hold's cutoffs are K = 8, 32 and 128 buckets on PHOLD (64, 256 and 1,024 time units) and 16, 64 and 256 on traffic (128, 512 and 2,048), around each workload's best W. A held event is released when GVT reaches its bucket.
> - The hold decision comes before the fast path, so it covers every event sent to another chare, as in PADS'19.
> - The controller is the frozen rule (`--ctl=3`, bracketed).
>
> **ROSS's window** at 1 and 4 nodes, 2 reps: optimistic ROSS at its best F5 setting (traffic batch 64 / GVT interval 64; dragonfly batch 2 / GVT 64), without a window and with `--max-opt-lookahead` 250, 500, 1,000 and 2,000 (traffic) or 5,000, 10,000, 20,000 and 40,000 ps (dragonfly). Charades' controller runs alongside for the ratio: traffic (PP 2,048) and dragonfly (WPs 512, buckets of 1,000 ps) at 1 node, and dragonfly at 4 nodes; traffic at 4 nodes comes from the ablation's deadline arm. Paper sizes: traffic END 12,000,000; dragonfly arrival 500 ns, generating 300,000 ns, END 310,000,000 ps.
>
> **Measures:** M committed ev/s; for htram, events per message and messages per committed event; rolled-back events; blocked share; for the hold, held events.
>
> **Predictions:**
> - **AB1:** within each workload and node count, every arm commits the same events with the same digest, the hold included.
> - **AB2:** deadline htram ÷ direct sends, each at its better fixed W, at 4 nodes: σ 100 1.1–1.6 (the fast path took most of htram's old 2.3×); σ 2,000 2.0–3.5; uniform 2.5–4.5; traffic 1.3–1.5. At 16 nodes at least the 4-node value on σ 2,000 and uniform.
> - **AB3:** eager ÷ deadline at the same W is 0.70–0.95 on σ 2,000 and uniform, with at least 1.5× fewer events per message. On σ 100 and traffic, where few events leave the process, 0.95–1.05.
> - **AB4:** in each transport the controller is 0.90–1.05 of that transport's better fixed W.
> - **AB5:** the hold's best K is at most 0.95 of direct sends at their better W on every workload, and below 0.5 of deadline htram on σ 2,000 and uniform. Its best K differs between PHOLD and traffic in time units, which is why PADS'19 tuned the cutoff per model. Some K at σ 2,000 or uniform may fail or hit the cap, since nothing bounds same-chare events.
> - **AB6:** ROSS with its best window is 0.95–1.30× ROSS without a window, on both applications. Charades ÷ ROSS stays at least 1.5 on traffic and at least 3 on dragonfly.

### §223 · ABL results: htram's deadline flush is 2.1–3.3× direct sends on PHOLD and 1.4× on traffic; eager flush loses up to 1.6× on uniform at 16 nodes; the F3 hold arms used the wrong release rule and are rerun; ROSS's window raises ROSS 1.13–1.48×, and Charades ÷ ROSS becomes 1.75–1.90 (traffic) and 3.0–3.2 (dragonfly) (2026-11-04; skx-dev batch job 3682372, 16 nodes)

> **Status: current (F2, ROSS's window) / superseded (F3 hold arms, see below).** Design and predictions in section 222. 16 nodes, 78 minutes; gate 48/48. Data, `abl_summary.py` and `abl_summary.txt` in `~/charades-data/abl/`.
> - **Counts:** within every workload and node count, all 18 runs that finished commit the same events with the same digest. ROSS commits the same counts as Charades on traffic and dragonfly at 1 and 4 nodes.
> - **All 48 hold runs hit the 90 s cap.**

**F2: deadline ÷ direct sends and eager ÷ deadline** (rates are M committed ev/s, mean of 2 reps; ratios are higher-is-better for the first arm named):

| workload | nodes | direct, better fixed W | eager, better fixed W | deadline, better fixed W | **deadline ÷ direct** | eager ÷ deadline at W A / W B | events per message, eager / deadline |
|---|---|---|---|---|---|---|---|
| σ 100 | 4 | 95.4 | 197.3 | 201.2 | **2.11** | 0.98 / 1.00 | 10.7 / 39.3 |
| σ 2,000 | 4 | 53.9 | 138.8 | 153.3 | **2.85** | 0.87 / 0.94 | 16.2 / 73.1 |
| uniform | 4 | 40.0 | 120.2 | 132.2 | **3.31** | 0.91 / 0.96 | 14.5 / 33.2 |
| traffic | 4 | 196.9 | 282.9 | 284.1 | **1.44** | 0.98 / 1.09 | 10.3 / 11.8 |
| σ 100 | 16 | 368.5 | 779.9 | 810.7 | **2.20** | 0.97 / 0.96 | 11.9 / 35.6 |
| σ 2,000 | 16 | 210.7 | 552.5 | 603.6 | **2.87** | 0.89 / 0.92 | 17.0 / 59.4 |
| uniform | 16 | 145.0 | 242.3 | 384.2 | **2.65** | **0.61 / 0.63** | 4.2 / 12.6 |
| traffic | 16 | 777.7 | 1,172.7 | 1,063.6 | **1.37** | 1.00 / 1.12 | 10.9 / 12.3 |

(W A / W B are 250 / 400 on PHOLD and 500 / 1,000 on traffic.)
- **Aggregation pays even at σ 100.** 2.1–2.2× there, although the fast path already keeps same-process events out of htram. Sending the few events that go to other processes one message each costs direct sends half their rate.
- **Deadline flush packs 2.3–4.5× more events per message than eager on PHOLD.** It is faster by up to 1.6× on uniform at 16 nodes, where eager sends 4.2 events per message.
- **On σ 100 and traffic the two flush policies are level.** On traffic at 16 nodes eager is 1.10× deadline, comparing each at its better fixed W.
- **The controller holds in every transport:** 0.94–1.08 of the better fixed W in all 24 cells (deadline 0.94–1.04, eager 0.96–1.08, direct 0.96–0.99).
- **Controllers against controllers** (the paper's configuration): deadline ÷ direct is 2.06 / 2.83 / 3.30 / 1.39 at 4 nodes and 2.16 / 2.85 / 2.68 / 1.49 at 16 nodes (σ 100 / σ 2,000 / uniform / traffic).

**F3: the hold arms used the wrong release rule.**
- The design released a held event only when GVT reached its bucket (`--gvt-clear-buckets=1`, the code's default). PADS'19 releases all held events at the next GVT computation ("for most models we release all events the next time a GVT is computed", Section 5): `--gvt-clear-buckets=0 --gvt-clear-lag=0`. It uses cutoffs of 2, 4, 8 and 16 buckets and no window.
- **The arms in this job are therefore not the PADS'19 baseline**, and all of them hit the 90 s cap.
- **Follow-up on the Mac** (PHOLD σ 100, 2 × 4 PEs, 1,024 LPs, END 256,000; M committed ev/s, higher is better):

| arm | M ev/s | events rolled back | events held | held events cancelled in the sender |
|---|---|---|---|---|
| W 250 | 0.53 | 77 | — | — |
| no window | 0.47 | 5.44 M | — | — |
| no window + hold K 32, release when GVT reaches the bucket (this job's rule) | 0.07 | 5.69 M | 8.37 M | 5.25 M |
| no window + PADS'19 hold, cutoff 2 / 8 / 16 | 0.08 / 0.09 / 0.09 | 34.7–35.2 M | 36.0–36.5 M | 20.0–20.3 M |
| W 250 + hold K 32, release when GVT reaches the bucket | 0.19 | 2.06 M | 4.98 M | 1.86 M |
| W 250 + PADS'19 hold, cutoff 8 | 0.52 | 691 | 3.67 M | 333 |

  - Released at the bucket, a held event reaches a receiver that has already run past it, so it arrives as a straggler. With W 250 that costs 2.8×.
  - Released at the next GVT (PADS'19), the hold beside a window changes nothing (0.52 against 0.53).
  - Without a window it is 5× slower than no window at all, at every cutoff. Receivers run ahead unbounded, and held events arrive one GVT period late.
- F3 needs a rerun with PADS'19's rule (no window and no hold; PADS'19's cutoffs without a window; the hold beside the best W), at full scale.
- **Correction (2026-11-04, section 224):** this table ran at 2 × 4 PEs. Its hold arms run with the local fast path off (the hold turns it off), while its no-window and W 250 rows have it on. Its cutoffs of 2–16 buckets of 8 (16–128 time units, against a mean delay of 1,000) hold nearly every remote event. The rerun scales the cutoff to the mean delay and adds no hold with the fast path off. At 2 × 2, the hold without a window is 4–9× slower than that at cutoffs up to 2 mean delays, and level with it at 4 and 8.

**ROSS's optimism window** (`--max-opt-lookahead`; ROSS optimistic at its best F5 setting; M committed ev/s, mean of 2 reps):

| application | nodes | none | 250 / 5,000 | 500 / 10,000 | 1,000 / 20,000 | 2,000 / 40,000 | best ÷ none | Charades controller | **Charades ÷ ROSS's best** |
|---|---|---|---|---|---|---|---|---|---|
| traffic | 1 | 35.8 | 35.8 | 39.4 | **40.5** | 39.9 | 1.13 | 70.9 | **1.75** |
| traffic | 4 | 117.8 | 121.8 | 135.4 | 140.1 | **140.1** | 1.19 | 266.3 | **1.90** |
| dragonfly (ps) | 1 | 10.0 | **13.5** | 10.0 | 10.0 | 10.0 | 1.35 | 43.2 | **3.20** |
| dragonfly (ps) | 4 | 27.9 | **41.3** | 27.9 | 27.8 | 27.9 | 1.48 | 123.7 | **3.00** |

- **The window helps ROSS:** 1.13–1.19× on traffic and 1.35–1.48× on dragonfly.
- **On dragonfly the effect is all or nothing.** W 5,000 ps raises ROSS's efficiency from 63–71% to 94–96%, and 10,000 and above change nothing. The best value is the grid's smallest, so a smaller one may be better still. The dragonfly ratio is provisional until the grid is extended below 5,000 (2,500, 1,250).
- **F5's Charades ÷ ROSS was against ROSS without a window** (3.7–4.0 on dragonfly, 1.8–2.2 on traffic). With it, at 1 and 4 nodes, the ratio is 3.0–3.2 on dragonfly and 1.75–1.90 on traffic.

**Predictions (section 222):**
- **AB1 right** for every arm that finished.
- **AB2 half:**
  - σ 2,000 (2.85), uniform (3.31) and traffic (1.44) are in range;
  - σ 100 is 2.11, not 1.1–1.6: the fast path did not take htram's gain away;
  - from 4 to 16 nodes σ 2,000 holds (2.87), but uniform falls (3.31 → 2.65).
- **AB3 mostly right:**
  - eager ÷ deadline is 0.87–0.94 on σ 2,000;
  - on uniform it is 0.91–0.96 at 4 nodes and 0.61–0.63 at 16, below the predicted range;
  - deadline packs at least 1.5× more events per message on PHOLD;
  - level on σ 100 and traffic, except eager's 1.12 at traffic's W B.
- **AB4 right in 23 of 24 cells;** eager uniform at 16 nodes is 1.08, above the range.
- **AB5 not tested** (wrong release rule; rerun).
- **AB6 half:** the window gains 1.13–1.19 on traffic (in range) and 1.35–1.48 on dragonfly (above it). Charades ÷ ROSS stays at least 1.5 on traffic and at least 3 on dragonfly (3.00 at 4 nodes, the edge).

### §256 · Bundling at 32 nodes on the remote-heavy end, and fixed windows past F1's and F5's grids (job AG32 design, 2026-11-07; written before any runs)

> **Status: design (results in section 257).**
> - **User decision 2026-11-07:** do the free analysis (section 255) and run 1, and add the wider fixed windows to it.
> - **Submitted 2026-11-07:** 3692756 (skx, 32 nodes); it ran 2026-11-08 06:03–07:21.
> - **Script:** `$WORK/charades-runs/ag32_256.slurm` (copy in `~/charades-data/f1/`). It runs on skx (32 nodes exceeds skx-dev), limit 2:30, about 70–80 minutes, `-x c455-081`.
> - **Code:** tree `charades-r5` (85a2aad), as F1. Charades only: the other engines' 32-node rates are in sections 252–253.

**Why.**
- **Part A:** on uniform, F1's 32-node runs carried 8.4 events per htram message, against 102 at 4 nodes (section 255). Bundling's gain over direct sends was measured only at 4 and 16 nodes (job ABL, section 223: uniform 3.31 and 2.65). At 32 nodes it is unknown, and claim 1 needs it.
- **Part B:** at 32 nodes F1's and F5's best fixed W was the grid's widest (W 400 at lookahead 100, traffic W 1,000). On lookahead 10 the controller beat both fixed W (1.05–1.07), which points to a best W between the grid points.

**Runs** (32 nodes, 5 reps; per rep part A then part B, with workload and arm order reversed in even reps; one warm-up run first):
- **Part A:** uniform and σ 4,000 × {direct sends, PP 512, PP 2,048, WPs 512, WPs 2,048} × {W 300, 400, 500, 600, the controller}. That is 50 runs per rep.
- **Part B:**
  - σ 100, σ 500, σ 1,000 (PP 2,048) and σ 2,000 (PP 512): W 400 / 500 / 600 and the controller;
  - lookahead 10 σ 500 (PP 2,048): W 50 / 75 / 100 / 150 and the controller;
  - lookahead 10 σ 2,000 (WPs 512): W 50 / 75 / 100 and the controller;
  - traffic (PP 2,048; F5's size): W 1,000 / 1,500 / 2,000 and the controller.
  - That is 29 runs per rep.
- **Gate:** F1's change-tier set on 2 nodes, plus Traffic.

**Flags per arm** (from a stub run with a fake `srun`: 396 commands, as planned). Every run carries the paper launch only:
- `+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free` under `numactl --localalloc`, `srun -c 24`, 2 × 23 PEs per node;
- config `bucket`, `--gvt-bucket-size=8`.

| arm | Charades flags beyond the launch | why |
|---|---|---|
| fixed W, bundled | `--optimism-window=W --aggregation=1 --agg-mode=M --agg-buffer=B --agg-policy=1 --agg-horizon-margin=8` | the window and the htram setting under test |
| fixed W, direct sends | `--optimism-window=W` | no aggregation flags; the same-process fast path stays on, as in every run |
| controller | `--ctl=3 --ctl-bracket=1`, plus the htram flags when bundled | the frozen controller |
| warm-up | W 300, σ 100, PP 2,048, end 512,000 | first-run effects; not counted |

No log, stats, trace or digest flag appears in any command. PHOLD runs carry no digest, as in F1.

**Predictions:**
- **AG-1. Counts:** one committed count per workload across all arms and reps, equal to F1's 32-node counts (traffic: F5-32b's).
- **AG-2. Bundling's gain at 32 nodes:** the best htram run ÷ the best direct-send run (each over W 300–600 and the controller, medians) is 1.5–2.5 on uniform and 2.0–3.0 on σ 4,000.
- **AG-3. Message size on uniform:**
  - Buffer 2,048 changes events per message by less than 20% against 512, since flushes are driven by the deadline, not by full buffers.
  - W 600 carries at least 1.3× W 300's events per message.
  - The best PP and WPs runs are within 10% of each other in rate.
- **AG-4. Best fixed W:** 400–500 for htram on uniform and σ 4,000. Direct sends' best W is no wider than htram's.
- **AG-5. Wider windows elsewhere:**
  - On σ 100–2,000, W 500 is within ±3% of W 400, and W 600 is below W 500.
  - On traffic, W 1,500 is within ±3% of W 1,000, and W 2,000 is lower.
  - On lookahead 10, W 75 is the best fixed W on both workloads, by at least 2% over W 50 and W 100.
- **AG-6. The controller ÷ the best fixed W over the widened grid** is 0.93–1.02 per cell (F1-32 on its grid: 0.94–1.07).
- **AG-7. Spread between reps:** at most 1.15 for every arm, apart from at most one slow rep per arm.

**What follows:**
- **If AG-2 holds,** claim 1 quotes bundling's gain at 32 nodes on the remote-heavy end. If it falls well below 1.5 on uniform, the paper says bundling's advantage fades for all-to-all traffic at scale.
- **If a setting raises uniform's message size and rate by more than 5%,** F1's uniform cell at 32 nodes gets that setting in a later job.
- **If a wider W beats F1's or F5's best fixed W by more than 3%,** those tables' "best fixed W" and the controller ratios take the new value.

### §257 · AG32 results: at 32 nodes bundling is 2.29× direct sends on uniform and 3.14× on σ 4,000; W 400 and traffic's W 1,000 stay the best fixed windows; on lookahead 10, W 75 is 8–15% faster than W 50 and W 100 (2026-11-08; skx batch job 3692756, 32 nodes)

> **Status: current.** Design and predictions in section 256.
> - **Job:** 32 nodes, 78 minutes (2026-11-08 06:03–07:21), gate 72/72. All 395 timing runs and the warm-up finished `ok`.
> - **Data:** `~/charades-data/f1/ag32_256/j3692756` (digests and per-round GVT files not copied). `~/charades-data/f1/ag32_257.py` writes `ag32_256/ag32_257_summary.txt`.
> - **Counts:** every run commits its workload's count from F1-32 (traffic: F5-32b's), whatever the transport, htram setting or window.
> - **Against F1-32 and F5-32b:** the 25 arms those jobs also ran agree within 0.95–1.04 (this job's median ÷ theirs), apart from the lookahead 10 σ 500 controller (0.90; two slow reps, below). σ 100–2,000 ran 1–4% faster here; uniform and traffic were within 2%.

**Part A: bundling on the remote-heavy end** (M committed ev/s, median of 5 reps, higher is better; bold: the row's best):

| workload | transport | W 300 | W 400 | W 500 | W 600 | controller | controller's mean W |
|---|---|---|---|---|---|---|---|
| uniform | direct sends | **280.4** | 279.4 | 269.3 | 276.3 | 270.1 | 351 |
| uniform | PP 512 | 504.7 | 515.4 | 499.9 | 468.3 | **531.0** | 390 |
| uniform | PP 2,048 | 504.6 | 516.9 | 489.6 | 470.6 | **525.1** | 396 |
| uniform | WPs 512 | 625.3 | **643.0** | 613.4 | 576.7 | 627.6 | 406 |
| uniform | WPs 2,048 | 625.3 | **638.9** | 608.5 | 574.0 | 632.7 | 413 |
| σ 4,000 | direct sends | **344.6** | 344.4 | 339.3 | 334.8 | 329.8 | 356 |
| σ 4,000 | PP 512 | **1,080.6** | 1,060.6 | 1,027.3 | 935.7 | **1,080.6** | 413 |
| σ 4,000 | PP 2,048 | 862.1 | 923.1 | **946.5** | 901.7 | 895.4 | 560 |
| σ 4,000 | WPs 512 | 1,012.8 | **1,049.3** | 960.4 | 874.1 | 1,030.3 | 415 |
| σ 4,000 | WPs 2,048 | 1,012.1 | **1,049.2** | 960.0 | 889.3 | 1,013.1 | 409 |

**htram events per message** (median of 5 reps; higher means fewer messages):

| workload | htram setting | W 300 | W 400 | W 500 | W 600 | controller |
|---|---|---|---|---|---|---|
| uniform | PP 512 | 8.6 | 8.3 | 8.4 | 8.5 | 8.3 |
| uniform | PP 2,048 | 8.6 | 8.3 | 8.4 | 8.5 | 8.3 |
| uniform | WPs 512 | 8.6 | 8.2 | 8.3 | 8.4 | 8.2 |
| uniform | WPs 2,048 | 8.6 | 8.2 | 8.3 | 8.4 | 8.2 |
| σ 4,000 | PP 512 | 57.6 | 49.5 | 50.5 | 53.8 | 48.8 |
| σ 4,000 | PP 2,048 | 58.9 | 53.2 | 44.1 | 38.5 | 36.0 |
| σ 4,000 | WPs 512 | 30.2 | 28.4 | 27.8 | 28.2 | 27.3 |
| σ 4,000 | WPs 2,048 | 30.3 | 28.3 | 27.3 | 27.7 | 27.4 |

**Bundling's gain by node count** (htram ÷ direct sends, higher is better for htram; 4 and 16 nodes from job ABL, section 223, which ran W 250/400 with diagnostics on both sides; 32 nodes from this job, W 300–600 without them; uniform with WPs 512, σ 2,000 and σ 4,000 with PP 512):

| workload | comparison | 4 nodes | 16 nodes | 32 nodes |
|---|---|---|---|---|
| uniform | each at its best fixed W | 3.31 | 2.65 | 2.29 |
| uniform | controller against controller | 3.30 | 2.68 | 2.32 |
| uniform | htram events per message (F1's controller runs, section 255; this job) | 102 | 14.5 | 8.2 |
| σ 2,000 | each at its best fixed W | 2.85 | 2.87 | — |
| σ 4,000 | each at its best fixed W | — | — | 3.14 |
| σ 4,000 | controller against controller | — | — | 3.28 |

- **Bundling still pays at 32 nodes:**
  - On uniform, htram's messages carry 8 events, and the best htram run is 2.29× the best direct-send run (WPs 512 at W 400, against direct sends at W 300); controller against controller, 2.32.
  - On σ 4,000, with 27–59 events per message, the gain is 3.14 (3.28 controller against controller).
- **On uniform the gain shrinks with node count but stays above 2:** 3.31 → 2.65 → 2.29 from 4 to 32 nodes, while the messages shrink from 102 to 8 events.
- **Neither the buffer nor the window changes uniform's message size:**
  - Buffer 2,048 carries the same events per message as 512 (0.99–1.00 in every arm, both modes), and W 600 the same as W 300 (0.98–1.00).
  - On σ 4,000 a wider W gives smaller messages (W 600 ÷ W 300: 0.65–0.93).
  - What sets 8 events per message on uniform at 32 nodes is not tested here.
- **WPs is 1.21× PP on uniform** (643.0 against 531.0, each at its best arm) at the same message size. On σ 4,000 PP 512 is level with WPs (1.03) with about twice the events per message. F1 already uses the best setting here on each (WPs 512 on uniform, PP 512 on σ 4,000).
- **Direct sends** do best at W 300 on both workloads, but vary by at most 4% over W 300–600.

**Part B: fixed windows past F1's and F5's grids** (the best fixed W with its rate in M committed ev/s, median of 5; every other W as a fraction of it, higher is better; the controller ÷ the best fixed W in this job; uniform and σ 4,000 from part A at F1's htram settings):

| workload | htram | best fixed W (M ev/s) | other W ÷ best | controller ÷ best fixed | controller's mean W |
|---|---|---|---|---|---|
| σ 100 | PP 2,048 | W 400 (1,662.1) | W 500 0.94, W 600 0.83 | 0.96 | 439 |
| σ 500 | PP 2,048 | W 400 (1,460.6) | W 500 0.91, W 600 0.81 | 0.96 | 446 |
| σ 1,000 | PP 2,048 | W 400 (1,372.3) | W 500 0.95, W 600 0.84 | 0.95 | 451 |
| σ 2,000 | PP 512 | W 400 (1,244.2) | W 500 0.92, W 600 0.83 | 0.95 | 418 |
| σ 4,000 | PP 512 | W 300 (1,080.6) | W 400 0.98, W 500 0.95, W 600 0.87 | 1.00 | 413 |
| uniform | WPs 512 | W 400 (643.0) | W 300 0.97, W 500 0.95, W 600 0.90 | 0.98 | 406 |
| lookahead 10, σ 500 | PP 2,048 | W 75 (1,270.9) | W 50 0.93, W 100 0.92, W 150 0.76 | 0.87 | 71 |
| lookahead 10, σ 2,000 | WPs 512 | W 75 (1,047.2) | W 50 0.89, W 100 0.87 | 0.98 | 74 |
| traffic | PP 2,048 | W 1,000 (2,288.1) | W 1,500 0.85, W 2,000 0.70 | 0.99 | 879 |

- **W 400 stays the best fixed W at lookahead 100.** W 500 is 0.91–0.95 of it and W 600 0.81–0.84 (σ 100–2,000); on σ 4,000, W 300 is 2% ahead of W 400. F1's best fixed W there stands, and so do F1-32's controller ratios (0.94–0.98).
- **Traffic's best fixed W stays 1,000:** W 1,500 is 0.85 of it and W 2,000 0.70.
- **On lookahead 10 the best fixed W is 75,** 8–15% faster than W 50 and W 100 (F1's grid).
  - Against it the controller is 0.98 (σ 2,000) and 0.87 (σ 500) in this job.
  - F1-32's controller ÷ this job's W 75 is 0.96 (σ 500) and 0.97 (σ 2,000). These are different jobs; their matched arms agree within ±4%.
  - So F1-32's 1.05–1.07 on lookahead 10 came from the missing W 75.
  - At 1–16 nodes F1's lookahead-10 grid also lacked W 75. The controller was 0.97–1.03 of the grid's best there; W 75 was not run.
- **The controller's slow runs** (reported, not investigated; user decision 2026-11-07):
  - Lookahead 10 σ 500: reps 1 and 3 ran at 790 and 751 M ev/s, against 1,100–1,272 in the other three, with a mean W of 91–99 against 60–71. Fixed W 100 runs at 0.92 of W 75 in this job, so the wider window accounts for little of the loss.
  - In 3 of the 30 controller runs at F1's settings on lookahead 100 (σ 1,000 rep 2, σ 2,000 reps 2 and 5), the mean W was 324–365 instead of 385–463. Those runs were 0.90–0.94 of their cell's median.
  - F1-32's σ 100 cell had the same pattern (W ≈ 290, 0.79–0.80). This job's σ 100 controller stayed at W 435–460 in all five reps.
- **Spread between reps** (fastest ÷ slowest rep):
  - The median is 1.08; 18 of 79 arms are above 1.15.
  - Rep 3 (06:37–06:52) holds 15 of the 28 runs that fell below 0.9 of their arm's median.
  - Without its slowest rep every arm is at 1.15 or less, apart from three on lookahead 10 (σ 500 controller 1.61, σ 500 W 75 1.17, σ 2,000 W 100 1.22).
  - The largest single drops were σ 4,000 WPs 2,048's controller at 0.50 of its median (rep 4) and σ 4,000 PP 512 at W 300 at 0.65 (rep 3).

**Predictions (section 256):**
- **AG-1 right:** one count per workload over 395 runs, equal to F1-32's and F5-32b's.
- **AG-2 right on uniform** (2.29; range 1.5–2.5) **and just above the range on σ 4,000** (3.14; range 2.0–3.0).
- **AG-3 mostly wrong:**
  - buffer 2,048 carries the same events per message as 512 on uniform: right;
  - W 600 carries 0.98–1.00 of W 300's events per message, not at least 1.3×: wrong;
  - PP ÷ WPs at their best is 0.83 on uniform (wrong) and 1.03 on σ 4,000 (right).
- **AG-4 mostly right:** W 400 for every htram setting on uniform; on σ 4,000, W 400 (WPs), W 500 (PP 2,048) and W 300 (PP 512, 2% over W 400). Direct sends' best (W 300) is no wider than htram's on either workload.
- **AG-5 half right:**
  - W 600 below W 500, and traffic's W 2,000 below W 1,500: right.
  - W 500 within ±3% of W 400 (it is 0.91–0.95), and traffic's W 1,500 within ±3% of W 1,000 (0.85): wrong. The window past the best costs more than predicted.
  - W 75 the best fixed W on both lookahead 10 workloads by at least 2% (8–15%): right.
- **AG-6 right in 15 of 17 cells** (0.93–1.02). Outside: lookahead 10 σ 500 (0.87, the two slow controller reps) and uniform PP 512 (1.03).
- **AG-7 wrong:** 18 of 79 arms spread above 1.15. Dropping the slowest rep brings all but three lookahead 10 arms to 1.15 or less.

**What follows:**
- **Claim 1 can quote 32 nodes:** bundling is 2.29× direct sends on uniform and 3.14× on σ 4,000, each at its best fixed W. On uniform it falls from 3.31 at 4 nodes but stays above 2. This job ran without diagnostics; F2's 4- and 16-node runs carried them on both sides.
- **No setting raises uniform's message size or rate by more than 5%,** so F1's uniform cell keeps WPs 512, which is the best setting here.
- **The lookahead 10 rows take W 75 as the best fixed W at 32 nodes.** The front page's 32-node controller range becomes 0.94–0.98 (F1-32's controller; lookahead 10 against this job's W 75). W 400 at lookahead 100 and W 1,000 on traffic stand.
- **Not run:** W 75 on lookahead 10 at 1–16 nodes; what sets uniform's 8 events per message at 32 nodes; why the controller sometimes settles at a narrower W (lookahead 100) or a wider one (lookahead 10 σ 500) in a slow run. (Section 267 answers the second from P64's logs.)

### §267 · Why uniform's messages shrink with node count, and per-process flushing in PP (`--agg-pp-local`): job PL16 (design, 2026-11-09; written before any runs)

> **Status: design (results in section 268).**
> - **User question 2026-11-09:** how can aggregation be improved, and is 2D aggregation worth trying for uniform's shrinking gain at scale? **User decision:** try per-process flushing first (the analysis below; 2D not now).
> - **Code:** htram branch `pp-local` (ca22b77, on `pdes` 42d347f); Charades branch `pp-local` (e12e40d, on main: 85a2aad's code plus the parser fix 0fc842d). The default (`--agg-pp-local=16`) runs the old code paths.
> - **Script:** `~/charades-data/f1/pl267.slurm` (copy in `$WORK/charades-runs/pl267/`); tree `$WORK/charades-ppl`, htram `$WORK/htram-ppl`.
> - **Submitted 2026-11-09:** 3698961 (skx) and 3698962 (skx-dev, `TWIN=3698961`; twin file `$WORK/charades-runs/pl267/pl267.twin`); the copy that starts first cancels the other. 16 nodes, limit 1:30, `-x c455-081`.

**What sets uniform's message size** (offline, from P64's logs, section 265; uniform, rep 1, W 400):

| htram setting | messages (millions) | sent at a GVT update | urgent event | buffer full | idle flush | events per message |
|---|---|---|---|---|---|---|
| WPs 512 | 2,036.5 | 2,023.0 (99.3%) | 13.5 | 0 | 0 | 5.64 |
| PP 512 | 2,028.8 | 2,013.9 (99.3%) | 14.9 | 45 messages | 1,222 messages | 5.67 |

- **How a message is formed now (deadline policy):**
  - Under WPs each PE keeps one buffer per destination process: 127 at 64 nodes (2 processes per node).
  - At each GVT update the PE sends every buffer holding an event that is now due (timestamp below GVT + W + 8), with everything in it.
  - A PE sends about 175 events per GVT update at 64 nodes, so each buffer gains about 1.4 per update and goes out after about four updates, with 5.6 events.
- **PP does the same here:**
  - Each PE first collects events in a 16-event local buffer per destination process, and copies it into the process's shared buffer only when it is full.
  - The GVT-update flush sends the local buffer on its own once it holds a due event. On uniform at 64 nodes that is at about 6 events, so 45 of 2,029 million messages came from a full buffer and the shared buffer was almost never used.
- **Messages shrink more slowly than destinations grow** (htram events per message, F1's controller runs and P64):

| nodes | destination processes | events per message | ratio to the previous row |
|---|---|---|---|
| 4 | 7 | 102 | — |
| 16 | 31 | 14.5 | 0.14 |
| 32 | 63 | 8.2 | 0.57 |
| 64 | 127 | 5.6 | 0.68 |

  - From 32 to 64 nodes the arrivals per buffer halve and messages shrink by 0.68, close to 1/√2 (0.71). A buffer that gains events more slowly also waits longer before its earliest event becomes due.
  - So multiplying a buffer's arrivals by m raises its message size by roughly √m in this range, not m.
- **What a message costs** (least-squares fit, Charades' uniform controller runs at 16, 32 and 64 nodes: 384.5, 627.8 and 980.0 M ev/s at 14.5, 8.3 and 5.55 events per message):
  - PE time per committed event = 1.24 µs + 9.8 µs × (share of events sent to another process ÷ events per message).
  - It fits the three points within about 2%, and predicts σ 4,000 at 32 and 64 nodes (1,080.6 and 2,169.2 M ev/s; 57.6 and 50.2 events per message; 72% sent to another process) within 1.5%, though those runs were not in the fit.
  - At 64 nodes, messages are 59% of uniform's PE time.
- **2D aggregation (estimate; not run):**
  - Assumptions: an 8 × 16 grid of the 128 processes, so 22 first-hop buffers instead of 127, with 105 of 127 destinations two hops away, and 0.35 µs per event for the second hop's receive and insert.
  - First-hop messages would grow by about √5.8 = 2.4 (to about 13 events), not 5.8×.
  - The middle process receives events that were sent because they were due, so it has to send them on at once, and bundles them little.
  - Model: 1.05× uniform's rate at 64 nodes (1.24× if the second hop carried 50 events; 1.44× if messages grew in proportion to arrivals).
  - Costs: htram has no multi-hop routing; the forwarding runs on PEs that execute events; a middle process holding a due event holds GVT back; and the extra hop delays events that are already due.
- **Per-process flushing (estimate):**
  - A process's 23 PEs send about 32 events per destination process per GVT update at 64 nodes. If they share one buffer per destination, a message carries that.
  - Model: 1.9× at 30 events per message, 1.6× at 15, before the cost of the per-event atomics on the shared buffer.
- **PP's gap to WPs at the same message size,** not explained:
  - At 16 nodes (F1-16, W 400) PP 512 runs 337.3 M ev/s at 14.3 events per message, and WPs 512 runs 383.3 at 12.5.
  - At 64 nodes the figures are 810.1 at 5.7 and 1,000.7 at 5.6.
  - Both differences come to about 3.8 µs of PE time per PP message, at both node counts. The node-level receive is the same code for both modes.

**The change** (htram ca22b77, Charades e12e40d):
- **`--agg-pp-local=N`** (N = 1, 2, 4, 8 or 16; default 16) sets htram's `htram_pp_local_size`. A PE copies its local buffer into the shared buffer every N events instead of every 16.
- **Due flushes and urgent sends** (GVT update, idle, `flushTo`) send the shared buffer with the flushing PE's own local events added, as one message (`shipSharedWithLocalPP`).
  - It reserves the rest of the buffer, as a flush always did, so the slots after the copies already reserved are its own.
  - A buffer has 16 spare slots past its limit.
- **While the shared buffer is full or being sent, a PE keeps its events** (up to 16) and copies them with its next copy or due flush, rather than sending them alone.
  - So copies vary in size, and the PE whose reservation reaches the buffer's limit sends it, after the copies reserved before it land.
  - The first version sent them alone: in a 2-process × 4-PE Mac run, 135,233 one-event messages (8% of events), and smaller messages at local 1 than at 16. It was fixed before any Stampede3 run.
- **At 16 every path is the old code.**
  - Found on the way, left as is: at 16, an urgent event that completes a local buffer is copied into the shared buffer, while `flushTo` sends only the local buffer, so that event waits for the next due flush.
  - That is about 1 in 16 urgent events; urgent events are 0.12% of events on uniform at 64 nodes.
- **Mac checks:**
  - Committed counts are identical at local 16, 4 and 1 in every comparison run.
  - In a shape where the GVT-update flush sends the messages (4 processes × 2 PEs, lookahead 500, W 400, 4,096-event buffers), messages carry 15.1 / 16.5 / 21.9 events at local 16 / 4 / 1.
  - Tests: change tier 66/66 on the two deadline configs. Engine tier with the five new configs named (`agg_deadline_bucket_pp_local1`, `agg_deadline_bucket_pp_local4`, `agg_ctl_measured_bucket_pp_local1`, `agg_bucket_pp_local1`, `agg_blocking_pp_local4`): 4,638 of 4,668 passed.
    - The five new configs passed all 565 of their runs, including 20 repeats each at the multi-PE shapes.
    - The 30 that did not pass are known and none runs the changed code:
      - 27 VLSI conservative failures (the lookahead abort, every tree);
      - VLSI `agg_ctl_park_bucket_pp` at 2 × 2 (the intermittent `--sched-park` hang; PP at the default local size, so the old code);
      - dragonfly `gentime` with `bucket_hold_early` and `bucket_hold_pads19` at 2 × 2, the hold hang recorded in applications.md (no aggregation in either config).
- **Stampede3 build:** tree `charades-ppl` (clone at e12e40d; `config.mk` differs from `charades-r5`'s only in the tree path and `HTRAM_DIR = $WORK/htram-ppl`, a worktree at ca22b77). It has the same 23 objects plus htram as `charades-r5`, and links `charm-pads-perf`. A first `make -j4` hit the fresh-tree `.decl.h` race; PHOLD's own `make` then built the library serially.

**Runs** (job PL16, 16 nodes, 5 reps, Charades only; F1's PHOLD settings: end 2,048,000, bucket 8, 128 LPs per PE, 2 × 23 PEs per node; workloads and htram settings in reverse order in even reps):
- **Uniform:** WPs 512 (F1's setting), PP 512, PP 512 local 4, PP 512 local 1.
- **σ 2,000 and σ 4,000:** PP 512 (F1's setting), PP 512 local 4, PP 512 local 1.
- **Arms:** fixed W 400 and the controller (`mb:0`) for each.
- **Run count:** 20 runs per rep, 100 in all, plus one warm-up (uniform, local 1, W 400, end 256,000). If the warm-up fails, the job stops.
- **Gate:** change tier on 2 nodes: F1's PHOLD set plus `agg_deadline_bucket_pp_local1`, `agg_deadline_bucket_pp_local4`, `agg_ctl_measured_bucket_pp_local1`, `agg_bucket_pp_local1`.

**Flags per arm** (from a stub run with a fake `srun`: 101 commands, as planned; `~/charades-data/f1/pl267/stub_cmds.txt`, `flag_table.txt`). Every run carries the paper launch only:
- `srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -N 16 -n 32 -c 24 … numactl --localalloc phold +pe 736`, with `+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free`;
- config `bucket`, `--gvt-bucket-size=8`, the workload config F1 used (94,208 LPs, 16 per chare, 15 start events, lookahead 100, mean 1,000, end 2,048,000).

| arm | Charades flags beyond the launch | runs |
|---|---|---|
| W 400, WPs 512 (uniform) | `--optimism-window=400 --aggregation=1 --agg-mode=0 --agg-buffer=512 --agg-policy=1 --agg-horizon-margin=8` | 5 |
| W 400, PP 512 | the same with `--agg-mode=2` | 5 per workload |
| W 400, PP 512 local 4 / local 1 | the same plus `--agg-pp-local=4` / `--agg-pp-local=1` | 5 each per workload |
| controller | `--ctl=3 --ctl-bracket=1` in place of `--optimism-window=400`, with each htram setting above | 5 each |
| warm-up | W 400, PP 512 local 1, uniform, end 256,000 | 1 |

No log, stats, trace or digest flag appears in any command.

**Predictions:**
- **PL-1. Counts:** one committed count per workload over every arm and rep, equal to F1-16's: uniform 2,895,361,579; σ 2,000 2,895,361,550; σ 4,000 2,895,358,752.
- **PL-2. Uniform's message size** (median events per message, W 400):
  - WPs 512 and PP 512 within ±15% of F1-16's (12.5 and 14.3).
  - Local 1 at least 50, about 3.5× PP 512. A process sends about 99 events per destination process per GVT update at 16 nodes.
  - Local 4 at 0.8–1.0 of local 1's.
- **PL-3. Uniform's rate at W 400:**
  - Local 1 ÷ WPs 512: 1.05–1.30.
  - Local 1 ÷ PP 512: 1.20–1.45.
  - The model gives 1.13–1.28 against WPs at 80 events per message, for per-event atomics costing 0.1–0.3 µs.
- **PL-4. Uniform:** local 4 ÷ local 1 is 0.95–1.05.
- **PL-5. σ 2,000 and σ 4,000 at W 400:**
  - Local 1 ÷ PP 512 is 0.90–1.05. Their messages already carry 50–60 events, so the saving is small and the atomics may cost more.
  - Local 1's events per message are at least 1.3× PP 512's.
- **PL-6. Controller arms:** within each workload the htram settings rank as at W 400, and each setting's controller ÷ W 400 is within ±0.05 of F1's setting's in this job.
- **PL-7. Message triggers on uniform at local 1:**
  - GVT-update messages are at least 90% of messages.
  - Messages from a full buffer (fills, and full local buffers sent alone) are at most 5%.
- **PL-8. Rollbacks:**
  - Efficiency is at least 99.9% in every arm (F1-16: 99.95–99.99).
  - Late stragglers per committed event at local 1 are within 2× of PP 512's.

**What follows:**
- **If local 1 (or 4) ÷ WPs 512 is at least 1.05 on uniform:** run uniform at 64 nodes with WPs 512 and PP 512 at local 1 and 4, W 400 / 500 and the controller. The model predicts 1.50–1.67× there, at about 32 events per message.
- **If it is below 1.05:** report it, and find where local 1's time goes before any 64-node run.
- **If local 1 or 4 is at least 0.98 of PP 512 on σ 2,000 and σ 4,000 too,** it could become PP's setting everywhere. That would mean rerunning every PP cell of F1 and F5, which is a user decision. The default stays 16 until then.

### §268 · PL16 results: one shared buffer per process makes uniform's messages 9× larger (111 events) but runs at 0.80 of WPs 512 and 0.90 of PP 512, and at 0.51–0.66 of PP 512 on σ 2,000 and σ 4,000; local 4 is worse, through a flush race; no 64-node run (2026-11-09; skx-dev batch job 3698962, 16 nodes)

> **Status: current; superseded in part by section 270** (padded counters: the excess below was mostly false sharing, and local 1 then beats WPs 512 on uniform). Design and predictions in section 267.
> - **Job:** 16 nodes, 22.5 minutes (2026-11-09 11:38–12:01); the skx twin 3698961 was cancelled by the guard. Gate 42/42; the warm-up and all 100 timing runs finished `ok`, every one with count waves.
> - **Data:** `~/charades-data/f1/pl267/j3698962` (digests and per-round GVT files not copied). `~/charades-data/f1/pl267/pl268.py` writes `pl268_summary.txt`.
> - **Counts:** one per workload over all 100 runs, equal to F1-16's (uniform 2,895,361,579; σ 2,000 2,895,361,550; σ 4,000 2,895,358,752).

**Rates** (M committed ev/s, median of 5 reps, higher is better; events per htram message, median):

| workload | htram setting | W 400 | controller | events per message (W 400) | ÷ the workload's F1 setting at W 400 |
|---|---|---|---|---|---|
| uniform | WPs 512 (F1) | **381.5** | **380.6** | 12.5 | 1 |
| uniform | PP 512 | 336.7 | 339.5 | 14.3 | 0.882 |
| uniform | PP 512 local 4 | 266.6 | 257.8 | 9.5 | 0.699 |
| uniform | PP 512 local 1 | 303.4 | 307.2 | 111.0 | 0.795 |
| σ 2,000 | PP 512 (F1) | **598.2** | **596.1** | 60.2 | 1 |
| σ 2,000 | PP 512 local 4 | 526.3 | 558.7 | 47.8 | 0.880 |
| σ 2,000 | PP 512 local 1 | 395.2 | 390.5 | 231.3 | 0.661 |
| σ 4,000 | PP 512 (F1) | **542.4** | **548.3** | 50.2 | 1 |
| σ 4,000 | PP 512 local 4 | 451.8 | 476.4 | 30.9 | 0.833 |
| σ 4,000 | PP 512 local 1 | 276.6 | 292.9 | 244.3 | 0.510 |

- **The baselines repeat F1-16:** WPs 512 381.5 (F1-16: 383.3), PP 512 336.7 (337.3), σ 2,000 598.2 (605.0), σ 4,000 542.4 (553.5), with the same message sizes (12.5 and 14.3 on uniform).
- **Local 1 does what it was built to do:** on uniform each process now sends one message per destination process per GVT update, carrying 111 events. That is 0.0090 messages per event, against 0.0798 for WPs, 8.9 times fewer. 95% of its messages are sent at a GVT update, 4.2% for an urgent event, and 1.9% are a PE's events sent alone.
- **It is slower anyway.** In PE time per committed event (736 PEs ÷ rate), local 1 takes 2.43 µs on uniform against WPs' 1.93 and PP's 2.19.
  - Section 267's cost model (9.8 µs per message) predicted 0.58 µs less than PP from the messages saved. Measured, it takes 0.24 µs more.
  - So something else costs 0.82 µs per event on uniform: 0.85 µs per event sent to another process.
  - The same calculation gives 0.69 µs per event on σ 2,000 (1.38 per event sent to another process) and 1.42 µs on σ 4,000 (1.97), where the message saving is small (0.06 and 0.11 µs).
- **Where that time goes is not measured** (no diagnostic in timing runs). The candidate is the per-event write into the process's shared buffer.
  - At local 1 every event sent to another process makes a compare-and-swap on the destination's reservation counter, an atomic add on its done counter, and a store into a buffer slot next to slots that other PEs of the process are writing.
  - The counters are 4-byte atomics packed 16 to a cache line, so all of a process's destinations share two lines of each, and all 23 PEs of the process write them at every such event.
  - Section 75's padding changed nothing, but at that time a copy happened once per 16 events and rarely at all.
- **Local 4 loses more, for a different reason:** a flush race.
  - 89% of its messages on uniform are a PE's local events sent alone (82% on σ 4,000, 76% on σ 2,000), and its messages shrink to 9.5 events.
  - At each GVT update every PE of a process flushes the same due destinations at nearly the same moment. The first sends the shared buffer, and the others find it reserved and send their one to three local events on their own.
  - Local 1 escapes this because its local buffers are almost always empty when a flush comes.
- **Rollbacks are not the cause:** efficiency is 99.95–99.99% in every arm, and late stragglers per committed event at local 1 are below PP 512's on all three workloads.
- **The controller ranks the settings as W 400 does** on all three workloads. Each setting's controller ÷ W 400 is 0.967–1.061.

**Predictions (section 267):**
- **PL-1 right:** one count per workload, equal to F1-16's.
- **PL-2 mostly right:**
  - WPs 512 and PP 512 carry 12.5 and 14.3 events per message, as in F1-16: right.
  - Local 1 carries 111, at least 50 predicted: right.
  - Local 4 carries 0.086 of local 1's, against 0.8–1.0 predicted: wrong (the flush race).
- **PL-3 wrong:**
  - Local 1 ÷ WPs 512 is 0.795 (1.05–1.30 predicted).
  - Local 1 ÷ PP 512 is 0.901 (1.20–1.45 predicted).
- **PL-4 wrong:** local 4 ÷ local 1 is 0.879 (0.95–1.05 predicted).
- **PL-5 half right:**
  - Local 1 ÷ PP 512 is 0.661 on σ 2,000 and 0.510 on σ 4,000 (0.90–1.05 predicted): wrong.
  - Local 1's messages are 3.8 and 4.9 times PP 512's (at least 1.3 predicted): right.
- **PL-6 right in 6 of 7:** the settings rank alike under both arms. The exception is σ 2,000 at local 4, where controller ÷ W 400 is 1.061 against PP 512's 0.996.
- **PL-7 right:** 95.3% of local 1's messages on uniform are sent at a GVT update, and none from a full buffer.
- **PL-8 right:** efficiency is at least 99.95% in every arm, and local 1's late stragglers are below PP 512's.

**What follows:**
- **Section 267's rule** (local 1 ÷ WPs 512 below 1.05) holds: no 64-node run. `--agg-pp-local` stays at 16, the `pp-local` branches stay unmerged, and F1's settings and every paper table stand.
- **The cost model mispredicted by about 1 µs per event.** It was fitted on runs whose events each go through one PE's own buffers, and it does not hold for a design that changes the per-event path.
  - Section 267's 2D estimate used the same model, and 2D also adds per-event work (a second hop), so this result gives no more reason to expect 2D to help.
- **Open:** where local 1's 0.85–1.97 µs per event sent to another process goes. Settling it would take a simulation-only profile at 4 nodes of local 1 against PP 512 on uniform, and an arm with each destination's counters on their own cache line.
- **For the paper:** the limit stands as written: aggregation's gain on all-remote traffic falls from 3.31× at 4 nodes to 1.85× at 64.
  - This job shows why the obvious fix does not work. One buffer shared by a process's PEs makes messages 9× larger, but costs more per event than the messages it saves.

### §269 · Where local 1's extra time goes: a profile, and PP's shared counters one destination per cache line (job PD16 design, 2026-11-09; written before any runs)

> **Status: design (results in section 270).**
> - **User decision 2026-11-09:** one bounded diagnostic of section 268's local 1 (option 2 there). The stop rule is below.
> - **Code:** htram branch `pp-pad` (978e065, on `pp-local`); Charades branch `pp-pad` (836f7fd, on `pp-local`). The default (`--agg-pp-pad=0`) keeps the packed layout.
> - **Script:** `~/charades-data/f1/pd269.slurm`; tree `$WORK/charades-pplpad`, htram `$WORK/htram-pplpad`.
> - **Jobs:** 3699744 (skx) and 3699745 (skx-dev), twins: whichever starts first cancels the other.

**Why.**
- In section 268, local 1 took 0.85 µs more per event sent to another process on uniform, and 1.97 µs more on σ 4,000, than the messages it saved allow.
- At local 1 every such event does three things in the process's shared buffer: a compare-and-swap on the destination's reservation counter (`get_idx`), an atomic add on its done counter (`done_count`), and a store into a buffer slot. It also reads the buffer's limit (`pp_limit`) and may lower its minimum key (`min_key`).
- These four counters were packed arrays: 16 destinations' 4-byte counters to a cache line. So every event any of a process's 23 PEs sends to another process writes one of the same two or three lines.
- Section 75 padded the same counters (with the input buffers) for PP at local 16 and found no effect (padded ÷ unpadded 0.98–1.02 at σ 100 and 2,000). At local 16 a PE touches them once per 16 events; at local 1 it touches them on every event, so that result does not settle this one.
- The test has two parts:
  - a perturbation: the same counters with no line shared between destinations;
  - a closure check: a profile of where local 1's cycles go.

**The change** (htram 978e065, Charades 836f7fd):
- **`--agg-pp-pad=M`** sets htram's `htram_pp_pad` on every process in `tw_init`, before the node group exists:
  - 0 = the four packed arrays, as before;
  - 1 = each array with one destination per 64-byte line;
  - 2 = one 64-byte line per destination holding all four counters (one line touched per event instead of up to four).
- The counters are read through a byte stride (`PPCounters`), so every call site is unchanged.
- **Mac:** committed counts identical at local 1 with pad 0 / 1 / 2 and at local 16 with pad 2 (2,049,257 events, 4 processes × 2 PEs). Change tier on the nine PP configs, 3 repeats, under pad 1 and under pad 2: 891/891 each.

**Runs** (job PD16, 16 nodes, F1's PHOLD settings as in section 267, W 400 only):
- **Part A, timing,** 5 reps, settings and workloads reversed in even reps:
  - uniform: WPs 512; PP 512 at pad 0 / 1 / 2; PP 512 local 1 at pad 0 / 1 / 2;
  - σ 4,000: PP 512 at pad 0 / 2; PP 512 local 1 at pad 0 / 1 / 2.
  - That is 12 runs per rep and 60 in all, plus one warm-up (uniform, local 1, pad 2, end 256,000). If the warm-up fails, the job stops.
- **Part B, profiles** (check runs after part A, not timing):
  - uniform W 400, one run each of WPs 512, PP 512, and local 1 at pad 0 / 1 / 2;
  - `perfwrap_d.sh`: user cycles at 1,999 Hz in task 0 (one process of 23 PEs on the first node), from 3 s after launch (setup takes about 1.5 s; the runs execute for 8–10 s);
  - `perf report` by symbol and by library, and `perf annotate` of htram's send path, run in the job.
- **Gate:** change tier on 2 nodes: PHOLD with the PP configs (`agg_deadline_bucket_pp`, `agg_ctl_measured_bucket_pp` and the three local-1 configs) and `agg_inputbuf_bucket_wps`, then the PP configs again under pad 1 and under pad 2.

**Flags per arm** (stub run on the login node, 66 commands: 60 timing, 1 warm-up, 5 profiles; `~/charades-data/f1/pd269/flag_table.txt`):
- Launch, every run: `srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -N 16 -n 32 -c 24 -w <16 nodes> numactl --localalloc phold`; the 5 profile runs alone put `perfwrap_d.sh` before `numactl`.
- Every run: `+pe 736`, `test_configs/bucket`, `--optimism-window=400 --gvt-bucket-size=8 --aggregation=1 --agg-buffer=512 --agg-policy=1 --agg-horizon-margin=8 +lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free`. These match section 268's fixed-W arms flag for flag.

| arm | runs | flags beyond the common set |
|---|---|---|
| WPs 512 (uniform) | 5 timing + 1 profile | `--agg-mode=0` |
| PP 512, pad 0 (uniform, σ 4,000) | 5 + 5 timing + 1 profile | `--agg-mode=2` |
| PP 512, pad 1 (uniform) | 5 | `--agg-mode=2 --agg-pp-pad=1` |
| PP 512, pad 2 (uniform, σ 4,000) | 5 + 5 | `--agg-mode=2 --agg-pp-pad=2` |
| local 1, pad 0 (uniform, σ 4,000) | 5 + 5 timing + 1 profile | `--agg-mode=2 --agg-pp-local=1` |
| local 1, pad 1 (uniform, σ 4,000) | 5 + 5 timing + 1 profile | `--agg-mode=2 --agg-pp-local=1 --agg-pp-pad=1` |
| local 1, pad 2 (uniform, σ 4,000) | 5 + 5 timing + 1 profile | `--agg-mode=2 --agg-pp-local=1 --agg-pp-pad=2` |
| warm-up (uniform, end 256,000) | 1 | `--agg-mode=2 --agg-pp-local=1 --agg-pp-pad=2` |

**Predictions:**
- **PD-1. Counts:** one per workload over every run, equal to F1-16's (uniform 2,895,361,579; σ 4,000 2,895,358,752).
- **PD-2. The baselines repeat PL16:** WPs 512, PP 512 and local 1 at pad 0 within ±5% of section 268's medians (uniform 381.5 / 336.7 / 303.4; σ 4,000 542.4 / 276.6 M ev/s).
- **PD-3. Padding leaves PP 512 alone** (as in section 75):
  - pad 1 and pad 2 ÷ pad 0 within 0.97–1.03 on uniform, where its counters are touched about once per 16 events;
  - pad 2 ÷ pad 0 within 0.97–1.05 on σ 4,000.
- **PD-4. Padding helps local 1:**
  - the better of pad 1 and pad 2 ÷ pad 0 is 1.10–1.30 on uniform and 1.10–1.50 on σ 4,000;
  - pad 2 is at least pad 1's rate.
- **PD-5. Against WPs 512 on uniform:** the best padded local 1 ÷ WPs 512 is 0.90–1.05, so below the stop rule's 1.05.
  - Padding removes sharing between destinations, but 23 PEs still write each destination's counters and slots.
- **PD-6. Profile:**
  - In local 1 at pad 0, htram's send path (the functions holding the copy into the shared buffer and the flushes) takes at least 15% of the profiled process's user cycles, against at most 5% under PP 512.
  - Most of the copy's samples fall on its atomic instructions and the instructions right after them.
  - At pad 2 that share falls by at least a third.
- **PD-7. Message sizes:** padding changes local 1's events per message by less than 10% (uniform about 111, σ 4,000 about 244).

**Stop rule** (user decision 2026-11-09):
- **If the best padded local 1 is at least 1.05 × WPs 512 on uniform:** propose uniform at 64 nodes (user decision).
- **Otherwise the per-process line closes:** the paper keeps its limit with this evidence and names per-process aggregation as future work, and no more aggregation runs go in before writing.

### §270 · PD16 results: with each destination's counters on their own cache line, local 1 runs at 1.41× its packed rate and 1.10× WPs 512 on uniform at 16 nodes, but at 0.84 of PP 512 on σ 4,000; false sharing on the packed counters was most of section 268's excess; the stop rule calls for a 64-node proposal (2026-11-09; skx-dev batch job 3699745, 16 nodes)

> **Status: current.** Design and predictions in section 269. Supersedes in part section 268 (its cause "not measured" and its "no 64-node run").
> - **Job:** 16 nodes, 17 minutes (2026-11-09 17:37–17:54); the skx twin 3699744 was cancelled by the guard. Gate 36/36, 30/30 (pad 1) and 30/30 (pad 2); the warm-up and all 60 timing runs finished `ok`, every one with count waves, and every padded run's log names its layout.
> - **Data:** `~/charades-data/f1/pd269/j3699745` (digests and per-round GVT files not copied). `~/charades-data/f1/pd269/pd270.py` writes `pd270_summary.txt`. Perf data and reports in `j3699745/perf/`.
> - **Counts:** one per workload over all 60 runs, equal to F1-16's (uniform 2,895,361,579; σ 4,000 2,895,358,752).

**Rates** (W 400, M committed ev/s, median of 5 reps, higher is better; spread = fastest ÷ slowest rep; PE time = 736 PEs ÷ rate, lower is better):

| workload | htram setting | rate (M ev/s) | spread | events per message | PE time per committed event (µs) | ÷ PP 512 pad 0 | ÷ WPs 512 |
|---|---|---|---|---|---|---|---|
| uniform | WPs 512 (F1) | **387.9** | 1.03 | 12.6 | 1.90 | 1.160 | 1 |
| uniform | PP 512, pad 0 | 334.5 | 1.04 | 14.4 | 2.20 | 1 | 0.862 |
| uniform | PP 512, pad 1 | 334.9 | 1.04 | 14.3 | 2.20 | 1.001 | 0.863 |
| uniform | PP 512, pad 2 | 337.5 | 1.03 | 14.3 | 2.18 | 1.009 | 0.870 |
| uniform | local 1, pad 0 | 302.6 | 1.13 | 111.5 | 2.43 | 0.905 | 0.780 |
| uniform | local 1, pad 1 | **427.6** | 1.05 | 105.5 | 1.72 | 1.278 | **1.102** |
| uniform | local 1, pad 2 | 381.6 | 1.10 | 109.5 | 1.93 | 1.141 | 0.984 |
| σ 4,000 | PP 512, pad 0 (F1) | **553.9** | 1.05 | 50.0 | 1.33 | 1 | |
| σ 4,000 | PP 512, pad 2 | 555.7 | 1.01 | 49.8 | 1.32 | 1.003 | |
| σ 4,000 | local 1, pad 0 | 283.4 | 1.13 | 247.7 | 2.60 | 0.512 | |
| σ 4,000 | local 1, pad 1 | 467.6 | 1.03 | 198.9 | 1.57 | 0.844 | |
| σ 4,000 | local 1, pad 2 | 416.6 | 1.06 | 216.4 | 1.77 | 0.752 | |

- **The baselines repeat section 268:** this job ÷ PL16 is 1.017 (WPs 512), 0.994 (PP 512) and 0.997 (local 1) on uniform, and 1.021 and 1.025 on σ 4,000.
- **Padding leaves PP 512 alone,** as in section 75: 1.001 and 1.009 on uniform, 1.003 on σ 4,000.
- **Padding speeds local 1 up a great deal:** pad 1 ÷ pad 0 is 1.413 on uniform and 1.650 on σ 4,000. Pad 2 helps less (1.261 and 1.470; pad 2 ÷ pad 1 0.89 on both).
- **On uniform, local 1 at pad 1 is now the fastest setting:** 1.102 × WPs 512 and 1.278 × PP 512, with 8.3 times fewer messages than WPs (0.0095 against 0.0792 per event through htram).
- **On σ 4,000 it still loses:** 0.844 of PP 512.
- **Closure against section 268:**
  - Pad 1 saves 0.71 µs per committed event on uniform and 1.02 µs on σ 4,000. Section 268's unexplained excess was 0.82 and 1.42 µs, so the packed layout accounts for about 87% of it on uniform and 72% on σ 4,000.
  - Padded, local 1 takes 0.48 µs less per committed event than PP 512 on uniform. Section 267's model predicted 0.58 µs less from the messages saved.
- **The packed layout also made local 1 noisy:** a rep spread of 1.13 on both workloads, against 1.03–1.05 at pad 1.
- **Messages on σ 4,000 shrink when padded** (248 → 199 events at pad 1), and the share sent for an urgent event rises from 6.8% to 24.5%. Why is not measured.
- **Rollbacks are not involved:** efficiency is 99.95–99.99% in every arm.

**Profiles** (part B: one check run per setting, uniform W 400; user cycles in one process of 23 PEs on the first node, from 3 s after launch to the end; the sample count follows the run's length; send path = htram's `copyLocalToNodeBuf`, `flushDue`, `flushOrder`, `shipSharedPP`, `insertValue`, `insert` and Charades' `agg_send`):

| setting | samples (thousands) | send path (% of samples) | send path (thousands of samples) | `copyLocalToNodeBuf` (%) | `flushDue` (%) | `flushOrder` (%) |
|---|---|---|---|---|---|---|
| WPs 512 | 256 | 4.6 | 11.8 | | below 0.3 | 1.4 |
| PP 512, pad 0 | 325 | 7.9 | 25.8 | | 2.8 | 2.6 |
| local 1, pad 0 | 438 | 30.9 | 135.3 | 15.7 | 4.9 | 7.7 |
| local 1, pad 1 | 236 | 31.5 | 74.2 | 12.0 | 13.6 | 1.5 |
| local 1, pad 2 | 246 | 34.2 | 84.1 | 12.6 | 17.8 | 1.3 |

- **Where the copy's time goes:** at every pad, 63–75% of `copyLocalToNodeBuf`'s samples fall on the instructions right after its two atomic instructions (the `lock cmpxchg` reserving a slot through `get_idx`, and the `lock add` on `done_count`), and another 18–20% on the load of `pp_limit` just before the compare-and-swap. A sample lands on the instruction after the one that waited, so this is the pattern of the atomics and the load waiting for lines other PEs write (no cache-miss counter was recorded).
- **What padding removes:** at pad 0, all 31 destinations' counters of each kind sit on two lines, so every event any of the process's 23 PEs sends to another process takes one of those lines away from the others. Padded, PEs sending to different destinations no longer interfere. The copy's samples fall from 68.8 to 28.3 thousand, the largest single drop.
- **What padding cannot remove:** the copy still takes 12% of cycles at pad 1, because PEs sending to the *same* destination still write the same `get_idx` and `done_count`.
- **A new cost appears in `flushDue`:**
  - Under the deadline policy, a scheduler pass that runs less than a full batch calls `agg_flush_idle`, which calls `flushDue`.
  - At local 1, a PE's local buffers are nearly always empty, so for each destination `flushDue` reads the process's shared `min_key`.
  - Packed, those 31 values sit on 4 lines. Padded, each is on a line of its own, recently written by an inserting PE, so each read is a miss. 95–96% of `flushDue`'s samples at pad 1 and pad 2 fall on that one load.
- **Why pad 2 loses to pad 1** (the reading the profile supports): pad 2 puts `min_key` on the same line as `get_idx` and `done_count`, which every insert writes. So every idle-pass read misses, and the next insert's atomic must take the line back. `flushDue` takes 17.8% of cycles at pad 2 against 13.6% at pad 1.
- **`flushOrder` is not a layout effect:** its samples at pad 0 and pad 1 fall on the same instructions (an integer division per destination, building the visiting order). It is called from the same idle passes, and it shrinks because local 1 waits less once padded.
- **The rest of the sample drop** (pad 0 → pad 1: 202 thousand, 61 of them in the send path) is spread over the scheduler, polling and lock functions that run while a PE waits. They shrink as the run gets shorter.

**Predictions (section 269):**
- **PD-1 right:** one count per workload, equal to F1-16's.
- **PD-2 right:** the baselines are within 0.994–1.025 of section 268's medians.
- **PD-3 right:** PP 512 padded ÷ packed is 1.001 and 1.009 on uniform and 1.003 on σ 4,000.
- **PD-4 wrong in size and in order:**
  - Padding helped local 1 more than predicted: 1.413 on uniform (1.10–1.30 predicted) and 1.650 on σ 4,000 (1.10–1.50).
  - Pad 2 is 0.89 of pad 1, not at least equal: `flushDue`'s reads of `min_key` were not in the reasoning.
- **PD-5 wrong:** the best padded local 1 ÷ WPs 512 is 1.102 (0.90–1.05 predicted).
- **PD-6 half right:**
  - The send path takes 30.9% of local 1's cycles at pad 0: right (at least 15%). PP 512's takes 7.9%: wrong (at most 5%).
  - Most of the copy's samples fall right after its atomic instructions: right.
  - The send path's share does not fall at pad 2 (34.2%) because `flushDue` grew: wrong. Its sample count falls 38% at pad 2 and 45% at pad 1.
- **PD-7 half right:** on uniform, local 1's messages change by 5.4% (pad 1) and 1.8% (pad 2): right. On σ 4,000 they shrink by 20% and 13%: wrong.

**What follows:**
- **The stop rule's first branch holds:** the best padded local 1 ÷ WPs 512 is 1.102, at least 1.05. Uniform at 64 nodes went to the user as a proposal; the user approved it (job L64, section 271).
- **Per workload:** padded local 1 replaces WPs 512 as the fastest uniform setting at 16 nodes. PP 512 at local 16 stays the fastest on σ 4,000.
  - F1 already chooses htram's setting per workload (WPs 512 for uniform, PP 512 for σ 2,000 and σ 4,000), so a uniform-only change fits the tables as they are.
- **Next costs, if the line continues:**
  - `flushDue`'s reads of every destination's shared `min_key` on every idle pass take 13.6% of cycles at pad 1. Cutting them touches the flush rules that keep GVT moving, so it needs its own design.
  - The remaining same-destination atomics take 12%.
- **The paper tables are unchanged:** the branches `pp-pad` stay unmerged and F1's settings stand until a 64-node result.
- **Section 268's lesson stands:** the per-message cost model did not predict a per-event cost. Here padding fixed most of that cost, but the model would not have found it.

### §271 · Does padded local 1 keep its lead over WPs 512 on uniform at 64 nodes? (job L64 design, 2026-11-09; written before any runs)

> **Status: design (results in section 272).**
> - **User decision 2026-11-09:** run the 64-node proposal of section 270's stop rule.
> - **Code:** the same binary as section 270 (Charades branch `pp-pad` 836f7fd, htram `pp-pad` 978e065, tree `$WORK/charades-pplpad`).
> - **Script:** `~/charades-data/f1/l64/l64.slurm`. 64 nodes is above skx-dev's limit, so it goes to skx alone, with no twin.
> - **Job:** 3700829 (skx), submitted 2026-11-09 evening.
> - **Cost:** 20 timing runs of about 12–20 s, plus the gate and warm-up: about 15–20 minutes of 64 nodes, roughly 20 SUs (P64 took 188).

**Why.**
- The paper states a limit: aggregation's gain on uniform falls from 3.31× at 4 nodes to 1.85× at 64 (P64, section 265), because WPs' messages shrink to 5.6 events.
- At 16 nodes, local 1 with padded counters ran at 1.102 × WPs 512 (section 270). It makes one message per process pair per GVT update instead of one per PE and process.
- The open question is whether that lead holds or grows at 64 nodes, where messages cost WPs more, or whether local 1's own per-event costs grow with the number of destinations.

**Runs** (64 nodes, one stream, F1's PHOLD settings as P64: end 2,048,000, bucket 8, 128 LPs per PE, 2 × 23 PEs, uniform):
- WPs 512 (F1's uniform setting) and PP 512 local 1 pad 1 (`--agg-mode=2 --agg-pp-local=1 --agg-pp-pad=1`), each under the controller and at W 400.
- 5 reps, settings and arms reversed in even reps: 20 runs.
- One warm-up first (local 1 pad 1, W 400, end 256,000). If it fails, the job stops.
- **Gate:** change tier on 2 nodes, PHOLD with the PP configs (including the three local-1 configs) and `agg_inputbuf_bucket_wps`, then the PP configs again under `--agg-pp-pad=1`.
- No diagnostics and no profiles: P64 already gives the 64-node baselines (WPs 512 controller 980.0, W 400 998.9, best fixed W 1,000.7 at W 500; PP 512 W 400 810.1; direct sends best 540.6 at W 300; 5.6 events per WPs message).

**Flags per arm** (stub run on the login node, 21 commands; `~/charades-data/f1/l64/flag_table.txt`):
- Launch, every run: `srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -N 64 -n 128 -c 24 -w <64 nodes> numactl --localalloc phold`.
- Every run: `+pe 2944`, `test_configs/bucket`, `--gvt-bucket-size=8 --aggregation=1 --agg-buffer=512 --agg-policy=1 --agg-horizon-margin=8 +lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free`, workload `steady_100_1000_1.0_376832_15_2048000`.
- Compared command by command with P64's stub log: the WPs 512 arms are identical apart from the tree's path.

| arm | runs | flags beyond the common set |
|---|---|---|
| WPs 512, controller | 5 | `--ctl=3 --ctl-bracket=1 --agg-mode=0` |
| WPs 512, W 400 | 5 | `--optimism-window=400 --agg-mode=0` |
| local 1 pad 1, controller | 5 | `--ctl=3 --ctl-bracket=1 --agg-mode=2 --agg-pp-local=1 --agg-pp-pad=1` |
| local 1 pad 1, W 400 | 5 | `--optimism-window=400 --agg-mode=2 --agg-pp-local=1 --agg-pp-pad=1` |
| warm-up (end 256,000) | 1 | `--optimism-window=400 --agg-mode=2 --agg-pp-local=1 --agg-pp-pad=1` |

**The estimate behind the predictions** (PE time per committed event, µs; lower is better):
- **WPs 512 at 64 nodes:** 2,944 PEs ÷ 998.9 M ev/s = 2.95 µs.
  - At section 267's 9.8 µs per message, its messages cost 1.74 µs of that: 0.992 of events go through htram, 5.6 to a message.
  - That leaves 1.21 µs for everything else (1.15 at 16 nodes).
- **Local 1's messages:** section 267's square-root rule (message size grows as the square root of a buffer's arrivals) and 4.1 times as many destinations take its 105.5 events per message at 16 nodes to about 52. That is 0.19 µs per committed event.
- **Local 1's own per-event cost:** 0.49 µs per committed event at 16 nodes. That is its measured time less its messages, less WPs' time less its messages.
  - If it stays at 0.49 µs: 1.21 + 0.49 + 0.19 = 1.89 µs, which is 1.56 × WPs 512.
  - If it doubles: 1.24 ×. If it triples: 1.03 ×.
- **Why it might grow:**
  - `flushDue` reads every destination's shared `min_key` on every idle pass (13.6% of cycles at 16 nodes, section 270).
  - At 64 nodes there are 127 destinations instead of 31, each on its own line at pad 1.
- **Why it might shrink:** a process's 23 PEs spread their sends over 4 times as many destinations, so fewer of them write any one destination's counters at once.

**Predictions:**
- **L64-1. Counts:** one over all 20 runs, equal to P64's uniform count (11,581,457,663).
- **L64-2. WPs 512 repeats P64:**
  - controller and W 400 within ±5% of 980.0 and 998.9;
  - 5.2–6.0 events per message.
- **L64-3. Local 1's messages:**
  - 40–70 events per message;
  - at least 85% of them sent at a GVT update (90.7% at 16 nodes).
- **L64-4. The lead holds:** local 1 pad 1 ÷ WPs 512 at W 400 is 1.15–1.55. Below 1.15 would mean local 1's own per-event cost more than doubled with four times the destinations.
- **L64-5. The controller agrees:**
  - local 1 ÷ WPs 512 under the controller is within 0.05 of the W 400 ratio;
  - each setting's controller ÷ W 400 is 0.95–1.06.
- **L64-6. Quality:** efficiency at least 99.9% in every run; local 1's rep spread (fastest ÷ slowest) at most 1.10.
- **L64-7. Bundling** (across jobs: local 1's better arm ÷ P64's best direct sends, 540.6) is 2.1–2.9, against P64's 1.85 and AG32's 2.29 at 32 nodes.

**After the result** (user decisions):
- **If local 1 ÷ WPs 512 is at least 1.10 under both arms,** the user decides how it enters the paper:
  - (a) a paragraph or figure on uniform at scale, with the tables kept on F1's settings;
  - (b) uniform's setting in the tables, which needs the `pp-pad` branches merged (engine tier) and uniform rerun at 1–64 nodes.
- **If 1.00–1.10:** the result goes in the limit's text, and there are no more runs.
- **Below 1.00:** the 16-node gain does not hold at scale. The limit stays, with section 270's measured causes as future work.

### §272 · L64 results: the machine ran at half speed, so the 64-node comparison is not usable; local 1 led WPs 512 in all 10 paired reps (1.05–1.43) (2026-11-10; skx batch job 3700829, 64 nodes)

> **Status: current (inconclusive); superseded in part by section 276** (the comparison at normal speed). Design and predictions in section 271.
> - **Job:** 64 nodes, 13.5 minutes (2026-11-10 11:14–11:27), about 14 SUs. Gate 36/36 and 30/30 (pad 1); the warm-up and all 20 timing runs finished `ok`, every one with count waves, and every local-1 run's log names pad 1.
> - **Start-up:** Slurm could not enter the job's `/work2` directory at start (`Input/output error`, it ran from `/tmp`). The script uses absolute paths, and every run read its configuration (count waves present).
> - **Data:** `~/charades-data/f1/l64/j3700829` (digests and per-round GVT files not copied). `~/charades-data/f1/l64/l64_272.py` writes `l64_272_summary.txt`.
> - **Count:** one over all 20 runs, equal to P64's uniform count (11,581,457,663).

**Rates** (uniform, 64 nodes, M committed ev/s, median of 5 reps, higher is better; spread = fastest ÷ slowest rep):

| htram setting | arm | rate (M ev/s) | spread | events per message | efficiency (%) | late stragglers per run (median) | P64 rate (M ev/s) | ÷ P64 |
|---|---|---|---|---|---|---|---|---|
| WPs 512 | controller | 493.6 | 1.19 | 5.7 | 99.74 | 3,964,000 | 980.0 | 0.504 |
| WPs 512 | W 400 | 493.4 | 1.17 | 5.7 | 99.75 | 2,888,000 | 998.9 | 0.494 |
| local 1 pad 1 | controller | 566.9 | 1.36 | 35.7 | 99.90 | 2,784 | | |
| local 1 pad 1 | W 400 | 583.6 | 1.47 | 36.5 | 99.92 | 1,323 | | |

**Local 1 pad 1 ÷ WPs 512, by rep** (each pair ran minutes apart in the same rep; higher is better):

| arm | rep 1 | rep 2 | rep 3 | rep 4 | rep 5 | median |
|---|---|---|---|---|---|---|
| controller | 1.320 | 1.382 | 1.106 | 1.149 | 1.051 | 1.149 |
| W 400 | 1.430 | 1.252 | 1.183 | 1.061 | 1.253 | 1.252 |

- **The baseline did not repeat P64.** WPs 512 ran at 0.49–0.50 of P64's rate with the same message size (5.7 events against 5.6), so it did the same aggregation work at half the speed.
- **The cause looks like the machine, not the code:**
  - Every rep was slow, from the first, and the rates fell through the job: local 1 at W 400 went from 764 to 521, WPs 512 from 534 to 456.
  - Each GVT round took 1.9–2.2 count waves for WPs and 2.7–3.0 for local 1, against 1.0 in P64. A wave repeats when the sent and received counts disagree, that is, when messages are still in transit.
  - WPs' late stragglers rose 4.4× (2.89 million against 0.66 million at W 400).
  - `/work2` returned I/O errors at start-up.
- **What was checked on the code:**
  - The code since P64's build (Charades 85a2aad → 836f7fd, htram 42d347f → 978e065) changes only PP's paths and how the node group lays out PP's counters; WPs' insert and flush paths are unchanged.
  - At 16 nodes the same binary's WPs ran at 1.017 of section 268's rate and as fast as F1-16 (section 270).
  - Not checked: P64's own binary on the same nodes at the same time. That is the control a rerun needs.
- **Local 1 still led in every pair** (10 of 10, 1.05–1.43). Its far fewer messages (0.027 per event against 0.175) and far fewer late stragglers may also have made it less sensitive to a slow network, so these ratios may overstate the lead on a quiet machine.
- **Local 1's messages carry 36 events,** below the 40–70 predicted, and 13–15% of them go out for an urgent event (9% at 16 nodes).

**Predictions (section 271):**
- **L64-1 right:** one count, equal to P64's.
- **L64-2 wrong:** WPs 512 ran at 0.494–0.504 of P64 (±5% predicted); message size 5.7: right.
- **L64-3 mostly wrong:** 36–37 events per message (40–70 predicted). 87% of messages are sent at a GVT update at W 400 (right) but 84% under the controller (at least 85% predicted).
- **L64-4 not tested:** the W 400 ratio is 1.183 (median of rates) or 1.252 (median of paired reps), inside 1.15–1.55. But the baseline failed L64-2, so the result does not count.
- **L64-5 right:** the controller ratio (1.148) is within 0.05 of W 400's (1.183), and controller ÷ W 400 is 1.000 (WPs) and 0.971 (local 1).
- **L64-6 wrong:** WPs' efficiency is 99.74–99.75% (at least 99.9% predicted), and local 1's spread is 1.36–1.47 (at most 1.10).
- **L64-7 not tested:** it compares across jobs, against P64's direct sends, and this job ran at half speed.

**What follows:**
- **No 64-node number from this job goes in the paper.** The limit's text keeps section 270's 16-node result.
- **A rerun would need a control** to separate the machine from the code: P64's own binary (`charades-r5`) running WPs 512 at W 400 in each rep, with a stop if its first run is far below P64's 998.9. The user approved it (job L64b, section 273).

### §273 · L64 again, with P64's own binary as a control in every rep and a probe that stops the job on a slow machine (job L64b design, 2026-11-10; written before any runs)

> **Status: design (results in section 274).**
> - **User decision 2026-11-10:** rerun L64 (section 272: the machine ran at half speed) with a control.
> - **Script:** `~/charades-data/f1/l64/l64b.slurm` (L64's script with the probe and the control added); skx only, no twin.
> - **Job:** 3704609 (skx).
> - **Cost:** about 10–15 minutes of 64 nodes at P64's speed (about 11–16 SUs). A slow machine stops the job after the probe, about 1–2 SUs.

**What changes from L64** (section 271 otherwise):
- **Probe first.** Before the gate, one run of P64's own tree and binary (`charades-r5`, 85a2aad, its own `ctl_sweep.sh`) with WPs 512 at W 400. If its rate is below 900 M committed ev/s (0.90 of P64's 998.9), the job stops. I then report to the user and do not resubmit without a decision.
- **A control in every rep.** The same `charades-r5` run, next to L64's four runs (WPs 512 and local 1 pad 1, each under the controller and at W 400). Settings and arms are reversed in even reps, as before: 25 timing runs.
- **What the control separates:**
  - If the control runs at P64's rate, the machine is as P64 saw it.
  - The same-rep ratio of `charades-pplpad`'s WPs 512 to the control then tests the code since P64. That code should not touch WPs' paths (section 272).

**Flags per arm** (stub run, 27 commands: probe, warm-up, 25 timing runs; `~/charades-data/f1/l64/flag_table_b.txt`):
- The probe's and the control's commands are identical to P64's uniform WPs 512 W 400 commands, apart from the node list, the job name and the run directory.
- The other arms' commands are identical to L64's (section 271's table).

**Predictions:**
- **L64-1 to L64-7 of section 271 stand unchanged.** Section 272's half-speed run does not revise them.
- **L64b-1. Control:** the probe and the control's median are within ±5% of P64's 998.9 M ev/s.
- **L64b-2. No code effect on WPs:** `charades-pplpad`'s WPs 512 at W 400 ÷ the control, paired by rep, has a median of 0.97–1.03.

**After the result:** as in section 271. A control below 0.95 of P64 marks the run as on a slow machine, as L64's was. Then no ratio from it counts, and the next step goes to the user.

### §274 · L64b results: the probe stopped the job (P64's own binary at 0.52 of its P64 rate); both slow 64-node jobs show 0.2 s stalls consistent with PSM2 retransmitting lost packets (2026-11-11; skx batch job 3704609, 64 nodes)

> **Status: current (stopped by its probe; no comparison); superseded in part by section 275** (the 7 nodes are weak suspects; job 3708456 cancelled before it ran). Design in section 273.
> - **Job:** 64 nodes, 4.2 minutes (2026-11-11 06:28–06:32), about 4.5 SUs; balance 1,825 SUs. The probe ran, and the job stopped before the gate, as designed.
> - **Data:** `~/charades-data/f1/l64/b_j3704609` (the probe's CSV and log); node lists of the five recent jobs in `~/charades-data/f1/l64/nodes.txt`.

**The probe** (P64's tree and binary, `charades-r5`; WPs 512 at W 400, uniform, 64 nodes; its command identical to P64's apart from the nodes):

| run | execution time (s) | rate (M committed ev/s) | count waves per GVT round | late stragglers | events rolled back | efficiency (%) |
|---|---|---|---|---|---|---|
| P64, rep 1 (2026-11-08) | 11.51 | 1,006.0 | 1.00 | 661,831 | 5,206,605 | 99.96 |
| L64b probe (2026-11-11) | 22.27 | 520.1 | 3.13 | 3,017,574 | 31,046,181 | 99.73 |

- **The same binary, half as fast.**
  - It loads the same libraries: Charades' runtime libraries date from 2026-11-03, and PSM2, libfabric and the C library from September or earlier.
  - L64's WPs 512 (section 272) ran at the same 0.49–0.50.
- **Where the time goes:** the run prints a line every 64 GVT rounds with the elapsed time.
  - In P64's run no gap between lines exceeds 0.12 s.
  - In the probe, 45 gaps take about 0.2 s each (median 0.198 s), 8.98 of its 22.27 s. Without them it takes 13.29 s, 1.15 × P64's 11.51 s.
  - L64's first WPs run has 18 such gaps (3.70 s).
- **A reading consistent with these numbers** (not tested):
  - PSM2 resends a packet it gets no acknowledgement for after its error-check timeout. That timeout is 160 ms at least, doubling up to 640 ms (`PSM2_ERRCHK_TIMEOUT` default `160:640:2`, from the library).
  - A stall of about 0.2 s every so often, more count waves per GVT round, and more late stragglers are what lost packets would do here.
  - A packet can be lost on a faulty link, or at a receiving node that falls behind and overflows its receive queues. The data do not separate the two.
- **Nodes:**
  - 7 nodes were in both slow jobs and in none of the three normal ones (P64, A64, PD16): c483-111, c494-023, c501-071, c503-084, c503-094, c503-102, c504-104.
  - Racks are not the pattern: P64 and A64 also used 4–5 nodes in c503.
  - Not shown: whether one of these 7 is at fault (as c455-081 was, and is excluded from every job), or the fabric at large changed after 2026-11-09. PD16 at 16 nodes on 2026-11-09 ran at its usual rate, and nothing has run at 16 nodes since.
- **Predictions (section 273):** L64b-1 wrong (the probe at 0.52 of P64, ±5% predicted). L64b-2 and L64-1 to L64-7 not tested.
- **Next** (user decision): exclude the 7 nodes and run L64b again with its probe; report the stalls to TACC; wait; or stop.
- **User decision 2026-11-11:** run L64b again, unchanged (same script, checked by checksum), with the 7 nodes excluded as well as c455-081: job 3708456 (skx, `-x c455-081,c483-111,c494-023,c501-071,c503-[084,094,102],c504-104`). Cancelled before it ran: section 275 adds a network record to the same job.

### §275 · Can the job name a bad node? L64b again with a network record between runs (job L64b design addendum, 2026-11-11; written before any runs)

> **Status: design (results in 276).** Corrects section 274's node list in part.
> - **Job:** section 273's L64b script plus a network record between runs; the runs, their order and their flags unchanged; the 7 nodes of section 274 and c455-081 still excluded (user decision in section 274).
> - **Files:** `~/charades-data/f1/l64/l64b.slurm` (the version before this change is `l64b_pre275.slurm`); analysis `net_276.py`, written before the run; stub run in `stub_c/`; the fabric manager's ports at 11:03 in `pa_focus_*.txt`.

**Why the 7 nodes are weak suspects.**
- About 1,060 skx nodes were in service on 2026-11-11 (`sinfo`: 1,050 allocated, 6 idle, the rest drained or down).
- Two 64-node jobs placed at random share 64 × 64 / 1,060 ≈ 3.9 nodes on average, and 7 or more about 1 time in 10.
- The slow jobs also shared nodes with normal ones: L64b had 5 of P64's nodes, and L64 had 2 of A64's.
- So a full-speed rerun without the 7 would not show they were at fault, and a slow one would not say which node was. The job has to record where packets were lost.

**What loses a packet on Stampede3's Omni-Path network, and which counter shows it.** A pause of about 0.2 s fits PSM2's 160 ms resend timer (section 274), which runs only when a packet vanishes entirely.

| where the packet is lost | counter | who can read it |
|---|---|---|
| The receiving card finds the input queue of the destination process's receive context full (the process did not poll in time) and drops the whole packet | `RcvHdrOvr<N>` (N = receive context), per node | any user, in sysfs |
| Dropped on the way out of the sending card | `PktDrop`, `XmitDscd`, `TxDropped`, `port_xmit_discards`, per node | any user, in sysfs |
| Dropped by a switch after waiting too long at the head of a queue (congestion) | the switch port's discard counters | the fabric manager only |
| Corrupted on a cable: the link resends most such packets itself; the rest are dropped | resends `DcRxReplay`, `DcTxReplay`; dropped or failed `port_rcv_errors`, `link_error_recovery`, `local_link_integrity_errors`; the fabric manager's integrity ranking | any user (node side), the fabric manager (both sides) |

A packet whose payload finds the eager buffer full still delivers its header, so PSM2 can ask for it again at once. That should not cause a 160 ms wait. `DRIVER_EgrBufFull` is recorded anyway.

**The fabric manager answers users** (read-only queries with `opapaquery` from the login node, 2026-11-11 about 11:00; the same tool can also clear counters, which we never do).
- It reads every port every 120 s: 11,819 ports (10,271 on 341 switches, 1,548 on nodes).
- It keeps the last 10 readings (20 minutes), so it cannot show the slow jobs of 2026-11-10 and 2026-11-11.
- After each reading it clears the 32- and 8-bit error counters (`Clr32bitErrCntrs`, `Clr8bitErrCntrs` on). A node's own reading of those counters can therefore fall between two records; `net_276.py` reports that as "cleared".
- The fabric at 10:59 and 11:03:
  - No congestion: the worst port scored 89,619 against a threshold of 500,000,000, and discards were 0.0%.
  - 3 links were over the integrity threshold of 100. At 10:59: s454-U to core3 (600), s460-L to core2 (120), and s506-L to core2 (120). At 11:03: c486-001's own cable (1,265), s454-U to core3 (600), and s460-L to core2 (120).
  - c486-001 was drained for a reboot and was in none of our jobs.

**The record** (between runs only, never alongside one):
- **When:** at the start, after the probe, after the gate, after the warm-up, and after each rep. The record after the probe comes before the stop test, so a stopped job still records its probe.
- **Every node** (one task per node): link state from `opainfo` (width, speed, downgrade, quality) and every nonzero counter in sysfs (`ports/1/counters`, `hw_counters`, `ports/1/hw_counters`).
- **The fabric manager** (from the first node): for each 2-minute reading since the last record, up to its 10, the summary of all ports and the 40 ports with the most link errors and the most congestion.
- **Cost:** 0.02 s per node to read the counters, 0.02 s per query, plus srun's start-up for 9 record steps. Under a minute in all, under 1 SU.
- **Stub run** (login node, fake srun):
  - The srun commands are L64b's, line for line, plus the 9 record steps.
  - The job's output is identical apart from the stub directory's size.
  - The login node stood in for the nodes: 133 nonzero values per record, and `net_276.py` parsed all 40 ports of each ranking.

**Predictions** (written before the run; L64-1 to L64-7 and L64b-1, L64b-2 carry over):
- **NC-1:** if the probe runs below 900 M ev/s, the record after it shows lost packets, at least as many as the probe's 0.2 s stalls. The lost packets show as per-node drop counters or as switch discards in the fabric manager's readings.
- **NC-2:** those losses are receive-queue overflows (`RcvHdrOvr`) on 3 nodes or fewer, not switch discards or link errors (none of those near our racks at 11:00).
- **NC-3:** in a probe or rep at normal speed (control at 0.90 of 998.9 or above), every node's lost-packet counters stay at 0.

**What each outcome means:**
- **Slow, losses on a few nodes:** exclude those nodes and report them to TACC; the spare-node job (ask for 66 nodes, swap out a node that loses packets) becomes worth building.
- **Slow, losses spread over many nodes or in switches:** a fabric-wide problem; report it to TACC; no choice of nodes helps.
- **Slow, no losses anywhere:** the stalls have another cause, and section 274's reading is wrong.
- **Normal speed:** section 271's decision rule applies to the comparison.
- **User decision 2026-11-11:** make the read-only query and add the record. Job 3708456 was cancelled before it ran, and the new script was submitted as job 3708796 (skx, 64 nodes, the same exclusions). Results in section 276.

### §276 · L64b results: at normal speed, padded local 1 runs at 1.52× WPs 512 on uniform at 64 nodes (1.49× under the controller), and no node lost a packet (2026-11-11; skx batch job 3708796, 64 nodes)

> **Status: current.** Designs in sections 271, 273 and 275.
> - **Job:** 64 nodes, 11.9 minutes (2026-11-11 22:44–22:56), about 12.6 SUs; balance 1,809 SUs. The probe passed; the gate passed 66 of 66 (36 PHOLD, 30 with pad 1); the warm-up ran; all 25 timing runs were `ok`, and none was dropped for missing count waves. Nodes excluded as in section 275.
> - **Data:** `~/charades-data/f1/l64/b_j3708796`; analysis `l64_276.py` (output `l64_276_summary.txt`) and `net_276.py` (output `net_276_summary.txt`).

**Rates** (uniform, 64 nodes, 2,944 PEs; medians of 5 reps; P64 = job 3696079, 2026-11-08):

| setting | arm | rate (M committed ev/s) | rep spread (fastest ÷ slowest) | events per htram message | PE time per committed event (µs) | efficiency (%) | P64 rate (M ev/s) | this ÷ P64 |
|---|---|---|---|---|---|---|---|---|
| probe (P64's binary, WPs 512) | W 400 | 990.2 | one run | 5.6 | 2.973 | 99.95 | 998.9 | 0.991 |
| control (P64's binary, WPs 512) | W 400 | 1,006.6 | 1.06 | 5.6 | 2.925 | 99.95 | 998.9 | 1.008 |
| WPs 512 | controller | 982.4 | 1.05 | 5.5 | 2.997 | 99.93 | 980.0 | 1.002 |
| WPs 512 | W 400 | 1,001.3 | 1.03 | 5.6 | 2.940 | 99.95 | 998.9 | 1.002 |
| local 1 pad 1 | controller | 1,467.8 | 1.04 | 35.6 | 2.006 | 99.97 | – | – |
| local 1 pad 1 | W 400 | 1,522.3 | 1.03 | 37.0 | 1.934 | 99.99 | – | – |

PE time per committed event is 2,944 PEs ÷ the rate. Efficiency is committed ÷ executed events. All 26 runs committed the same count as P64 (11,581,457,663).

**Ratios** (higher is better for the first named):
- **local 1 pad 1 ÷ WPs 512:** 1.520 at W 400 and 1.494 under the controller. Paired by rep (runs minutes apart), every one of the 10 pairs is 1.457–1.540; medians 1.525 (W 400) and 1.496 (controller).
- **controller ÷ W 400:** 0.981 for WPs 512, 0.964 for local 1 pad 1.
- **The machine ran at P64's speed:** the control is 1.008 of P64's median and the probe 0.991. `charades-pplpad`'s WPs 512 ÷ the control, paired by rep, is 0.973–1.048 (median 1.004), so the `pp-pad` code does not change WPs.
- **Bundling** (across jobs, ÷ P64's best direct sends, 540.6 M ev/s): local 1's better arm is 2.82×, against WPs' 1.85× (P64's 1.85).
- **Across engines** (across jobs, three days apart, against P64's other engines on the same workload: Devastator at its best W 489.3 M ev/s, ROSS 295.2):
  - Charades ÷ Devastator is 3.00 under the controller and 3.11 at W 400, against P64's 2.00 (controller) and 2.01 (best fixed W).
  - Charades ÷ ROSS is 4.97 and 5.16, against 3.32 and 3.87.

**Why the lead grew from 1.10 at 16 nodes to 1.52 at 64.** Section 267's cost of 9.8 µs per message accounts for both settings' change from PD16 (section 270) to this job:

| setting | events per htram message, 16 → 64 nodes | messages per event through htram, 16 → 64 nodes | PE time per event through htram (µs), 16 → 64 nodes | change (µs) | 9.8 µs × change in messages per event (µs) |
|---|---|---|---|---|---|
| WPs 512 | 12.6 → 5.6 | 0.0792 → 0.1775 | 1.958 → 2.964 | +1.006 | +0.96 |
| local 1 pad 1 | 105.5 → 37.0 | 0.0095 → 0.0271 | 1.776 → 1.950 | +0.174 | +0.17 |

PE time per event through htram = PEs × execution time ÷ events sent through htram (W 400 at 64 nodes, W 400 at 16 nodes).
- With 4× the destination processes, each of WPs' per-PE buffers gets 4× fewer events per GVT update, so its messages shrink. Local 1 shares one buffer per destination process among a process's 23 PEs, so its messages start 8× larger and stay 6.6× larger.
- Local 1's own cost per event (the copy into the shared buffer and the shared counters) did not grow with the 4× destinations. Its per-event time rose by just what its extra messages cost.

**Network record** (section 275):
- **No packet was lost in any segment.** In every segment the change in each node's drop counters (receive-queue overflows `RcvHdrOvr`, `PktDrop`, `XmitDscd`, `TxDropped`, port discards and receive errors) is 0. So are the link counters (`DcRxReplay`, `DcTxReplay`, `link_error_recovery`, `local_link_integrity_errors`). The probe covers 48 nodes; the gate, warm-up and every rep cover all 64.
- **The first record missed 16 nodes.** The job's first srun step did not start on them within its 120 s limit; 48 nodes reported within 8 s. The probe's step launched normally 2.5 minutes later, and every later record reached all 64. The first version of `net_276.py` counted a missing earlier record as zero, so it showed those 16 nodes' totals since reset as losses during the probe. Fixed: a node needs both records.
- **Users can't reach the fabric manager from compute nodes.** Every `opapaquery` there failed ("No hfi names found"), and `opainfo` printed nothing; the sysfs counters read on all 64 nodes. To query it for a future slow job, query from a login node within 20 minutes of the slow segment.
- **Earlier totals:** at their first record, 44 of the 64 nodes carried nonzero receive-queue overflow totals from before this job (median about 50,000; the largest, c489-072, 1.57 billion). These cannot be tied to any job.
- **Cost:** the first record's 2.5 minutes (about 2.7 SUs); every later record took a few seconds.

**Predictions:**
- **Right:**
  - L64-1: one count, P64's.
  - L64-2: WPs within ±5% of P64; 5.5–5.6 events per message.
  - L64-4: 1.52, in 1.15–1.55.
  - L64-5: the controller's ratio 1.494, within 0.05 of 1.520; controller ÷ W 400 0.96–0.98.
  - L64-6: lowest efficiency 99.93%; local 1's spread 1.03–1.04.
  - L64-7: bundling 2.82, in 2.1–2.9.
  - L64b-1: control 1.008, probe 0.991.
  - L64b-2: median 1.004.
  - NC-3: no lost packets at normal speed.
- **Wrong in part:** L64-3. 35.6–37.0 events per message, against 40–70 predicted; the 92–97% of messages sent at a GVT update was right (85% or more predicted).
- **Not tested:** NC-1 and NC-2, since the probe ran at normal speed. Section 274's slow jobs remain unexplained, and this job cannot say whether the 7 excluded nodes were at fault.

**Section 271's decision rule:** local 1 ÷ WPs 512 is at least 1.10 under both arms (1.49 and 1.52), so the user decides how it enters the paper:
- (a) a paragraph or figure on uniform at scale, with the tables kept on F1's settings;
- (b) uniform's setting in the tables, which needs the `pp-pad` branches merged (engine tier) and uniform rerun at 1–64 nodes.

### §277 · Padded local 1 as a candidate setting for uniform in the tables, 1–64 nodes (job UL design, 2026-11-12; written before any runs)

> **Status: design (results: 1–16 nodes in 278; 32 and 64 nodes stopped by their probes in 282, rerun as 3716315 and 3716316, results in a later section listed in INDEX).** User decision 2026-11-12, after section 276: padded local 1 becomes one of uniform's htram settings in the tables, which take Charades' controller at the better setting per node count.
> - **Code:** Charades `main` 9f7480a merges `pp-pad` (`--agg-pp-local`, `--agg-pp-pad`); htram `pdes` fast-forwarded to 978e065. Both settings default to the old behaviour, so existing configurations run unchanged.
> - **Mac tests on the merge** (2026-11-12):
>   - **Engine tier** with the five local-buffer configs named: 4,637 of 4,668 passed, and the five named configs passed every run, including their 20 repeats at the multi-PE shapes. The 31 that did not pass are the known ones from section 267, and none runs the merged code:
>     - 27 VLSI conservative lookahead aborts;
>     - the intermittent `--sched-park` hang in VLSI `agg_ctl_park_bucket_pp`, twice this time (2 × 2 on `file`, and 1 × 4 on `base`, a shape where it had not been seen). PP there runs at the default local size and packed counters, so on the old code; the paper's runs do not use `--sched-park`;
>     - dragonfly `gentime` with `bucket_hold_early` and `bucket_hold_pads19` at 2 × 2, the hold hang recorded in applications.md, which has no aggregation.
>   - **Change tier with `--agg-pp-pad=1`, then with `--agg-pp-pad=2`,** on the nine PP configs (deadline, controller, eager and blocking, and the five local-buffer configs): 297 of 297 each.
> - **Trees on Stampede3:** `charades-r6` (main 9f7480a) with `htram-r6` (978e065), built serially; its option strings match `charades-pplpad`'s binary. Reference: `charades-r5` (85a2aad), F1's and P64's binary.
> - **Files:** `~/charades-data/f1/ul277/ul277.slurm`; stub runs `stub_cmds_{small,n32,n64}.txt`; per-arm flags `flag_table.txt`.

**Jobs** (Charades only; Devastator and ROSS keep F1's, R8's and P64's numbers):

| job | nodes | partition | node counts | reps |
|---|---|---|---|---|
| UL small | 16 | skx-dev, with a twin on skx | 8, 4, 2 and 1 side by side on nodes 1–15 (the batch host idle, section 261), then 16 | 3 |
| UL 32 | 32 | skx | 32 | 5 |
| UL 64 | 64 | skx | 64 | 5 |

- **Workload and launch:** uniform PHOLD on F1's settings (end time 2,048,000, bucket 8, margin 8, 128 LPs per PE, 2 × 23 PEs per node, `+lci_ndevices 23`, `numactl --localalloc`, `+mempool_remote_free`). Same exclusions as section 275 (c455-081 and the 7 nodes).
- **New setting** (`charades-r6`): PP 512 with `--agg-pp-local=1 --agg-pp-pad=1`, under the controller and at F1's fixed W (300 and 400; at 64 nodes P64's 400 and 500).
- **Reference** (`charades-r5`): the table's setting at that node count, under the controller only: WPs 512 at 1 node, PP 512 at 2, 4 and 8, WPs 512 at 16, 32 and 64. Its commands are F1's, R8's and P64's apart from the nodes and the output paths (checked against R8's and P64's stub commands).
- **Order:** in even reps the two settings, and the new setting's arms, run in reverse order.
- **Probe** (as L64b): before the gate, the reference binary runs WPs 512 at W 400 at the job's largest node count. The job stops below 0.90 of F1's median there (16 nodes 383.3, 32 nodes 639.5 M ev/s; 64 nodes P64's 998.9).
- **Gate** (as L64b): the PP and local 1 test configurations on 2 nodes, with packed and padded counters.
- **Network record** (section 275): sysfs counters on every node, between runs only; no fabric-manager queries, which fail on compute nodes (section 276).
- **Cost:** about 23 SUs (UL small 4, UL 32 6, UL 64 13).

**The table's values that would change**, from F1 (jobs 3689513 and 3688916), R8 (3695259) and P64 (3696079); M committed ev/s, controller medians:

| nodes | 1 | 2 | 4 | 8 | 16 | 32 | 64 |
|---|---|---|---|---|---|---|---|
| table's setting | WPs 512 | PP 512 | PP 512 | PP 512 | WPs 512 | WPs 512 | WPs 512 |
| rate (M ev/s) | 45.9 | 79.3 | 151.9 | 229.0 | 384.5 | 627.8 | 980.0 |
| events per htram message | 74.8 | 104.6 | 101.9 | 36.7 | 12.6 | 8.3 | 5.6 |
| committed events | 180,941,384 | 361,891,305 | 723,815,947 | 1,447,683,514 | 2,895,361,579 | 5,790,767,104 | 11,581,457,663 |

**Estimate** (section 267's 9.8 µs per message; local 1's own extra per event sent to another process: 0.48 µs over WPs, at both 16 and 64 nodes, and 0.09 µs over PP, at 16 nodes; local 1's events per message fitted to 105.5 at 16 nodes and 37.0 at 64, about 512 at 1–4 nodes). Local 1 ÷ the table's setting comes out at 0.97, 0.99, 0.98, 1.08, 1.11, 1.29 and 1.51 at 1, 2, 4, 8, 16, 32 and 64 nodes. At 1–4 nodes the table's settings already send 75–105 events per message, so there is little left to save.

**Predictions** (written before any runs):
- **UL-1. Counts:** one count per node count over every run, equal to F1's (table above).
- **UL-2. The reference repeats F1:** within ±5% of the table's rate at every node count.
- **UL-3. Local 1 ÷ the reference** (controller, median of the per-rep ratios):

| nodes | 1 | 2 | 4 | 8 | 16 | 32 | 64 |
|---|---|---|---|---|---|---|---|
| predicted range | 0.90–1.02 | 0.93–1.05 | 0.93–1.05 | 0.98–1.15 | 1.03–1.20 | 1.20–1.40 | 1.40–1.60 |

- **UL-4. Local 1's messages:** 80–130 events per message at 16 nodes, 45–80 at 32 and 33–42 at 64.
- **UL-5. The controller:** 0.93–1.03 of local 1's better fixed W at every node count.
- **UL-6. Quality:** efficiency at least 99.8% in every run; local 1's rep spread (fastest ÷ slowest) at most 1.10 under the controller.

**How results enter the tables** (decided before the runs):
- **Uniform's cell** at each node count is Charades' controller at the better setting, as now. Local 1's controller median replaces F1's value where it is higher, and the old value stays where it is not. Devastator and ROSS keep F1's, R8's and P64's numbers, so the ratios become cross-job; the table's caption says so.
- **Where the reference misses UL-2** (more than ±5% from F1), that node count's local 1 number is not used: that node count is rerun, not scaled.
- **The uniform row of the bundling table** (htram ÷ direct sends) takes local 1 where it wins, as a cross-job ratio, marked as such.
- **Not changed:** σ 4,000 and every Gaussian workload keep their settings (local 1 ran at 0.84 of PP 512 on σ 4,000 at 16 nodes, section 270).
- **Submitted 2026-11-12** (after the Mac tests passed and both branches were pushed): UL small 3711817 (skx) with its twin 3711818 (skx-dev; the copy that starts first cancels the other), UL 32 3711819 (skx), UL 64 3711820 (skx). Output `$WORK/charades-runs/ul277/<group>_j<id>`, logs `ul277_<id>.out`. Results: 1–16 nodes in section 278; 32 and 64 nodes in a later section (section 279 went to the 1-node profile).

### §278 · UL results, 1–16 nodes: padded local 1 is 1.17× the table's setting on uniform at 16 nodes, but 0.61–0.80 of it at 1–8 (2026-11-12; skx-dev batch job 3711818, 16 nodes)

> **Status: current (1–16 nodes; 32 and 64 nodes pending, in a later section); superseded in part by section 280** (the 1-node loss: contention on the shared buffer's counters). Design in section 277. The 1-node profile asked for after this section: sections 279 and 280.
> - **Job:** the skx-dev copy, 3711818, started first and cancelled its skx twin, 3711817. It ran 16 nodes for 7.5 minutes (2026-11-12 05:52–06:00), about 2 SUs. Probe: the reference binary's WPs 512 at W 400 on 16 nodes ran at 395.3 M ev/s, against F1's 383.3. Gate 66 of 66. All 60 timing runs `ok`; none dropped.
> - **Data:** `~/charades-data/f1/ul277/small_j3711818`; analysis `ul_278.py` (written before the runs; output `ul_278_small_summary.txt`).

**Rates** (uniform, controller arms, medians of 3 reps; reference = the table's setting on F1's binary, `charades-r5`):

| nodes | reference setting | reference (M ev/s) | reference ÷ F1's table value | local 1 pad 1 (M ev/s) | local 1 ÷ reference, paired median (higher is better for local 1) | per-rep ratios | local 1 rep spread (fastest ÷ slowest) | events per htram message, reference / local 1 |
|---|---|---|---|---|---|---|---|---|
| 1 | WPs 512 | 45.5 | 0.992 | 34.5 | 0.759 | 0.751 / 0.759 / 0.760 | 1.01 | 74.5 / 227.8 |
| 2 | PP 512 | 81.8 | 1.032 | 50.2 | 0.610 | 0.610 / 0.626 / 0.520 | 1.18 | 104.5 / 327.0 |
| 4 | PP 512 | 153.2 | 1.009 | 117.5 | 0.774 | 0.718 / 0.820 / 0.774 | 1.16 | 99.5 / 300.7 |
| 8 | PP 512 | 232.1 | 1.014 | 185.8 | 0.800 | 0.685 / 0.800 / 0.896 | 1.29 | 36.6 / 188.4 |
| 16 | WPs 512 | 386.1 | 1.004 | 450.5 | 1.172 | 1.172 / 1.177 / 1.167 | 1.02 | 12.6 / 104.7 |

- **Counts:** one per node count, equal to F1's.
- **Machine speed:** the reference is 0.992–1.032 of F1's table values, so the cross-job comparison holds.
- **Local 1's fixed W** (M ev/s, W 300 / W 400): 34.4 / 27.2 at 1 node, 41.3 / 43.5 at 2, 109.7 / 92.7 at 4, 199.9 / 173.8 at 8, 463.5 / 415.0 at 16. The fixed-W arms at 2 nodes vary a lot between reps (spread 1.18 and 1.47).

**Where local 1 loses at 1–8 nodes** (controller arms, medians):

| nodes | GVT rounds per second, reference / local 1 | messages sent urgent, reference / local 1 (share) | messages sent at a GVT update, reference / local 1 (share) | extra PE time per event sent to another process, local 1 − reference (µs) |
|---|---|---|---|---|
| 1 | 8,079 / 6,181 | 0.16 / 0.36 | 0.84 / 0.11 | +0.64 |
| 2 | 7,158 / 4,471 | 0.12 / 0.25 | 0.16 / 0.20 | +0.94 |
| 4 | 6,479 / 5,228 | 0.08 / 0.16 | 0.71 / 0.78 | +0.42 |
| 8 | 4,974 / 4,100 | 0.01 / 0.06 | 0.96 / 0.93 | +0.42 |
| 16 | 3,752 / 4,669 | 0.01 / 0.07 | 0.99 / 0.93 | −0.28 |

- Both settings complete the same number of GVT rounds (28,000–32,300); local 1 takes longer for each. Efficiency is 99.85–99.95% in both, so the time is not spent rolling back. Where it goes is not measured: the blocked-time fields need a diagnostic these timing runs do not carry.
- Local 1's messages are 2–5× larger than the reference's at 1–8 nodes, so message count is not the cost.
- **Not explained.** One reading fits the trend, untested: at 1–8 nodes a process has only 1–15 destination processes, so its 23 PEs insert into the same few shared buffers and contend for the same counters (section 270 found same-destination atomics at about 12% of cycles at 16 nodes, with 31 destinations). The insertion rate into one destination's buffer falls from about 8.6 M events/s at 1 node to 0.4 M at 16. The extra time does not fall evenly with that rate (2 nodes is the worst), so this reading is incomplete at best.

**Predictions (section 277):**
- **Right:**
  - UL-1: the counts.
  - UL-2: reference within ±5% of F1 at every node count.
  - UL-3 at 16 nodes: 1.17, in 1.03–1.20.
  - UL-4 at 16 nodes: 104.7 events per message, in 80–130.
  - UL-5 at 1 and 16 nodes: 1.00 and 0.97 of local 1's better fixed W.
- **Wrong:**
  - **UL-3 at 1–8 nodes:** 0.61–0.80, against 0.90–1.15. The estimate applied local 1's extra cost over PP measured at 16 nodes (0.09 µs per event) to 1–8 nodes; the measured extra over the reference there is 0.42–0.94 µs.
  - **UL-5 at 2, 4 and 8 nodes:** 1.155, 1.071 and 0.929, against 0.93–1.03. The fixed-W arms vary a lot between reps there.
  - **UL-6 in part:** one arm's lowest efficiency is 99.76% (1 node, W 400), against at least 99.8%; local 1's controller spread is 1.16–1.29 at 2–8 nodes, against at most 1.10. At 1 and 16 nodes it is 1.01–1.02.

**Section 277's rule applied:**
- **Uniform's 16-node cell becomes local 1's 450.5 M ev/s.** Charades ÷ Devastator rises from 2.01 to 2.36 and Charades ÷ ROSS from 4.23 to 4.96, both cross-job (Devastator and ROSS from F1).
- **The 1–8-node cells keep F1's values** (WPs 512 at 1 node, PP 512 at 2–8).
- **The front page's tables change once the 32- and 64-node jobs report** (a later section). Changing the 16-node cell alone would move the 16→32 per-node column.
- **For the paper:** uniform's htram setting then depends on scale: local 1 from 16 nodes, the old settings below. The paper needs the rule and its reason; the reason is open (above).

### §279 · Why local 1 loses at 1 node: a profile, and fewer copies into the shared buffer (job PF1 design, 2026-11-12; written before any runs)

> **Status: design (results in section 280).** User decision 2026-11-12, after section 278: profile local 1 at 1 node.
> - **Job:** 1 node, skx-dev with a twin on skx; tree `charades-r6` (main 9f7480a, htram `pdes` 978e065), gated in job 3711818; no network, so no probe. About 10 minutes, under 0.2 SU.
> - **Files:** `~/charades-data/f1/pf279/pf279.slurm`; stub run `stub_cmds.txt`; per-arm flags `flag_table.txt`.

**The question.** At 1 node local 1 runs at 0.76 of WPs 512 and about 0.73 of PP 512 (section 278). Both settings complete the same GVT rounds, but local 1 takes about 0.32 µs more per committed event. Is that time spent working (in htram's send path) or waiting?

**How local 1 sends now** (PP, `--agg-pp-local=1`):
- **Where:** each process holds one shared buffer per destination process, plus that buffer's counters (reservation index, done count, limit, minimum key).
- **Insert:** a PE sending an event to another process copies it straight into that destination's shared buffer. It reserves a slot with a compare-and-swap on the reservation index, copies the event, then adds 1 to the done count. At the default local size of 16, a PE gathers 16 events in its own buffer first and copies them with one reservation.
- **At 1 node:** each process has one destination, so all 23 of its PEs make these atomic updates on the same few counters, for every event. At 16 nodes they spread over 31 destinations; at 64 over 127.

**Hypothesis (H):** the extra time is contention on those counters. Every event's reservation and done-count update moves the counters' cache line between cores, and with one destination all 23 PEs share that line.

**Runs** (1 node, uniform, F1's PHOLD settings, 2 × 23 PEs, fixed W 300, the better fixed W at 1 node for local 1 and WPs in section 278):
- **Part A, timing** (end 2,048,000, 5 reps, settings reversed in even reps, no diagnostics):

| setting | flags | why |
|---|---|---|
| WPs 512 | `--agg-mode=0` | F1's 1-node setting |
| PP 512 | `--agg-mode=2` (local 16, packed counters) | F1's 2–8-node setting |
| PP 512 pad 1 | `--agg-pp-pad=1` | padding alone |
| local 4 pad 1 | `--agg-pp-local=4 --agg-pp-pad=1` | a quarter of local 1's reservations per event |
| local 1 pad 1 | `--agg-pp-local=1 --agg-pp-pad=1` | the new setting |

- **Part B, profiles** (check runs after part A, end 8,192,000): one run each of WPs 512, PP 512, local 4 pad 1 and local 1 pad 1, under `perf record -e cycles:u -F 1999` in task 0 (one process, 23 PEs) from 2.5 s after launch. Reports by symbol and by library, and annotations of htram's send path (`copyLocalToNodeBuf`, `insert`, `insertValue`, `shipSharedWithLocalPP`, `shipSharedPP`, `flushDue`, `flushOrder`).
- **Stub run:** 30 srun commands (1 warm-up, 25 timing, 4 profiles); each setting adds only its own flags, and only the profile runs go through the perf wrapper.

**Predictions** (written before any runs):
- **PF-1. Checks:** one count, 180,941,384, in every timing run; WPs 512 at W 300 within ±5% of F1's 46.9 M ev/s.
- **PF-2. The loss repeats:** local 1 pad 1 ÷ PP 512 is 0.68–0.80.
- **PF-3. Padding alone does nothing here:** PP 512 pad 1 ÷ PP 512 is 0.97–1.03 (one destination, so the counters cannot share a line with another destination's).
- **PF-4. The perturbation (H):** local 4 pad 1 ÷ PP 512 is at least 0.90, because it makes a quarter of local 1's reservations per event. At 0.80 or below, the cost does not follow the number of reservations, and H is wrong.
- **PF-5. Closure (H):** at least 70% of local 1's extra time per committed event over PP 512 is in htram's send path (the functions above). The annotation puts those cycles on the atomic instructions on the shared counters. If the extra time is instead in the scheduler loop, LCI progress or the receive path, H is wrong: the PEs are waiting, not working.

**What it decides:**
- **If H holds:** the paper says local 1 pays per-event atomics on a shared buffer, a cost spread out only when there are many destination processes, and uniform uses local 1 from 16 nodes. Batching (local 4) may serve every scale; that would be a separate decision.
- **If H fails:** the reason is still open, and the profile says where to look next.
- **Submitted 2026-11-12:** 3712467 (skx) and its twin 3712468 (skx-dev); the copy that starts first cancels the other. Output `$WORK/charades-runs/pf279/j<id>`, log `pf279_<id>.out`.

### §280 · PF1 results: at 1 node, local 1 loses its time in the copy into the shared buffer, almost all of it on two atomic instructions; local 4 recovers most of it but sends as many messages as local 16 (2026-11-12; skx-dev job 3712468, 1 node)

> **Status: current.** Design and predictions in section 279.
> - **Job:** the skx-dev copy, 3712468, started first and cancelled its skx twin, 3712467. It ran 1 node (c454-083) for 6.8 minutes (2026-11-12 12:46–12:53). The warm-up, all 25 timing runs and all 4 profile runs finished `ok`, every one with count waves.
> - **Data:** `~/charades-data/f1/pf279/j3712468`; the `perf.data` files stay on Stampede3 in `$WORK/charades-runs/pf279/j3712468/perf`. Analysis `pf_prof.py`, written before the runs, with one fix after them (below); output `pf_279_summary.txt`.

**Rates** (uniform, fixed W 300, 1 node, 2 × 23 PEs; medians of 5 reps):

| setting | rate (M committed ev/s) | ÷ PP 512, paired median (higher is better for the setting) | per-rep ratios | rep spread (fastest ÷ slowest) | events per htram message | GVT rounds per second |
|---|---|---|---|---|---|---|
| WPs 512 | 45.5 | 0.989 | 0.983 / 0.989 / 1.006 / 1.002 / 0.962 | 1.06 | 82.5 | 7,751 |
| PP 512 (local 16, packed counters) | 46.1 | 1 | – | 1.06 | 131.2 | 7,812 |
| PP 512 pad 1 | 46.2 | 1.003 | 1.003 / 1.011 / 1.012 / 1.002 / 1.000 | 1.06 | 131.2 | 7,824 |
| local 4 pad 1 | 42.0 | 0.921 | 0.921 / 0.903 / 0.921 / 0.921 / 0.901 | 1.07 | 130.1 | 7,095 |
| local 1 pad 1 | 34.0 | 0.742 | 0.740 / 0.745 / 0.735 / 0.742 / 0.754 | 1.04 | 276.5 | 5,781 |

- **Counts:** one, 180,941,384 committed events in every run, equal to F1's. Efficiency is at least 99.98% in every run, so no setting loses time to rollback.
- **Local 1 repeats section 278's loss:** 0.742 of PP 512 here, against 0.759 of WPs 512 there.
- Every setting does the same work in about the same number of GVT rounds (30,574–30,813 per run); the slower settings complete fewer rounds per second.

**Where the time goes.** One profile run per setting: `perf` cycles:u in task 0 (one process, 23 PEs). Each group's share of the samples times the setting's PE time per committed event (46 PEs ÷ the rate above) gives µs of PE time per committed event (lower is better):

| group | WPs 512 | PP 512 | local 4 pad 1 | local 1 pad 1 | local 1 − PP 512 |
|---|---|---|---|---|---|
| htram send path | 0.023 | 0.044 | 0.088 | 0.390 | +0.346 |
| … of which the copy into the shared buffer | – | 0.014 | 0.052 | 0.359 | +0.345 |
| htram receive | 0.050 | 0.044 | 0.040 | 0.037 | −0.007 |
| scheduler and polling | 0.032 | 0.033 | 0.042 | 0.033 | 0.000 |
| LCI / PSM2 progress | 0.012 | 0.010 | 0.020 | 0.014 | +0.004 |
| engine and model | 0.600 | 0.619 | 0.627 | 0.611 | −0.008 |
| locks | 0.019 | 0.016 | 0.022 | 0.021 | +0.004 |
| memory | 0.041 | 0.015 | 0.013 | 0.010 | −0.005 |
| other | 0.117 | 0.108 | 0.120 | 0.100 | −0.008 |
| symbols below 0.2% each | 0.117 | 0.107 | 0.124 | 0.135 | +0.028 |
| **total** | 1.010 | 0.997 | 1.095 | 1.351 | **+0.354** |

- The copy is `copyToNodeBuf` at local 16 (16 events at a time) and `copyLocalToNodeBuf` below 16. WPs has no shared buffer.
- **Checks on the profiles:** the profile runs (end 8,192,000) ran at 0.97–0.99 of the rates above, with one count, 723,844,217. Their sample counts (674,000–923,000) are 6–8% more than 23 PEs × 1,999 Hz give over each run's measured time after the 2.5 s delay (a process also runs before and after the measured part). So the PEs are in user code almost all the time, spinning included, and cycles:u sees nearly all of it.
- **Closure:** 0.346 µs of local 1's extra 0.354 µs per committed event (97.6%) is in htram's send path, and 0.345 µs of that is the copy itself. No other group moves by more than 0.03 µs.

**On which instructions** (`perf annotate` of `copyLocalToNodeBuf`; share of that function's samples; a sample usually lands on the instruction after the one that stalled):

| the samples follow | what it does | local 1 pad 1 | local 4 pad 1 |
|---|---|---|---|
| `lock add` on `done_count[d]` | marks this PE's copied events as written | 40.2% | 40.5% |
| `lock cmpxchg` on `get_idx[d]` | reserves the slots | 38.6% | 25.2% |
| the plain load of `get_idx[d]` before it | reads the next free slot; misses, because another PE wrote the line last | 17.2% | 18.8% |
| `lock cmpxchg` on `min_key[d]` | lowers the buffer's earliest timestamp, when needed | 0.7% | 2.7% |
| everything else, including writing the event into its slot | | 3.3% | 12.8% |

- At local 1, 96.0% of the copy's samples are on the two shared counters, `get_idx` and `done_count`. Pad 1 puts each on a line of its own, so every copy takes two contended lines from whichever PEs wrote them last.
- **The cost per copy rises with the copy rate.** Local 1 copies once per event: 0.36 µs per copy. Local 4 copies about once per 4 events: 0.052 × 4 ≈ 0.21 µs per copy. A fixed cost per atomic would make those equal. With contention, each atomic waits for the line to pass through the PEs ahead of it, so the cost grows with the rate, as measured.
- **The rate.** Charades sends through htram with scope all, so a process's own process is also a destination: at 1 node each process has 2 destination processes, the other one and its own. At local 1 each process copies about 17 M events per second, so each destination's counters take about 8.5 M copies per second from 23 PEs, one every 120 ns.

**Predictions (section 279):**
- **Right:**
  - PF-1: one count, equal to F1's; WPs 512 at 45.5 M ev/s, 0.971 of F1's 46.9 (within ±5%).
  - PF-2: local 1 pad 1 ÷ PP 512 is 0.742, in 0.68–0.80.
  - PF-3: PP 512 pad 1 ÷ PP 512 is 1.003, in 0.97–1.03.
  - PF-4: local 4 pad 1 ÷ PP 512 is 0.921, at least 0.90. From the medians it is 0.911; the lowest rep is 0.901.
  - PF-5: 97.6% of the extra time is in htram's send path, against at least 70%, and the annotation puts it on the atomics on the shared counters.
- **Fixed in the analysis after the run:** `pf_prof.py` filed local 16's copy function, `copyToNodeBuf`, under "other", and first gave the closure as 101.6%. It now counts that function in the send path; nothing else changed.

**Hypothesis H holds at 1 node.** Local 1's loss there is contention on the shared buffer's two counters:
- each event makes one reservation and one add;
- every PE of the process makes them on the same two lines;
- those two counters take 96% of the copy's 0.36 µs.

The perturbation agrees: local 4 makes a quarter of the copies and cuts the copy's cost 6.9× (0.359 → 0.052 µs per committed event).

**Not explained by this job:**
- **Local 4's own loss** (0.098 µs per committed event against PP 512): 0.044 µs is the send path. The other 0.054 µs is spread over every group, none above 0.017 µs.
- **2 nodes, the worst point in section 278** (0.61; +0.94 µs per event sent to another process) is not profiled. Contention alone would predict a smaller loss there than at 1 node: each destination's counters take about 3.1 M copies per second (4 destination processes), against 8.6 M at 1 node. So something else adds to it.

**Local 4 does not keep local 1's message savings.** Section 279 said local 4 might serve every scale. As built, it does not: its messages carry 130.1 events, the same as local 16's 131.2, against local 1's 276.5. Section 268 had already found the reason at 16 nodes, the flush race (89% of local 4's messages on uniform were one PE's 1–3 local events sent alone, 9.5 events per message), and section 279 overlooked it. The code (`flushDue` and `shipSharedWithLocalPP` in htram):
- At a GVT update with local below 16, each PE checks each destination. If its own leftover events or the shared buffer hold a due event, it reserves the rest of the shared buffer, adds its own leftovers, and sends that as a message. If another PE has already reserved the buffer to send it, the PE sends its leftovers alone.
- At local 4, most PEs hold 1–3 leftovers toward each destination, so most PEs send a message of their own at each update. Local 16 does the same: each PE sends its partly filled local buffer.
- At local 1 no PE holds leftovers. A PE sends only if due events reached the shared buffer since the last send, and the first PE to flush usually takes them all.
- Section 267's Mac measurement showed the same: 16.5 events per message at local 4, against 15.1 at local 16 and 21.9 at local 1.

**Corrections to sections 278 and 279:**
- Both say a process has one destination process at 1 node (and 31 at 16 nodes, 127 at 64). Under scope all it has 2, 32 and 128.
- Section 278's insertion rates per destination (8.6 M events/s at 1 node, 0.4 M at 16) already used 2 and 32. No conclusion changes.

**What it decides:**
- **For the paper, the reason uniform's setting depends on scale:**
  - Local 1 makes one reservation and one add per event, on counters shared by a process's 23 PEs.
  - At 1 node (2 destination processes) those counters take about 8.5 M copies per second each. The copies cost 0.36 µs of PE time per event, and local 1 runs at 0.74 of PP 512.
  - At 16 nodes (32 destinations) the same copies spread over 16× as many counters. Local 1 then wins on message count: 1.17× the table's setting at 16 nodes (section 278) and 1.52× WPs 512 at 64 (section 276).
  - Section 277's rule already gives this: 1–8 nodes keep F1's settings. No table changes here.
- **One setting for every scale would need a design change in htram.** For example, at a GVT update each PE copies its leftovers into the shared buffer, and the last of the process's PEs to flush sends it. That would keep local 16's few copies and send one message per destination per update. It is not written or measured, and it needs a GVT-liveness argument (the update reaches a process's PEs at different times).

### §281 · Charades' htram setting in each paper cell, 1–64 nodes (2026-11-12; no new job: from F1, R8, F1-32, P64, UL, F5a2, F5-32b and A64)

> **Status: current.** User request 2026-11-12, after section 280: document the best htram setting for each case. The front page's settings table comes from here.
> - **Scripts and outputs:** `~/charades-data/f1/settings_281_phold.py` → `settings_281_phold.txt`; `settings_281_apps.py` → `settings_281_apps.txt`.

**Rule.** Each cell takes the setting whose controller median is highest among the settings that cell's job ran, as F1's tables already did (section 243).
- The 8-node column comes from job R8 alone (section 261).
- Uniform's 16-node cell is local 1, from job UL (section 278), under section 277's rule.
- These choices reproduce every Charades rate in the front page's PHOLD table.

**Settings:**
- **PP 512 / PP 2,048:** `--agg-mode=2 --agg-buffer=512` or `2048`. Each process has one shared buffer per destination process, and each PE copies into it 16 events at a time.
- **WPs 512:** `--agg-mode=0 --agg-buffer=512`. Each PE has its own buffer per destination process.
- **local 1:** PP 512 with `--agg-pp-local=1 --agg-pp-pad=1`. Each event is copied into the shared buffer as it is sent, and each destination's counters sit on their own cache lines.
- **direct sends:** no htram.

**PHOLD** (the setting at each node count; runner-up ÷ best is the other setting's controller median ÷ the chosen one's, so lower means a clearer choice):

| workload | setting at 1 / 2 / 4 / 8 / 16 / 32 / 64 nodes | settings the paper jobs ran | runner-up ÷ best at 1 / 2 / 4 / 8 / 16 / 32 / 64 |
|---|---|---|---|
| σ 100 | PP 2,048 at every node count | PP 2,048 | – |
| σ 500 | PP 2,048 at every node count | PP 2,048 | – |
| σ 1,000 | PP 512 / PP 2,048 / PP 2,048 / PP 2,048 / PP 2,048 / PP 2,048 / PP 2,048 | PP 2,048 and PP 512 (PP 2,048 alone at 32) | 0.944 / 0.956 / 0.977 / 0.985 / 0.971 / – / 0.987 |
| σ 2,000 | PP 512 at every node count | PP 512 | – |
| σ 4,000 | PP 512 at every node count | PP 512 | – |
| uniform | WPs 512 / PP 512 / PP 512 / PP 512 / local 1 / WPs 512 / WPs 512 | PP 512 and WPs 512; local 1 at 1–16 (32 and 64 pending) | 0.974 / 0.951 / 0.867 / 0.983 / 0.857 / 0.834 / 0.847 |
| lookahead 10, σ 500 | PP 2,048 at every node count | PP 2,048 | – |
| lookahead 10, σ 2,000 | WPs 512 / WPs 512 / WPs 512 / PP 512 / PP 512 / WPs 512 / WPs 512 | PP 512 and WPs 512 | 0.986 / 0.996 / 0.995 / 0.999 / 0.996 / 0.943 / 0.971 |

- **Uniform's runner-up:** at 1–8 nodes it is the other of PP 512 and WPs 512. Local 1 ran there too, at 0.61–0.80 of the chosen setting (section 278). At 16 nodes the runner-up is WPs 512, the same job's reference (386.1 against local 1's 450.5 M ev/s).
- **The single-setting workloads** (σ 100, σ 500, σ 2,000, σ 4,000, lookahead 10 σ 500) took their setting from the 1/4/16-node long runs that compared PP 512 and PP 2,048 (sections 124 and 130, fixed in section 140). The other setting was not rerun at 2, 8, 32 or 64 nodes.

**Applications:**

| application | setting at every node count | what it was chosen against | runner-up ÷ best |
|---|---|---|---|
| dragonfly | WPs 512 | PP 512 at 1 and 4 nodes (section 179); direct sends in every paper job | PP 512 0.89–0.92 (section 179); direct sends: htram ÷ direct 1.12–1.17 at 32–64 nodes (front page) |
| traffic | PP 2,048 (the only setting the controller ran) | WPs 512 at W 500 only | WPs 512 ÷ PP 2,048, both at W 500: 0.99 / 1.00 / 0.98 / 0.97 / 0.99 / 0.99 / **1.05** at 1 / 2 / 4 / 8 / 16 / 32 / 64 nodes |
| VLSI | direct sends | PP 2,048 and WPs 512 at 1 and 4 nodes (section 195) | PP 2,048 0.65–0.83 of direct, WPs 512 0.96–0.99 |

**Close calls and gaps:**
- **Lookahead 10, σ 2,000 at 1–16 nodes:** PP 512 and WPs 512 are within 1.4% of each other, inside the reps' spread. The table takes the higher median.
- **Uniform at 32 and 64 nodes:** local 1 is pending (jobs 3711819 and 3711820 were stopped by their probes, section 282; reruns 3716315 and 3716316). At 64 nodes it ran at 1.49× WPs 512 under the controller in job L64b (section 276), so it will probably take both cells. This table changes when UL reports.
- **Traffic at 64 nodes is not settled.** WPs 512 is 1.05× PP 2,048 at W 500, but it never ran at W 1,000 (PP 2,048's best fixed W there, 4,308.2 M ev/s) or with the controller. The table keeps PP 2,048.
- **Local 1 is a candidate on uniform only:**
  - σ 4,000: 0.84 of PP 512 at 16 nodes (section 270).
  - Uniform at 1–8 nodes: it loses to contention on the shared buffer's counters (section 280).

### §282 · UL at 32 and 64 nodes: both probes stopped their jobs (the fabric was congested: switch back-pressure about 200× normal, no lost packets); resubmitted (2026-11-13; skx batch jobs 3711819 and 3711820, stopped; reruns 3716315 and 3716316)

> **Status: current (no results; the reruns' results go in a later section).** Design in section 277.
> - **Jobs:** 3711820 (64 nodes) ran 2026-11-12 21:04–21:08 and 3711819 (32 nodes) 21:07–21:11. Each stopped after its probe, before the gate. They cost about 6.5 node-hours together.
> - **Data:** `~/charades-data/f1/ul277/fail/` (the probe run and the network records `net/start.nodes` and `net/probe.nodes` of each job).

**The probes** (reference binary `charades-r5`, WPs 512 at W 400, one run; M committed ev/s, higher is better):

| nodes | probe rate | F1 / P64 rate | probe ÷ F1 / P64 | stop below (0.90×) |
|---|---|---|---|---|
| 32 | 429 | 639.5 | 0.67 | 575 |
| 64 | 518 | 998.9 | 0.52 | 899 |

**Diagnosis, from each node's network-card counters** (record before and after the probe, deltas per node):
- **No packet was lost on any node in either job.** There were no receive-queue overflows (`RcvHdrOvr`), drops or link resends. This is not the 0.2 s retransmission stall of the slow 64-node jobs of 2026-11-10/11 (sections 272, 274), whose cause remains unexplained.
- **The switches held our packets back far more than usual.** `TxWait` counts the time a card had data to send but no credit from its switch. Per word sent (median over nodes; lower is better):

| job and segment | TxWait per word sent | nodes above 10⁷ TxWait per second |
|---|---|---|
| 3711819, 32-node probe (slow) | 2.6 × 10⁻² | 6 of 32 |
| 3711820, 64-node probe (slow) | 3.3 × 10⁻² | 10 of 64 |
| 3708796, 64 nodes, reps 1 and 2 (normal speed, section 276) | 1.3–1.5 × 10⁻⁴ | 0 of 64 |
| 3711818, 16 nodes (normal speed, section 278) | 4.3 × 10⁻⁵ | 0 of 16 |

- That is about 200× the back-pressure per word of a normal-speed 64-node segment on the same workload (job 3708796's reps also ran uniform), so the fabric was congested.
- **Our two jobs did not cause it for each other:** the 64-node job had ended (21:08:30) before the 32-node probe started (21:10:42).
- **Uniform's own traffic makes some back-pressure** (section 155: 1–6 M ticks per second per node at 3.8 GB/s sent per node), which is why the comparison above is per word on the same workload. Section 155 also saw one external episode raise it about 100× for 4 s. Uniform sends about 1.5 GB/s per node at 16 nodes, 12% of a link (section 144).
- **So other jobs' load on shared links is the likely cause.** That fits the time-varying noise seen before (sections 144 and 155).
- The fabric manager was not queried (its 20-minute history had long passed when the jobs were seen).

**Changes and reruns:**
- **The probe's stop now exits 0** when the machine is slow, so Slurm records the job as COMPLETED instead of FAILED. A probe that gives no rate still exits 1. `ul277.slurm` md5 d0aac967… (was 2dc2b263…, kept as `ul277_pre282.slurm`). Both branches were checked locally, and the stub runs for 32 and 64 nodes print the same 43 srun commands as before. The login-node checks passed for both groups.
- **Resubmitted unchanged otherwise:** 3716315 (32 nodes) and 3716316 (64 nodes), skx, same exclusions. Predictions and the table rule are section 277's.

## Earlier

Superseded or historical sections, in the order they were written. Their numbers came from an older stack, launch or setting, or a later section replaced them; each says which.

### §3 · Per-message cost and scaling (2026-10-20, idev job 3620576, 8 skx nodes)

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

### §4 · Aggregation through htram (2026-10-20, idev job 3621217, 4 skx nodes)

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

### §5 · Deadline flush policy (2026-10-20, idev job 3621758, 4 skx nodes)

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
