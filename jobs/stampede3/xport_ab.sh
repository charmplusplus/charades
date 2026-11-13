#!/bin/bash
# verbs;ofi_rxm against native psm2 (LCI ofi-psm2-native in charm-pads-exp),
# interleaved, same build and binary. Usage: xport_ab.sh <reps>
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/xport_ab; mkdir -p $OUT
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-exp MARGINS=8 LPS_PER_PE=128 LPC=16 NODES=${NODES:-2}
for rep in $(seq 1 ${1:-3}); do
  for x in verbs psm2; do
    ( export XPORT=$x AGG=pp:512 PPN=2 PEPP=23 CPT=24 END=512000 WORKLOADS="gauss:100:1000:2000" ARMS="w:250" EXTRA_ARGS="+lci_ndevices 4 +pemap 2-46:2,3-47:2"
      RUNS=$OUT/full_$x $S 1 $OUT/full_${x}_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/full $x /" )
    ( export XPORT=$x AGG=pp:256 PPN=2 PEPP=8 CPT=24 END=512000 WORKLOADS="gauss:100:1000:2000" ARMS="w:250" EXTRA_ARGS="+lci_ndevices 4 +pemap 2-16:2,3-17:2"
      RUNS=$OUT/p8_$x $S 1 $OUT/p8_${x}_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/p8 $x /" )
  done
done
for c in full p8; do for x in verbs psm2; do echo "$c $x M ev/s: $(cat $OUT/${c}_${x}_r*.csv | grep -v ^rep | cut -d, -f17 2>/dev/null | awk "{printf \"%.2f \", \$1/1e6}")"; done; done
echo XPORT DONE
