#!/bin/bash -l
#SBATCH -J sdiag6
#SBATCH -t 00:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag6_%j.out
# Is rank 0 preempted? Per-thread scheduler statistics (run-queue wait,
# involuntary switches, allowed cores) and per-CPU interrupt time from /proc,
# with --gvt-trace=3, at 16 and 23 LCI devices (charades RESULTS.md section 89).
# Submit: sbatch -p skx-dev -N 4 -n 192 -x c455-081 diag6.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
R=$W/charades-runs; OUT=$R/sdiag6/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-50)"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
cs() { # tag ndev workload W extra   (env WRAP=1: run under schedwrap.sh)
  ( if [ -n "${WRAP:-}" ]; then mkdir -p $OUT/$1; export BIN_WRAP=$R/schedwrap.sh SCHED_DIR=$OUT/$1; fi
    export NODES=4 AGG=pp:512 END=512000 WORKLOADS="$3" ARMS="w:$4" EXTRA_ARGS="+lci_ndevices $2 +pemap 2-46:2,3-47:2 $5"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm 16 gauss:100:1000:100 250 ""
cs warm2 16 gauss:100:1000:100 250 ""
for rep in 1 2; do
  for nd in 16 23; do
    for wl in gauss:100:1000:100 gauss:100:1000:2000; do
      t=nd${nd}_${wl//:/_}_w400_r$rep
      WRAP=1 cs S_$t $nd $wl 400 "--gvt-trace=3 --pe-stats=1"
      cs off_$t $nd $wl 400 ""
    done
  done
  log "REP $rep DONE"
done
log "SDIAG6 DONE"
