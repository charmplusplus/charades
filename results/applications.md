# Traffic and dragonfly

The two applications ported from Charades to ROSS and Devastator (phase B), the traffic count fix, and the paper runs F5 at 1–32 nodes. Part of the Charades results: the current paper tables are on the front page, [../RESULTS.md](../RESULTS.md), and every section's date, job, status and file is in [INDEX.md](INDEX.md). Sections keep the numbers (§N) they had in the single RESULTS.md they came from (split 2026-11-07); "section N" anywhere means §N.

| § | date | status | section |
|---|---|---|---|
| 168 | 2026-11-01 | current | Phase B, step 1: weak-scalable forms of dragonfly and traffic |
| 169 | 2026-11-01 | current | Phase B, step 2a: ROSS reproduces Charades' traffic, base and trips |
| 170 | 2026-11-01 | current | Phase B, step 2b: Devastator reproduces Charades' traffic, base and trips |
| 171 | 2026-11-01 | current | Phase B, step 2c: ROSS reproduces Charades' dragonfly, all four configs |
| 172 | 2026-11-01 | current | Phase B, step 2d: Devastator reproduces Charades' dragonfly; both Phase B models now match in all three eng… |
| 175 | 2026-11-01 | design | Phase B, step 3: weak-scaling sizes, a partition that need not divide, and a calibration job |
| 177 | 2026-11-01 | current | Job C results: Phase B builds and counts pass on Stampede3; dragonfly and traffic run faster than predicted… |
| 183 | 2026-11-01 | current | Traffic's varying count: the pending heap reordered equal-timestamp events after an erase; fixed |
| 186 | 2026-11-02 | current (design) | The applications at 1–32 nodes in three engines (F5): the plan, and a calibration job at 1 and 4 nodes |
| 187 | 2026-11-02 | current / design | F5 calibration results: every engine commits the same events; aggregation gains 1.36–1.38× on traffic throu… |
| 194 | 2026-11-02 | current | F5b results, 32 nodes: one count per cell in all three engines; on dragonfly Charades ÷ Devastator reaches… |
| 248 | 2026-11-06 | current | F5a2 results: traffic and dragonfly at 1–16 nodes without diagnostics. Charades ÷ Devastator (controller) i… |
| 188 | 2026-11-02 | superseded by §244, then §248 (was: current / design) | F5a results, 1–16 nodes: every cell commits one count in all three engines; on dragonfly Charades' lead ove… |
| 189 | 2026-11-02 | superseded by §244 (was: current) | F5c results: ROSS's best on dragonfly is batch 2 / GVT interval 64; batch 1 and GVT interval 16 are slower;… |
| 244 | 2026-11-06 | superseded by §248 (was: current) | F5a results: traffic and dragonfly at 1–16 nodes on the final defaults. Charades leads Devastator in all 10… |

## Current

Current findings, and designs with their results, in the order they were written.

### §168 · Phase B, step 1: weak-scalable forms of dragonfly and traffic (2026-11-01, Mac)

> **Status: current** (Mac correctness only; no performance runs yet). Plan in section 140, "Phase B". Commits: dragonfly `--gen-time` and traffic `--trip-radius`, both off by default.

Section 140 found that neither model could be weak-scaled as written. This step adds the option each one needed:

| model | as written | new option (off by default) | new test config | committed events (Mac, every engine config and shape) |
|---|---|---|---|---|
| dragonfly | each MPI process sends 3,000 / arrive-rate messages (15 at 200 ns), then the network drains in a few µs | `--gen-time=T` (ns): generate at the arrive rate until virtual time T, so a process's load does not depend on the network's size | `gentime`: base topology (9 groups, 72 terminals), uniform traffic, T = 10 µs (about 50 messages per process) | 738,837 |
| traffic | cars leave at their destination, drawn anywhere on the grid, so routes and the load per intersection change with the grid | `--trip-radius=R`: each destination is within R intersections in x and y (on the torus, never the car's own intersection, one random draw); a car that reaches it picks the next and keeps driving; routing takes the short way around the torus | `trips`: base grid (8 × 8, 1,024 cars), R 3, end time 60,000 (several trips per car) | 61,559 |

- **Defaults unchanged.** Dragonfly base 226,944 and congested 178,850, traffic base 14,789, as before.
- **Mac change tier, 10 engine configs** (sequential, conservative, blocking, bucketed, bucketed with a window, chare rollback, htram PP with the deadline policy, htram WPs with the input buffer, the sparse controller, the shared controller) **× 1 PE, 4 PEs and 2 × 2:**
  - dragonfly (base, congested, gentime): 84/84;
  - traffic (base, trips): 56/56.
- Both new configs join the change tier's core model configs.
- `--trip-radius` requires R below half the grid's width and height, and it does not combine with an end cluster. `--gen-time` must be below 4.29 ms, the 32-bit generation time a packet carries.

**Next in Phase B:**
- Port both models, in these forms, to ROSS and Devastator. Each port is checked for the same committed events as Charades on the Mac.
  - ROSS uses reverse computation like Charades.
  - Devastator saves state in each event's reverse object, as its PHOLD port does.
- Then size each model on Stampede3 with Charades (LPs per PE; the dragonfly topology grows in steps: groups = a·h + 1), and run the A1/A2 shape.

### §169 · Phase B, step 2a: ROSS reproduces Charades' traffic, base and trips (2026-11-01, Mac)

> **Status: current.**
> - **Port:** `~/pdes-baselines/ROSS/models/traffic/traffic.main.c` (staged in the ROSS checkout, as phold-gauss is; patch `~/pdes-baselines/ross-traffic.patch`). It follows Charades' `models/traffic` draw for draw, including `--trip-radius` (section 168).
> - **Not ported:** the start cluster (`--percent-start`), which no config uses. ROSS matches option names by prefix, so Charades' `--end-size/-x/-y` are `--dest-size/-x/-y` here: as "end-…" they captured `--end`.

**Equal timestamps.** Traffic's events carry their cars, so the order of equal-timestamp events at one intersection decides which car gets which random draws (open issue 8). The three engines break such ties differently:
- **Charades:** sending LP, then the order the sender created them (`event_id`, numbered per chare, so in creation order for each LP).
- **ROSS:** a user priority in [0, 1], then a random tiebreaker drawn from the sender's stream.
- **Devastator:** a 64-bit `subtime` the model may supply.

The port sets ROSS's priority to (sender gid × 2³² + the sender's send count) / 2⁵². That is the same order as Charades, and exact below 2²⁰ LPs (checked). The Devastator port will use `subtime` the same way. Neither engine's core changes.

**Committed events** (count; must equal Charades'):

| config | Charades | ROSS sequential | ROSS rollback check (`--synch=6`) | ROSS conservative, 2 ranks | ROSS optimistic, 2 ranks | optimistic, 4 ranks | optimistic, 4 ranks, `--batch=4 --gvt-interval=256 --nkp=4` |
|---|---|---|---|---|---|---|---|
| base (8 × 8, 1,024 cars, end 20,000) | 14,789 | 14,789 | 14,789 | 14,789 | 14,789 (127 rolled back) | 14,789 (3,753) | 14,789 (6,202) |
| trips (base with `--trip-radius=3`, end 60,000) | 61,559 | 61,559 | 61,559 | 61,559 | 61,559 (1,140) | 61,559 (2,741) | 61,559 (4,066) |

Every column matches, with up to 6,202 rolled-back events, so the reverse handlers and the tie order are right.

**Next:** traffic for Devastator; then dragonfly for both engines.

### §170 · Phase B, step 2b: Devastator reproduces Charades' traffic, base and trips (2026-11-01, Mac)

> **Status: current.**
> - **Port:** `~/pdes-baselines/devastator/bench/traffic.cxx` (intent-to-add, as phold-gauss; patch `~/pdes-baselines/devastator-traffic.patch`).
> - **Binaries:** threads world, `~/pdes-baselines/deva-mac/traffic-threads-r{2,4}`.
> - It follows Charades draw for draw on Charades' clcg4 streams, with state saving (each event's reverse object keeps its LP's state, as in phold-gauss).
> - **Equal timestamps:** each event's `subtime()` is sender gid × 2³² + the sender's send count, which Devastator compares after the time (section 169).

Committed events (count; must equal Charades'; events rolled back in parentheses):

| config | Charades | Devastator, 2 ranks | Devastator, 4 ranks |
|---|---|---|---|
| base (8 × 8, 1,024 cars, end 20,000) | 14,789 | 14,789 (101) | 14,789 (3,151) |
| trips (`--trip-radius=3`, end 60,000) | 61,559 | 61,559 (4,486) | 61,559 (7,850) |

- Devastator's own determinism flag (no equal (time, subtime) pairs) is 1 in every run.
- Traffic now commits the same events in all three engines.
- **Next:** dragonfly for ROSS and Devastator, then the GASNet build of both Devastator models on Stampede3.

### §171 · Phase B, step 2c: ROSS reproduces Charades' dragonfly, all four configs (2026-11-01, Mac)

> **Status: current.**
> - **Port:** `~/pdes-baselines/ROSS/models/dragonfly/dragonfly.main.c` (staged; patch `~/pdes-baselines/ross-dragonfly.patch`). It follows Charades' `models/dragonfly` draw for draw, including `--gen-time` (section 168), integer-picosecond time, the router waiting list released on commit, and the same statistics.
> - **Tie order:** ROSS's user priority, as for traffic (section 169).
> - **Mapping:** by default each rank holds R / ranks consecutive routers with their terminals and MPI processes, as Charades' mapper groups a router with its terminals and processes on one chare (ROSS custom mapping). `--mapping=0` is ROSS's linear mapping.

**ROSS's rollback check (`--synch=6`) needed a checkpointer, and showed a ROSS bug.**
- A router's arrays live outside the state struct, so the default byte comparison checked only their pointers. A custom checkpointer now compares the logical state: scalars, the per-port arrays, and the waiting entries in order.
- ROSS's rollback-check scheduler allocates its checkpoint buffers before it reads the checkpointer's `sz_storage`, so a checkpoint larger than the LP state overruns them. The checkpoint is therefore a state-sized struct holding deep copies.
- ROSS also checks after the event, its reverse, the event again and its commit. Commit handlers change state here on purpose, as in Charades: the print-once drop flags, and a committed credit retires the waiting entry it released. Those changes are excluded from the second comparison.

**Committed events** (count; must equal Charades'; events rolled back in parentheses):

| config | Charades | ROSS sequential | rollback check | conservative, 2 ranks | optimistic, 2 ranks | optimistic, 4 ranks | optimistic, 4 ranks, `--batch=4 --gvt-interval=256 --nkp=4` | optimistic, 4 ranks, linear mapping |
|---|---|---|---|---|---|---|---|---|
| base | 226,944 | 226,944 | 226,944 | 226,944 | 226,944 (20,591) | 226,944 (80,403) | 226,944 (195,643) | 226,944 (392,318) |
| congested | 178,850 | 178,850 | 178,850 | 178,850 | 178,850 (16,770) | 178,850 (55,372) | 178,850 (84,170) | 178,850 (337,568) |
| nonminimal | 311,214 | 311,214 | 311,214 | 311,214 | 311,214 (22,437) | 311,214 (88,824) | 311,214 (248,196) | 311,214 (500,620) |
| gentime | 738,837 | 738,837 | 738,837 | 738,837 | 738,837 (54,725) | 738,837 (172,436) | 738,837 (399,528) | 738,837 (1,162,307) |

- **The model statistics agree too.** For example congested at 4 ranks against Charades sequential:
  - messages 1,080; packets finished 409; total latency 630,020,050 ps; hops 1,520; chunks dropped 10,466; chunks that waited 6,548;
  - gentime: 3,519 packets, 1,054,724,896 ps, 11,652 hops, both engines.
- **ROSS's linear mapping rolls back 4.9–6.7× more events** than the grouped mapping at 4 ranks (base: 392,318 against 80,403). The grouped mapping is the fair setting for timing.

**Next:** dragonfly for Devastator, storing in each event's reverse object only what its handler overwrites, the values Charades keeps in `saved_*` fields, rather than copying a whole router per event.

### §172 · Phase B, step 2d: Devastator reproduces Charades' dragonfly; both Phase B models now match in all three engines (2026-11-01, Mac)

> **Status: current.**
> - **Port:** `~/pdes-baselines/devastator/bench/dragonfly.cxx` (intent-to-add; patch `~/pdes-baselines/devastator-dragonfly.patch`).
> - **Binaries:** threads world, `~/pdes-baselines/deva-mac/dragonfly-threads-r{2,4}`.

**How it is written:**
- **Undo is state saving,** Devastator's own approach. Each event's reverse object keeps the LP's clcg4 state and creation count from before the event, plus only the fields its handler overwrites: the values Charades keeps in its messages' `saved_*` fields. Copying a whole router (its per-port arrays and waiting list) per event would handicap Devastator in the timing runs.
- **The router waiting list** is released as in Charades: a credit marks the entry it serves, and the credit's commit retires it.
- **Ranks hold whole routers** with their terminals and processes, as in Charades and the ROSS port.
- **Tie order** through `subtime()` (section 169).
- **`pdes::register_state` is not used.** Its snapshot, which only rewinding a drain needs, requires a trivially destructible state, and a router holds vectors and a deque.

**Committed events** (count; must equal Charades'; events rolled back in parentheses):

| config | Charades | Devastator, 2 ranks | Devastator, 4 ranks |
|---|---|---|---|
| base | 226,944 | 226,944 (13,690) | 226,944 (48,062) |
| congested | 178,850 | 178,850 (13,140) | 178,850 (39,418) |
| nonminimal | 311,214 | 311,214 (45,647) | 311,214 (44,558) |
| gentime | 738,837 | 738,837 (46,827) | 738,837 (146,687) |

- Devastator's determinism flag is 1 in every run.
- The statistics equal Charades' and ROSS's (section 171) at 4 ranks:
  - congested: 1,080 messages, 409 packets finished, 630,020,050 ps total latency, 1,520 hops, 10,466 chunks dropped, 6,548 that waited;
  - gentime: 3,519 packets, 1,054,724,896 ps, 11,652 hops.

**Phase B ports done on the Mac:** traffic and dragonfly, in their weak-scalable forms, commit the same events in Charades, ROSS and Devastator under every scheduler tried.

**Next in Phase B:**
- Build the ports on Stampede3: ROSS with mvapich, Devastator with GASNet ofi-psm2, one binary per layout.
- Choose weak-scaling sizes with Charades. The dragonfly network grows in steps (groups = a·h + 1); traffic grows with the grid.
- Then the A1/A2-shaped runs.

### §175 · Phase B, step 3: weak-scaling sizes, a partition that need not divide, and a calibration job (design, 2026-11-01; written before any runs)

> **Status: design.**
> - **Ports:** the ROSS and Devastator dragonfly ports no longer need the router count to divide by the ranks. Patches are in `~/pdes-baselines` (`ross-dragonfly.patch`, `devastator-dragonfly.patch`, regenerated). Charades is unchanged.
> - **Stampede3:** ROSS traffic and dragonfly are built with mvapich/3.0 (`$WORK/ROSS`, the same configuration as `phold-gauss`). Devastator's `build_stampede3.sh` takes `BENCHES` (e.g. `"traffic dragonfly"`). Charades builds from a separate worktree, `$WORK/charades-phaseb` (main f1c2f80), so job L32 keeps `charades-alloc`. `ctl_sweep.sh` (f1c2f80) adds `dragonfly:<a>:<h>:<p>:<traffic>:<arrive rate>:<gen-time>` and an optional trip radius on `traffic`.

**The partition.** A dragonfly has R = a·(a·h + 1) routers, and with 46 PEs per node R must divide by 46·N. That forces lopsided shapes: at 32 nodes the only shape near 15 routers per PE is a = 23, h = 25. So all three engines now place routers the same way, in blocks where the first R mod n ranks hold one router more:
- **Charades:** this is Charm++'s default block map of its LP chares at one router per chare (`--routers-per-chare=1`, the default). Charades looks up each chare's home PE, so nothing changed.
- **ROSS and Devastator ports:** rank k holds routers [k·q + min(k, r), (k+1)·q + min(k+1, r)), where q = ⌊R/n⌋ and r = R mod n, with their terminals and processes.

**Mac check of the new partition** (committed events; each must equal Charades'):
- ROSS at 5 and 7 ranks, conservative and optimistic, all four dragonfly configs: 16 of 16 equal.
- Devastator threads world at 4, 5 and 7 ranks, all four configs, 2 runs each: 24 of 24 equal, deterministic.
- Charades at 1 × 5, 1 × 7 and 5 × 1 PEs (36 routers do not divide), `bucket_window` and `agg_deadline_bucket_pp`, base, congested and gentime: 18 of 18 pass.

**Dragonfly shapes** (Charades needs h even; p = 4 terminals per router at every size; the most-loaded PE ÷ the mean is the imbalance the partition leaves; lower is better):

| nodes | ranks | a | h | groups | routers | routers per PE | most-loaded PE ÷ mean | LPs (R + 2·4R) |
|---|---|---|---|---|---|---|---|---|
| 1 | 46 | 13 | 4 | 53 | 689 | 15.0 | 1.001 | 6,201 |
| 2 | 92 | 15 | 6 | 91 | 1,365 | 14.8 | 1.011 | 12,285 |
| 4 | 184 | 16 | 10 | 161 | 2,576 | 14.0 | 1.000 | 23,184 |
| 8 | 368 | 22 | 12 | 265 | 5,830 | 15.8 | 1.010 | 52,470 |
| 16 | 736 | 28 | 14 | 393 | 11,004 | 15.0 | 1.003 | 99,036 |
| 32 | 1,472 | 36 | 18 | 649 | 23,364 | 15.9 | 1.008 | 210,276 |

- Routers per PE stay within 14.0–15.9 (±6.5%). Run tables will report each run's LP count.
- h/a lies between 0.31 and 0.63 (the balanced dragonfly has 0.5).
- Traffic is uniform random (`traffic=1`) with minimal routing.
- 512 B messages at 5.25 GB/s per terminal take about 100 ns to inject, so an arrival interval of 500–1,000 ns is a 10–20% load. Where h = p (1 node), global links carry about the terminals' load; the global links of the larger shapes carry less.
- The largest shape has 210,276 LPs, below the 2^20 at which the ROSS tie priority stops being exact.

**Traffic sizes:** a 64 × 46·N torus, so each PE holds one row of 64 intersections in every engine. 16 cars per intersection, trip radius 3, lookahead 100, mean 1,000.
- A car moving up or down leaves its PE: about half the moves.
- Moves between rows 23k − 1 and 23k leave the process: about 1 in 23 of the vertical moves.

**Job C (calibration and builds; skx-dev, 2 nodes):**
1. **Devastator builds on node 1:** traffic and dragonfly, GASNet ofi-psm2, layouts p2w23, p4w23, p8w23, p16w23, p32w23 and p64w23 (1–32 nodes), plus p2w2 and p2w3 for the count checks.
2. **Meanwhile on node 2, Charades at 1 node,** 1 rep:
   - dragonfly at arrival intervals of 500 and 1,000 ns, generating for 50,000 ns; WPs 512; W 10,000, 50,000 and 200,000 ps and the controller; GVT buckets of 1,000 ps.
   - traffic to end time 500,000; PP 2,048; W 250, 1,000 and the controller.
3. **Counts on 2 nodes,** every engine against Charades' expected counts:
   - Charades: `test.py` change tier, Dragonfly and Traffic, `bucket_window` and `agg_deadline_bucket_pp`.
   - ROSS: optimistic, 5 ranks (dragonfly) and 4 (traffic).
   - Devastator: p2w3 (dragonfly) and p2w2 (traffic).

**Predictions:**
- **C1.** Every count equals Charades' on Stampede3, as on the Mac.
- **C2.** Dragonfly's mean packet latency at 1,000 ns is within 1.2× of its latency at 500 ns: the network is lightly loaded at both.
- **C3.** Charades runs dragonfly at 1 node at 5–20 M committed events/s and traffic at 10–40 M. These rates set the generation window and end time that give runs of about 10 s at every size.
- **C4.** All 16 Devastator binaries build.

**What follows:** the generation window and end time for 10 s runs; then the A1/A2-shaped runs at 1–32 nodes with all three engines. Each engine uses its own best setting:
- Charades: its controller and the better htram mode;
- Devastator: its best of three W;
- ROSS: the better of optimistic and conservative.

### §177 · Job C results: Phase B builds and counts pass on Stampede3; dragonfly and traffic run faster than predicted; the controller reaches only 0.29–0.41 of the best fixed W on dragonfly, still climbing when the short runs end (2026-11-01; skx-dev batch job 3668971, 2 nodes)

> **Status: current.** Design and predictions in section 175.
> - **Job:** 7 minutes.
> - **Data:** `~/charades-data/phaseb/j3668971/`.

**Builds and counts:**
- **Devastator:** all 16 binaries built (traffic and dragonfly, ofi-psm2, p2w2, p2w3 and p2w23 to p64w23) in `$WORK/devastator/bin/ofi-psm2/`.
- **Counts on 2 nodes:**
  - Charades: `test.py` change tier, Dragonfly and Traffic, 30/30.
  - ROSS (optimistic, 5 and 4 ranks): 5/5 equal to Charades' expected counts.
  - Devastator (p2w3, p2w2): 5/5 equal.

**Charades at 1 node** (1 rep; short runs of 1–4 s):

| workload | arm | M committed ev/s (higher is better) | efficiency (%) | blocked share (%) |
|---|---|---|---|---|
| dragonfly, arrival 500 ns (63.5 M events) | W 10,000 ps | **38.5** | 98.0 | — |
| | W 50,000 | 27.1 | 71.2 | — |
| | W 200,000 | 25.4 | 69.7 | — |
| | controller (mean W 1,900; final 7,009) | 15.9 | 98.4 | 75.3 |
| dragonfly, arrival 1,000 ns (31.6 M events) | W 10,000 | **29.6** | 96.1 | 48.4 |
| | W 50,000 | 26.1 | 67.5 | — |
| | W 200,000 | 22.1 | 62.8 | — |
| | controller (mean W 1,571; final 6,474) | 8.6 | 98.2 | 87.8 |
| traffic, end 500,000 (23.6 M events) | W 250 | 56.1 | 100.0 | — |
| | W 1,000 | 59.0 | 99.3 | — |
| | controller (mean W 603) | **59.2** | 99.9 | — |

(— : not printed in the arms' logs read here.)

**What it says:**
- **The controller does not suit dragonfly as it stands:** 0.41 and 0.29 of W 10,000.
  - Its rollback rule set W in about 90% of updates; κ in 9–13%.
  - Its W was still rising when the runs ended: final W 6,474–7,009 ps against time-weighted means of 1,571–1,900. It starts from the smallest window and moves at most 1.25× per update, and dragonfly's delays are in ps, so it needs many updates to reach the 10,000 ps range.
  - The longer runs below will show how much is start-up. The best W itself may lie below 10,000, the smallest W tried.
  - CONTEXT.md listed "test κ on dragonfly, a model it was not fitted to" as open since 2026-10-23. This is that test.
- **Dragonfly aggregates poorly at 1 node:** 2.2–3.0 events per htram message.
- **Traffic's controller is at its best** (W 603, level with W 1,000).

**Predictions (section 175):**
- **C1 right:** every count is equal.
- **C2 right:** mean packet latency is 186 ns at 1,000 ns arrivals and 204 ns at 500 ns (1.09×), so the network is lightly loaded at both.
- **C3 wrong:** both run faster than predicted, dragonfly at 38.5 M ev/s (predicted 5–20) and traffic at 59 M (predicted 10–40).
- **C4 right:** all 16 binaries built.

**Sizes for runs of about 10 s,** assuming each node keeps its 1-node rate:
- **Dragonfly:** arrival 500 ns, generating 300,000 ns (about 380 M events per node).
- **Traffic:** end time 12,000,000 (about 570 M events per node).
- ROSS runs will take 2–5× as long.

**Next:**
- A dragonfly W sweep on long runs at 1 and 4 nodes, with W 2,500–20,000 ps and the controller, to find the best W and see whether the controller converges.
- Then the A1/A2-shaped runs.

### §183 · Traffic's varying count: the pending heap reordered equal-timestamp events after an erase; fixed (2026-11-01, Mac)

> **Status: current.** Section 181 found one traffic run of job M whose committed count differed. It found the same in earlier full-node traffic data.
> - **Fix:** `src/collections/pending_heap.h`, in the commit after this section's.
> - **Data and scripts:** the session scratchpad (`trrep/`); not kept.

**Reproduction on the Mac.** Congested traffic: 128 × 64 intersections, 15 cars each, half of them starting in the 32 × 32 corner; end 512,000; direct sends:

| launch | W | runs | runs with a different count |
|---|---|---|---|
| 1 process × 8 PEs | 1,000 (and the quantile rule) | 24 | 0 |
| 4 processes × 2 PEs | 500 (direct sends; 13 runs also htram PP 512) | 53 | 3 (one of them htram) |
| 8 processes × 1 PE | 1,000 | 65 | 6 |

The sequential scheduler commits 30,302,829 events. That is the count of every run that agreed, so the runs that differed were wrong (+355 to +591 events).

**New tools (off by default):**
- **`--commit-digest=1`:**
  - each LP hashes its committed events (timestamp, source LP, type) in commit order;
  - the run prints one combined hash and writes `commit_digest.csv`, one row per LP;
  - `--commit-digest-interval=T` also keeps each LP's hash at every multiple of T.
- **`--commit-log-until=T`:** each PE writes its committed events below T, with the first 16 bytes of each event's data, to `commit_log_<pe>.bin`.
- **`--trace-lp=N`** (with `--trace-from`, `--trace-to`): prints every receive, execution, rollback, cancellation and commit of LP N's events.
- **`ctl_sweep.sh`:** keeps each run's digest table (`logs/<label>.digest.csv`) and adds a `digest` column.

**The diagnosis:**
1. **Digests at 8,000-step marks:** a divergent run first differs from a good one between t = 16,000 and 24,000, in LPs around (10, 7) inside the congested corner.
2. **Commit logs** (first difference with its data):
   - At LP 906, two arrivals from LP 905 share t = 17,346.
   - The good run committed car 1031/1 (event ID 18504), then car 391/19 (18506).
   - The divergent run committed 391/19 (18652), then 1031/1 (18650). The comparator puts the lower ID first.
   - Both IDs follow creation order (LP 905 sent 1031 at t = 17,043 and 391 at 17,046), so the heap, not the IDs, chose the order.
3. **`--trace-lp=906` in a divergent run:**
   - Both arrivals were in LP 906's chare heap when an older, cancelled arrival at the same timestamp was erased from it (`delete_pending`).
   - The next two `pop()`s returned 391 before 1031.
   - In good runs the heap held other events at that moment.
4. **The cause:**
   - `PendingHeap::erase` moves the last element into the gap. It then chose between moving it up and moving it down by timestamp alone (`elems[i]->ts <= victim->ts` → up).
   - An event with the victim's timestamp that sorts after it, on destination LP, source LP or ID, must move down. It was tried upward, stayed where it was, and sat above a child that sorts first.
   - The code dates from 2015 (Charades' original heap). It is the same kind of fault as the comparator fix of 2026-10-20 (CONTEXT.md, open issue 8): equal timestamps handled by time alone.
5. **Why only traffic, and why rarely:**
   - It needs a cancelled pending event, an equal-timestamp pair, and a particular heap layout, which depends on timing.
   - The swapped pair must also carry different data. PHOLD's events are interchangeable; traffic's carry cars, and swapping two cars gives each the other's random draws.
   - Direct sends and htram both cancel pending events, so both showed it.

**The fix:** `erase` decides by the comparator: up if the moved event sorts before the victim, otherwise down. The heap's order is total, so exactly one direction can be needed.

**Verification:**
- **8 processes × 1 PE, W 1,000:** 60 of 60 runs commit 30,302,829 events with the sequential run's digest (5d094f47e80f6250). Before the fix, 6 of 65 did not; at that rate 60 clean runs has a probability of about 0.003.
- **Mac change tier:** 152/152 on every model (bucketed, htram, the measured rule bracketed and not, sequential).
- **Engine tier:** 2,887 of 2,888, with one timeout. It is dragonfly `gentime` with `bucket_hold_early` (the PADS'19 hold, early release) at 2 processes × 2 PEs.
  - That combination hangs in 5 of 5 runs with this fix and in 5 of 5 at the parent commit (638c8b8). So it predates this fix and the other changes of this session.
  - Single-process shapes pass. Open issue: it matters for F3 if the hold baseline is run on dragonfly.

**What it changes:**
- **Rates:** none. Erase does the same work. Every rate in this file stands.
- **Traffic and dragonfly counts:** their committed counts are now deterministic on several processes. Earlier traffic counts that differed between runs are wrong, but none is quoted as a count.
- **Table T1:**
  - the paper-grade runs of traffic and dragonfly carry `--commit-digest`;
  - T1 compares digests across arms, node counts and repeats, not counts alone;
  - ROSS and Devastator are compared on counts and model statistics, as before.
- **Job N:** it runs on the fixed engine, with `--commit-digest` on traffic and dragonfly, so it checks the fix on Stampede3 at 4 and 16 nodes.

### §186 · The applications at 1–32 nodes in three engines (F5): the plan, and a calibration job at 1 and 4 nodes (design, 2026-11-02; written before any runs)

> **Status: current (design); results in section 187.** PAPER.md work item 3, moved ahead of the ablation on 2026-11-02 (user decision).
> - **Calibration job:** `$WORK/charades-runs/f5cal186.slurm` (copy in `~/charades-data/f5/`), 5 nodes; submitted 2026-11-02 as 3672846 (skx-dev) and 3672847 (skx), the later starter to be cancelled.
> - **Trees:** Charades `charades-phaseb` at e1fbdc4 (the frozen controller and the heap fix; main has only notes since); ROSS and Devastator as in job C (section 177).

**Why now.** Traffic and dragonfly have never run above 16 nodes, and claim 3 rests on them. The aggregation evidence on them so far is mixed: dragonfly gains 1.06–1.10× (section 179), and traffic as laid out sends few events across processes. The runs count as paper-grade: everything they use is already final. A change before the 2026-12-07 freeze that touches those paths reruns the cells it touches.

**What has not been measured.** Charades' best fixed W is known on both applications (dragonfly 10,000–20,000 ps, traffic 500; sections 179, 185). Nobody has swept Devastator's W or ROSS's settings on them. A1 ran three Devastator windows in every cell, chosen from PHOLD. On the applications there is nothing to choose them from, hence this job.

**The calibration job** (1-node and 4-node series side by side on 5 nodes; 2 reps; rep 2 runs the engines and the arms in reverse order):
- **Sizes:** half the paper-grade runs, as in jobs M and N.
  - Dragonfly: arrival 500 ns, generating 150,000 ns, end 160,000,000 ps; the section 175 shapes (a = 13, h = 4 at 1 node; 16, 10 at 4).
  - Traffic: 64 × 46·N, 16 cars per intersection, trip radius 3, end 6,000,000.
- **Charades** (`--localalloc` launch, `--blocked-time=1`, `--commit-digest=1`):
  - dragonfly, WPs 512: W 5,000, 10,000, 20,000, 40,000 ps and the frozen controller (`mb`); direct sends at W 10,000 and 20,000;
  - traffic, PP 2,048: W 250, 500, 1,000, 2,000 and the controller; WPs 512 at W 500; direct sends at W 500 and 1,000.
- **Devastator** (2 processes × 23 workers per node, CLCG4):
  - dragonfly: W 5,000, 10,000, 20,000, 40,000, 80,000 ps and its adaptive window;
  - traffic: W 250, 500, 1,000, 2,000, 4,000 and its adaptive window.
- **ROSS** (46 ranks per node, `--read-buffer=1`, the grouped mapping on dragonfly): conservative, and optimistic batch / GVT interval 16/64 (A0's best on PHOLD), 16/256, 4/64 and 64/64.
- **Caps:** Charades 300 s; Devastator and ROSS 240 s. An arm that hits its cap in rep 1 is skipped in rep 2.
- **Gate:** the change tier on 2 nodes, Dragonfly and Traffic, four configs including the measured controller.
- **Estimate:** 37 runs per rep and node count, about 35 minutes.

**Predictions:**
- **K1. Counts.** In each application and node count every run of every engine commits the same events, and all Charades runs share one digest.
- **K2. Charades' best fixed W:** dragonfly 10,000 or 20,000 ps at both node counts; traffic 500 at 4 nodes and 500 or 1,000 at 1.
- **K3. The frozen controller** is at least 0.93 of Charades' best fixed W in all four cells (job N: 0.95–1.03 on these two applications).
- **K4. Aggregation** (best htram ÷ best direct, higher is better): dragonfly 1.03–1.15; traffic 0.95–1.05. On traffic, PP 2,048 and WPs 512 are within 3% of each other.
- **K5. Devastator's best fixed W is 2–4× Charades'**, as on PHOLD (its 500–2,000 against 250–400): dragonfly 20,000–80,000 ps, traffic 1,000–2,000. Its best is not at a grid edge.
- **K6. Devastator's adaptive window** is at most 0.8 of its best fixed W on both applications at 4 nodes (PHOLD: 0.70–0.77 at 64 cores, collapsing on full nodes).
- **K7. ROSS:**
  - batch 16 / GVT interval 64 is within 5% of its best optimistic setting on both applications;
  - conservative is at most 0.5 of the best optimistic setting on dragonfly, whose lookahead (100 ps) is tiny against a 500 ns arrival interval;
  - on traffic (lookahead 100, mean 1,000, like σ 100 PHOLD, where conservative was ROSS's fastest) it is within 0.8–1.25 of it.
- **K8. Each engine at its best:** Charades ÷ ROSS ≥ 2 on both applications at both node counts; Charades ÷ Devastator ≥ 1.0 on both at 4 nodes.

**Rules for the scaling jobs, fixed now:**
- **Charades:**
  - the frozen controller, and the two best fixed W at 4 nodes;
  - direct sends at the better of the two (aggregation's gain on the applications);
  - htram mode: WPs 512 on dragonfly, and on traffic the better of PP 2,048 and WPs 512.
- **Devastator:**
  - its best fixed W at 4 nodes and the grid points either side (× 0.5 and × 2), moved outward if the best is at a grid edge;
  - its adaptive window only if it is its best setting in some cell here; otherwise this job is its F4 entry.
- **ROSS:** its best optimistic setting at 4 nodes, plus conservative unless that is at most 0.5 of it at both node counts.
- **Sizes:** full (section 177): dragonfly generating 300,000 ns, end 310,000,000 ps; traffic end 12,000,000. About 10 s per Charades run at the 1-node rate.

**The scaling jobs** (predictions written after this job, before they run):
- **F5a** (skx-dev, 16 nodes): the 8-, 4-, 2- and 1-node series side by side, then 16 nodes; 3 reps; the engines interleaved per rep, as in A1.
- **F5b** (skx, 32 nodes): 16 nodes on each half side by side, then 32 nodes; 5 reps at 32 (32-node reps vary by ±14%).
- **T1** from both: counts equal across the three engines in every cell, and one Charades digest per cell.

### §187 · F5 calibration results: every engine commits the same events; aggregation gains 1.36–1.38× on traffic through same-process sends; Devastator's best W is Charades' on dragonfly and 4× it on traffic; the scaling jobs' arms and predictions (2026-11-02; skx-dev batch job 3672846, 5 nodes; F5a/F5b design written before their runs)

> **Status: current (calibration) / design (F5a, F5b; F5a results in section 188, where F5b is amended).** Design and predictions in section 186.
> - **Job:** 30 minutes; gate 60/60; 146 runs (Charades 60, Devastator 48, ROSS 38). Two ROSS runs hit the 240 s cap: dragonfly at 4 nodes, optimistic 16/256 and 64/64. Both were skipped in rep 2.
> - **Data:** `~/charades-data/f5/j3672846/`; summary `~/charades-data/f5/f5cal_summary.py`.

**Dragonfly** (M committed ev/s, median of 2 reps, higher is better; in brackets each rep ÷ that engine's best fixed setting in the same rep, rep 1 / rep 2; W in ps; ROSS's optimistic arms are batch / GVT interval):

| engine | arm | 1 node | 4 nodes |
|---|---|---|---|
| Charades, WPs 512 | W 5,000 | 32.8 (0.89 / 0.87) | 88.5 (0.80 / 0.81) |
| | W 10,000 | 37.3 (1.00 / 1.00) | 108.2 (0.99 / 0.98) |
| | W 20,000 | 36.5 (1.00 / 0.96) | **109.5 (1.00 / 1.00)** |
| | W 40,000 | 27.6 (0.75 / 0.73) | 70.7 (0.63 / 0.66) |
| | the frozen controller (mean W 14,219 / 14,648) | **38.0 (1.03 / 1.00)** | 109.7 (1.01 / 1.00) |
| Charades, direct sends | W 10,000 | 35.2 (0.97 / 0.91) | 99.0 (0.91 / 0.90) |
| | W 20,000 | 33.9 (0.92 / 0.89) | 101.2 (0.92 / 0.92) |
| Devastator | W 5,000 | 37.9 (0.95 / 0.96) | 67.5 (0.80 / 0.77) |
| | W 10,000 | **39.7 (1.00 / 1.00)** | 81.3 (0.94 / 0.94) |
| | W 20,000 | 38.7 (0.98 / 0.98) | **86.3 (1.00 / 1.00)** |
| | W 40,000 | 35.5 (0.89 / 0.90) | 70.3 (0.81 / 0.82) |
| | W 80,000 | 35.9 (0.90 / 0.91) | 28.2 (0.17 / 0.49) |
| | its adaptive window | 36.4 (0.92 / 0.92) | 70.2 (0.80 / 0.83) |
| ROSS | conservative | 3.3 (0.34 / 0.34) | 7.9 (0.31 / 0.31) |
| | 4 / 64 | **9.5 (1.00 / 1.00)** | **25.8 (1.00 / 1.00)** |
| | 16 / 64 | 3.2 (0.34 / 0.33) | 8.0 (0.31 / 0.31) |
| | 16 / 256 | 0.9 (0.09 / 0.09) | capped |
| | 64 / 64 | 1.6 (0.17 / 0.17) | capped |

**Traffic** (as above; W in the model's time unit):

| engine | arm | 1 node | 4 nodes |
|---|---|---|---|
| Charades, PP 2,048 | W 250 | 55.3 (0.83 / 0.86) | 199.7 (0.76 / 0.79) |
| | W 500 | 62.6 (0.95 / 0.96) | **257.1 (1.00 / 1.00)** |
| | W 1,000 | 56.8 (0.86 / 0.88) | 227.6 (0.87 / 0.90) |
| | W 2,000 | 49.1 (0.76 / 0.74) | 188.0 (0.73 / 0.73) |
| | the frozen controller (mean W 516 / 566) | 61.4 (0.91 / 0.96) | 243.3 (0.95 / 0.94) |
| Charades, WPs 512 | W 500 | **65.5 (1.00 / 1.00)** | 241.4 (0.94 / 0.94) |
| Charades, direct sends | W 500 | 48.0 (0.74 / 0.73) | 186.0 (0.71 / 0.73) |
| | W 1,000 | 47.5 (0.72 / 0.73) | 183.6 (0.70 / 0.72) |
| Devastator | W 250 | 53.0 (0.92 / 0.92) | 179.0 (0.79 / 0.79) |
| | W 500 | 55.3 (0.96 / 0.96) | 211.8 (0.95 / 0.92) |
| | W 1,000 | 56.8 (0.99 / 0.98) | 217.7 (0.95 / 0.97) |
| | W 2,000 | **57.6 (1.00 / 1.00)** | **226.7 (1.00 / 1.00)** |
| | W 4,000 | 55.7 (0.97 / 0.97) | 207.9 (0.92 / 0.91) |
| | its adaptive window | 54.9 (0.95 / 0.95) | 69.3 (0.28 / 0.33) |
| ROSS | conservative | 34.0 (0.96 / 0.96) | 110.6 (0.92 / 0.93) |
| | 4 / 64 | 28.9 (0.82 / 0.82) | 94.9 (0.79 / 0.80) |
| | 16 / 64 | 33.8 (0.95 / 0.95) | 114.6 (0.96 / 0.97) |
| | 16 / 256 | 34.2 (0.96 / 0.97) | 112.5 (0.94 / 0.95) |
| | 64 / 64 | **35.4 (1.00 / 1.00)** | **119.1 (1.00 / 1.00)** |

**Each engine at its best fixed setting** (median M committed ev/s; Charades ÷ the other, higher is better for Charades; aggregation is Charades' best htram arm ÷ its best direct arm):

| application | nodes | Charades | Devastator | ROSS | Charades ÷ Devastator | Charades ÷ ROSS | aggregation |
|---|---|---|---|---|---|---|---|
| dragonfly | 1 | 37.3 (W 10,000) | 39.7 (W 10,000) | 9.5 (4 / 64) | 0.94 | 3.91 | 1.06 |
| | 4 | 109.5 (W 20,000) | 86.3 (W 20,000) | 25.8 (4 / 64) | 1.27 | 4.24 | 1.08 |
| traffic | 1 | 65.5 (WPs 512, W 500) | 57.6 (W 2,000) | 35.4 (64 / 64) | 1.14 | 1.85 | 1.36 |
| | 4 | 257.1 (PP 2,048, W 500) | 226.7 (W 2,000) | 119.1 (64 / 64) | 1.13 | 2.16 | 1.38 |

**What it says:**
- **Counts.** Each application and node count has one committed count across all 146 runs and the three engines, and one Charades digest. Devastator reports every run deterministic.
- **Aggregation gains 1.36–1.38× on traffic, but not by combining network messages.**
  - htram sent only 0.72% of committed events to other processes, 11–14 events per message.
  - 17.7% of committed events go to another PE, almost all in the same process. With aggregation on, `--agg-scope=0` (the default) sends these through htram too, which delivers them to the destination's input buffer instead of as one Charm++ message each.
  - With direct sends, PEs spend 43–46% of their time blocked at the window's edge, against 24–34% with htram.
  - So the gain most likely comes from the same-process path. Not tested here: `--agg-scope=1` (other processes only) would separate the two. It joins the aggregation ablation (item 4, F2), and the paper must not describe this gain as network aggregation until then.
  - **Correction (2026-11-04, section 222): the explanation above is wrong.** The local fast path (`--local-fast-path=1`, the default) hands every event for another PE of the same process over by pointer, with direct sends and with htram alike. In this job's 4-node runs at W 500, it carried 192.0 M of 200.2 M remote sends in both arms. htram carried only the 8.2 M events to other processes, in 0.69 M messages (11.9 per message), where direct sends used 8.2 M messages. So `--agg-scope=1` changes nothing on this stack, and the 1.40× (258.6 against 184.7 M ev/s at W 500) comes from aggregating the events to other processes. It is not fewer rollbacks: htram rolled back more (38,222 events against 6,514).
- **Dragonfly gains 1.06–1.08× from aggregation**, as in job D.
- **Devastator's best W:**
  - On dragonfly it equals Charades' best (10,000 ps at 1 node, 20,000 at 4). Devastator runs it at 83% efficiency at 4 nodes, against Charades' 92%.
  - On traffic it is 2,000, 4× Charades' 500.
  - A wider W hurts it more at 4 nodes: at W 80,000 on dragonfly it rolls back 3 events for every one it commits.
- **Devastator's adaptive window** reaches 0.92–0.95 of its best fixed W at 1 node. At 4 nodes it reaches 0.80–0.83 on dragonfly and 0.28–0.33 on traffic, where it runs at 53% efficiency.
- **The frozen controller:**
  - dragonfly: 1.00–1.03 of the best fixed W;
  - traffic: 0.94–1.00 of PP 2,048 at its best W;
  - traffic, 1 node: 0.91–0.96 of the best arm overall, which is WPs 512 (1.05× PP 2,048 there; at 4 nodes PP 2,048 is 1.065× WPs 512).
- **ROSS:**
  - On dragonfly, optimistic ROSS rolls back more events than it commits at batch 16 and above. Batch 4, the grid's smallest, is its best, and conservative reaches 0.31–0.34 of it.
  - On traffic, batch 64, the grid's largest, is its best, and conservative reaches 0.92–0.96.
- **Each engine at its best:**
  - Charades leads Devastator at 4 nodes on both applications (1.27, 1.13) and on traffic at 1 node (1.14).
  - Devastator leads on dragonfly at 1 node (Charades 0.94).
  - Charades leads ROSS by 3.9–4.2× on dragonfly and 1.85–2.16× on traffic.

**Predictions (section 186):**
- **K1 right.**
- **K2 right:** dragonfly 10,000 at 1 node and 20,000 at 4 (10,000 at 0.98–0.99); traffic 500 at both.
- **K3 right on dragonfly** (1.00–1.03). On traffic it is right against the same htram mode (0.94–1.00), but wrong against the best arm at 1 node (0.91 in rep 1), which is WPs 512, a mode the controller did not run with.
- **K4 half right.**
  - Dragonfly: 1.06–1.08, inside 1.03–1.15.
  - Traffic: 1.36–1.38, not 0.95–1.05.
  - PP 2,048 and WPs 512 differ by 5–6.5%, not by 3% or less.
- **K5 half right.**
  - Traffic: 2,000, 4× Charades' best W.
  - Dragonfly: equal to Charades' best W, not 2–4×.
  - Not at a grid edge: right.
- **K6 half right.**
  - Traffic at 4 nodes: 0.28–0.33.
  - Dragonfly at 4 nodes: 0.80 and 0.83, so rep 2 is above 0.8.
- **K7 mostly wrong.**
  - Batch 16 / GVT interval 64 is within 5% of the best on traffic (0.95–0.97), but only 0.31–0.34 on dragonfly.
  - The conservative parts are right: 0.31–0.34 on dragonfly, 0.92–0.96 on traffic.
- **K8 half right.**
  - Charades ÷ ROSS is 1.85 on traffic at 1 node, below 2.
  - Charades ÷ Devastator ≥ 1.0 at 4 nodes: right.

**The scaling jobs' arms** (section 186's rules applied to this job):
- **Charades, dragonfly:** WPs 512, with the controller, W 10,000 and W 20,000. Direct sends at both W, since each was direct's better W at one node count.
- **Charades, traffic:**
  - PP 2,048, with the controller, W 500 and W 1,000;
  - WPs 512 at W 500, because the better mode differs by node count;
  - direct sends at W 500.
- **Devastator:** dragonfly W 10,000, 20,000 and 40,000; traffic W 1,000, 2,000 and 4,000. Its adaptive window was never its best setting, so this job is its F4 entry on the applications.
- **ROSS:**
  - Dragonfly: optimistic 4 / 64, plus 2 / 64 because batch 4 is the grid's smallest. Conservative is dropped (0.31–0.34 at both node counts).
  - Traffic: optimistic 64 / 64, plus 128 / 64 because batch 64 is the grid's largest. Conservative is kept (0.92–0.96).
  - Extending ROSS's grid at its edge applies section 186's Devastator rule to ROSS, which the rule did not say.
- **Sizes and caps:** full sizes; caps of 300 s for every engine.

**Jobs** (`$WORK/charades-runs/f5scale187.slurm`, copy in `~/charades-data/f5/`; submitted 2026-11-02: F5a as 3673108 (skx-dev) and 3673109 (skx), the later starter to be cancelled; F5b as 3673110 (skx)):
- **F5a (`a`):** skx-dev, 16 nodes. The 8-, 4-, 2- and 1-node series run side by side, then 16 nodes alone; 3 reps. Engines are interleaved per rep, with engine and arm order reversed in even reps. About 60 minutes.
- **F5b (`big`):** skx, 32 nodes. Dragonfly and traffic at 16 nodes side by side on the two halves (3 reps), then both at 32 nodes (5 reps). About 85 minutes.

**Predictions (F5a and F5b):**
- **S1 (T1).** Each application and node count has one committed count across the three engines and one Charades digest.
- **S2. Charades ÷ Devastator,** each at its best arm:
  - dragonfly ≥ 1.2 at 4–32 nodes. From 1 to 4 nodes here, Devastator's per-node rate fell to 0.54 of its 1-node rate, Charades' to 0.73.
  - traffic 1.05–1.25 at every node count, because its cross-process share does not grow with the node count.
- **S3. Charades ÷ ROSS:** dragonfly ≥ 3.5 at every node count; traffic 1.8–2.6.
- **S4.** The frozen controller is at least 0.93 of Charades' best fixed W in the same htram mode in every cell, 32 nodes included.
- **S5. Per-node rate at 16 nodes ÷ at 1 node:**
  - Charades: dragonfly 0.55–0.75 (job N's 16 nodes against this job's 1 node: 0.63 at half size); traffic 0.85–1.0 (0.91).
  - Devastator: dragonfly ≤ 0.5.
- **S6.** From 16 to 32 nodes in the same allocation (F5b), Charades' per-node rate at 32 ÷ at 16 is at least 0.85 on both applications.
- **S7. Aggregation:** traffic ≥ 1.3 at every node count; dragonfly 1.05–1.20, rising with the node count.

**What follows:** F5 and T1 come from these two jobs, and claim 3's wording from S2 and S3. If S1 fails anywhere, the runs stop counting until the split is found on the Mac with `--commit-digest`.

### §194 · F5b results, 32 nodes: one count per cell in all three engines; on dragonfly Charades ÷ Devastator reaches 2.03 and Charades keeps 0.90 of its per-node rate from 16 to 32 nodes (Devastator 0.80); on traffic Charades leads by 1.05–1.08 and its controller follows the best W as it widens (2026-11-02; skx batch job 3673481, 32 nodes)

> **Status: current.** Design and predictions in sections 187 (S1–S7) and 188 (amendment, R1–R3). 2 h 10 min of the 2 h 40 min limit: gate 60/60; 16 nodes, dragonfly and traffic side by side on the two halves (3 reps); then 32 nodes, both applications (5 reps). Every run finished, with no failures or caps. Summary `~/charades-data/f5/f5_summary.py a_j3673108 big_j3673481 rossdf_j3673482`; data `~/charades-data/f5/big_j3673481/` (per-LP digest files left on `$WORK`).

**32 nodes** (M committed ev/s, median of 5, higher is better; Charades: its controller and its best fixed W in the same htram mode (dragonfly WPs 512, traffic PP 2,048); Devastator: best of three W; ROSS: best setting; ratios are Charades' controller ÷ the other engine's best):

| application | Charades, controller | Charades, best fixed W | Devastator, best W | ROSS, best | Charades ÷ Devastator | Charades ÷ ROSS | controller ÷ best fixed W, per rep |
|---|---|---|---|---|---|---|---|
| dragonfly | 689.6 | 663.5 (W 20,000) | 339.2 (W 20,000) | 161.9 (batch 2 / GVT 64) | 2.03 | 4.26 | 1.02 / 1.05 / 1.04 / 1.05 / 0.95 |
| traffic | 1,846.6 | 1,795.3 (W 1,000) | 1,706.1 (W 2,000) | 843.6 (batch 64 / GVT 64) | 1.08 | 2.19 | 1.03 / 0.98 / 1.09 / 1.02 / 0.99 |

**16 to 32 nodes in one allocation** (per-node rate at 32 ÷ at 16, each engine at its best (Charades: controller); 1.0 is perfect):

| application | Charades | Devastator | ROSS |
|---|---|---|---|
| dragonfly | 0.90 | 0.80 | 0.85 |
| traffic | 0.99 | 0.95 | 0.97 |

- **The 16-node half reproduces F5a's 16 nodes** within 1–3% for every engine (dragonfly: Charades 384.8 against 384.6, Devastator 211.2 against 213.7, ROSS 95.4 against 97.5; traffic: 929.9 against 929.0, 896.0 against 898.7, 435.8 against 438.5), with the same counts and digests.
- **Per-node rate at 32 nodes ÷ at 1 node** (across allocations, F5a's 1 node): dragonfly Charades 0.56, Devastator 0.26, ROSS 0.50; traffic 0.94, 0.89 and 0.73.
- **Traffic's best fixed W widens at 32 nodes:** W 1,000 beats W 500 by 1.07× (at 16 nodes W 500 led by 1.06×). The controller follows it, with a mean W of 590–766 ps against 585–648 at 16 nodes, and beats both fixed settings (1.03× the better). On dragonfly its mean W is 14,700–15,700 ps at both node counts, between the two fixed settings.
- **Aggregation** (best htram ÷ direct sends): traffic 1.35 (16 nodes) and 1.33 (32); dragonfly 1.11 and 1.07. Traffic's gain is still to be split between the same-process path and network aggregation (`--agg-scope=1`, PAPER.md item 4).
- **ROSS's best on dragonfly stays batch 2 / GVT interval 64 at 32 nodes:** batch 1 is 0.71× of it, GVT interval 16 0.53×, both 0.32×. **Caveat for every Charades ÷ ROSS ratio in F5:** no ROSS run used its fixed optimism window (`--max-opt-lookahead`, section 192). ROSS's dragonfly efficiency is 57–62%, so a window could raise ROSS's rate there.

**Predictions (sections 187 and 188), at 16 (F5b) and 32 nodes:**
- **S1 right.** One count per cell across the three engines and one Charades digest: dragonfly 13,323,722,220 (32 nodes), traffic 18,096,870,611; at 16 nodes F5a's counts and digests.
- **S2 right at 32 nodes, just short once at 16.** Dragonfly 2.03 (≥ 1.2); traffic 1.08 (1.05–1.25; 1.05 with the best fixed W). F5b's 16-node traffic cell gives 1.04 with Charades' best arm, just below 1.05 (F5a's 16 nodes: 1.06).
- **S3 right.** Dragonfly 4.03 (16) and 4.26 (32), ≥ 3.5; traffic 2.15 and 2.19, in 1.8–2.6. ROSS ran without a window (caveat above).
- **S4 right.** The controller is 0.95–1.05 of the best fixed W per rep on dragonfly and 0.95–1.10 on traffic, at both node counts (≥ 0.93).
- **S5** (16 ÷ 1 node) was graded on F5a; F5b's 16 nodes give the same values (Charades 0.62 / 0.94, Devastator dragonfly 0.32).
- **S6 right.** Charades' per-node rate 32 ÷ 16 is 0.90 (dragonfly) and 0.99 (traffic), ≥ 0.85.
- **S7 half right.** Traffic 1.35 / 1.33 (≥ 1.3); dragonfly 1.11 / 1.07, in 1.05–1.20 but falling from 16 to 32 nodes, not rising.
- **R1 wrong at 32 nodes too:** batch 1 is 0.71× of batch 2, not ≥ 1.1×.
- **R2 wrong:** GVT interval 16 is 0.53× of 64 at batch 2.
- **R3 right:** Charades ÷ ROSS on dragonfly is 4.03 / 4.26, ≥ 2.5.

**Consequences:**
- F5 and T1 are complete for traffic and dragonfly at 1–32 nodes. Charades leads Devastator from 2 nodes on (dragonfly 1.04 → 2.03) and at every node count on traffic (1.02–1.08 with the controller). ROSS trails by 1.7–4.3×.
- The VLSI cells wait on V1 (section 193).
- Before the paper quotes Charades ÷ ROSS, ROSS needs a `--max-opt-lookahead` arm on dragonfly and traffic. The user has not yet decided whether a job gets it.

### §248 · F5a2 results: traffic and dragonfly at 1–16 nodes without diagnostics. Charades ÷ Devastator (controller) is 1.24–1.28 on traffic and 1.08–2.04 on dragonfly; dropping the log raised traffic's controller 1.01–1.04×, and the other diagnostics cost 0–1.6% (2026-11-06; skx-dev batch job 3690453, 16 nodes)

> **Status: current for traffic and dragonfly at 1–16 nodes.** Design and predictions in section 247. This replaces section 244 in the paper table.
> - **Job:** 1 h 4 min of the 1 h 55 min limit. Gate 60/60. The guard cancelled the skx copy 3690454 when this copy started.
> - **Runs:** 245 Charades, 90 Devastator, 90 ROSS; none failed.
> - **Data:** `~/charades-data/f1/scale240/f5a_j3690453/`.
> - **Summary:** `~/charades-data/f1/f5_247_summary.py`, run on this job and section 244's (`scale240/f5a_j3689887`); output `scale240/f5a_j3690453_summary.txt`.
>   - It keeps the check arms out of every timing comparison.
>   - It recomputes section 244's ratios from the same rate column, so they differ from that section by at most 0.01.
> - **Counts and digests (D1, right):** one count per cell in all three engines; one Charades digest per cell across the od and dg arms and reps, the same digests as section 244.

**Charades ÷ Devastator and Charades ÷ ROSS** (Charades' controller ÷ the other engine's best arm; median of 3 reps; higher is better). Section 244, with the log, is in brackets:

| application, ratio | 1 node | 2 | 4 | 8 | 16 |
|---|---|---|---|---|---|
| dragonfly, ÷ Devastator | 1.08 (1.08) | 1.18 (1.18) | 1.46 (1.45) | 1.91 (1.70) | 2.04 (2.00) |
| dragonfly, ÷ ROSS | 3.11 (3.10) | 2.93 (2.91) | 3.04 (3.04) | 3.13 (3.07) | 3.03 (2.97) |
| traffic, ÷ Devastator | 1.27 (1.25) | 1.25 (1.22) | 1.24 (1.19) | 1.26 (1.19) | 1.28 (1.23) |
| traffic, ÷ ROSS | 1.85 (1.82) | 1.97 (1.92) | 2.04 (1.96) | 2.09 (2.01) | 2.21 (2.11) |

**Dragonfly at 8 nodes:** Devastator's W 20,000 ran 53–54 s in 2 of its 3 reps instead of about 24 s, with the same executed events. So its median there falls to 62 M ev/s, and its best arm by median becomes W 10,000 (122.1). Against its fastest W 20,000 rep (137.1), Charades ÷ Devastator is 1.70, as in section 244.

**Per application** (M committed ev/s, median of 3, higher is better; per-node rate at 16 ÷ at 1 node, 1.0 is perfect):

| application | M ev/s at 16 nodes, Charades / Devastator / ROSS | per-node rate 16 ÷ 1, Charades / Devastator / ROSS | controller ÷ best fixed W in its htram setting, per rep (higher is better) |
|---|---|---|---|
| dragonfly | 433.2 / 212.8 / 142.8 | 0.61 / 0.33 / **0.63** | 0.985–0.995 at 1 node; 1.015–1.063 at 2–16 |
| traffic | 1,161.1 / 904.9 / 526.5 | **0.96** / 0.95 / 0.80 | 0.956–1.005 at 1–8 nodes; 1.034–1.078 at 16 |

(Bold: the best of the three engines.)

**Check arms ÷ the same fixed arm** (traffic PP 2,048 W 500, dragonfly WPs 512 W 10,000; paired per rep; the range of the per-node-count medians, with the per-rep range in brackets; higher means the flag costs less):

| arm | flags | dragonfly | traffic |
|---|---|---|---|
| od | `--blocked-time=1 --commit-digest=1` (the old set) | 0.987–1.002 (0.979–1.018) | 0.984–0.999 (0.980–1.011) |
| dg | `--commit-digest=1` | 0.995–1.007 (0.976–1.019) | 0.989–0.996 (0.983–1.016) |
| ri | `--report-interval=1000000` | 0.993–1.009 (0.985–1.026) | 0.998–1.007 (0.979–1.012) |

**Each engine's rate ÷ its own in section 244's job** (1.0 is unchanged):
- **Charades' controller:** dragonfly 0.99–1.01, traffic 1.01–1.04.
- **Charades' best fixed arm:** 0.98–1.02.
- **Devastator:** 0.98–1.02, except dragonfly at 8 nodes (0.90, the slow reps above).
- **ROSS:** 0.98–1.02.

**What the job shows:**
- **Dropping the log helped traffic's controller.**
  - It ran 1.01–1.04× faster, while the fixed arms ran 0.98–1.02×. On dragonfly, which makes fewer controller rounds a second, the controller ran 0.99–1.01×. This matches section 246.
  - So Charades ÷ Devastator on traffic rises from 1.19–1.25 to 1.24–1.28.
- **The other diagnostics cost little.**
  - With them on, the fixed arms ran at 0.984–1.002 (medians), the most on traffic at 16 nodes (0.984–0.987 per rep). The digest alone and the GVT progress print are within the spread between reps.
  - So the earlier jobs that carried them understated Charades against the other engines by at most about 1.5%.
- **The controller:**
  - On traffic it runs at 0.956–1.005 of W 500 at 1–8 nodes (section 246: 0.977 at 1 node) and 1.034–1.078 at 16 nodes, where the best W is above 500 (section 246: 750).
  - On dragonfly it runs at 1.015–1.063 at 2–16 nodes and 0.985–0.995 at 1 node.
- **Per-node rate from 1 to 16 nodes:** Charades is best on traffic now (0.96 against Devastator's 0.95), and second to ROSS on dragonfly (0.61 against 0.63).
- **Devastator's slow reps** now appear in two cells: traffic W 1,000 at 16 nodes in section 244, and dragonfly W 20,000 at 8 nodes here. Each time 2 of 3 reps ran 2.2–3.5× long with the same executed events. The cause is not known. Every engine's cells use medians, and where this hits Devastator's best arm the table also gives the ratio against its fastest rep.

**Predictions:**
- **D1: right.**
- **D2: right within the spread.**
  - The old set costs 0–1.6% (predicted at most 2%).
  - The digest alone is 0.989–0.996 on traffic, at the predicted 0.99 bound.
  - Without the progress print, 0.993–1.009, against the predicted 1.00–1.01.
- **D3: mostly right.**
  - Traffic 0.956–1.078 against 0.95–1.07: 16 nodes rep 2 is above.
  - Dragonfly 0.985–1.063 against 1.00–1.06: 1 node is below, 16 nodes rep 1 above.
- **D4: mostly right.**
  - Charades ÷ Devastator (controller) is 1.02–1.06× section 244's on traffic and 1.00–1.02× on dragonfly, inside the predicted 1.00–1.08.
  - The exception is dragonfly at 8 nodes, 1.12×, from Devastator's slow reps.
  - With Charades' best fixed arm, 0.99–1.02× except that cell.
- **D5: mostly right.** ROSS is within 2% and Devastator within 2%, except dragonfly at 8 nodes (0.90).

**What follows:**
- **The paper's traffic and dragonfly rows at 1–16 nodes** come from this job. At dragonfly 8 nodes the table gives both ratios (1.91 by median, 1.70 against Devastator's fastest rep).
- **The fixed-W, Devastator and ROSS results of F4, ABL and F3R stand,** within the 1.5% above. Their controller rows carry the log's cost: up to 6% where controller rounds are frequent (traffic; PHOLD at 16 nodes), 0–1% on dragonfly.
- **F4** is decided once VA shows the effect on VLSI.

## Earlier

Superseded or historical sections, in the order they were written. Their numbers came from an older stack, launch or setting, or a later section replaced them; each says which.

### §188 · F5a results, 1–16 nodes: every cell commits one count in all three engines; on dragonfly Charades' lead over Devastator grows from 0.94 to 1.80 with node count; on traffic both scale at 0.94 and Charades leads by 1.06–1.11; ROSS's dragonfly grid is extended again before F5b (2026-11-02; skx-dev batch job 3673108, 16 nodes; F5b amendment and F5c design written before their runs)

> **Superseded (2026-11-07):** the paper table now comes from §244, then §248.

> **Status: current (F5a) / design (F5b amended, F5c).** Design and predictions in section 187.
> - **Job:** 61 minutes (skx copy 3673109 cancelled); gate 60/60.
> - **Runs:** 315, all finished: Charades 150 plus 5 warm-up runs, Devastator 90, ROSS 75. None hit a cap.
> - **Data:** `~/charades-data/f5/a_j3673108/`; summary `~/charades-data/f5/f5_summary.py`.

**Dragonfly** (M committed ev/s, median of 3 reps, higher is better; "÷" columns are Charades' controller ÷ the other engine at its best setting, higher is better for Charades; the controller column is the controller ÷ the best fixed W in its htram mode, per rep):

| nodes | Charades, controller | Charades, best fixed W | Devastator, best W | ROSS, best (batch / GVT interval) | ÷ Devastator | ÷ ROSS | controller ÷ best fixed W | aggregation (best htram ÷ best direct) |
|---|---|---|---|---|---|---|---|---|
| 1 | 38.7 | 38.6 (10,000) | 41.1 (10,000) | 10.2 (2 / 64) | 0.94 | 3.80 | 1.01 / 0.93 / 1.01 | 1.06 |
| 2 | 66.7 | 63.8 (20,000) | 64.4 (20,000) | 18.1 (4 / 64) | 1.04 | 3.69 | 1.03 / 1.03 / 1.02 | 1.03 |
| 4 | 112.2 | 110.7 (20,000) | 87.1 (20,000) | 27.8 (2 / 64) | 1.29 | 4.03 | 1.01 / 1.04 / 1.01 | 1.10 |
| 8 | 209.4 | 206.8 (10,000) | 138.6 (20,000) | 52.2 (2 / 64) | 1.51 | 4.01 | 1.02 / 1.01 / 1.02 | 1.12 |
| 16 | 384.6 | 374.4 (20,000) | 213.7 (20,000) | 97.5 (2 / 64) | 1.80 | 3.94 | 1.04 / 1.01 / 1.03 | 1.10 |

**Traffic** (as above; Charades' controller runs with PP 2,048, and its column compares it with PP 2,048's best fixed W):

| nodes | Charades, controller | Charades, best fixed | Devastator, best W | ROSS, best | ÷ Devastator | ÷ ROSS | controller ÷ best fixed W | aggregation |
|---|---|---|---|---|---|---|---|---|
| 1 | 61.5 | 66.5 (WPs 512, W 500) | 59.7 (2,000) | 36.3 (64 / 64) | 1.03 | 1.70 | 0.90 / 0.98 / 0.95 | 1.34 |
| 2 | 122.1 | 124.2 (WPs 512, W 500) | 116.6 (1,000) | 61.3 (64 / 64) | 1.05 | 1.99 | 0.95 / 0.99 / 0.95 | 1.29 |
| 4 | 234.4 | 244.6 (PP 2,048, W 500) | 230.0 (2,000) | 117.6 (64 / 64) | 1.02 | 1.99 | 0.97 / 0.96 / 0.94 | 1.36 |
| 8 | 462.6 | 482.8 (PP 2,048, W 500) | 444.1 (2,000) | 226.3 (64 / 64) | 1.04 | 2.04 | 0.96 / 1.01 / 0.95 | 1.35 |
| 16 | 929.0 | 949.5 (PP 2,048, W 500) | 898.7 (2,000) | 438.5 (64 / 64) | 1.03 | 2.12 | 0.98 / 0.97 / 0.98 | 1.35 |

With Charades' best fixed setting instead of its controller, Charades ÷ Devastator on traffic is 1.11, 1.06, 1.06, 1.09 and 1.06.

**Per-node rate ÷ the 1-node rate** (weak-scaling efficiency; each engine at its best, Charades with its controller; higher is better):

| application | engine | 2 nodes | 4 | 8 | 16 |
|---|---|---|---|---|---|
| dragonfly | Charades | 0.86 | 0.73 | 0.68 | 0.62 |
| | Devastator | 0.78 | 0.53 | 0.42 | 0.32 |
| | ROSS | 0.89 | 0.68 | 0.64 | 0.60 |
| traffic | Charades | 0.99 | 0.95 | 0.94 | 0.94 |
| | Devastator | 0.98 | 0.96 | 0.93 | 0.94 |
| | ROSS | 0.85 | 0.81 | 0.78 | 0.76 |

**What it says:**
- **T1 holds at 1–16 nodes.** Each of the 10 cells has one committed count across Charades, Devastator and ROSS, and one Charades digest. Devastator reports every run deterministic.
- **Dragonfly: Charades scales better than Devastator.**
  - At 1 node Devastator is faster (Charades 0.94). From 2 nodes Charades leads, and the lead grows: 1.04, 1.29, 1.51, 1.80.
  - Devastator's per-node rate falls to 0.32 of its 1-node rate at 16 nodes, Charades' to 0.62.
  - On this application the gap is scaling, not per-event cost.
- **Traffic: both engines scale almost perfectly** (0.94 at 16 nodes).
  - Charades leads by 1.06–1.11 at its best fixed setting and by 1.02–1.05 with its controller.
  - Its lead comes from the same-process path that section 187 found (aggregation 1.29–1.36×), and the lead stays level with node count.
- **The controller:**
  - On dragonfly it beats every fixed W at 2–16 nodes (1.01–1.04), where the best fixed W moves between 10,000 and 20,000.
  - On traffic it is 0.90–1.01 of PP 2,048's best W, and 0.92 of WPs 512's at 1 node.
- **ROSS on dragonfly is not yet at its best.**
  - Batch 2 ÷ batch 4 (GVT interval 64) is 1.01, 0.95, 1.09, 1.57 and 1.88 at 1, 2, 4, 8 and 16 nodes.
  - Batch 2 is again the grid's smallest, and its gain grows with node count, so the Charades ÷ ROSS figures on dragonfly above are upper bounds.
  - On traffic ROSS's grid is settled: batch 128 is 0.56–0.89 of batch 64.

**Predictions (section 187), at 1–16 nodes:**
- **S1 right.**
- **S2 right** with Charades' best arm: dragonfly 1.29–1.80 at 4–16 nodes; traffic 1.06–1.11. With the controller, traffic is 1.02–1.05.
- **S3:**
  - traffic right: 1.83–2.17 with Charades' best arm;
  - dragonfly 3.69–4.03 meets ≥ 3.5, but ROSS's grid is unsettled (see above).
- **S4 half right:**
  - dragonfly 0.93–1.04;
  - traffic 0.90 in rep 1 at 1 node, and 0.94–1.01 elsewhere.
- **S5 right:**
  - Charades: dragonfly 0.62, traffic 0.94;
  - Devastator: dragonfly 0.32.
- **S7 half right:**
  - traffic: 1.29 at 2 nodes, just below 1.3, and 1.34–1.36 elsewhere;
  - dragonfly: 1.03–1.12, below 1.05 at 2 nodes and not rising steadily.

**Amendment before F5b runs: ROSS on dragonfly gets batch 1 and GVT interval 16.**
- **Why:** section 187 extended ROSS's grid at its edge (batch 2 added to batch 4), and the new edge won by up to 1.88×. Applying the same rule again gives batch 2 and 1 × GVT interval 64 and 16. Batch 4 is dropped, since batch 2 is 1.09–1.88× faster at 4–16 nodes.
- **F5b** (32 nodes) had not started (pending, reason Priority, no start estimate). It is cancelled and resubmitted with ROSS on dragonfly running those four settings. Nothing else changes, and the time limit becomes 2 h 40 min.
- **F5c** (`f5scale187.slurm rossdf`, skx-dev, 16 nodes) runs ROSS only, on dragonfly, with the same four settings at 1–16 nodes (8-, 4-, 2- and 1-node series side by side, then 16; 3 reps; about 35 minutes).
- **ROSS's dragonfly entry in each cell** is its best setting over F5a and F5c.
- **Submitted 2026-11-02:** F5b as 3673481 (skx; 3673110 cancelled while pending); F5c as 3673482 (skx-dev) and 3673483 (skx), the later starter to be cancelled.

**Predictions (F5c and F5b's ROSS runs):**
- **R1.** Batch 1 is at least 1.1× batch 2 (GVT interval 64) at 8, 16 and 32 nodes.
- **R2.** At batch 2, GVT interval 16 is within ±10% of GVT interval 64.
- **R3.** With ROSS at its best of the four, Charades ÷ ROSS on dragonfly stays at least 2.5 at every node count.

### §189 · F5c results: ROSS's best on dragonfly is batch 2 / GVT interval 64; batch 1 and GVT interval 16 are slower; Charades ÷ ROSS stays 3.7–4.0 (2026-11-02; skx-dev batch job 3673482, 16 nodes)

> **Superseded (2026-11-07):** the paper table now comes from §244.

> **Status: current.** Design and predictions in section 188 (amendment). 49 minutes, 60 ROSS runs, all finished (skx copy 3673483 cancelled). Data `~/charades-data/f5/rossdf_j3673482/`.

**ROSS on dragonfly** (M committed ev/s, median of 3, higher is better; batch / GVT interval; Charades ÷ ROSS uses Charades' controller from F5a and ROSS's best over F5a and F5c):

| nodes | 4 / 64 (F5a) | 2 / 64 (F5a / F5c) | 1 / 64 | 2 / 16 | 1 / 16 | Charades ÷ ROSS |
|---|---|---|---|---|---|---|
| 1 | 10.1 | 10.2 / 9.8 | 7.5 | 6.5 | 4.5 | 3.80 |
| 2 | **18.1** | 17.2 / 17.1 | 12.9 | 10.7 | 7.0 | 3.69 |
| 4 | 25.4 | 27.8 / **28.5** | 21.6 | 17.2 | 11.2 | 3.94 |
| 8 | 33.2 | **52.2** / 51.9 | 38.4 | 29.1 | 18.6 | 4.01 |
| 16 | 51.8 | **97.5** / 96.7 | 73.2 | 54.1 | 34.0 | 3.94 |

- **Batch 2 / GVT interval 64 is ROSS's best**, and the grid now brackets it in batch: batch 1 is 0.74–0.77× of it at every node count, batch 4 is 0.53–0.91× from 4 nodes up. ROSS's efficiency at 16 nodes is 57–62% at every setting.
- **Shorter GVT intervals lose:** 16 is 0.55–0.63× of 64 at batch 2.
- **The two allocations agree:** batch 2 / 64 within 3% between F5a and F5c.
- **Not yet bracketed:** GVT interval 256 was tried only at batch 16 (section 187: 0.09–0.27× of 64 there). It joins the next skx-dev job as one extra ROSS arm (batch 2 / 256 at 4 and 16 nodes) rather than a job of its own.

**Predictions (section 188):**
- **R1 wrong:** batch 1 is 0.74–0.77× of batch 2, not ≥ 1.1×.
- **R2 wrong:** GVT interval 16 is 0.55–0.63× of 64, not within ±10%.
- **R3 right:** Charades ÷ ROSS on dragonfly is 3.69–4.01.

F5b (32 nodes, still queued) runs the same four ROSS settings; it confirms them at 32 nodes at a cost of about 25 minutes of its allocation.

### §244 · F5a results: traffic and dragonfly at 1–16 nodes on the final defaults. Charades leads Devastator in all 10 cells (dragonfly 1.08–2.00, traffic 1.19–1.25), and ROSS with its window by 2.90–3.10 (dragonfly) and 1.82–2.11 (traffic); one count and one Charades digest per cell (2026-11-06; skx-dev batch job 3689887, 16 nodes)

> **Superseded (2026-11-07):** the paper table now comes from §248.

> **Status: current for traffic and dragonfly at 1–16 nodes.** Design and predictions in section 240. It replaces F5a (section 188) and F5c's ROSS (section 189) in the paper table; the 32-node column comes from F5-32.
> - **Job:** 56 min of the 1 h 55 min limit. Gate 60/60. The guard cancelled the skx copy 3688915 when this copy started. The 8-, 4-, 2- and 1-node series ran side by side (18:40–19:05), then 16 nodes (19:05–19:32).
> - **Runs:** every run finished.
> - **Data:** `~/charades-data/f1/scale240/f5a_j3689887/`.
> - **Summary:** `~/charades-data/f5/f5_summary.py`, run on this job and the old F5a (`~/charades-data/f5/a_j3673108`); output `~/charades-data/f1/scale240/f5a_j3689887_summary.txt`.
> - **Counts and digests (C1):** every cell commits one count in all three engines and has one Charades digest across arms and reps.

**Charades ÷ Devastator and Charades ÷ ROSS** (Charades' controller ÷ the other engine's best arm; median of 3 reps; higher is better). The old F5a is in brackets; ROSS ran without its window there:

| application, ratio | 1 node | 2 | 4 | 8 | 16 |
|---|---|---|---|---|---|
| dragonfly, ÷ Devastator | 1.08 (**0.94**) | 1.18 (1.04) | 1.45 (1.29) | 1.70 (1.51) | 2.00 (1.80) |
| dragonfly, ÷ ROSS | 3.10 (3.80) | 2.90 (3.69) | 3.04 (4.03) | 3.07 (4.01) | 2.97 (3.94) |
| traffic, ÷ Devastator | 1.25 (1.03) | 1.22 (1.05) | 1.19 (1.02) | 1.20 (1.04) | 1.23 (1.03) |
| traffic, ÷ ROSS | 1.82 (1.70) | 1.92 (1.99) | 1.96 (1.99) | 2.01 (2.04) | 2.11 (2.12) |

(Bold: below 1.)

**Per application** (rates in M committed ev/s, median of 3, higher is better; per-node rate at 16 ÷ at 1 node, 1.0 is perfect):

| application | M ev/s at 16 nodes, Charades / Devastator / ROSS | per-node rate 16 ÷ 1, Charades / Devastator / ROSS | controller ÷ best fixed W in its htram setting, per rep (higher is better) | best htram ÷ best direct, Charades fixed W (higher is better) |
|---|---|---|---|---|
| dragonfly | 427.4 / 213.9 / 144.1 | 0.61 / 0.33 / **0.64** | 0.99–1.03 | 1.08–1.13 |
| traffic | 1,114.3 / 904.0 / 528.0 | 0.95 / **0.96** / 0.82 | 0.93–1.06 | 1.42–1.45 |

(Bold: the best of the three engines.)

**Each engine's best rate ÷ its own in the old F5a** (1.0 is unchanged):

| application | Charades (controller) | Devastator | ROSS (now with its window) |
|---|---|---|---|
| dragonfly | 1.11–1.13 | 0.98–1.00 | 1.38–1.50 |
| traffic | 1.16–1.20 | 0.98–1.02 | 1.11–1.21 |

**What the job shows:**
- **Charades leads Devastator in all 10 cells.**
  - The old F5a trailed only on dragonfly at 1 node (0.94); it is now 1.08.
  - Charades is 1.11–1.20× faster than in the old F5a, and Devastator is unchanged. The old F5a (2026-11-02) already had `--localalloc` and per-LP rollback; round 3 (sections 213–217) came after it.
- **ROSS's window is worth what jobs ABL and F3R found** (sections 223, 225): 1.38–1.50× on dragonfly, 1.11–1.21× on traffic.
  - So Charades ÷ ROSS on dragonfly falls from 3.69–4.03 to 2.90–3.10.
  - On traffic it moves within ±0.12 (1.82–2.11), since Charades gained about as much as ROSS.
  - ROSS's best window is 5,000 ps on dragonfly at 2–16 nodes (2,500 at 1 node; 7,500 is always the worst of the three), and 1,000 (1–2 nodes) or 2,000 (4–16) on traffic. Its conservative arm is never best.
- **Per-node scaling from 1 to 16 nodes** is close between the leaders.
  - On dragonfly, ROSS keeps 0.64 against Charades' 0.61 and Devastator's 0.33.
  - On traffic, Devastator keeps 0.96 against Charades' 0.95.
  - Charades' 1-node rate gained more than its 16-node rate (1.13 against 1.11 on dragonfly, 1.19 against 1.20 on traffic), so its per-node ratio is slightly lower than in the old F5a (0.62 and 0.94).
- **The controller:**
  - On dragonfly its mean W is 14,300–16,100 ps, between the two fixed arms (10,000 and 20,000), and it beats both at 2–16 nodes.
  - On traffic its mean W is 504–506 at 1 node and 531–736 at 2–16; W 500 is the best fixed arm at 1–8 nodes.
  - At 1 node it holds W 500 and still runs at 0.93–0.96 of fixed W 500 per rep: the same pattern as on PHOLD (sections 242–243), where it sits at the best fixed W's value but runs a few percent slower. What costs it is not measured.
- **Aggregation** (best htram ÷ best direct, both at fixed W) is 1.42–1.45 on traffic and 1.08–1.13 on dragonfly (old: 1.29–1.36 and 1.03–1.12).
- **Devastator's traffic at W 1,000 on 16 nodes:** 2 of its 3 reps ran 3.5× long (37–38 s against about 10 s), with the same executed events and almost no rollbacks. In the old F5a all three ran about 10 s. W 1,000 is not Devastator's best arm there (W 2,000, 904 M ev/s in every rep), so no ratio changes. The cause is not known.

**Predictions:**
- **C1 (traffic and dragonfly, 1–16 nodes): right.** One count per cell in all three engines, one Charades digest per cell.
- **C7: mostly right.**
  - Charades ÷ Devastator is 1.11–1.15× the old F5a's on dragonfly and 1.15–1.21× on traffic, against the predicted 0.95–1.20. 9 of 10 cells are in range; traffic at 1 node is just above, at 1.21.
  - Charades ÷ ROSS with its window is 2.90–3.10 on dragonfly (2.6–3.6 predicted) and 1.82–2.11 on traffic (1.5–2.2 predicted): right.

**What follows:**
- **Traffic and dragonfly at 1–16 nodes are paper-grade** on 85a2aad: this table replaces the old F5a in the paper.
- **The applications table at the top of this file** is rewritten when F5-32 adds the 32-node column. Until then, the note above it points here.
- **The controller's cost at the best fixed W's value** (PHOLD and traffic) is now seen in three workloads. Its robustness numbers are unaffected, and section 240's plan has no run for it.
