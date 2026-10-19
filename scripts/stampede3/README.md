# Stampede3 helpers

For running Charades on TACC Stampede3 (Omni-Path) inside an `idev`
allocation. See `CONTEXT.md` at the top of the repository for the build.

- `env.sh` — source before every run: LCI over libfabric `verbs;ofi_rxm`,
  libfabric 2.7.0 from node-local `/tmp` if staged, and (in an ssh shell on
  the idev node) the job's `SLURM_*` variables from idev's environment file,
  so `srun` works as it does at the idev prompt.
- `stage_libfabric.sh` — copy libfabric 2.7.0 from `$WORK/libfabric-2.7.0`
  to this node's `/tmp`; run once per node per job.
- `nd [node] '<command>'` — run a command on the idev job's first node (or
  the one named) from the login node, in a login shell with TACC's module
  tree, gcc 13.2.0 and cmake loaded. Plain ssh shells there lack TACC's
  `MODULEPATH`, so `module load gcc/13.2.0` silently does nothing.
- `repro.sh <reps> <procs> <pes> <model dir> <model cfg> <test cfg> [tree]` —
  rerun one case until it fails, with cores enabled.
- `ab_qd.sh <reps> [model cfg]` — time conservative and blocking-GVT PHOLD
  linked against two Charm++ trees (`$WORK/charades` and `$WORK/charades-qd`,
  the latter built on Reconverse `idle-progress-poll`), alternating them.

Outputs go under `$RUNS` (default `$WORK/charades-runs`).
- `gvt_cost.sh <reps>` — blocking vs. bucketed GVT (bucket size 8 and 256)
  on a 4,096-LP Gaussian PHOLD at σ = 100 and 2000, 2 × 8 and 16 × 1 PEs
  over 2 nodes. Writes its configs to `$RUNS/gvt_cost/`.
- `try.sh <cap s> <N> <procs> <pes> <label> -- <phold args>` — one capped
  run (`TREE=charades-qd` for the other build); on timeout it cancels the
  step with `scancel` instead of SIGKILLing `srun`, which would orphan it.
- `hang_stacks.sh [wait s] [phold args]` — reproduce the σ = 2000 bucketed
  hang (needs `gvt_cost.sh`'s configs) and save gdb stacks of every thread on
  every node to `$RUNS/hang/stacks.<node>`.
- `window_sweep.sh <reps> [out.csv]` — blocking vs. bucketed vs. bucketed
  with `--optimism-window` on Gaussian PHOLD, over σ, window and node count
  (knobs in the header); one CSV row per run, stalled runs cancelled at
  `CAP` seconds. `window_summary.py <csv...>` prints medians per case.
