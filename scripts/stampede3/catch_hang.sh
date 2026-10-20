#!/bin/bash
# Rerun one case until a run hangs, then save gdb stacks of every thread on
# every node it ran on, and cancel it.
# Usage (on the idev master): catch_hang.sh <reps> <cap s> <N> <procs> <pes>
#          <model dir> <model cfg> <test cfg> [extra phold args...]
#   e.g. catch_hang.sh 50 30 2 2 16 phold/imbalanced combo agg_bucket_pp
# Model cfg and test cfg are names under the tree's model test_configs and
# tests/test_configs. TREE=charades-qd (default) picks the build.
reps=$1 cap=$2 N=$3 n=$4 pe=$5 model=$6 mcfg=$7 tcfg=$8; shift 8
source "$(dirname "$0")/env.sh"
C=$WORK/${TREE:-charades-qd}
exe=$C/models/$model/$(basename $model); [ -x $exe ] || exe=$C/models/$model/phold
out=${RUNS:-$WORK/charades-runs}/hang/$(basename $model)_${mcfg}_${tcfg}_${n}x$((pe / n))
mkdir -p $out; cd $out
for rep in $(seq $reps); do
  srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -N $N -n $n -c $((pe / n)) -J hang_$rep \
      stdbuf -oL -eL $exe +pe $pe $C/models/$model/test_configs/$mcfg $C/tests/test_configs/$tcfg "$@" \
      > run.out 2>&1 &
  sp=$! t0=$(date +%s)
  while kill -0 $sp 2>/dev/null && [ $(( $(date +%s) - t0 )) -lt $cap ]; do sleep 0.2; done
  if ! kill -0 $sp 2>/dev/null; then
    wait $sp; rc=$?
    grep -q Successfully run.out && [ $rc = 0 ] || { echo "rep $rep: FAILED rc=$rc"; cp run.out fail.$rep.out; }
    continue
  fi
  echo "rep $rep: still running after ${cap}s; output tail:"; tail -n 3 run.out
  nodes=$(squeue -h -s -j $SLURM_JOB_ID -o "%j %N" | awk -v j=hang_$rep '$1==j {print $2}')
  for node in $(scontrol show hostnames $nodes); do
    ssh -o "StrictHostKeyChecking no" -o LogLevel=ERROR $node \
      'for p in $(pgrep -u $USER -f "models/.*/test_configs"); do echo "=== $(hostname -s) pid $p"; gdb -p $p -batch -ex "set pagination off" -ex "thread apply all bt 40" 2>/dev/null | grep -E "^Thread|^#"; done' > stacks.$node 2>&1
  done
  cp run.out hang.$rep.out; wc -l stacks.*
  st=$(squeue -h -s -j $SLURM_JOB_ID -o "%i %j" | awk -v j=hang_$rep '$2==j {print $1}')
  [ -n "$st" ] && scancel $st
  wait $sp 2>/dev/null
  echo "stacks in $out"; exit 1
done
echo "no hang in $reps runs"
