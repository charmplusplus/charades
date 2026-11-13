#!/bin/bash -l
#SBATCH -J sdiag12
#SBATCH -t 00:40:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag12_%j.out
# htram flush pass order: by index (0), rotating start (1), earliest timestamp
# first (2); htram 8ed0252, charades 64d2db8 (charades RESULTS.md section 102).
# Submit: sbatch -p skx-dev -N 4 -n 192 -x c455-081 diag12.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/sdiag12/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-60)"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
declare -A A=([fo0]="--agg-flush-order=0" [fo1]="--agg-flush-order=1" [fo2]="--agg-flush-order=2")
cs() { # tag arm workload extra
  ( export NODES=4 AGG=pp:512 END=512000 WORKLOADS="$3" ARMS="w:400" EXTRA_ARGS="+lci_ndevices 23 +pemap 2-46:2,3-47:2 ${A[$2]} $4"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm fo0 gauss:100:1000:100 ""
cs warm2 fo0 gauss:100:1000:100 ""
for rep in 1 2 3; do
  for a in fo0 fo1 fo2; do
    for wl in gauss:100:1000:100 gauss:100:1000:2000; do
      s=${wl##*:}
      cs T_${a}_s${s}_r$rep $a $wl "--gvt-trace=3 --pe-stats=1"
      cs off_${a}_s${s}_r$rep $a $wl ""
    done
  done
  log "REP $rep DONE"
done
log "SDIAG12 DONE"
