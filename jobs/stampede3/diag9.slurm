#!/bin/bash -l
#SBATCH -J sdiag9
#SBATCH -t 00:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag9_%j.out
# Rank 0's faults: perf (user-mode faults, every one) against /proc in the same
# run; a light /proc sampler; memory bound to the local socket (charades RESULTS.md section 96).
# Submit: sbatch -p skx -N 4 -n 192 -x c455-081 diag9.slurm
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
R=$W/charades-runs; OUT=$R/sdiag9/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
srun -N $SLURM_NNODES -n $SLURM_NNODES --mpi=none -J nodecfg bash -c 'echo "$(hostname -s) numa_balancing=$(cat /proc/sys/kernel/numa_balancing) thp=$(cat /sys/kernel/mm/transparent_hugepage/enabled) defrag=$(cat /sys/kernel/mm/transparent_hugepage/defrag) $(grep AnonHugePages /proc/meminfo)"' | sort
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
cs() { # tag numa(0/1) perf(0/1) sample(full/light/none) workload extra
  ( mkdir -p $OUT/$1
    if [ "$2$3$4" != "00none" ]; then export BIN_WRAP=$R/gwrap.sh SCHED_DIR=$OUT/$1 G_NUMA=$2 G_PERF=$3 G_SAMPLE=$4; fi
    export NODES=4 AGG=pp:512 END=512000 WORKLOADS="$5" ARMS="w:400" EXTRA_ARGS="+lci_ndevices 23 +pemap 2-46:2,3-47:2 $6"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
TR="--gvt-trace=3 --pe-stats=1"
S1=gauss:100:1000:100; S2=gauss:100:1000:2000
cs warm 0 0 none $S1 ""
cs warm2 0 0 none $S1 ""
for rep in 1 2; do
  cs T_plain_s100_r$rep 0 0 none $S1 "$TR"
  cs T_fullperf_s100_r$rep 0 1 full $S1 "$TR"
  cs T_light_s100_r$rep 0 0 light $S1 "$TR"
  cs T_numa_s100_r$rep 1 0 light $S1 "$TR"
  cs T_light_s2000_r$rep 0 0 light $S2 "$TR"
  cs T_numa_s2000_r$rep 1 0 light $S2 "$TR"
  for wl in $S1 $S2; do
    s=${wl##*:}
    cs off_plain_s${s}_r$rep 0 0 none $wl ""
    cs off_numa_s${s}_r$rep 1 0 none $wl ""
  done
  log "REP $rep DONE"
done
log "SDIAG9 DONE"
