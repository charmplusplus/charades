#!/bin/bash
# Fill the three-engine table's gaps (2026-10-21, second allocation):
#  1. Charades weak-scaled on full nodes (4 x 2 x 24 PEs, 128 LPs/PE, 24,576 LPs):
#     a fixed-W sweep (so "best fixed W" is measured) and the controller.
#  2. Devastator with fixed windows at 64 cores (both slacks) and on full nodes.
#  3. ROSS weak-scaled at the longer end time.
W=$WORK; out=$W/charades-runs/gapfill; mkdir -p $out
cd $W/charades-qd || exit 1
source scripts/stampede3/env.sh
srun -N 4 --ntasks-per-node=1 --mpi=none bash $W/charades-runs/stage_libfabric.sh || exit 1
source scripts/stampede3/env.sh
echo "tree $(git log --oneline -1)"
make -s -C src -j24 >/dev/null && make -s -C models/phold/simple >/dev/null || { echo BUILD FAILED; exit 1; }
ls -la models/phold/simple/phold
export RUNS=$out TREE=charades-qd MARGINS=8 AGG=pp:64 PPN=2 PEPP=24 LPS_PER_PE=128 LPC=16
S=scripts/stampede3/ctl_sweep.sh
END=128000 WORKLOADS="gauss:100:1000:2000" ARMS="w:100 w:250 w:500 w:1000 q:0.003 q:0.001" $S 2 $out/charades_weak_128k.csv
END=512000 WORKLOADS="gauss:100:1000:2000" ARMS="w:100 w:250 w:500 w:1000 q:0.003 q:0.001 hill:250" $S 2 $out/charades_weak_512k.csv
echo CHARADES DONE
D=$W/devastator; C=ofi-psm2
for rep in 1 2; do
  for w in 250 500 1000; do
    WINDOW=$w END=512000 SIGMA=2000 RUNS=$out bash $D/run_phold.sh $D/bin/$C/phold-gauss-p8w8 4
  done
  for w in 25 50 100; do
    WINDOW=$w END=128000 SIGMA=2000 LOOKAHEAD=10 MEAN=200 RUNS=$out bash $D/run_phold.sh $D/bin/$C/phold-gauss-p8w8 4
  done
  for w in 100 250 500 1000; do
    WINDOW=$w END=512000 SIGMA=2000 LPS_PER_RANK=128 RUNS=$out bash $D/run_phold.sh $D/bin/$C/phold-gauss-p8w23 4
  done
done
for w in 100 500 1000; do
  WINDOW=$w END=128000 SIGMA=2000 LPS_PER_RANK=128 RUNS=$out bash $D/run_phold.sh $D/bin/$C/phold-gauss-p8w23 4
done
echo DEVA DONE
module load mvapich/3.0 >/dev/null 2>&1
unset FI_PROVIDER FI_PROVIDER_PATH
export LD_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | tr : '\n' | grep -v libfabric_ | paste -sd:)
cd $out
for rep in 1 2; do
  timeout -s TERM 400 srun --mpi=pmi2 --kill-on-bad-exit=1 -N 4 -n 192 --ntasks-per-node=48 $W/ROSS/build/models/phold-gauss/phold-gauss --synch=3 --read-buffer=1 --start-events=15 --sigma=2000 --extramem=800000 --num-lps=24576 --lookahead=100 --mean=1000 --end=512000 > ross_weak512k_$rep.out 2>&1
  echo "ross 4x48 24576 LPs end 512000 rc=$? committed $(awk '/Net Events Processed/{print $NF; exit}' ross_weak512k_$rep.out) M ev/s $(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' ross_weak512k_$rep.out) eff $(awk '/Efficiency/{print $(NF-1); exit}' ross_weak512k_$rep.out)"
done
echo ALL DONE
