#!/bin/bash
# Window controller (eps 0.003) against fixed W on native psm2, 4 nodes.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/ctl_psm2; mkdir -p $OUT
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-exp MARGINS=8 LPS_PER_PE=128 LPC=16 NODES=4 XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536 PPN=2 CPT=24
( export AGG=pp:512 PEPP=23 END=512000 WORKLOADS="gauss:100:1000:2000" ARMS="w:100 w:250 w:500 w:1000 q:0.003 hill:250" EXTRA_ARGS="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
  RUNS=$OUT/full $S 1 $OUT/full.csv | grep -E " (ok|fail|stall) " | sed "s/^/full /" )
( export AGG=pp:256 PEPP=8 END=512000 WORKLOADS="gauss:100:1000:2000" ARMS="w:100 w:250 w:500 w:1000 q:0.003 hill:250" EXTRA_ARGS="+lci_ndevices 8 +pemap 2-16:2,3-17:2"
  RUNS=$OUT/64hi $S 1 $OUT/64hi.csv | grep -E " (ok|fail|stall) " | sed "s/^/64hi /" )
( export AGG=pp:256 PEPP=8 END=128000 WORKLOADS="gauss:10:200:2000" ARMS="w:25 w:50 w:100 w:250 q:0.003 hill:50" EXTRA_ARGS="+lci_ndevices 8 +pemap 2-16:2,3-17:2"
  RUNS=$OUT/64lo $S 1 $OUT/64lo.csv | grep -E " (ok|fail|stall) " | sed "s/^/64lo /" )
for c in full 64hi 64lo; do grep -v ^rep $OUT/$c.csv | awk -F, -v c=$c "{printf \"%s %-8s %s rate %.2f M ev/s eff %s mean_W %s\n\", c, \$10, \$11, \$17/1e6, \$16, \$23}"; done
echo CTL DONE
