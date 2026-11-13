#!/bin/bash -l
#SBATCH -J sdiag10
#SBATCH -t 00:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag10_%j.out
# Name the lock rank 0 takes 10x as often: strace -f -k -e trace=futex on
# process 0 (charades RESULTS.md section 98).
# Submit: sbatch -p skx-dev -N 4 -n 192 -x c455-081 diag10.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
R=$W/charades-runs; OUT=$R/sdiag10/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=120 PPN=2 PEPP=23 CPT=24
cs() { # tag workload   (env WRAP=1: strace -k on process 0)
  ( mkdir -p $OUT/$1
    [ -n "${WRAP:-}" ] && export BIN_WRAP=$R/skwrap.sh ST_DIR=$OUT/$1
    export NODES=4 AGG=pp:512 END=512000 WORKLOADS="$2" ARMS="w:400" EXTRA_ARGS="+lci_ndevices 23 +pemap 2-46:2,3-47:2 --gvt-trace=3"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm gauss:100:1000:100
cs warm2 gauss:100:1000:100
WRAP=1 cs K_s100_r1 gauss:100:1000:100
WRAP=1 cs K_s100_r2 gauss:100:1000:100
WRAP=1 cs K_s2000_r1 gauss:100:1000:2000
du -sh $OUT
log "SDIAG10 DONE"
