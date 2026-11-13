#!/bin/bash
# srun wrapper (BIN_WRAP for ctl_sweep.sh): task 0 runs under perf, sampling
# every ${PF_PERIOD:-100}th user page fault with a DWARF call stack, every
# thread; other tasks run plain. Output: $PERF_DIR/pf.<job>.<step>.data
if [ "${SLURM_PROCID:-0}" = 0 ]; then
  exec perf record -q -e page-faults:u -c ${PF_PERIOD:-100} --call-graph dwarf,8192 \
      -o "${PERF_DIR:-.}/pf.${SLURM_JOB_ID:-0}.${SLURM_STEP_ID:-0}.data" -- "$@"
fi
exec "$@"
