#!/bin/bash -l
#SBATCH -J sdiag4
#SBATCH -t 00:40:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag4_%j.out
# What rank 0 does while it is late: --gvt-trace=3 wave-aligned timers and a
# per-thread perf profile of process 0 (charades RESULTS.md section 85).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 diag4.slurm
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/sdiag4/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-50)"
PERF_OK=0
if srun -N 1 -n 1 --mpi=none -J perfcheck perf --version 2>&1 | grep -q "perf version"; then PERF_OK=1; fi
log "perf on compute nodes: $PERF_OK"
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
cs() { # tag agg end workloads arms extra
  ( export NODES=16 AGG=$2 END=$3 WORKLOADS="$4" ARMS="$5" EXTRA_ARGS="$P $6"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm pp:512 512000 gauss:100:1000:100 w:250 ""
cs warm2 pp:512 512000 gauss:100:1000:100 w:250 ""
for rep in 1 2; do
  for wl in gauss:100:1000:100 gauss:100:1000:2000; do
    for w in 250 400; do
      t=${wl//:/_}_w${w}_r$rep
      cs T_tr_$t pp:512 512000 $wl w:$w "--gvt-trace=3 --pe-stats=1"
      cs T_off_$t pp:512 512000 $wl w:$w ""
    done
  done
  log "T REP $rep DONE"
done
if [ $PERF_OK = 1 ]; then
  for rep in 1 2; do
    for wl in gauss:100:1000:100 gauss:100:1000:2000; do
      t=${wl//:/_}_w400_r$rep; d=$OUT/P_$t; mkdir -p $d
      ( export BIN_WRAP=$W/$T/scripts/stampede3/perfwrap.sh PERF_DIR=$d
        cs P_$t pp:512 512000 $wl w:400 "--gvt-trace=3" )
      for f in $d/perf.*.data; do
        [ -e "$f" ] || continue
        perf report -i $f --stdio -q --sort tid --percent-limit 0.1 > ${f%.data}.tid.txt 2>/dev/null
        perf report -i $f --stdio -q --sort tid,sym --percent-limit 0.05 > ${f%.data}.tidsym.txt 2>/dev/null
        perf report -i $f --stdio -q --sort dso,sym --percent-limit 0.2 > ${f%.data}.sym.txt 2>/dev/null
      done
    done
    log "P REP $rep DONE"
  done
fi
log "SDIAG4 DONE"
