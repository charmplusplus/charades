#!/bin/bash
# RNG fairness (Devastator xorshift vs clcg4) and fewer network pollers for Charades at sigma 100.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/diag1; S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
D=$W/devastator; DB=$D/bin/ofi-psm2/phold-gauss-p8w23
export NODES=4 LPS_PER_PE=128 LPC=16 CAP=120
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
dv() { # tag sigma window extra
  local tag=$1 sig=$2 w=$3; shift 3
  ( export RUNS=$OUT/deva_rng LPS_PER_RANK=128 START=15 LOOKAHEAD=100 MEAN=1000 SIGMA=$sig END=512000 CAP=60 AFFINITY=0 WINDOW=$w
    LABEL=${tag}_s${sig}_w${w}_rep$rep bash $D/run_phold.sh $DB 4 "$@" | head -1 ); }
for rep in 1 2 3; do
  for sig in 100 2000; do
    dv xor $sig 1000
    dv clcg4 $sig 1000 --rng=clcg4
  done
  for k in 0 2 4; do
    ex=""; [ $k != 0 ] && ex="+backend_poll_thread $k"
    ( export AGG=pp:512 END=512000 WORKLOADS="gauss:100:1000:100 gauss:100:1000:2000" ARMS="w:250" EXTRA_ARGS="$P $ex"
      RUNS=$OUT/poll$k $S 1 $OUT/poll${k}_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/poll$k /" )
  done
  echo "[$(date +%T)] C2 REP $rep DONE"
done
echo "[$(date +%T)] DIAG1C DONE"
