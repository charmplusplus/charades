#!/bin/bash
# Revised controller: direct sends (kappa off; sparse waves and histogram every
# 32nd wave still apply) and 15 s runs with long delays.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/ctl2; S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export NODES=4 LPS_PER_PE=128 LPC=16 CAP=120
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
log() { echo "[$(date +%T)] $*"; }
cs() { ( export TREE=$2 AGG=$3 END=$4 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="$P $7"
    RUNS=$OUT/$1 $S 1 $OUT/$1_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
V2="--ctl-agg-kappa=0.20 --ctl-sparse-waves=1 --ctl-hist-waves=32"
for rep in 1 2 3; do
  cs v2dhi_b charades-ctl off 512000 "gauss:100:1000:2000 steady:100:1000:1.0" "w:250 w:500"
  cs v2dhi_old charades-exp off 512000 "gauss:100:1000:2000 steady:100:1000:1.0" "q:0.001"
  cs v2dhi charades-ctl off 512000 "gauss:100:1000:2000 steady:100:1000:1.0" "q:0.001" "$V2"
  cs v2dlo_b charades-ctl off 128000 "steady:10:200:1.0 gauss:10:200:500" "w:50 w:100"
  cs v2dlo_old charades-exp off 128000 "steady:10:200:1.0 gauss:10:200:500" "q:0.001"
  cs v2dlo charades-ctl off 128000 "steady:10:200:1.0 gauss:10:200:500" "q:0.001" "$V2"
  log "D REP $rep DONE"
done
for rep in 1 2; do
  WL="gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0"
  cs v2long_b charades-ctl pp:512 4096000 "$WL" "w:250"
  cs v2long charades-ctl pp:512 4096000 "$WL" "q:0.001" "$V2"
  log "D LONG REP $rep DONE"
done
log "CTL2D DONE"
