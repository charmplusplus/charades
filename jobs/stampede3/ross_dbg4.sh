#!/bin/bash
module load mvapich/3.0 >/dev/null 2>&1
if [ -z "${SLURM_JOB_ID:-}" ]; then
  f=$(ls -t /tmp/idev_${USER}_bash_env.* 2>/dev/null | head -1)
  [ -n "$f" ] && source <(grep -E "^(export +|declare -x +)?SLURM_" "$f")
fi
unset FI_PROVIDER
cd $WORK/charades-runs/ross
P=$WORK/ROSS/build/models/phold-gauss/phold-gauss
run() {  # label N n lps lookahead mean args
  local l=$1 N=$2 n=$3 lps=$4 la=$5 mean=$6; shift 6
  timeout -s TERM 240 srun --mpi=pmi2 --kill-on-bad-exit=1 -N $N -n $n $P --num-lps=$lps --start-events=15 --lookahead=$la --mean=$mean --sigma=2000 --end=64000 --extramem=400000 "$@" > d4_$l.out 2>&1
  echo "$l rc=$? committed, M ev/s: $(grep -E 'Net Events Processed' d4_$l.out | awk '{print $NF}') $(grep -E 'Event Rate' d4_$l.out | awk '{printf "%.2f", $NF/1e6}') $(grep -m1 -o 'error: .*' d4_$l.out | cut -c1-70)"
}
run cons_hi_4x64_b 4 64 8192 100 1000 --synch=2
run cons_hi_4x192 4 192 8448 100 1000 --synch=2
run cons_lo_4x64 4 64 8192 10 200 --synch=2
run cons_lo_4x192 4 192 8448 10 200 --synch=2
