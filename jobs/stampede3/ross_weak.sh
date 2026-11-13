#!/bin/bash
W=$WORK; out=$W/charades-runs/scaling; cd $out
module load mvapich/3.0 >/dev/null 2>&1
if [ -z "${SLURM_JOB_ID:-}" ]; then
  f=$(ls -t /tmp/idev_${USER}_bash_env.* 2>/dev/null | head -1)
  [ -n "$f" ] && source <(grep -E "^(export +|declare -x +)?SLURM_" "$f")
fi
for rep in 1 2; do
  timeout -s TERM 400 srun --mpi=pmi2 --kill-on-bad-exit=1 -N 4 -n 192 --ntasks-per-node=48 $W/ROSS/build/models/phold-gauss/phold-gauss --synch=3 --read-buffer=1 --start-events=15 --sigma=2000 --extramem=800000 --num-lps=24576 --lookahead=100 --mean=1000 --end=128000 > ross_weak_$rep.out 2>&1
  echo "ross 4x48 24576 LPs rc=$? committed $(awk '/Net Events Processed/{print $NF; exit}' ross_weak_$rep.out) M ev/s $(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' ross_weak_$rep.out) eff $(awk '/Efficiency/{print $(NF-1); exit}' ross_weak_$rep.out) time $(awk '/Running Time/{print $(NF-1); exit}' ross_weak_$rep.out)"
done
