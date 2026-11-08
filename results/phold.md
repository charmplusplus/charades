# PHOLD: performance and weak scaling

Gaussian and uniform PHOLD in Charades, Devastator and ROSS: σ sweeps, full nodes, long runs, weak scaling from 1 to 32 nodes, and the paper runs F1. Part of the Charades results: the current paper tables are on the front page, [../RESULTS.md](../RESULTS.md), and every section's date, job, status and file is in [INDEX.md](INDEX.md). Sections keep the numbers (§N) they had in the single RESULTS.md they came from (split 2026-11-07); "section N" anywhere means §N.

| § | date | status | section |
|---|---|---|---|
| 35 | 2026-10-22 | design | Full-node reruns |
| 36 | 2026-10-22/23 | current | Full-node reruns, results (2026-10-22/23, idev jobs 3629783 (skx-dev) and 3629781 (skx), 4 nodes) |
| 41 | 2026-10-23 | design | Scaling check at 16 and 32 nodes |
| 42 | 2026-10-23 | design | Three engines at 4 nodes, paper grade |
| 43 | 2026-10-24 | current | Scaling check at 16 and 32 nodes, results (2026-10-24, batch jobs 3633769 (16 nodes, runs at 4 and 16) and… |
| 44 | 2026-10-24 | design | Window sweep at 16 and 32 nodes |
| 45 | 2026-10-24 | current | Window sweep at 16 and 32 nodes, results: 16 nodes |
| 67 | 2026-10-25 | design | The 16-node gaps with wider windows (uniform, lookahead 10) |
| 68 | 2026-10-25 | current | The 16-node gaps with wider windows, results |
| 77 | 2026-10-25 | design | Weak scaling 1–16 nodes in one allocation; one process per node |
| 78 | 2026-10-25 | current | Weak scaling 1–16 nodes in one allocation, results: time per GVT advance, not aggregation, limits Charades |
| 123 | 2026-10-27 | design | Charades and Devastator on long runs, 1 / 4 / 16 nodes: σ 2,000, σ 4,000, uniform |
| 124 | 2026-10-27 | current | Both engines on long runs, results: Charades leads Devastator 1.33–1.98×, scales as well at σ ≥ 2,000 (0.93… |
| 129 | 2026-10-28 | design | Charades and Devastator on long runs, 1 / 4 / 16 nodes: the other five workloads |
| 130 | 2026-10-28 | current | The other five workloads on long runs, results: Charades ahead in 14 of 15 cells (level in the 15th), scale… |
| 140 | 2026-10-28 | design | Paper-grade scaling, 1–32 nodes: the plan; A0, ROSS tuning |
| 141 | 2026-10-28 | current / design | A0, ROSS tuning, results; A1 and A2, paper-grade weak scaling |
| 240 | 2026-11-06 | design (RW results in 241) | F1 and F5 on the final defaults: seven jobs queued at once — ROSS's window on PHOLD, Gaussian PHOLD at 1–32… |
| 242 | 2026-11-06 | superseded in part by §261 (was: current) | F1a results: on PHOLD group a (σ 100, σ 1,000, σ 4,000, lookahead 10 σ 2,000) Charades ÷ Devastator is 1.13… |
| 243 | 2026-11-06 | superseded in part by §261 (was: current) | F1b results, and F1 at 1–16 nodes: Charades leads Devastator in all 40 PHOLD cells (1.08–2.25), each ratio… |
| 252 | 2026-11-07 | superseded in part by §257 (was: current) | F1-32 results, and F1 at 1–32 nodes: Charades leads Devastator in all 48 PHOLD cells, 1.26–2.01 at 32 nodes… |
| 255 | 2026-11-07 | current | How each engine slows as events go to other processes, and its GVT pace, from F1's data: Charades keeps 0.4… |
| 260 | 2026-11-08 | design (results in 261) | The 8-node columns of F1 and F5 rerun with the batch host idle, GC's four 1-node cells off node 0, and whet… |
| 261 | 2026-11-08 | current | R8 results: with the batch host idle, Devastator runs 3–10% faster at 8 nodes and Charades ÷ Devastator the… |
| 1 | 2026-10-19 | historical | First Stampede3 measurements |
| 2 | 2026-10-19 | historical | Optimism window sweep |
| 11 | 2026-10-21 | design | Gaussian PHOLD σ sweep |
| 12 | 2026-10-21 | superseded | Gaussian PHOLD σ sweep, results |
| 19 | 2026-10-21 | superseded | Three engines on Gaussian PHOLD, 4 nodes (same job; first real comparison) |
| 20 | 2026-10-21 | superseded | Three engines: the gaps filled |
| 27 | 2026-10-22 | design | Gaussian PHOLD σ sweep on the fast stack |
| 28 | 2026-10-22 | superseded | Gaussian PHOLD σ sweep on the fast stack, results |
| 142 | 2026-10-28 | superseded by §242 (was: current) | A1a, weak scaling 1–16 nodes, group a (σ 100, σ 1,000, σ 4,000, lookahead 10 σ 2,000), results |
| 143 | 2026-10-28 | superseded by §243 (was: current) | A1b, weak scaling 1–16 nodes, group b (σ 500, σ 2,000, uniform, lookahead 10 σ 500) and σ 1,000 with both h… |
| 144 | 2026-10-29 | not for use / design | A2, 32 nodes: a noisy allocation, so the 32-node point is rerun |
| 153 | 2026-10-29 | superseded by §252 (was: current) | A2r, 32 nodes, results: Charades leads in 6 of 8 but loses more per node from 16 to 32 nodes than Devastato… |

## Current

Current findings, and designs with their results, in the order they were written.

### §35 · Full-node reruns (design, 2026-10-22; written before any runs)

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

### §36 · Full-node reruns, results (2026-10-22/23, idev jobs 3629783 (skx-dev) and 3629781 (skx), 4 nodes)

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

### §41 · Scaling check at 16 and 32 nodes (design, 2026-10-23; written before any runs)

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

### §42 · Three engines at 4 nodes, paper grade (design, 2026-10-23; written before any runs)

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

### §43 · Scaling check at 16 and 32 nodes, results (2026-10-24, batch jobs 3633769 (16 nodes, runs at 4 and 16) and 3633770 (32 nodes))

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

### §44 · Window sweep at 16 and 32 nodes (design, 2026-10-24; written before any runs)

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

### §45 · Window sweep at 16 and 32 nodes, results: 16 nodes (2026-10-24, batch job 3635596 on skx-dev)

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

### §67 · The 16-node gaps with wider windows (uniform, lookahead 10) (design, 2026-10-25; written before any runs)

> **Status: design.** Written before any runs.

**Why.** At 16 nodes Charades trails Devastator with uniform traffic (0.94) and at lookahead 10 / mean 200 (0.86 at σ 500, 0.77 at σ 2,000), but in both its best arm was the widest window tested (W 400; W 100 at σ 2,000), while Devastator's best was W 1,000 and W 200. Are these gaps real?

**Job** (skx-dev, 16 nodes, 2 reps, fast path on, short runs, each node warmed first):
- Uniform remote 1.0 (lookahead 100 / mean 1,000): W 400, 600, 800, 1,000 and the controller; PP 512 and WPs 512. Devastator W 500, 1,000, 2,000.
- Lookahead 10 / mean 200, σ 500 and 2,000: W 50, 100, 150, 200, 300 and the controller; PP 512, PP 2,048 and WPs 512. Devastator W 100, 200, 400, 800.

**Predictions:**
- G1. Uniform: Charades' best W is 600–800, and Charades ÷ Devastator rises to at least 1.00.
- G2. Lookahead 10: the best W is 150–200; Charades ÷ Devastator rises to at least 0.95 at σ 500 and 0.90 at σ 2,000.
- G3. The controller reaches at least 0.90 of the best fixed W in all three workloads; if not, its bound (κ) holds W too low at 16 nodes.

### §68 · The 16-node gaps with wider windows, results (2026-10-25, skx-dev batch job 3638330)

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

### §77 · Weak scaling 1–16 nodes in one allocation; one process per node (design, 2026-10-25; written before any runs)

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

### §78 · Weak scaling 1–16 nodes in one allocation, results: time per GVT advance, not aggregation, limits Charades (2026-10-25; skx-dev batch job 3639098)

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

### §123 · Charades and Devastator on long runs, 1 / 4 / 16 nodes: σ 2,000, σ 4,000, uniform (design, 2026-10-27; written before any runs)

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

### §124 · Both engines on long runs, results: Charades leads Devastator 1.33–1.98×, scales as well at σ ≥ 2,000 (0.93), and its controller is within 2% of its best W on 16 nodes (2026-10-27; skx-dev batch job 3650921, 16 nodes)

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

### §129 · Charades and Devastator on long runs, 1 / 4 / 16 nodes: the other five workloads (design, 2026-10-28; written before any runs)

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

### §130 · The other five workloads on long runs, results: Charades ahead in 14 of 15 cells (level in the 15th), scales as well or better in 4 of 5; its controller is its best setting or within 1% (2026-10-28; skx-dev batch job 3652595, 16 nodes)

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

### §140 · Paper-grade scaling, 1–32 nodes: the plan; A0, ROSS tuning (design, 2026-10-28; written before any runs)

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

### §141 · A0, ROSS tuning, results; A1 and A2, paper-grade weak scaling (A0 results and A1/A2 design, 2026-10-28; skx-dev batch job 3653550, 16 nodes; A1/A2 design written before their runs)

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

### §240 · F1 and F5 on the final defaults: seven jobs queued at once — ROSS's window on PHOLD, Gaussian PHOLD at 1–32 nodes, traffic and dragonfly at 1–32, VLSI at 32 (design, 2026-11-06; written before any runs)

> **Status: design; queued 2026-11-06. RW done (results in section 241).** RW 3688911 (skx-dev, started at once; skx copy 3688912 cancelled), F1a 3688913 (skx) and 3689004 (skx-dev, 1:55, added at the user's request after RW; `TWIN=3688913`: the copy that starts first cancels the other, and one that starts second exits; 3689004 started 13:24 and its guard cancelled 3688913; gate 36/36), F1b 3688914 (skx) and 3689513 (skx-dev, 1:55, added at the user's request after F1a; `TWIN=3688914`), F5a 3688915 (skx) and 3689887 (skx-dev, 1:55, added at the user's request after F1b; `TWIN=3688915`; the guard added to `f5scale240.slurm`), F1-32 3688916, F5-32 3688917, V32 3688918 (all skx). Login-node checks pass for all seven submissions.
> User decisions 2026-11-06:
> - **No hard engine freeze;** the focus now is runs. A later engine change means rerunning the cells it touches.
> - **F1:** all eight PHOLD workloads.
> - **Charades:** the controller plus two fixed windows.
> - **ROSS's window on PHOLD:** calibrated first.
> - **The 32-node job:** carries VLSI, 16 nodes inside a 32-node allocation, and traffic and dragonfly.
> - **Reps:** 3, and 5 at 32 nodes.
> - **Queueing:** everything that can run in parallel now. My rule allows one job at a time in skx-dev, so only the calibration goes there (with an skx copy); the rest queue on skx.
>
> **Code:**
> - **Charades:** `charades-r5`, at charades 85a2aad on `charm-pads-perf`.
>   - It carries round 3, per-LP rollback and `--agg-pp-alloc=1`.
>   - The frozen controller now has `--ctl-reach-buckets=2`, and VLSI runs with eager commits.
>   - Launch: `numactl --localalloc` (Charades only), 2 × 23 PEs per node except VLSI (1 × 46).
>   - Traffic and dragonfly are built by `build_r5_apps.sh`.
> - **Devastator and ROSS:** the binaries of F1 and F5 (sections 141–153, 187–194, 238).

**Jobs** (scripts in `$WORK/charades-runs/`, copies in `~/charades-data/f1/`; all with `-x c455-081`):

| job | script | queue, nodes, limit | what |
|---|---|---|---|
| RW | `rosswin240.slurm` | skx-dev (and an skx copy), 5, 1:30 | ROSS on the eight PHOLD workloads, optimistic batch 16 / GVT interval 64, without a window and over a window grid (lookahead 100: 250–4,000; lookahead 10: 50–800), at 1 and 4 nodes side by side, A0's run length, 1 rep. It writes ROSS's best window per workload at 4 nodes to `f1_240/ross_windows.txt` (0 if none beats no window). |
| F1a, F1b | `scale240.slurm a` / `b` | skx, 16, 2:30 | A1's groups a and b at 8, 4, 2 and 1 nodes side by side, then 16; 3 reps |
| F1-32 | `scale240.slurm big` | skx, 32, 4:00 | all eight workloads at 32 nodes, 5 reps |
| F5a | `f5scale240.slurm a` | skx, 16, 2:00 | traffic and dragonfly at 8, 4, 2 and 1 nodes side by side, then 16; 3 reps |
| F5-32 | `f5scale240.slurm big` | skx, 32, 4:00 | traffic and dragonfly at 16 nodes on the two halves side by side (3 reps), then 32 nodes (5 reps) |
| V32 | `vscale240.slurm` | skx, 32, 1:30 | VLSI at 16 nodes on each half side by side (3 reps each), then 32 nodes (5 reps) |

**Arms:**
- **PHOLD** (A1's workloads, sizes and htram settings, section 141; long runs):
  - **Charades:** the controller (`--ctl=3`, bracketed, reach 2 buckets) and W 300 / 400 (lookahead 10: 50 / 100).
  - **Devastator:** W 500 / 1,000 / 2,000 (lookahead 10: 100 / 200 / 400), plus 4,000 at 32 nodes; CLCG4.
  - **ROSS:** optimistic batch 16 / GVT interval 64, conservative, and optimistic with the window RW chose for that workload. If RW has not finished when the arm runs, it runs two windows instead: 1,000 and 2,000, or 200 and 400 at lookahead 10.
- **Traffic and dragonfly** (F5's sizes and Charades and Devastator arms, section 187):
  - **ROSS now runs with its window** (sections 223, 225): traffic batch 64 / GVT interval 64 at windows 1,000 and 2,000, and conservative; dragonfly batch 2 / GVT interval 64 at windows 2,500, 5,000 and 7,500 ps.
  - Every Charades run carries `--commit-digest`.
- **VLSI:** VS3's arms (section 238): Charades E at W 5,000 and W 2,500, L at W 2,500, and the controller; Devastator 2 × 23 at W 2,500 / 5,000 / 10,000. Copy 2's node is sampled around every Charades run. ROSS is not rerun; its 32-node rate from job big2 (section 226) stands, since ROSS has not changed.
- **Engines are interleaved per rep,** and in F5 and VLSI the order is reversed in even reps.
- **Each gate is a change tier on 2 nodes** and fails if it ran no test.
- **Checks:** every script's arm order and options were run against stubs on the Mac. ROSS's window is read from RW's file, a 0 there drops the arm, and a missing entry falls back to the pair.

**Earlier numbers these replace:**
- **F1:** the table at the top of this file (sections 142–143, 153). It ran on the paper's tree before round 3 (1.16–1.18× on PHOLD, section 215), before `--localalloc` (1.03–1.12× at 16–32 nodes, sections 164, 166) and with chare rollback.
- **F5:** sections 188, 189 and 194, before round 3, with ROSS without its window.
- **VLSI 32:** section 226, with lazy commits.

**Predictions** ("ratio" is Charades ÷ the other engine, each at its best arm, higher is better; "old" is the table each replaces):
- **C1. Counts:**
  - Every cell commits the same events in all three engines.
  - Every traffic, dragonfly and VLSI cell has one Charades digest across arms and reps.
- **C2. PHOLD at 1–16 nodes:**
  - Each Charades ÷ Devastator ratio is 1.10–1.30× the old one: round 3, `--localalloc` and the PP allocation help Charades only.
  - So Charades leads in all 40 cells (old: 38).
- **C3. PHOLD at 32 nodes:**
  - Charades leads in all eight workloads, each at 1.05 or more (old: 0.89 at σ 100, 0.99 at lookahead 10 σ 500).
  - The median over the eight is at least 1.3. Job N32 (section 166) found 1.65 at σ 100 and 2.46 on uniform with `--localalloc`.
- **C4. The controller ÷ Charades' better fixed W:** at least 0.93 in every PHOLD cell at 1–16 nodes and 0.90 at 32 (jobs M and N: 0.91–1.03; N32's controller 0.94–0.95 at 32 nodes).
- **C5. Per-node rate from 16 to 32 nodes** (each at its best): Charades at least 0.88 on the six lookahead-100 workloads (N32: 1.02 at σ 100; old: 0.72–0.87).
- **C6. ROSS's window on PHOLD (RW):**
  - It beats no window by 1.05–1.25× on at least five of the eight workloads at 4 nodes.
  - ROSS's best window at lookahead 100 is 1,000–4,000.
  - Charades ÷ ROSS at its best (window included) stays at least 2.0 in every F1 cell.
- **C7. Traffic and dragonfly:**
  - Charades ÷ Devastator is 0.95–1.20× F5's at each node count (dragonfly 1.80 at 16 nodes and 2.03 at 32; traffic 1.03 and 1.08).
  - Charades ÷ ROSS, with ROSS at its window, is 2.6–3.6 on dragonfly and 1.5–2.2 on traffic.
- **C8. VLSI at 32 nodes:**
  - Charades ÷ Devastator at its best fixed arm is at least 1.15 (old: 1.05).
  - The controller is at least 0.95 of Charades' best fixed arm.
  - E at W 5,000 varies at most 1.05× between reps (W 2,500 varied 1.17–1.19×, section 226).
- **C9. VLSI at 16 nodes inside the 32-node allocation:**
  - At W 2,500 (L and E) it runs at least 3% slower than in VS3's 16-node allocation on at least one half.
  - E at W 5,000 is within 3% of VS3's.
  - This would confirm that the slow waves come with the allocation (section 228).

**What follows:**
- **If C1 holds:** F1 at 1–32 nodes and F5's three applications are paper-grade on 85a2aad. Their tables replace the old ones at the top of this file and in PAPER.md.
- **If C6 holds:** the paper's Charades ÷ ROSS on PHOLD uses ROSS with its window.
- **If C9 holds:** the paper says the VLSI 32-node spread at W 2,500 is the allocation's. The setting at W 5,000 avoids it.
- **A slow rep in V32:** read the copy-2-node samples, as in section 239.

### §242 · F1a results: on PHOLD group a (σ 100, σ 1,000, σ 4,000, lookahead 10 σ 2,000) Charades ÷ Devastator is 1.13–1.93 at 1–16 nodes, ahead in all 20 cells; Charades itself is 1.09–1.22× faster than in A1a while Devastator and ROSS are unchanged; the controller is 0.94–1.03 of the better fixed W (2026-11-06; skx-dev batch job 3689004, 16 nodes)

> **Status: current for group a at 1–16 nodes.** Design and predictions in section 240. It replaces A1a (section 142) in the paper table. σ 1,000 also waits for F1b's PP 512 series (`g1000x`): as in A1, Charades' σ 1,000 cell takes the better htram setting at each node count.
> - **Superseded in part (2026-11-08, section 261):** the 8-node column. Its series ran on nodes 0–7 beside three other streams, and node 0, the batch host, slows runs placed on it (section 259). Rerun with node 0 idle (job R8), Devastator ran 3–10% faster at 8 nodes, and Charades ÷ Devastator there is 1.22 (σ 100), 1.48 (σ 1,000), 1.82 (σ 4,000) and 1.46 (lookahead 10 σ 2,000). The other node counts stand: other streams' network traffic does not slow a run (section 261's check).
> - **Job:** 1 h 5 min of the 1 h 55 min limit. Gate 36/36. The guard cancelled the skx copy 3688913 when this copy started. The 8-, 4-, 2- and 1-node series ran side by side (13:28–13:58), then 16 nodes (13:58–14:29).
> - **Runs:** 585 (Charades 225, Devastator 180, ROSS 180), none failed.
> - **Data:** `~/charades-data/f1/scale240/a_j3689004/`; summary `~/charades-data/f1/f1_240_summary.py` (run on this job and A1a's `~/charades-data/scale32/scale32/a_j3653803`), output `scale240/a_j3689004_summary.txt`.
> - **Counts (C1, PHOLD part):** every cell commits one count in all three engines. PHOLD runs carry no digest.

**Charades ÷ Devastator** (Charades' controller at its htram setting ÷ Devastator's best W, as in the paper table; median of 3 reps; higher is better). A1a's ratio is in brackets:

| workload | 1 node | 2 | 4 | 8 | 16 |
|---|---|---|---|---|---|
| σ 100 (PP 2,048) | 1.26 (1.10) | 1.23 (1.06) | 1.21 (1.03) | 1.30 (1.03) | 1.25 (1.04) |
| σ 1,000 (PP 2,048) | 1.13 (0.99) | 1.30 (1.13) | 1.40 (1.21) | 1.52 (1.29) | 1.60 (1.30) |
| σ 4,000 (PP 512) | 1.46 (1.32) | 1.90 (1.66) | 1.86 (1.67) | 1.91 (1.66) | 1.93 (1.60) |
| lookahead 10, σ 2,000 (WPs 512; PP 512 at 16) | 1.27 (1.19) | 1.41 (1.28) | 1.38 (1.27) | 1.45 (1.28) | 1.49 (1.35) |

With Charades at its best arm (controller or fixed W), the ratios are 1.00–1.07× these: 1.18–2.02.

**Per workload** (rates in M committed ev/s, median of 3, higher is better; per-node rate at 16 ÷ at 1 node, 1.0 is perfect):

| workload | M ev/s at 16 nodes, Charades / Devastator / ROSS | per-node rate 16 ÷ 1, Charades / Devastator / ROSS | Charades ÷ ROSS, 1–16 nodes (higher is better) | controller ÷ better fixed W, 1–16 nodes (higher is better) |
|---|---|---|---|---|
| σ 100 | 802.7 / 644.5 / 216.1 | 0.95 / **0.96** / 0.70 | 2.73–3.71 | 0.966–0.976 |
| σ 1,000 | 665.6 / 415.9 / 122.4 | **0.99** / 0.70 / 0.80 | 4.37–5.44 | 0.939–0.968 |
| σ 4,000 | 552.3 / 285.5 / 98.6 | **0.83** / 0.63 / 0.67 | 4.51–5.60 | 0.945–0.991 |
| lookahead 10, σ 2,000 | 519.3 / 347.4 / 103.9 | **0.89** / 0.75 / 0.75 | 4.21–5.00 | 0.976–1.032 |

(Bold: the best of the three engines.)

**Each engine's rate ÷ its own in A1a** (same workloads, node counts and settings; Charades: its controller; 1.0 is unchanged):

| workload | Charades | Devastator | ROSS |
|---|---|---|---|
| σ 100 | 1.15–1.22 | 0.97–1.01 | 0.96–1.02 |
| σ 1,000 | 1.15–1.19 | 0.97–1.02 | 0.98–1.01 |
| σ 4,000 | 1.12–1.19 | 0.97–1.02 | 0.97–1.03 |
| lookahead 10, σ 2,000 | 1.09–1.13 | 0.98–1.02 | 0.98–1.03 |

**What the job shows:**
- **The gain is Charades' own.**
  - Devastator and ROSS reproduce A1a within 4%, while Charades runs 1.09–1.22× faster.
  - That is round 3 (1.16–1.18× on PHOLD, section 215), `--localalloc` and the PP allocation, which section 240 expected.
- **Charades scales best from 1 to 16 nodes in 3 of 4 workloads.**
  - On σ 100 it is level with Devastator (0.95 against 0.96).
  - On σ 1,000 it keeps 0.99 of its 1-node rate per node, against Devastator's 0.70.
  - All three engines dip at 8 nodes on σ 100 and σ 4,000. Devastator's and ROSS's 8-node rates are also their lowest against A1a (0.97–0.98), so this is likely the 8 nodes this job drew.
- **The controller** runs at mean W 304–392 at lookahead 100 (58–70 at lookahead 10) and rolls back 0.01–0.45% of events.
  - It trails the better fixed W by 1–6% at lookahead 100, where W 300 is the better fixed arm in 14 of 15 cells.
  - A1's fixed arms were W 250 and 400; W 300 is new. Against W 400 the controller is ahead, for example 1.07 at σ 100 on 16 nodes.
  - At lookahead 10, where the fixed arms did not change (W 50 and 100), it is 0.98–1.03, as in A1.
  - What costs the 1–6% is not measured here.
- **ROSS's window hardly matters, as RW found.**
  - ROSS's best is conservative on σ 100 and σ 1,000 at every node count, and on σ 4,000 at 1–4 nodes; optimistic at σ 4,000 on 8–16.
  - Only on lookahead 10 σ 2,000 is its window best (2–16 nodes), by at most 1.5% over optimistic without one.
- **Rep spread:** the controller's runs vary at most 1.059× (max ÷ min) in a cell.

**Predictions (group a only):**
- **C1 (PHOLD): right.** One count per cell in all three engines.
- **C2: mostly right.**
  - Charades leads in all 20 cells (A1a: 19; σ 1,000 at 1 node was 0.99).
  - Each ratio is 1.06–1.25× A1a's. 18 of 20 cells fall in the predicted 1.10–1.30.
  - The two below are lookahead 10 σ 2,000 at 1 node (1.06) and 4 nodes (1.09). That workload runs WPs 512 at 1–8 nodes, where the PP allocation change does not apply. This is a possible reason only; it was not tested.
- **C4: right.** The controller is 0.939–1.032 of the better fixed W, at least 0.93 in every cell.
- **C6, third part: right for group a.** Charades ÷ ROSS is 2.73–5.60 (at least 2.0 predicted).
- C3 and C5 are about 32 nodes; F1-32 tests them.

**What follows:**
- **Group a at 1–16 nodes is paper-grade.**
  - The table at the top of this file is replaced once F1b (group b) and F1-32 finish.
  - σ 1,000 takes the better of PP 2,048 (here) and F1b's PP 512 at each node count.
- **Not followed up now:** the controller's 1–6% gap to W 300 at lookahead 100. It stays within C4's bound and the robustness claim, and section 240's plan has no run for it.

### §243 · F1b results, and F1 at 1–16 nodes: Charades leads Devastator in all 40 PHOLD cells (1.08–2.25), each ratio 1.06–1.25× A1's; Charades ÷ ROSS 2.73–5.95; the controller is 0.930–1.032 of the better fixed W (2026-11-06; skx-dev batch job 3689513, 16 nodes)

> **Status: current for PHOLD at 1–16 nodes.** Design and predictions in section 240; group a in section 242. This and section 242 replace A1 (sections 142–143) in the paper table; the 32-node column comes from F1-32.
> - **Superseded in part (2026-11-08, section 261):** the 8-node column. Its series ran on nodes 0–7 beside three other streams, and node 0, the batch host, slows runs placed on it (section 259). Rerun with node 0 idle (job R8), Devastator ran 3–10% faster at 8 nodes, and Charades ÷ Devastator there is 1.32 (σ 500), 1.58 (σ 2,000), 1.99 (uniform) and 1.20 (lookahead 10 σ 500). The other node counts stand.
> - **Job:** 1 h 4 min of the 1 h 55 min limit. Gate 36/36. The guard cancelled the skx copy 3688914 when this copy started. The 8-, 4-, 2- and 1-node series ran side by side (15:15–15:44), then 16 nodes (15:44–16:15).
> - **Runs:** 615 (Charades 270, Devastator 180, ROSS 165; uniform has no ROSS window arm), none failed.
> - **Data:** `~/charades-data/f1/scale240/b_j3689513/`.
> - **Summaries:**
>   - Group b against A1b: `~/charades-data/f1/f1_240_summary.py`, output `scale240/b_j3689513_summary.txt`.
>   - Both groups against A1, combined: `f1_240_combine.py`, output `scale240/combined_1_16_summary.txt`.
> - **Counts (C1, PHOLD part):** every cell of both groups commits one count in all three engines.

**Charades ÷ Devastator, all eight workloads** (Charades' controller at its better htram setting ÷ Devastator's best W; median of 3 reps; higher is better). A1's ratio is in brackets, recomputed with the same rule; σ 1,000 differs from the table at the top of this file by 0.01 at 2 and 16 nodes.

| workload | 1 node | 2 | 4 | 8 | 16 |
|---|---|---|---|---|---|
| σ 100 | 1.26 (1.10) | 1.23 (1.06) | 1.21 (1.03) | 1.30 (1.03) | 1.25 (1.04) |
| σ 500 | 1.19 (1.03) | 1.19 (1.03) | 1.23 (1.08) | 1.46 (1.20) | 1.35 (1.19) |
| σ 1,000 | 1.20 (1.07) | 1.30 (1.13) | 1.40 (1.22) | 1.55 (1.33) | 1.60 (1.30) |
| σ 2,000 | 1.44 (1.27) | 1.55 (1.37) | 1.52 (1.34) | 1.61 (1.38) | 1.63 (1.35) |
| σ 4,000 | 1.46 (1.32) | 1.90 (1.66) | 1.86 (1.67) | 1.91 (1.66) | 1.93 (1.60) |
| uniform | 1.57 (1.38) | 2.03 (1.87) | 2.25 (1.99) | 2.14 (1.94) | 2.01 (1.84) |
| lookahead 10, σ 500 | 1.08 (**0.95**) | 1.09 (**0.97**) | 1.15 (1.02) | 1.30 (1.15) | 1.31 (1.14) |
| lookahead 10, σ 2,000 | 1.27 (1.19) | 1.41 (1.28) | 1.38 (1.27) | 1.45 (1.28) | 1.49 (1.35) |

(Bold: below 1.) σ 1,000 takes F1b's PP 512 series at 1 and 8 nodes and F1a's PP 2,048 at 2, 4 and 16. Its Devastator rate is F1a's, so those two cells mix two allocations.

**Per workload** (rates in M committed ev/s, median of 3, higher is better; per-node rate at 16 ÷ at 1 node, 1.0 is perfect):

| workload | M ev/s at 16 nodes, Charades / Devastator / ROSS | per-node rate 16 ÷ 1, Charades / Devastator / ROSS | Charades ÷ ROSS, 1–16 nodes (higher is better) | controller ÷ better fixed W, 1–16 nodes (higher is better) |
|---|---|---|---|---|
| σ 100 | 802.7 / 644.5 / 216.1 | 0.95 / **0.96** / 0.70 | 2.73–3.71 | 0.966–0.976 |
| σ 500 | 676.6 / 502.4 / 145.5 | **0.91** / 0.81 / 0.79 | 4.04–4.67 | 0.930–0.973 |
| σ 1,000 | 665.6 / 415.9 / 122.4 | **0.94** / 0.70 / 0.80 | 4.62–5.44 | 0.939–0.979 (PP 2,048: 0.939–0.968; PP 512: 0.959–0.979) |
| σ 2,000 | 594.7 / 364.3 / 105.5 | **0.88** / 0.77 / 0.72 | 4.60–5.64 | 0.961–0.976 |
| σ 4,000 | 552.3 / 285.5 / 98.6 | **0.83** / 0.63 / 0.67 | 4.51–5.60 | 0.945–0.991 |
| uniform | 384.5 / 191.0 / 90.9 | 0.52 / 0.41 / **0.61** | 4.23–5.95 | 0.959–1.003 |
| lookahead 10, σ 500 | 641.7 / 491.4 / 143.3 | **0.96** / 0.79 / 0.85 | 3.95–4.48 | 0.972–0.993 |
| lookahead 10, σ 2,000 | 519.3 / 347.4 / 103.9 | **0.89** / 0.75 / 0.75 | 4.21–5.00 | 0.976–1.032 |

(Bold: the best of the three engines.)

**Each engine's rate ÷ its own in A1** (group b against A1b; group a in section 242; 1.0 is unchanged):
- **Charades** (controller): 1.08–1.23 (group a: 1.09–1.22).
- **Devastator:** 0.98–1.05 (group a: 0.97–1.02).
- **ROSS:** 0.98–1.04 (group a: 0.96–1.03).

**What the job shows:**
- **Charades leads in all 40 cells.**
  - In A1 it trailed on lookahead 10 σ 500 at 1 and 2 nodes (0.95, 0.97); those cells are now 1.08 and 1.09, the lowest of the 40.
  - The largest lead is on uniform: 2.01–2.25 at 2–16 nodes.
- **As in group a, the gain is Charades' own:** Devastator and ROSS reproduce A1 within 5%.
- **Per-node rate from 1 to 16 nodes:** Charades keeps the most in 6 of 8 workloads.
  - The exceptions are σ 100 (Devastator 0.96 against 0.95) and uniform (ROSS 0.61 against 0.52).
  - On uniform every engine loses the most: Charades 0.52, Devastator 0.41.
- **The controller** is 0.930–1.032 of the better fixed W.
  - Its lowest cell is σ 500 at 16 nodes, against W 400. Paired by rep it is 0.965, 0.930 and 0.921. Its rate fell 8% from rep 1 to rep 3, against 4% for W 400.
  - In that cell its mean W is 378–402 and it rolls back 0.03–0.05% of events, so rollback is not what costs it.
  - **A1's controller arm was a different rule:** `q:0.001` is `--ctl=1` (ε 0.001); F1 runs the frozen rule, `--ctl=3` bracketed (`mb:0`).
    - Against W 400 at 8–16 nodes on lookahead 100, A1's ε rule was 0.96–1.06 and F1's frozen rule 0.93–1.02. That also crosses trees.
    - The freeze (section 185) chose the bracketed rule knowing its range: 0.91–1.03 in job N, with the ε rule at 0.31–0.34 on dragonfly. F1's 0.930–1.032 matches it.
- **ROSS's window** is ROSS's best in 11 of the 40 cells (lookahead 10 σ 500 at every node count, lookahead 10 σ 2,000 at 2–16, σ 500 and σ 2,000 at 16), by at most 2.7% over its next-best arm. Conservative is ROSS's best in most other cells, as RW suggested (section 241).

**Predictions (1–16 nodes):**
- **C1 (PHOLD): right.** One count per cell in all three engines, in all 40 cells.
- **C2: mostly right.**
  - Charades leads in all 40 cells (A1: 38): right.
  - Each ratio is 1.06–1.25× A1's, and 36 of 40 fall in the predicted 1.10–1.30. The four below, all 1.06–1.09, are lookahead 10 σ 2,000 at 1 and 4 nodes and uniform at 2 and 16.
- **C4: right at 1–16 nodes.** 0.930–1.032 against at least 0.93; σ 500 at 16 nodes is at the bound.
- **C6, third part: right at 1–16 nodes.** Charades ÷ ROSS is 2.73–5.95.
- C3 and C5 (32 nodes) wait for F1-32.

**What follows:**
- **PHOLD at 1–16 nodes is paper-grade** on 85a2aad: the table above replaces A1's.
- **The table at the top of this file** is rewritten when F1-32 adds the 32-node column. Until then, the note above it points here.
- **F5a (3688915)** is the last 16-node job; with its 1 h 55 min limit it fits skx-dev.

### §252 · F1-32 results, and F1 at 1–32 nodes: Charades leads Devastator in all 48 PHOLD cells, 1.26–2.01 at 32 nodes (old: 0.89–1.66); from 16 to 32 nodes it keeps 0.82–1.00 of its per-node rate (old: 0.72–0.87); Charades ÷ ROSS 2.73–6.08; the controller is 0.94–1.07 of the best fixed W at 32 nodes (median of 5 reps), but on σ 100 it stays at W ≈ 290 in 2 of 5 reps (0.79–0.80) (2026-11-07; skx batch job 3688916, 32 nodes)

> **Status: current.** Design and predictions in section 240. With sections 242–243 (1–16 nodes), it replaces A1 and A2r (sections 142–143 and 153) in the paper's PHOLD table.
> - **Superseded in part (2026-11-08, section 257):** at 32 nodes on lookahead 10 the best fixed W is 75, which this job did not run (8–15% faster than W 50 and W 100 in job AG32). Against it this job's controller is 0.96–0.97, not 1.05–1.07, so the 32-node controller range is 0.94–0.98. W 400 at lookahead 100 stays the best fixed W (W 500 and 600 are slower), and the Charades ÷ Devastator ratios, which use the controller, are unchanged.
> - **Job:** 2 h 19 min (08:56–11:15), 32 nodes. The gate passed.
>   - 5 reps of all eight workloads, as in A2r's layout.
>   - Charades 150 runs, Devastator 150, ROSS 115. None failed.
> - **Launch:** F1's launch carries no diagnostics (section 247's check), so no rate here carries a flag's cost.
> - **Data:** `~/charades-data/f1/scale240/big_j3688916/` (with `scale240_3688916.out`). The summaries are in `~/charades-data/f1/scale240/`:
>   - `f1_240_summary.py`, run on this job against A2r (`~/charades-data/scale32/scale32/n32_j3657016`), output in `big_j3688916_summary.txt`;
>   - `f1_240_combine32.py` (F1a + F1b + F1-32 against A1a + A1b + A2r), output in `combined_1_32_summary.txt`.
> - **Counts (C1, PHOLD part):** every cell commits one count in all three engines.

**Charades ÷ Devastator, 1–32 nodes** (Charades' controller at the better htram setting ÷ Devastator's best W; medians, 3 reps at 1–16 nodes and 5 at 32; old table in parentheses; higher is better):

| workload | 1 | 2 | 4 | 8 | 16 | 32 |
|---|---|---|---|---|---|---|
| σ 100 | 1.26 (1.10) | 1.23 (1.06) | 1.21 (1.03) | 1.30 (1.03) | 1.25 (1.04) | 1.26 (**0.89**) |
| σ 500 | 1.19 (1.03) | 1.19 (1.03) | 1.23 (1.08) | 1.46 (1.20) | 1.35 (1.19) | 1.46 (1.04) |
| σ 1,000 | 1.20 (1.07) | 1.30 (1.13) | 1.40 (1.22) | 1.55 (1.33) | 1.60 (1.30) | 1.58 (1.14) |
| σ 2,000 | 1.44 (1.27) | 1.55 (1.37) | 1.52 (1.34) | 1.61 (1.38) | 1.63 (1.35) | 1.66 (1.24) |
| σ 4,000 | 1.46 (1.32) | 1.90 (1.66) | 1.86 (1.67) | 1.91 (1.66) | 1.93 (1.60) | 1.98 (1.39) |
| uniform | 1.57 (1.38) | 2.03 (1.87) | 2.25 (1.99) | 2.14 (1.94) | 2.01 (1.84) | 2.01 (1.66) |
| lookahead 10, σ 500 | 1.08 (**0.95**) | 1.09 (**0.97**) | 1.15 (1.02) | 1.30 (1.15) | 1.31 (1.14) | 1.31 (**0.99**) |
| lookahead 10, σ 2,000 | 1.27 (1.19) | 1.41 (1.28) | 1.38 (1.27) | 1.45 (1.28) | 1.49 (1.35) | 1.51 (1.11) |

(Bold: below 1.) At 32 nodes each ratio is 1.21–1.43× the old one.

**At 32 nodes** (medians of 5 reps; per-node rate as a share of perfect scaling, each engine at its own best, Charades at its controller):

| workload | M ev/s, Charades / Devastator / ROSS | per-node rate 16→32, C / D / R | per-node rate 1→32, C / D / R | Charades ÷ ROSS at 1–32 nodes | controller ÷ best fixed W (median; per rep) |
|---|---|---|---|---|---|
| σ 100 | 1,532.3 / 1,216.0 / 378.3 | 0.95 / 0.94 / 0.88 | 0.91 / 0.91 / 0.61 | 2.73–4.05 | 0.94 (0.79–1.06) |
| σ 500 | 1,358.5 / 927.5 / 272.9 | 1.00 / 0.92 / 0.94 | 0.92 / 0.75 / 0.74 | 4.04–4.98 | 0.95 (0.92–0.97) |
| σ 1,000 | 1,279.7 / 810.2 / 234.6 | 0.96 / 0.97 / 0.96 | 0.90 / 0.69 / 0.77 | 4.62–5.46 | 0.97 (0.90–0.99) |
| σ 2,000 | 1,163.5 / 699.5 / 195.8 | 0.98 / 0.96 / 0.93 | 0.86 / 0.74 / 0.66 | 4.60–5.94 | 0.95 (0.85–0.97) |
| σ 4,000 | 1,067.6 / 540.2 / 175.6 | 0.97 / 0.95 / 0.89 | 0.80 / 0.59 / 0.59 | 4.51–6.08 | 0.96 (0.92–0.97) |
| uniform | 627.8 / 312.4 / 162.4 | 0.82 / 0.82 / 0.89 | 0.43 / 0.33 / 0.54 | 3.87–5.95 | 0.98 (0.97–0.99) |
| lookahead 10, σ 500 | 1,222.4 / 930.8 / 269.4 | 0.95 / 0.95 / 0.94 | 0.92 / 0.75 / 0.80 | 3.95–4.54 | 1.07 (0.97–1.06) |
| lookahead 10, σ 2,000 | 1,012.8 / 669.6 / 195.6 | 0.98 / 0.96 / 0.94 | 0.86 / 0.73 / 0.70 | 4.21–5.18 | 1.05 (0.94–1.06) |

(The median ratio is the ratio of medians, so it can lie outside the per-rep range: on lookahead 10, σ 500 the controller's median rate is 1.07× the fixed W's.)

- **From 16 to 32 nodes,** Charades now keeps 0.82–1.00 of its per-node rate against Devastator's 0.82–0.97. It keeps more than Devastator in 6 of 8 workloads; it is level on uniform (0.82 each) and just behind on σ 1,000 (0.96 against 0.97). In the old table it lost more in every workload (0.72–0.87 against 0.80–0.98).
  - From 1 to 32 nodes, Charades scales best of the three in 7 of 8 workloads; it is level with Devastator on σ 100 (0.908 against 0.906).
  - On uniform, ROSS scales best from 1 to 32 (0.54 against 0.43); Charades still runs 3.87× ROSS there.
  - The old table's 16 → 32 loss was mostly automatic NUMA balancing (sections 164, 166). The launch has avoided it since (`numactl --localalloc`), and round 3 and per-LP rollback added to Charades' rate.
- **ROSS** is best with its window on six workloads, best conservative on σ 100, and best optimistic without a window on uniform (job RW's windows, section 241).
- **Best fixed W.** Charades' best fixed W at 32 nodes is the grid's widest: W 400 on every lookahead-100 workload and W 100 on lookahead 10, σ 500.
  - The controller's mean W is 316–442 on lookahead-100 workloads, apart from σ 100's two low reps. So the best fixed W may lie a little above 400, and "÷ best fixed W" may be slightly high.
  - Devastator's best W is inside its grid: 1,000 at lookahead 100, and 200 at lookahead 10.

**The controller at 32 nodes, per rep** (÷ the best fixed W of the same rep; mean W):
- **σ 100 is bimodal.**
  - In reps 1, 2 and 5 the controller moves to a mean W of 433–438 and runs at 0.96–1.06.
  - In reps 3 and 4 it stays at 290–292 and runs at 0.79–0.80. That is also below fixed W 300 in those reps (1,303–1,305 against 1,508–1,513 M ev/s), and it makes 3,941–3,954 rounds against 2,912–3,053.
  - So in those reps it neither moved up nor matched the fixed window it sat at. These runs carry no per-round log (the paper launch), so which trials it rejected is not known.
  - Section 173 found that σ 100 at 32 nodes wants W 400–600.
- **Elsewhere** it is 0.85–1.06 per rep.
- **Lookahead 10, σ 2,000 at PP 512, rep 5:** 0.59 at a mean W of 180, where the other reps sat at 68–76. The table takes WPs 512 there (the better setting), where every rep is 0.94–1.06.

**Spread between reps** (max ÷ min, best arm):
- **Devastator:** σ 4,000 had two slow reps (430–437 against 540–558 M ev/s, 1.30), and σ 100 spread 1.13. The other six spread at most 1.07.
  - Against Devastator's fastest rep, Charades' controller is still 1.19–2.00 ahead (σ 100 1.19, σ 4,000 1.91).
- **ROSS:** 1.41 on σ 4,000, 1.26 on σ 100 and 1.23 on uniform.
- **No rep was disturbed.** Every fixed-W run made 1.00–1.05 count waves per GVT advance.

**Predictions (section 240):**
- **C1 (PHOLD, 32 nodes): right.**
- **C3: right.**
  - Charades leads in all eight at 32 nodes, each at 1.26 or more (predicted at least 1.05). The median is 1.55 (predicted at least 1.3).
  - It also holds against Devastator's fastest rep (1.19–2.00).
- **C4 at 32 nodes: right on medians, not in every rep.** The median per cell is 0.94–1.07 (predicted at least 0.90), but σ 100 falls to 0.79–0.80 in 2 of 5 reps.
- **C5: mostly right.**
  - Charades' per-node rate from 16 to 32 nodes at its best arm is 0.95–1.01 on five lookahead-100 workloads.
  - On uniform it is 0.83 (predicted at least 0.88), where Devastator has 0.82.
- **C6, third part: right at 32 nodes.** Charades ÷ ROSS is 3.87–6.08.

**What follows:**
- **The paper's PHOLD table** is F1 at 1–32 nodes (sections 242, 243 and this one). It replaces the table on the front page and A2r (section 153).
  - Charades leads in 48 of 48 cells (old: 44).
  - Charades ÷ Devastator is 1.08–2.25, and 1.26–2.01 at 32 nodes.
  - Charades ÷ ROSS is 2.73–6.08.
- **Claim 3's scaling sentence changes.** Charades no longer loses more per node than Devastator from 16 to 32 nodes.
- **σ 100's low controller reps are reported, not explained** (user decision 2026-11-07: report slow reps, keep the controller). A 32-node check run with the per-round log on σ 100 would show which trials it rejects there.
- **A fixed W above 400 at 32 nodes** was not run.

### §255 · How each engine slows as events go to other processes, and its GVT pace, from F1's data: Charades keeps 0.41–0.76 of its σ 100 rate from σ 2,000 to uniform at 32 nodes, Devastator 0.26–0.58; Devastator's time per GVT advance grows 4.6× from σ 100 to uniform, Charades' 2.4×, but in both it follows the event rate (2026-11-07; offline, no runs)

> **Status: current.** Analysis of F1's PHOLD runs (sections 242, 243, 252; jobs 3689004, 3689513, 3688916) for the user's question: does Charades lose less than Devastator as communication becomes remote, and does that answer the future work Devastator's authors name ("with so many messages flying around, the asynchronous GVT algorithm is slower to complete and the adaptive moving time window is slow to adapt")?
> - **Scripts:** `~/charades-data/f1/gvt_vs_remote.py`, output `gvt_vs_remote.txt`. The rate table comes from `f1_240_summary.py`'s cells.
> - **Remote share** is the share of executed events whose sends go to another process: Charades' `Events Through htram` ÷ executed events, in its controller runs. The local fast path keeps same-process events out of htram (section 222). It is the same at every node count from 4 up (weak scaling), apart from uniform: 87.5% at 4 nodes, 96.8% at 16, 98.4% at 32. At 1 node it caps at 50% (two processes).

**Each engine's rate as a share of its own σ 100 rate, 32 nodes** (medians of 5 reps; each engine at its best arm as in F1's table; higher means it loses less):

| workload | events sent to another process | Charades | Devastator | ROSS | Charades ÷ Devastator |
|---|---|---|---|---|---|
| σ 100 | 2.7% | 1.00 | 1.00 | 1.00 | 1.26 |
| σ 500 | 13.5% | 0.89 | 0.76 | 0.72 | 1.46 |
| σ 1,000 | 27% | 0.84 | 0.67 | 0.62 | 1.58 |
| σ 2,000 | 50% | 0.76 | 0.58 | 0.52 | 1.66 |
| σ 4,000 | 72% | 0.70 | 0.44 | 0.46 | 1.98 |
| uniform | 98% | 0.41 | 0.26 | 0.43 | 2.01 |

- **At 4 and 16 nodes the order is the same.**
  - At 16 nodes: Charades 0.74 / 0.69 / 0.48 at σ 2,000 / σ 4,000 / uniform, Devastator 0.57 / 0.44 / 0.30.
  - At 4 nodes: Charades 0.75 / 0.70 / 0.74, Devastator 0.59 / 0.46 / 0.40.
- **At 1 node,** where "remote" means the node's other process, Charades loses more at σ 500–1,000 (0.79–0.88 against Devastator's 0.88–0.93) and less from σ 2,000 up (0.79–0.87 against 0.68–0.70).
- **Devastator stays ahead of ROSS everywhere** (Devastator ÷ ROSS on uniform: 3.1 at 1 node, 1.92 at 32). The crossover the Devastator paper reports on Frontera (ROSS 8.7× faster at 2 nodes, σ 10⁴) does not appear on this system with these settings. Devastator's lead over ROSS does shrink as remote traffic grows (3.2 at σ 100, 32 nodes).

**Why uniform drops most for Charades: events per htram message** (controller runs, rep 1):

| workload | 4 nodes | 16 nodes | 32 nodes |
|---|---|---|---|
| σ 100 (PP 2,048) | 34.6 | 34.4 | 32.9 |
| σ 2,000 (PP 512) | 64.9 | 62.8 | 56.7 |
| σ 4,000 (PP 512) | 60.8 | 52.9 | 49.8 |
| uniform (PP 512) | 102.0 | 14.5 | 8.4 |

- **Uniform sends to every process.** Each destination's buffer fills slowly before its deadline flush, so the bundling that carries Charades elsewhere thins out from 16 nodes up.
- **Gaussian destinations stay within a bounded neighbourhood,** so messages keep 50–65 events at every node count.

**GVT pace** (per GVT advance; Charades at its controller, Devastator at its best fixed W, 1,000 at lookahead 100; medians):

| workload | Charades: wall ms per advance, 32 nodes | Devastator: wall ms per advance, 32 nodes | Devastator ÷ Charades, 4 / 16 / 32 nodes |
|---|---|---|---|
| σ 100 | 0.154 | 0.719 | 2.2 / 4.4 / 4.7 |
| σ 2,000 | 0.192 | 1.445 | 7.6 / 8.1 / 7.5 |
| σ 4,000 | 0.209 | 1.897 | 9.6 / 9.6 / 9.1 |
| uniform | 0.370 | 3.310 | 6.8 / 10.1 / 9.0 |

- **How the advances are counted:**
  - Devastator's advances are its window updates: `global_status.update` runs only when an epoch advances GVT (`pdes.cxx:896`), and the bench prints the count. Its window is fixed in these runs.
  - Charades makes one count wave per GVT advance (1.00) in every fixed-W run at every remote share, so none of its waves is wasted when traffic is heavy.
- **What each advance covers:** Charades advances about 80 time units per GVT at 32 nodes (W 400) and commits 220–240 k events. Devastator advances 300–366 (W 1,000) and commits 850–1,034 k.
- **From σ 100 to uniform at 32 nodes,** Devastator's time per advance grows 4.6× and Charades' 2.4×.
- **Both track the event rate:** committed events per advance stay nearly constant in each engine (Charades 221–239 k, Devastator 850–1,034 k), so the time per advance grows as the rate falls.
- **So this data cannot separate "GVT is slower to complete" from "events are slower".** Telling them apart would take traces inside Devastator. The paper should not claim a faster GVT; it can say Charades' GVT advances 4.7–9.1× as often at 32 nodes and wastes no wave.

**What this supports for the paper:**
- **Supported:**
  - Charades loses less than Devastator as communication becomes remote, from 4 nodes up, so its lead grows with the remote share (1.26 to 2.01 at 32 nodes).
  - Its window controller stays within 1–4% of the best fixed W on uniform and σ 2,000 (section 251), where Devastator's window fell to 0.09 or did not finish. That answers "slow to adapt".
- **Not supported:**
  - A fix for the Devastator paper's ROSS crossover, which does not appear here.
  - A faster GVT, which was not measured apart from the event rate.
  - Behaviour beyond 32 nodes. Uniform's message size is already falling at 32 (job AG32, section 256, measures what bundling still buys there).
- **Wording:** "Charades loses less than Devastator as communication becomes remote", not "solves".

### §260 · The 8-node columns of F1 and F5 rerun with the batch host idle, GC's four 1-node cells off node 0, and whether other streams' traffic slows an 8-node run (job R8 design, 2026-11-08; written before any runs)

> **Status: design.**
> - **User decision 2026-11-08:** rerun those columns (F1's and F5's 8-node columns and GC's four node-0 cells; VLSI's 8-node column not included).
> - **Submitted 2026-11-08:** 3695259 (skx) and 3695260 (skx-dev). The skx copy started at once and cancelled the skx-dev copy. Its script began about 3 minutes after the job did (14:18 → 14:20:54): the batch node's login profile waited on /work2 ("mounted not FULL nor IDLE"). The gate passed 63/63.
> - **Script:** `$WORK/charades-runs/r8_260.slurm` (copy in `~/charades-data/f1/`). It runs on skx-dev with an skx copy (twin guard), 15 nodes, limit 1:58, about 95 minutes, `-x c455-081`.
> - **Code:** tree `charades-r5` (85a2aad), Devastator's and ROSS's builds as in F1 and F5.

**Why.**
- Job GC (section 259) found that a run on node 0, the batch host, is slowed while several streams run side by side, Devastator more than Charades. Node 0 runs the job script and every stream's `srun` clients and polling loops.
- F1's and F5's 8-node streams ran on nodes 0–7 beside three other streams. Uniform at 8 nodes, run alone in GC, gave Devastator 1.085× its F1 rate and Charades 1.011×, so the 8-node ratios may overstate Charades' lead by up to about 7%.
- GC's four 1-node cells on node 0 (σ 100, 500, 1,000 and 2,000) could not be used.
- GC could not tell whether the batch host or the other streams' network traffic cost the 8-node runs. If it was the traffic, the 2- and 4-node columns, which also ran beside other streams, are suspect too.

**Runs:**
1. **S8, nodes 1–8, 3 reps:**
   - **F1's 8-node column** with F1's arms (scale240.slurm): the eight PHOLD workloads and σ 1,000 with PP 512.
     - Charades: the controller and W 300 / 400 (lookahead 10: 50 / 100) at F1's htram settings.
     - Devastator: W 500 / 1,000 / 2,000 (lookahead 10: 100 / 200 / 400).
     - ROSS: optimistic, conservative, and optimistic with the window job RW chose (none on uniform).
   - **F5's 8-node column** with F5's timing arms (f5scale240.slurm): dragonfly and traffic. F5's check arms `od`, `dg` and `ri` are left out.
     - Charades: dragonfly WPs 512 (the controller, W 10,000 and 20,000) and direct sends at W 10,000 and 20,000; traffic PP 2,048 (the controller, W 500 and 1,000), WPs 512 at W 500 and direct sends at W 500.
     - Devastator: dragonfly W 10,000 / 20,000 / 40,000, traffic W 1,000 / 2,000 / 4,000.
     - ROSS: dragonfly optimistic at windows 2,500 / 5,000 / 7,500; traffic optimistic at windows 1,000 / 2,000, and conservative.
   - Workload order is reversed in even reps, and in F5 so is the order of engines and arms.
2. **S1, node 9, beside S8, 5 reps:** GC's four 1-node cells as in section 258: Devastator's finer grid, and Charades' controller at F1's htram settings. 1-node runs do not use the network.
3. **Check, nodes 1–8, after S1 and S8, 3 reps:**
   - Uniform at 8 nodes: Devastator at W 500 and 1,000, and Charades' controller (PP 512).
   - Each rep runs them alone and with load streams on nodes 9–14, in alternating order. The load is Devastator uniform at 4 nodes (W 500) and Charades uniform at 2 nodes (controller), each repeating until the measured runs end.
   - The check is skipped if less than 18 minutes of the limit remain.
- **Node 0 runs nothing** throughout.

**Flags per arm** (stub run with a fake `srun`: 444 commands, as planned; 165 Charades, 192 Devastator, 87 ROSS):
- No log, stats, trace, digest or report-interval flag appears in any command.
- **Devastator:** for three workloads, the command line in the stub's output header equals F1's word for word, apart from job name and node list. Every Devastator run sets its window in the environment, and none runs adaptive.
- **Charades:** its config files are byte-identical to F1's (four workloads checked) and F5's (traffic and dragonfly).

| engine, arm | flags beyond the launch | source |
|---|---|---|
| Charades, fixed W | `--optimism-window=W --gvt-bucket-size=B --aggregation=1 --agg-mode=M --agg-buffer=N --agg-policy=1 --agg-horizon-margin=8` (B 8, dragonfly 1,000 ps; M 2 = PP, 0 = WPs); direct sends: `--optimism-window=W --gvt-bucket-size=B` only | F1, F5 |
| Charades, controller | `--ctl=3 --ctl-bracket=1` and the htram flags | F1, F5 |
| Devastator, PHOLD | `deva_static_look_dt=W` (environment, through `run_phold.sh`); `--lp-per-rank=128 --start-events=15 --lookahead=L --mean=M --sigma=S --end-time=E --rng=clcg4` (uniform also `--remote=1.0`) | F1 |
| Devastator, traffic and dragonfly | `deva_static_look_dt=W`; F5's model arguments at 8 nodes (traffic `--num-y=368 --total-cars=376832`; dragonfly 22 routers per group, 12 global channels), `--rng=clcg4` | F5 |
| ROSS, PHOLD | `--synch=3 --batch=16 --gvt-interval=64` (optimistic), `--synch=2 --batch=16 --gvt-interval=16` (conservative), optimistic with `--max-opt-lookahead=X`; `--read-buffer=1 --extramem=800000`, 46 ranks per node | F1 |
| ROSS, traffic and dragonfly | optimistic `--batch=64` (traffic) or `--batch=2` (dragonfly) `--gvt-interval=64 --max-opt-lookahead=X`; traffic conservative | F5 |
| warm-ups | Charades σ 100, PP 2,048, W 300, end 512,000; Devastator σ 100, W 1,000 | not counted |

**Predictions:**
- **R8-1. Counts:** one committed count per cell over every engine and arm, equal to F1's, F5's and GC's.
- **R8-2. Rates at 8 nodes, each engine's best arm, this job ÷ F1 or F5:** Devastator 1.03–1.10; Charades 1.00–1.03; ROSS 1.00–1.05.
- **R8-3. Charades ÷ Devastator at 8 nodes** falls by 2–8% per PHOLD workload and stays at 1.20 or more in each. σ 100 and σ 500 lose their bump at 8 nodes: each lands within 0.05 of the range between its 4- and 16-node values.
- **R8-4. Dragonfly and traffic** (F5: 1.91 and 1.26 at 8 nodes): Charades ÷ Devastator falls by 2–8%.
- **R8-5. The four 1-node cells:**
  - Devastator at F1's best W runs at 0.97–1.03 of its F1 rate, with reps spread 1.05 or less;
  - its finer grid gains at most 3%;
  - Charades ÷ Devastator is within 0.05 of F1's (1.26, 1.19, 1.20, 1.44).
- **R8-6. Check:** Devastator at 8 nodes with load on other nodes runs at 0.97 or more of its rate alone (paired per rep, median), and Charades at 0.98 or more. So GC's 8.5% came from the batch host, not from other streams' traffic.
- **R8-7. Spread between reps:** at most 1.10 per arm, apart from at most one slow rep per arm.

**What follows:**
- **F1's and F5's tables take this job's 8-node column** for all three engines. The per-node 1 → 32 columns use 1 and 32 nodes and do not change.
- **GC's part D** takes the four 1-node cells from here.
- **If R8-6 fails** (with load below 0.97 of alone), the 2- and 4-node columns of F1 and F5, which ran beside the 8-node stream, need the same rerun, and the layout rule becomes one multi-node stream at a time.
- **VLSI's 8-node column** used the same layout and stays unchecked.

### §261 · R8 results: with the batch host idle, Devastator runs 3–10% faster at 8 nodes and Charades ÷ Devastator there is 1.20–1.99 on PHOLD (F1: 1.30–2.14), 1.69 on dragonfly (F5's median caught two slow Devastator reps) and 1.26 on traffic; other streams' network traffic does not slow an 8-node run; GC's four 1-node cells match F1 (2026-11-08; skx batch job 3695259, 15 nodes)

> **Status: current.** Design and predictions in section 260.
> - **Job:** 90 minutes (14:18–15:49; the script from 14:20:54). The skx-dev copy (3695260) was cancelled by the guard; gate 63/63. Every run finished; none failed or stalled.
> - **Nodes:** node 0 (c476-034) ran nothing. Node 9 (c479-081) held the 1-node cells.
> - **Data:** `~/charades-data/f1/r8_260/j3695259` (digests and per-round GVT files not copied). `~/charades-data/f1/r8_261.py` writes `r8_260/r8_261_summary.txt`.
> - **Counts:** one committed count per cell over every engine and arm, equal to F1's and F5's; the check's uniform runs commit phase 1's count.

**PHOLD at 8 nodes** (M committed ev/s, median of 3 reps; F1's definitions: Charades = its controller at the better htram setting, Devastator = its best W, ROSS = its best arm; ratios Charades ÷ other, higher is better; F1's value in brackets):

| workload | Charades | Devastator, best W | ROSS, best arm | this job ÷ F1: Charades / Devastator / ROSS | Charades ÷ Devastator | Charades ÷ ROSS |
|---|---|---|---|---|---|---|
| σ 100 | 404.6 | 332.7 (W 500) | 116.4 | 1.027 / 1.095 / 1.027 | **1.22** [1.30] | 3.48 [3.47] |
| σ 500 | 357.4 | 270.4 (W 1,000) | 76.3 | 1.001 / 1.102 / 0.998 | **1.32** [1.46] | 4.68 [4.67] |
| σ 1,000 | 337.9 | 228.3 (W 1,000) | 63.9 | 1.020 / 1.065 / 1.018 | **1.48** [1.55] | 5.29 [5.28] |
| σ 2,000 | 304.0 | 192.9 (W 1,000) | 53.6 | 1.004 / 1.028 / 0.987 | **1.58** [1.61] | 5.67 [5.58] |
| σ 4,000 | 278.4 | 153.2 (W 1,000) | 50.9 | 1.043 / 1.097 / 1.006 | **1.82** [1.91] | 5.47 [5.28] |
| uniform | 229.0 | 115.4 (W 1,000) | 46.8 | 1.007 / 1.087 / 0.972 | **1.99** [2.14] | 4.90 [4.73] |
| lookahead 10, σ 500 | 321.1 | 267.3 (W 200) | 72.6 | 0.992 / 1.074 / 0.988 | **1.20** [1.30] | 4.42 [4.41] |
| lookahead 10, σ 2,000 | 260.8 | 179.1 (W 200) | 52.7 | 1.027 / 1.025 / 1.011 | **1.46** [1.45] | 4.95 [4.87] |

**Traffic and dragonfly at 8 nodes** (F5's definitions; F5's value in brackets):

| application | Charades | Devastator, best W | ROSS, best arm | this job ÷ F5: Charades / Devastator / ROSS | Charades ÷ Devastator | Charades ÷ ROSS |
|---|---|---|---|---|---|---|
| dragonfly | 234.5 | 138.7 (W 20,000 ps) | 74.7 (window 5,000) | 1.006 / 1.135 / 1.003 | **1.69** [1.91] | 3.14 [3.13] |
| traffic | 574.9 | 455.9 (W 2,000) | 270.1 (window 2,000) | 1.025 / 1.022 / 1.008 | **1.26** [1.26] | 2.13 [2.09] |

**The check: uniform at 8 nodes beside load streams on nodes 9–14** (each run with load ÷ the same arm alone in the same rep; higher means the load cost less):

| arm | rep 1 / rep 2 / rep 3 | median |
|---|---|---|
| Devastator, W 500 | 1.002 / 1.003 / 1.008 | 1.003 |
| Devastator, W 1,000 | 1.002 / 0.995 / 1.011 | 1.002 |
| Charades' controller | 1.012 / 1.006 / 0.998 | 1.006 |

The load ran 15 Devastator 4-node runs and 9 Charades 2-node runs across the three load phases.

**GC's four 1-node cells, on node 9** (5 reps):

| workload | Devastator's best W on GC's grid (÷ best at F1's points) | this job ÷ F1: Charades / Devastator | Charades ÷ Devastator [F1] |
|---|---|---|---|
| σ 100 | 1,400 (1.002) | 0.966 / 0.946 | 1.28 [1.26] |
| σ 500 | 700 (1.000; W 500 level) | 0.964 / 0.956 | 1.20 [1.19] |
| σ 1,000 | 1,000 (1.000) | 0.965 / 0.954 | 1.21 [1.20] |
| σ 2,000 | 500 (1.000) | 0.952 / 0.953 | 1.44 [1.44] |

- **The batch host was the cause.**
  - With node 0 idle, Devastator's best 8-node rate is 1.03–1.10× F1's on all eight PHOLD workloads, against 0.99–1.04× for Charades and 0.97–1.03× for ROSS.
  - Beside load streams on other nodes, both engines ran at 1.00 of their rate alone (0.995–1.012 per rep). Other streams' network traffic does not slow an 8-node run.
  - So F1's and F5's 1-, 2- and 4-node columns, which never ran on node 0, stand.
- **Charades ÷ Devastator at 8 nodes** is 1.20–1.99 on PHOLD, 0.91–1.00× F1's value, and Charades stays ahead in every cell.
  - The closest 8-node cell is lookahead 10 σ 500 (1.20); the table's closest cell is still the same workload at 1 node (1.08).
  - σ 100's and σ 500's bump at 8 nodes is gone: σ 100 is 1.21 / 1.22 / 1.25 at 4 / 8 / 16 nodes, σ 500 1.23 / 1.32 / 1.35.
- **Dragonfly's 1.91 → 1.69 is mostly F5's slow reps, not the batch host.**
  - In F5, Devastator at W 20,000 ran two of three reps at 62 M ev/s against 137, so the median picked W 10,000 (122.1).
  - Here W 20,000 ran at 138.5–139.1 in all three reps. F5's ratio against Devastator's fastest rep was 1.70.
  - Traffic is unchanged (1.26).
- **Charades ÷ ROSS at 8 nodes** moves by at most 0.19 (σ 4,000 5.28 → 5.47, uniform 4.73 → 4.90) and stays inside each workload's 1–32-node range.
- **Devastator's slow reps also happen off the batch host:** 4 of its 90 timing runs at 8 nodes ran 2–4× slower with the same events (dragonfly at W 10,000 and W 40,000, lookahead 10 σ 2,000 at W 100 and W 200, once each). The medians of 3 absorb them.
- **Dragonfly's controller** is 1.031 of Charades' best fixed W at 8 nodes (F5: 1.036). F5's grid lacks W 15,000 ps, which section 259 found best at 4 and 16 nodes.
- **GC's four 1-node cells:**
  - Devastator's finer grid gains at most 0.2%, and its reps spread 1.01–1.05 (on node 0 in GC: 1.12–1.37).
  - Both engines ran at 0.95–0.97 of their F1 rates on this node, so Charades ÷ Devastator matches F1's within 0.02.
  - With these cells, GC's part D is complete: Devastator's finer grid gains at most 1.4% in all 14 cells, and Charades leads in all.

**Predictions (section 260):**
- **R8-1 right.**
- **R8-2 mostly right:**
  - Devastator 1.025–1.102, in range in 5 of 8 and within 0.005 of it in the other three;
  - Charades 0.992–1.043, in range in 6 of 8;
  - ROSS 0.972–1.027, in range in 4 of 8; the other four are 0.97–1.00.
- **R8-3 mostly right:**
  - The ratio falls by 2.4–7.7% in 6 of 8 workloads. σ 500 falls by 9.2%, and lookahead 10 σ 2,000 does not fall (1.003×).
  - Every workload stays at 1.20 or more (lookahead 10 σ 500: 1.201).
  - The σ 100 and σ 500 bumps are gone.
- **R8-4 wrong in size:** traffic does not fall, and dragonfly falls by 11.5%, mostly from F5's slow reps.
- **R8-5 mostly right:** the finer grid gains at most 0.2%, reps spread at most 1.05, and the ratios are within 0.02 of F1's. But Devastator ran at 0.95–0.96 of its F1 rate, not 0.97–1.03; so did Charades, on this node.
- **R8-6 right:** 1.002–1.006.
- **R8-7 right:** 4 of 102 arms spread above 1.10, each from one slow Devastator rep (1.00–1.03 without it).

**What follows:**
- **F1's PHOLD table** takes this job's 8-node column: 1.22 / 1.32 / 1.48 / 1.58 / 1.82 / 1.99 / 1.20 / 1.46. Its range (1.08–2.25) and "ahead in all 48 cells" stand. The Charades ÷ ROSS ranges and the per-node columns do not change.
- **F5's applications table** takes dragonfly 1.69 and traffic 1.26 at 8 nodes, with Charades ÷ ROSS 3.14 and 2.13 (dragonfly's range becomes 2.93–3.14).
- **The layout rule** stays: node 0 runs nothing while streams run side by side. Multi-node streams side by side on other nodes are fine.
- **Still open:** VLSI's 8-node column (the same layout; 1.30).

## Earlier

Superseded or historical sections, in the order they were written. Their numbers came from an older stack, launch or setting, or a later section replaced them; each says which.

### §1 · First Stampede3 measurements (2026-10-19, idev job 3615231, 2 skx nodes)

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

### §2 · Optimism window sweep (2026-10-19, idev job 3615917, 4 skx nodes)

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

### §11 · Gaussian PHOLD σ sweep (design, 2026-10-21; written before any runs)

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

### §12 · Gaussian PHOLD σ sweep, results (2026-10-21, idev job 3624866, 4 skx nodes)

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

### §19 · Three engines on Gaussian PHOLD, 4 nodes (same job; first real comparison)

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

### §20 · Three engines: the gaps filled (2026-10-21, idev job 3626388, 4 skx nodes)

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

### §27 · Gaussian PHOLD σ sweep on the fast stack (design, 2026-10-22; written before any runs)

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

### §28 · Gaussian PHOLD σ sweep on the fast stack, results (2026-10-22, idev job 3628587, 4 skx nodes)

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

### §142 · A1a, weak scaling 1–16 nodes, group a (σ 100, σ 1,000, σ 4,000, lookahead 10 σ 2,000), results (2026-10-28; skx-dev batch job 3653803, 16 nodes)

> **Superseded (2026-11-07):** the paper table now comes from §242.

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

### §143 · A1b, weak scaling 1–16 nodes, group b (σ 500, σ 2,000, uniform, lookahead 10 σ 500) and σ 1,000 with both htram settings, results; all eight workloads at 1–16 nodes (2026-10-28; skx-dev batch job 3654651, 16 nodes)

> **Superseded (2026-11-07):** the paper table now comes from §243.

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

### §144 · A2, 32 nodes: a noisy allocation, so the 32-node point is rerun (A2 results and A2r design, 2026-10-29; skx batch job 3653806, 32 nodes; A2r design written before its run)

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

### §153 · A2r, 32 nodes, results: Charades leads in 6 of 8 but loses more per node from 16 to 32 nodes than Devastator everywhere; a start-up transient at σ 100, per-wave work on uniform (2026-10-29; skx batch job 3657016, 32 nodes)

> **Superseded (2026-11-07):** the paper's 32-node PHOLD column now comes from §252 (job F1-32: the final defaults, `numactl --localalloc`, 5 reps). There Charades leads in all eight workloads (1.26–2.01) and keeps 0.82–1.00 of its per-node rate from 16 to 32 nodes.

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
