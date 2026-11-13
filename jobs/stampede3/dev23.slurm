#!/bin/bash -l
#SBATCH -J dev23
#SBATCH -t 01:15:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/dev23_%j.out
# +lci_ndevices 23 (one per PE) against 16 at 16 nodes, the 8 workloads of
# the scaling series, controller and one fixed W (charades RESULTS.md section 89).
# Submit: sbatch -p skx -N 16 -n 768 -x c455-081 dev23.slurm   (or skx-dev)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/dev23/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-50)"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
cs() { # tag ndev end workloads arms
  ( export NODES=16 AGG=pp:512 END=$3 WORKLOADS="$4" ARMS="$5" EXTRA_ARGS="+lci_ndevices $2 +pemap 2-46:2,3-47:2"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
HI="gauss:100:1000:100 gauss:100:1000:500 gauss:100:1000:1000 gauss:100:1000:2000 gauss:100:1000:4000 steady:100:1000:1.0"
LO="gauss:10:200:500 gauss:10:200:2000"
cs warm 16 512000 gauss:100:1000:100 w:250
cs warm2 23 512000 gauss:100:1000:100 w:250
for rep in 1 2 3; do
  for nd in 16 23; do
    cs hi_nd${nd}_r$rep $nd 512000 "$HI" "w:400 q:0.001"
    cs lo_nd${nd}_r$rep $nd 128000 "$LO" "w:100 q:0.001"
  done
  log "REP $rep DONE"
done
log "DEV23 DONE"
