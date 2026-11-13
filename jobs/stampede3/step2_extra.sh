#!/bin/bash
# (a) Event share 0.001 with the floor guard, 16 PEs per node (the time share
#     failed: kappa 0.3-1.0); (b) full nodes: full vs. coarse histogram and a
#     looser event share (the rollback floor there is ~0.5%)
cd $WORK/charades-qd && source scripts/stampede3/env.sh
export RUNS=$WORK/charades-runs/step2 TREE=charades-qd MARGINS=8
S=scripts/stampede3/ctl_sweep.sh
END=256000 AGG=pp:64 WORKLOADS="gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0" \
  ARMS="qev:0.001" $S 2 $RUNS/ev001_hi.csv
END=64000 AGG=pp:64 WORKLOADS="gauss:10:200:2000 steady:10:200:1.0" ARMS="qev:0.001" $S 2 $RUNS/ev001_lo.csv
PPN=2 PEPP=24 LPS_PER_PE=44 LPC=4 END=64000 AGG=pp:64 WORKLOADS="gauss:100:1000:2000" \
  ARMS="qs8:0.003 qsc8:0.003 qs8:0.01 qsc8:0.01" EXTRA_ARGS="+lci_ndevices 8 --ctl-cost=0 --ctl-log=1" \
  $S 2 $RUNS/full_extra.csv
echo EXTRA DONE
