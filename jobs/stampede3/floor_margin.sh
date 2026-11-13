#!/bin/bash
# Where does the htram rollback floor come from? sigma 4000, high slack, W 50
# and 250 (below / at the best W), one change at a time from the fast stack.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/floor_margin; mkdir -p $OUT
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-exp LPS_PER_PE=128 LPC=16 NODES=4 PPN=2 PEPP=8 CPT=24 CAP=90 END=512000
export WORKLOADS="gauss:100:1000:4000" ARMS="w:250"
B="+lci_ndevices 8 +pemap 2-16:2,3-17:2"
run() { local l=$1 agg=$2 x=$3 ex=$4
  ( export AGG=$agg EXTRA_ARGS="$B $ex"; export $x; RUNS=$OUT/$l $S 2 $OUT/$l.csv >/dev/null 2>&1 )
  echo "$l: $(grep -v ^rep $OUT/$l.csv | awk -F, "{printf \"%s %s rb%%=%.3f rate=%.1f | \", \$10, \$11, \$15/\$14*100, \$17/1e6}")"; }
P="XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536"
for m in 8 64 250 1000; do run m$m pp:256 "$P MARGINS=$m" ""; done
echo FLOOR DONE
