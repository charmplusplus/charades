#!/bin/bash
# Full-node reruns (charades CONTEXT.md "Full-node reruns", design 2026-10-22).
# Charades: ctl_sweep.sh defaults (full nodes: 2 x 23 PEs, psm2 64 KB, 16
# devices, PP 512, margin 8, charades-exp). Devastator: ofi-psm2 8 x 23.
# Usage: full_rerun.sh "<stages: A B C>" <reps>
# Stages run in order; within a stage reps are outermost, so a partial stage
# still has whole reps.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/full; mkdir -p $OUT
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
D=$W/devastator; DB=$D/bin/ofi-psm2/phold-gauss-p8w23
export NODES=4 LPS_PER_PE=128 LPC=16 CAP=120
STAGES=${1:-"A B C"} REPS=${2:-3}

cs() { # tag agg end workloads arms
  ( export AGG=$2 END=$3 WORKLOADS="$4" ARMS="$5"
    RUNS=$OUT/$1 $S 1 $OUT/$1_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
dv() { # tag end lookahead mean sigma window extra-args...
  local tag=$1 end=$2 la=$3 mean=$4 sig=$5 w=$6; shift 6
  ( [ $w = adaptive ] && unset WINDOW || export WINDOW=$w
    export RUNS=$OUT/deva_$tag LPS_PER_RANK=128 START=15 LOOKAHEAD=$la MEAN=$mean SIGMA=$sig END=$end CAP=120 AFFINITY=0
    LABEL=${tag}_s${sig}_w${w}_rep$rep bash $D/run_phold.sh $DB 4 "$@" | head -1 ); }

for st in $STAGES; do
  case $st in
  A)
    for rep in $(seq 1 $REPS); do
      for agg in pp:512 off; do
        cs phase_${agg%%:*} $agg 256000 "phases:10:200:100:1000:1.0:32000 phases:10:200:100:1000:0.5:32000" \
           "blk:0 w:25 w:50 w:100 w:250 q:0.001 hill:250"
      done
      for rem in 0.5 1.0; do for w in adaptive 50 100 250 500 1000 2000; do
        dv phase_r$rem 256000 10 200 0 $w --remote=$rem --phase-length=32000 --alt-lookahead=100 --alt-mean=1000
      done; done
      echo "A REP $rep DONE"
    done ;;
  B)
    HI="gauss:100:1000:100 gauss:100:1000:500 gauss:100:1000:1000 gauss:100:1000:2000 gauss:100:1000:4000 steady:100:1000:1.0"
    LO="gauss:10:200:500 gauss:10:200:2000 steady:10:200:1.0"
    for rep in $(seq 1 $REPS); do
      for agg in pp:512 off; do
        cs gauss_${agg%%:*}_hi $agg 512000 "$HI" "blk:0 w:50 w:100 w:250 w:500 q:0.001 hill:250"
        cs gauss_${agg%%:*}_lo $agg 128000 "$LO" "blk:0 w:25 w:50 w:100 w:250 q:0.001 hill:250"
      done
      for w in adaptive 250 500 1000 2000; do
        for sig in 100 500 1000 2000 4000; do dv gauss_hi 512000 100 1000 $sig $w; done
        dv gauss_hi 512000 100 1000 0 $w --remote=1.0
      done
      for w in adaptive 50 100 200 500; do
        for sig in 500 2000; do dv gauss_lo 128000 10 200 $sig $w; done
        dv gauss_lo 128000 10 200 0 $w --remote=1.0
      done
      echo "B REP $rep DONE"
    done ;;
  C)
    for rep in $(seq 1 $REPS); do
      for agg in pp:512 off; do
        cs traffic_${agg%%:*}_hi $agg 512000 "traffic:100:1000:128:15:0:0 traffic:100:1000:128:15:0.5:32 traffic:100:1000:5888:15:0:0" \
           "blk:0 w:50 w:100 w:250 w:500 w:1000 q:0.001 hill:250"
        cs traffic_${agg%%:*}_lo $agg 128000 "traffic:10:200:5888:15:0:0" "blk:0 w:25 w:50 w:100 w:250 q:0.001 hill:250"
      done
      echo "C REP $rep DONE"
    done ;;
  esac
done
echo FULL DONE
