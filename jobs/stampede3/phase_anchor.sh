#!/bin/bash
# Charades anchor for phase_deva.sh (same allocation): phase-changing PHOLD,
# htram PP 256, controller (default) and fixed W 50 and 100, as phase_ab.sh.
# Usage: phase_anchor.sh <node list> <reps>
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/phase_anchor; mkdir -p $OUT
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-exp MARGINS=8 LPS_PER_PE=128 LPC=16 NODES=4 PPN=2 PEPP=8 CPT=24 CAP=45 END=256000
export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536 SRUN_ARGS="-w $1"
export WORKLOADS="phases:10:200:100:1000:1.0:32000 phases:10:200:100:1000:0.5:32000"
export ARMS="w:50 w:100 q:0.001" EXTRA_ARGS="+lci_ndevices 8 +pemap 2-16:2,3-17:2"
for rep in $(seq 1 ${2:-3}); do
  ( export AGG=pp:256; RUNS=$OUT/pp $S 1 $OUT/pp_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/pp:256 /" )
  echo "REP $rep DONE"
done
echo ANCHOR DONE
