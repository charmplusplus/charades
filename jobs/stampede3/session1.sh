#!/bin/bash
# Runtime tuning session 1 (one idev allocation): builds, the step-1 sweep,
# the TLS A/B, the +backend_poll_thread hang, and a first psm2 attempt.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/session1; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
cd $W/charades-qd && source scripts/stampede3/env.sh
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 cmake >/dev/null 2>&1

log "build charm-pads-exp (reconverse $(git -C $W/charm-pads-exp/contrib/reconverse log --oneline -1 | cut -c1-40))"
if [ ! -x $W/charm-pads-exp/reconverse-linux-x86_64/bin/charmc ]; then
  (cd $W/charm-pads-exp && ./build charm++ reconverse-linux-x86_64 --with-production --disable-fortran -j48 > build.log 2>&1) || { tail -20 $W/charm-pads-exp/build.log; exit 1; }
fi
E=$W/charm-pads-exp/reconverse-linux-x86_64; P=$W/charm-pads-prod/reconverse-linux-x86_64
log "reconverse flags: $(grep CXX_FLAGS $E/reconverse/CMakeFiles/reconverse.dir/flags.make)"
log "__tls_get_addr calls in libreconverse: prod $(objdump -d $P/lib/libreconverse.so | grep -c 'call.*__tls_get_addr') exp $(objdump -d $E/lib/libreconverse.so | grep -c 'call.*__tls_get_addr')"
for t in charades-exp charades-prod; do
  (cd $W/$t && make -s -C src && make -s -C models/phold/simple) > $OUT/build_$t.log 2>&1 || { tail -20 $OUT/build_$t.log; exit 1; }
done
log "built"

log "psm2 provider attributes"
fi_info -p psm2 -v 2>&1 | grep -E "cq_data_size|inject_size|threading|max_ep_tx_ctx|max_ep_rx_ctx|mr_mode|ep_type" | sort | uniq -c | head -12

log "step 1 sweep"
bash $W/charades-runs/tune1.sh 2>&1 | grep -vE "^writing|^done:"

log "TLS A/B"
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export MARGINS=8 AGG=pp:64 LPS_PER_PE=128 LPC=16 PPN=2 PEPP=23 CPT=24 END=512000 WORKLOADS="gauss:100:1000:2000" ARMS="w:250"
for rep in 1 2 3; do
  for t in charades-prod charades-exp; do
    ( export TREE=$t EXTRA_ARGS="+lci_ndevices 4 +pemap 2-46:2,3-47:2"
      RUNS=$OUT/tls_$t $S 1 $OUT/tls_${t}_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$t /" )
  done
done

log "poll_thread hang: +backend_poll_thread 4, stacks after 45 s"
NODE0=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -1)
( export TREE=charades-prod CAP=90 EXTRA_ARGS="+lci_ndevices 4 +pemap 2-46:2,3-47:2 +backend_poll_thread 4"
  RUNS=$OUT/pollthread $S 1 $OUT/pollthread.csv ) &
sp=$!; sleep 45
ssh -o "StrictHostKeyChecking no" -o LogLevel=ERROR $NODE0 'p=$(pgrep -u $USER "^phold$" | head -1); echo "pid $p"; gdb -p $p -batch -ex "set pagination off" -ex "thread apply all bt 25" 2>/dev/null | grep -E "^Thread|^#"' > $OUT/pollthread_stacks.txt 2>&1
tail -5 $OUT/pollthread/ctl_sweep/logs/*.out 2>/dev/null | grep -v reg_cache | tail -5
wait $sp
log "stacks: $(grep -c '^Thread' $OUT/pollthread_stacks.txt) threads"

log "psm2: 2 nodes x 1 process x 2 PEs, ndev 1"
for nd in 1 2; do
  ( unset FI_PROVIDER_PATH; export LCI_ATTR_BACKEND=ofi LCI_ATTR_OFI_PROVIDER_NAME=psm2 FI_PROVIDER=psm2 PSM2_MULTI_EP=1
    export LD_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | tr : '\n' | grep -v libfabric_ | paste -sd:)
    timeout -s TERM 60 srun --mpi=pmi2 --kill-on-bad-exit=1 -N 2 -n 2 -c 24 $W/charades-prod/models/phold/simple/phold +pe 4 \
      $OUT/../tune1/base/ctl_sweep/gauss_100_1000_2000_23552_15_512000 $W/charades-qd/tests/test_configs/bucket --end-time=8000 --num-lps=512 +lci_ndevices $nd \
      > $OUT/psm2_ndev$nd.out 2>&1; echo "psm2 ndev $nd rc=$?" )
  grep -vE "reg_cache" $OUT/psm2_ndev$nd.out | grep -iE "error|invalid|assert|abort|Successfully|timeout|lci" | sort | uniq -c | head -8
done
log "SESSION1 DONE"
