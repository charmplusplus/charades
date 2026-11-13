#!/bin/bash -l
#SBATCH -J fp2
#SBATCH -p skx-dev
#SBATCH -N 16
#SBATCH -n 768
#SBATCH -t 00:40:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/fp2_%j.out
# Where the fast path loses at sigma 2,000, and with WPs (charades RESULTS.md, design 2026-10-24)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/fp2; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-nw; S=$W/$T/scripts/stampede3/ctl_sweep.sh; D=$W/devastator
log "job $SLURM_JOB_ID; charades $(git -C $W/$T log --oneline -1 | cut -c1-50)"
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24 END=512000
cs() { # tag nodes agg workload arms extra
  ( export NODES=$2 AGG=$3 WORKLOADS="$4" ARMS="$5" EXTRA_ARGS="$P $6"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
dv() { # nodes sigma window
  ( export WINDOW=$3 RUNS=$OUT/deva LPS_PER_RANK=128 START=15 LOOKAHEAD=100 MEAN=1000 SIGMA=$2 END=512000 CAP=90 AFFINITY=0
    LABEL=deva_n$1_s$2_w$3_r$rep bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p$(($1 * 2))w23 $1 --rng=clcg4 | head -1 )
}
cs warm 4 pp:512 gauss:100:1000:100 w:250 ""
for rep in 1 2; do
  for N in 4 16; do for s in 100 2000; do
    for v in 0:pp 1:pp 2:pp 1:wps; do
      a=${v%%:*} m=${v##*:}
      cs fp${a}${m}_n${N}_s${s}_r$rep $N $m:512 gauss:100:1000:$s "w:250 w:400 q:0.001" "--local-fast-path=$a"
    done
    for w in 500 1000; do dv $N $s $w; done
  done; done
  log "REP $rep DONE"
done
log "FP2 DONE"
