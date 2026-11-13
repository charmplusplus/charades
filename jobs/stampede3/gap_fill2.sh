#!/bin/bash
# Extend the gap-fill sweeps: Devastator's best fixed W was at the top of the grid;
# Charades' grid had no point between 100, 250 and 500.
W=$WORK; out=$W/charades-runs/gapfill
cd $W/charades-qd || exit 1
source scripts/stampede3/env.sh
export RUNS=$out TREE=charades-qd MARGINS=8 AGG=pp:64 PPN=2 PEPP=24 LPS_PER_PE=128 LPC=16
END=512000 WORKLOADS="gauss:100:1000:2000" ARMS="w:175 w:350" scripts/stampede3/ctl_sweep.sh 2 $out/charades_weak_512k_b.csv
echo CHARADES DONE
D=$W/devastator; C=ofi-psm2
for rep in 1 2; do
  for w in 2000 4000 8000; do
    WINDOW=$w END=512000 SIGMA=2000 RUNS=$out bash $D/run_phold.sh $D/bin/$C/phold-gauss-p8w8 4
    WINDOW=$w END=512000 SIGMA=2000 LPS_PER_RANK=128 RUNS=$out bash $D/run_phold.sh $D/bin/$C/phold-gauss-p8w23 4
  done
  for w in 200 400 800; do
    WINDOW=$w END=128000 SIGMA=2000 LOOKAHEAD=10 MEAN=200 RUNS=$out bash $D/run_phold.sh $D/bin/$C/phold-gauss-p8w8 4
  done
done
echo ALL DONE
