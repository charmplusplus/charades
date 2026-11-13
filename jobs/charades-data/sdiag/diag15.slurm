#!/bin/bash -l
#SBATCH -J sdiag15
#SBATCH -t 01:20:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag15_%j.out
# htram inbox modes: 0 mutex, 1 padded mutex, 2 lock-free rings; throughput
# at 1/4/16 nodes and the receive breakdown at 16; charades 5bd80f6, htram
# 2d9fd13 (charades RESULTS.md section 108).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 diag15.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/sdiag15/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-60)"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
WL="gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0"
UNI=steady:100:1000:1.0
cs() { # tag nodes agg workloads arms extra
  ( export NODES=$2 AGG=$3 END=512000 WORKLOADS="$4" ARMS="$5" EXTRA_ARGS="+lci_ndevices 23 +pemap 2-46:2,3-47:2 $6"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm 16 pp:512 gauss:100:1000:100 w:250 ""
cs warm2 16 pp:512 gauss:100:1000:100 w:250 ""
for rep in 1 2; do
  for m in 0 1 2; do
    cs R_uni_wps512_m${m}_r$rep 16 wps:512 $UNI w:400 "--agg-inbox-mode=$m --gvt-trace=3"
    cs R_uni_pp512_m${m}_r$rep 16 pp:512 $UNI w:400 "--agg-inbox-mode=$m --gvt-trace=3"
  done
done
log "B DONE"
for rep in 1 2 3; do
  for n in 16 4 1; do
    for m in 0 1 2; do
      cs m${m}_pp512_n${n}_r$rep $n pp:512 "$WL" "w:400 q:0.001" "--agg-inbox-mode=$m"
      cs m${m}_wps512_n${n}_r$rep $n wps:512 $UNI "w:400 q:0.001" "--agg-inbox-mode=$m"
    done
    log "REP $rep N $n DONE"
  done
done
log "SDIAG15 DONE"
