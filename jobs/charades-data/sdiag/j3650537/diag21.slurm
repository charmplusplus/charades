#!/bin/bash -l
#SBATCH -J sdiag21
#SBATCH -t 01:00:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag21_%j.out
# Shorter scheduler passes while a count wave is in flight (--wave-batch);
# charades 6595d9e, htram 699c3a9, Reconverse 22871c6 (charades RESULTS.md section 119).
# Resubmitted after job 3650177's gate hit a /work2 Input/output error loading
# liblci-ucx.so (not a test failure).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 diag21.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/sdiag21/j$SLURM_JOB_ID; mkdir -p $OUT
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
      bucket_window_wavebatch agg_ctl_sparse_bucket_pp_wavebatch agg_bucket_pp_wavebatch_pe \
      bucket_window agg_bucket_pp > $1 2>&1 )
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
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
S100=gauss:100:1000:100; S2K=gauss:100:1000:2000; S4K=gauss:100:1000:4000; UNI=steady:100:1000:1.0
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
cs() { # tag nodes agg workloads arms extra
  ( export NODES=$2 AGG=$3 END=512000 WORKLOADS="$4" ARMS="$5" EXTRA_ARGS="$L $6"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
declare -A F=([base]="" [wb2]="--wave-batch=2" [wb4]="--wave-batch=4" [wb8]="--wave-batch=8" [wb4pe]="--wave-batch=4 --wave-batch-when=1")
cs warm 16 pp:512 $S100 w:250 ""
cs warm2 16 pp:512 $S100 w:250 ""
for rep in 1 2; do
  for n in 16 4; do
    for f in base wb2 wb4 wb8 wb4pe; do cs A_${f}_n${n}_r$rep $n pp:512 $S2K w:400 "${F[$f]}"; done
  done
  log "A REP $rep DONE"
  for f in base wb4 wb4pe; do cs T_${f}_r$rep 16 pp:512 $S2K w:400 "${F[$f]} --gvt-trace=2"; done
  for f in base wb4; do cs T_tree4_${f}_r$rep 16 pp:512 $S2K w:400 "${F[$f]} --gvt-wave-tree=4 --gvt-trace=2"; done
  log "T REP $rep DONE"
  for f in base wb4; do
    cs B_${f}_s100_r$rep 16 pp:512 $S100 "w:400 q:0.001" "${F[$f]}"
    cs B_${f}_s4k_r$rep 16 pp:512 $S4K "w:400 q:0.001" "${F[$f]}"
    cs B_${f}_uni_r$rep 16 wps:512 $UNI "w:400 q:0.001" "${F[$f]}"
  done
  log "B REP $rep DONE"
done
log "SDIAG21 DONE"
