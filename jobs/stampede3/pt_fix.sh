#!/bin/bash
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/pt_fix; mkdir -p $OUT
cd $W/charades-qd && source scripts/stampede3/env.sh
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-exp CAP=90 MARGINS=8 LPS_PER_PE=128 LPC=16 AGG=pp:512 PPN=2 PEPP=23 CPT=24 END=512000 WORKLOADS="gauss:100:1000:2000" ARMS="w:250"
for t in 1 12 23 1; do
  EXTRA_ARGS="+lci_ndevices 4 +pemap 2-46:2,3-47:2 +backend_poll_thread $t" RUNS=$OUT/pt$t $S 1 $OUT/pt${t}_$RANDOM.csv | grep -E " (ok|fail|stall) " | sed "s/^/poll_thread $t /"
done
for f in $OUT/pt*.csv; do echo "$f: $(tail -n +2 $f | cut -d, -f11,17)"; done
