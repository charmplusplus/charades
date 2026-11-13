#!/bin/bash
# srun wrapper for job G (BIN_WRAP for ctl_sweep.sh). Env:
#   G_NUMA=1   bind each process's memory to its socket (numactl --membind)
#   G_PERF=1   task 0 runs under perf record -e page-faults:u -c 1 (every user-mode fault, no stacks)
#   G_SAMPLE=full|light|none   /proc sampler (schedsample.py; light = stat only, 1 s)
# Output in $SCHED_DIR.
cmd=("$@")
[ "${G_NUMA:-0}" = 1 ] && cmd=(numactl --membind=${SLURM_LOCALID:-0} "${cmd[@]}")
if [ "${G_PERF:-0}" = 1 ] && [ "${SLURM_PROCID:-0}" = 0 ]; then
  perf record -q -e page-faults:u -c 1 -o "${SCHED_DIR:-.}/pf.${SLURM_JOB_ID:-0}.${SLURM_STEP_ID:-0}.data" -- "${cmd[@]}" &
  ppid=$!; pid=
  for i in $(seq 100); do pid=$(pgrep -P $ppid | head -1); [ -n "$pid" ] && break; sleep 0.05; done
else
  "${cmd[@]}" &
  ppid=$!; pid=$ppid
fi
# numactl execs the program, so its pid is the program's
out="${SCHED_DIR:-.}/sched.${SLURM_JOB_ID:-0}.${SLURM_STEP_ID:-0}.${SLURM_PROCID:-0}.txt"
if [ "${G_SAMPLE:-none}" != none ] && [ -n "$pid" ]; then
  SCHED_MODE=$G_SAMPLE taskset -c ${SLURM_LOCALID:-0} python3 /work2/09863/rrao/stampede3/charades-runs/schedsample.py $pid "$out" &
fi
wait $ppid; rc=$?
wait
exit $rc
