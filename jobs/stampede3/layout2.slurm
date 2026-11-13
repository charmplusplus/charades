#!/bin/bash -l
#SBATCH -J layout2
#SBATCH -p skx-dev
#SBATCH -N 16
#SBATCH -n 768
#SBATCH -t 00:35:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/layout2_%j.out
# Padded shared atomics (charades RESULTS.md section 74)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
N=$SLURM_NNODES
OUT=$W/charades-runs/layout2/n$N; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-nw; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID, $N nodes; charades-nw $(git -C $W/charades-nw log --oneline -1 | cut -c1-8) charades-pad $(git -C $W/charades-pad log --oneline -1 | cut -c1-8) htram-pad $(git -C $W/htram-pad log --oneline -1 | cut -c1-8); htram $(git -C $W/htram log --oneline -1 | cut -c1-10)"
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
export TREE=$T NODES=$N LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24 END=512000
cs() { # tag agg arms extra
  ( export AGG=$2 WORKLOADS="gauss:100:1000:100 gauss:100:1000:2000" ARMS="$3" EXTRA_ARGS="$P $4"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm pp:512 w:250 ""
cs warm2 pp:512 w:250 ""
NEVER="--agg-auto=1 --agg-auto-advances=1000000000"
NEVER="--agg-auto=1 --agg-auto-advances=1000000000"
for rep in 1 2 3; do
  for v in $(for t in nw pad; do for a in pp512 pp512i pp2048 pp2048i; do echo ${t}_$a; done; done | shuf --random-source=<(yes $rep)); do
    t=${v%%_*} a=${v#*_}
    x=""; case $a in *i) x="$NEVER"; a=${a%i} ;; esac
    ( export TREE=charades-$t; cs ${v}_r$rep ${a/pp/pp:} w:250 "$x" )
  done
  log "REP $rep DONE"
done
log "LAYOUT2 DONE"



