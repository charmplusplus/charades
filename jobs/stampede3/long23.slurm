#!/bin/bash -l
#SBATCH -J long23
#SBATCH -t 01:58:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/long23_%j.out
# Charades and Devastator on long runs (end time 2,048,000), 1/4/16 nodes,
# sigma 2,000, sigma 4,000 and uniform, 3 reps; Charades code 4e6d8b8 (defaults),
# htram 699c3a9, Reconverse 22871c6 (charades RESULTS.md section 123).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 long23.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/long23/j$SLURM_JOB_ID; mkdir -p $OUT
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
GS="gauss:100:1000:2000 gauss:100:1000:4000"; UNI=steady:100:1000:1.0; ARMS="w:250 w:400 w:600 q:0.001"
cs warm 16 pp:512 512000 gauss:100:1000:100 w:250
cs warm2 16 pp:512 512000 gauss:100:1000:100 w:250
for rep in 1 2 3; do
  for n in 16 4 1; do
    for a in pp:512 pp:2048; do cs hi_${a/:/}_n${n}_r$rep $n $a $END "$GS" "$ARMS"; done
    for a in wps:512 pp:512; do cs uni_${a/:/}_n${n}_r$rep $n $a $END $UNI "$ARMS"; done
    WS="500 1000"; [ $n = 16 ] && WS="500 1000 2000"
    for w in $WS; do
      for sig in 2000 4000; do dv hi $n $END 100 1000 $sig $w; done
      dv hi $n $END 100 1000 0 $w --remote=1.0
    done
    log "REP $rep N $n DONE"
  done
done
log "LONG23 DONE"
