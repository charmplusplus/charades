#!/bin/bash -l
#SBATCH -J sdiag8
#SBATCH -t 00:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag8_%j.out
# Which system calls rank 0 makes: strace -ff on process 0 (charades RESULTS.md section 93).
# Submit: sbatch -p skx-dev -N 4 -n 192 -x c455-081 diag8.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
R=$W/charades-runs; OUT=$R/sdiag8/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=90 PPN=2 PEPP=23 CPT=24
MTRIM="glibc.malloc.trim_threshold=1073741824:glibc.malloc.top_pad=67108864"
cs() { # tag tunables workload W extra   (env WRAP=st: strace process 0)
  ( [ -n "$2" ] && export GLIBC_TUNABLES=$2
    [ "${WRAP:-}" = st ] && { mkdir -p $OUT/$1; export BIN_WRAP=$R/stwrap.sh ST_DIR=$OUT/$1; }
    export NODES=4 AGG=pp:512 END=512000 WORKLOADS="$3" ARMS="w:$4" EXTRA_ARGS="+lci_ndevices 23 +pemap 2-46:2,3-47:2 $5"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm "" gauss:100:1000:100 250 ""
cs warm2 "" gauss:100:1000:100 250 ""
for rep in 1 2; do
  WRAP=st cs ST_m0_s100_r$rep "" gauss:100:1000:100 400 "--gvt-trace=3"
  WRAP=st cs ST_mtrim_s100_r$rep "$MTRIM" gauss:100:1000:100 400 "--gvt-trace=3"
  WRAP=st cs ST_m0_s2000_r$rep "" gauss:100:1000:2000 400 "--gvt-trace=3"
  cs off_m0_s100_r$rep "" gauss:100:1000:100 400 ""
  log "REP $rep DONE"
done
du -sh $OUT
log "SDIAG8 DONE"
