#!/bin/bash
# --ctl-floor A/B: the quantile controller (eps 0.003) calibrated on all
# rollbacks (=0) or only on window stragglers (=1), against the best fixed W,
# interleaved by rep. Fast stack: charades-exp bc5055d, psm2 64 KB.
# Usage: floor_ab.sh <reps>
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/floor_ab; mkdir -p $OUT
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-exp MARGINS=8 LPS_PER_PE=128 LPC=16 NODES=4 PPN=2 CPT=24 CAP=90 XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536
HI="gauss:100:1000:100 gauss:100:1000:1000 gauss:100:1000:4000 steady:100:1000:1.0"
P64="+lci_ndevices 8 +pemap 2-16:2,3-17:2"; PFULL="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
sweep() { # tag pepp agg end workloads arms extra
  ( export PEPP=$2 AGG=$3 END=$4 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="$7"
    RUNS=$OUT/$1 $S 1 $OUT/$1_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
for rep in $(seq 1 ${1:-3}); do
  sweep hi_f0 8 pp:256 512000 "$HI" "w:250 q:0.003" "$P64"
  sweep hi_f1 8 pp:256 512000 "$HI" "q:0.003" "$P64 --ctl-floor=1"
  sweep lo_f0 8 pp:256 128000 "gauss:10:200:2000" "w:50 q:0.003" "$P64"
  sweep lo_f1 8 pp:256 128000 "gauss:10:200:2000" "q:0.003" "$P64 --ctl-floor=1"
  sweep full_f0 23 pp:512 512000 "gauss:100:1000:2000" "w:250 q:0.003" "$PFULL"
  sweep full_f1 23 pp:512 512000 "gauss:100:1000:2000" "q:0.003" "$PFULL --ctl-floor=1"
  echo "REP $rep DONE"
done
echo FLOORAB DONE
