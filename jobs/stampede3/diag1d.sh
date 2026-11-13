#!/bin/bash
# Controller fixes: warm start (--ctl-warm) and slower calibration (--ctl-alpha-gain),
# against fixed W and dry runs, on charades-ctl (charades-exp + the two options).
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/diag1; S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export NODES=4 LPS_PER_PE=128 LPC=16 CAP=120 TREE=charades-ctl AGG=pp:512 END=512000
export WORKLOADS="gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0"
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
cs() { # tag arms extra
  ( export ARMS="$2" EXTRA_ARGS="$P $3"
    RUNS=$OUT/fix_$1 $S 1 $OUT/fix_$1_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
for rep in 1 2 3; do
  cs base "w:250 w:300 dry:300 q:0.001"
  cs warm "q:0.001" "--ctl-warm=4"
  cs warmg "q:0.001 q:0.0005" "--ctl-warm=4 --ctl-alpha-gain=0.1"
  cs g "q:0.001" "--ctl-alpha-gain=0.1"
  echo "[$(date +%T)] D REP $rep DONE"
done
echo "[$(date +%T)] DIAG1D DONE"
