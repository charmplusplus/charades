#!/bin/bash
module load mvapich/3.0 >/dev/null 2>&1
if [ -z "${SLURM_JOB_ID:-}" ]; then
  f=$(ls -t /tmp/idev_${USER}_bash_env.* 2>/dev/null | head -1)
  [ -n "$f" ] && source <(grep -E "^(export +|declare -x +)?SLURM_" "$f")
fi
echo "job $SLURM_JOB_ID, mpicc $(which mpicc)"
cd $WORK/charades-runs/ross
P=$WORK/ROSS/build/models/phold-gauss/phold-gauss
A="--synch=3 --num-lps=8192 --start-events=15 --lookahead=100 --mean=1000 --sigma=2000 --end=64000 --extramem=400000"
for shape in "1 16" "4 64" "4 192"; do
  set -- $shape
  t0=$(date +%s.%N)
  timeout -s TERM 300 srun --mpi=pmi2 --kill-on-bad-exit=1 -N $1 -n $2 $P $A > ross_${1}x$2.out 2>&1
  rc=$?
  echo "N=$1 ranks=$2 rc=$rc wall=$(echo "$(date +%s.%N) - $t0" | bc)"
  grep -E "Net Events Processed|Event Rate|Efficiency|Running Time|Total Remote|rror" ross_${1}x$2.out | head -8
done
