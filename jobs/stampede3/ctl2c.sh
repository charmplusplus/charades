#!/bin/bash
# After ctl2b: (1) the controller's cost with sparse waves; (2) the revised
# controller (kappa 0.20, sparse waves, histogram every 32nd wave) on every group.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/ctl2; S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export NODES=4 LPS_PER_PE=128 LPC=16 CAP=120
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
log() { echo "[$(date +%T)] $*"; }
cd $W/charades-ctl && git apply $W/charades-runs/sparse.patch && source scripts/stampede3/env.sh >/dev/null 2>&1
( make -s -C src && make -s -C models/phold/simple && make -s -C models/traffic ) > $OUT/build_c.log 2>&1 || { tail -20 $OUT/build_c.log; exit 1; }
strings models/phold/simple/phold | grep -q ctl-sparse-waves || { echo "build lacks --ctl-sparse-waves"; exit 1; }
log "built with sparse waves"
cs() { ( export TREE=$2 AGG=$3 END=$4 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="$P $7"
    RUNS=$OUT/$1 $S 1 $OUT/$1_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
HI="gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0"
LO="gauss:10:200:500 gauss:10:200:2000 steady:10:200:1.0"
PH="phases:10:200:100:1000:1.0:32000 phases:10:200:100:1000:0.5:32000"
TR="traffic:100:1000:128:15:0:0 traffic:100:1000:128:15:0.5:32"
V2="--ctl-agg-kappa=0.20 --ctl-sparse-waves=1 --ctl-hist-waves=32"
for rep in 1 2 3; do
  cs cost_b charades-ctl pp:512 512000 "$HI" "w:250 dry:250"
  cs cost_s charades-ctl pp:512 512000 "$HI" "dry:250" "--ctl-sparse-waves=1"
  cs cost_s32 charades-ctl pp:512 512000 "$HI" "dry:250" "--ctl-sparse-waves=1 --ctl-hist-waves=32"
  log "COST REP $rep DONE"
done
for rep in 1 2 3; do
  cs v2hi_b charades-ctl pp:512 512000 "$HI" "w:250 w:300"
  cs v2hi_old charades-exp pp:512 512000 "$HI" "q:0.001"
  cs v2hi charades-ctl pp:512 512000 "$HI" "q:0.001" "$V2"
  cs v2lo_b charades-ctl pp:512 128000 "$LO" "w:50"
  cs v2lo_old charades-exp pp:512 128000 "$LO" "q:0.001"
  cs v2lo charades-ctl pp:512 128000 "$LO" "q:0.001" "$V2"
  cs v2ph_b charades-ctl pp:512 256000 "$PH" "w:100"
  cs v2ph_old charades-exp pp:512 256000 "$PH" "q:0.001"
  cs v2ph charades-ctl pp:512 256000 "$PH" "q:0.001" "$V2"
  cs v2tr_b charades-ctl pp:512 512000 "$TR" "w:250 w:500"
  cs v2tr_old charades-exp pp:512 512000 "$TR" "q:0.001"
  cs v2tr charades-ctl pp:512 512000 "$TR" "q:0.001" "$V2"
  log "V2 REP $rep DONE"
done
log "CTL2C DONE"
