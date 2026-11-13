#!/bin/bash -l
#SBATCH -J sdiag13
#SBATCH -t 01:00:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag13_%j.out
# Why one PE holds up each GVT advance at uniform and sigma 2,000: per-PE wave
# records (--gvt-trace=4), and --gvt-wave-events 0/32 against 128; charades
# ff3f4fd, htram 3cb3d1e (charades RESULTS.md section 104).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 diag13.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/sdiag13/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-60)"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
UNI=steady:100:1000:1.0; S2K=gauss:100:1000:2000
cs() { # tag nodes agg workload extra
  ( export NODES=$2 AGG=$3 END=512000 WORKLOADS="$4" ARMS="w:400" EXTRA_ARGS="+lci_ndevices 23 +pemap 2-46:2,3-47:2 $5"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm 16 pp:512 gauss:100:1000:100 ""
cs warm2 16 pp:512 gauss:100:1000:100 ""
for rep in 1 2; do
  for n in 16 4; do
    for c in "uni wps:512 $UNI" "uni pp:512 $UNI" "s2k pp:512 $S2K"; do
      set -- $c; t=${1}_${2/:/}
      cs T_${t}_n${n}_r$rep $n $2 $3 "--gvt-trace=4 --pe-stats=1"
      cs off_${t}_n${n}_r$rep $n $2 $3 ""
    done
  done
  for c in "uni wps:512 $UNI 0 32" "uni pp:512 $UNI 0 32" "s2k pp:512 $S2K 32"; do
    set -- $c; t=${1}_${2/:/}; a=$2; wl=$3; shift 3
    for k in "$@"; do cs we${k}_${t}_n16_r$rep 16 $a $wl "--gvt-wave-events=$k"; done
  done
  log "REP $rep DONE"
done
log "SDIAG13 DONE"
