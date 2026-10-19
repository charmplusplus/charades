#!/bin/bash
# Reproduce the bucketed-GVT hang (Gaussian PHOLD sigma=2000, 2 processes x
# 8 PEs over 2 nodes) and dump all thread stacks on both nodes after WAIT s.
# Usage: hang_stacks.sh [wait] [extra phold args...]   (on the idev master)
wait=${1:-40}; shift
source "$(dirname "$0")/env.sh"
C=$WORK/charades
out=${RUNS:-$WORK/charades-runs}/hang; mkdir -p $out; cd $out; rm -f stacks.* run.out
srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -N 2 -n 2 -c 8 \
    stdbuf -oL -eL $C/models/phold/simple/phold +pe 16 \
    ${RUNS:-$WORK/charades-runs}/gvt_cost/gauss_2000 $C/tests/test_configs/bucket "$@" > run.out 2>&1 &
sp=$!
for i in $(seq $wait); do sleep 1; kill -0 $sp 2>/dev/null || { echo "finished after $i s"; tail -n 3 run.out; exit 0; }; done
echo "still running after $wait s; last progress:"; grep "^GVT" run.out | tail -n 2
for n in $(scontrol show hostnames $SLURM_JOB_NODELIST); do
    ssh -o "StrictHostKeyChecking no" -o LogLevel=ERROR $n \
        'for p in $(pgrep -u $USER -x phold); do echo "=== $(hostname -s) pid $p"; gdb -p $p -batch -ex "set pagination off" -ex "thread apply all bt 40" 2>/dev/null | grep -E "^Thread|^#"; done' > stacks.$n 2>&1
done
wc -l stacks.*
kill -TERM $sp; sleep 35; kill -0 $sp 2>/dev/null && { echo "srun still alive; scancel the step"; scancel $SLURM_JOB_ID.$(squeue -h -s -j $SLURM_JOB_ID -o %i | grep -v batch | tail -1 | cut -d. -f2); }
wait $sp 2>/dev/null; echo done
