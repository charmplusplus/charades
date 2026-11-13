#!/bin/bash -l
#SBATCH -J send29
#SBATCH -t 01:00:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/send29_%j.out
# The post and the network poll inside each send; +lci_send_progress 0 (skip the
# poll after a successful post), uniform at 4 and 16 nodes plus sigma 2,000 and
# 100 at 16; long runs; charades 70b9224, htram ed31d7e, Reconverse 8b67e60
# (charades RESULTS.md section 135).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 send29.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/send29/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-50); htram $(git -C $W/htram log --oneline -1 | cut -c1-50); reconverse $(git -C $W/charm-pads-exp/contrib/reconverse log --oneline -1 | cut -c1-50)"
gate() { # output file
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/$T/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $W/$T/tests; export CHARADES_RUN_ARGS="+mempool_remote_free ${GATE_ARGS:-}"
    python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" \
      bucket_gvt_trace5 agg_inputbuf_bucket_wps bucket_window agg_bucket_pp agg_ctl_sparse_bucket_pp > $1 2>&1 )
  tail -4 $1; grep -E "FAIL|TIMEOUT" $1 | head
  grep -q "Failed: *0/" $1 && grep -q "Timed out: *0/" $1; }
# A failure that is only /work2 failing to read a library (Input/output error,
# as in job 3650177) gets one rerun; any other failure stops the job
export GATE_ARGS="+lci_send_progress 0"
if ! gate $OUT/gate.txt; then
  bad=$(grep -E "FAIL|TIMEOUT" $OUT/gate.txt | awk '{print $NF}' | grep "test.out$")
  if [ -n "$bad" ] && [ -z "$(for f in $bad; do grep -L "Input/output error" $f; done)" ]; then
    log "GATE: /work2 read errors only; rerunning"
    gate $OUT/gate2.txt || { log "GATE FAILED"; exit 1; }
  else log "GATE FAILED"; exit 1; fi
fi
log "GATE DONE"
unset GATE_ARGS
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=120 PPN=2 PEPP=23 CPT=24
UNI=steady:100:1000:1.0
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
cs() { # tag nodes agg workloads arms extra
  ( export NODES=$2 AGG=$3 END=2048000 WORKLOADS="$4" ARMS="$5" EXTRA_ARGS="$L $6"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm 16 pp:512 gauss:100:1000:100 w:250 ""
cs warm2 16 pp:512 gauss:100:1000:100 w:250 ""
for rep in 1 2; do
  for n in 16 4; do
    for sp in 1 0; do
      cs T_sp${sp}_n${n}_r$rep $n wps:512 $UNI w:400 "+lci_send_progress $sp --gvt-trace=5 --pe-stats=1"
      cs off_sp${sp}_n${n}_r$rep $n wps:512 $UNI w:400 "+lci_send_progress $sp"
    done
  done
  for sp in 1 0; do
    cs C_s2k_sp${sp}_r$rep 16 pp:512 gauss:100:1000:2000 w:400 "+lci_send_progress $sp"
    cs C_s100_sp${sp}_r$rep 16 pp:2048 gauss:100:1000:100 q:0.001 "+lci_send_progress $sp"
  done
  log "REP $rep DONE"
done
log "SEND29 DONE"
