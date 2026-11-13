#!/bin/bash
# final_cmp.sh with Charades on both transports: verbs;ofi_rxm (4 devices,
# 8 KB packets) and native psm2 (LCI ofi-psm2-native; 64 KB packets, 16
# devices full / 8 at 64 cores), interleaved, against Devastator, same job.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/final_cmp2; mkdir -p $OUT
cd $W/charades-qd && source scripts/stampede3/env.sh
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-exp MARGINS=8 LPS_PER_PE=128 LPC=16 NODES=4
D=$W/devastator
cfg() { # name xport ndev pemap agg pepp end workload arm
  ( export XPORT=$2 AGG=$5 PPN=2 PEPP=$6 CPT=24 END=$7 WORKLOADS=$8 ARMS=$9 EXTRA_ARGS="+lci_ndevices $3 +pemap $4"
    [ $2 = psm2 ] && export LCI_ATTR_PACKET_SIZE=65536
    RUNS=$OUT/$1_$2 $S 1 $OUT/$1_$2_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 $2 /" ); }
for rep in 1 2 3; do
  cfg full verbs 4 2-46:2,3-47:2 pp:512 23 512000 gauss:100:1000:2000 w:250
  cfg full psm2 16 2-46:2,3-47:2 pp:512 23 512000 gauss:100:1000:2000 w:250
  cfg 64hi verbs 4 2-16:2,3-17:2 pp:256 8 512000 gauss:100:1000:2000 w:250
  cfg 64hi psm2 8 2-16:2,3-17:2 pp:256 8 512000 gauss:100:1000:2000 w:250
  cfg 64lo verbs 4 2-16:2,3-17:2 pp:256 8 128000 gauss:10:200:2000 w:50
  cfg 64lo psm2 8 2-16:2,3-17:2 pp:256 8 128000 gauss:10:200:2000 w:50
  WINDOW=1000 END=512000 SIGMA=2000 LPS_PER_RANK=128 RUNS=$OUT bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p8w23 4 | head -1
  WINDOW=1000 END=512000 SIGMA=2000 RUNS=$OUT bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p8w8 4 | head -1
  WINDOW=200 END=128000 SIGMA=2000 LOOKAHEAD=10 MEAN=200 RUNS=$OUT bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p8w8 4 | head -1
done
for c in full 64hi 64lo; do for x in verbs psm2; do echo "charades $c $x: $(cat $OUT/${c}_${x}_r*.csv | grep -v ^rep | cut -d, -f17 | awk "{printf \"%.2f \", \$1/1e6}") committed $(cat $OUT/${c}_${x}_r*.csv | grep -v ^rep | cut -d, -f14 | sort -u | paste -sd/)"; done; done
grep -h PHOLD_GAUSS_RESULT $OUT/*.out | grep -oE "ranks=[0-9]+|lookahead=[0-9]+|committed_per_s=[0-9.e+]+" | paste - - - | sort
echo FINAL DONE
