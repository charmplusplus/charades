#!/bin/bash
# Validate epsilon 0.0003 and the histogram on every 32nd wave where they might throttle:
# phase-changing PHOLD, low slack, direct sends. Anchors: each workload's best fixed W in job 3629781.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/diag1; S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export NODES=4 LPS_PER_PE=128 LPC=16 CAP=120 TREE=charades-ctl
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"; H="--ctl-hist-waves=32"
cs() { # tag agg end workloads arms extra
  ( export AGG=$2 END=$3 WORKLOADS="$4" ARMS="$5" EXTRA_ARGS="$P $6"
    RUNS=$OUT/val_$1 $S 1 $OUT/val_$1_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
PH="phases:10:200:100:1000:1.0:32000 phases:10:200:100:1000:0.5:32000"
LO="gauss:10:200:500 gauss:10:200:2000 steady:10:200:1.0"
HI="gauss:100:1000:2000 steady:100:1000:1.0"
for rep in 1 2 3; do
  cs ph pp:512 256000 "$PH" "w:50 w:100 q:0.001"
  cs ph_h pp:512 256000 "$PH" "q:0.001 q:0.0003" "$H"
  cs lo pp:512 128000 "$LO" "w:50 w:100 q:0.001"
  cs lo_h pp:512 128000 "$LO" "q:0.001 q:0.0003" "$H"
  cs off off 512000 "$HI" "w:250 w:500 q:0.001"
  cs off_h off 512000 "$HI" "q:0.001 q:0.0003" "$H"
  echo "[$(date +%T)] I REP $rep DONE"
done
echo "[$(date +%T)] DIAG1I DONE"
