#!/bin/bash
# srun wrapper (BIN_WRAP for ctl_sweep.sh): run the program, and sample its
# threads' scheduler statistics and the node's per-CPU interrupt time from
# /proc every 0.5 s. The sampler runs on the process's free core (core 0 for
# local task 0 = even cores, core 1 for local task 1), so it takes no PE's core.
out="${SCHED_DIR:-.}/sched.${SLURM_JOB_ID:-0}.${SLURM_STEP_ID:-0}.${SLURM_PROCID:-0}.txt"
"$@" &
pid=$!
taskset -c ${SLURM_LOCALID:-0} python3 /work2/09863/rrao/stampede3/charades-runs/schedsample.py $pid "$out" &
wait $pid; rc=$?
wait
exit $rc
