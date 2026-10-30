#!/bin/bash
# numabind.sh: run a program with its CPUs and memory on NUMA node
# SLURM_LOCALID, for 2 processes per Stampede3 SKX node (node 0 = socket 0,
# even cores; node 1 = socket 1, odd cores; +pemap 2-46:2,3-47:2 puts process
# 0's PEs on even cores). Every allocation, including the main thread's before
# the PEs are pinned, then comes from the process's own socket, and automatic
# NUMA balancing skips the process (a non-default memory policy).
# For ctl_sweep.sh: BIN_WRAP=$PWD/numabind.sh. RESULTS.md section 163.
n=${SLURM_LOCALID:-0}
if [ "${SLURM_PROCID:-0}" -lt 2 ]; then
  echo "numabind: task ${SLURM_PROCID:-0} on $(hostname -s): $(numactl --cpunodebind=$n --membind=$n numactl --show | grep -E '^(policy|cpubind|membind)' | tr '\n' ' ')" >&2
fi
exec numactl --cpunodebind=$n --membind=$n "$@"
