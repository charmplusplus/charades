#!/bin/bash
# perfwrap.sh: run a program under `perf record` in task 0 of an srun step
# only (user-space cycles, 1999 Hz, every thread); other tasks run it plain.
# For ctl_sweep.sh: BIN_WRAP="$PWD/perfwrap.sh". Output: $PERF_DIR/perf.<job>.<step>.data
if [ "${SLURM_PROCID:-0}" = 0 ]; then
  exec perf record -q -e cycles:u -F 1999 \
      -o "${PERF_DIR:-.}/perf.${SLURM_JOB_ID:-0}.${SLURM_STEP_ID:-0}.data" -- "$@"
fi
exec "$@"
