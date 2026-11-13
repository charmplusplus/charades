#!/bin/bash
# Controller machinery cost on full nodes: dry runs (W fixed 300) with the
# histogram coarse and/or on fewer count waves; the controller with the cheapest.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/diag1; S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export NODES=4 LPS_PER_PE=128 LPC=16 CAP=120 TREE=charades-ctl AGG=pp:512 END=512000
export WORKLOADS="gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0"
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
cs() { # tag arms extra
  ( export ARMS="$2" EXTRA_ARGS="$P $3"
    RUNS=$OUT/cost_$1 $S 1 $OUT/cost_$1_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
for rep in 1 2 3; do
  cs base "w:300 dry:300"
  cs h32 "dry:300" "--ctl-hist-waves=32"
  cs coarse "dry:300" "--ctl-hist-coarse=1"
  cs c32 "dry:300 q:0.001" "--ctl-hist-coarse=1 --ctl-hist-waves=32"
  cs c32g "q:0.001 q:0.0005" "--ctl-hist-coarse=1 --ctl-hist-waves=32 --ctl-alpha-gain=0.1"
  echo "[$(date +%T)] E REP $rep DONE"
done
echo "[$(date +%T)] DIAG1E DONE"
