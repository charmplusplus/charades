#!/bin/bash -l
#SBATCH -J long26
#SBATCH -t 01:58:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/long26_%j.out
# Charades and Devastator on long runs, 1/4/16 nodes: lookahead 100 sigma 100,
# 500, 1,000 (end 2,048,000) and lookahead 10 sigma 500, 2,000 (end 512,000),
# 3 reps; Charades code 0cf5341 (defaults), htram 699c3a9, Reconverse 22871c6
# (charades RESULTS.md section 129).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 long26.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/long26/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh; D=$W/devastator
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-50); reconverse $(git -C $W/charm-pads-exp/contrib/reconverse log --oneline -1 | cut -c1-50)"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=120 PPN=2 PEPP=23 CPT=24
END=2048000
cs() { # tag nodes agg end workloads arms
  ( export NODES=$2 AGG=$3 END=$4 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
dv() { # tag nodes end lookahead mean sigma window extra...
  local tag=$1 n=$2 end=$3 la=$4 mean=$5 sig=$6 w=$7; shift 7
  ( export WINDOW=$w RUNS=$OUT/deva LPS_PER_RANK=128 START=15 LOOKAHEAD=$la MEAN=$mean SIGMA=$sig END=$end CAP=300 AFFINITY=0
    LABEL=${tag}_n${n}_s${sig}_w${w}_r$rep bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p$((2 * n))w23 $n --rng=clcg4 "$@" | head -1 ); }
HI="gauss:100:1000:100 gauss:100:1000:500 gauss:100:1000:1000"; LO="gauss:10:200:500 gauss:10:200:2000"
cs warm 16 pp:512 512000 gauss:100:1000:100 w:250
cs warm2 16 pp:512 512000 gauss:100:1000:100 w:250
for rep in 1 2 3; do
  for n in 16 4 1; do
    for a in pp:512 pp:2048; do
      cs hi_${a/:/}_n${n}_r$rep $n $a 2048000 "$HI" "w:250 w:400 w:600 q:0.001"
      cs lo_${a/:/}_n${n}_r$rep $n $a 512000 "$LO" "w:50 w:100 w:200 q:0.001"
    done
    cs lo2k_wps512_n${n}_r$rep $n wps:512 512000 gauss:10:200:2000 "w:50 w:100 w:200 q:0.001"
    WS="500 1000"; [ $n = 16 ] && WS="500 1000 2000"
    for w in $WS; do for sig in 100 500 1000; do dv hi $n 2048000 100 1000 $sig $w; done; done
    for w in 100 200 400; do for sig in 500 2000; do dv lo $n 512000 10 200 $sig $w; done; done
    log "REP $rep N $n DONE"
  done
done
log "LONG26 DONE"
