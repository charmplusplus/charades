#!/bin/bash -l
#SBATCH -J sdiag22
#SBATCH -t 01:00:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag22_%j.out
# Closure check follow-up: does a warm-up before the clock remove the 16-node
# start-up excess, and do long runs dilute it? charades 7670534, htram 699c3a9,
# Reconverse 22871c6 (charades RESULTS.md section 121).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 diag22.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/sdiag22/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-50); htram $(git -C $W/htram log --oneline -1 | cut -c1-50); reconverse $(git -C $W/charm-pads-exp/contrib/reconverse log --oneline -1 | cut -c1-50)"
gate() { # output file
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/$T/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $W/$T/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
    python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" \
      agg_bucket_pp_warmup bucket_window_warmup bucket_window agg_bucket_pp > $1 2>&1 )
  tail -4 $1; grep -E "FAIL|TIMEOUT" $1 | head
  grep -q "Failed: *0/" $1 && grep -q "Timed out: *0/" $1; }
# A failure that is only /work2 failing to read a library (Input/output error,
# as in job 3650177) gets one rerun; any other failure stops the job
if ! gate $OUT/gate.txt; then
  bad=$(grep -E "FAIL|TIMEOUT" $OUT/gate.txt | awk '{print $NF}' | grep "test.out$")
  if [ -n "$bad" ] && [ -z "$(for f in $bad; do grep -L "Input/output error" $f; done)" ]; then
    log "GATE: /work2 read errors only; rerunning"
    gate $OUT/gate2.txt || { log "GATE FAILED"; exit 1; }
  else log "GATE FAILED"; exit 1; fi
fi
log "GATE DONE"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=120 PPN=2 PEPP=23 CPT=24
S100=gauss:100:1000:100; S2K=gauss:100:1000:2000; S4K=gauss:100:1000:4000; UNI=steady:100:1000:1.0
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
cs() { # tag nodes agg workloads arms extra   (END from $E, default 512000)
  ( export NODES=$2 AGG=$3 END=${E:-512000} WORKLOADS="$4" ARMS="$5" EXTRA_ARGS="$L $6"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm 16 pp:512 $S100 w:250 ""
cs warm2 16 pp:512 $S100 w:250 ""
for rep in 1 2; do
  # A: warm-up, short runs
  for n in 16 4; do
    for wp in 0 1; do cs A_w${wp}_n${n}_r$rep $n pp:512 $S2K w:400 "--warmup-pings=$wp"; done
  done
  for wp in 0 1; do cs AT_w${wp}_n16_r$rep 16 pp:512 $S2K w:400 "--warmup-pings=$wp --gvt-trace=2"; done
  log "A REP $rep DONE"
  # B: 4x longer runs
  for n in 16 4; do
    for wp in 0 1; do E=2048000 cs B_w${wp}_n${n}_r$rep $n pp:512 $S2K w:400 "--warmup-pings=$wp"; done
  done
  E=2048000 cs BT_w0_n16_r$rep 16 pp:512 $S2K w:400 "--gvt-trace=2"
  log "B REP $rep DONE"
  # C: closure on uniform and sigma 4,000; warm-up there too
  for n in 16 4; do
    cs CT_uni_n${n}_r$rep $n wps:512 $UNI w:400 "--gvt-trace=2"
    cs CT_s4k_n${n}_r$rep $n pp:512 $S4K w:400 "--gvt-trace=2"
    for wp in 0 1; do
      cs C_uni_w${wp}_n${n}_r$rep $n wps:512 $UNI w:400 "--warmup-pings=$wp"
      cs C_s4k_w${wp}_n${n}_r$rep $n pp:512 $S4K w:400 "--warmup-pings=$wp"
    done
  done
  log "C REP $rep DONE"
done
log "SDIAG22 DONE"
