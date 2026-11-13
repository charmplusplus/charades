#!/bin/bash
# The controller and W 250 side by side on the best layout (2 x 23 pinned, ndev 4)
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/rtsweep2; mkdir -p $OUT
cd $W/charades-qd && source scripts/stampede3/env.sh
export TREE=charades-prod MARGINS=8 AGG=pp:64 LPS_PER_PE=128 LPC=16 END=512000 WORKLOADS="gauss:100:1000:2000" \
  PPN=2 PEPP=23 CPT=24 EXTRA_ARGS="+lci_ndevices 4 +pemap 2-46:2,3-47:2" ARMS="w:250 q:0.003 w:300 q:0.001"
RUNS=$OUT/ctl $W/charades-qd/scripts/stampede3/ctl_sweep.sh 3 $OUT/ctl_best.csv | grep -E " (ok|fail|stall) "
echo SWEEP3 DONE
