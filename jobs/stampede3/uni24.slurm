#!/bin/bash -l
#SBATCH -J uni24
#SBATCH -t 01:00:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/uni24_%j.out
# Uniform's steady loss: WPs buffer-size perturbation on 4 and 16 nodes, plus
# --gvt-trace=4 splits; Charades code 4e6d8b8 (defaults), htram 699c3a9,
# Reconverse 22871c6 (charades RESULTS.md section 125).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 uni24.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/uni24/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-50); reconverse $(git -C $W/charm-pads-exp/contrib/reconverse log --oneline -1 | cut -c1-50)"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
UNI=steady:100:1000:1.0
cs() { # tag nodes agg extra
  ( export NODES=$2 AGG=$3 END=512000 WORKLOADS=$UNI ARMS=w:400 EXTRA_ARGS="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free $4"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm 16 pp:512 ""
cs warm2 16 pp:512 ""
for rep in 1 2; do
  for b in 512 64 32 16; do cs A_b${b}_n4_r$rep 4 wps:$b ""; done
  for b in 512 16; do cs B_b${b}_n16_r$rep 16 wps:$b ""; done
  log "REP $rep DONE"
  cs AT_b512_n4_r$rep 4 wps:512 "--gvt-trace=4 --pe-stats=1"
  cs AT_b16_n4_r$rep 4 wps:16 "--gvt-trace=4 --pe-stats=1"
  cs BT_b512_n16_r$rep 16 wps:512 "--gvt-trace=4 --pe-stats=1"
  log "TRACED REP $rep DONE"
done
log "UNI24 DONE"
