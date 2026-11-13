#!/bin/bash -l
#SBATCH -J nodewaves
#SBATCH -p skx-dev
#SBATCH -N 16
#SBATCH -n 768
#SBATCH -t 00:40:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /work2/09863/rrao/stampede3/charades-runs/nodewaves/job_%j.out
# --gvt-node-waves on Stampede3 (charades RESULTS.md, design 2026-10-24):
# message path (0) vs per-process waves (1), same binary (charades-nw).
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/nodewaves; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-nw; S=$W/$T/scripts/stampede3/ctl_sweep.sh
strings $W/$T/models/phold/simple/phold | grep -q gvt-node-waves || { log "FAILED: build lacks --gvt-node-waves"; exit 1; }
log "job $SLURM_JOB_ID; charades $(git -C $W/$T log --oneline -1 | cut -c1-50)"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24 END=512000 AGG=pp:512
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
cs() { # tag nodes workload arms extra
  ( export NODES=$2 WORKLOADS="$3" ARMS="$4" EXTRA_ARGS="$P $5"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm 4 gauss:100:1000:100 w:250 ""   # the job's first launch can be slow (cold $WORK)
for rep in 1 2; do for N in 4 16; do for s in 100 2000; do for w in 250 400; do for nw in 0 1; do
  cs nw${nw}_n${N}_s${s}_w${w}_r$rep $N gauss:100:1000:$s w:$w "--gvt-trace=1 --gvt-node-waves=$nw"
done; done; done; done
  for s in 100 2000; do for nw in 0 1; do
    cs ctl_nw${nw}_n16_s${s}_r$rep 16 gauss:100:1000:$s q:0.001 "--gvt-trace=1 --gvt-node-waves=$nw"
  done; done
  log "REP $rep DONE"
done
log "NODEWAVES DONE"
