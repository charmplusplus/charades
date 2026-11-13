#!/bin/bash -l
#SBATCH -J sdiag19
#SBATCH -t 01:00:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag19_%j.out
# What paces GVT at sigma 2,000 (traced), GVT bucket size, horizon margin with
# wider windows; charades cedf3d7, htram 699c3a9, Reconverse 22871c6
# (charades RESULTS.md section 115).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 diag19.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/sdiag19/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-50); htram $(git -C $W/htram log --oneline -1 | cut -c1-50); reconverse $(git -C $W/charm-pads-exp/contrib/reconverse log --oneline -1 | cut -c1-50)"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
S2K=gauss:100:1000:2000; S4K=gauss:100:1000:4000
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
cs() { # tag nodes workloads arms buckets margins extra
  ( export NODES=$2 AGG=pp:512 END=512000 WORKLOADS="$3" ARMS="$4" BUCKETS="$5" MARGINS="$6" EXTRA_ARGS="$L $7"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm 16 gauss:100:1000:100 w:250 8 8 ""
cs warm2 16 gauss:100:1000:100 w:250 8 8 ""
for rep in 1 2; do
  # A: traced, with untraced pairs
  for n in 16 4; do
    cs T_w400_n${n}_r$rep $n $S2K w:400 8 8 "--gvt-trace=4 --pe-stats=1"
    cs off_w400_n${n}_r$rep $n $S2K w:400 8 8 ""
  done
  for w in 250 600; do
    cs T_w${w}_n16_r$rep 16 $S2K w:$w 8 8 "--gvt-trace=4 --pe-stats=1"
    cs off_w${w}_n16_r$rep 16 $S2K w:$w 8 8 ""
  done
  log "A REP $rep DONE"
  # B: bucket size
  for n in 16 4; do
    for b in 8 16 32; do
      cs B_b${b}_n${n}_r$rep $n "$S2K $S4K" "w:400 q:0.001" $b 8 ""
    done
  done
  log "B REP $rep DONE"
  # C: margin x window
  for m in 4 8 16; do
    cs C_m${m}_n16_r$rep 16 $S2K "w:400 w:600" 8 $m ""
  done
  log "C REP $rep DONE"
done
log "SDIAG19 DONE"
