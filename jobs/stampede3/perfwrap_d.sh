#!/bin/bash
# perfwrap.sh with a start delay: record only after PERF_DELAY_MS (skip setup)
if [ "${SLURM_PROCID:-0}" = 0 ]; then
  exec perf record -q -e cycles:u -F 1999 -D ${PERF_DELAY_MS:-9500} \
      -o "${PERF_DIR:-.}/perf.${SLURM_JOB_ID:-0}.${SLURM_STEP_ID:-0}.data" -- "$@"
fi
exec "$@"
