#!/bin/bash -l
#SBATCH -J sdiag5
#SBATCH -t 00:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag5_%j.out
# Are late ranks 0 and 1 the threads that poll LCI device 0? Vary +lci_ndevices
# (4/8/16/23 -> device 0 polled by ranks 0-5 / 0-2 / 0-1 / 0) with
# --gvt-trace=3, plus PSM2_RCVTHREAD=0 at 16 devices (charades RESULTS.md section 87).
# Submit: sbatch -p skx-dev -N 4 -n 192 -x c455-081 diag5.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/sdiag5/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-50)"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
cs() { # tag ndev workload W extra  (env RT=0: PSM2_RCVTHREAD=0)
  ( [ -n "${RT:-}" ] && export PSM2_RCVTHREAD=$RT
    export NODES=4 AGG=pp:512 END=512000 WORKLOADS="$3" ARMS="w:$4" EXTRA_ARGS="+lci_ndevices $2 +pemap 2-46:2,3-47:2 $5"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm 16 gauss:100:1000:100 250 ""
cs warm2 16 gauss:100:1000:100 250 ""
for rep in 1 2; do
  for arm in 16 23 8 4 16rt0; do
    nd=${arm%rt0}; rt=; [ $arm != $nd ] && rt=0
    for wl in gauss:100:1000:100 gauss:100:1000:2000; do
      t=nd${arm}_${wl//:/_}_w400_r$rep
      RT=$rt cs T_tr_$t $nd $wl 400 "--gvt-trace=3 --pe-stats=1"
      RT=$rt cs T_off_$t $nd $wl 400 ""
    done
  done
  log "REP $rep DONE"
done
log "SDIAG5 DONE"
