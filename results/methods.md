# Methods

How runs are made and checked: run length and warm-up, and the flag check that keeps diagnostics out of timing runs. Part of the Charades results: the current paper tables are on the front page, [../RESULTS.md](../RESULTS.md), and every section's date, job, status and file is in [INDEX.md](INDEX.md). Sections keep the numbers (§N) they had in the single RESULTS.md they came from (split 2026-11-07); "section N" anywhere means §N.

| § | date | status | section |
|---|---|---|---|
| 121 | 2026-10-27 | design | Closure check: 78% of σ 2,000's 4→16-node loss is in the first 10% of waves, which sections 116–120 left ou… |
| 122 | 2026-10-27 | current | Warm-up and long runs, results: in 4× longer runs σ 2,000 scales at 0.96–0.97 and σ 4,000's loss is all sta… |
| 247 | 2026-11-06 | design | Paper runs without diagnostics: F5 and VLSI rerun at 1–16 nodes and resubmitted at 32, after a check of eve… |
| 263 | 2026-11-08 | current | A config file that opens but cannot be read runs on the defaults: job V8's gate failed on a /work2 stall, n… |

## Current

Current findings, and designs with their results, in the order they were written.

### §121 · Closure check: 78% of σ 2,000's 4→16-node loss is in the first 10% of waves, which sections 116–120 left out; a warm-up test and long runs (analysis of existing traces and design, 2026-10-27; written before any runs)

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

### §122 · Warm-up and long runs, results: in 4× longer runs σ 2,000 scales at 0.96–0.97 and σ 4,000's loss is all start-up; warm-up pings do nothing; uniform's loss is steady (2026-10-27; skx-dev batch job 3650843, 16 nodes)

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

### §247 · Paper runs without diagnostics: F5 and VLSI rerun at 1–16 nodes and resubmitted at 32, after a check of every flag (design, 2026-11-06; written before any runs)

> **Status: design.**
> - **User decisions 2026-11-06 (section 246):**
>   - Cancel F5-32 and V32 and resubmit them without the log.
>   - Rerun F5a's and VS3's controller arms without the log, next to their best fixed arms.
>   - Leave the controller as it is.
>   - Check carefully the parameters of every run.
> - **Done:** F5-32 (3688917) and V32 (3688918) were cancelled before they started.
> - **Queued 2026-11-06 21:10:** F5a2 3690453 (skx-dev) / 3690454 (skx; the skx-dev copy reads 3690454 from `f5scale240_a.twin`), VA 3690455 (skx), F5-32b 3690451, V32b 3690452 (skx, 32 nodes). Login-node checks pass for all four modes; no `--ctl-log` outside comments.

**The flag check.** Every flag of every arm was listed from stub runs of the scripts, for all three engines.
- **Besides `--ctl-log`, the Charades launch of F5 and VLSI carried four more diagnostics:**
  - `--blocked-time=1`: a timer read per blocked spell;
  - `--commit-digest=1`: a hash per committed event;
  - on VLSI, `--copy-stats=1` and `--pe-stats=1`: per-PE counters and end-of-run tables.
- None had a measured cost, and Devastator and ROSS carry nothing like them. So they could bias Charades ÷ Devastator and Charades ÷ ROSS, which the log could not, because it printed only in controller arms.
- **They all leave the timing arms.** Check arms carry them, to keep the digest check and to measure what they cost.
- **The engine's GVT progress print** (`--report-interval`, default 64, about 180 lines a second on PE 0) is part of every Charades run so far, F1 included. It stays at its default, and one arm measures it.
- **F5a and VS3 are rerun whole,** not only their controller arms. The ratios need every engine in the same allocation, and Charades' fixed arms lose the diagnostics too.
- **F1-32 (3688916, still queued) is unchanged:** its runs already carry the launch only.

**Flags per arm** (Charades launch for every arm: `+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free` under `numactl --localalloc`):
- **`ctl_sweep.sh` adds** the arm's own `--optimism-window=W` or `--ctl=3 --ctl-bracket=1`, plus `--gvt-bucket-size`, the htram settings (`--aggregation=1 --agg-mode --agg-buffer --agg-policy=1 --agg-horizon-margin=8`; none for direct sends), and the config `bucket` (sync=3, gvt=4, buffer-size=655360).
- **Layouts:** F5 runs 2 × 23 PEs per node, VLSI 1 × 46.

| arm | Charades flags beyond the above | why |
|---|---|---|
| every timing arm | none; VLSI adds `--batch=32`, its L arm `--fossil-lazy=1` | timing (VLSI's settings, section 236) |
| od (F5) / O (VLSI), every job | `--blocked-time=1 --commit-digest=1`; VLSI also `--copy-stats=1 --pe-stats=1` | the digest check (C1); per-PE stats for VLSI's slow reps; the old set's cost |
| dg / G, 1–16 nodes only | `--commit-digest=1` | the digest's cost alone |
| ri / R, 1–16 nodes only | `--report-interval=1000000` | the cost of the GVT progress print |

- The check arms run at the best fixed W: traffic PP 2,048 W 500, dragonfly WPs 512 W 10,000, VLSI eager W 5,000.
- **Devastator** gets model arguments, `--end-time` and `--rng=clcg4` (VLSI draws none). Its window comes from `deva_static_look_dt`, and it prints about 20 lines a run.
- **ROSS** gets `--synch --read-buffer=1 --extramem=800000 --batch --gvt-interval`, `--max-opt-lookahead` in its window arms, model arguments and `--end`. It prints about 300 lines, mostly at the end.

**Jobs** (`f5scale240.slurm`, `vscale240.slurm`, with modes; copies in `~/charades-data/f1/`, the previous versions as `*.pre247`; `-x c455-081`):

| job | mode | queue, nodes, limit | what | runs (Charades / Devastator / ROSS) |
|---|---|---|---|---|
| F5a2 | `f5scale240.slurm a` | skx-dev and an skx copy, 16, 1:55 | F5a's arms and layout at 1–16 nodes (section 240), 3 reps, plus od, dg, ri | 245 / 90 / 90 |
| VA | `vscale240.slurm a` | skx (an skx-dev copy when that queue is free), 16, 0:50 | VS3's arms and layout at 1–16 nodes (section 238), 3 reps, plus O, G, R | 110 / 45 / — |
| F5-32b | `f5scale240.slurm big` | skx, 32, 4:00 | F5-32's plan (16 on halves, 3 reps; 32 nodes, 5 reps) plus od | 99 / 48 / 48 |
| V32b | `vscale240.slurm big` | skx, 32, 1:45 | V32's plan (16 on halves, 3 reps; 32 nodes, 5 reps) plus O | 58 / 33 / — |

- Run counts are from the stub runs, and match the plan in every mode.
- A copy that starts second exits, and one that starts first cancels its twin: the guard reads `TWIN` from the environment or from `f1_240/<script>_<mode>.twin`.

**Predictions:**
- **D1. Counts:** one count per cell in every engine; one Charades digest per cell across the od/dg (O/G) arms and reps.
- **D2. The old diagnostics cost Charades at most 2%:**
  - od ÷ the same fixed arm is 0.98–1.00 on traffic and dragonfly, and O ÷ E at W 5,000 is 0.97–1.00 on VLSI.
  - The digest alone is at least 0.99; without the progress print, 1.00–1.01.
- **D3. The controller without the log ÷ the best fixed W, per rep:** traffic 0.95–1.07, dragonfly 1.00–1.06, VLSI 0.97–1.05. With the log they were 0.93–1.06, 0.99–1.03 and 0.95–1.02 (sections 244, 239).
- **D4. Charades ÷ Devastator** with the controller is 1.00–1.08× section 244's (F5a) and 239's (VS3) at each node count, and 1.00–1.03× with Charades' best fixed arm.
- **D5.** Devastator and ROSS reproduce sections 244 and 239 within 5%.
- **Section 240's 32-node predictions stand:** C7 for F5; C8 and C9 for VLSI. C9 now compares the 16-node halves with VA's 16-node cell instead of VS3's.

**What follows:**
- **The paper tables:** VA and F5a2 replace sections 239 and 244 at 1–16 nodes, and F5-32b and V32b give the 32-node column.
- **If D2 fails** (the old diagnostics cost more than 2%), earlier Charades ÷ Devastator ratios from jobs that carried them (F4, ABL, F3R) understated Charades by that much, and F4 is decided then.

### §263 · A config file that opens but cannot be read runs on the defaults: job V8's gate failed on a /work2 stall, no recorded run was affected, V8 resubmitted (2026-11-08; skx-dev batch job 3696078, 9 nodes)

> **Status: current.**
> - **Job:** V8's first copy (section 262), 3696078 on skx-dev. It started at 17:22:58, cancelled its skx twin 3696077, and stopped at its gate, before any timing run. Its script took 2 min 49 s to reach its first `git log` on /work2.
> - **Resubmitted** with the gate retry below: 3696169 (skx) and 3696170 (skx-dev; running at 17:41). P64 and A64 (3696079, 3696080) were left in the queue as submitted.

**What failed.** The gate passed 26 of 27 tests. VLSI `agg_ctl_measured_fast_bucket_pp` on one process of 4 PEs aborted on every PE with "Lookahead violation" from the conservative scheduler's assertion (`event.C:380`). Its log printed the engine's defaults: "Synch Protocol 2" (conservative), lookahead 5, GVT interval 16, buffer 65,536. The test's config sets `sync=3`, `gvt=4`, `buffer-size=655360`, the controller and htram PP. The model's own config (`tiny.bench`, 3 copies) was applied. Conservative VLSI at lookahead 5 aborts, so the abort itself is expected once the defaults are in force.

**Why.**
- **Mechanism.** `parse_command_line` (`src/util/command_line.C`) aborts if a config file cannot be opened. If it opens and the read then fails, `std::getline` ends the loop and the run goes on with whatever was parsed so far. `tw_init` sets every kernel option to its default (`clear_globals`) before parsing, so a failed read leaves the defaults.
- **Perturbation (Mac):** PHOLD given a directory as its config file (it opens, every read fails) printed "Synch Protocol 2" and ran, with no error.
- **The stall.** The test before it (1 PE) reached "Simulation Starting" at 17:25:51.9, normal. The failed run took 9.5 s to get there (normally about 0.3 s) and the next one (2 × 2 PEs, same config) 16 s, and that one passed. From 17:26:19 runs started at normal speed. So for about 26 s file reads on the node stalled, and in that window one read of the test config came back empty.
- **Ruled out:** a race between PE threads at startup (`clear_globals` and the parse run in each process's `tw_init`) would not hold startup for 9.5 s, and the same config passed seconds before and after.

**No recorded run was affected.**
- Timing runs pass two files through `ctl_sweep.sh`: the workload's config and the GVT config (`tests/test_configs/bucket`: `sync=3`, `gvt=4`, `buffer-size=655360`). Every other setting is on the command line.
- If the workload file read failed, the committed count would differ, and every analysis checks one count per cell.
- If the GVT file read failed, the run would be conservative with the default GVT and record a rate with no error. Its signature is no count waves (the `count_waves` column).
- **Scan of `~/charades-data`:** 14,094 Charades runs with status ok in 5,020 CSVs. Every optimistic run with a `count_waves` column has count waves; the 90 runs without are the deliberate blocking-GVT arms (`blk:0`). VLSI's CSVs (345 files) have no such column, but a defaulted VLSI run aborts as this one did; it cannot record a rate.

**Changes.**
- **V8's gate** (`v8_262.slurm`) reruns once if every failed test shows an I/O error or the default protocol line, which no gate config uses; F1's gate already reran on I/O errors, and this failure printed none. Checked against this job's gate output: it would have rerun.
- **P64 and A64:** their analyses drop and report any Charades run without count waves (and any VLSI run that fails), so a defaulted timing run cannot enter a table. Their gates rerun only on I/O errors (Slurm keeps the script as submitted); a gate failure stops the job before any timing run.
- **Not changed:** the paper's tree `charades-r5` (85a2aad); the pending jobs check its commit and binaries. A parser that aborts when a read fails (checking `ferror` or reading the whole file first) belongs on `main`.
