#!/bin/bash
# Stack traces of the two psm2 hangs in lci_bench_many2many_am (LCI PR #214):
#   h1: 23 threads x 23 devices, 400k msgs (pool 65,536 < 23 x 4096 recvs)
#   h2: 1 thread x 1 device, 4M msgs (psm2 only)
# Each case runs in the background; after WAIT s, gdb dumps every thread of
# each rank, and the step is cancelled.
# Usage (on the idev node): lci_hang.sh [build: new] [wait s: 25]
W=/work2/09863/rrao/stampede3; A=$W/lci_ab; B=${1:-new}; WAIT=${2:-25}
OUT=$A/hang; mkdir -p $OUT
source $W/charades-qd/scripts/stampede3/env.sh >/dev/null 2>&1
export XPORT=psm2 LCI_ATTR_OFI_PROVIDER_NAME=psm2 FI_PROVIDER=psm2 PSM2_MULTI_EP=1
export OMP_PLACES=cores OMP_PROC_BIND=close LCI_LOG_LEVEL=info
nodes=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -2 | paste -sd,)
which gdb >/dev/null || echo "no gdb on $(hostname -s)"
for c in "h1 23 23 400000" "h2 1 1 4000000"; do
  set -- $c
  srun --mpi=pmi2 --kill-on-bad-exit=1 -w $nodes -N 2 --ntasks-per-node=1 -c 48 -J hang_$1 \
    env OMP_NUM_THREADS=$2 ${EXTRA_ENV:-} $A/$B/build/bin/lci_bench_many2many_am -s 8 -n $4 -t $2 -d $3 -m 1024 \
    > $OUT/${B}_$1.out 2>&1 &
  sp=$!; sleep $WAIT
  if kill -0 $sp 2>/dev/null; then
    for n in ${nodes//,/ }; do
      ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR $n \
        "for p in \$(pgrep -f lci_bench_many2many_am); do echo \"=== $n pid \$p\"; gdb -p \$p -batch -ex 'thread apply all bt 25' 2>&1 | grep -v '^\[New LWP\|^warning'; done" \
        > $OUT/${B}_$1_stacks_$n.txt 2>&1
    done
    st=$(squeue -h -s -j $SLURM_JOB_ID -o "%i %j" | awk -v j=hang_$1 '$2==j {print $1}')
    [ -n "$st" ] && scancel $st
    echo "$1: hung after ${WAIT}s; stacks in $OUT/${B}_$1_stacks_*.txt"
  else
    echo "$1: finished: $(grep -h 'Global message rate' $OUT/${B}_$1.out)"
  fi
  wait $sp 2>/dev/null
done
