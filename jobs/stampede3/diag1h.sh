#!/bin/bash
# Long runs (end 4,096,000; ~15 s): does the controller gap shrink once the start is amortised?
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/diag1; S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export NODES=4 LPS_PER_PE=128 LPC=16 CAP=180 TREE=charades-ctl AGG=pp:512 END=4096000
export WORKLOADS="gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0"
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"; H="--ctl-hist-coarse=1 --ctl-hist-waves=32"
for rep in 1 2; do
  ( export ARMS="w:250 w:300 q:0.001 q:0.0003" EXTRA_ARGS="$P $H"
    RUNS=$OUT/long $S 1 $OUT/long_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/long /" )
  ( export ARMS="q:0.001" EXTRA_ARGS="$P"
    RUNS=$OUT/longdef $S 1 $OUT/longdef_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/longdef /" )
  echo "[$(date +%T)] H REP $rep DONE"
done
echo "[$(date +%T)] DIAG1H DONE"
