# The optimism-window controller

Every controller design and test: the delay-quantile rule, the aggregation bound, the measured-cost rule and its freeze, where the best window lies at scale, robustness (F4), and the controller's own cost (CC). Part of the Charades results: the current paper tables are on the front page, [../RESULTS.md](../RESULTS.md), and every section's date, job, status and file is in [INDEX.md](INDEX.md). Sections keep the numbers (§N) they had in the single RESULTS.md they came from (split 2026-11-07); "section N" anywhere means §N.

| § | date | status | section |
|---|---|---|---|
| 29 | 2026-10-22 | design | Floor-aware controller, `--ctl-floor` |
| 30 | 2026-10-22 | provisional | Floor-aware controller, results |
| 37 | 2026-10-23 | design | Controller level, `--agg-scope`, σ 100 profile |
| 38 | 2026-10-23 | current | Controller level, `--agg-scope`, σ 100 profile, results |
| 39 | 2026-10-23 | design | Controller: an aggregation bound, cheaper bookkeeping, a faster start |
| 40 | 2026-10-23 | current | Controller: an aggregation bound, cheaper bookkeeping, a faster start, results |
| 167 | 2026-11-01 | design | Why the controller falls short at 32 nodes: where the best window lies at 16 and 32 nodes, and how far GVT… |
| 173 | 2026-11-01 | current | Job K results: only σ 100 at 32 nodes wants a wider window (W 400–600 beat W 300 in every rep); the κ bound… |
| 174 | 2026-11-01 | design | What a wider window buys: PE time blocked at the window's edge, by W, at 4, 16 and 32 nodes |
| 176 | 2026-11-01 | current | Job L16 results: above W 300 a wider window costs blocked time, not busy time; GVT advance per wave levels… |
| 178 | 2026-11-01 | design | The controller on dragonfly: start-up or its rollback target? Long runs at 1 and 4 nodes |
| 179 | 2026-11-01 | current | Job D results: on dragonfly both of the controller's bounds misfire; the rollback rule chases a rollback le… |
| 180 | 2026-11-01 | design | The window by measured cost (`--ctl=3`), and job M: the controllers against fixed windows on seven workload… |
| 181 | 2026-11-01 | current | Job M results: the measured rule fixes dragonfly (1.00–1.03 of the best fixed W, against the quantile rule'… |
| 182 | 2026-11-01 | design | The measured rule's last change: a trial must beat the base on both sides of it; job N |
| 184 | 2026-11-01 | current | Job L32 results: at 32 nodes the lowest blocked share again marks the best fixed W (W 400 for σ 100 and σ 2… |
| 185 | 2026-11-01 | current | Job N results: the bracketed measured rule is 0.91–1.03 of the best fixed W in every cell (worst 0.91, agai… |
| 237 | 2026-11-06 | current | The measured controller's trials reach two buckets: `--ctl-reach-buckets=2`, and checks that it changes no… |
| 245 | 2026-11-06 | design | Where the controller's 3–7% goes |
| 246 | 2026-11-06 | current | CC results: without its per-round log the controller runs at 0.970–0.985 of the best fixed W. The log itsel… |
| 250 | 2026-11-07 | design (results in 251) | F4 rerun without diagnostics: the robustness comparison on the current tree, with F4's three flags only in… |
| 251 | 2026-11-07 | current | F4b results: without diagnostics the frozen controller is 0.92–1.03 of the best fixed W per cell (median of… |
| 6 | 2026-10-20 | design | Window controller |
| 7 | 2026-10-20 | superseded | Window controller, first Stampede3 results |
| 8 | 2026-10-20 | superseded | Waste floor, controller cost, horizon margin |
| 13 | 2026-10-21 | design | Controller on the GVT's count waves |
| 15 | 2026-10-21 | superseded | Controller on the GVT's count waves, results |
| 17 | 2026-10-21 | design | Controller step 2: cost-aware target and floor guard |
| 18 | 2026-10-21 | superseded | Controller step 2, results |
| 31 | 2026-10-22 | design | Phase-changing PHOLD and traffic characterisation |
| 32 | 2026-10-22 | superseded | Phase-changing PHOLD and traffic, results |
| 33 | 2026-10-22 | design | Devastator's own window on phase-changing PHOLD |
| 34 | 2026-10-22 | superseded | Devastator's own window on phase-changing PHOLD, results |
| 227 | 2026-11-05 | design (results in 230) | F4, robustness of the window policies: Charades' fixed windows, its frozen controller and Devastator's rule… |
| 230 | 2026-11-05 | superseded by §251 (was: current) | F4 results: Charades' frozen controller is 0.83–1.03 of the best fixed W, with phase-changing PHOLD at 4 no… |
| 231 | 2026-11-05 | design (results in 232) | F4's phase-changing PHOLD cell at 16 nodes, rerun |
| 232 | 2026-11-05 | superseded by §251 (was: current) | F4R results: phase-changing PHOLD at 16 nodes reruns clean; the controller is 0.95–0.96 of the best fixed W… |

## Current

Current findings, and designs with their results, in the order they were written.

### §29 · Floor-aware controller, `--ctl-floor` (design, 2026-10-22; written before any runs)

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

### §30 · Floor-aware controller, results (2026-10-22, idev job 3628811, 4 skx nodes)

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

### §37 · Controller level, `--agg-scope`, σ 100 profile (design, 2026-10-23; written before any runs)

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

### §38 · Controller level, `--agg-scope`, σ 100 profile, results (2026-10-23, idev job 3632385, 4 skx nodes)

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

### §39 · Controller: an aggregation bound, cheaper bookkeeping, a faster start (design, 2026-10-23; written before any runs)

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

### §40 · Controller: an aggregation bound, cheaper bookkeeping, a faster start, results (2026-10-23, idev job 3633379, 4 skx nodes)

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

### §167 · Why the controller falls short at 32 nodes: where the best window lies at 16 and 32 nodes, and how far GVT trails the slowest PE (design, 2026-11-01; written before any runs)

> **Status: design; results in section 173.**
> - **Job K:** Charades `main` (this commit adds a statistic), the `--localalloc` launch, htram `pdes` 42d347f, Reconverse as in job N32. `$WORK/charades-runs/wsweep167.slurm`, 32 nodes on skx (`-x c455-081`); its 16-node runs use the allocation's first 16 nodes.
> - **New statistic:** at the end of a bucketed-GVT run, "Slowest PE's lead over GVT, mean over count waves" (time units): the buckets every PE had passed when each wave completed, times the bucket size. It is computed from values every wave already carries, at no cost. `ctl_sweep.sh` writes it as `gvt_lag`.

**What the paper-grade data already shows** (jobs 3653803, 3654651 and 3657016; balancer on, chare rollback):
- The controller's W is 292–314 at every node count on the lookahead-100 workloads. It is set by the κ bound: at 32 nodes κ set W in 97% of updates (job N32), while the rollback rule's calibration sat at its floor (efficiency 100%).
- **At 1–16 nodes W 250 is the best fixed window** on every lookahead-100 workload except σ 2,000 at 16 nodes. The controller there is 0.96–1.03 of the best.
- **At 32 nodes W 400 is the best on all six,** and the controller is 0.89–0.97 of it.
- Widening W from 250 to 400 costs htram little at 16–32 nodes: events per message fall 12% at σ 100 (40.0 to 35.0) and 5% on uniform (14.3 to 13.5). The κ bound guards against this cost, which is large only at 1–2 nodes (σ 100 at 1 node: 48.7 to 19.5).
- **GVT trails the slowest PE by about three waves of GVT advance.** Job E's traces at W 400 show the slowest PE's lead over GVT:
  - at 16 nodes, a median of 200 time units with 68 per wave;
  - at 32 nodes, 232–272 with 80–90 per wave.

  A window measured from GVT leaves the PEs only W minus that lag of room past the slowest PE, and the lag grows with node count as waves slow.
- Job N32: the controller (W 302–329) reached 0.939 (σ 100) and 0.952 (σ 2,000) of W 400. It spent 1.3–1.8× as many scheduler passes blocked at the window edge as W 400.

**Runs** (end time 2,048,000, untraced, the sampler on, 3 reps):
- Workloads: σ 100 (PP 2,048), σ 2,000 (PP 512), uniform (WPs 512).
- Per rep and workload, at 32 nodes and then at 16: W 250, 300, 400, 500 and 600, and the controller. The arm order rotates by rep.
- 108 runs, about 25 minutes.

**Predictions:**
- **K1. The best fixed W moves up with node count.** At 16 nodes it is 250–400 for each workload. At 32 nodes it is 400–600, and the 32-node best is at least 1.03× the 32-node W 300.
- **K2. The lag grows with W until it levels off.** Below the best W the slowest PE's lead rises with W; above it, by less than 30% of the increase in W. At the best W, the room left past the lag (best W − lag) is the same at 16 and 32 nodes within ±30% for each workload. If K2 holds, the window should follow the measured lag, W ≥ lag + room, rather than a constant quantile.
- **K3.** The controller is at least 0.97 of the best fixed W at 16 nodes and at most 0.95 at 32 nodes (as in jobs A2r and N32).
- **K4.** Events per htram message fall by less than 15% from W 250 to W 400 at both node counts, for every workload.

**What follows:**
- **K2 right:** the controller keeps its quantile rule but never sets W below the measured lag plus the room K2 finds (`--ctl-lag-room`). Test it at 16 and 32 nodes against the best fixed W.
- **K2 wrong:** look at what else changes between 16 and 32 nodes at the best W: the wave period, the share of passes blocked at the window edge, and events per message.

### §173 · Job K results: only σ 100 at 32 nodes wants a wider window (W 400–600 beat W 300 in every rep); the κ bound holds every workload at W ≈ 300 and counts same-process sends; the lag is 3 waves of GVT advance at every W and node count (2026-11-01; skx batch job 3668027, 32 nodes)

> **Status: current; its reading of a wider window's cost as memory is wrong (section 176: busy time hardly moves; the cost is blocked time, from slower GVT waves).** Design and predictions in section 167.
> - **Job:** 108 measured runs and the warm-up all finished in 22 minutes; gate 24/24.
> - **Data:** `~/charades-data/scale32/wsweep/j3668027/` (CSVs and per-run logs; the per-PE GVT files stay on `$WORK`). Scripts: `k_summary.py`, `k_logs.py`, `k_gvt_series.py` in `~/charades-data/scale32/wsweep/`.
> - **Noise:** the spread between reps of one arm (max ÷ min of 3) has a median of 1.09 at 16 nodes and 1.14 at 32, up to 1.34. Below, only comparisons that hold in every rep (paired by rep) are claimed.
> - **Between allocations:** σ 100 W 400 at 32 nodes ran at 1,382 M ev/s in job N32 and 1,175 here (1.18×).

**Rates by window** (M committed events/s, median of 3 reps; higher is better):

| workload, nodes | W 250 | W 300 | W 400 | W 500 | W 600 | controller (its mean W) | best fixed W | controller ÷ best fixed W, reps 1 / 2 / 3 (higher is better) |
|---|---|---|---|---|---|---|---|---|
| σ 100, 16 | 555.7 | 634.9 | 634.9 | 587.3 | 573.3 | 646.3 (314) | 300 and 400 tie | 1.02 / 0.99 / 0.91 (to W 300) |
| σ 100, 32 | 1,122.2 | 1,028.6 | 1,174.6 | **1,214.0** | 1,128.8 | 1,003.6 (312) | 500 | 0.78 / 1.06 / 0.76 |
| σ 2,000, 16 | 429.6 | **486.6** | 469.3 | 446.8 | 436.7 | 440.0 (299) | 300 | 0.87 / 1.04 / 1.10 |
| σ 2,000, 32 | 722.0 | **937.0** | 852.8 | 845.4 | 828.4 | 773.1 (299) | 300 | 0.76 / 0.82 / 1.13 |
| uniform, 16 | 256.5 | 274.4 | **338.2** | 251.3 | 280.6 | 274.2 (299) | 400 | 0.80 / 0.81 / 1.21 |
| uniform, 32 | 373.4 | 391.5 | 387.9 | **400.7** | 396.1 | 412.7 (299) | 500 | 0.85 / 1.12 / 1.08 |

**Each arm ÷ W 300, paired by rep** (reps 1 / 2 / 3; higher is better). Only the rows that hold in every rep are shown:

| workload, nodes | W 250 | W 400 | W 500 | W 600 | controller |
|---|---|---|---|---|---|
| σ 100, 16 | 0.87 / 0.87 / 0.91 | 1.00 / 0.94 / 1.09 | 0.95 / 0.90 / 0.96 | 0.88 / 0.88 / 0.94 | 1.02 / 0.99 / 0.91 |
| σ 100, 32 | 1.10 / 0.82 / 1.19 | **1.08 / 1.27 / 1.25** | **1.25 / 1.12 / 1.29** | **1.15 / 1.05 / 1.20** | 0.98 / 1.18 / 0.97 |
| σ 2,000, 32 | **0.74 / 0.77 / 0.94** | 0.82 / 0.91 / 1.11 | 0.91 / 0.89 / 1.10 | 0.89 / 0.88 / 1.07 | 0.76 / 0.82 / 1.13 |

(σ 2,000's rep 3 had a slow W 300 run at both node counts. Uniform's arms do not separate from the spread at either node count.)

**Where the events go** (per executed event; the same in every arm):

| workload | sends to other chares (what κ counts as r) | sent through htram (other processes) | sent by pointer (same process, `--local-fast-path`) |
|---|---|---|---|
| σ 100 | 0.936 | 0.027 | 0.909 |
| σ 2,000 | 0.996 | 0.499 | 0.497 |
| uniform | 0.999 | 0.968 (16 nodes), 0.984 (32) | 0.03, 0.015 |

**htram messages per 1,000 committed events** (lower is better), W 250 / 300 / 400 / 500 / 600:

| workload | 16 nodes | 32 nodes |
|---|---|---|
| σ 100 | 0.68 / 0.71 / 0.82 / 1.07 / 1.33 | 0.69 / 0.73 / 0.78 / 0.92 / 1.19 |
| σ 2,000 | 6.6 / 7.1 / 8.9 / 12.5 / 13.4 | 6.8 / 7.1 / 8.9 / 11.7 / 13.5 |
| uniform | 74.0 / 76.1 / 77.7 / 86.9 / 92.1 | 115.3 / 117.5 / 122.9 / 129.7 / 137.7 |

**GVT lag** (the new statistic: the slowest PE's mean lead over GVT, time units), W 250 / 300 / 400 / 500 / 600:

| workload | 16 nodes | 32 nodes | lag ÷ GVT advance per count wave |
|---|---|---|---|
| σ 100 | 181 / 203 / 232 / 238 / 215 | 182 / 214 / 254 / 263 / 269 | 3.00–3.06 in every arm |
| σ 2,000 | 180 / 205 / 225 / 233 / 224 | 181 / 206 / 255 / 255 / 226 | 3.01–3.06 |
| uniform | 192 / 220 / 222 / 245 / 234 | 196 / 230 / 289 / 276 / 274 | 3.0–4.3 (16), 3.4–4.9 (32) |

At W 300, 16 → 32 nodes: µs per count wave σ 100 151 → 193, σ 2,000 190 → 206, uniform 288 → 374; GVT advance per wave (time units) 67 → 70, 68 → 68, 56 → 47. At W 400 and above σ 100's advance per wave levels off at about 78 (16 nodes) and 88 (32).

**What it says:**
- **Only σ 100 at 32 nodes wants a wider window.** W 400–600 beat W 300 in every rep (1.05–1.29×), and the controller runs at W 300's rate (0.97–1.18 of it).
  - At W 300, σ 100 keeps 0.81 of its 16-node rate per node; σ 2,000 keeps 0.96. W 500 brings σ 100 back to 0.96 of its 16-node best.
  - At σ 2,000, W 250 loses in every rep at 32 nodes (0.74–0.94), against 0.85–0.86 in two of three reps at 16 nodes. Too small a window costs more at 32 nodes there too, but W 300 is already enough.
- **The κ bound holds every workload at W ≈ 300, and it counts sends that never enter htram.** It bounds r·F(W), with r = sends to other chares per executed event: 0.94 at σ 100 and 1.00 at σ 2,000 and uniform. A send to a chare in the same process goes by pointer, so it cannot be flushed early. At σ 100 only 0.027 sends per executed event go through htram, and from W 300 to 500 htram messages rise by 0.2 per 1,000 events at 32 nodes.
- **A wider window's cost is not mainly messages, at σ 2,000 either.** From W 300 to 600 at 16 nodes:
  - PE time per committed event rises by the same share at σ 100 (+10.8%) and σ 2,000 (+11.4%), although σ 2,000 adds 6.4 htram messages per 1,000 events and σ 100 only 0.6.
  - What both add is memory: the most events held on a PE rises from about 3,400 to 4,700 (+38%) in both.
  - The rollback rule cannot see this cost: rollbacks stay at 0.06–0.12% of committed events at W 600, and held stragglers are excluded from its calibration.
  - So κ landing on σ 2,000's best W is a coincidence. Counting only htram sends would leave W unbounded at σ 100: the calibration sits at its floor, so q = 0.99 and W ≈ 4,700. It would also move σ 2,000 to W ≈ 560.
- **The controller has no measure of what a wider window buys.**
  - **What it buys:** less time with PEs blocked at the window edge. That time grows with node count as waves lengthen. At W 300, from 16 to 32 nodes, µs per wave goes 151 → 193 at σ 100 and 190 → 206 at σ 2,000.
  - **What it costs:** memory, a few rollbacks, and on some workloads aggregation.
  - **Hypothesis, not measured:** σ 100 gains most because its PEs spend the least time per unit of virtual time (2.06 µs per GVT time unit at 16 nodes, against 2.70–2.88 for σ 2,000), so they reach the window edge sooner. Blocked time is not recorded.
- **The lag is the bucketed GVT's bookkeeping, and it follows W, not node count.**
  - At Gaussian σ, GVT trails the slowest PE by 3.0 waves of GVT advance in every run. Section 58 found the same: completed = valid ÷ 3 when a wave asks only about the buckets left open.
  - At W ≤ 300 the lag is within 5% between 16 and 32 nodes.
- **Uniform's 16 → 32 loss is aggregation thinning,** as before: 76 → 117 htram messages per 1,000 events at W 300. No window separates from the spread.

**Predictions (section 167):**
- **K1 partly right.**
  - σ 100: the best W moves from 300–400 (16 nodes) to 400–500 (32), at 1.12–1.29× W 300 per rep.
  - σ 2,000: it stays at 300 at both node counts.
  - Uniform: no best W separates from the spread.
- **K2 wrong.** The lag is 3 waves of advance at every W. It levels off only with the advance per wave, and at the best W the room past it is not the same at 16 and 32 nodes for σ 100: 97–168 against 146–237. `--ctl-lag-room` is not built.
- **K3 right at 32 nodes for σ 100 and σ 2,000** (0.78 and 0.82 of the best, median by rep; 1.08 on uniform). At 16 nodes it is right for σ 100 (0.99) and σ 2,000 (1.04), but uniform reached only 0.81 (0.80, 0.81, 1.21 by rep).
- **K4 wrong for σ 2,000 and for σ 100 at 16 nodes.** Events per htram message from W 250 to 400:
  - σ 100: −17% at 16 nodes, −12% at 32;
  - σ 2,000: −25% and −24%;
  - uniform: −5% and −7%.

**What follows** (design in the next section, written before its runs):
- Measure what the window buys: PE time blocked at the window edge, for each W, at 16 and 32 nodes.
- Then replace κ with a rule built on that measurement. Whatever replaces κ must still bound the window, by memory or rollbacks.
- Separately, the aggregation bound should count only events sent through htram.

### §174 · What a wider window buys: PE time blocked at the window's edge, by W, at 4, 16 and 32 nodes (design, 2026-11-01; written before any runs)

> **Status: design.**
> - **Code:** Charades `main` 1b472ef adds `--blocked-time=1`. Each PE times its spells at the window's edge: a spell starts when a pass stops at the window and ends when the PE next executes an event. That is one timer read at each end of a spell and none on the blocked passes in between; off by default.
> - **Printed:** "Time Blocked at Window %" (mean over PEs, and the least and most PE), "Blocked Spells" and "Blocked Spell Mean us".
> - **Also fixed:** the end-of-run statistics reduction started from a zeroed `Statistics` and leaked it; it now starts from the first contribution, so the least-PE value is a minimum over PEs. No other statistic changes: the others are sums, maxima, or the same on every PE.
> - **Mac:** change tier, 144/144: `bucket_window_blocked` and `agg_deadline_bucket_pp_blocked` (new configs) plus `blocking`, `bucket`, `bucket_window` and `agg_ctl_sparse_bucket_pp` on every model; committed counts unchanged.
> - **`ctl_sweep.sh`** writes blocked_pct, blocked_min_pct, blocked_max_pct, spell_us, max_events, htram_events and htram_msgs.

**Why.** Section 173: only σ 100 at 32 nodes wants a window wider than about 300, and the controller has no measure of what a wider window buys. The cost of width is visible: busy PE time per event rises with W through memory, as it did at σ 100 and σ 2,000 alike at 16 nodes. The benefit, less time with PEs stopped at the window's edge, was never measured. So split each run's PE time into blocked and busy:
- blocked = the blocked share × PEs × run time;
- busy per committed event = (1 − blocked share) × PEs ÷ the rate.

**Runs** (the job K setup: `--localalloc` launch, end time 2,048,000, 3 reps, the arm order rotating by rep; `--blocked-time=1` on every arm):
- σ 100 (PP 2,048), σ 2,000 (PP 512) and uniform (WPs 512).
- W 250, 300, 400, 500, 600 and the controller.
- **Job L16** (skx-dev, or skx if it starts first, 16 nodes): 16 nodes, then the first 4.
- **Job L32** (skx, 32 nodes): 32 nodes, then the first 16.
- 108 runs per job, about 25 minutes each. 16 nodes appears in both jobs, so the two allocations can be compared.

**Predictions:**
- **L1. Blocked time is what σ 100 loses at 32 nodes.**
  - At W 300, σ 100's blocked share is at least 12 points higher at 32 nodes than at 16. PE time per event went from 1.16 to 1.43 µs (section 173).
  - σ 2,000's is at most 6 points higher (1.51 to 1.57 µs).
  - At W 500, σ 100's blocked share at 32 nodes is within 6 points of its 16-node W 300 share.
- **L2. Busy time per committed event rises with W** at every workload and node count: W 600 is at least 1.06× W 300. This is the cost of width that the rollback rule does not see.
- **L3. At the best fixed W, the blocked share lies in a narrow band:** within 10 points across the three workloads and three node counts. If so, a blocked-share target can set W.
- **L4.** At 4 nodes the blocked share at W 300 is below the 16-node share for every workload.

**What follows:**
- **L3 right:** the controller sets W to hold the blocked share at the band's level, with the memory and rollback costs as upper bounds. κ either goes, or counts only events sent through htram.
- **L3 wrong:** the controller perturbs W and compares busy plus blocked PE time per committed event, which it can sum on its count waves at no extra cost. That is a gradient rule on a measured cost, not a target.

### §176 · Job L16 results: above W 300 a wider window costs blocked time, not busy time; GVT advance per wave levels off at W 300 while waves keep lengthening; the blocked share is lowest at the best W (2026-11-01; skx-dev batch job 3668911, 16 nodes)

> **Status: current for 4 and 16 nodes; 32 nodes in section 184.** Design and predictions in section 174.
> - **Job:** 108 runs, all finished; gate 24/24.
> - **Data:** `~/charades-data/scale32/blocked/j3668911/`; script `~/charades-data/scale32/blocked/l_summary.py`.
> - **Noise:** low. Per-rep ratios to W 300 agree within about ±3% (the 32-node spread in section 173 was ±14%).

**Rate, blocked share and PE time per committed event** (median of 3 reps):
- M ev/s: higher is better.
- Blocked %: the mean over PEs of the share of run time stopped at the window's edge; lower is better.
- Busy and blocked µs: PE time per committed event, (1 − blocked share) × PEs ÷ rate and blocked share × PEs ÷ rate; lower is better.

| workload, nodes | W | M ev/s | blocked % (least / most PE) | blocked spell (µs) | busy µs per event | blocked µs per event | ÷ W 300, reps 1 / 2 / 3 |
|---|---|---|---|---|---|---|---|
| σ 100, 4 | 250 | 181.0 | 18.9 (14.4 / 22.9) | 28.4 | 0.832 | 0.191 | 1.00 / 0.98 / 0.99 |
| | **300** | **181.9** | **17.7** (12.2 / 24.3) | 29.3 | 0.834 | 0.179 | 1 |
| | 400 | 172.7 | 20.6 (9.9 / 25.2) | 34.5 | 0.846 | 0.219 | 0.96 / 0.95 / 0.94 |
| | 600 | 151.1 | 29.8 (17.1 / 33.6) | 51.3 | 0.861 | 0.363 | 0.83 / 0.82 / 0.83 |
| | controller (314) | 178.7 | 18.4 | 30.6 | 0.840 | 0.190 | 1.00 / 0.98 / 0.98 |
| σ 100, 16 | 250 | 687.7 | 23.8 (18.1 / 29.2) | 31.5 | 0.813 | 0.255 | 0.97 / 0.99 / 0.95 |
| | **300** | **716.7** | **20.1** (12.5 / 24.9) | 30.8 | 0.823 | 0.207 | 1 |
| | 400 | 692.7 | 21.9 (10.8 / 28.4) | 35.3 | 0.830 | 0.232 | 0.97 / 0.99 / 0.96 |
| | 600 | 600.7 | 30.8 (22.2 / 34.3) | 52.1 | 0.848 | 0.377 | 0.84 / 0.86 / 0.84 |
| | controller (314) | 704.5 | 20.7 | 33.0 | 0.828 | 0.217 | 1.00 / 1.01 / 0.96 |
| σ 2,000, 4 | 250 | 137.9 | 26.7 | 48.8 | 0.979 | 0.356 | 0.98 / 0.98 / 0.99 |
| | **300** | **141.1** | **23.1** | 49.5 | 1.004 | 0.301 | 1 |
| | 600 | 116.2 | 34.9 | 70.5 | 1.031 | 0.553 | 0.82 / 0.82 / 0.83 |
| | controller (299) | 137.6 | 24.4 | 51.7 | 1.011 | 0.326 | 0.96 / 0.99 / 0.99 |
| σ 2,000, 16 | 250 | 530.3 | 32.8 | 55.7 | 0.935 | 0.454 | 0.99 / 1.00 / 0.96 |
| | 300 | 536.2 | 29.8 | 60.7 | 0.968 | 0.410 | 1 |
| | 400 | 534.2 | **27.1** | 60.8 | 1.005 | 0.373 | 0.99 / 1.02 / 0.97 |
| | 600 | 471.6 | 33.6 | 77.8 | 1.035 | 0.523 | 0.88 / 0.90 / 0.86 |
| | controller (299) | **540.2** | 28.6 | 57.0 | 0.972 | 0.390 | 1.02 / 1.03 / 0.98 |
| uniform, 4 | 250 | 119.4 | 27.8 | 60.0 | 1.109 | 0.428 | 0.97 / 0.99 / 0.98 |
| | **300** | **122.3** | **24.2** | 62.8 | 1.138 | 0.364 | 1 |
| | 600 | 97.0 | 39.7 | 91.3 | 1.138 | 0.753 | 0.79 / 0.80 / 0.79 |
| | controller (299) | 120.6 | 25.0 | 64.2 | 1.143 | 0.382 | 0.98 / 0.97 / 1.00 |
| uniform, 16 | 250 | 353.1 | 36.6 | 92.8 | 1.319 | 0.763 | 0.97 / 0.96 / 0.96 |
| | **300** | **367.4** | **32.0** | 94.5 | 1.363 | 0.640 | 1 |
| | 600 | 313.0 | 42.0 | 126.7 | 1.372 | 0.989 | 0.85 / 0.85 / 0.84 |
| | controller (299) | 357.0 | 33.1 | 99.0 | 1.377 | 0.685 | 0.96 / 0.97 / 0.98 |

(W 400 and 500 for the rows not shown fall between their neighbours; all arms are in `l_summary.py`'s output.)

**GVT per count wave**, W 250 / 300 / 400 / 500 / 600:

| workload, nodes | µs per wave (lower is better) | GVT advance per wave, time units (higher is better) |
|---|---|---|
| σ 100, 4 | 117 / 128 / 138 / 153 / 162 | 59.9 / 65.9 / 67.5 / 67.9 / 69.2 |
| σ 100, 16 | 123 / 132 / 139 / 152 / 161 | 59.8 / 66.8 / 68.4 / 68.6 / 68.5 |
| σ 2,000, 4 | 154 / 167 / 177 / 192 / 205 | 60.1 / 66.5 / 67.4 / 68.4 / 67.4 |
| σ 2,000, 16 | 159 / 177 / 185 / 200 / 210 | 59.8 / 67.1 / 70.2 / 69.6 / 70.2 |
| uniform, 4 | 178 / 193 / 211 / 224 / 244 | 60.0 / 67.0 / 66.9 / 66.8 / 66.9 |
| uniform, 16 | 240 / 264 / 276 / 285 / 304 | 60.0 / 68.7 / 69.1 / 67.4 / 67.2 |

**What it says:**
- **Above W 300, a wider window costs blocked time, not busy time.** From W 300 to 600, the extra PE time per committed event is 63–100% blocked time:
  - σ 100: +0.025 µs busy against +0.170 blocked at 16 nodes;
  - σ 2,000: +0.067 against +0.113;
  - uniform: +0.009 against +0.349.
  
  Busy time per event at W 600 is 1.00–1.03× W 300 in five cells and 1.07× in one. **This corrects section 173,** which read the cost of width as memory: the most events held on a PE does rise 38%, but busy time hardly moves.
- **Why blocked time grows: GVT advance per wave levels off at W 300 while waves keep lengthening.**
  - From W 300 to 600, advance per wave rises at most 5% (to 67–70 time units, about a third of the buckets every PE has passed, as in section 58).
  - Over the same range, µs per wave rise 15–27%.
  - So GVT moves more slowly through virtual time, and every PE waits longer at the edge: blocked spells grow from 31 to 52 µs at σ 100, 16 nodes.
  - **Hypothesis, not tested:** waves are paced by 128 events per PE (`--gvt-wave-events`). In a narrow window PEs reach the edge and contribute early; in a wide one each PE works through its 128 events first.
- **The blocked share is lowest at the best fixed W in every cell.** At W 300 in five cells; at W 400 at σ 2,000, 16 nodes, where W 300, W 400 and the controller tie (0.98–1.03 per rep). Busy time is nearly flat in W, so the rate follows the blocked time.
- **At 4 and 16 nodes the controller is where it should be:** 0.96–1.03 of W 300 per rep, at a mean W of 299–314. The question that remains is 32 nodes (section 173: σ 100 wanted W 400–500 there), which job L32 measures.

**Predictions (section 174):**
- **L1:** pending (L32).
- **L2 wrong.** Busy time at W 600 is 1.00–1.07× W 300, not ≥ 1.06× (only σ 2,000 at 16 nodes reaches it).
- **L3 wrong.** The blocked share at the best W spans 17.7–32.0%, 14 points, so no single target fits. But its minimum marks the best W everywhere.
- **L4 right.** At W 300 the 4-node share is below the 16-node share for every workload: 17.7 vs 20.1, 23.1 vs 29.8, 24.2 vs 32.0.

**What follows:** per section 174, "L3 wrong" points to a rule that moves W toward the lowest measured blocked time, by perturbing W, rather than to a target. Whether to build it waits for L32:
- if at 32 nodes the lowest blocked share again marks the best W, and the controller misses it, one test of that rule;
- otherwise the controller stays as it is.

### §178 · The controller on dragonfly: start-up or its rollback target? Long runs at 1 and 4 nodes (job D design, 2026-11-01; written before any runs)

> **Status: design.** PAPER.md work item 1.
> - **Job D:** `$WORK/charades-runs/dfctl178.slurm`, skx-dev, 4 nodes. Charades `charades-phaseb` (main f1c2f80); no code change.

**Why.** Section 177: the controller reached 0.29–0.41 of W 10,000 ps on dragonfly in 1–4 s runs. Two explanations fit:
- **Start-up:** W was still rising at the end (final 6,474–7,009 ps, mean 1,571–1,900). The calibration starts at α = 1 and moves at most 1.25× per update; the final α was 0.004–0.005.
- **The target:** ε = 0.001 aims at 0.1% of events rolled back. Dragonfly's best fixed W ran at 2–4% rolled back (efficiency 96–98%), against at most about 0.1% for PHOLD's best W. An event-share target fitted on PHOLD may hold dragonfly's window low however long the run.

**Runs.**
- Dragonfly, uniform traffic, arrival 500 ns, generating 300,000 ns (about 10 s at the 1-node best rate), end 310,000,000 ps.
- 4 nodes (a = 16, h = 10) then 1 node (a = 13, h = 4); p = 4; WPs 512; GVT buckets of 1,000 ps; 3 reps.
- **Fixed W:** 2,500, 5,000, 10,000 and 20,000 ps.
- **Controller:**
  - ε 0.001 (default), 0.01 and 0.03, all with `--ctl-log` (W every round);
  - ε 0.001 started from α = 0.005 (`--ctl-alpha-init`), section 177's final value.
- **Rep 1 only:** PP 512 and direct sends at W 10,000.
- `--blocked-time=1` on every arm.

**Predictions:**
- **D1. The target, not start-up.**
  - At ε 0.001 the controller's W in the last 20% of rounds stays at or below 7,500 ps at both node counts.
  - Starting from α = 0.005 does not lift its rate above 0.6 of the best fixed W.
- **D2.** ε 0.01 or 0.03 reaches at least 0.9 of the best fixed W at both node counts.
- **D3.** The best fixed W is 5,000–10,000 ps at 1 node and 5,000–20,000 at 4.
- **D4.** As at PHOLD (section 176), the blocked share is lowest at the best fixed W.
- **D5.** WPs 512 is at least 1.0× direct sends at 4 nodes; PP 512 is within 5% of WPs 512.

**What follows:**
- **D1 and D2 right:** an event-share target does not carry across models. A looser ε would cost PHOLD, whose best W runs near 0.1% rolled back. So the fix is a rule that does not depend on the model's rollback level: W toward the lowest blocked time, as section 176 suggests, or ε set from each model's own rollback cost. That is one code change and one job, joined with job L32's question.
- **D1 wrong (start-up):** start the calibration from the delay histogram (the first round's quantile) instead of α = 1, check that this does not hurt traffic (section 40 saw that), and keep ε.

### §179 · Job D results: on dragonfly both of the controller's bounds misfire; the rollback rule chases a rollback level no window removes, and κ caps W at the median delay; start-up is not the problem (2026-11-01; skx-dev batch job 3669044, 4 nodes)

> **Status: current.** Design and predictions in section 178.
> - **Job:** 52 runs, all finished in 22 minutes; gate 18/18.
> - **Data:** `~/charades-data/phaseb/j3669044/`; script `~/charades-data/phaseb/d_summary.py`.
> - **Noise:** per-rep ratios agree within ±3%.

**Dragonfly, long runs** (1 node: 389 M events, 4 nodes: 1,488 M; median of 3 reps; ratios to the best fixed W are per rep; higher is better):

| nodes | arm | M ev/s | efficiency (%) | blocked share (%) | controller's mean W (ps) | ÷ best fixed W |
|---|---|---|---|---|---|---|
| 1 | W 2,500 | 19.5 | 98.4 | 71.5 | | 0.51 / 0.52 / 0.53 |
| | W 5,000 | 32.6 | 98.5 | 47.3 | | 0.85 / 0.88 / 0.88 |
| | **W 10,000** | **37.4** | 98.0 | 33.7 | | 1 |
| | W 20,000 | 36.4 | 87.8 | 25.3 | | 0.96 / 0.97 / 0.95 |
| | controller ε 0.001 | 14.9 | 98.3 | 76.4 | 1,854 | 0.39 / 0.40 / 0.40 |
| | controller ε 0.001, started at α 0.005 | 14.8 | 98.3 | 76.6 | 1,856 | 0.39 / 0.40 / 0.40 |
| | controller ε 0.01 | 32.0 | 98.5 | 47.6 | 5,958 | 0.83 / 0.86 / 0.87 |
| | controller ε 0.03 | 32.1 | 98.5 | 47.3 | 5,963 | 0.84 / 0.85 / 0.87 |
| | PP 512, W 10,000 (rep 1) | 34.3 | 97.7 | 33.2 | | 0.90 |
| | direct sends, W 10,000 (rep 1) | 35.4 | 98.8 | 34.4 | | 0.93 |
| 4 | W 2,500 | 47.5 | 97.3 | 79.6 | | 0.43 / 0.43 / 0.43 |
| | W 5,000 | 88.9 | 97.6 | 59.8 | | 0.81 / 0.81 / 0.80 |
| | W 10,000 | 109.4 | 97.2 | 41.5 | | 0.99 / 0.99 / 0.99 |
| | **W 20,000** | **110.4** | 92.7 | 35.4 | | 1 |
| | controller ε 0.001 | 36.2 | 97.2 | 82.9 | 1,700 | 0.33 / 0.33 / 0.33 |
| | controller ε 0.001, started at α 0.005 | 36.2 | 97.2 | 83.1 | 1,696 | 0.33 / 0.33 / 0.32 |
| | controller ε 0.01 | 86.7 | 97.6 | 59.3 | 5,846 | 0.79 / 0.78 / 0.79 |
| | controller ε 0.03 | 86.4 | 97.6 | 59.6 | 5,850 | 0.80 / 0.78 / 0.78 |
| | PP 512, W 10,000 (rep 1) | 97.4 | 97.0 | 38.6 | | 0.89 |
| | direct sends, W 10,000 (rep 1) | 99.0 | 98.6 | 43.5 | | 0.90 |

**What it says:**
- **Start-up is not the problem.**
  - Over the last 20% of rounds, the controller at ε 0.001 holds W at a median of 1,015–1,017 ps in every run.
  - Starting from α 0.005 gives the same W and rate.
  - Section 177's "final window" of about 7,000 was the drain after generation ends, when nothing rolls back.
- **The rollback rule chases a rollback level the window cannot remove.**
  - About 3% of events roll back at every W tested, including at ε 0.001's W of about 1,000 (42.5 M of 1,488 M at 4 nodes). Efficiency is 97–98.5% from W 2,500 to 10,000.
  - 86–91% of stragglers were held by htram and are left out of the calibration. The rest still roll back more than 0.1% of events, so the rule keeps narrowing W toward its floor.
  - PHOLD's best W runs at about 0.1% rolled back; dragonfly's at 2–3%. An event-share target fitted on one does not suit the other.
- **κ caps W at the median delay.**
  - With ε 0.01 or 0.03, κ set W in 99.8–99.9% of updates, and both land on the same W, about 5,850–5,960 ps.
  - It counts r = 0.39 sends to other chares per executed event, while only 0.125 go through htram (section 173's defect). κ ÷ r = 0.51 puts W at the median delay, where a chunk's 6.1 ns serialization delay sits.
  - Result: 0.78–0.87 of the best W.
- **The best fixed W:** 10,000 ps at 1 node, and 10,000 to 20,000 (level) at 4.
  - At W 20,000, efficiency falls to 88–93%, and the blocked share keeps falling (25–35%). So the lowest blocked share alone would pick W 20,000, 0.96 of the best at 1 node.
  - The rate follows busy plus blocked PE time, not blocked time alone, once rollbacks grow.
- **Aggregation gains little on dragonfly at these sizes.** WPs 512 ÷ direct is 1.06 (1 node) and 1.10 (4 nodes); PP 512 is 0.89–0.92 of WPs.

**Predictions (section 178):**
- **D1 right:** the target, not start-up.
- **D2 wrong:** looser targets reach only 0.78–0.87, because κ then caps W.
- **D3 right:** the best W is 10,000 at 1 node and 10,000–20,000 at 4.
- **D4 right at 4 nodes, wrong at 1:** the blocked share is lowest at W 20,000 at both node counts, which is the best W only at 4.
- **D5 half right:** WPs 512 is 1.10× direct at 4 nodes, but PP 512 is 0.89×, not within 5%.

**What follows:** both of the controller's bounds encode PHOLD facts:
- the rollback level its best window runs at;
- that every send to another chare can be aggregated.

On the first application, both are wrong. A rule that suits every model has to use measured cost instead. Section 176 found that busy plus blocked PE time per committed event has its minimum at the best W, and summing both on the count waves costs nothing. The design choice is the user's (next section).

### §180 · The window by measured cost (`--ctl=3`), and job M: the controllers against fixed windows on seven workloads at 4 and 16 nodes (design, 2026-11-01; written before any runs)

> **Status: design.** PAPER.md work item 1 (and the start of F4).
> - **User decision, 2026-11-01:** of four options (hybrid, measured cost only, patching the two bounds, freezing), the hybrid.
> - **Code:** Charades main 0e158d5; Mac change tier 120/120 with three new configs (`agg_ctl_measured_bucket_pp`, `ctl_measured_bucket`, `agg_ctl_measured_fast_bucket_pp`) on every model.
> - **Job M:** `$WORK/charades-runs/mctl180.slurm`; Stampede3 tree `charades-phaseb` at 0e158d5.

**The rule (`--ctl=3`).** Section 179: both of the quantile rule's bounds encode PHOLD facts. Its rollback target sits below dragonfly's rollback level at any W, and κ counts sends that never enter htram. The new rule keeps the delay histogram for the scale and lets measured cost choose the point:
- **Start and range:** after the first histogram, W starts at the median delay and stays between the 0.01 and 0.99 quantiles.
- **The cost:** PE time per committed event, the summed elapsed time of every PE over the events committed. Section 176 found it lowest at the best W; it counts rollbacks, smaller htram messages and blocked time alike.
- **Periods:** they alternate between a base (the W in force) and a trial (W times or over a step). Each period leaves out its first 2 rounds (`--ctl-settle`) and measures the next 8 (`--ctl-period`); a round is 8 count waves.
- **A cheaper trial** is kept, becomes the next base, and the step grows from 1.5× up to 2×.
- **A dearer one** sends W back to the base, which is measured again, and flips the direction. Two rejected trials in a row halve the step (in log), down to 1.05×.
- **Only adjacent periods are compared,** so the rule follows phase changes, and every PE computes the same W.

**Runs** (16 nodes, then the allocation's first 4; 2 reps, arm order reversed in rep 2):

| workload | htram | end time | arms |
|---|---|---|---|
| PHOLD σ 100, lookahead 100 / mean 1,000 | PP 2,048 | 2,048,000 | W 300, quantile rule, measured |
| PHOLD σ 2,000 | PP 512 | 2,048,000 | W 100, W 300, quantile, measured |
| PHOLD uniform | WPs 512 | 2,048,000 | W 300, quantile, measured |
| PHOLD σ 500, lookahead 10 / mean 200 | PP 512 | 512,000 | W 50, 100, 200, 300, quantile, measured |
| phase-changing PHOLD (10 / 200 and 100 / 1,000 every 8,000; remote 0.5) | PP 512 | 1,024,000 | W 100, 250, 500, quantile, measured |
| traffic (64 × 46·N, 16 cars per intersection, trip radius 3) | PP 2,048 | 6,000,000 | W 250, 1,000, quantile, measured |
| dragonfly (a = 28, h = 14 at 16 nodes; 16 / 10 at 4; arrival 500 ns, generating 150,000 ns) | WPs 512 | 160,000,000 ps | W 10,000, 20,000, quantile, measured |

**Predictions:**
- **M1 (the gate).** The measured rule reaches at least 0.9 of the best fixed W in this job for every workload at both node counts, dragonfly included.
- **M2.** On the three lookahead-100 PHOLD workloads it is within 0.05 of the quantile rule, which is already 0.96–1.03 of W 300 there (section 176).
- **M3. No single W fits every workload:**
  - W 300 is at most 0.8 of the best at lookahead 10;
  - W 100 is at most 0.8 of W 300 at σ 2,000, lookahead 100.
- **M4.** On phase-changing PHOLD the measured rule is at least 0.95 of the best fixed W.

**What follows:**
- **M1 right:** `--ctl=3` becomes the default, and the robustness figure (F4) is built on it. L32's 32-node question is then asked of it in the paper-grade runs.
- **M1 wrong:** read the `CTL` logs to see where W went. One more change at most, then freeze, per PAPER.md.

### §181 · Job M results: the measured rule fixes dragonfly (1.00–1.03 of the best fixed W, against the quantile rule's 0.31–0.34) and is 0.94–1.07 elsewhere, but 0.88–0.94 on phase-changing PHOLD, where its W wanders instead of following the phases; one traffic run committed a different count (2026-11-01; skx-dev batch job 3669193, 16 nodes)

> **Status: current.** Design and predictions in section 180.
> - **Job:** 116 runs, all finished in 24 minutes (skx copy 3669194 cancelled); gate 45/45.
> - **Data:** `~/charades-data/phaseb/mctl180/j3669193/`; script `~/charades-data/phaseb/mctl180/m_summary.py`.
> - **No `--ctl-log`** in this job, so the trajectory of W below comes from a Mac run.
> - **Committed counts:** equal in every workload and node count, except one run (traffic, 4 nodes; see the end of this section).

**Each policy ÷ the best fixed W of the same rep** (2 reps, shown as rep 1 / rep 2; higher is better; the measured rule's time-weighted mean W in parentheses; fixed W in the model's time unit, dragonfly in ps):

| workload | nodes | best fixed W (M ev/s) | measured rule (mean W) | quantile rule | the other fixed W |
|---|---|---|---|---|---|
| PHOLD σ 100 | 16 | W 300 (717.6) | 0.97 / 0.95 (354) | 0.95 / 0.98 | |
| | 4 | W 300 (182.3) | 0.95 / 0.97 (310) | 0.98 / 0.97 | |
| PHOLD σ 2,000 | 16 | W 300 (553.1) | 0.98 / 0.98 (352) | 0.97 / 0.99 | W 100: 0.59 / 0.61 |
| | 4 | W 300 (141.9) | 0.94 / 0.97 (314) | 0.97 / 0.99 | W 100: 0.68 / 0.66 |
| PHOLD uniform | 16 | W 300 (368.6) | 0.98 / 0.97 (352) | 0.98 / 0.99 | |
| | 4 | W 300 (120.6) | 0.99 / 0.99 (308) | 1.02 / 1.01 | |
| lookahead 10, σ 500 | 16 | W 50 (565.4) | 1.00 / 1.00 (64) | 1.02 / 1.01 | W 100: 0.92; W 200: 0.64; W 300: 0.55 / 0.54 |
| | 4 | W 50 (146.2) | 0.98 / 0.97 (58) | 0.99 / 0.99 | W 100: 0.90 / 0.88; W 200: 0.64; W 300: 0.54 |
| phase-changing PHOLD | 16 | W 100 (349.1) | **0.90 / 0.94** (157) | 0.98 / 0.96 | W 250: 0.89 / 0.91; W 500: 0.50 |
| | 4 | W 100 (123.0) | **0.88 / 0.89** (144) | 0.91 / 0.87 | W 250: 0.82; W 500: 0.29 / 0.28 |
| traffic | 16 | W 1,000 (904.1) | 1.02 / 1.07 (609) | 0.90 / 0.96 | W 250: 0.70 / 0.73 |
| | 4 | W 1,000 (224.9) | 1.05 / 1.06 (568) | 1.02 / 1.05 | W 250: 0.88 / 0.87 |
| dragonfly | 16 | W 20,000 (375.7) | 1.00 / 1.01 (15,587) | **0.32 / 0.31** | W 10,000: 0.99 / 0.94 |
| | 4 | W 20,000 (108.7) | 1.02 / 1.03 (14,593) | **0.34 / 0.34** | W 10,000: 0.98 |

**Worst case over the 14 cells** (lowest rep):
- measured rule: 0.88 (phase-changing PHOLD, 4 nodes);
- quantile rule: 0.31 (dragonfly); 0.87 without dragonfly;
- any single PHOLD window: W 300 is 0.54 at lookahead 10, and W 100 is 0.59 at σ 2,000 (and dragonfly needs a W 50–200× larger in its own unit).

**What it says:**
- **Dragonfly is fixed.** The measured rule settles at a mean W of 14,600–15,600 ps, between the two best fixed windows, and reaches 1.00–1.03 of the best. The quantile rule repeats section 179 (0.31–0.34).
- **On steady PHOLD it costs 1–6%.** The measured rule is 0.94–1.00 on the four steady PHOLD workloads, within 0.03 of the quantile rule. Half its periods run at a trial W, so a few percent is the price of measuring.
- **On traffic it beats both grid points** (1.02–1.07), at a W of about 510–610 that the grid (250 and 1,000) did not include. Traffic's ratio cannot be quoted until the grid has W 500 and 750.
- **On phase-changing PHOLD it misses.** It reaches 0.88–0.94, and W 100 beats it at both node counts. It kept 44% of its trials there against 30–34% elsewhere, and its step ended at its largest, 1.68–2.0×, against 1.05–1.32× on the steady workloads. The cost per committed event changes with the phase. A trial measured in a cheaper phase than its base looks better whatever its W is, so it is kept, and each keep enlarges the step.
- **Lowest blocked share is not lowest cost here.** On phase-changing PHOLD, W 500 has the lowest blocked share (2.0–4.3%) and is the worst arm (0.28–0.50; efficiency 68–78%). A rule on blocked time alone (PAPER.md item 2) would have to count rollbacks as well. The measured rule's cost already does.

**Mac trace (where W went).** Phase-changing PHOLD on one process of 8 PEs (1,024 LPs, end 512,000, PP 512, `--ctl-log=1`; one run each; Mac timings vary ±5%):
- **The measured rule reaches 0.91 of W 100 here as well** (9.57 against 10.50 M ev/s).
- **W does not follow the phases; it wanders.** Its median per phase:
  - lookahead-10 phases: 82–219;
  - lookahead-100 phases: 98–976.
  - The phase kind does not predict whether W is high or low. W reached 488 and 976 in phases 22–23.
- **Following the phases would gain little on the Mac.** Per-phase rates from fixed-W runs with the controller in dry mode (W 50–300):
  - the best W is 100 in lookahead-10 phases and 200 in lookahead-100 phases;
  - the best W in each phase would beat W 100 by only 1.024×.
- **So on the Mac the loss is the wandering:** trials at bad W, and excursions kept by comparisons across a phase change. It is not that W fails to follow the phases. On Stampede3 the per-phase optima may be further apart (lookahead 10, σ 500 is best at W 50; lookahead 100 at W 300), which this job cannot separate.

**Predictions (section 180):**
- **M1 wrong, narrowly:** 13 of 14 cells reach 0.9 in both reps. Phase-changing PHOLD at 4 nodes reaches 0.88 / 0.89.
- **M2 right:** within 0.03 of the quantile rule on the three lookahead-100 PHOLD workloads.
- **M3 right:** W 300 is 0.54–0.55 of the best at lookahead 10, and W 100 is 0.59–0.68 of W 300 at σ 2,000.
- **M4 wrong:** 0.88–0.94 on phase-changing PHOLD, not 0.95.

**A committed count that differs (traffic, 4 nodes).** The quantile-rule run of rep 1 committed 1,131,024,789 events; the other seven traffic runs at 4 nodes committed 1,131,043,125 (18,336 more, 0.0016%). All 8 traffic runs at 16 nodes agree, as do all runs of the other six workloads. The run ended normally with no warning.
- **This is not new.** The full-node traffic runs of 2026-10-22/23 (jobs 3629783 and 3629781, `~/charades-data/full/`) committed more than one count in 5 of 8 traffic groups (workload × direct or htram), with direct sends as well as htram. Congested traffic diverged most: 6–8 of 24 runs differed from the majority count. Uniform traffic over 5,888 × 4 agreed in all 48 runs. One of 51 traffic runs of job 3633379 (`~/charades-data/ctl2/`) differed too.
  - Those sections reported rates only and did not compare traffic's counts.
  - The comparator fix of 2026-10-20 (CONTEXT.md, open issue 8) made the pending heap's order total. Something else still lets traffic's events run in an order that changes the result, rarely, on several processes.
- **What it does not affect:** PHOLD and dragonfly. Every PHOLD and dragonfly run in this job and in every earlier group compared commits one count per configuration.
- **What it does affect:** table T1 (equal committed events in all three engines) for traffic, and the claim that aggregation commits the same events as direct sends.
- **Next:** reproduce on the Mac (traffic, 8 PEs, repeated runs; started), then on several processes. Until it is fixed, traffic's counts are reported per run.

**What follows:**
- Per section 180, M1 wrong means one more change to the measured rule, then freeze. The change has to stop the wandering on phase-changing PHOLD without costing the steady workloads, dragonfly or traffic. The design comes next.
- The traffic count is a correctness bug, ahead of the controller in priority. It must be fixed before the engine freeze (2026-12-07).

### §182 · The measured rule's last change: a trial must beat the base on both sides of it; job N (design, 2026-11-01; written before any runs)

> **Status: current (design); results and the freeze in section 185.** PAPER.md work item 1, the one change section 180 allowed after M1 failed. Whatever job N shows, the controller freezes after it.
> - **Job N:** `$WORK/charades-runs/nctl182.slurm` (copy in `~/charades-data/phaseb/`), submitted 2026-11-01 as 3669802 (skx-dev) and 3669803 (skx); Stampede3 tree `charades-phaseb` at e1fbdc4 (heap fix included).

**The change (`--ctl-bracket=1`, the new default; `0` is section 180's rule).** Section 181: on phase-changing PHOLD the rule kept trials that were measured in a cheaper phase than their base, whatever their W, and each keep enlarged the step. Now a trial is judged against two bases:
- **Order:** base, trial, base again, each a full period (2 settle rounds, 8 measured).
- **Kept** only if the trial costs less than both bases. W moves to the trial and the step grows as before. The next comparison starts with a fresh base at the new W.
- **Dropped** otherwise. The direction flips, two drops in a row halve the step as before, and the closing base opens the next comparison.
- **Effect:** a change in cost during the three periods has to look better than both neighbours to be kept, which a phase change alone rarely does. A dropped trial still takes 2 periods, but a kept one takes 3 instead of 1, so W moves more slowly.
- **Not changed:** the start at the median delay, the 0.01–0.99 quantile range, the cost, and the step sizes.

**Considered and not chosen.** Making W a multiple of the median delay, so that W follows a change in scale at once. On the Mac the best W in each phase is not a fixed multiple of the median delay (100 at a median of about 150, 200 at about 790; computed as the lookahead plus the exponential's median), and the best W per phase would gain only 1.024× there (section 181). The wandering is what lost, so the change targets the comparison.

**Mac check, before Stampede3:**
- the change tier on every model;
- the section 181 trace again (phase-changing PHOLD, 8 PEs, `--ctl-log`), bracketed against unbracketed.
- Expected: the kept share falls from about 44% toward the steady workloads' 30–34%, and W stays within 50–300 in every phase.
- **Result (2026-11-01, 2 runs each, main b67e32d):**
  - change tier 176/176;
  - bracketed: 20–32% of trials kept, final step 1.05–1.12, W within 42–381 and 77–221 over the run (per-phase medians 77–307 and 93–147);
  - unbracketed: 33–38% kept, final step 1.16–2.0, W within 25–476 and 36–989 (per-phase medians up to 740);
  - rates (M ev/s): bracketed 8.63 and 9.20, unbracketed 9.65 and 8.60, W 100 9.35 and 9.56. These are within the Mac's ±5%, so job N decides.

**Job N** (16 nodes, then the allocation's first 4; 2 reps, arm order reversed in rep 2; `--ctl-log=1` on the controller arms; `m` = section 180's rule, `mb` = bracketed):

| workload | htram | arms |
|---|---|---|
| phase-changing PHOLD | PP 512 | W 50, 75, 100, 150, 250; quantile; m; mb |
| PHOLD lookahead 10, σ 500 | PP 512 | W 50, 100; m; mb |
| PHOLD σ 100 | PP 2,048 | W 300; m; mb |
| PHOLD σ 2,000 | PP 512 | W 300; m; mb |
| PHOLD uniform | WPs 512 | W 300; m; mb |
| traffic | PP 2,048 | W 500, 750, 1,000; quantile; m; mb |
| dragonfly | WPs 512 | W 10,000, 20,000; m; mb |

The sizes are job M's. That makes 31 runs per rep and node count, 124 in all, about 25 minutes.

**Predictions:**
- **N1 (the gate):** the bracketed rule reaches at least 0.9 of the best fixed W in every cell, and at least 0.95 on phase-changing PHOLD.
- **N2:** on phase-changing PHOLD its kept share is at most 35% and its final step at most 1.35×, against 44% and 1.68–2.0× unbracketed.
- **N3:** on the other six workloads it is within 0.03 of the unbracketed rule.
- **N4:** traffic's best fixed W on the finer grid is 500 or 750, and the measured rules reach 0.95–1.02 of it, not section 181's 1.02–1.07.
- **N5:** phase-changing PHOLD's best fixed W is 75–150.

**What follows:**
- **N1 right:** the bracketed rule is the default and the controller is frozen; F4 uses jobs M and N.
- **N1 wrong:** the controller freezes anyway, on whichever rule has the better worst case over jobs M and N, and the paper reports phase-changing PHOLD as its limit.

### §184 · Job L32 results: at 32 nodes the lowest blocked share again marks the best fixed W (W 400 for σ 100 and σ 2,000), and the quantile rule reaches 0.87–0.96 of it on σ 100; the measured rule is the rule section 174 called for (2026-11-01; skx batch job 3668913, 32 nodes)

> **Status: current.** Design and predictions in section 174; L16 (4 and 16 nodes) in section 176.
> - **Job:** 108 runs, all finished in 20 minutes; gate 30/30. Committed counts are equal within every workload and node count.
> - **Tree:** `charades-alloc` at 3dc65ad, so the controller arm is the quantile rule (`q:0.001`). The measured rule did not exist yet.
> - **Data:** `~/charades-data/scale32/blocked/blocked32_j3668913/`; script `l_summary.py` there.
> - **Start-up:** two `/work2` I/O errors at the job's start (chdir), harmless.
> - **Noise:** per-rep ratios vary by up to ±10% at 32 nodes (uniform most).

**Medians of 3 reps** (the same allocation for 16 and 32 nodes; rate in M committed ev/s, higher is better; blocked share = mean over PEs of the PE time stopped at the window's edge, lower is better):

| workload | nodes | W 250 | W 300 | W 400 | W 500 | W 600 | quantile rule (mean W) | lowest blocked share at |
|---|---|---|---|---|---|---|---|---|
| σ 100 | 16 | 625.3 (30.9%) | 659.5 (26.0%) | **686.1** (21.2%) | 613.4 (28.9%) | 576.8 (32.2%) | 662.6 (313) | W 400 |
| | 32 | 1,167.5 (35.8%) | 1,242.7 (31.1%) | **1,295.5** (26.5%) | 1,256.1 (27.7%) | 1,169.9 (31.7%) | 1,133.2 (313) | W 400 |
| σ 2,000 | 16 | 466.2 (40.3%) | 509.7 (32.8%) | **517.0** (28.3%) | 479.4 (31.0%) | 447.5 (34.8%) | 515.2 (299) | W 400 |
| | 32 | 919.2 (41.6%) | 938.5 (38.4%) | **1,010.6** (30.7%) | 961.9 (32.0%) | 826.1 (38.5%) | 998.4 (299) | W 400 |
| uniform | 16 | 316.4 (42.9%) | 322.1 (40.6%) | **324.6** (36.4%) | 313.4 (38.9%) | 297.0 (40.9%) | 327.9 (299) | W 400 |
| | 32 | 493.7 (48.6%) | 521.2 (44.9%) | **526.9** (41.7%) | 520.8 (41.0%) | 500.9 (40.8%) | 540.7 (298) | W 600 (W 400–600 within 1 point) |

**What it says:**
- **The best fixed W at 32 nodes is 400 for σ 100 and σ 2,000.** σ 100: 1.04–1.09 of W 300 per rep. σ 2,000: 1.01–1.21. On uniform, W 300–500 are level within the noise.
- **The lowest blocked share marks the best fixed W in 5 of 6 cells.** In the sixth (uniform, 32 nodes) W 400–600 are within a point of each other and within the noise in rate. With L16 that makes 11 of 12 cells.
- **The quantile rule misses W 400 on σ 100 at 32 nodes:**
  - It holds W at 313 and reaches 0.87–0.96 of W 400 per rep.
  - On σ 2,000 it reaches 0.96–0.98 of W 400; on uniform it is the best arm.
- **The cost of a wider window is still mostly blocked time.**
  - At W 600, busy time per committed event is 1.05× W 300 (σ 100), 1.10× (σ 2,000) and 1.12× (uniform) at 32 nodes.
  - The blocked share stops falling at W 400 and rises again.
- **σ 100 at 32 nodes is not a blocked-time outlier in this allocation:**
  - From 16 to 32 nodes at W 300 its blocked share rises 5.1 points, about as much as σ 2,000's (5.6).
  - PE time per committed event rises 6.5% (1.12 to 1.19 µs), not section 173's 23%. Section 173 ran in another allocation, and 32-node runs vary between allocations (section 166).

**Predictions (section 174):**
- **L1 mostly wrong.**
  - σ 100's blocked share rises 5.1 points from 16 to 32 nodes at W 300, not ≥ 12.
  - σ 2,000's rises ≤ 6 points (5.6), which is right.
  - σ 100 at W 500 on 32 nodes is within 6 points of its 16-node W 300 share (27.7 vs 26.0), which is right.
- **L2 wrong**, as at 16 nodes: busy time at W 600 is 1.05× W 300 for σ 100, below 1.06.
- **L3 wrong**, as at 16 nodes: the blocked share at the best W spans 26.5–41.7%.

**What follows (PAPER.md item 2):**
- Item 2 said: if the lowest blocked share again marks the best W and the controller misses it at 32 nodes, try a blocked-time rule. Both hold.
- The rule section 174 named for "L3 wrong" already exists: the measured rule (sections 180 and 182). It perturbs W and compares busy plus blocked PE time per committed event.
- So no separate blocked-time rule: item 2 is closed into item 1.
- Section 181 shows why the cost must include busy time. On phase-changing PHOLD the lowest blocked share is at the worst W, where rollbacks dominate.
- Whether the measured rule finds W 400 on σ 100 at 32 nodes is checked in the paper-grade 32-node runs (F1), which run it as the default.

### §185 · Job N results: the bracketed measured rule is 0.91–1.03 of the best fixed W in every cell (worst 0.91, against 0.87 unbracketed), and the controller is frozen on it; phase-changing PHOLD stays its weakest workload; the heap fix holds on Stampede3 (2026-11-01; skx-dev batch job 3669802, 16 nodes)

> **Status: current.** Design and predictions in section 182.
> - **Job:** 124 runs, all finished in 24 minutes (skx copy 3669803 cancelled); gate 60/60; tree `charades-phaseb` at e1fbdc4.
> - **Data:** `~/charades-data/phaseb/nctl182/j3669802/` (with `--ctl-log` for every controller arm); script `~/charades-data/phaseb/nctl182/n_summary.py`.
> - **Copy:** `/work2` hung for about 15 minutes during the copy (a listing stuck in Lustre); the 16-node data arrived once it recovered.

**Each policy ÷ the best fixed W of the same rep** (rep 1 / rep 2; higher is better; `m` = section 180's rule, `mb` = bracketed, the new default; fixed W in the model's time unit):

| workload | nodes | best fixed W (M ev/s) | bracketed | unbracketed | quantile rule | the other fixed W |
|---|---|---|---|---|---|---|
| phase-changing PHOLD | 16 | W 100 (348.9) | **0.95 / 0.93** | 0.88 / 0.90 | 0.96 / 0.94 | W 50: 0.90 / 0.91; W 75: 0.98; W 150: 0.97 / 0.95; W 250: 0.92 / 0.90 |
| | 4 | W 100 (121.5) | **0.91 / 0.92** | 0.91 / 0.87 | 0.86 / 0.90 | W 50: 0.94 / 0.96; W 75: 1.00 / 0.98; W 150: 0.94 / 0.96; W 250: 0.81 / 0.84 |
| lookahead 10, σ 500 | 16 | W 50 (555.6) | 0.98 / 1.03 | 0.97 / 1.02 | | W 100: 0.92 / 0.95 |
| | 4 | W 50 (144.7) | 0.95 / 0.95 | 0.95 / 0.97 | | W 100: 0.89 |
| σ 100 | 16 | W 300 (692.6) | 1.02 / 0.93 | 1.00 / 0.93 | | |
| | 4 | W 300 (173.0) | 0.98 / 0.98 | 0.98 / 0.99 | | |
| σ 2,000 | 16 | W 300 (548.9) | 0.98 / 0.97 | 0.95 / 0.94 | | |
| | 4 | W 300 (141.1) | 0.96 / 0.94 | 0.94 / 0.94 | | |
| uniform | 16 | W 300 (364.4) | 0.98 / 0.98 | 0.97 / 0.95 | | |
| | 4 | W 300 (122.8) | 0.95 / 0.93 | 0.95 / 0.95 | | |
| traffic | 16 | W 500 (957.5) | 0.97 / 0.95 | 0.95 / 0.96 | 0.89 / 0.87 | W 750: 0.98 / 0.97; W 1,000: 0.93 |
| | 4 | W 500 (243.8) | 0.95 / 0.95 | 0.98 / 0.95 | 0.95 / 0.93 | W 750: 0.99 / 0.95; W 1,000: 0.93 / 0.94 |
| dragonfly | 16 | W 20,000 (374.3) | 1.02 / 1.00 | 1.01 / 1.00 | | W 10,000: 0.99 |
| | 4 | W 20,000 (108.7) | 1.01 / 1.03 | 1.00 / 1.00 | | W 10,000: 0.99 / 0.97 |

(A single ratio means both reps gave it. The quantile rule ran on phase-changing PHOLD and traffic only.)

**Worst case over jobs M and N** (lowest rep, 14 cells each):
- bracketed: 0.91 (phase-changing PHOLD, 4 nodes);
- unbracketed: 0.87 (the same cell);
- quantile rule: 0.31 (dragonfly, job M);
- any single PHOLD window: 0.54 or lower (job M).

**What it says:**
- **The bracket stops the wandering.** On phase-changing PHOLD, 86–88% of the bracketed rule's rounds sit at W 50–149, against 67–70% unbracketed; 1–2% reach W ≥ 250, against 2–5%.
- **The remaining loss on that workload is the cost of measuring, not where W sits.**
  - The best fixed W is flat over 75–100.
  - The bracketed rule spends most rounds there, yet reaches 0.91–0.95.
  - Half its periods run at a trial W, and every change of W leaves a transient while GVT and the htram horizon catch up. This job does not separate the two, and the controller is now frozen.
- **The quantile rule follows the phases but does no better.** On phase-changing PHOLD at 4 nodes it holds W near 66 in lookahead-10 phases and near 306 in lookahead-100 phases, yet reaches 0.86–0.90. The best W does not scale with the delay between these phases, so following them is not what pays (section 182's "considered and not chosen").
- **Elsewhere the bracket costs nothing.** It is within 0.03 of the unbracketed rule on the other six workloads, and above it in 8 of those 12 cells.
- **Traffic:** the best fixed W is 500 at both node counts. The bracketed rule reaches 0.95–0.97 (W about 555–606), the quantile rule 0.87–0.95, and W 1,000 0.93. Section 181's "1.02–1.07" was against a grid without W 500.
- **The heap fix holds on Stampede3.** All 12 traffic runs per node count commit one count with one digest (4 nodes: 1,131,043,125, job M's majority count; 16 nodes: 4,524,190,271). All 8 dragonfly runs per node count also share one digest. Every other workload commits one count per node count.

**Predictions (section 182):**
- **N1 half right.** Every cell is at least 0.9 (worst 0.91). Phase-changing PHOLD reaches 0.91–0.95, not ≥ 0.95.
- **N2 wrong.** On phase-changing PHOLD the bracketed rule kept 35–38% of its trials, not ≤ 35%. Its final step was 1.08–2.0, not ≤ 1.35.
- **N3 right:** within 0.03 of the unbracketed rule on the other six workloads.
- **N4 right:** traffic's best fixed W on the finer grid is 500, and the measured rules reach 0.95–0.98 of it.
- **N5 right:** phase-changing PHOLD's best fixed W is 100 (75–100 at 4 nodes).

**Decision (per section 182, N1 not fully right): the controller is frozen** on the rule with the better worst case over jobs M and N:
- **The rule:** the measured rule, bracketed: `--ctl=3`, with `--ctl-bracket=1`, `--ctl-period=8`, `--ctl-settle=2` and the step constants as in main b67e32d.
- **The paper's robustness claim (claim 2, figure F4):**
  - Over 7 workloads at 4 and 16 nodes, the frozen rule is 0.91–1.03 of the best fixed W for each workload.
  - The quantile rule falls to 0.31 (dragonfly).
  - Any single fixed W falls to 0.54 (PHOLD alone).
  - On steady workloads it ties a well-chosen fixed W (0.93–1.03), as PAPER.md already says. Its weakest workload is phase-changing PHOLD (0.91–0.95).
- **Still to run for F4 (PAPER.md item 3; item 4 since 2026-11-02, when the application runs moved ahead of it):**
  - Devastator's rule in Charades (`--ctl=2`) on the same workloads;
  - Devastator's own adaptive window on the PHOLD workloads;
  - the frozen rule at 32 nodes (F1's runs; section 184's W 400 question).

### §237 · The measured controller's trials reach two buckets: `--ctl-reach-buckets=2`, and checks that it changes no earlier controller result (2026-11-06; Mac)

> **Status: current.** User decision 2026-11-06 (section 236): widen the controller's trial range so that it can reach W 5,000 on VLSI. This is a change to the controller frozen on 2026-11-01.
> - **Code:** charades 85a2aad. Mac: change tier on the four measured-controller configs (`ctl_measured_bucket`, `agg_ctl_measured_bucket_pp`, `agg_ctl_measured_fast_bucket_pp`, `agg_ctl_measured_fast_nobracket_bucket_pp`) 132/132.
> - **Runs:** on the Mac at 1 × 4, `ctl_measured_bucket` with `--ctl=3 --ctl-bracket=1`; logs not kept (session scratch), the numbers below are copied from them.

**The change** (`measured_clamp`, `controller.C`):
- **Before:** a trial window was held between the 0.01 and 0.99 quantiles of the remote-send delay, then raised to at least one bucket. On VLSI every delay is under one bucket, so every trial ran at one bucket (section 236).
- **Now:** under bucketed GVT the upper end is the 0.99 quantile or `--ctl-reach-buckets` buckets (default 2), whichever is larger. `--ctl-reach-buckets=0` restores the old range.
- **Why two buckets:** a window two buckets wide lets PEs run on while a GVT update is one bucket late (section 228). On VLSI two clock periods are the best fixed window at 1, 2 and 16 nodes (section 236).
- **New statistics** at the end of a `--ctl=3` run:
  - the least 0.99 quantile of delay that any clamp saw;
  - how many trials the reach let past that quantile ("Trials past it"). Zero means every decision matched the old controller's.

**Checks** (Mac; the trials the reach changed; any value above 0 would change a result):

| workload (as in F4 unless noted) | bucket | least 0.99 quantile of delay seen | two buckets | trials changed |
|---|---|---|---|---|
| dragonfly, F4's link settings (16 routers per group, 10 global channels, arrival 500), end time 4,000,000 | 1,000 ps | 12,510 ps | 2,000 ps | **0** |
| phase-changing PHOLD (test config `phases`: 10/200 and 100/1,000) | 8 | 3,019 | 16 | **0** |
| traffic (test config `trips`, lookahead 100) | 8 | 4,109 | 16 | **0** |
| VLSI, `tiny.bench` × 3 (test config `base`) | 100 ps | 21.9 ps | 200 ps | 3 |

- **PHOLD and traffic cannot be affected**, whatever the scale. Every remote delay is at least the lookahead (10 or 100) plus an exponential draw (mean 200 or 1,000). Even at the shortest lookahead and mean, under 4% of delays fall below 16, so the 0.99 quantile stays far above two buckets of 8.
- **Dragonfly** keeps a sixfold margin at F4's link settings. Its 16-node runs (28 routers per group, 14 global channels) use the same link delays.
- **So the controller results so far stand unchanged:** F4 (sections 230, 232), the 1–32-node tables, and phase-changing PHOLD. Their runs would have made the same decisions, and none is rerun. Every `--ctl=3` run from now on prints the statistic, so paper-scale runs check this themselves.
- **On the VLSI test** the window now leaves one bucket: time-weighted mean 122 ps and final 150, against 100 throughout with `--ctl-reach-buckets=0`. Every run commits the same count (15,489).
- **The frozen controller is now** `--ctl=3`, bracketed, with `--ctl-reach-buckets=2`. Its VLSI row is measured in the VLSI rerun job (step 2 of the plan of 2026-11-06).

### §245 · Where the controller's 3–7% goes (job CC design, 2026-11-06; written before any runs)

> **Status: done; results in section 246.** Queued 2026-11-06 as 3690326 (skx-dev) and 3690327 (skx; `TWIN=3690326`, and the skx-dev copy reads 3690327 from `f1_240/ctlcost245.twin`). Login-node checks pass; arm order and options checked on the Mac against a stub `ctl_sweep.sh` (74 calls, 110 runs). User decision 2026-11-06 (after section 244): one diagnostic job on skx-dev while the 32-node jobs wait; no engine change.

**The question.** In F1 and F5a the frozen controller (`--ctl=3`, bracketed) settles at the best fixed W's value but runs 3–7% slower than that fixed W:
- σ 500 at 16 nodes: mean W 378–402, against fixed W 400 per rep 0.965 / 0.930 / 0.921 (section 243);
- traffic at 1 node: mean W 504–506, against fixed W 500 per rep 0.93–0.96 (section 244).

In both it rolls back under 0.5% of events.

**How the controller works (`controller.C`, `measured_window`):**
- Periods alternate between a base, at the W in force, and a trial at W × step or W ÷ step.
- Each period runs `--ctl-settle` rounds (2) unmeasured, then sums `--ctl-period` rounds (8) of PE time and committed events.
- With the bracket, the base is measured again after the trial. A trial is kept only if it beats both bases.
- The step starts at 1.5, grows 1.5× (in log) on a kept trial up to 2, and halves after two drops in a row, down to 1.05.
- A round is about 0.5–2 ms, so a run makes hundreds of trials: σ 500 at 16 nodes 158 (34 kept), traffic at 1 node 562 (173 kept).
- Every round, `decide()` sets the window, `agg_set_window` (one assignment) and `wake()` (acts only on a parked PE); `--ctl-dry=1` skips those three and keeps W fixed, but runs everything else.

**What the existing traces already show** (F5a traffic, which ran with `--ctl-log=1`; the per-round W, committed events and PE time, scratch analysis):
- **The start is negligible.** The controller sits at its starting W (one bucket) for 12–20 of 10,400–13,000 rounds.
- **Time at windows other than the best is cheap.**
  - Priced within the controller's own run, rounds at other windows cost 0.9–1.3% extra time in total.
  - At 1 node, 59% of the time is at W ≈ 516 and 24% at W ≈ 413, which costs 1.012× per event.
- **Most of the gap arises at the same W.**
  - At 1 node, the controller's rounds within ±12% of W 500 cost 1.030–1.060× per event what the fixed W 500 run does, against 1.045–1.074× for the whole run.
  - Each run's per-round PE time sums to its measured run time (within 0.2%), so the accounting closes.
- **One confound:** F5a's controller runs printed two lines per round on PE 0 (`--ctl-log=1`, about 26,000 lines a run), and its fixed-W runs printed none. F1's PHOLD runs had no log and show the same gap.

**Candidate causes:**
- **H1, the measuring and reducing:** the delay record on every remote send, the counters and histogram on the count waves, `decide()`.
- **H2, the per-round log on PE 0** (traffic in F5a only).
- **H3, changing W every period** (every 10 rounds): GVT and the htram horizon re-settle after each change, at any W.
- **H4, time at trial windows,** priced by the cost curve near the best W.

**Job CC** (`$WORK/charades-runs/ctlcost245.slurm`, copy in `~/charades-data/f1/`):
- **Queue:** skx-dev, 16 nodes, 50 minutes, `-x c455-081`, plus an skx copy. The copy that starts first cancels the other (the twin guard; the skx-dev copy reads the other's ID from a file written after both are submitted).
- **Tree:** `charades-r5` (85a2aad). Gate: F1's change tier on 2 nodes.
- **Cells:** PHOLD σ 500 (F1's settings, PP 2,048) and traffic (F5's settings, PP 2,048, `--commit-digest`), at 16 nodes, then 1 node. 3 reps, arm order reversed in rep 2.
- **Arms per cell:**
  - **F:** fixed W, a grid around the best: σ 500 at 200 / 300 / 400 / 600; traffic at 350 / 500 / 750 / 1,000.
  - **C:** the controller (`mb:0`), as in F1 and F5.
  - **CL:** C with `--ctl-log=1`.
  - **CPL:** CL with `--ctl-period=32`: a change of W every 34 rounds instead of 10.
  - **D:** dry at the best fixed W (`--ctl=3 --ctl-bracket=1 --ctl-dry=1 --optimism-window=W`; σ 500: W 300 at 1 node, 400 at 16; traffic: W 500).
  - **DL:** D with `--ctl-log=1`, the per-round reference at a fixed W.
- **Launch:** as F1 for PHOLD and F5 for traffic, except that `--ctl-log` is set per arm.
- **About 110 runs, 30–40 minutes.**

**Analysis:**
- Rates per arm, median of 3.
- **H1:** D ÷ F at the same W. **H2:** C ÷ CL. **H3:** CPL ÷ CL.
- **H4 and closure:** from CL's and DL's per-round traces, the controller's extra PE time over DL's cost per event, split into rounds within ±12% of the best W and rounds outside it, and priced against F's cost curve.

**Predictions:**
- **CC1. Counts:** every arm in a cell commits the same count; every traffic run has the same digest.
- **CC2. The gap reproduces:** C ÷ the best fixed W in the grid is 0.93–0.98 for σ 500 at 16 nodes and 0.95–0.99 at 1 node; 0.95–0.99 for traffic at 1 node; and 0.97–1.03 for traffic at 16 nodes, where W 750 is in the grid now.
- **CC3. H1 is small:** D ÷ F at the same W is at least 0.99 in every cell.
- **CC4. H2:** CL ÷ C is at least 0.97 in every cell. That is, the log costs at most 3%, so it explains part of traffic's gap in F5a at most.
- **CC5. H3 is the main cause:** in every cell where C ÷ the best fixed W is below 0.97, CPL ÷ CL is at least 1.02.
- **CC6. Closure:** at least half of CL's extra PE time over DL arises in rounds within ±12% of the best W, as in F5a's traffic traces.
- **CC7. The cost curve:** the best fixed W is 300 (σ 500, 1 node), 400 (σ 500, 16), 500 (traffic, 1) and 750 (traffic, 16). One step of 1.5 from it costs 2–10%.

**What follows:**
- **If CC5 holds** (changing W costs):
  - The candidate change is fewer changes once the step reaches its floor: a longer period, or a pause between trials after rejections.
  - It would change the engine, so the controller arms of F1, F4 and F5 would be rerun (the user's decision).
- **If CC3 fails** (the measuring costs): look at the delay record per remote send and the per-wave counters.
- **If neither:** the per-round traces show where the time goes, and this section says so.

### §246 · CC results: without its per-round log the controller runs at 0.970–0.985 of the best fixed W. The log itself costs 2–6%, and F4, F5 and the VLSI jobs ran every controller arm with it. Most of what remains is time at trial windows; changing W is not the cause (2026-11-06; skx-dev batch job 3690326, 16 nodes)

> **Status: current.** Design and predictions in section 245.
> - **Job:** 19 min. Gate 24/24. The guard cancelled the skx copy 3690327 when this copy started. 110 runs, all finished.
> - **Data:** `~/charades-data/f1/cc245/cc_j3690326/`; summary `~/charades-data/f1/cc245_summary.py`, output `cc245/cc_j3690326_summary.txt`.
> - **Counts (CC1, right):** every arm in a cell commits the same count; every traffic run has the same digest.
> - **Spread between reps:** 1.01–1.06 at 16 nodes, mostly under 1.03 at 1 node. The ratios below are medians of 3 with the per-rep range, paired within each rep.

**Rates** (M committed ev/s, median of 3, higher is better):

| cell | fixed W grid | best fixed W | C | CL | CPL | D (dry at the best W) | DL |
|---|---|---|---|---|---|---|---|
| PHOLD σ 500, 16 nodes | 200: 626.5, 300: 716.0, 400: 724.0, 600: 584.9 | 400 | 704.1 | 689.8 | 673.4 | 719.5 | 686.0 |
| PHOLD σ 500, 1 node | 200: 42.5, 300: 45.6, 400: 41.3, 600: 34.1 | 300 | 44.2 | 44.2 | 43.0 | 45.4 | 45.4 |
| traffic, 16 nodes | 350: 848.9, 500: 1,079.4, 750: 1,174.2, 1,000: 1,057.6 | 750 | 1,157.1 | 1,091.3 | 1,130.9 | 1,052.9 (at W 500) | 1,045.3 (at W 500) |
| traffic, 1 node | 350: 69.1, 500: 73.8, 750: 69.0, 1,000: 64.6 | 500 | 72.1 | 69.5 | 70.1 | 73.8 | 72.4 |

**Ratios** (median, per-rep range in brackets; higher is better for the first arm):

| cell | C ÷ best fixed W (the gap) | D ÷ F at the same W (measuring) | C ÷ D (moving W; at 1 node both at the best W) | CL ÷ C (the log, controller) | DL ÷ D (the log, fixed W) | CPL ÷ CL (period 32) |
|---|---|---|---|---|---|---|
| PHOLD σ 500, 16 nodes | 0.972 | 0.994 (0.984–0.997) | 0.979 (0.967–0.986) | 0.980 (0.975–0.980) | 0.953 (0.935–0.961) | 0.976 (0.976–0.989) |
| PHOLD σ 500, 1 node | 0.970 | 0.996 (0.996–1.002) | 0.973 (0.974–0.976) | 0.999 (0.964–1.009) | 0.998 (0.985–1.002) | 0.975 (0.962–1.002) |
| traffic, 16 nodes | 0.985 | 0.975 (0.937–0.977; W 500) | — (D at W 500, not 750) | 0.943 (0.941–0.983) | 0.993 (0.989–1.049) | 1.036 (0.995–1.044) |
| traffic, 1 node | 0.977 | 0.999 (0.972–1.000) | 0.977 (0.972–0.992) | 0.963 (0.943–0.971) | 0.981 (0.980–1.003) | 1.010 (0.992–1.044) |

**Per round** (CL's and CPL's logs against DL's cost per committed event). This is clean at 1 node only. At 16 nodes DL's own rate varies by up to 3.7% between reps, and on traffic DL ran at W 500 rather than the best W.
- **PHOLD σ 500, 1 node:**
  - CL spends 55–76% of its time within ±12% of W 300, yet 80–100% of its extra time over DL falls in the other rounds.
  - A round right after a change of W costs 1.5–3% more than the rounds after it. Such rounds are 10% of all rounds, so changes cost about 0.2–0.3% in all.
- **Traffic, 1 node:** CL spends 43–56% of its time near W 500, and 69–74% of its extra time falls in the other rounds.
- **How this closes:** the extra time sits in rounds at windows the cost curve prices at 1.07–1.34× (σ 500, 1 node: W 200 1.07, W 400 1.10, W 600 1.34 time per event). That accounts for C ÷ D of 0.973–0.977.
- **This corrects section 245's reading of F5a's traces.** There, the controller's rounds near W 500 cost 1.03–1.06× the fixed W 500 run's. That run printed no log while the controller's did, and the log alone costs 0.94–0.97 on traffic at 1 node.

**What the job shows:**
- **The per-round log (`--ctl-log=1`) is the largest single cost.**
  - It costs 2–6%: CL ÷ C is 0.94–0.98 on traffic and on σ 500 at 16 nodes, and DL ÷ D is 0.935–0.961 on σ 500 at 16 nodes.
  - PE 0 prints two lines a round, 1,000–1,700 rounds a second.
  - **These jobs passed it to every Charades arm, but only arms that run a controller print:** F4 and F4R (sections 227, 230–232), F5 (sections 186–194 and 244), ABL and F3R (222–225), and the VLSI jobs (191–239, including VS3).
    - So in all of them, the controller (and Devastator's rule run in Charades) carried a cost of 2–6% that the fixed-W arms did not.
    - F1 (sections 242–243) and the old A1/A2r PHOLD tables ran without it.
- **Without the log, the controller is 0.970–0.985 of the best fixed W in the grid,** in all four cells.
  - **Measuring** costs 0–1.6% in three cells. On traffic at 16 nodes the dry arm ran at 0.94–0.98 of fixed W 500 per rep; that arm's own spread is 1.057.
  - **Moving W** costs 1–3% more (C ÷ D 0.967–0.992 per rep). That is mostly time at trial windows, priced by a steep cost curve: one step of about 1.5 from the best W costs 7–24% per event (σ 500 at 16 nodes: W 600 1.24×).
  - **Changing W itself** costs about 0.3%.
- **A longer period does not help.**
  - With `--ctl-period=32`, PHOLD runs at 0.96–1.00 of CL, because each trial lasts longer at its worse window.
  - On traffic it runs at 0.99–1.04, inside the spread.

**Predictions:**
- **CC1: right.**
- **CC2: right.** The gap reproduces: 0.972 and 0.970 on σ 500 at 16 and 1 nodes, 0.977 on traffic at 1 node, 0.985 on traffic at 16 against W 750.
- **CC3: mostly right.** Measuring costs at most 1% in three cells (0.994, 0.996, 0.999). On traffic at 16 nodes it is 0.975.
- **CC4: wrong.** The log costs up to 6% (CL ÷ C 0.943 on traffic at 16 nodes), not at most 3%.
- **CC5: wrong.** Changing W is not the main cause. A period of 32 does not help PHOLD, and a change costs about 0.3%.
- **CC6: wrong.** At 1 node, 69–100% of the extra time is in rounds away from the best W, not near it. Section 245's reading of F5a's traces was the log, as above.
- **CC7: half.** The best fixed W is as predicted in all four cells (300, 400, 500, 750). But one step of about 1.5 costs 7–24%, not 2–10%.

**What follows:**
- **The controller rows of F4, F5 and VLSI understate it by about 2–6%** against fixed W and against the other engines. That includes F5a's traffic controller at 0.93–1.06 of its best fixed W per rep, and VS3's VLSI controller at 0.95–1.02.
  - Their fixed-W arms, Devastator and ROSS are unaffected.
  - The two 32-node jobs still pending, F5-32 (3688917) and V32 (3688918), pass `--ctl-log=1` too. What to do about them, and about the finished rows, is the user's decision.
- **Without the log, the controller's cost against the best fixed W is 1.5–3%,** mostly the trial windows it pays to find that W. Smaller or rarer trials could cut it, but would change the engine and mean rerunning every controller arm, F1 included.
- **The log stays off in paper runs from now on.** Per-round traces come from separate runs, as here.

### §250 · F4 rerun without diagnostics: the robustness comparison on the current tree, with F4's three flags only in a check arm (job F4b design, 2026-11-07; written before any runs)

> **Status: design (results in 251).**
> - **User decision 2026-11-07:** rerun F4 in full without the log (sections 246, 249).
> - **Submitted 2026-11-07:** 3691176 (skx-dev) and 3691177 (skx; the skx-dev copy reads 3691177 from `f4b250/f4b250.twin`).
>   - A first pair, 3691173 / 3691174, was cancelled 2 minutes after 3691173 started. Its batch node, c454-004, reported "/work2 is mounted not FULL nor IDLE", and the script's first read of the Devastator tree hung in Lustre I/O wait there.
>   - Both copies now run with `-x c455-081,c454-004`. 3691176 started at 07:36:53. Its batch node, c454-002, printed the same message, and its checks took about 3 minutes before it went on. So /work2 was slow on the compute nodes at the time, and c454-004 was probably not at fault.
>   - Rates come from each engine's own timers, not from wall time, so slow file reads at startup do not enter them.
> - **Script:** `$WORK/charades-runs/f4b250.slurm` (copy in `~/charades-data/f4/`). It runs on skx-dev with an skx copy, 16 nodes, limit 1:55, about 75 minutes, `-x c455-081`.
> - **Code:** tree `charades-r5` (85a2aad), the tree of F1, F5a2 and VA.
>   - F4 ran 8a34d51. The engine code between the two is 609212b (`--fossil-rounds`; its default is the old rule) and 85a2aad (`--ctl-reach-buckets=2`).
>   - The reach moved no trial on dragonfly, PHOLD or traffic on the Mac (section 237). Every controller run here prints `Trials past it (reach buckets)`, which checks that on Stampede3.

**Why.** F4 passed `--blocked-time=1 --ctl-log=1 --commit-digest=1` to every Charades arm.
- The log prints only in the controller and Devastator's rule in Charades, and it cost them 2–6% on traffic and about 2% on PHOLD at 16 nodes (sections 246, 248).
- The other two flags cost 0–1.6% wherever they were measured (sections 248, 249), but never on PHOLD.
- So F4's controller column (0.83–1.03), which claim 2 quotes, is low by up to a few percent. Its baselines are not affected.

**Plan, as F4 (section 227).**
- **Workloads:** job N's seven, with F4's sizes, htram settings and grids:
  - phase-changing PHOLD, PP 512, W 50 / 75 / 100 / 150 / 250 / 300;
  - lookahead 10 σ 500, PP 512, W 25 / 50 / 100 / 300;
  - σ 100, PP 2,048, and σ 2,000, PP 512, each W 100 / 200 / 300 / 400;
  - uniform, WPs 512, W 100 / 200 / 300 / 400;
  - traffic, PP 2,048, W 500 / 750 / 1,000;
  - dragonfly, WPs 512, W 10,000 / 20,000 / 40,000 ps.
- **Arms:**
  - Charades: the fixed grid, the frozen controller (`mb:0`), and Devastator's rule in Charades (`hill:<bucket>`, from one bucket).
  - Devastator (2 × 23, CLCG4): F4's fixed grid and its own window, capped at 120 s.
- **Layout:**
  - 4 nodes: four streams side by side (Charades A and B, Devastator A and B).
  - 16 nodes: Charades then Devastator in each rep, reversed in rep 2.
- **Gate:** the change tier on 2 nodes (Simple PHOLD, traffic, dragonfly).

**What changes from F4:**
- **Timing arms carry the paper launch only.**
- **Check arm `old`:** the controller with F4's three flags, every cell and rep, run after that rep's timing arms. It gives the digest check (one digest per cell, compared with F4's) and the flags' cost paired per rep.
- **Reps:** 3, not 2, so every cell has a median (Devastator has had slow reps, sections 244 and 248). Arm and workload order are reversed in rep 2.
- **Arms that hit their cap:** a Devastator window or Charades hill climb that hits its cap is skipped in later reps, and at 16 nodes if it hit it at 4. F4's adaptive window stalled in both reps on phase-changing PHOLD and σ 2,000 at 4 nodes. F4 skipped those only at 16 nodes.
- **Warm-up:** a short run starts each stream and is not counted (F1 and F5 do the same).

**Flags per arm.** Listed from a stub run of the script, in which a fake `srun` printed every command (297 Charades and 183 Devastator commands). Charades' launch for every arm:
- `+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free` under `numactl --localalloc`, `srun -c 24`, with 2 × 23 PEs per node;
- config `bucket` (sync=3, gvt=4, buffer-size=655360);
- from `ctl_sweep.sh`: `--gvt-bucket-size` (8; dragonfly 1,000) and htram `--aggregation=1 --agg-mode --agg-buffer --agg-policy=1 --agg-horizon-margin=8`;
- the model's settings in its config file.

The GVT progress print stays at its default, as in every paper run (its cost was within the spread, section 248).

| arm | Charades flags beyond the launch | why |
|---|---|---|
| fixed W | `--optimism-window=W` | F4's grid |
| controller `mb:0` | `--ctl=3 --ctl-bracket=1` | the frozen controller (section 185; trial reach from section 237) |
| Devastator's rule `hill:B` | `--optimism-window=B --ctl=2` | starts from one bucket, as in F4 |
| check `old` | `--ctl=3 --ctl-bracket=1 --blocked-time=1 --ctl-log=1 --commit-digest=1` | F4's flags: the digest check and their cost |
| warm-up, one per stream | `--optimism-window=300`; σ 100, PP 2,048, end 512,000 | first-run effects; not counted |

- **Devastator:** `--lp-per-rank=128 --start-events=15 --rng=clcg4`, the model's arguments and `--end-time`.
  - The window comes from `deva_static_look_dt`, which is unset for its own window.
  - The environment is `GASNET_OFI_SPAWNER=pmi FI_PROVIDER=psm2 GASNET_BACKTRACE=1`. The backtrace setting acts only on a crash.
  - The launch is `srun -c 24 --cpu-bind=cores -m block:block` under `stdbuf -oL`. It prints about 20 lines a run and carries no diagnostics.
- **Runs:**
  - Charades: 252 timing, 42 check and 3 warm-up.
  - Devastator: 180 plus 3 warm-up, about 170 after the cap skips.
  - F4's run times give about 17 minutes at 4 nodes and 17 per rep at 16 nodes.

**Predictions** (each policy ÷ the best fixed W of the same engine and rep; median of 3 reps; higher is better):
- **F4b-1. Counts:** every finished run commits one count per cell in both engines, the same as F4. The `old` arm's digests are one per cell and equal F4's (and F4R's on phase-changing PHOLD at 16 nodes).
- **F4b-2. The controller without the log** is 1.00–1.06× F4's value in each cell:
  - 0.95–1.00 on lookahead 10, σ 100, σ 2,000, uniform and traffic at 4 and 16 nodes;
  - 1.01–1.05 on dragonfly;
  - 0.84–0.92 on phase-changing PHOLD at 4 nodes, still its worst cell (the loss there is the cost of measuring, section 230), and 0.94–0.99 at 16.
- **F4b-3. `old` ÷ the controller, paired per rep:** traffic 0.94–0.99, PHOLD 0.96–1.00, dragonfly 0.98–1.01.
- **F4b-4. Devastator's rule in Charades** spans 0.10–0.90. Its worst cell is at most 0.25, and it is at most 0.65 on every PHOLD workload.
- **F4b-5. Devastator:**
  - Its best fixed W runs within 5% of F4's rate in each cell (compared at its fastest rep when a slow rep moves the median).
  - Its own window does not finish within 120 s on phase-changing PHOLD and σ 2,000 at 4 nodes, and is 0.09–0.85 where it finishes.
- **F4b-6. Charades ÷ Devastator,** each at its best fixed W, is 1.00–1.05× F4's per cell, about 1.13–2.10.
- **F4b-7. No rep is disturbed.** Every fixed-W run makes at most 1.03 count waves per GVT advance, except W 25 on lookahead 10 (1.33 throughout F4). Every controller run reports 0 trials past the reach.

**What follows:**
- The results replace sections 230 and 232 (F4, F4R) as the robustness figure and claim 2's numbers in PAPER.md.
- If F4b-2 holds, phase-changing PHOLD at 4 nodes stays the controller's worst cell, and the paper states it as the limit.

### §251 · F4b results: without diagnostics the frozen controller is 0.92–1.03 of the best fixed W per cell (median of 3 reps; 0.86–1.03 per rep), and 0.96–1.03 everywhere but phase-changing PHOLD at 4 nodes; its baselines fail as in F4: Devastator's rule in Charades falls to 0.15, Devastator's own window to 0.09 or does not finish (now also out of memory), one PHOLD window to 0.51; one count and one digest per cell (2026-11-07; skx-dev batch job 3691176, 16 nodes)

> **Status: current.** Design and predictions in section 250. Replaces sections 230 and 232 (F4, F4R).
> - **Job:** 66 minutes (07:36:53–08:42:51).
>   - The gate passed, and the skx copy (3691177) was cancelled by the guard.
>   - Every Charades timing and check run finished.
>   - Devastator's own window is the only Devastator arm that failed (below).
> - **Data:** `~/charades-data/f4/f4b250/j3691176/` (with `job.out`; digest files not copied). The summary is `f4b_summary.py` (arguments: this job, F4, F4R), with output in `f4b_summary.txt`, in `~/charades-data/f4/`. The departures below are also in `f4b250_notes.txt`.
> - **Two departures from section 250:**
>   - **The two 4-node Charades warm-ups failed** ("Argument parse error"). Both streams wrote the same config file at once, so every key appeared twice; the script gave the warm-up one name for both streams. Those two streams therefore started cold, as in F4. Timing runs were not affected, since each workload has its own directory.
>   - **At 07:44:59 I removed the cap marker for Devastator's own window on uniform.** It had hit the 120 s cap at 4 nodes in rep 1, but it finished that cell in both F4 reps. Without the marker, the rule would also have dropped it in reps 2–3 and at 16 nodes. The cap rule was meant for windows that never finish (phase-changing PHOLD and σ 2,000 in F4).

**Counts (F4b-1 right).** In each of the 14 cells, every finished run of both engines commits F4's count. Charades' `old` runs give one digest per cell, equal to F4's (F4R's on phase-changing PHOLD at 16 nodes).

**Each policy ÷ the best fixed W of the same engine and rep.** Median of 3 reps, range in parentheses, F4's mean in brackets (F4R's on phase-changing PHOLD at 16 nodes). Fixed W is in the model's time unit, dragonfly in ps. Rates are M committed ev/s, medians. Higher is better.

| workload | nodes | Charades' best fixed W (M ev/s) | Charades' controller | Devastator's rule in Charades | Devastator's best fixed W (M ev/s) | Devastator's own window | Charades ÷ Devastator, each at its best fixed W [F4] |
|---|---|---|---|---|---|---|---|
| phase-changing PHOLD | 4 | 75 (135.2) | **0.92** (0.86–0.93) [0.85] | 0.31 (0.29–0.32) | 250 (98.2) | did not finish in 120 s (< 0.09), rep 1; then skipped | 1.38 [1.38] |
| | 16 | 75 / 100 (364.3) | 0.96 (0.96–0.99) [0.95] | 0.41 (0.41–0.42) | 250 (285.8) | not run (did not finish at 4 nodes) | 1.27 [1.32] |
| lookahead 10, σ 500 | 4 | 50 (165.3) | 0.97 (0.97–0.98) [0.96] | 0.46 (0.40–0.49) | 200 (142.1) | 0.72 (0.68–0.73) | 1.16 [1.17] |
| | 16 | 50 (641.5) | 1.00 (1.00–1.01) [0.98] | 0.27 (0.27–0.30) | 200 (510.9) | out of memory in reps 1 and 2; 0.62 in rep 3 | 1.26 [1.26] |
| σ 100 | 4 | 300 (211.9) | 0.97 (0.95–0.98) [0.95] | 0.32 (0.32) | 500 (168.4) | 0.66 (0.52–0.71) | 1.26 [1.23] |
| | 16 | 300 (837.0) | 0.96 (0.95–0.97) [0.95] | 0.33 (0.29–0.43) | 1,000 (661.8) | 0.41 (0.35–0.42) | 1.26 [1.26] |
| σ 2,000 | 4 | 300 (161.3) | 0.97 (0.96–0.97) [0.94] | 0.30 (0.26–0.31) | 1,000 (99.9) | did not finish in 120 s (< 0.06), rep 1; then skipped | 1.61 [1.59] |
| | 16 | 300 / 400 (614.1) | 0.99 (0.99–1.00) [0.98] | 0.16 (0.15–0.16) | 1,000 (371.1) | not run | 1.65 [1.66] |
| uniform | 4 | 300 (136.5) | 0.96 (0.96–0.98) [0.94] | 0.18 (0.16–0.35) | 500 (68.3) | 0.09 in reps 2–3 (115–117 s); rep 1 hit the 120 s cap | 2.00 [2.00] |
| | 16 | 300 (387.7) | 0.99 (0.98–1.00) [0.98] | 0.24 (0.20–0.26) | 1,000 (195.7) | 0.61 (0.56–0.62) | 1.98 [2.00] |
| traffic | 4 | 500 (299.5) | 0.96 (0.95–0.97) [0.95] | 0.61 (0.56–0.61) | 2,000 (233.6) | 0.28 (0.25–0.49) | 1.28 [1.25] |
| | 16 | 750 (1,185.0) | 0.98 (0.97–1.01) [0.93] | 0.60 (0.60–0.62) | 2,000 (912.7) | 0.19 (0.18–0.22) | 1.30 [1.28] |
| dragonfly | 4 | 20,000 (122.7) | 1.03 (1.03) [1.03] | 0.81 (0.79–0.83) | 20,000 (88.2) | 0.80 (0.77–0.81) | 1.39 [1.39] |
| | 16 | 20,000 (416.0) | 1.01 (1.01–1.02) [1.03] | 0.79 (0.79–0.82) | 20,000 (214.8) | 0.84 (0.83–0.84) | 1.94 [1.93] |

("< x": the run did not end within 120 s, so its rate is below the committed count ÷ 120 s, which is x of Devastator's best. "Out of memory": `std::bad_alloc` on several processes after 74–76 s.)

**Worst case of each policy** (lowest; higher is better):

| policy | worst rep | worst cell (median) | F4 (section 230) |
|---|---|---|---|
| Charades' frozen controller | 0.86 (phase-changing PHOLD, 4 nodes, rep 3) | **0.92** (phase-changing PHOLD, 4 nodes); 0.96–1.03 in the other 13 | 0.83 |
| Devastator's rule in Charades | 0.15 (σ 2,000, 16 nodes) | 0.16 (σ 2,000, 16 nodes) | 0.13 |
| Devastator's own window | did not finish: the cap on phase-changing PHOLD and σ 2,000 at 4 nodes (< 0.06–0.09), out of memory on lookahead 10 at 16 nodes in 2 of 3 reps; 0.09 among runs that finished (uniform, 4 nodes) | the same | did not finish (< 0.06); 0.09 among finished runs |
| one window for the five PHOLD workloads | W 100: 0.55 (σ 100, 16 nodes); W 300: 0.51 (lookahead 10, 4 nodes) | | 0.55; 0.52 |

**What F4's flags cost.** Each check run is the controller with F4's three flags, paired with the clean controller run of the same rep (median; higher means the flags cost less):

| | phase-changing PHOLD | lookahead 10 | σ 100 | σ 2,000 | uniform | traffic | dragonfly |
|---|---|---|---|---|---|---|---|
| 4 nodes | 0.989 | 0.976 | 0.965 | 0.991 | 0.990 | 0.960 | 0.997 |
| 16 nodes | 0.996 | 0.988 | 0.981 | 0.978 | 0.991 | 0.971 | 1.007 |

- **The controller column moved, the fixed windows barely did.**
  - Against F4, the controller's per-cell ratio is 0.98–1.08× F4's, and 1.01–1.05× in 11 of 14 cells.
  - Charades' best fixed W runs at 0.986–1.033× F4's rate. The fixed arms lost `--blocked-time` and `--commit-digest`, and these runs are in another allocation.
  - Devastator's best fixed W runs at 1.001–1.031× F4's.
- **Phase-changing PHOLD at 4 nodes** rose from 0.85 to 0.92 (1.08×), more than the flags' cost there (0.989). Its reps spread 1.08: F4's 0.83 was its low rep, and this job's low rep is 0.86.
- **Traffic at 16 nodes** rose from 0.93 to 0.98, in line with the flags' 0.971 plus F4's lower rep.

**Devastator's own window.**
- **Lookahead 10 at 16 nodes:** out of memory in 2 of 3 reps. In F4 it finished at 0.60–0.66 after running to its 2⁵⁸ clamp; here rep 3 finished at 0.62. Its window runs far ahead on that workload, and how far it gets before memory runs out varies from run to run.
- **Uniform at 4 nodes:** 115–120 s, about 0.09 of its best (F4: 0.13–0.17).

**Checks:**
- **No rep is disturbed.** Two W 100 runs at 16 nodes in rep 1 made 1.05 count waves per GVT advance: uniform 1.049 and σ 100 1.053 (F4: 1.034 on σ 100). They ran at their other reps' rate (280.1 against 279.0–280.0 M ev/s, and 460.4 against 462.2–462.3), so at W 100 the 1.03 threshold is too tight. W 25 on lookahead 10 made 1.33, as in F4.
- **Spread between reps:**
  - Charades' best fixed W: 1.04 or less.
  - The controller: 1.05 or less, except phase-changing PHOLD at 4 nodes (1.08).
  - Devastator's best fixed W: 1.04 or less.
- **The trial reach (section 237):** all 84 controller runs (timing and check) report 0 trials past it, so the reach changed no decision on these workloads.
- **Devastator's rule in Charades** settles at 72–89% efficiency, with mean windows 1.3–113× the best fixed W, as in F4.

**Predictions (section 250):**
- **F4b-1 right.**
- **F4b-2 mostly right:**
  - Every cell is in its predicted range:
    - lookahead 10, σ 100, σ 2,000, uniform and traffic 0.96–1.00;
    - dragonfly 1.03 and 1.01;
    - phase-changing PHOLD 0.92 at 4 nodes (the top of 0.84–0.92) and 0.96 at 16.
  - The ratio to F4 falls outside 1.00–1.06 in two cells: phase-changing PHOLD at 4 nodes (1.08) and dragonfly at 16 nodes (0.98).
- **F4b-3 right:** traffic 0.960 and 0.971; PHOLD 0.965–0.996; dragonfly 0.997 and 1.007.
- **F4b-4 right:** 0.15–0.83. The worst cell is 0.16, and no PHOLD rep exceeds 0.49.
- **F4b-5 mostly right:**
  - Devastator's best fixed W is within 3.1% of F4's in every cell.
  - Its own window did not finish on phase-changing PHOLD and σ 2,000 at 4 nodes, as predicted, and is 0.09–0.84 where it finished.
  - Not predicted: out of memory on lookahead 10 at 16 nodes, and the cap in one uniform rep at 4 nodes.
- **F4b-6 mostly right:** Charades ÷ Devastator is 1.16–2.00, and 0.96–1.03× F4's per cell (predicted 1.00–1.05×). Five cells are lower by at most 1%. Phase-changing PHOLD at 16 nodes is 0.96× F4's; F4's Charades rate there comes from F4R, another allocation.
- **F4b-7 mostly right:** no rep is disturbed, but two W 100 runs exceed the threshold at normal rates. The reach changed no trial.

**What follows:**
- **Claim 2's numbers** (PAPER.md; replaces section 230):
  - The frozen controller is 0.92–1.03 of the best fixed W per cell (median of 3 reps; 0.86–1.03 per rep), and 0.96–1.03 in 13 of 14 cells.
  - Its weakest cell is phase-changing PHOLD at 4 nodes, where the loss is the cost of measuring. The paper states it as the limit.
  - Its baselines' worst cases: Devastator's rule in Charades 0.15; Devastator's own window 0.09 or not finishing (the 120 s cap on two workloads, out of memory on a third); any one PHOLD window 0.51–0.55.
- **Charades ÷ Devastator on these seven workloads** (each at its best fixed W, short runs) is 1.16–2.00, unchanged from F4 within 4%.
- **F4's flags** (`--blocked-time --ctl-log --commit-digest`) cost the controller up to 4% (traffic and σ 100 at 4 nodes), consistent with sections 246 and 248.
- **The script's warm-up bug:** if `f4b250.slurm` is reused, the warm-up needs a name per stream.

## Earlier

Superseded or historical sections, in the order they were written. Their numbers came from an older stack, launch or setting, or a later section replaced them; each says which.

### §6 · Window controller (design, 2026-10-20; written before any runs)

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

### §7 · Window controller, first Stampede3 results (2026-10-20, idev job 3622528, 4 skx nodes)

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

### §8 · Waste floor, controller cost, horizon margin (2026-10-20, idev job 3623246, 4 skx nodes)

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

### §13 · Controller on the GVT's count waves (implementation, 2026-10-21)

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

### §15 · Controller on the GVT's count waves, results (2026-10-21, idev job 3625507, 4 skx nodes)

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

### §17 · Controller step 2: cost-aware target and floor guard (design, 2026-10-21; written before the runs)

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

### §18 · Controller step 2, results (2026-10-21, idev job 3626068, 4 skx nodes)

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

### §31 · Phase-changing PHOLD and traffic characterisation (design, 2026-10-22; written before any runs)

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

### §32 · Phase-changing PHOLD and traffic, results (2026-10-22, idev job 3628935, 4 skx nodes)

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

### §33 · Devastator's own window on phase-changing PHOLD (design, 2026-10-22; written before any runs)

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

### §34 · Devastator's own window on phase-changing PHOLD, results (2026-10-22, idev job 3629361, 4 skx nodes)

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

### §227 · F4, robustness of the window policies: Charades' fixed windows, its frozen controller and Devastator's rule in Charades, against Devastator's fixed windows and its own adaptive window, on seven workloads at 4 and 16 nodes (job F4 design, 2026-11-05; written before any runs)

> **Status: design.** PAPER.md item 4, figure F4. User decisions 2026-11-05: prepare F4; submit it. Submitted as 3684492 (skx-dev) and 3684493 (skx); the later starter is cancelled.
> - **Script:** `$WORK/charades-runs/f4227.slurm` (copy in `~/charades-data/f4/`), skx-dev, 16 nodes, 1 h 50 min.
> - **Code:** charades 8a34d51, tree `charades-f3` (built for job F3R): round 3 and every default since, on `charm-pads-perf`. No code change for this job.
> - **Mac check on this code:** change tier 63/63 on Simple PHOLD, traffic and dragonfly with `ctl_hill`, `ctl_hill_shared` and `agg_ctl_measured_bucket_pp`. One Mac run of the hill climb from one bucket (PHOLD σ 100, htram PP, 2 processes × 4 PEs) commits the right count, and its window doubles from 8 to about 310 within 21 control rounds, then reaches the end time in the run's last rounds.
> - **Devastator:** the binaries of the earlier comparisons (phold-gauss 2026-10-22/24, with the phase options; traffic and dragonfly 2026-11-01), 2 × 23, `--rng=clcg4`, without `numactl` (it gained nothing there, section 166).

**Why all of Charades' arms run again.** Jobs M and N (sections 181, 185) measured the fixed windows and the frozen controller on the paper's older tree (e1fbdc4). Round 3 runs PHOLD 1.16–1.18× faster (section 215), so the best fixed W may have moved. Each ratio in F4 is a policy ÷ the best fixed W of the same engine, rep and allocation, so the fixed grid, the controller and Devastator's rule all run here, on the tree the paper's runs will use.

**The two baselines, as each engine runs them:**
- **Devastator's own window** (`global_status_state::update()` in `src/devastator/pdes.cxx`):
  - It starts at 1 time unit and changes once per GVT round.
  - The efficiency is committed ÷ executed events, summed over the last 16 GVT rounds.
  - Below 0.33 the window is quartered, below 0.66 halved, and above 0.95 doubled.
  - Otherwise it moves by 1%, keeping its direction while the 16-round committed total rises and reversing when it falls.
  - It is clamped to [1, 2⁵⁸]; `deva_static_look_dt=<W>` fixes it instead.
- **Devastator's rule in Charades** (`--ctl=2`, `hill_climb_window` in `src/scheduler/controller.C`):
  - The same thresholds, over the same 16-round average.
  - It changes once per control round (8 count waves).
  - In the 1% band it steps up if this round committed more events than the last, and down if fewer.
  - **Start:** one bucket, the smallest window the controller allows under the bucketed GVT (Devastator starts at 1).
  - **Cadence:** deciding after every GVT update, the literal transplant, was worse in Charades (0.10–0.17 of the best fixed W, section 7; again section 15), so this job runs the per-round variant, the better of the two.
- **Earlier results** (older stacks; F4 replaces them):
  - Devastator's own window ÷ its best fixed W: 0.92–0.95 on traffic and dragonfly at 1 node, 0.80–0.83 on dragonfly and 0.28–0.33 on traffic at 4 nodes (section 187); 0.06–0.28 on PHOLD at σ ≥ 1,000 (an older stack); 0.70–0.77 on phase-changing PHOLD at 8 PEs per process (section 34), and on full nodes at 4 nodes it did not finish in 2 of 3 phase-changing runs (`~/charades-data/full/deva_phase_r0.5/`).
  - The hill climb in Charades: 0.19–0.55 of the best fixed W with htram, 0.85–0.98 with direct sends (section 28).

**Workloads** (job N's sizes and htram settings; Charades buckets of 8, dragonfly 1,000 ps; 128 LPs per PE or per Devastator worker, traffic 64 × 46·N intersections; Devastator runs the same models with the same parameters):

| workload | Charades htram | end time | Charades fixed W | Devastator fixed W |
|---|---|---|---|---|
| phase-changing PHOLD (lookahead 10 / mean 200 and 100 / 1,000, alternating every 8,000; remote 0.5) | PP 512 | 1,024,000 | 50, 75, 100, 150, 250, 300 | 100, 250, 500 |
| lookahead 10 / mean 200, σ 500 | PP 512 | 512,000 | 25, 50, 100, 300 | 100, 200, 400 |
| σ 100 | PP 2,048 | 2,048,000 | 100, 200, 300, 400 | 500, 1,000, 2,000, 4,000 |
| σ 2,000 | PP 512 | 2,048,000 | 100, 200, 300, 400 | 500, 1,000, 2,000 |
| uniform | WPs 512 | 2,048,000 | 100, 200, 300, 400 | 250, 500, 1,000, 2,000 |
| traffic (16 cars per intersection, trip radius 3) | PP 2,048 | 6,000,000 | 500, 750, 1,000 | 1,000, 2,000, 4,000 |
| dragonfly (16 / 10 at 4 nodes, 28 / 14 at 16; arrival 500 ns, generating 150,000 ns) | WPs 512 | 160,000,000 ps | 10,000, 20,000, 40,000 | 10,000, 20,000, 40,000 |

- **Charades' grids** bracket job N's best fixed W in every workload (it was at the grid's edge on dragonfly, 20,000, and on lookahead 10, 50). W 100 and W 300 run on every PHOLD workload, so one window for all five can be judged from this job.
- **Devastator's grids** bracket its best W in jobs A2r and F5 (sections 142–143: σ 100 1,000–2,000, σ 2,000 1,000, uniform 500–1,000, lookahead 10 200; section 187: traffic 2,000, dragonfly 10,000–20,000; section 34: phase-changing 250).
- **Policy arms:** Charades' frozen controller (`mb:0`) and Devastator's rule in Charades (`hill:<one bucket>`); Devastator's own window (`adaptive`).

**Runs.** Launch as in job N: 2 × 23, pemap, 23 LCI devices, `+mempool_remote_free`, `numactl --localalloc`, `--blocked-time=1 --ctl-log=1 --commit-digest=1`. 2 reps, arm and workload order reversed in rep 2. Cap 180 s per Charades run, 120 s per Devastator run.
1. **Gate**, 2 nodes: change tier on Simple PHOLD, traffic and dragonfly with `ctl_hill`, `agg_ctl_measured_bucket_pp` and `bucket_window`.
2. **4 nodes**, four streams side by side:
   - nodes 0–3: Charades on phase-changing PHOLD, lookahead 10, σ 100, σ 2,000;
   - nodes 4–7: Charades on uniform, traffic, dragonfly;
   - nodes 8–11 and 12–15: Devastator, the same split.
3. **16 nodes:** per rep, every Charades arm, then every Devastator arm (Devastator first in rep 2). Devastator's adaptive window and Charades' hill climb run at 16 nodes only on workloads where every 4-node run of that arm finished.
- About 72 runs per rep and node count (42 Charades, 30 Devastator), 288 in all; estimate 50–70 minutes.

**Measures:** M committed ev/s; each policy ÷ the best fixed W of the same engine and rep; the controller's and the hill climb's mean and final W; Devastator's mean window (`window_mean`) and efficiency; blocked share; committed counts and digests.

**Predictions:**
- **F4-1 (counts):** within each workload and node count, every finished run of either engine commits the same count, and Charades' runs share one digest.
- **F4-2:** the frozen controller is 0.90–1.03 of Charades' best fixed W in all 14 cells (job N: 0.91–1.03). Phase-changing PHOLD stays its weakest workload, at most 0.95.
- **F4-3:** Charades' best fixed W is job N's in at least 10 of 14 cells (phase-changing 100, lookahead 10 50, the lookahead-100 PHOLD workloads 300, traffic 500, dragonfly 20,000). A new grid point beats job N's best by more than 3% in at most 3 cells.
- **F4-4:** Devastator's rule in Charades has a worst cell of at most 0.6 of the best fixed W, and is at most 0.6 on at least three of the five PHOLD workloads.
  - With htram, a rolled-back event costs many committed ones, so its efficiency targets (doubling above 95%) overshoot (section 28).
  - On dragonfly, whose rollback level is about 3% at every W (section 179), its 16-round efficiency stays above 0.95, so its W doubles to the end time in every run.
- **F4-5:** Devastator's own window is at most 0.85 of Devastator's best fixed W on at least 4 of the 7 workloads at 16 nodes. Its worst case, counting runs that do not finish within the cap, is at most 0.35. At least one workload's adaptive runs do not finish at 4 nodes.
- **F4-6:** no single window serves the five PHOLD workloads. W 100 is at most 0.7 of the best fixed W on at least one lookahead-100 workload, and W 300 at most 0.7 on lookahead 10 or phase-changing PHOLD.

**What follows:**
- F4 is built from this job: for each engine and workload, each policy ÷ that engine's best fixed W, and each policy's worst case.
- If F4-2 fails (any cell under 0.90), read the `CTL` logs for where W went before writing claim 2. The controller stays frozen.
- If Devastator's rule in Charades does well (F4-4 wrong), the paper says so; claim 2 then rests on the worst case against Devastator's own window and any single fixed W.

### §230 · F4 results: Charades' frozen controller is 0.83–1.03 of the best fixed W, with phase-changing PHOLD at 4 nodes its weakest cell; Devastator's rule in Charades falls to 0.13; Devastator's own window falls to 0.09 and does not finish on two workloads; one window for all PHOLD falls to 0.52; every cell commits one count in both engines (2026-11-05; skx-dev batch job 3684492, 16 nodes)

> **Superseded (2026-11-07):** the robustness figure and claim 2's numbers now come from §251 (job F4b: F4's plan on the current tree, without diagnostics, 3 reps). This section's controller column carried `--ctl-log=1`, which cost it up to 4%; its baselines and counts stand.

> **Status: current.** Design and predictions in section 227. The episode cell (phase-changing PHOLD, 16 nodes, rep 2) is replaced by job F4R's three reps (section 232): controller 0.95–0.96, Devastator's rule in Charades 0.40–0.44.
> - **Job:** 51 minutes; gate 63/63 (skx copy 3684493 cancelled before it started).
>   - Every Charades run finished.
>   - Devastator's own window did not finish within the 120 s cap on phase-changing PHOLD and σ 2,000 at 4 nodes, in both reps, so it was skipped there at 16 nodes. Every other Devastator run finished.
> - **Data:** `~/charades-data/f4/f4227/j3684492/` (with `job.out`; `gvt_*.out` and digest files not copied); `f4_summary.py`, output `f4_summary.txt`, in `~/charades-data/f4/`.
> - **Counts (F4-1 right):** in each of the 14 cells, every finished run of both engines commits one count, and Charades' runs share one digest.
> - **One cell was hit by an episode on the machine:** phase-changing PHOLD at 16 nodes, rep 2, the job's last block (described below). Ratios from it are marked †, and the worst cases are given with and without it.

**Each policy ÷ the best fixed W of the same engine and rep** (rep 1 / rep 2; M committed ev/s in parentheses; higher is better; mean W of Charades' controller in parentheses; fixed W in the model's time unit, dragonfly in ps):

| workload | nodes | Charades' best fixed W (M ev/s) | Charades' controller (mean W) | Devastator's rule in Charades | Devastator's best fixed W (M ev/s) | Devastator's own window |
|---|---|---|---|---|---|---|
| phase-changing PHOLD | 4 | 75 (136.6 / 134.6) | **0.88 / 0.83** (118, 156) | 0.29 / 0.29 | 250 (99.4 / 96.8) | did not finish (< 0.09) |
| | 16 | 100 / 75 (370.6 / 346.3) | 0.97 / 0.13† (108, 371) | 0.41 / 0.11† | 250 (273.1 / 285.4) | not run |
| lookahead 10, σ 500 | 4 | 50 (161.2 / 162.5) | 0.96 / 0.96 (61, 61) | 0.51 / 0.41 | 200 / 100 (143.3 / 132.4) | 0.72 / 0.77 |
| | 16 | 50 (636.1 / 628.9) | 0.98 / 0.98 (65, 62) | 0.31 / 0.29 | 200 (499.8 / 507.2) | 0.60 / 0.66 |
| σ 100 | 4 | 300 (203.4 / 208.1) | 0.95 / 0.94 (316, 322) | 0.32 / 0.37 | 1,000 / 500 (167.7 / 168.0) | 0.70 / 0.62 |
| | 16 | 300 / 400 (826.1 / 834.5) | 0.95 / 0.94 (366, 369) | 0.34 / 0.37 | 1,000 (658.1 / 660.4) | 0.38 / 0.40 |
| σ 2,000 | 4 | 300 (158.1 / 156.9) | 0.95 / 0.93 (318, 315) | 0.32 / 0.41 | 1,000 (99.4 / 98.9) | did not finish (< 0.06) |
| | 16 | 400 / 300 (612.2 / 605.0) | 0.98 / 0.99 (374, 367) | 0.17 / 0.13 | 1,000 (365.3 / 367.6) | not run |
| uniform | 4 | 300 (136.1 / 134.9) | 0.95 / 0.94 (311, 309) | 0.23 / 0.20 | 500 (67.7 / 67.5) | 0.17 / 0.13 |
| | 16 | 300 / 400 (388.8 / 389.0) | 0.98 / 0.98 (367, 348) | 0.23 / 0.25 | 1,000 (194.3 / 194.6) | 0.55 / 0.56 |
| traffic | 4 | 500 (291.9 / 288.1) | 0.95 / 0.96 (548, 546) | 0.59 / 0.62 | 2,000 (233.3 / 232.0) | 0.29 / 0.37 |
| | 16 | 750 (1,140.1 / 1,169.7) | 0.92 / 0.94 (883, 732) | 0.62 / 0.61 | 2,000 (893.0 / 910.4) | 0.09 / 0.22 |
| dragonfly | 4 | 20,000 (120.7 / 120.9) | 1.03 / 1.03 (14,620, 14,234) | 0.84 / 0.80 | 20,000 (86.2 / 87.9) | 0.81 / 0.80 |
| | 16 | 20,000 (409.2 / 409.4) | 1.02 / 1.03 (16,103, 14,064) | 0.82 / 0.79 | 20,000 (212.6 / 211.8) | 0.83 / 0.83 |

("Did not finish (< x)": the run did not end within 120 s, so its rate is below the committed count ÷ 120 s, which is x of Devastator's best. † the episode.)

**Worst case over the 28 rep-cells** (lowest; higher is better):

| policy | worst case without the episode rep | with it |
|---|---|---|
| Charades' frozen controller | **0.83** (phase-changing PHOLD, 4 nodes) | 0.13 |
| Devastator's rule in Charades | 0.13 (σ 2,000, 16 nodes) | 0.11 |
| Devastator's own window | did not finish (< 0.06; σ 2,000, 4 nodes); 0.09 among runs that finished (traffic, 16 nodes) | the same |
| one window for the five PHOLD workloads | W 100: 0.55 (σ 100, 16 nodes); W 300: 0.52 (lookahead 10, 16 nodes) | W 300: 0.26 |

- **The controller is 0.92–1.03 in 12 of the 14 cells.** On phase-changing PHOLD it is 0.83–0.88 at 4 nodes, and 0.97 in the 16-node rep that the episode did not hit.
  - At 4 nodes round 3 moved the best fixed W from 100 (job N) to 75. The controller's mean W is 118–156, and it runs below even W 150 held fixed (0.92–0.94).
  - So, as in job N, the loss is the cost of measuring: half its periods run at a trial W, and every change of W leaves a transient.
- **Devastator's rule in Charades** reaches 0.11–0.84.
  - It settles at 70–88% efficiency, with mean windows 5–66× the best on PHOLD and traffic (σ 100: 3,353–12,507 against 300; dragonfly 1.3–1.4×).
  - Its rule doubles W while efficiency is above 95% and moves it only 1% per round between 66% and 95%. Charades' best fixed windows commit 99.5–100% of the events they execute (dragonfly 92–95%), so the rule's band sits far from where Charades runs best.
  - On dragonfly it is 0.79–0.84 at 75–79% efficiency. Its W did not run to the end time (mean 25,404–27,439 ps; final 29,032–166,744).
- **Devastator's own window** reaches 0.09–0.83 where it finished.
  - On lookahead 10 and σ 100 it runs to its 2⁵⁸ clamp (mean window 1.3–2.6 × 10¹⁷) at 61–85% efficiency.
  - On uniform it stays finite (mean 570–780) at 46–74% efficiency.
  - On phase-changing PHOLD and σ 2,000 at 4 nodes it did not finish within 120 s, where its best fixed W takes 7–11 s.
- **Charades across engines** (each at its best fixed W, same allocation, job N's short sizes, round 3): Charades ÷ Devastator is 1.13–2.01 in all 14 cells. Charades' controller ÷ Devastator's best fixed W is 1.08–1.99 (without †), and ÷ Devastator's own window 1.49–14.3 where that window finished.

**The episode (phase-changing PHOLD, 16 nodes, rep 2).** It was the job's last block, about 11:25–11:31.
- **The waves:** every arm made extra count waves that advanced nothing: 1.07–1.56 waves per GVT advance at fixed W (2.2 for the controller). Every other fixed-W run of the job made 1.00–1.03, except W 25 on lookahead 10 (1.33 in every rep and node count) and dragonfly W 10,000 at 4 nodes in rep 1 (1.09).
- **The windows:** the wider the window, the worse it was. W 50–100 lost 6–15% against rep 1, W 150 24%, W 250 and 300 66–72%. The controller (mean W 371 against 108 in rep 1) and the hill climb, which ran first in the block, lost most.
- **When:** the slowness came in bursts in the middle of runs. W 300 took 8–12 s in three tenths of its advances, against 1.3 s per tenth throughout rep 1. W 250 slowed in its last four tenths.
- **Reading:** a slow period on the machine, amplified by rollbacks at wide windows. An after-effect of the preceding hill-climb run (3.7 billion events rolled back) would have shown at the start of each run and faded instead.
- Rep 1 of the same cell, at the job's start, ran evenly (1.00 waves per advance in every fixed-W arm).

**Predictions (section 227):**
- **F4-1 right.**
- **F4-2 wrong in one cell:** the controller is 0.92–1.03 in 12 of 14 cells, and 0.83–0.88 on phase-changing PHOLD at 4 nodes (predicted at least 0.90). Phase-changing PHOLD is its weakest workload, as predicted. The 16-node rep 2 is the episode.
- **F4-3 right:** the best fixed W is job N's in 12 of 14 cells. The exceptions are phase-changing PHOLD at 4 nodes (75, not 100) and traffic at 16 nodes (750, not 500; W 750 was in job N's grid). The new grid points never beat job N's best by more than 2%.
- **F4-4 mostly right:** the hill climb's worst cell is 0.13, and it is at most 0.6 on all five PHOLD workloads. On dragonfly its W did not double to the end time: it ran at 75–79% efficiency, not above 95%.
- **F4-5 right:** at 16 nodes Devastator's own window is at most 0.83 in all five cells where it ran. Its worst case is under 0.06, and two workloads did not finish at 4 nodes.
- **F4-6 right:** W 100 falls to 0.55 (σ 100) and W 300 to 0.52 (lookahead 10).

**What follows:**
- **Claim 2's number changes** on the current tree: the frozen controller is 0.83–1.03 of the best fixed W, not 0.91–1.03 (jobs M and N, older tree). Its baselines' worst cases are 0.13 (Devastator's rule in Charades), did not finish (Devastator's own window) and 0.52–0.55 (any single PHOLD window).
- **Phase-changing PHOLD at 16 nodes was rerun** (job F4R, section 232): 0.95–0.96 for the controller in three clean reps.

### §231 · F4's phase-changing PHOLD cell at 16 nodes, rerun (job F4R design, 2026-11-05; written before any runs)

> **Status: design.** User decision 2026-11-05: rerun the cell whose rep 2 was hit by an episode on the machine (section 230). Submitted as 3685047 (skx-dev) and 3685048 (skx); the later starter is cancelled.
> - **Script:** `$WORK/charades-runs/f4r231.slurm` (copy in `~/charades-data/f4/`), skx-dev plus an skx copy, 16 nodes, 30 minutes.
> - **Code:** as in F4: tree `charades-f3` (8a34d51), job F4's launch and sizes.

**Runs:** phase-changing PHOLD (lookahead 10 / mean 200 and 100 / 1,000 alternating every 8,000; remote 0.5), htram PP 512, end 1,024,000, 16 nodes. Charades' arms only:
- W 50, 75, 100, 150, 250 and 300;
- the frozen controller (`mb:0`);
- Devastator's rule in Charades (`hill:8`).
3 reps, arm order reversed in rep 2. Gate: the change tier on 2 nodes (Simple PHOLD, `ctl_hill` and `agg_ctl_measured_bucket_pp`).

**Episode check, set before the runs:** a rep counts as disturbed if any fixed-W run in it makes more than 1.03 count waves per GVT advance (section 230: 1.00–1.03 in every undisturbed fixed-W run except W 25). A disturbed rep is reported, and the cell's ratios are taken from the undisturbed reps.

**Predictions:**
- **R1:** every run commits F4's count, 4,096,302,492, with one digest.
- **R2:** no rep is disturbed.
- **R3:** the best fixed W is 75 or 100, and the controller is 0.90–1.00 of it in every rep (F4 rep 1: 0.97; job N: 0.93–0.95).
- **R4:** Devastator's rule in Charades is 0.3–0.5 of the best fixed W (F4 rep 1: 0.41).

**What follows:** the undisturbed reps replace F4's 16-node phase-changing cell in F4 and in PAPER.md's numbers.

### §232 · F4R results: phase-changing PHOLD at 16 nodes reruns clean; the controller is 0.95–0.96 of the best fixed W (W 100) and Devastator's rule in Charades 0.40–0.44; F4's disturbed rep was the machine (2026-11-05; skx-dev batch job 3685047, 16 nodes)

> **Superseded (2026-11-07):** the robustness figure and claim 2's numbers now come from §251 (job F4b: F4's plan on the current tree, without diagnostics, 3 reps). This section's controller column carried `--ctl-log=1`, which cost it up to 4%; its baselines and counts stand.

> **Status: current.** Design and predictions in section 231.
> - **Job:** 10 minutes; gate 12/12. The skx copy 3685048 was cancelled before it started.
> - **Data:** `~/charades-data/f4/f4r231/j3685047/`; `f4r_summary.py`, output `f4r_summary.txt`, in `~/charades-data/f4/`.

**Phase-changing PHOLD, 16 nodes** (M committed ev/s; ÷ the best fixed W of the same rep, higher is better; count waves per GVT advance, lower is better):

| arm | rep 1 | rep 2 | rep 3 | waves per advance |
|---|---|---|---|---|
| W 50 | 338.2 (0.90) | 332.7 (0.91) | 336.9 (0.92) | 1.000 |
| W 75 | 371.1 (0.99) | 358.8 (0.98) | 363.8 (0.99) | 1.000–1.002 |
| **W 100** | **374.8** | **367.4** | **366.0** | 1.000 |
| W 150 | 358.8 (0.96) | 363.3 (0.99) | 346.6 (0.95) | 1.000–1.009 |
| W 250 | 332.5 (0.89) | 334.1 (0.91) | 332.9 (0.91) | 1.000 |
| W 300 | 322.8 (0.86) | 317.3 (0.86) | 316.8 (0.87) | 1.000 |
| controller (mean W) | 358.6 (**0.96**; 107) | 349.1 (**0.95**; 112) | 349.8 (**0.96**; 102) | 1.026–1.043 |
| Devastator's rule in Charades (efficiency) | 150.9 (0.40; 75.1%) | 146.6 (0.40; 73.9%) | 161.1 (0.44; 76.5%) | 1.053–1.080 |

- **Counts (R1 right):** all 24 runs commit 4,096,302,492, F4's count, with one digest (c8e86881…).
- **No rep is disturbed (R2 right):** every fixed-W run makes 1.000–1.009 waves per advance.
- **It reproduces F4's undisturbed rep 1** within 1–2%: W 100 367–375 against 370.6, the controller 349–359 against 358.9 (0.97).
- **The disturbed rep was the machine, not the run order.** Rep 2 here ran its arms in the order of F4's disturbed rep 2: the hill climb first (1.4 billion events rolled back), then the controller, W 300 and W 250. It is clean. W 300 ran at 317.3 M ev/s against 89.3, and W 250 at 334.1 against 112.2.

**Predictions (section 231):**
- **R1 right.**
- **R2 right.**
- **R3 right:** the best fixed W is 100 in every rep; the controller is 0.95–0.96.
- **R4 right:** Devastator's rule in Charades is 0.40–0.44.

**What follows: F4's 16-node phase-changing cell** is F4's rep 1 and these three reps.
- Controller: 0.95–0.97 of the best fixed W.
- Devastator's rule in Charades: 0.40–0.44.
- W 300 as the one PHOLD window: 0.86–0.87.
- Section 230's worst cases without the episode rep stand: controller 0.83 (phase-changing PHOLD, 4 nodes), Devastator's rule in Charades 0.13, one PHOLD window 0.52.
