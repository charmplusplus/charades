#!/bin/bash
# Traffic model characterisation: 8,192 intersections (128 x 64, 2,048 x 4),
# 15 cars each; fixed W, controller default, hill climb; htram PP 256 and
# direct. charades-exp 9b3c00f. Usage: traffic_char.sh <node list> <reps>
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/traffic_char_blk; mkdir -p $OUT
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-exp MARGINS=8 LPS_PER_PE=128 LPC=16 NODES=4 PPN=2 PEPP=8 CPT=24 CAP=90
export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536 SRUN_ARGS="-w $1" EXTRA_ARGS="+lci_ndevices 8 +pemap 2-16:2,3-17:2 --buffer-size=655360"
HI="traffic:100:1000:128:15:0:0 traffic:100:1000:128:15:0.5:32 traffic:100:1000:2048:15:0:0"
for rep in $(seq 1 ${2:-3}); do
  for agg in pp:256 off; do
    t=${agg%%:*}
    ( export AGG=$agg END=512000 WORKLOADS="$HI" ARMS=blk:0
      RUNS=$OUT/${t}_hi $S 1 $OUT/${t}_hi_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$agg /" )
    ( export AGG=$agg END=128000 WORKLOADS="traffic:10:200:2048:15:0:0" ARMS=blk:0
      RUNS=$OUT/${t}_lo $S 1 $OUT/${t}_lo_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$agg /" )
  done
  echo "REP $rep DONE"
done
echo TRAFFIC DONE
