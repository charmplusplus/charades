#!/bin/bash -l
#SBATCH -J pestats
#SBATCH -p skx-dev
#SBATCH -N 16
#SBATCH -n 768
#SBATCH -t 00:20:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/pestats_%j.out
# What makes a process late to a count wave (charades RESULTS.md, design 2026-10-24).
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/pestats; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-nw; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; charades $(git -C $W/$T log --oneline -1 | cut -c1-50)"
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24 END=512000 AGG=pp:512
cs() { # tag nodes workload arms extra
  ( export NODES=$2 WORKLOADS="$3" ARMS="$4" EXTRA_ARGS="$P $5"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm 4 gauss:100:1000:100 w:250 ""
for rep in 1 2; do
  for N in 4 16; do for s in 100 2000; do
    cs ps_n${N}_s${s}_r$rep $N gauss:100:1000:$s w:250 "--gvt-trace=1 --pe-stats=1"
  done; done
  log "REP $rep DONE"
done
log "PESTATS DONE"
