#!/bin/bash
# Where the dry controller's cost comes from: counters on every count wave vs decisions.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/diag1; S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export NODES=4 LPS_PER_PE=128 LPC=16 CAP=120 TREE=charades-ctl AGG=pp:512 END=512000
export WORKLOADS="gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0"
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
cs() { ( export ARMS="$2" EXTRA_ARGS="$P $3"
    RUNS=$OUT/src_$1 $S 1 $OUT/src_$1_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
for rep in 1 2 3; do
  cs base "w:300 dry:300 drysep:300"
  cs nodecide "dry:300" "--ctl-hist-waves=1000000 --ctl-interval=1000000"
  echo "[$(date +%T)] F REP $rep DONE"
done
echo "[$(date +%T)] DIAG1F DONE"
