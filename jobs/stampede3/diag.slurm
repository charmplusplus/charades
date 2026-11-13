#!/bin/bash -l
#SBATCH -J sdiag
#SBATCH -t 00:50:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag_%j.out
# Where a GVT advance's time goes at 4-16 nodes; PP 2,048's allocation vs its
# limit; the deadline horizon margin (charades RESULTS.md section 79).
# Submit: sbatch -p skx-dev -N 16 -n 768 diag.slurm
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/sdiag/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID, $SLURM_NNODES nodes; charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-50)"
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
cs() { # tag nodes agg end workloads arms margins extra
  ( export NODES=$2 AGG=$3 END=$4 WORKLOADS="$5" ARMS="$6" MARGINS="$7" EXTRA_ARGS="$P $8"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm 16 pp:512 512000 gauss:100:1000:100 w:250 8 ""
cs warm2 16 pp:512 512000 gauss:100:1000:100 w:250 8 ""
# Canary: the new option and trace level on 16 nodes
cs canary 16 pp:2048 512000 gauss:100:1000:100 w:250 8 "--agg-pp-limit=512 --gvt-trace=2"
if [ "$(grep -c ",ok," $OUT/canary.csv)" != 1 ] || [ "$(ls $OUT/canary/ctl_sweep/gvt_waves_*.csv | wc -l)" != 32 ]; then log "CANARY FAILED: stopping"; exit 1; fi
log "canary ok"
WL="gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0"
for rep in 1 2 3; do
  # A. Per-process count-wave timings; one setting per directory (the trace files are per run)
  for n in 16 8 4; do
    for wl in $WL; do
      t=${wl//:/_}
      cs A_tr_${t}_n${n}_r$rep $n pp:512 512000 $wl w:250 8 "--gvt-trace=2 --pe-stats=1"
      cs A_off_${t}_n${n}_r$rep $n pp:512 512000 $wl w:250 8 ""
    done
  done
  log "A REP $rep DONE"
  # B. PP 2,048's allocation with PP 512's limit
  for v in pp:512: pp:2048: pp:2048:cap; do
    a=${v%:*} x=${v##*:}; e=""; [ "$x" = cap ] && e="--agg-pp-limit=512"
    cs B_${a/:/}${x}_r$rep 16 $a 512000 "gauss:100:1000:100 gauss:100:1000:2000" w:250 8 "$e"
  done
  log "B REP $rep DONE"
done
# C. Deadline horizon margin (the horizon is W + margin)
for rep in 1 2; do
  for a in pp:512 pp:2048; do
    cs C_${a/:/}_r$rep 16 $a 512000 "gauss:100:1000:100 gauss:100:1000:2000 gauss:100:1000:4000" "w:250 w:400" "8 32 64 128" ""
  done
  log "C REP $rep DONE"
done
log "SDIAG DONE"
