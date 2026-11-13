#!/bin/bash
# Native psm2 settings, one run each on the full-node config.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/psm2_tune; mkdir -p $OUT
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-exp MARGINS=8 LPS_PER_PE=128 LPC=16 NODES=2 AGG=pp:512 PPN=2 PEPP=23 CPT=24 END=512000 WORKLOADS="gauss:100:1000:2000" ARMS="w:250"
export EXTRA_ARGS="+lci_ndevices 4 +pemap 2-46:2,3-47:2"
run() { # label, then env assignments
  local l=$1; shift
  ( export "$@"; RUNS=$OUT/$l $S 1 $OUT/$l.csv >/dev/null 2>&1 )
  echo "$l: $(grep -v ^rep $OUT/$l.csv | awk -F, "{printf \"%s %.2f M ev/s\", \$11, \$17/1e6}")"
}
run verbs_def XPORT=verbs
run verbs_pk32k XPORT=verbs LCI_ATTR_PACKET_SIZE=32768
run psm2_def XPORT=psm2
run psm2_pk16k XPORT=psm2 LCI_ATTR_PACKET_SIZE=16384
run psm2_pk32k XPORT=psm2 LCI_ATTR_PACKET_SIZE=32768
run psm2_pk64k XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536
run psm2_norcvthr XPORT=psm2 PSM2_RCVTHREAD=0
run psm2_pk32k_norcv XPORT=psm2 LCI_ATTR_PACKET_SIZE=32768 PSM2_RCVTHREAD=0
run psm2_ndev2 XPORT=psm2 EXTRA_ARGS="+lci_ndevices 2 +pemap 2-46:2,3-47:2"
run psm2_ndev8 XPORT=psm2 EXTRA_ARGS="+lci_ndevices 8 +pemap 2-46:2,3-47:2"
echo TUNE DONE
