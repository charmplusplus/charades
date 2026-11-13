#!/bin/bash
# Controller level and W damping (--ctl-w-gain), with the cheaper histogram (coarse, every 32nd wave).
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/diag1; S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export NODES=4 LPS_PER_PE=128 LPC=16 CAP=120 TREE=charades-ctl AGG=pp:512 END=512000
export WORKLOADS="gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0"
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"; H="--ctl-hist-coarse=1 --ctl-hist-waves=32"
cs() { ( export ARMS="$2" EXTRA_ARGS="$P $3"
    RUNS=$OUT/lvl_$1 $S 1 $OUT/lvl_$1_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
for rep in 1 2 3; do
  cs base "w:250 w:300 q:0.0003 q:0.0001" "$H"
  cs wg3 "q:0.001 q:0.0003" "$H --ctl-w-gain=0.3"
  cs wg1 "q:0.001 q:0.0003" "$H --ctl-w-gain=0.1"
  echo "[$(date +%T)] G REP $rep DONE"
done
echo "[$(date +%T)] DIAG1G DONE"
