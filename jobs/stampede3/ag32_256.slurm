#!/bin/bash -l
#SBATCH -J ag32_256
#SBATCH -t 02:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/ag32_256_%j.out
# Job AG32 (charades results/aggregation.md section 256; user decision
# 2026-11-07): Charades only, 32 nodes, 5 reps, the paper launch (no
# diagnostics), tree charades-r5 (85a2aad), F1's sizes (end 2,048,000;
# lookahead 10: 512,000; 128 LPs per PE; traffic as F5).
# Part A, aggregation on the remote-heavy end: does bundling still pay at 32
#   nodes, where F1's uniform runs carried 8 events per htram message (102 at
#   4 nodes)?
#   uniform and sigma 4,000 x {direct sends, PP 512, PP 2,048, WPs 512,
#   WPs 2,048} x {W 300, 400, 500, 600, the controller}
# Part B, fixed windows past F1-32's and F5-32b's grids (their best fixed W was
#   the grid's edge, or the controller beat both fixed W):
#   sigma 100, 500, 1,000 (PP 2,048) and 2,000 (PP 512): W 400 / 500 / 600 and
#     the controller
#   lookahead 10 sigma 500 (PP 2,048): W 50 / 75 / 100 / 150 and the controller;
#     lookahead 10 sigma 2,000 (WPs 512): W 50 / 75 / 100 and the controller
#   traffic (PP 2,048): W 1,000 / 1,500 / 2,000 and the controller
# Per rep: part A then part B, workload and arm order reversed in even reps.
# A short warm-up run (not counted) starts the job.
# Submit: sbatch -p skx -N 32 -n 1536 -x c455-081 ag32_256.slurm
# STUB=1 (login node, fake srun first in PATH): print every command, no gate.
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
STUB=${STUB:-0}
OUT=$W/charades-runs/ag32_256/j${SLURM_JOB_ID:-dry}; [ $STUB = 1 ] && OUT=$W/charades-runs/ag32_256/stub
mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
[ $STUB = 1 ] && export PATH=$W/charades-runs/f4b250/stubbin:$PATH   # its srun appends its command line to $STUBLOG
T=charades-r5; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}"
log "charades $(git -C $C log --oneline -1 | cut -c1-50)"
[ "$(git -C $C rev-parse --short=7 HEAD)" = 85a2aad ] || { log "$T not at 85a2aad"; exit 1; }
for b in $C/models/phold/simple/phold $C/models/traffic/traffic; do
  for s in ctl-reach-buckets "the base before and after" "PER-PE WITH A SHARED SPARE LIST"; do
    strings $b | grep -q "$s" || { log "$b lacks $s"; exit 1; }
  done
  ldd $b | grep -q charm-pads-perf/ || { log "$b does not link charm-pads-perf"; exit 1; }
done
grep -q "mb)   extra" $S || { log "ctl_sweep.sh lacks the mb arm"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }

if [ $STUB = 0 ]; then
gate() { # output file
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
    python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" --model Traffic \
      agg_deadline_bucket_pp agg_inputbuf_bucket_wps bucket_window agg_bucket_pp agg_ctl_measured_bucket_pp ctl_measured_bucket > $1 2>&1 )
  tail -4 $1; grep -E "FAIL|TIMEOUT" $1 | head
  grep -q "Failed: *0/" $1 && grep -q "Timed out: *0/" $1 && grep -q "Passed: *[1-9]" $1; }
if ! gate $OUT/gate.txt; then
  bad=$(grep -E "FAIL|TIMEOUT" $OUT/gate.txt | awk '{print $NF}' | grep "test.out$")
  if [ -n "$bad" ] && [ -z "$(for f in $bad; do grep -L "Input/output error" $f; done)" ]; then
    log "GATE: /work2 read errors only; rerunning"
    gate $OUT/gate2.txt || { log "GATE FAILED"; exit 1; }
  else log "GATE FAILED"; exit 1; fi
fi
log "GATE DONE"
fi

export TREE=$T PPN=2 PEPP=23 CPT=24 CAP=150 LPC=16
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
N=32; NL32=$(join ${NL[@]:0:32})
cs() { # tag agg workload arms end lps_per_pe
  ( export NODES=$N AGG=$2 WORKLOADS="$3" ARMS="$4" END=$5 BUCKETS=8 LPS_PER_PE=$6 EXTRA_ARGS="$L" SRUN_ARGS="-w $NL32"
    RUNS=$OUT/n$N/$1 $S 1 $OUT/n$N/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$N $1 /" )
  rm -f $OUT/n$N/$1/ctl_sweep/gvt_*.out; }
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
ord() { [ $(($2 % 2)) = 1 ] && echo "$1" || rev "$1"; }
# part A: workload -> ctl_sweep workload; part B: tag -> agg, workload, arms, end, LPs per PE
wa() { case $1 in uni) echo steady:100:1000:1.0 ;; g4000) echo gauss:100:1000:4000 ;; esac; }
wb() { case $1 in
    g100)     echo "pp:2048 gauss:100:1000:100 |w:400 w:500 w:600 mb:0|2048000 128" ;;
    g500)     echo "pp:2048 gauss:100:1000:500 |w:400 w:500 w:600 mb:0|2048000 128" ;;
    g1000)    echo "pp:2048 gauss:100:1000:1000|w:400 w:500 w:600 mb:0|2048000 128" ;;
    g2000)    echo "pp:512 gauss:100:1000:2000 |w:400 w:500 w:600 mb:0|2048000 128" ;;
    l10g500)  echo "pp:2048 gauss:10:200:500   |w:50 w:75 w:100 w:150 mb:0|512000 128" ;;
    l10g2000) echo "wps:512 gauss:10:200:2000  |w:50 w:75 w:100 mb:0|512000 128" ;;
    tr)       echo "pp:2048 traffic:100:1000:64:16:0:0:3|w:1000 w:1500 w:2000 mb:0|12000000 64" ;;
  esac; }
AGGS="off pp:512 pp:2048 wps:512 wps:2048"; AARMS="w:300 w:400 w:500 w:600 mb:0"
WLA="uni g4000"; WLB="g100 g500 g1000 g2000 l10g500 l10g2000 tr"
{
  cs warm pp:2048 gauss:100:1000:100 w:300 512000 128
  for rep in 1 2 3 4 5; do
    for wl in $(ord "$WLA" $rep); do
      for a in $(ord "$AGGS" $rep); do
        cs ${wl}_${a/:/}_r$rep $a $(wa $wl) "$(ord "$AARMS" $rep)" 2048000 128
      done
    done
    for wl in $(ord "$WLB" $rep); do
      IFS='|' read -r aw arms el <<< "$(wb $wl)"; read -r agg cw <<< "$aw"; read -r end lps <<< "$el"
      cs ${wl}_${agg/:/}_r$rep $agg $cw "$(ord "$arms" $rep)" $end $lps
    done
    log "REP $rep DONE"
  done
} > $OUT/stream_n32.log 2>&1
grep -h -E ' (fail|stall) ' $OUT/stream_n32.log | head -20
log "AG32_256 DONE"
