#!/bin/bash
# --ctl-floor=2 at smaller epsilon (the floor no longer traps it), against
# the best fixed W, interleaved by rep. charades-exp f24c55c, psm2 64 KB.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/floor_eps; mkdir -p $OUT
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-exp MARGINS=8 LPS_PER_PE=128 LPC=16 NODES=4 PPN=2 CPT=24 CAP=90 XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536
HI="gauss:100:1000:100 gauss:100:1000:1000 gauss:100:1000:4000 steady:100:1000:1.0"
P64="+lci_ndevices 8 +pemap 2-16:2,3-17:2"; PFULL="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
sweep() { ( export PEPP=$2 AGG=$3 END=$4 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="$7"
    RUNS=$OUT/$1 $S 1 $OUT/$1_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
for rep in $(seq 1 ${1:-3}); do
  sweep hi_w 8 pp:256 512000 "$HI" "w:250" "$P64"
  sweep hi_f2 8 pp:256 512000 "$HI" "q:0.001 q:0.002" "$P64 --ctl-floor=2"
  sweep lo_w 8 pp:256 128000 "gauss:10:200:2000 steady:10:200:1.0" "w:50" "$P64"
  sweep lo_f2 8 pp:256 128000 "gauss:10:200:2000 steady:10:200:1.0" "q:0.001 q:0.002" "$P64 --ctl-floor=2"
  sweep full_w 23 pp:512 512000 "gauss:100:1000:2000" "w:250" "$PFULL"
  sweep full_f2 23 pp:512 512000 "gauss:100:1000:2000" "q:0.001 q:0.002" "$PFULL --ctl-floor=2"
  echo "REP $rep DONE"
done
echo FLOOREPS DONE
