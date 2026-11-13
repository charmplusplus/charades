#!/bin/bash -l
#SBATCH -A TG-ASC050039N
#SBATCH -o /work2/09863/rrao/stampede3/charades-runs/wsweep/job_%j.out
# Window sweep at 16 and 32 nodes (charades RESULTS.md "Window sweep at 16 and
# 32 nodes", design 2026-10-24). Runs at the job's own node count.
# Submit: sbatch -p skx-dev -N 16 -n 768 -t 00:50:00 -J wsw16 wsweep.slurm
#         sbatch -p skx     -N 32 -n 1536 -t 00:50:00 -J wsw32 wsweep.slurm
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/wsweep; mkdir -p $OUT
N=$SLURM_JOB_NUM_NODES REPS=${REPS:-2}
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-main; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID on $N nodes; charades $(git -C $W/$T log --oneline -1 | cut -c1-40)"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24 NODES=$N END=512000 AGG=pp:512
WL="gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0"
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
cs() { # tag arms extra
  ( export WORKLOADS="$WL" ARMS="$2" EXTRA_ARGS="$P ${3:-}"
    RUNS=$OUT/$1_n${N}_r$rep $S 1 $OUT/$1_n${N}_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 n$N /" ); }
D=$W/devastator; DB=$D/bin/ofi-psm2/phold-gauss-p$((2 * N))w23
dv() { # sigma window
  ( export WINDOW=$2 RUNS=$OUT/deva LPS_PER_RANK=128 START=15 LOOKAHEAD=100 MEAN=1000 SIGMA=$1 END=512000 CAP=60 AFFINITY=0
    LABEL=deva_n${N}_s$1_w$2_r$rep bash $D/run_phold.sh $DB $N --rng=clcg4 | head -1 ); }
for rep in $(seq $REPS); do
  log "rep $rep"
  cs fixed "w:400 w:600 w:800 w:1200"
  cs ctl "q:0.001"
  cs ctlk0 "q:0.001" "--ctl-agg-kappa=0"
  for s in 100 2000; do dv $s 1000; dv $s 2000; done
  log "REP $rep DONE"
done
log "WSWEEP DONE"
