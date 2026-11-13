#!/bin/bash -l
#SBATCH -J roll45
#SBATCH -t 00:55:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/roll45_%j.out
# Job R: why Charades rolls back more than Devastator at the same window.
# Charades with htram (W 400/600/800) against Charades with direct sends and
# Devastator (W 400/800/1,600), sigma 100 / sigma 2,000 / uniform, 16 nodes,
# end time 512,000, 2 reps; plus a 20 us GVT-update delay at sigma 2,000
# (charades RESULTS.md section 145).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 roll45.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/roll45/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh; D=$W/devastator
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-50); htram $(git -C $W/htram log --oneline -1 | cut -c1-50); reconverse $(git -C $W/charm-pads-exp/contrib/reconverse log --oneline -1 | cut -c1-50)"
gate() { # output file
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/$T/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $W/$T/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
    python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" \
      agg_deadline_bucket_pp agg_inputbuf_bucket_wps bucket_window agg_bucket_pp agg_ctl_sparse_bucket_pp > $1 2>&1 )
  tail -4 $1; grep -E "FAIL|TIMEOUT" $1 | head
  grep -q "Failed: *0/" $1 && grep -q "Timed out: *0/" $1; }
# A failure that is only /work2 failing to read a library gets one rerun
if ! gate $OUT/gate.txt; then
  bad=$(grep -E "FAIL|TIMEOUT" $OUT/gate.txt | awk '{print $NF}' | grep "test.out$")
  if [ -n "$bad" ] && [ -z "$(for f in $bad; do grep -L "Input/output error" $f; done)" ]; then
    log "GATE: /work2 read errors only; rerunning"
    gate $OUT/gate2.txt || { log "GATE FAILED"; exit 1; }
  else log "GATE FAILED"; exit 1; fi
fi
log "GATE DONE"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=120 PPN=2 PEPP=23 CPT=24
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
END=512000
cs() { # tag agg workload arms extra
  ( export NODES=16 AGG=$2 END=$END WORKLOADS="$3" ARMS="$4" EXTRA_ARGS="$L $5"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
dv() { # tag window sigma remote
  local extra=(); [ "$4" != 0 ] && extra=(--remote=$4)
  ( export WINDOW=$2 RUNS=$OUT/deva LPS_PER_RANK=128 START=15 LOOKAHEAD=100 MEAN=1000 SIGMA=$3 END=$END CAP=200 AFFINITY=0
    LABEL=$1 bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p32w23 16 --rng=clcg4 "${extra[@]}" | head -1 | cut -c1-120 ); }
# workload: Charades workload, htram setting, Devastator sigma and remote
spec() { case $1 in
  g100)  CW=gauss:100:1000:100;  AGG=pp:2048; SIG=100;  REM=0 ;;
  g2000) CW=gauss:100:1000:2000; AGG=pp:512;  SIG=2000; REM=0 ;;
  uni)   CW=steady:100:1000:1.0; AGG=wps:512; SIG=0;    REM=1.0 ;;
esac; }
cs warm pp:512 gauss:100:1000:100 w:250 ""
for rep in 1 2; do
  for wl in g100 g2000 uni; do
    spec $wl
    cs ${wl}_htram_r$rep $AGG $CW "w:400 w:600 w:800" ""
    cs ${wl}_direct_r$rep off $CW "w:400 w:800 w:1600" ""
    for w in 400 800 1600; do dv ${wl}_w${w}_r$rep $w $SIG $REM; done
  done
  spec g2000
  cs g2000_spin_r$rep $AGG $CW "w:400 w:800" "--diag-gvt-spin-ns=20000"
  log "REP $rep DONE"
done
log "ROLL45 DONE"
