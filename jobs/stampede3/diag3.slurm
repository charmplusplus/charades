#!/bin/bash -l
#SBATCH -J sdiag3
#SBATCH -t 00:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag3_%j.out
# Where a wider window's cost goes, on an allocation without c455-081
# (charades RESULTS.md section 83).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 diag3.slurm
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/sdiag3/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-50)"
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
cs() { # tag nodes agg end workloads arms extra
  ( export NODES=$2 AGG=$3 END=$4 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="$P $7"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm 16 pp:512 512000 gauss:100:1000:100 w:250 ""
cs warm2 16 pp:512 512000 gauss:100:1000:100 w:250 ""
for rep in 1 2 3; do
  for wl in gauss:100:1000:100 gauss:100:1000:2000; do
    for w in 250 400 600; do
      cs W_${wl//:/_}_w${w}_r$rep 16 pp:512 512000 $wl w:$w "--gvt-trace=2 --pe-stats=1"
    done
  done
  log "W REP $rep DONE"
done
log "SDIAG3 DONE"
