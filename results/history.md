# History

Notes on the work itself, moved from the single RESULTS.md (split 2026-11-07): the re-read of 2026-10-28 and the plan as it stood on 2026-10-21. Front page: [../RESULTS.md](../RESULTS.md).

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
