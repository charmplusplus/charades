#!/bin/bash
# Phase-changing PHOLD (low slack 10/200 and high slack 100/1000 alternating
# every 32,000), controller default (--ctl-floor=2, eps 0.001) against fixed W
# and the hill climb; htram PP 256 and direct. charades-exp 9b3c00f.
# Usage: phase_ab.sh <node list> <reps>
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/phase_ab; mkdir -p $OUT
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-exp MARGINS=8 LPS_PER_PE=128 LPC=16 NODES=4 PPN=2 PEPP=8 CPT=24 CAP=45 END=256000
export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536 SRUN_ARGS="-w $1"
export WORKLOADS="phases:10:200:100:1000:1.0:32000 phases:10:200:100:1000:0.5:32000"
export ARMS="blk:0 w:25 w:50 w:100 w:250 q:0.001 hill:250" EXTRA_ARGS="+lci_ndevices 8 +pemap 2-16:2,3-17:2"
for rep in $(seq 1 ${2:-3}); do
  for agg in pp:256 off; do
    ( export AGG=$agg; RUNS=$OUT/${agg%%:*} $S 1 $OUT/${agg%%:*}_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$agg /" )
  done
  echo "REP $rep DONE"
done
echo PHASE DONE
