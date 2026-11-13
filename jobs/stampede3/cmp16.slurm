#!/bin/bash -l
#SBATCH -J cmp16
#SBATCH -t 01:40:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/cmp16_%j.out
# Charades (+lci_ndevices 23) against Devastator at 16 nodes, same allocation,
# the 8 workloads of the scaling series, each engine over its grid, 3 reps
# interleaved (charades RESULTS.md section 91).
# Submit: sbatch -p skx -N 16 -n 768 -x c455-081 cmp16.slurm   (or skx-dev)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/cmp16/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh; D=$W/devastator
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-50)"
log "devastator binary $(ls -l --time-style=+%F_%T $D/bin/ofi-psm2/phold-gauss-p32w23 | awk '{print $6}')"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
cs() { # tag agg end workloads arms
  ( export NODES=16 AGG=$2 END=$3 WORKLOADS="$4" ARMS="$5" EXTRA_ARGS="+lci_ndevices 23 +pemap 2-46:2,3-47:2"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
dv() { # tag end lookahead mean sigma window extra...
  local tag=$1 end=$2 la=$3 mean=$4 sig=$5 w=$6; shift 6
  ( export WINDOW=$w RUNS=$OUT/deva LPS_PER_RANK=128 START=15 LOOKAHEAD=$la MEAN=$mean SIGMA=$sig END=$end CAP=90 AFFINITY=0
    LABEL=${tag}_n16_s${sig}_w${w}_r$rep bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p32w23 16 --rng=clcg4 "$@" | head -1 ); }
HI="gauss:100:1000:100 gauss:100:1000:500 gauss:100:1000:1000 gauss:100:1000:2000 gauss:100:1000:4000 steady:100:1000:1.0"
LO="gauss:10:200:500 gauss:10:200:2000"
cs warm pp:512 512000 gauss:100:1000:100 w:250
cs warm2 pp:512 512000 gauss:100:1000:100 w:250
for rep in 1 2 3; do
  for a in pp:512 pp:2048; do
    t=${a/:/}
    cs hi_${t}_r$rep $a 512000 "$HI" "w:250 w:400 w:600 q:0.001"
    cs lo_${t}_r$rep $a 128000 "$LO" "w:50 w:100 w:200 q:0.001"
  done
  cs uni_wps512_r$rep wps:512 512000 steady:100:1000:1.0 "w:250 w:400 w:600 q:0.001"
  cs lo2k_wps512_r$rep wps:512 128000 gauss:10:200:2000 "w:50 w:100 w:200 q:0.001"
  for w in 500 1000 2000; do
    for sig in 100 500 1000 2000 4000; do dv hi 512000 100 1000 $sig $w; done
    dv hi 512000 100 1000 0 $w --remote=1.0
  done
  for w in 100 200 400; do for sig in 500 2000; do dv lo 128000 10 200 $sig $w; done; done
  log "REP $rep DONE"
done
log "CMP16 DONE"
