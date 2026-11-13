#!/bin/bash
# Session 2: htram PP buffer size past 256, at full nodes and at 64 PEs (both
# slack levels), and the controller with the chosen buffer. TREE (default
# charades-prod) picks the build.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/session2; mkdir -p $OUT
cd $W/charades-qd && source scripts/stampede3/env.sh
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=${TREE:-charades-prod} MARGINS=8 LPS_PER_PE=128 LPC=16
PF="+lci_ndevices 4 +pemap 2-46:2,3-47:2"; P64="+lci_ndevices 4 +pemap 2-16:2,3-17:2"
run() {  # name agg layout pin workload end arms
  local name=$1 agg=$2 lay=$3 pin=$4 wl=$5 end=$6 arms=$7
  ( export AGG=$agg $lay END=$end WORKLOADS="$wl" ARMS="$arms" "EXTRA_ARGS=$pin"
    RUNS=$OUT/$name $S 1 $OUT/${name}_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$name /" )
}
FULL="PPN=2 PEPP=23 CPT=24"; L64="PPN=2 PEPP=8 CPT=24"
HI="gauss:100:1000:2000"; LO="gauss:10:200:2000"
for rep in 1 2 3; do
  echo "=== rep $rep"
  for b in 64 256 512 1024 2048; do run full_pp$b pp:$b "$FULL" "$PF" $HI 512000 w:250; done
  for b in 64 256 1024; do
    run 64hi_pp$b pp:$b "$L64" "$P64" $HI 512000 w:250
    run 64lo_pp$b pp:$b "$L64" "$P64" $LO 128000 w:50
  done
done
echo SESSION2 DONE
