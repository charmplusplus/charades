#!/bin/bash
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/tls_ab; mkdir -p $OUT
cd $W/charades-qd && source scripts/stampede3/env.sh
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export MARGINS=8 LPS_PER_PE=128 LPC=16 AGG=pp:512 PPN=2 PEPP=23 CPT=24 END=512000 WORKLOADS="gauss:100:1000:2000" ARMS="w:250" EXTRA_ARGS="+lci_ndevices 4 +pemap 2-46:2,3-47:2"
for rep in 1 2 3 4 5 6; do
  for t in charades-prod charades-exp; do
    [ $((rep % 2)) = 0 ] && t=$([ $t = charades-prod ] && echo charades-exp || echo charades-prod)   # alternate order
    TREE=$t RUNS=$OUT/$t $S 1 $OUT/${t}_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$t /"
  done
done
for t in charades-prod charades-exp; do echo "$t: $(cat $OUT/${t}_r*.csv | grep -v ^rep | cut -d, -f17 | awk '{printf "%.2f ", $1/1e6}')"; done
