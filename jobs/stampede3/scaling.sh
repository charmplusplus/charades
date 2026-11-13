#!/bin/bash
# Charades weak scaling on 4 nodes (128 LPs per PE): where does it stop?
cd $WORK/charades-qd && source scripts/stampede3/env.sh
export RUNS=$WORK/charades-runs/scaling TREE=charades-qd MARGINS=8 AGG=pp:64 END=128000 \
  WORKLOADS="gauss:100:1000:2000" ARMS="w:250"
S=scripts/stampede3/ctl_sweep.sh
for shape in "2 8" "2 16" "2 24" "4 12" "8 6"; do
  set -- $shape
  PPN=$1 PEPP=$2 $S 2 $RUNS/ppn$1_pe$2.csv
done
# direct sends at 64 and 192 PEs, for the per-message cost side
AGG=off PPN=2 PEPP=8 $S 1 $RUNS/off_ppn2_pe8.csv
AGG=off PPN=2 PEPP=24 $S 1 $RUNS/off_ppn2_pe24.csv
echo SCALING DONE
