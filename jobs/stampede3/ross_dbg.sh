#!/bin/bash
module load mvapich/3.0 >/dev/null 2>&1
if [ -z "${SLURM_JOB_ID:-}" ]; then
  f=$(ls -t /tmp/idev_${USER}_bash_env.* 2>/dev/null | head -1)
  [ -n "$f" ] && source <(grep -E "^(export +|declare -x +)?SLURM_" "$f")
fi
cd $WORK/charades-runs/ross
P=$WORK/ROSS/build/models/phold-gauss/phold-gauss
A="--num-lps=8192 --start-events=15 --lookahead=100 --mean=1000 --sigma=2000 --end=64000 --extramem=400000"
run() {  # label N n args
  local l=$1 N=$2 n=$3; shift 3
  timeout -s TERM 300 srun --mpi=pmi2 --kill-on-bad-exit=1 -N $N -n $n $P $A "$@" > dbg_$l.out 2>&1
  echo "$l rc=$? $(grep -E 'Net Events Processed|Event Rate' dbg_$l.out | awk '{print $NF}' | tr '\n' ' ') $(grep -m1 -o 'error: .*' dbg_$l.out | cut -c1-90)"
}
run opt_1x64 1 64 --synch=3          # same rank count, one node
run opt_2x32 2 32 --synch=3
run opt_4x64_r2 4 64 --synch=3
run cons_4x64 4 64 --synch=2
run seq_1x1 1 1 --synch=1
