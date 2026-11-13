#!/bin/bash
# srun wrapper (BIN_WRAP for ctl_sweep.sh): task 0 runs under strace, futex
# calls only, with a call stack for each (-k), one file per thread; other
# tasks run plain. Output: $ST_DIR/sk.<job>.<step>.<tid>
if [ "${SLURM_PROCID:-0}" = 0 ]; then
  exec strace -f -ff -k -qq -tt -T -e trace=futex -o "${ST_DIR:-.}/sk.${SLURM_JOB_ID:-0}.${SLURM_STEP_ID:-0}" -- "$@"
fi
exec "$@"
