#!/bin/bash
# Charades with everything (fast paths, TLS build, PP 512 / 256, pinned 2 x 23 or
# 2 x 8) against Devastator at its best fixed windows, same job.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/final_cmp; mkdir -p $OUT
cd $W/charades-qd && source scripts/stampede3/env.sh
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-exp MARGINS=8 LPS_PER_PE=128 LPC=16
D=$W/devastator
for rep in 1 2 3; do
  ( export AGG=pp:512 PPN=2 PEPP=23 CPT=24 END=512000 WORKLOADS="gauss:100:1000:2000" ARMS="w:250" EXTRA_ARGS="+lci_ndevices 4 +pemap 2-46:2,3-47:2"
    RUNS=$OUT/full $S 1 $OUT/full_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/full /" )
  ( export AGG=pp:256 PPN=2 PEPP=8 CPT=24 END=512000 WORKLOADS="gauss:100:1000:2000" ARMS="w:250" EXTRA_ARGS="+lci_ndevices 4 +pemap 2-16:2,3-17:2"
    RUNS=$OUT/64hi $S 1 $OUT/64hi_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/64hi /" )
  ( export AGG=pp:256 PPN=2 PEPP=8 CPT=24 END=128000 WORKLOADS="gauss:10:200:2000" ARMS="w:50" EXTRA_ARGS="+lci_ndevices 4 +pemap 2-16:2,3-17:2"
    RUNS=$OUT/64lo $S 1 $OUT/64lo_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/64lo /" )
  WINDOW=1000 END=512000 SIGMA=2000 LPS_PER_RANK=128 RUNS=$OUT bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p8w23 4 | head -1
  WINDOW=1000 END=512000 SIGMA=2000 RUNS=$OUT bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p8w8 4 | head -1
  WINDOW=200 END=128000 SIGMA=2000 LOOKAHEAD=10 MEAN=200 RUNS=$OUT bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p8w8 4 | head -1
done
for c in full 64hi 64lo; do echo "charades $c: $(cat $OUT/${c}_r*.csv | grep -v ^rep | cut -d, -f17 | awk '{printf "%.2f ", $1/1e6}')"; done
grep -h PHOLD_GAUSS_RESULT $OUT/*.out | grep -oE "ranks=[0-9]+|lookahead=[0-9]+|committed_per_s=[0-9.e+]+" | paste - - - | sort
echo FINAL DONE
