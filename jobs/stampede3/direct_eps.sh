#!/bin/bash
# Direct sends: the current default controller (eps 0.003, --ctl-floor=0)
# against eps 0.001 with --ctl-floor=2, and the best fixed W. charades-exp
# f24c55c, psm2 64 KB. Interleaved by rep.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/direct_eps; mkdir -p $OUT
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-exp MARGINS=8 LPS_PER_PE=128 LPC=16 NODES=4 PPN=2 CPT=24 CAP=120 XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536 AGG=off
HI="gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0"
LO="gauss:10:200:2000 steady:10:200:1.0"
P64="+lci_ndevices 8 +pemap 2-16:2,3-17:2"; PFULL="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
sweep() { ( export PEPP=$2 END=$3 WORKLOADS="$4" ARMS="$5" EXTRA_ARGS="$6"
    RUNS=$OUT/$1 $S 1 $OUT/$1_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
for rep in $(seq 1 ${1:-3}); do
  sweep hi_old 8 512000 "$HI" "w:250 q:0.003" "$P64"
  sweep hi_new 8 512000 "$HI" "q:0.001" "$P64 --ctl-floor=2"
  sweep lo_old 8 128000 "$LO" "w:50 q:0.003" "$P64"
  sweep lo_new 8 128000 "$LO" "q:0.001" "$P64 --ctl-floor=2"
  sweep full_old 23 512000 "gauss:100:1000:2000" "w:250 q:0.003" "$PFULL"
  sweep full_new 23 512000 "gauss:100:1000:2000" "q:0.001" "$PFULL --ctl-floor=2"
  echo "REP $rep DONE"
done
echo DIRECT DONE
