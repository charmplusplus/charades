#!/bin/bash
module load mvapich/3.0 >/dev/null 2>&1
if [ -z "${SLURM_JOB_ID:-}" ]; then
  f=$(ls -t /tmp/idev_${USER}_bash_env.* 2>/dev/null | head -1)
  [ -n "$f" ] && source <(grep -E "^(export +|declare -x +)?SLURM_" "$f")
fi
export FI_PROVIDER="verbs;ofi_rxm"
cd $WORK/charades-runs/ross
P=$WORK/ROSS/build/models/phold-gauss/phold-gauss
run() {  # label N n lps args
  local l=$1 N=$2 n=$3 lps=$4; shift 4
  timeout -s TERM 200 srun --mpi=pmi2 --kill-on-bad-exit=1 -N $N -n $n $P --num-lps=$lps --start-events=15 --lookahead=100 --mean=1000 --sigma=2000 --end=64000 --extramem=400000 "$@" > d3_$l.out 2>&1
  echo "$l rc=$? committed/rate/eff: $(grep -E 'Net Events Processed|Event Rate|^\s*Efficiency' d3_$l.out | awk '{print $(NF-1)=="Efficiency"?$NF:$NF}' | tr '\n' ' ') $(grep -m1 -o 'error: .*' d3_$l.out | cut -c1-70)"
}
run opt_4x64_a 4 64 8192 --synch=3
run opt_4x64_b 4 64 8192 --synch=3
run cons_4x64 4 64 8192 --synch=2
run opt_4x192 4 192 8448 --synch=3
run cons_4x192 4 192 8448 --synch=2
