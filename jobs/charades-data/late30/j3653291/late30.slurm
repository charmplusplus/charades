#!/bin/bash -l
#SBATCH -J late30
#SBATCH -t 00:50:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/late30_%j.out
# Held events that lose the race at each GVT update: --agg-flush-ahead (send
# what the next GVT will make due at each count-wave contribution) against
# --diag-window-lag-ns (hold the window edge back 50 us after each update),
# with held-straggler bins; long runs, 16 nodes and 1 node (charades RESULTS.md
# section 138).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 late30.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/late30/j$SLURM_JOB_ID; mkdir -p $OUT
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
      agg_deadline_bucket_pp_flushahead agg_deadline_bucket_pp_flushahead1 agg_deadline_bucket_wps_flushahead agg_deadline_bucket_pp_windowlag \
      agg_deadline_bucket_pp agg_bucket_pp bucket_window > $1 2>&1 )
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
UNI=steady:100:1000:1.0; GS="gauss:100:1000:2000 gauss:100:1000:4000"
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
cs() { # tag nodes agg workloads arms extra
  ( export NODES=$2 AGG=$3 END=2048000 WORKLOADS="$4" ARMS="$5" EXTRA_ARGS="$L $6"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
xa() { case $1 in base) echo "";; ahead) echo "--agg-flush-ahead=2";; ahead1) echo "--agg-flush-ahead=1";; lag) echo "--diag-window-lag-ns=50000";; esac; }
cs warm 16 pp:512 gauss:100:1000:100 w:250 ""
cs warm2 16 pp:512 gauss:100:1000:100 w:250 ""
for rep in 1 2 3; do
  for v in base ahead lag; do
    for a in pp:512 pp:2048; do cs A_${v}_${a/:/}_r$rep 16 $a "$GS" w:400 "$(xa $v)"; done
    [ $v != lag ] && cs A_${v}_pp2048cap_r$rep 16 pp:2048 "$GS" w:400 "--agg-pp-limit=512 $(xa $v)"
    [ $v = ahead ] && cs A_ahead1_pp2048_r$rep 16 pp:2048 "$GS" w:400 "$(xa ahead1)"
    cs B_${v}_r$rep 16 pp:2048 gauss:100:1000:100 w:250 "$(xa $v)"
    [ $v != lag ] && cs C_${v}_r$rep 16 wps:512 $UNI w:400 "$(xa $v)"
    for a in pp:512 pp:2048; do cs D_${v}_${a/:/}_r$rep 1 $a gauss:100:1000:2000 w:250 "$(xa $v)"; done
  done
  log "REP $rep DONE"
done
log "LATE30 DONE"
