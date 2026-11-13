#!/bin/bash -l
#SBATCH -J iso
#SBATCH -p skx-dev
#SBATCH -N 16
#SBATCH -n 768
#SBATCH -t 00:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/iso_%j.out
# Why --agg-auto differs from the fixed setting it chose (charades RESULTS.md section 70)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
N=$SLURM_NNODES
OUT=$W/charades-runs/iso/n$N; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-nw; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID, $N nodes; charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-10)"
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
export TREE=$T NODES=$N LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24 END=512000
cs() { # tag agg arms extra
  ( export AGG=$2 WORKLOADS="gauss:100:1000:100 gauss:100:1000:2000" ARMS="$3" EXTRA_ARGS="$P $4"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm pp:512 w:250 ""
cs warm2 pp:512 w:250 ""
NEVER="--agg-auto=1 --agg-auto-advances=1000000000"
for rep in 1 2 3; do
  for v in $(printf "A B C D E\n" | tr " " "\n" | shuf --random-source=<(yes $rep)); do
    case $v in
      A) cs A_r$rep pp:512 w:250 "" ;;
      B) cs B_r$rep pp:2048 w:250 "" ;;
      C) cs C_r$rep pp:512 w:250 "$NEVER" ;;
      D) cs D_r$rep pp:2048 w:250 "$NEVER" ;;
      E) cs E_r$rep pp:512 w:250 "--agg-auto=1" ;;
    esac
  done
  log "REP $rep DONE"
done
log "ISO DONE"
