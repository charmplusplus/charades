#!/bin/bash
# Controller W traces (--ctl-log=1) next to the fixed W at its mean; follows diag1.sh.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/diag1; S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export NODES=4 LPS_PER_PE=128 LPC=16 CAP=120
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
for rep in 1 2; do
  ( export AGG=pp:512 END=512000 WORKLOADS="gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0" ARMS="q:0.001 q:0.0003" EXTRA_ARGS="$P --ctl-log=1"
    RUNS=$OUT/ctl_trace_r$rep $S 1 $OUT/ctl_trace_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/trace /" )
done
echo "[$(date +%T)] DIAG1B DONE"
