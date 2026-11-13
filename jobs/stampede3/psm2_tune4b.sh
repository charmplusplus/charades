#!/bin/bash
# Native psm2 at 4 nodes, one run each: devices for the three final_cmp configs.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/psm2_tune4b; mkdir -p $OUT
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-exp MARGINS=8 LPS_PER_PE=128 LPC=16 NODES=4 XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536 CPT=24 PPN=2
run() { local l=$1; shift; ( export "$@"; RUNS=$OUT/$l $S 1 $OUT/$l.csv >/dev/null 2>&1 )
  echo "$l: $(grep -v ^rep $OUT/$l.csv | awk -F, "{printf \"%s %.2f M ev/s\", \$11, \$17/1e6}")"; }
F="AGG=pp:512 PEPP=23 END=512000 WORKLOADS=gauss:100:1000:2000 ARMS=w:250"
H="AGG=pp:256 PEPP=8 END=512000 WORKLOADS=gauss:100:1000:2000 ARMS=w:250"
L="AGG=pp:256 PEPP=8 END=128000 WORKLOADS=gauss:10:200:2000 ARMS=w:50"
for nd in 16 23; do run full_nd$nd $F EXTRA_ARGS="+lci_ndevices $nd +pemap 2-46:2,3-47:2"; done
for nd in 4 8 12; do run full_verbs_nd$nd $F XPORT=verbs LCI_ATTR_PACKET_SIZE= EXTRA_ARGS="+lci_ndevices $nd +pemap 2-46:2,3-47:2"; done
for nd in 4 8; do run 64hi_verbs_nd$nd $H XPORT=verbs LCI_ATTR_PACKET_SIZE= EXTRA_ARGS="+lci_ndevices $nd +pemap 2-16:2,3-17:2"; done
for nd in 4 8; do run 64lo_verbs_nd$nd $L XPORT=verbs LCI_ATTR_PACKET_SIZE= EXTRA_ARGS="+lci_ndevices $nd +pemap 2-16:2,3-17:2"; done
echo TUNE DONE
