#!/bin/bash -l
#SBATCH -J allreduce
#SBATCH -p skx-dev
#SBATCH -N 16
#SBATCH -n 768
#SBATCH -t 00:35:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /work2/09863/rrao/stampede3/charades-runs/allreduce/job2_%j.out
# Cross-process part of a GVT advance (charades RESULTS.md, design 2026-10-24):
# redbench -m 3 / -m 4 at 1-16 nodes; Charades --gvt-wave-allreduce 0/1, traced.
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/allreduce; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-nw; S=$W/$T/scripts/stampede3/ctl_sweep.sh; RB=$W/charades-runs/gvtprobe/redbench/redbench
strings $W/$T/models/phold/simple/phold | grep -q gvt-wave-allreduce || { log "FAILED: build lacks --gvt-wave-allreduce"; exit 1; }
log "job $SLURM_JOB_ID; charades $(git -C $W/$T log --oneline -1 | cut -c1-50)"
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24 END=512000 AGG=pp:512
cs() { # tag nodes workload arms extra
  ( export NODES=$2 WORKLOADS="$3" ARMS="$4" EXTRA_ARGS="$P $5"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm 4 gauss:100:1000:100 w:250 ""
log "redbench"
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/$T/scripts/stampede3/env.sh >/dev/null 2>&1
  for rep in 1 2; do for N in 1 16; do for m in 3 4; do
    timeout -s TERM 120 srun --mpi=pmi2 --kill-on-bad-exit=1 -N $N -n $((2 * N)) -c 24 -J rb $RB +pe $((46 * N)) $P -m $m -r 20000 -w 1000 > $OUT/rb2_n${N}_m${m}_r$rep.out 2>&1
    echo "n$N m$m r$rep rc=$? $(grep REDBENCH $OUT/rb2_n${N}_m${m}_r$rep.out)"
  done; done; done ) | tee $OUT/redbench2.txt
log "Charades"
for rep in 1 2; do
  for N in 4 16; do for s in 100 2000; do for a in 0 1; do
    cs ar${a}_n${N}_s${s}_r$rep $N gauss:100:1000:$s w:250 "--gvt-trace=1 --gvt-wave-allreduce=$a"
  done; done; done
  for s in 100 2000; do for a in 0 1; do
    cs ctl_ar${a}_n16_s${s}_r$rep 16 gauss:100:1000:$s q:0.001 "--gvt-trace=1 --gvt-wave-allreduce=$a"
  done; done
  log "REP $rep DONE"
done
log "ALLREDUCE DONE"
