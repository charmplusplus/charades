#!/bin/bash
if [ "${SLURM_PROCID:-0}" = 0 ]; then
  exec perf record -q -e cycles:u -F 999 -g -o "${PERF_DIR:-.}/perf.${SLURM_JOB_ID:-0}.${SLURM_STEP_ID:-0}.data" -- "$@"
fi
exec "$@"
