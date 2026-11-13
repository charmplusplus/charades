#!/bin/bash
# The 2026-10-21 Gaussian PHOLD sigma sweep on the fast stack: charades-exp,
# native psm2 (64 KB packets, 8 devices), pinned 2 x 8 PEs per node, 4 nodes;
# direct sends against htram PP 256. Reps outermost so partial runs are whole.
# Usage: gauss2.sh <first rep> <last rep>
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/gauss2; mkdir -p $OUT
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-exp MARGINS=8 LPS_PER_PE=128 LPC=16 NODES=4 PPN=2 PEPP=8 CPT=24 CAP=90
HI="gauss:100:1000:100 gauss:100:1000:500 gauss:100:1000:1000 gauss:100:1000:2000 gauss:100:1000:4000 steady:100:1000:1.0"
LO="gauss:10:200:500 gauss:10:200:2000 steady:10:200:1.0"
AHI="blk:0 w:50 w:100 w:250 w:500 q:0.003 q:0.01 hill:250"
ALO="blk:0 w:25 w:50 w:100 q:0.003 q:0.01 hill:250"
PSM="XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536"
sweep() { # tag agg workloads arms xport-env extra-args
  local end=512000; [[ $1 == *_lo ]] && end=128000
  ( export END=$end AGG=$2 WORKLOADS="$3" ARMS="$4" EXTRA_ARGS="$6"; export $5
    RUNS=$OUT/$1 $S 1 $OUT/$1_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
for rep in $(seq ${1:-1} ${2:-3}); do
  for agg in pp:256 off; do
    t=${agg%%:*}
    sweep ${t}_hi $agg "$HI" "$AHI" "$PSM" "+lci_ndevices 8 +pemap 2-16:2,3-17:2"
    sweep ${t}_lo $agg "$LO" "$ALO" "$PSM" "+lci_ndevices 8 +pemap 2-16:2,3-17:2"
    sweep ${t}_verbs $agg "gauss:100:1000:2000 steady:100:1000:1.0" "w:250" "XPORT=verbs" "+lci_ndevices 4 +pemap 2-16:2,3-17:2"
  done
  echo "REP $rep DONE"
done
echo GAUSS2 DONE
