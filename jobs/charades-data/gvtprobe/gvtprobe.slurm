#!/bin/bash -l
#SBATCH -J gvtprobe
#SBATCH -p skx-dev
#SBATCH -N 16
#SBATCH -n 768
#SBATCH -t 00:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /work2/09863/rrao/stampede3/charades-runs/gvtprobe/job_%j.out
# GVT round cost at 4 and 16 nodes (charades RESULTS.md, design 2026-10-24).
# A: tools/redbench alone at 1-16 nodes; B: Charades with --gvt-trace=1;
# C: --gvt-wave-events 0 vs 128 at 16 nodes.
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/gvtprobe; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-main; S=$W/$T/scripts/stampede3/ctl_sweep.sh
RB=$OUT/redbench/redbench
[ -x $RB ] || { log "FAILED: no $RB"; exit 1; }
log "job $SLURM_JOB_ID; charades $(git -C $W/$T log --oneline -1 | cut -c1-40)"
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"

log "A: redbench"
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/$T/scripts/stampede3/env.sh >/dev/null 2>&1
  for rep in 1 2; do for N in 1 2 4 8 16; do
    timeout -s TERM 120 srun --mpi=pmi2 --kill-on-bad-exit=1 -N $N -n $((2 * N)) -c 24 -J rb_n$N \
      $RB +pe $((46 * N)) $P -r 20000 -w 1000 > $OUT/redbench_n${N}_r$rep.out 2>&1
    echo "rc=$? $(grep REDBENCH $OUT/redbench_n${N}_r$rep.out)"
  done; done ) | tee -a $OUT/redbench_results.txt

export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24 END=512000 AGG=pp:512
cs() { # tag nodes workload arm extra
  ( export NODES=$2 WORKLOADS="$3" ARMS="$4" EXTRA_ARGS="$P $5"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
log "B: Charades with --gvt-trace=1"
for rep in 1 2; do for N in 4 16; do for s in 100 2000; do for w in 250 400; do
  cs tr_n${N}_s${s}_w${w}_r$rep $N gauss:100:1000:$s w:$w "--gvt-trace=1"
done; done; done; done
log "C: --gvt-wave-events"
for rep in 1 2; do for e in 0 128; do
  cs we${e}_r$rep 16 gauss:100:1000:2000 w:400 "--gvt-trace=1 --gvt-wave-events=$e"
done; done
log "GVTPROBE DONE"
