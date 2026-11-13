#!/bin/bash
# srun wrapper (BIN_WRAP for ctl_sweep.sh): task 0 runs under strace, one
# output file per thread (-ff), with wall-clock stamps and time spent in each
# call; other tasks run plain. Output: $ST_DIR/st.<job>.<step>.<tid>
if [ "${SLURM_PROCID:-0}" = 0 ]; then
  exec strace -f -ff -qq -tt -T -o "${ST_DIR:-.}/st.${SLURM_JOB_ID:-0}.${SLURM_STEP_ID:-0}" -- "$@"
fi
exec "$@"
