#!/bin/bash
module load mvapich/3.0 >/dev/null 2>&1
if [ -z "${SLURM_JOB_ID:-}" ]; then
  f=$(ls -t /tmp/idev_${USER}_bash_env.* 2>/dev/null | head -1)
  [ -n "$f" ] && source <(grep -E "^(export +|declare -x +)?SLURM_" "$f")
fi
mpichversion 2>/dev/null | head -4; mpiname -a 2>/dev/null | head -3
cd $WORK/charades-runs/ross
P=$WORK/ROSS/build/models/phold-gauss/phold-gauss
A="--synch=3 --num-lps=8192 --start-events=15 --lookahead=100 --mean=1000 --sigma=2000 --end=64000 --extramem=400000"
for prov in psm2 "verbs;ofi_rxm" tcp; do
  FI_PROVIDER=$prov timeout -s TERM 200 srun --mpi=pmi2 --kill-on-bad-exit=1 -N 2 -n 32 $P $A > dbg_prov.out 2>&1
  echo "FI_PROVIDER=$prov rc=$? $(grep -E 'Net Events Processed|Event Rate' dbg_prov.out | awk '{print $NF}' | tr '\n' ' ') $(grep -m1 -o 'error: .*' dbg_prov.out | cut -c1-80)"
done
