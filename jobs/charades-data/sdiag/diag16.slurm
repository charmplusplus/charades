#!/bin/bash -l
#SBATCH -J sdiag16
#SBATCH -t 01:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag16_%j.out
# Rings (--agg-inbox-mode=2) against mutex inboxes on all 8 scaling workloads,
# 16 nodes x 5 reps and 4 nodes x 3; charades 5bd80f6, htram 2d9fd13
# (charades RESULTS.md section 110).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 diag16.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/sdiag16/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-60)"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
HI="gauss:100:1000:100 gauss:100:1000:500 gauss:100:1000:1000 gauss:100:1000:2000 gauss:100:1000:4000 steady:100:1000:1.0"
LO="gauss:10:200:500 gauss:10:200:2000"
cs() { # tag nodes agg end workloads arms extra
  ( export NODES=$2 AGG=$3 END=$4 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="+lci_ndevices 23 +pemap 2-46:2,3-47:2 $7"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm 16 pp:512 512000 gauss:100:1000:100 w:250 ""
cs warm2 16 pp:512 512000 gauss:100:1000:100 w:250 ""
for n in 16 4; do
  reps=5; [ $n = 4 ] && reps=3
  for rep in $(seq 1 $reps); do
    for m in 0 2; do
      E="--agg-inbox-mode=$m"
      cs m${m}_hi_pp512_n${n}_r$rep $n pp:512 512000 "$HI" "w:400 q:0.001" "$E"
      cs m${m}_lo_pp512_n${n}_r$rep $n pp:512 128000 "$LO" "w:50 q:0.001" "$E"
      cs m${m}_uni_wps512_n${n}_r$rep $n wps:512 512000 steady:100:1000:1.0 "w:400 q:0.001" "$E"
    done
    log "N $n REP $rep DONE"
  done
done
log "SDIAG16 DONE"
