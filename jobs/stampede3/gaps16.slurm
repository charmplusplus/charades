#!/bin/bash -l
#SBATCH -J gaps16
#SBATCH -p skx-dev
#SBATCH -N 16
#SBATCH -n 768
#SBATCH -t 00:45:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/gaps16_%j.out
# The 16-node gaps with wider windows (charades RESULTS.md section 67)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
N=$SLURM_NNODES
OUT=$W/charades-runs/gaps16; mkdir -p $OUT
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
cs warm pp:512 512000 gauss:100:1000:100 w:250
cs warm2 pp:512 512000 gauss:100:1000:100 w:250
for rep in 1 2; do
  for a in pp:512 wps:512; do
    cs uni_${a/:/}_r$rep $a 512000 steady:100:1000:1.0 "w:400 w:600 w:800 w:1000 q:0.001"
  done
  for a in pp:512 pp:2048 wps:512; do
    cs lo_${a/:/}_r$rep $a 128000 "gauss:10:200:500 gauss:10:200:2000" "w:50 w:100 w:150 w:200 w:300 q:0.001"
  done
  for w in 500 1000 2000; do dv hi 512000 100 1000 0 $w --remote=1.0; done
  for w in 100 200 400 800; do for sig in 500 2000; do dv lo 128000 10 200 $sig $w; done; done
  log "REP $rep DONE"
done
log "GAPS16 DONE"
