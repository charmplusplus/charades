#!/bin/bash -l
#SBATCH -J hsel
#SBATCH -t 01:15:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/hsel_%j.out
# Which htram mode and buffer for which workload, fast path on (charades RESULTS.md section 65).
# Submit: sbatch -p skx-dev -N 16 -n 768 hsel.slurm ; sbatch -p skx -N 4 -n 192 hsel.slurm
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
N=$SLURM_NNODES
OUT=$W/charades-runs/hsel/n$N; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-nw; S=$W/$T/scripts/stampede3/ctl_sweep.sh; D=$W/devastator
DB=$D/bin/ofi-psm2/phold-gauss-p$((2 * N))w23
log "job $SLURM_JOB_ID, $N nodes; charades $(git -C $W/$T log --oneline -1 | cut -c1-60)"
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
export TREE=$T NODES=$N LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
cs() { # tag agg end workloads arms
  ( export AGG=$2 END=$3 WORKLOADS="$4" ARMS="$5" EXTRA_ARGS="$P"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
dv() { # tag end lookahead mean sigma window extra...
  local tag=$1 end=$2 la=$3 mean=$4 sig=$5 w=$6; shift 6
  ( export WINDOW=$w RUNS=$OUT/deva LPS_PER_RANK=128 START=15 LOOKAHEAD=$la MEAN=$mean SIGMA=$sig END=$end CAP=90 AFFINITY=0
    LABEL=${tag}_s${sig}_w${w}_r$rep bash $D/run_phold.sh $DB $N --rng=clcg4 "$@" | head -1 ); }
HI="gauss:100:1000:100 gauss:100:1000:500 gauss:100:1000:1000 gauss:100:1000:2000 gauss:100:1000:4000 steady:100:1000:1.0"
LO="gauss:10:200:500 gauss:10:200:2000"
# Warm every node: a first launch on an untouched node can print nothing until the cap
cs warm pp:512 512000 gauss:100:1000:100 w:250
cs warm2 pp:512 512000 gauss:100:1000:100 w:250
for rep in 1 2; do
  for a in pp:512 wps:512 pp:128 wps:128 pp:2048 wps:2048; do
    t=${a/:/}
    cs hi_${t}_r$rep $a 512000 "$HI" "w:250 w:400 q:0.001"
    cs lo_${t}_r$rep $a 128000 "$LO" "w:50 w:100 q:0.001"
  done
  for w in 500 1000; do
    for sig in 100 500 1000 2000 4000; do dv hi 512000 100 1000 $sig $w; done
    dv hi 512000 100 1000 0 $w --remote=1.0
  done
  for w in 100 200 400; do for sig in 500 2000; do dv lo 128000 10 200 $sig $w; done; done
  log "REP $rep DONE"
done
log "HSEL DONE"
