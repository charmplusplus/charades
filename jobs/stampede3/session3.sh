#!/bin/bash
# Session 3: how many PEs poll the network (+backend_poll_thread, which no
# longer hangs) and the TLS build, on the best htram buffer (BUF, default
# 256); then psm2 with explicit tag layouts.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/session3; mkdir -p $OUT
cd $W/charades-qd && source scripts/stampede3/env.sh
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
BUF=${BUF:-256}
export MARGINS=8 LPS_PER_PE=128 LPC=16 AGG=pp:$BUF PPN=2 PEPP=23 CPT=24 END=512000 WORKLOADS="gauss:100:1000:2000" ARMS="w:250"
PF="+lci_ndevices 4 +pemap 2-46:2,3-47:2"
run() {  # name tree extra
  local name=$1 tree=$2 extra=$3
  ( export TREE=$tree "EXTRA_ARGS=$PF $extra"
    RUNS=$OUT/$name $S 1 $OUT/${name}_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$name /" )
}
for rep in 1 2 3; do
  echo "=== rep $rep"
  run prod_pt1   charades-prod ""
  run exp_pt1    charades-exp  ""
  for t in 2 4 6 12 23; do run exp_pt$t charades-exp "+backend_poll_thread $t"; done
  run exp_pt6_f256 charades-exp "+backend_poll_thread 6 +backend_poll_freq 256"
done
echo "=== psm2 tag layouts"
for layout in tag60 tag96 auto; do
  ( unset FI_PROVIDER_PATH; export LCI_ATTR_BACKEND=ofi LCI_ATTR_OFI_PROVIDER_NAME=psm2 FI_PROVIDER=psm2 PSM2_MULTI_EP=1 FI_PSM2_TAG_LAYOUT=$layout LCI_LOG_LEVEL=info
    export LD_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | tr : '\n' | grep -v libfabric_ | paste -sd:)
    timeout -s TERM 60 srun --mpi=pmi2 --kill-on-bad-exit=1 -N 2 -n 2 -c 24 $W/charades-prod/models/phold/simple/phold +pe 4 \
      $W/charades-runs/tune1/base/ctl_sweep/gauss_100_1000_2000_23552_15_512000 $W/charades-qd/tests/test_configs/bucket --end-time=8000 --num-lps=512 +lci_ndevices 1 \
      > $OUT/psm2_$layout.out 2>&1; echo "psm2 $layout rc=$?" )
  grep -vE "reg_cache" $OUT/psm2_$layout.out | grep -iE "cq_data|tag|invalid|Successfully|provider|prov_name|Assert" | sort | uniq -c | head -8 | cut -c1-200
done
echo SESSION3 DONE
