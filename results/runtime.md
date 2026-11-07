# Runtime, transport and the machine

Reconverse builds and settings, native psm2 through LCI, LCI devices, the late-rank investigation, the message pool, NUMA balancing, shared memory between processes, and the slow node. Part of the Charades results: the current paper tables are on the front page, [../RESULTS.md](../RESULTS.md), and every section's date, job, status and file is in [INDEX.md](INDEX.md). Sections keep the numbers (§N) they had in the single RESULTS.md they came from (split 2026-11-07); "section N" anywhere means §N.

| § | date | status | section |
|---|---|---|---|
| 26 | 2026-10-22 | current | Native psm2 through a patched LCI (2026-10-22, idev jobs 3628343 (2 nodes) and 3628358 (4 nodes)) |
| 81 | 2026-10-25 | design | The allocator behind `--agg-pp-limit`'s gain; the slow node in both engines; where a wider window's cost goes |
| 82 | 2026-10-25 | current | The allocator, the slow node in both engines, a wider window's cost, results: c455-081 is slow only with th… |
| 85 | 2026-10-25 | design | What rank 0 does while it is late: wave-aligned timers and a per-thread perf profile |
| 86 | 2026-10-25 | current | What rank 0 does while it is late, results: nothing extra on average; ranks 0 and 1 are late as a pair |
| 87 | 2026-10-26 | design | Late ranks 0 and 1: the LCI device they poll, or the PSM2 receive thread? |
| 88 | 2026-10-26 | current | Late ranks, results: rank 0 is late at every device count; rank 1 only because it shares rank 0's device; 2… |
| 89 | 2026-10-26 | design | Is rank 0 preempted? Per-thread scheduler statistics; and 23 devices at 16 nodes |
| 90 | 2026-10-26 | current | Rank 0 takes page faults, not preemption; 23 devices is 1.21× at 16 nodes |
| 91 | 2026-10-26 | design | Rank 0's page faults: where from, and do malloc settings stop them? And Charades (23 devices) against Devas… |
| 92 | 2026-10-26 | current | Results: malloc settings 1.06–1.08×, but rank 0's faults come from system calls; Charades ahead of Devastat… |
| 93 | 2026-10-26 | design | Rank 0's system calls; and the 1/4/16-node series on 23 devices, with glibc no-trim at 16 nodes |
| 94 | 2026-10-26 | current | Rank 0's system calls, results: not the cause |
| 95 | 2026-10-26 | current | 1/4/16 nodes on 23 devices, results: Charades leads in 22 of 24 cells; glibc no-trim is 1.055× for Charades… |
| 96 | 2026-10-26 | design | Rank 0's faults: perf against /proc in the same run, a lighter sampler, and memory bound to the socket |
| 97 | 2026-10-26 | current | Rank 0's faults, results: an artifact of my /proc sampler; rank 0 is late without it, and takes one shared… |
| 98 | 2026-10-26 | design | Naming the lock rank 0 takes 10× as often |
| 99 | 2026-10-26 | current | The lock, results: Reconverse's per-PE message pool, fought over by the process-edge ranks because each one… |
| 100 | 2026-10-26 | design | Late rank 0: edge traffic or the rank? Rotated LP blocks, and sending on the destination PE's device |
| 101 | 2026-10-26 | current | Late rank 0, results: the lateness follows the lower-edge LPs, not the rank or the device; sending on the d… |
| 112 | 2026-10-27 | design | Freeing another PE's message without its pool lock (`+mempool_remote_free`) |
| 113 | 2026-10-27 | current | `+mempool_remote_free`, results: freeing a received message 1.45 → 0.30 µs; uniform 1.02–1.06× at 16 nodes;… |
| 114 | 2026-10-27 | current | Correctness gate for `+mempool_remote_free`, rerun with the psm2 transport |
| 133 | 2026-10-28 | design | Where an htram message's 2.9 µs goes: htram, Charm++, Reconverse and LCI |
| 134 | 2026-10-28 | current | An htram message's cost, results: 92–95% is the LCI backend's send call, which polls the network after ever… |
| 135 | 2026-10-28 | design | The post and the network poll inside each send, and skipping the poll (`+lci_send_progress 0`) |
| 136 | 2026-10-28 | current | The poll inside each send, results: it does useful work; skipping it costs uniform 6% on 16 nodes, and the… |
| 154 | 2026-10-29 | design | Section 153's start-up transient is a slow cross-process reduction, in episodes of seconds; a diagnostic job |
| 155 | 2026-10-29 | current | Job E16, 16 nodes, results: no reduction stretch at 16 nodes; σ 2,000's start-up ramp is in the PEs' user-s… |
| 162 | 2026-10-30 | current | Job E results: no start-up stretch this time; TLB-shootdown bursts at a fixed process age cost 0.26–0.60 s… |
| 163 | 2026-10-30 | design | Are the TLB-shootdown bursts automatic NUMA balancing, and does turning it off for our processes remove the… |
| 164 | 2026-10-30 | current | Job N16 results: the TLB-shootdown bursts are automatic NUMA balancing; keeping it away from our processes… |
| 165 | 2026-10-30 | design | Job N32: `numactl --localalloc` at 32 nodes for Charades and Devastator, the controller with per-LP rollbac… |
| 166 | 2026-10-31 | current | Job N32 results: at 32 nodes keeping NUMA balancing away gains 1.060× (σ 100), 1.124× (σ 2,000) and 1.028×… |
| 205 | 2026-11-03 | current | Shared memory between processes, rewritten in Reconverse: 2 × 23 with the pool is 1.38× 2 × 23 over LCI, 0.… |
| 218 | 2026-11-04 | design | The shared-memory pool rewrite as a Reconverse pull request: Stampede3 tests against Reconverse main |
| 219 | 2026-11-04 | current | SHMPR results: the branch's pool is 2.1× main's on VLSI at 2 × 23 over `+ipc` (2.3× on 2 nodes), 1.17× on u… |
| 220 | 2026-11-04 | design | Reconverse PR #319 after review: the counter for full segments, the default segment size, and a check for s… |
| 221 | 2026-11-04 | current | SHMPR2 results: Charades never fills a segment; VLSI's busiest segment peaks at 4.0–4.2 MiB of 8 MiB at bot… |
| 0 | 2026-10-19 | historical | QD poll fix on the Mac |
| 21 | 2026-10-21 | historical | Production runtime build |
| 22 | 2026-10-21 | historical | Runtime settings on the production build |
| 25 | 2026-10-21 night | superseded | Runtime tuning |

## Current

Current findings, and designs with their results, in the order they were written.

### §26 · Native psm2 through a patched LCI (2026-10-22, idev jobs 3628343 (2 nodes) and 3628358 (4 nodes))

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

### §81 · The allocator behind `--agg-pp-limit`'s gain; the slow node in both engines; where a wider window's cost goes (design, 2026-10-25; written before any runs)

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

### §82 · The allocator, the slow node in both engines, a wider window's cost, results: c455-081 is slow only with the network, and it hurts Devastator more (2026-10-25; skx-dev batch job 3639812)

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

### §85 · What rank 0 does while it is late: wave-aligned timers and a per-thread perf profile (design, 2026-10-25; written before any runs)

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

### §86 · What rank 0 does while it is late, results: nothing extra on average; ranks 0 and 1 are late as a pair (2026-10-25; skx-dev batch job 3640203, 4 nodes)

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

### §87 · Late ranks 0 and 1: the LCI device they poll, or the PSM2 receive thread? (design, 2026-10-26; written before any runs)

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

### §88 · Late ranks, results: rank 0 is late at every device count; rank 1 only because it shares rank 0's device; 23 devices is 1.03–1.07× faster (2026-10-26; skx-dev batch job 3641728, 4 nodes)

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

### §89 · Is rank 0 preempted? Per-thread scheduler statistics; and 23 devices at 16 nodes (design, 2026-10-26; written before any runs)

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

### §90 · Rank 0 takes page faults, not preemption; 23 devices is 1.21× at 16 nodes (2026-10-26; skx-dev batch jobs 3641766, 4 nodes, and 3641785, 16 nodes)

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

### §91 · Rank 0's page faults: where from, and do malloc settings stop them? And Charades (23 devices) against Devastator at 16 nodes, same allocation (design, 2026-10-26; written before any runs)

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

### §92 · Results: malloc settings 1.06–1.08×, but rank 0's faults come from system calls; Charades ahead of Devastator in all 8 workloads at 16 nodes (2026-10-26; skx-dev batch jobs 3641910, 4 nodes, and 3641926, 16 nodes)

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

### §93 · Rank 0's system calls; and the 1/4/16-node series on 23 devices, with glibc no-trim at 16 nodes (design, 2026-10-26; written before any runs)

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

### §94 · Rank 0's system calls, results: not the cause (2026-10-26; skx-dev batch job 3642143, 4 nodes)

> **Status: current.** Design and predictions in section 93 (job E). 4 nodes (c455-081 excluded), 10 runs, all ok; strace output 106 MB in `$WORK/charades-runs/sdiag8/j3642143/`. Summary `~/charades-data/sdiag/sdiag8_summary.py`, output `~/charades-data/sdiag/j3642143/summary.txt`. Job F is still queued.

- **E1 wrong.** Over the whole run rank 0 makes 19–31× as many system calls a second as the median rank at σ 100. But binned in time, nearly all of them are start-up and shutdown, in the main thread: about 6,600 `openat`/`read`/`close` of `/sys/devices/system/cpu/...` files (the CPU topology probe) before the PEs start, and `munmap`/`sched_yield` at exit. **While the simulation runs (about 1.2 s under strace), rank 0 makes about 900 `futex` calls a second and a handful of `brk`, against about 250 `futex` calls for rank 11; no calls into the Omni-Path driver and almost no memory calls.** strace times all of rank 0's calls at under 1% of its time.
- **E2 right:** at σ 2,000 every PE makes about 2,200 calls a second (mostly `futex`, plus `writev` to the hfi1 device and `process_vm_readv` for same-node transfers), and rank 0 is like the rest once start-up is excluded.
- **What this leaves.** Rank 0 at σ 100 spends 17–32% of its time in the kernel and takes 18,000–48,000 minor faults a second (`/proc`, sections 90 and 92). Those are not in system calls (strace), and `perf record -e page-faults:u` saw only 400–1,600 user-mode faults a second (section 92). One of the two measurements is misleading, or the faults come from a kernel mechanism neither sees directly. The leading candidate: automatic NUMA balancing is on (`kernel.numa_balancing` = 1, checked on a login node). It periodically unmaps a process's pages to see which node touches them, and charges the scan and the hinting faults to the threads that run into them. Its address-space walk starts at the lowest addresses, where the main thread's `brk` heap sits. Not yet tested; two other open possibilities are that the `/proc` sampler itself causes the faults on the main thread, or that perf undercounts them.
- The extra `futex` calls (about 3.5× the median rank) are lock waits. A plausible source is glibc's main-arena lock: memory rank 0 allocates is freed by other PEs, which must take that arena's lock.

### §95 · 1/4/16 nodes on 23 devices, results: Charades leads in 22 of 24 cells; glibc no-trim is 1.055× for Charades and 0.25–0.53× for Devastator (2026-10-26; skx-dev batch job 3642157, 16 nodes)

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

### §96 · Rank 0's faults: perf against /proc in the same run, a lighter sampler, and memory bound to the socket (design, 2026-10-26; written before any runs)

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

### §97 · Rank 0's faults, results: an artifact of my /proc sampler; rank 0 is late without it, and takes one shared lock 10× as often (2026-10-26; skx-dev batch job 3642578, 4 nodes)

> **Status: current.** Design and predictions in section 96. 4 nodes (c455-014, c455-021, c455-042, c455-043), 22 runs, all ok; 4 min. Summary `~/charades-data/sdiag/sdiag9_summary.py`, output `~/charades-data/sdiag/j3642578/summary.txt`. **This corrects sections 90 and 92:** rank 0's 18,000–48,000 faults a second and 17–32% kernel time there were caused by the full `/proc` sampler, not by Charades. The throughput results of those sections (23 devices; glibc no-trim) came from runs without the sampler and stand.

- **G1 right.** With every user-mode fault recorded (`-c 1`), perf and `/proc` agree per thread over the whole run (perf ÷ `/proc` 1.00–1.02 for ranks 0, 1, 11 and 22). The faults are ordinary user-mode faults; the earlier sampled profile (section 92, every 100th fault with DWARF stacks) undercounted them.
- **G2 wrong.** With the light sampler (one `stat` read per thread per second), rank 0 at σ 100 takes about 490 faults a second and spends 0.3% of its time in the kernel, against 3,700 and 5% next to the full sampler in this job, and 18,000–48,000 and 17–32% in sections 90 and 92. The full sampler reads `status` and `schedstat` for every thread every 0.5 s. Something in that, for the main thread, makes it fault. I have not found the mechanism and will not use that sampler again.
- **G3 wrong.** Binding memory to the socket (`numactl --membind`, which also exempts it from NUMA-balancing migration) leaves rank 0 as late as before. The slowest process's last PE is rank 0 in 74% of waves, against 71% plain; its mean delay is 25 µs against 11–12 for the rest. Throughput 1.020× at σ 100, 1.001× at σ 2,000.
- **G4 right:** `numa_balancing` = 1 on all four nodes; transparent huge pages `always`, defrag `madvise`.
- **Rank 0 is late with nothing attached** (`plain`): mean contribution delay 25 µs against 12 for the rest, last PE in 71% of waves at σ 100 (12% at σ 2,000).

**What is left, from the strace runs of section 94.** Between 1.45 and 2.55 s of the σ 100 run (the simulation phase under strace), rank 0 makes 620 `futex` calls on one address, 0x3e06600 (455 wakes, 165 waits). Every other PE makes 40–70 calls on that address. The address is in the main thread's `brk` heap, about 30 MB above its start, so the lock was allocated early by the main thread. It is a lock every PE takes, which rank 0 takes, and finds contended, about 10× as often as any other PE: mostly it is holding it while others wait. That would make rank 0 slow exactly when the lock is busy, without more work on average. `strace -k` (call stack for every system call) works on Stampede3 and would name the lock.

### §98 · Naming the lock rank 0 takes 10× as often (design, 2026-10-26; written before any runs)

> **Status: design.** Charades `scale-diag` e2806de (unchanged), htram b25ab15, `+lci_ndevices 23`, glibc defaults. Job H `$WORK/charades-runs/diag10.slurm` (4 nodes, skx-dev and skx, the copy that starts second cancelled), wrapper `skwrap.sh`: process 0 runs under `strace -f -ff -k -e trace=futex` (every lock call that enters the kernel, with its call stack, one file per thread). Runs: σ 100 at W 400, 2 reps, and σ 2,000 once, all with `--gvt-trace=3` so thread ids map to ranks.

**Predictions:**
- H1. The hot lock is not glibc's main-arena lock: that lock lives in libc's data segment, and the hot address (0x3e06600 in section 94) was in the `brk` heap. The new runs' hot address will also be in the heap. Its call stacks on rank 0 go through Reconverse or Charm++ code that delivers node-level messages (the node queue, or node-group entry methods such as htram's node receives and the GVT node waves), not through Charades' event code.
- H2. Rank 0 reaches the lock through a path the other PEs rarely take, for instance as the main thread or as the thread that drains a node-level queue first. The other PEs' calls on the same address come through the same functions, but about 10× less often.
- H3. At σ 2,000 rank 0's calls on that lock are within 2× of the median PE's.

### §99 · The lock, results: Reconverse's per-PE message pool, fought over by the process-edge ranks because each one drains the other's network messages (2026-10-26; skx-dev batch job 3642782, 4 nodes)

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

### §100 · Late rank 0: edge traffic or the rank? Rotated LP blocks, and sending on the destination PE's device (design, 2026-10-26; written before any runs)

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

### §101 · Late rank 0, results: the lateness follows the lower-edge LPs, not the rank or the device; sending on the destination device does not help (2026-10-26; skx-dev batch job 3643113, 4 nodes)

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

### §112 · Freeing another PE's message without its pool lock (`+mempool_remote_free`) (design, 2026-10-27; written before any runs)

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

### §113 · `+mempool_remote_free`, results: freeing a received message 1.45 → 0.30 µs; uniform 1.02–1.06× at 16 nodes; gate rerun needed (2026-10-27; skx-dev batch job 3647310, 16 nodes)

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

### §114 · Correctness gate for `+mempool_remote_free`, rerun with the psm2 transport (design, 2026-10-27; written before the run)

> **Status: design.** Charades `main` 8344576 (after the input-buffer rename; ring input buffers are the default), htram `pdes` 699c3a9, Reconverse 22871c6. Job `gate18` `$WORK/charades-runs/gate18.slurm` (2 nodes, skx-dev and skx).

- Pass 1: `CHARADES_RUN_ARGS=+mempool_remote_free`, `test.py --tier change --launcher srun --nodes 2`, with `env.sh` and XPORT=psm2. Configs: sequential, blocking, bucket, bucket_window, conservative, agg_blocking_pp, agg_inputbuf_bucket_pp, agg_inputbuf_bucket_wps, agg_inputbuf0_bucket_pp, agg_deadline_bucket_pp, agg_ctl_sparse_bucket_pp. Core model configs, launches 1, 4 and 2 × 2.
- Pass 2: 2 processes × 23 PEs, 5 repeats, Simple and Imbalanced PHOLD: agg_inputbuf_bucket_pp, agg_inputbuf_bucket_wps, agg_ctl_sparse_bucket_pp. This puts 23 senders on the rings, which the Mac (at most 4 PEs per process) never did.
- **Prediction G1:** every run passes. Committed counts must match the sequential runs.

### §114 · Correctness gate for `+mempool_remote_free`, results: 231/231; the flag joins the Stampede3 launch (2026-10-27; skx-dev batch job 3647898, 2 nodes)

> **Status: current.** Design in section 113. 2 nodes (c454-081, c454-082); 8 min. Output `$WORK/charades-runs/gate18/j3647898/pass1.txt` and `pass2.txt`. A transient `/work2` I/O error at job start (Slurm could not `chdir` to the submit directory) affected no run.

- Pass 1 (change tier, launches 1, 4 and 2 × 2 on 2 nodes, every model's core configs): **186/186**.
- Pass 2 (2 processes × 23 PEs, 5 repeats, Simple and Imbalanced PHOLD; ring input buffers under their real load): **45/45**.
- **G1 right.**

**Decision.** `+mempool_remote_free` joins the Stampede3 launch line. It is the new default `EXTRA_ARGS` in `scripts/stampede3/ctl_sweep.sh` (`+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free`; the old default still said 16 devices). It needs a Reconverse with the `pads-remote-free` patch, which only `charm-pads-exp` on Stampede3 has. Whether to make it Reconverse's own default, and where to publish the `pads-*` runtime patches, is open.

### §133 · Where an htram message's 2.9 µs goes: htram, Charm++, Reconverse and LCI (design, 2026-10-28; written before any runs)

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

### §134 · An htram message's cost, results: 92–95% is the LCI backend's send call, which polls the network after every post (2026-10-28; skx-dev batch job 3652869, 16 nodes)

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

### §135 · The post and the network poll inside each send, and skipping the poll (`+lci_send_progress 0`) (design, 2026-10-28; written before any runs)

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

### §136 · The poll inside each send, results: it does useful work; skipping it costs uniform 6% on 16 nodes, and the time moves into allocating the next buffer (2026-10-28; skx-dev batch job 3652896, 16 nodes)

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

### §154 · Section 153's start-up transient is a slow cross-process reduction, in episodes of seconds; a diagnostic job (analysis of existing traces and design, 2026-10-29; written before any runs)

> **Status: design; results in section 162** (job E) **and 155** (job E16). Section 162: the start-up stretch did not recur; the time lost at 32 nodes follows TLB-shootdown bursts at a fixed time after setup.
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

### §155 · Job E16, 16 nodes, results: no reduction stretch at 16 nodes; σ 2,000's start-up ramp is in the PEs' user-space work, not the kernel; a dip tied to process age; one external congestion episode, no receive overflow (2026-10-29; skx-dev batch job 3660089, 16 nodes); and two arms added to job E (design, written before job E's runs)

> **Status: current** (E16); **design** (the job E additions at the end).
> - **E16:** design and predictions in section 154.
>   - Allocation: c454-081 to c454-104 (12 nodes) and c455-024, c455-031 to c455-033 (4 nodes, another rack); 21:24–21:30.
>   - Runs: gate 24/24. All 44 Charades runs ok, and committed counts equal within each workload. Devastator 4 of 4 ok.
>   - Data: `~/charades-data/scale32/episodes/n16_j3660089/`, with `summary.txt` (`epi_summary.py`).
> - **The sampler failed to start in the job.** The step's cgroup holds only the one CPU Slurm gives it, so `taskset -c 1` was refused. It was attached from the login node instead (`srun -p skx-dev -t … --jobid --overlap`) and ran from the last run of block A's rep 1 to the end of block D. So rep 1's σ 100 arms have no counters.
> - **Job E is resubmitted** with the sampler on its step's own CPU (now logged in the sampler's start dump) and the two arms below; the first submission, 3660078, was cancelled before it started.

**Untraced, 16 nodes** (median of 3 reps; M ev/s, higher is better; "lost" is the time the first 2 s of wall time lose against the rest of the run's rate):

| arm | M ev/s | ÷ σ 100 default (higher is better) | rest ÷ first 2 s | lost in the first 2 s (s) |
|---|---|---|---|---|
| σ 100, Charm++ reduction (default) | 666.6 | 1.000 | 1.02 | 0.05 |
| σ 100, `--gvt-wave-tree=4` | 683.2 | 1.025 | 1.05 | 0.10 |
| σ 100, `--start-delay-ms=5000` | 680.4 | 1.021 | 0.99 | −0.03 |
| σ 100, `--wave-batch=4` | 618.1 | 0.927 | 1.04 | 0.08 |
| σ 2,000 | 492.8 | — | 1.25 | **0.40** (0.36–0.42 in all 3 reps) |
| uniform | 336.2 | — | 1.07 | 0.12 |

**Simulated time per wall second, in 0.25 s bins from the clock start** (thousands; higher is faster; one rep each, the others alike):

| run | 0 | 0.25 | 0.5 | 0.75 | 1.0 | 1.25 | **1.5** | **1.75** | 2.0 | 2.25 | 2.5 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| σ 100, default | 435 | 497 | 505 | 500 | 505 | 496 | **421** | **376** | 464 | 477 | 479 |
| σ 100, 5 s start delay | 486 | 500 | 487 | 491 | 490 | 495 | 471 | 462 | 493 | 475 | 473 |
| σ 2,000 | **152** | **255** | 334 | 363 | 370 | 345 | **310** | **286** | 360 | 367 | 362 |
| uniform | 204 | 250 | 251 | 248 | 249 | 244 | **211** | **202** | 247 | 248 | 249 |

- **A dip tied to process age.** Every run without the start delay slows 15–25% from 1.5 to 2.0 s after the clock starts, which is about 3.5–4 s after launch (setup takes about 2 s). Of the delayed runs, two show no dip and the third dips at 2.25–2.75 s instead. In the traced runs the dip is in the slowest process's turnaround (126–132 against about 95 µs), not in the reduction, and not in the kernel. It costs about 0.1 s a run, 2% at 16 nodes.
- **No reduction stretch at 16 nodes.** In all four traced σ 100 runs (Charm++ reduction and tree) the reduction after the last process is 34–72 µs from the first bin on. Section 153's stretch, a reduction of 300–410 µs, was at 32 nodes; at 16 nodes A2r showed only 116–149 µs in its first 1.5 s.
- **σ 2,000's start-up ramp** (0.4 s a run, about 7% at 16 nodes) is in the slowest process's turnaround: 526 µs in the first 0.25 s and 263 µs in the next, against 135–150 µs steady, with the reduction steady at 56–67 µs.
  - **The kernel is not the cause (H1 out at 16 nodes).** Kernel time is about 1% of PE time throughout (5.8 µs per PE per 587 µs wave at the start, 1.7 per 200 µs steady). Minor faults per PE per wave fall from 0.38 to 0.02; at about 1 µs each they are negligible.
  - Caveat: Linux accounts thread CPU time by ticks, so only these averages are meaningful; the largest single-PE kernel time per wave in the trace is a tick and means nothing.
  - So the extra time is user-space PE work, as section 121 found from 4 to 16 nodes. That points at the runtime loop (network progress inside psm2 and LCI, allocation), or at the model's and htram's own start.
- **Hops (tree, fan-out 4):** up hops wait 12–17 µs beyond their pair's fastest (35 µs on uniform), and down hops 4–7 µs, with no change over the run. This is as section 118 found.
- **hfi1 counters:**
  - **No receive overflow in any run.** Eager buffers full, header queue full, receive overflow, `SeqDrop0` and every context's `RcvHdrOvr` stay at 0.
  - **Transmit wait appears only with uniform's traffic:** 1–6 M ticks/s across the nodes at 61–64 GB/s sent (about 3.8 GB/s per node, 30% of a link).
  - **One external congestion episode.** In uniform's rep 3, transmit wait rose about 100× for 4 s (0.35–0.88 × 10⁹ ticks/s; the most on c455-024, in the other rack) while our send rate fell from 62 to 47–54 GB/s. That was the slowest uniform rep (320.5 against 346.4 and 336.2 M ev/s).
- **Devastator:**
  - σ 100 rep 1 took 33.5 s (86.5 M ev/s) against 4.8 s (608.6) for rep 2. For about 30 s of rep 1 the nodes sent almost nothing (0.06 GB/s in all), so this was a stall inside Devastator, not the fabric. A2r also had single slow Devastator reps.
  - Uniform: 181.0–181.7 M ev/s.
- **Sampler cost.** The arms run without the sampler (block A's rep 1) are within the rep spread of the same arms with it: σ 100 667.9 against 666.6 and 653.7 M ev/s; tree 685.1 against 663.3 and 683.2. The two runs of block E (sampler off) ran last, at 637 M ev/s; that is a different time, not the sampler.
- **Predictions (16-node counterparts):**
  - E1 right: no stretch at 16 nodes (rest ÷ first 2 s: 1.02).
  - E3: the tree is level (1.025×).
  - E4 right: kernel work is not the cause.
  - E5: no receive overflow; back-pressure seen once, from outside.
  - E6: the start delay removes the 1.5–2.0 s dip.
  - E7 wrong at 16 nodes (`--wave-batch=4`: 0.927×), as in section 120.
  - E8 right.

**Added to job E (32 nodes), design, written before its runs:**
- **`--gvt-wave-tree=8`** (two levels below process 0 instead of three), 3 reps at σ 100. Section 118's flat tree lost to the root's serial sends at 16 nodes. Fan-out 8 halves the levels at 32 nodes, with 8 serial sends a level.
- **σ 2,000 with `--start-delay-ms=5000`,** 3 reps.
- **Predictions:**
  - E9. If the hop count sets the steady reduction at 32 nodes (about 109 µs over 6–7 hops), dropping two levels shortens it by about 30 µs, and fan-out 8 is at least 1.08× the Charm++ reduction at σ 100. If the serial sends cost more, it is at most 1.0×.
  - E10. If σ 2,000's start-up ramp comes from the simulation's own start (the model, htram's buffers, the runtime's pools filling), the 5 s delay leaves it unchanged (at least 0.3 s lost in the first 2 s). If it comes from process age, it disappears.

### §162 · Job E results: no start-up stretch this time; TLB-shootdown bursts at a fixed process age cost 0.26–0.60 s a run at 32 nodes, and a 5 s start delay that moves them out of the clocked run gains 1.13×; the tree and wave batching lose; stretched waves are one slow hop each (2026-10-30; skx batch job 3660196, 32 nodes)

> **Status: current.** Design and predictions in sections 154 and 155.
> - **Allocation:** 32 nodes in 14 racks (c476-002 to c506-112), 12:10–12:21. Gate 24/24.
> - **Runs:** all 36 Charades runs ok, plus Devastator 4 of 4. Committed counts are equal within each workload, and equal to Devastator's.
> - **Binary:** charades-lprb, built from e6c5efc. It predates `--agg-pp-alloc`, so σ 2,000 used PP's old 1.2 MB shared buffers.
> - **Sampler:** on all 32 nodes, on its step's own CPU, from the warm-up to the end of block D. Again it left no end dumps; the 5 s flushes kept every CSV.
> - **Data:** `~/charades-data/scale32/episodes/n32_j3660196/`, with `summary.txt` (`epi_summary.py`).
> - **Scripts:** `course32.py` (time course), `irq32.py` (interrupts by 0.25 s bin), `tlb_closure.py`, `hopwave.py` and `hoppairs.py` (tree hops), all in `~/charades-data/scale32/episodes/`.

**Untraced, 32 nodes** (M ev/s, higher is better; "paired" is each rep's arm ÷ the default run of the same rep, which ran within a minute of it; "lost" is the time the first 2 s lose against the rest of the run's rate):

| arm | M ev/s, median (reps) | ÷ default, paired median (per rep) | lost in the first 2 s (s) |
|---|---|---|---|
| σ 100, Charm++ reduction (default) | 1,098.2 (1,098.2, 927.1, 1,159.7) | 1.000 | 0.26 |
| σ 100, `--gvt-wave-tree=4` | 1,010.4 (981.3, 1,177.3, 1,010.4) | 0.894 (0.894, 1.270, 0.871) | 0.13 |
| σ 100, `--gvt-wave-tree=8` | 942.6 (939.8, 1,153.6, 942.6) | 0.856 (0.856, 1.244, 0.813) | 0.21 |
| σ 100, `--wave-batch=4` | 1,045.4 (1,045.4, 915.9, 1,091.7) | 0.952 (0.952, 0.988, 0.941) | 0.26 |
| σ 100, `--start-delay-ms=5000` | **1,241.1** (1,241.1, 1,046.2, 1,258.8) | **1.128** (1.130, 1.128, 1.085) | 0.34 |
| σ 100, sampler off (block E, after Devastator) | 944.6 (961.3, 927.9) | — | 0.27 |
| σ 2,000 (PP 512, old allocation) | 829.2 (909.8, 803.7, 829.2) | 1.000 | 0.45 |
| σ 2,000, `--start-delay-ms=5000` | 747.4 (665.5, 954.0, 747.4) | 0.901 (0.731, 1.187, 0.901) | 0.21 |
| uniform (WPs 512) | 430.6 (430.6, 357.0, 481.7) | — | 0.57 |
| σ 100 at 16 nodes (block C, the first 16) | 629.3 (606.6, 652.0) | — | 0.07 |

- **Devastator, W 1,000:** σ 100 852.2 and 878.0 M ev/s; uniform 247.8 and 253.6. That is 0.70× and 0.82× its A2r rates at the same W (1,242.2 and 306.8). Charades' σ 100 W 400 is 0.94× its A2r rate (1,171.9, chare rollback then).
  - So in this allocation Charades ÷ Devastator is 1.27 at σ 100 and 1.72 on uniform (A2r: 0.89 and 1.66). One allocation each; Devastator's best W was not swept here.
- **With the start delay, σ 100 runs at 0.99 of twice the 16-node rate** (1,241.1 against 2 × 629.3). The 16-node runs had no delay, but the dip costs only about 2% there.
- **Large run-to-run spread.** Every arm has a fast and a slow rep (1.25× apart for the default). Only the paired ratios separate the arms.

**Simulated time per wall second, 0.5 s bins from the clock start** (thousands; higher is faster):

| run | 0 | 0.5 | 1.0 | **1.5** | 2.0 | 2.5 | 3.0 | 3.5 | 4.0 | 4.5 |
|---|---|---|---|---|---|---|---|---|---|---|
| default r1 | 267 | 448 | 349 | **233** | 363 | 419 | 409 | 441 | 443 | 475 |
| default r2 | 225 | 334 | 382 | **246** | 309 | 356 | 338 | 382 | 311 | 327 |
| default r3 | 260 | 459 | 455 | **305** | 379 | 448 | 421 | 457 | 462 | — |
| tree 4, r2 | 256 | 459 | 479 | **287** | 398 | 458 | 418 | 453 | 486 | — |
| start delay r1 | 235 | 405 | 455 | 474 | 479 | 472 | 474 | 476 | 469 | — |
| start delay r2 | 283 | 374 | 244 | 397 | 443 | 387 | 389 | 468 | 370 | 366 |
| start delay r3 | 281 | 451 | 473 | 474 | 473 | 461 | 471 | 451 | 469 | — |

**The dip lines up with bursts of TLB shootdowns.** Default r1, per 0.25 s, interrupts per second summed over the 32 nodes (thousands; from `/proc/interrupts`; the function-call interrupts track the TLB ones):

| wall s | 0.75 | 1.0 | 1.25 | **1.5** | **1.75** | **2.0** | 2.25 | 2.5 | 2.75 | **3.0** | 3.25 | … | **5.0** |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| simulated time per s (thousands) | 455 | 338 | 360 | **261** | **206** | **301** | 426 | 455 | 383 | **391** | 427 | … | **453** |
| TLB shootdowns per s (thousands) | 13.9 | 13.8 | 14.9 | **133** | **359** | **133** | 22.8 | 9.4 | 44.9 | **149** | 25.9 | … | **83** |

- **What it shows:**
  - In every run without the delay, TLB shootdowns rise about 25× at 1.5–2.25 s of clock time: about 11 k/s per node, on most nodes at once. Smaller bursts follow near 3.0 s and 5.0 s. In uniform's 13–16 s runs there are more, near 11 s and 14 s.
  - The gaps between bursts grow (about 1.3, 2, 6 s).
  - **The delayed σ 100 runs have the same bursts at the same times after setup, while no events run:** 156–349 k/s at 1.5–2.25 s after setup, and 119–168 k/s at 3.0 s. The clocked part then stays at 5–17 k/s, except for one 36–42 k/s bin at 4.0 s. So the bursts follow the time since setup (launch and setup take under 2 s, so a process age of about 3–4 s), not the simulation's work.
- **The same burst at 16 nodes.** Job A16's σ 2,000 runs (section 159) have it at the same clock time (75, 163 and 87 k/s summed over 16 nodes at 1.5–2.25 s; again at 3.0 s), with the dip. Section 159 compared only the first 0.75 s with 2–5 s, so it missed this.
  - The per-node rate is the same at 16 and 32 nodes. The dip is deeper at 32 nodes (35–50% of the rate, against 15–25% at 16), as expected if any one of 64 processes being slow holds up a wave.
- **Closure.** σ 100 runs, 0.25 s bins from 0.75 s to the end, time lost against the delayed runs' 470 k/s (`tlb_closure.py`, threshold 50 k/s summed):
  - In the 12 runs without the delay (default, both trees, wave batching), the 4–7 high-TLB bins hold 0.26–0.60 s, 36–82% of each run's loss. Their mean rate is 283–347 k/s against 347–466 in the other bins.
  - The delayed runs have no high-TLB bins. Two lose 0.04 s each; the third (r2) loses 0.93 s in ordinary bins.
  - **The rest of the loss is a slow-run state.** Outside the bursts, 7 of the 15 σ 100 runs run at 347–390 k/s, against 421–470 for the other eight, with no TLB rise. Arms of both kinds are among them.
- **Kernel settings.** On the login node automatic NUMA balancing is on (`kernel.numa_balancing = 1`) and transparent huge pages are `always`; the compute nodes are not yet checked.
  - Automatic NUMA balancing makes page-table entries inaccessible to sample where a process's memory is used. Every such change interrupts the process's other CPUs to flush their TLBs, and a misplaced page is migrated on its next use.
  - Its scan period starts short and lengthens while the faults it sees are local. Each process here runs on one socket, so its faults would be local.
  - That fits both the timing and the growing gaps, but it is not shown: the sampler did not read `/proc/vmstat`.

**Traced runs:**
- **No start-up stretch.** In both traced Charm++ runs the reduction after the last process is 83–108 µs over 0–1.5 s; in A2r it was 292–411 µs. It peaks at 117–193 µs in the dip.
- **In the 1.75–2.0 s dip:**
  - the slowest process's turnaround is 172–266 µs (45–65 µs otherwise);
  - kernel time per PE per wave rises from 0.4 to 0.7–0.8 µs, and minor faults per PE per wave from 0.03–0.05 to 0.07–0.10.
  - As averages these are small. They cannot show one PE held in the kernel on a wave's critical path.
- **Mid-run episodes** have the section 154 signature: reduction 150–581 µs with turnarounds normal (39–71 µs). Examples: default trace r1 at 2.0–2.75, 3.5–3.75 and 5.25–5.5 s; the tree runs at 1.0–1.5 s and 3.25–3.5 s.
- **The tree is slower in steady state:** its reduction is mostly 150–230 µs against 110–125 µs for the Charm++ path. Up hops wait 14–22 µs beyond their pair's fastest at σ 100, and 58–76 µs on uniform.
- **Each stretched wave is one slow hop** (`hopwave.py`). For waves whose reduction is at least 2× the median, the slowest single hop holds at least 70% of the wave's excess in 98–99% of them (2,645 of 2,691; 2,955 of 3,025; 2,979 of 3,039; 7,260 of 7,344). The median share is 1.3–1.4, so that hop holds all the excess.
  - They are up and down hops in about equal numbers.
  - They spread over many node pairs (`hoppairs.py`). The worst pairs are slow (≥ 100 µs beyond their fastest) in 4–6% of waves, against 0.85% for the median pair.
  - In all four tree runs the top pairs involve c479-044 as sender (processes 14 and 15) and c477-021 (processes 2 and 3) in both directions.
  - The lifetime error counters dumped at the start do not single out these nodes.

**hfi1 counters:**
- **No receive overflow in any run.** Eager buffers full, header queue full, receive overflow, `SeqDrop0` and the per-context `RcvHdrOvr` stay at 0.
- **Transmit wait:**
  - σ 100: 0 in 11 of the 15 32-node runs; at most 7 × 10⁴ ticks/s in the other four.
  - σ 2,000: 0.6–5 × 10⁷ ticks/s.
  - uniform: 1–4 × 10⁸ ticks/s.
- So at σ 100 the slow-run state and the reduction episodes come with no back-pressure at our ports.

**Two more things seen:**
- **σ 2,000 stalls (old PP allocation).** In 3 of 6 σ 2,000 runs, 64 GVT advances took 0.39–0.83 s instead of about 16 ms, once or twice a run (default r2 at 1.6 s; delay r1 at 1.4 and 2.3 s; delay r3 at 2.1 s). That cost 0.4–1.7 s a run.
  - There is no TLB rise and no overflow during them. One CAL-only burst (2.5 M/s summed) followed delay r1's second stall.
  - Unexplained. None of the 95 runs of jobs E16, R16, A16 and P16 at 16 nodes, with the old allocation or the new, has a gap over 0.2 s. They make E10 unreadable.
- **Uniform's clock start** brings 2.0 M TLB shootdowns/s summed (62 k/s per node) in the first 0.25 s. This is tied to the simulation's own start, presumably WPs' buffers being allocated.

**Predictions:**
- **E1 wrong.** No systematic start-up stretch at 32 nodes: rest ÷ first 2 s is 1.15 (1.15–1.31), and 0.26 s is lost. A2r's stretch was an episode that happened to fall at the start.
- **E2:** wrong at start-up, where there was no stretch. The signature is right for the mid-run episodes.
- **E3:** the tree is not faster (0.894 paired) and has episodes too, so the Charm++ path is not the cause (H4 out). Each stretched wave is one slow hop, not most hops. Those hops are not confined to two receiving processes: they spread over node pairs, led by c479-044's sends.
- **E4 wrong as stated.** Average kernel time and faults rise less than 3×. The kernel is still involved, through the TLB-shootdown bursts, which the averages cannot attribute.
- **E5 wrong at σ 100.** The episodes come without transmit wait at our ports or any overflow (H3 out at our ports). Congestion deeper in the fabric is not excluded.
- **E6 right in part.** The start delay removes the 1.5–2.0 s dip (two of three runs stay at 470 k/s throughout) and gains 1.128× paired. The first 2 s still lose 0.34 s to the first 0.75 s's ramp, which the delay does not touch.
- **E7 wrong:** `--wave-batch=4` 0.952×.
- **E8 not separable.** Block E ran 0.86× the default, but last and after Devastator, as in E16. E16's interleaved check found no sampler cost.
- **E9 wrong:** fan-out 8 is 0.856×, below both the 4-ary tree and the Charm++ path.
- **E10 unreadable:** σ 2,000's stalls dominate (0.731–1.187 paired).

**What follows:**
- **Remove the TLB-shootdown bursts without a start delay.**
  - First check that they are automatic NUMA balancing (`/proc/vmstat`), then turn it off for our processes. `numactl --localalloc` gives each process a memory policy other than the default, and NUMA balancing skips memory under such a policy.
  - Allocation is unchanged: each thread's pages still come from its own socket.
  - Every engine gets the same launch in the paper runs. Devastator ran 0.70× its A2r rate here and may be exposed too.
  - Job N16, section 163.
- **Still unexplained:**
  - the slow-run state;
  - the single slow hops spread over node pairs;
  - σ 2,000's stalls, to be checked with the new PP allocation.
- **Dropped:** the 4-ary and 8-ary trees and wave batching at 32 nodes.

### §163 · Are the TLB-shootdown bursts automatic NUMA balancing, and does turning it off for our processes remove the dip? (design, 2026-10-30; written before any runs)

> **Status: design; results in section 164.**
> - **Job N16:** Charades `main` a035fbc (`--agg-pp-alloc=1` and per-LP rollback are the defaults) with htram `pdes` 42d347f, Reconverse and the launch as in job E.
> - **Sampler:** it now also reads `/proc/vmstat`'s counters for:
>   - NUMA balancing (`numa_pte_updates`, `numa_huge_pte_updates`, `numa_hint_faults`, `numa_hint_faults_local`, `numa_pages_migrated`);
>   - migration (`pgmigrate_success`, `pgmigrate_fail`);
>   - transparent huge pages (`thp_fault_alloc`, `thp_collapse_alloc`, `thp_split_pmd`, `thp_migration_success`);
>   - compaction (`compact_stall`, `compact_migrate_scanned`), and `pgfault`.
>
>   Its start dump records `kernel.numa_balancing` and the transparent-huge-page settings.
> - **Script:** `$WORK/charades-runs/numa63.slurm`, 16 nodes on skx-dev, with an skx copy; the loser is cancelled.
> - **Amended before any runs:** the first submission (3662305 and 3662306) was cancelled while pending, to add the binding arm (`scripts/stampede3/numabind.sh`) and N6.

**Why 16 nodes.** The burst and the dip appear at 16 nodes at the same clock time and per-node rate (job A16), and skx-dev starts within hours, where 32 skx nodes took 15 h. The dip costs only about 2% at 16 nodes, so the decision rests on the counters and the time course, not on throughput. The 32-node measurement follows if the mechanism is confirmed.

**Runs** (16 nodes, W 400, end time 2,048,000, untraced, the sampler on, 3 reps interleaved, a warm-up launch first):
- σ 100 (PP 2,048): the default; under `numactl --localalloc`; bound; with `--start-delay-ms=5000`.
- σ 2,000 (PP 512) and uniform (WPs 512): the default; under `numactl --localalloc`; bound.
- **Bound** (`numabind.sh`): `numactl --cpunodebind=L --membind=L`, with L the process's rank on its node.
  - Process 0's PEs are on socket 0's even cores and process 1's on socket 1's odd ones, so every allocation comes from the process's own socket.
  - That includes the main thread's allocations before the PEs are pinned. Without binding, the main thread may start on either socket.
  - NUMA balancing skips this policy too. So bound against `--localalloc` separates misplaced memory from NUMA balancing's own work.
- The job logs `numactl --show` from one task under the same srun options, `numactl --hardware`, and the policy each bound process gets.

**Predictions:**
- **N1. Mechanism.** In the default runs, `numa_pte_updates` and `numa_hint_faults`, summed over nodes, rise at least 10× during the 1.5–2.25 s TLB burst against 0.75–1.5 s. If instead `thp_collapse_alloc`, `compact_*` or `pgmigrate_*` rise with the burst and the NUMA counters do not, the cause is huge-page collapse or compaction, and N2 should fail.
- **N2. Perturbation.** Under `numactl --localalloc`, in all 3 reps of each workload:
  - `numa_pte_updates` stays below 1% of the default runs';
  - TLB shootdowns at 1.5–2.25 s stay below 2× their 0.75–1.5 s rate;
  - the time course has no 1.5–2.0 s dip (that bin within 10% of 1.0–1.5 s).
- **N3. Throughput at 16 nodes.** At σ 100 `numactl --localalloc` is at least 1.01× the default (paired median) and within 0.02 of the start delay's ratio. At σ 2,000 it is at least 1.01×.
- **N4. Uniform's burst at the clock start** (2 M/s at 32 nodes) is unchanged by `numactl`, because it comes from the simulation's own allocations.
- **N5. σ 2,000 with the new PP allocation** has no stretch where 64 GVT advances take more than 0.2 s.
- **N6. Misplaced memory.**
  - If some memory starts on the wrong socket, then in the default runs at least 25% of NUMA hinting faults are remote (`numa_hint_faults` − `numa_hint_faults_local`), and `numa_pages_migrated` rises in the burst. The bound arm is then at least 1.01× `--localalloc` at σ 100 (paired median).
  - If the hinting faults are at least 95% local, nothing is misplaced, and bound and `--localalloc` are level (within ±1%).

**What follows:**
- **N1 and N2 right:** add `numactl --localalloc` to the Stampede3 launch for Charades, Devastator and ROSS. Measure it at 32 nodes in the next skx job (prediction: at least 1.08× paired at σ 100, against the start delay's 1.128×), together with the checks already queued there:
  - `--agg-pp-alloc=1`;
  - the controller with per-LP rollback;
  - Devastator under the same launch.
- **N1 wrong:** follow whichever `/proc/vmstat` counter moves with the burst.

### §164 · Job N16 results: the TLB-shootdown bursts are automatic NUMA balancing; keeping it away from our processes (`numactl --localalloc`) removes the bursts and the dip and gains 1.024–1.049× at 16 nodes; no memory was misplaced (2026-10-30; skx-dev batch job 3662319, 16 nodes)

> **Status: current.** Design and predictions in section 163.
> - **Allocation:** c454-003 to c455-104 (16 nodes, 2 racks), 13:59–14:07. Gate 30/30.
> - **Runs:** all 30 runs ok; committed counts equal within each workload.
> - **Kernel settings, on all 16 nodes:** `kernel.numa_balancing = 1`, transparent huge pages `always`.
> - **Data:** `~/charades-data/scale32/numa/j3662319/`, with `summary.txt` (`numa_summary.py`).

**16 nodes, W 400** (M ev/s, higher is better; "paired" is each rep's arm ÷ the default run of the same rep; "dip" is simulated time per second at 1.5–2.0 s ÷ at 1.0–1.5 s, 1.0 means no dip):

| arm | M ev/s, median (reps) | ÷ default, paired median (per rep) | lost in the first 2 s (s) | dip |
|---|---|---|---|---|
| σ 100, default | 679.9 (679.9, 679.9, 670.6) | 1.000 | 0.06 | 0.82–0.85 |
| σ 100, `numactl --localalloc` | 694.6 (708.0, 694.6, 693.6) | **1.034** (1.041, 1.022, 1.034) | −0.05 | 0.96–1.01 |
| σ 100, bound to its socket | 698.3 (707.4, 698.3, 695.5) | **1.037** (1.041, 1.027, 1.037) | −0.02 | 0.99–1.00 |
| σ 100, 5 s start delay | 695.3 (696.1, 674.8, 695.3) | 1.024 (1.024, 0.993, 1.037) | −0.03 | 0.99–1.01 |
| σ 2,000, default | 516.0 (514.0, 516.0, 518.9) | 1.000 | 0.13 | 0.75–0.84 |
| σ 2,000, `numactl --localalloc` | 542.2 (544.3, 541.3, 542.2) | **1.049** (1.059, 1.049, 1.045) | 0.01 | 0.96–1.02 |
| σ 2,000, bound | 542.8 (542.8, 545.3, 542.3) | **1.056** (1.056, 1.057, 1.045) | 0.00 | 0.96–0.99 |
| uniform, default | 347.4 (347.4, 352.4, 342.9) | 1.000 | 0.07 | 0.85–0.88 |
| uniform, `numactl --localalloc` | 356.7 (355.6, 358.0, 356.7) | **1.024** (1.024, 1.016, 1.040) | 0.01 | 1.00–1.02 |
| uniform, bound | 355.5 (353.2, 355.5, 356.3) | 1.017 (1.017, 1.009, 1.039) | 0.00 | 0.99–1.01 |

**Automatic NUMA balancing, summed over the 16 nodes** (`/proc/vmstat`; per second):

| | default runs | `--localalloc` and bound runs |
|---|---|---|
| page-table entries made inaccessible to sample use (`numa_pte_updates`), whole run | 2.1–4.5 M | 0 (at most 1.4) |
| the same, 1.5–2.25 s ÷ 0.75–1.5 s | 2.1–3.6× | — |
| NUMA hinting faults, steady state, per node | 3,800–7,600 | 0 |
| TLB shootdowns, 1.5–2.25 s ÷ 0.75–1.5 s | 11–17× (σ 100, σ 2,000); 4–7× (uniform) | 0.0–2.0× of near zero |
| TLB shootdowns, steady state, per node | 340–770 | 5–11 (σ 100, σ 2,000); 173 (uniform) |
| hinting faults that were local | 100.0% in every run | — |
| pages migrated, whole run | 1–518 | 0–20 |

- **The scan runs throughout, and its first pass over the whole heap lines up with the burst.** In default runs the balancer changes 2–5 M page-table entries a second (summed over 16 nodes) for the whole run. It starts at the clock start (13–16 M/s in the first 0.25 s) and is 2–4× higher in the 1.5–2.25 s window.
  - Each change interrupts the process's other 22 CPUs to flush their TLBs.
  - Each later touch of a changed page takes a hinting fault.
  - With the balancer kept away, TLB shootdowns fall to 5–11 per node per second for σ 100 and σ 2,000. The remainder on uniform (173) is its own.
- **Nothing was misplaced.** Every default run's hinting faults were 100.0% local, and at most 518 pages moved. The bound arm, which also places the main thread's early allocations, is level with `--localalloc` (paired, bound ÷ `--localalloc`: σ 100 1.003, σ 2,000 1.000, uniform 0.993). So the cost is the balancer's own work, not remote memory.
- **The gain is larger than the dip.** The dip costs about 2% at 16 nodes, but `--localalloc` gains 3.4% at σ 100 and 4.9% at σ 2,000. The balancer's steady scanning (100–180 k entries and 4–8 k hinting faults per node per second) costs throughput all run. The start delay removes only the first bursts: 1.024× against 1.034× at σ 100.
- **Uniform's burst at the clock start is not the balancer.** It stays under `--localalloc` (0.83 M/s summed in the first 0.25 s, against 0.80 M/s by default). It comes from WPs' own allocations at the start.
- **σ 2,000 with the new PP allocation:** the largest gap between progress lines is 0.016–0.043 s, so no stalls at 16 nodes.

**Predictions:**
- **N1: the cause right; the threshold wrong.** The balancer's counters rise only 2.1–3.6× in the burst (predicted ≥ 10×), because it scans all run. The perturbation settles the cause.
- **N2 right.** Under `--localalloc`, `numa_pte_updates` is 0 in every run, the 1.5–2.25 s TLB burst is gone (at most 2× of a near-zero rate), and the dip is gone (0.96–1.02) in all 9 runs.
- **N3 right.** σ 100 1.034× (≥ 1.01), 0.010 above the start delay; σ 2,000 1.049× (≥ 1.01).
- **N4 right.** Uniform's clock-start burst is unchanged.
- **N5 right.** σ 2,000 has no gap over 0.2 s.
- **N6 second branch right.** 100% of hinting faults were local, and bound and `--localalloc` are level (within ±1%).

**What follows:**
- **`numactl --localalloc` is the Stampede3 launch from now on**, for every engine.
  - In `ctl_sweep.sh` it is the default (`NUMA_WRAP`; `NUMA_WRAP=` runs without).
  - Devastator's `run_phold.sh` gets the same wrapper, and so will ROSS's launch. A launch setting must be the same for all three engines.
  - It needs no change to Charades, and allocation is unchanged.
- **Next, at 32 nodes (section 165):** where the start delay alone gave 1.128×; with Devastator under the same launch; and the controller with per-LP rollback.

### §165 · Job N32: `numactl --localalloc` at 32 nodes for Charades and Devastator, the controller with per-LP rollback, and the slow-run state (design, 2026-10-30; written before any runs)

> **Status: design; results in section 166.**
> - **Charades:** `main` (per-LP rollback, `--agg-pp-alloc=1`, and the `numactl --localalloc` launch from `ctl_sweep.sh`), htram `pdes` 42d347f, Reconverse and the launch as in job E.
> - **Devastator:** as in A2r; `run_phold.sh` now runs it through `BIN_WRAP` when set.
> - **Script:** `$WORK/charades-runs/numa165.slurm`, 32 nodes on skx (`-x c455-081`). The sampler runs throughout.

**Runs** (32 nodes, end time 2,048,000, untraced; reps interleaved; a warm-up launch first):
- **A. Charades, W 400, 3 reps.** For each of σ 100 (PP 2,048), σ 2,000 (PP 512) and uniform (WPs 512): `--localalloc` (the new launch) and without (`NUMA_WRAP=`), back to back.
- **B. Charades' controller** (ε 0.001), `--localalloc`, 3 reps: σ 100 and σ 2,000.
- **C. Devastator, W 1,000, 2 reps:** σ 100 and uniform, with and without `numactl --localalloc`.
- **D. 16 nodes (the allocation's first 16):** σ 100 W 400 with `--localalloc`, 2 reps.

**Predictions:**
- **M1.** Charades `--localalloc` ÷ without, paired median: σ 100 ≥ 1.10, σ 2,000 ≥ 1.05, uniform ≥ 1.02.
  - At 32 nodes the start delay alone gave 1.128×. At 16 nodes `--localalloc` beat the delay by 0.010, and gained 1.049× at σ 2,000 and 1.024× on uniform.
- **M2.** Under `--localalloc`, no 1.5–2.25 s TLB burst and no dip (≥ 0.95) in any run.
- **M3. The slow-run state.** If the balancer also caused it, the three σ 100 `--localalloc` reps are within 1.08× of each other (max ÷ min); job E's default reps were 1.25× apart. If they stay at least 1.15× apart, it is something else.
- **M4.** Devastator gains too, at least 1.03× at σ 100: its 23 worker threads per process are as exposed. Charades ÷ Devastator is reported with both engines under the same launch.
- **M5.** Per-node efficiency from 16 to 32 nodes at σ 100 under `--localalloc` is at least 0.93 (A2r, with chare rollback and the balancer: 0.82).
- **M6.** The controller with per-LP rollback is at least 0.95 of W 400 at σ 100 and σ 2,000 (A2r, chare rollback: 0.93–0.94).
- **M7.** σ 2,000 with the new PP allocation has no gap over 0.2 s between progress lines at 32 nodes (job E, old allocation: 3 of 6 runs).

**What follows:** if M1, M4 and M5 hold, rerun the paper-grade 1–32-node table (all eight workloads, three engines) with the new defaults and launch.

### §166 · Job N32 results: at 32 nodes keeping NUMA balancing away gains 1.060× (σ 100), 1.124× (σ 2,000) and 1.028× (uniform) and removes the dip; σ 100 now keeps its per-node rate from 16 to 32 nodes; Devastator does not gain; slow episodes remain (2026-10-31; skx batch job 3662671, 32 nodes)

> **Status: current.** Design and predictions in section 165.
> - **Allocation:** 32 nodes in 6 racks (c483-022 to c505-003), 21:44–21:54 on 2026-10-31. Gate 30/30.
> - **Runs:** all 27 Charades runs and 8 Devastator runs ok. Committed counts are equal within each workload and node count, and equal to Devastator's.
> - **Kernel:** `kernel.numa_balancing = 1` on all 32 nodes.
> - **Data:** `~/charades-data/scale32/numa/j3662671/`, with `summary.txt` (`numa32_summary.py`).

**Charades, 32 nodes** (M ev/s, higher is better; "paired" is each rep's arm ÷ the run without numactl of the same rep, which ran next to it; "spread" is the fastest rep ÷ the slowest; "dip" is simulated time per second at 1.5–2.0 s ÷ at 1.0–1.5 s, 1.0 means no dip):

| workload | arm | M ev/s, median (reps) | spread | ÷ without numactl, paired median (per rep) | dip |
|---|---|---|---|---|---|
| σ 100 (PP 2,048) | W 400, `--localalloc` | **1,382.1** (1,398.1, 1,135.2, 1,382.1) | 1.23 | **1.060** (1.066, 0.909, 1.060) | 0.98–0.99 |
| | W 400, without | 1,303.5 (1,311.2, 1,248.2, 1,303.5) | 1.05 | 1.000 | 0.70–0.74 |
| | controller, `--localalloc` | 1,297.3 (1,261.1, 1,297.7, 1,297.3) | 1.03 | 0.995 | 0.98–1.04 |
| σ 2,000 (PP 512) | W 400, `--localalloc` | **1,062.7** (1,061.2, 1,062.9, 1,062.7) | 1.00 | **1.124** (1.124, 1.126, 1.112) | 0.93–1.01 |
| | W 400, without | 944.1 (944.1, 944.0, 955.5) | 1.01 | 1.000 | 0.63–0.67 |
| | controller, `--localalloc` | 1,011.4 (1,011.4, 1,007.3, 1,013.0) | 1.01 | 1.067 | 0.96–0.99 |
| uniform (WPs 512) | W 400, `--localalloc` | **580.2** (589.3, 580.2, 579.9) | 1.02 | **1.028** (1.028, 1.036, 1.027) | 0.95–1.01 |
| | W 400, without | 564.4 (573.4, 559.8, 564.4) | 1.02 | 1.000 | 0.71–0.72 |

- **The bursts and the dip are gone.** Without numactl, TLB shootdowns rise 14–16× at 1.5–2.25 s (uniform 4.8–4.9×), and the dip is 0.63–0.74. Under `--localalloc` TLB shootdowns stay at 0–3 k/s summed over 32 nodes in every run, and the dip is 0.93–1.04.
- **σ 2,000 gains most** (1.124×, every rep within 1.112–1.126). Its runs also have no stalls: the largest gap between progress lines is 0.019–0.062 s against 0.39–0.83 s in job E. Job E used the old PP allocation; this job has the new one (`--agg-pp-alloc=1`) as well as the new launch.
- **Slow episodes remain, and they are not the balancer.** σ 100 `--localalloc` rep 2 ran at 164–297 thousand simulated time per second for 1.75 s (2.0–3.75 s), against about 500 otherwise. The 16-node rep 2 ran at 113–168 for 2.5 s (0.5–3.0 s), against about 480.
  - Neither shows any TLB shootdowns.
  - Transmit wait was 0 on every node throughout, so there was no back-pressure at our ports. Our sent words fall with the throughput.
  - These are the same kind of episode as job E's slow runs. They are now the largest remaining source of run-to-run spread at σ 100.

**Against the paper-grade table** (A2r, job 3657016: chare rollback, the old PP allocation, balancer on, a different allocation). M ev/s at 32 nodes, higher is better:

| workload | A2r, controller | A2r, W 400 | this job, controller | this job, W 400 `--localalloc` |
|---|---|---|---|---|
| σ 100 | 1,107.2 | 1,171.9 | 1,297.3 | 1,382.1 |
| σ 2,000 | 857.9 | — | 1,011.4 | 1,062.7 |
| uniform | 508.7 | — | — | 580.2 |

This allocation was also faster without numactl: σ 100 W 400 1,303.5, against 1,171.9 in A2r. So these columns mix the launch, the defaults (per-LP rollback, `--agg-pp-alloc=1`) and the allocation. The rerun of the table separates them.

**Devastator, W 1,000** (M ev/s):

| workload | with `--localalloc` | without | paired, with ÷ without |
|---|---|---|---|
| σ 100 | 751.7, 810.5 | 838.4, 835.3 | 0.897, 0.970 |
| uniform | 237.2, 235.0 | 234.9, 233.2 | 1.010, 1.008 |

- **Devastator does not gain from `--localalloc`**, and at σ 100 both of its runs with it were slower. Two reps; its launch stays as it was.
- **Charades ÷ Devastator in this allocation**, each engine with its better launch (higher is better): σ 100 1.65 (1,382.1 against 836.9), uniform 2.46 (580.2 against 236.1). With both engines without numactl: 1.56 and 2.41. Devastator's best W was not swept here; in A2r it was W 1,000 for both workloads.

**16 → 32 nodes at σ 100** (both under `--localalloc`): the 16-node reps were 676.5 and 488.2 M ev/s, and the second had one of the slow episodes. Against the first, the per-node efficiency is 1,382.1 ÷ (2 × 676.5) = **1.02**; against job N16's 16-node median under `--localalloc` (694.6, another allocation) it is 0.995. A2r had 0.82 (Charades) and 0.96 (Devastator).

**Predictions:**
- **M1 right for σ 2,000 and uniform, wrong for σ 100.**
  - σ 2,000 1.124 (≥ 1.05) and uniform 1.028 (≥ 1.02).
  - σ 100 1.060, not ≥ 1.10. The rep with the slow episode gives 0.909; the other two give 1.060–1.066.
  - Job E's start-delay gain of 1.128× was in an allocation where the default ran at 1,098 M ev/s against 1,304 here, and part of it was its own slow runs.
- **M2 right.** No burst and no dip under `--localalloc` in any run.
- **M3 wrong.** The σ 100 `--localalloc` reps are 1.23× apart because of one slow episode. The slow-run state is not the balancer.
- **M4 wrong.** Devastator 0.897–0.970× at σ 100 and 1.008–1.010× on uniform.
- **M5 right**, with one usable 16-node rep: 1.02 (≥ 0.93).
- **M6 right at σ 2,000, wrong at σ 100.** The controller is 0.952 of W 400 at σ 2,000 and 0.939 at σ 100 (≥ 0.95 predicted).
  - It holds W at 313–329, the κ bound. With per-LP rollback, W 400 is better at 32 nodes.
- **M7 right.** σ 2,000 has no gap over 0.062 s.

**What follows:**
- **Launch.** `numactl --localalloc` stays the Charades launch. Devastator keeps its own, since each engine runs with its better launch.
- **The controller's κ bound at 32 nodes.** It costs 5–6% against W 400 now. Test a larger κ, or a κ that follows the measured cost of a rollback (cheaper with per-LP rollback), at 16 and 32 nodes before the rerun.
- **The slow episodes** (1.75–2.5 s at a third of the rate, no TLB shootdowns, no transmit wait). They are the largest remaining noise at σ 100. They need a traced run that catches one, to see whether it is one slow hop, as in job E, or every process.
- **Then rerun the paper-grade 1–32-node table** with the new defaults and launch (Charades), Devastator's best W, and ROSS.

### §205 · Shared memory between processes, rewritten in Reconverse: 2 × 23 with the pool is 1.38× 2 × 23 over LCI, 0.86 of one process per node; Charm++ `--enable-shmem` and `+ipc` alike (2026-11-03; idev 3677573, c455-104)

> **Status: current.** Reconverse branch `pads-perf` a7e5108 (Mac worktree `~/reconverse_perf`, local only; on Stampede3 as 80b7417 by `git am` in `$WORK/charm-pads-perf/contrib/reconverse`). Runtimes built on the idev node (Xeon 8160): `$WORK/charm-pads-perf` (`--with-production`, the pool on with `+ipc`) and `$WORK/charm-pads-perfshm` (`--enable-shmem`), both with `charm-pads-exp`'s patched LCI source. Charades trees `charades-perf` and `charades-perfshm` (c7373b4 plus section 204's changes). b19 × 1 on 1 node, W 5,000, `--fossil-lazy=1 --batch=32`, 2 reps; same count and digest in every run. **Reconverse's tests on the Mac found a start-up race in the first version** (`runtime_modes`: 4 of 6 runs crashed or aborted): a peer maps a segment before its owner initializes it, the zeroed lists read as holding a block at offset 0, and taking it wrote a block header over the segment's heap and bound. Fixed in b127a67 (check the heap pointer, published last, before touching a peer's lists); Mac ctest 112/113 (`abort_peer-multinode` times out, as on main), the 19 pool tests 10 times each all passed; both Stampede3 runtimes rebuilt with it (cc5b7b0 / 8871e68); VLSI gates on 1 node at 2 × 2 and 4 × 2 30/30 for `+ipc`, `--enable-shmem` and `+ipc --fossil-lazy=1`. The rates below were measured before the fix; the fix only adds one load on a path a sender takes when its private list is empty.

**The change** (`cmishmem.cpp`, `cmi-shmem-common.h`, `scheduler.cpp`, `converse.h`):
- One receive queue per PE in its process's segment instead of one per process. Senders push with a compare-and-swap; the PE takes its whole list each scheduler pass and delivers it oldest first (`CmiDeliverIpcInbox`). Node datagrams get their own queue.
- Each block records the host-local index of the PE that allocated it. Freeing pushes it onto that sender's return list in the block's segment; the sender takes that list whole when its private list of that size is empty; new blocks come from the heap by `fetch_add`.
- Every list is pushed by compare-and-swap and emptied whole by one exchange, so none needs a lock or an ABA counter. Before, one queue and one heap per process were each guarded by an exchange used as a lock, receivers gave up for the pass when it was held, and each PE took one block per pass.

**Rates** (M committed ev/s, higher is better):

| layout | r1 / r2 | ÷ 2 × 23 over LCI | ÷ 1 × 46 |
|---|---|---|---|
| 2 × 23, LCI between processes | 23.8 / 23.6 | 1.00 | 0.62 |
| 2 × 23, new pool, `+ipc` | 33.3 / 32.5 (later pair 32.4 / 32.5) | 1.38 | 0.86 |
| 2 × 23, new pool, Charm++ `--enable-shmem` | 32.6 / 33.0 | 1.38 | 0.86 |
| 1 × 46 | 38.2 / 38.1 (38.3 / 38.0) | 1.61 | 1.00 |
| old pool (V4, W 2,500, before section 204's changes), `--enable-shmem` / `+ipc` | 4.1 / 4.8 | 0.17 / 0.21 | |

- **Through the new pool** (`--comm-stats=1`, `+ipc`): a send call takes 0.74 µs (old pool 16, LCI 2.0), send calls are 6.4% of PE time, and delivery takes a mean of 13.9 µs (median 4–8), the same as within a process (14.2). 16.3 M messages went through the pool.
- **What is left between 2 × 23 and 1 × 46:** a cross-process event still goes through Charm++'s message path (envelope, the send, the copy into a block, delivery to the array element) where a same-process event is a pointer handed to the PE's input buffer.

**The frozen controller with lazy fossils** (1 × 46, batch 32, buckets of 2,500): it holds W at 2,500 ps (one bucket) and runs 33.4 M ev/s, as fixed W 2,500 does (33.4), but the best fixed W is now 5,000 (38.1): 0.88 of it, where V2 had 0.99. Its smallest W is one bucket and every remote delay is shorter than one, so its scale does not reach W 5,000. **With buckets of 5,000 ps** the controller settles at W 5,000 and runs 37.7 / 36.6, the same as fixed W 5,000 at those buckets (36.5 / 37.0) and 0.97 of the best fixed setting (38.1, buckets of 2,500): the per-model bucket setting puts it back, as in V2.

### §218 · The shared-memory pool rewrite as a Reconverse pull request: Stampede3 tests against Reconverse main (job SHMPR design, 2026-11-04; written before any runs)

> **Status: design.** User decision 2026-11-04: push `pads-perf` as it is (done: `origin/pads-perf` at bab3df1, no PR), and make the pool rewrite (section 205) a pull request, tested on Stampede3 while job big2 waits.
> - **Branch:** Reconverse `shmem-pool-queues` (4159d3e, pushed) is upstream main (5471ba0) with:
>   - the two pool commits from `pads-perf`;
>   - fixes found in review: return lists up to 2 MiB blocks, so a 128 KiB `++ipccutoff` works; `++ipccutoff` capped at 1 MiB, with a notice; the heap moves only for a block that fits;
>   - `ipc_order` generalized to several PEs per process, with a new test `ipc_order-multi` (2 × 4 PEs).
> - **Mac:** ctest 133/133.
> - **Script:** `$WORK/charades-runs/shmpr.slurm` (copy in `~/charades-data/vlsi/`), 2 nodes.
> - **Trees:**
>   - Charm++ `recharm` 3d409d45d built twice (`charm-shm-base` with Reconverse main, `charm-shm-pr` with the branch), both on LCI 1287c59c (upstream's pin, which includes native psm2, lci#214);
>   - Charades at ae0dbd3 (round 3's code) against each (`charades-shm-base`, `charades-shm-pr`);
>   - the branch built alone with its tests (`reconverse-shmpr`).

**Steps:**
1. Builds on the nodes.
2. Reconverse's ctest, every test's processes on one node.
3. The one-process `+ipc` start-up hang (section 211), on both builds.
4. Charades' change tier with `+ipc` at 2 × 2 and 4 × 2, on both builds.
5. 1 node, 2 × 23 over `+ipc`, main's pool against the branch's:
   - VLSI b19 (lazy fossils, batch 32, W 5,000), 3 reps;
   - PHOLD σ 100 (PP 2,048) and uniform (WPs 512) at W 300, 2 reps;
   - the branch over LCI for reference.
6. 2 nodes, VLSI b19 × 2 at 2 × 23 over `+ipc`, 2 reps.

**Predictions:**
- **SP1.** Both trees build. Reconverse's ctest passes on Stampede3 as on the Mac.
- **SP2.** The one-process `+ipc` hang happens on main as well as on the branch: it is not the rewrite's.
- **SP3.** Charades' change tier with `+ipc` passes on both builds, with one count per config.
- **SP4.** VLSI at 2 × 23 over `+ipc`, branch ÷ main 3–6. Section 202 measured main's design at 0.17–0.21 of one process per node on the old tree; section 205 measured the rewrite at 0.86.
- **SP5.** PHOLD at 2 × 23 over `+ipc`, branch ÷ main 1.0–1.4. htram combines the events between the node's processes, so fewer messages cross the pool than on VLSI.
- **SP6.** VLSI on 2 nodes, branch ÷ main at least 1.5.

### §219 · SHMPR results: the branch's pool is 2.1× main's on VLSI at 2 × 23 over `+ipc` (2.3× on 2 nodes), 1.17× on uniform PHOLD, level on σ 100; Charades' change tier with `+ipc` passes on both; the one-process `+ipc` hang is gone upstream; this upstream stack runs Charades at about half `charm-pads-perf`'s rate (2026-11-04; skx-dev batch job 3681031, 2 nodes)

> **Status: current.** Design and predictions in section 218.
> - **Job:** 18 minutes (skx copy 3681032 cancelled). Both Charm++ trees built on the node in under 2 minutes; Charades against each in about a minute. `libreconverse.so` exports `CmiDeliverIpcInbox` only in the branch's build.
> - **Data:** `~/charades-data/vlsi/shmpr/j3681031/`.
> - **Counts:** every pair of runs commits the same events with the same digest in both builds.

**Main's pool against the branch's** (2 × 23 per node over `+ipc`; M committed ev/s, median of the reps, higher is better):

| workload | nodes | main (5471ba0) | branch | branch ÷ main |
|---|---|---|---|---|
| VLSI b19, `--fossil-lazy=1 --batch=32`, W 5,000 | 1 | 6.69 (6.69 / 6.57 / 6.73) | 13.97 (13.74 / 14.19 / 13.97) | **2.09** |
| VLSI b19 × 2 | 2 | 12.49 (12.52 / 12.45) | 29.21 (29.31 / 29.11) | **2.34** |
| PHOLD uniform, WPs 512, W 300 | 1 | 30.55 (31.09 / 30.01) | 35.62 (35.69 / 35.55) | 1.166 |
| PHOLD σ 100, PP 2,048, W 300 | 1 | 38.55 (39.25 / 37.85) | 39.51 (39.59 / 39.42) | 1.025 |

- **Against LCI:** the branch over LCI without `+ipc` runs VLSI at 10.69. Its `+ipc` is 1.31× that, as section 205 found on `pads-perf` (1.38×). Main's `+ipc` is 0.63× LCI.
- **Charades' change tier with `+ipc`** (2 × 2 and 4 × 2; VLSI, Simple PHOLD, traffic, dragonfly; four configs) passes 80/80 on both builds. It took 1.5 minutes on the branch and 9 minutes on main.
- **The one-process `+ipc` start-up hang** (section 211) does not occur on either. Reconverse main now declines `+ipc` in a one-process job (`+ipc ignored: this job has a single process`), so the hang was on `pads-perf`'s older base.
- **Reconverse's ctest on Stampede3** (the branch, standalone, every test's processes on one node through `srun`):
  - 114 of the first 116 tests pass;
  - `ipc-onenode` and `pingpong_multipairs` time out at 180 s with no output. Both are one-process tests launched without `srun`, and `pingpong_multipairs` does not use the pool;
  - stopped at test 117 so as not to share node 1 with the job's 2-node runs (the first of them overlapped the stop by a few seconds; its two reps agree within 0.5%).
  - **On an idev node** (3681098; c455-011, 20–30 s caps):
    - tests 117–133 pass when launched through `srun`;
    - every one-process test that timed out passes under `srun`, except three: `ipc-onenode`, `pingpong_multipairs` and `megarecon` (one process, `+pe 2` or `+pe 4`). Those three hang on Reconverse main (5471ba0) the same way, and pass on the Mac.
    - Started straight from an ssh shell on the node, without `srun`, such tests had every thread on core 0, with or without `HFI_NO_CPUAFFINITY=1`, though the shell's mask was the whole node.
  - **So on Stampede3 every test either passes on the branch or hangs on main as well.** Logs in `~/charades-data/vlsi/shmpr/idev/`.

**This upstream stack is slower for Charades.** On the same node and code (round 3), the branch's build runs VLSI at 2 × 23 over LCI at 10.69 M ev/s and with `+ipc` at 13.97. `charm-pads-perf` ran these at about 22.8 (section 208, older Charades) and 33.4 (section 215). PHOLD σ 100 at 2 × 23 is 39.5 here against 54.0 there, and the blocked share is 71–74% against 54% on VLSI.

The two stacks differ in:
- Charm++ (`recharm` 3d409d45d against 9d6a55780);
- Reconverse (main lacks `pads-perf`'s TLS initial-exec model, `+lci_dest_device` and the old schedulers' poller rule);
- LCI (stock 1287c59c against the patched tree with 64 KiB packets).

Which of these costs the half is not measured. It does not touch the paper's numbers, which all come from `charm-pads-perf`, but it matters for running Charades on upstream Reconverse.

**Predictions (section 218):**
- **SP1 half:** both trees build. ctest: every test passes on the branch or hangs on main as well; three one-process tests hang on Stampede3 in both.
- **SP2 wrong:** no hang on either build.
- **SP3 right.**
- **SP4 wrong:** 2.09, not 3–6. Main's pool is less bad here than on the older stack, which section 202 measured at 0.17–0.21 of one process per node.
- **SP5 right:** 1.03 and 1.17.
- **SP6 right:** 2.34.

### §220 · Reconverse PR #319 after review: the counter for full segments, the default segment size, and a check for slowdowns (job SHMPR2 design, 2026-11-04; written before any runs)

> **Status: design.** Kale reviewed reconverse#319. The scheme was judged sound, with one design question: a freed block goes back only to the PE that allocated it, so one sender's burst can use up a segment while its freed blocks sit on its own lists, and other senders then fall back to the network with nothing reporting it. The review asked whether the Charades runs hit this. User decision 2026-11-04: make every change the review asks for except the chunked allocator (a later step).
> - **Branch `shmem-pool-queues` at 4b1740a** (pushed; Mac ctest 135/135), on top of 4159d3e (section 218):
>   - `CmiIpcPoolFullSends()` counts a PE's sends that went over the network because the destination's segment was full; the first one in a process prints a notice. `CmiIpcPoolBytesUsed()` gives the bytes of this process's segment cut into blocks.
>   - Without `++ipcpoolsize`, a segment gets 512 KiB per PE of the host's other processes, at least 8 MiB: 11.5 MiB at 2 × 23, 16.5 MiB at 4 × 11.
>   - Limits 512 PEs per process and 1,024 per host (header about 160 KiB), applied only when a host runs several processes.
>   - Each PE's private lists are indexed by the host's processes, not the job's.
>   - `CmiIpcBlock::src`/`dst` renamed `segment_proc`/`sender_proc`; design document `doc/shared-memory-ipc.md`; new test `ipc_poolfull`.
> - **Charades f5e8179** reports the two counters ("Shared-Memory Pool Full (sent over the network)", "Shared-Memory Pool Bytes Used (most in a process)") when the runtime has them. Same engine code as ae0dbd3.
> - **Charades keeps a received message as its event's storage until the event is freed** (`LPChare::recv_remote_event`, `e->set_msg(event)`), so a pool block stays in use for the event's lifetime, not just until delivery. How much of a segment VLSI needs is therefore unknown.
> - **Script:** `$WORK/charades-runs/shmpr2.slurm` (copy in `~/charades-data/vlsi/`), 2 nodes, `HFI_NO_CPUAFFINITY=1` in every run:
>   1. builds: Charm++ `charm-shm-pr2` (recharm 3d409d45d, Reconverse 4b1740a) on node 0, the standalone branch on node 1, then `charades-shm-pr2`;
>   2. Reconverse's IPC tests on node 1 (`srun`, 30 s cap, `ipc-onenode` left out: it hangs on main too);
>   3. node 0, `+ipc`, 2 × 23: VLSI b19 (settings of section 219) with `pr` (4159d3e), `pr2` (4b1740a, default segment) and `pr2` at `++ipcpoolsize 8388608`, 2 reps each; PHOLD uniform (WPs 512) and σ 100 (PP 2,048) at W 300, `pr` and `pr2`, 2 reps;
>   4. node 0, `+ipc`, 4 × 11 (`+pemap 2-44:2,3-45:2`: one socket per process; `+lci_ndevices 11`): VLSI b19 with `pr2` at its default and at 8 MiB, 2 reps.
>
> **Predictions:**
> - **SR1:** both builds pass; every IPC test passes on Stampede3, including `ipc_poolfull` and `ipc_poolfull-multi`.
> - **SR2:** `pr2` ÷ `pr` at the default segment is 0.98–1.02 on VLSI, uniform and σ 100. The changes add one load per allocation, and counting happens only on a failure.
> - **SR3:** VLSI at 2 × 23 with an 8 MiB segment records some full-segment sends, but under 1% of the cross-process sends; the bytes used then equal the segment's size within one block.
> - **SR4:** the default segment (11.5 MiB at 2 × 23) has fewer full-segment sends than 8 MiB, and its rate is within 2% of 8 MiB's.
> - **SR5:** at 4 × 11 (33 senders per segment), 8 MiB has more full-segment sends than at 2 × 23, and the default (16.5 MiB) has fewer than 8 MiB.

### §221 · SHMPR2 results: Charades never fills a segment; VLSI's busiest segment peaks at 4.0–4.2 MiB of 8 MiB at both 2 × 23 and 4 × 11; the reviewed branch runs at 0.985–1.006 of the branch before review (2026-11-04; skx-dev batch job 3682096, 2 nodes)

> **Status: current.** Design and predictions in section 220. Data in `~/charades-data/vlsi/shmpr2/j3682096/`.

**No send found a segment full, in any run.** The table gives the pool's own counters from Reconverse 4b1740a. Two reps per row; both values are listed where they differ.

| workload | processes × PEs | segment (MiB) | messages through the pool per run (M) | sends that found the segment full | most of one segment in blocks (MiB; lower means more room) |
|---|---|---|---|---|---|
| VLSI b19 | 2 × 23 | 11.5 (default) | 16.3 | 0 | 4.06 / 4.02 |
| VLSI b19 | 2 × 23 | 8 | 16.3 | 0 | 4.02 / 4.03 |
| VLSI b19 | 4 × 11 | 16.5 (default) | 27.0 | 0 | 4.03 / 4.01 |
| VLSI b19 | 4 × 11 | 8 | 27.1 | 0 | 3.98 / 4.18 |
| PHOLD uniform | 2 × 23 | 11.5 (default) | 1.27 | 0 | 1.51 / 1.47 |
| PHOLD σ 100 | 2 × 23 | 11.5 (default) | 0.20 | 0 | 0.91 / 0.92 |

- Charades keeps a received message as its event's storage until the event is freed (section 220), and still uses about half of an 8 MiB segment at most.
- **Peak use does not grow with the number of senders.** At 4 × 11 (33 senders per segment) it is the same as at 2 × 23 (23 senders). So the messages in use at once set the peak, not how many PEs send them.

**The review changes cost nothing measurable.** Rates are M committed events/s, the mean of 2 reps; higher is better.

| workload | processes × PEs | before review, 4159d3e | after review, 4b1740a (default segment) | after ÷ before | 4b1740a at 8 MiB |
|---|---|---|---|---|---|
| VLSI b19 | 2 × 23 | 14.52 (14.39 / 14.65) | 14.31 (14.37 / 14.24) | 0.985 | 14.47 (14.51 / 14.42) |
| PHOLD uniform, WPs 512, W 300 | 2 × 23 | 35.72 (35.50 / 35.93) | 35.92 (35.88 / 35.95) | 1.006 | — |
| PHOLD σ 100, PP 2,048, W 300 | 2 × 23 | 40.14 (40.20 / 40.08) | 39.62 (39.97 / 39.27) | 0.987 | — |
| VLSI b19 | 4 × 11 | — | 13.80 (13.82 / 13.77) | — | 13.77 (13.74 / 13.79) |

- The ratios are inside the rep spread: the two reps of 4159d3e on VLSI differ by 1.8%.
- **Same committed counts in every comparison, and the same digest within each layout.** VLSI 2 × 23: 87c11aec982ad656 (235,520 LPs). VLSI 4 × 11: 7348d5d9fb7409e8 (247,808 LPs, a different padding of the netlist). PHOLD ran without digests.
- VLSI at 2 × 23 ran at 14.3–14.7 M ev/s here, against 13.97 in job 3681031 (section 219), with `HFI_NO_CPUAFFINITY=1` now set as well.

**Reconverse's IPC tests on Stampede3.**
- The job's standalone build failed with exit 127: the job ran it through a non-login ssh shell on node 1, which has no `module` and so no `cmake`. This is the same mistake as in section 219. The job's own ctest step therefore ran the old build (18/18 passed) and is not counted.
- I rebuilt within the allocation from a login shell on node 1 (`build_rc_shmpr.sh`), then ran the IPC tests through `srun` (`ctest_ipc_shmpr2.sh`, 30 s cap): **20/20 pass**, including `ipc_poolfull` and `ipc_poolfull-multi`. `ipc-onenode` was left out; it hangs on main too (reconverse#320).

**Predictions (section 220):**
- **SR1 right**, after the rebuild.
- **SR2 right:** 0.985, 1.006, 0.987.
- **SR3 wrong:** no full-segment sends at 8 MiB. The peak is about 4.0 MiB, half the segment.
- **SR4 half:** the default's rate is 0.989 of 8 MiB's, within 2%. But neither size had a full-segment send, so there was nothing to reduce.
- **SR5 wrong:** none at 4 × 11 either, and peak use is the same as at 2 × 23.

**What follows:** this answers the review's question for Charades: it never ran out, with room to spare. The per-sender default size is a safeguard that these runs do not need. The reply to the review and the new PR description quote these numbers.

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

## Earlier

Superseded or historical sections, in the order they were written. Their numbers came from an older stack, launch or setting, or a later section replaced them; each says which.

### §0 · QD poll fix on the Mac (2026-10-19)

> **Status: historical.** The reason for Reconverse PR #290 (`idle-progress-poll`).

**Why `idle-progress-poll` matters.** Reconverse's default scheduler polled the
network ~40 times per idle sweep before raising idle conditions. Quiescence
detection waits on those conditions every hop, so with one PE per process a QD
round took 10.7 ms instead of 0.39 ms on the Mac (libfabric TCP, a `kevent`
per poll). Synchronous GVT and the conservative scheduler use QD every round:
Charades conservative `long` went from 70 s to 4.1 s. On Stampede3
(Omni-Path, verbs) the cost per poll is far lower, but the fix still gives
3–4× (see "First Stampede3 measurements").

### §21 · Production runtime build (2026-10-21, batch job 3626643, 4 skx nodes)

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

### §22 · Runtime settings on the production build (2026-10-21, idev job 3626832, 4 skx nodes)

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

### §25 · Runtime tuning (2026-10-21 night, idev job 3627274, 4 skx nodes)

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
