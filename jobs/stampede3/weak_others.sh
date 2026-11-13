#!/bin/bash
# ROSS and Devastator on the weak-scaled problem (about 128 LPs per core, 4 full nodes)
W=$WORK; out=$W/charades-runs/scaling; cd $out
D=$W/devastator
END=128000 SIGMA=2000 LPS_PER_RANK=128 RUNS=$out bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p8w23 4
END=128000 SIGMA=2000 LPS_PER_RANK=128 WINDOW=250 RUNS=$out bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p8w23 4
module load mvapich/3.0 >/dev/null 2>&1
unset FI_PROVIDER FI_PROVIDER_PATH
export LD_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | tr : '\n' | grep -v libfabric_ | paste -sd:)
for rep in 1 2; do
  timeout -s TERM 400 srun --mpi=pmi2 --kill-on-bad-exit=1 -N 4 -n 192 --ntasks-per-node=48 $W/ROSS/build/models/phold-gauss/phold-gauss --synch=3 --read-buffer=1 --start-events=15 --sigma=2000 --extramem=800000 --num-lps=24576 --lookahead=100 --mean=1000 --end=128000 > ross_weak_$rep.out 2>&1
  echo "ross 4x48 24576 LPs rc=$? committed $(awk '/Net Events Processed/{print $NF; exit}' ross_weak_$rep.out) M ev/s $(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' ross_weak_$rep.out) eff $(awk '/Efficiency/{print $(NF-1); exit}' ross_weak_$rep.out)"
done
echo WEAK DONE
grep -h PHOLD_GAUSS_RESULT $out/*.out | grep "num_lps=23552" | grep -oE "window=[a-z0-9]+|committed=[0-9]+|efficiency=[0-9.]+|wall_s=[0-9.]+|committed_per_s=[0-9.e+]+" | paste - - - - -
