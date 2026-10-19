#!/bin/bash
# Synchronous (blocking) vs bucketed GVT on a mid-size Gaussian PHOLD.
# Usage: gvt_cost.sh <reps>   (on the idev master node)
reps=${1:-1}
source "$(dirname "$0")/env.sh"
C=$WORK/charades
out=${RUNS:-$WORK/charades-runs}/gvt_cost; mkdir -p $out; cd $out
for sigma in 100 2000; do
  printf '%s\n' "num-lps=4096" "lps-per-chare=16" "end-time=32000" "lookahead=100" \
      "start-events=15" "sigma=$sigma" > gauss_$sigma
done
for rep in $(seq $reps); do
  for sigma in 100 2000; do
    for lay in 2:2:16 2:16:16; do
      IFS=: read N n pe <<< "$lay"
      for g in blocking bucket "bucket --gvt-bucket-size=256"; do
        set -- $g; cfg=$1; shift
        tag=${cfg}${1:+_b256}
        f=run.$sigma.$tag.${lay//:/x}.$rep
        timeout -s TERM -k 30 300 srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 \
            -N $N -n $n -c $((pe / n)) $C/models/phold/simple/phold +pe $pe \
            gauss_$sigma $C/tests/test_configs/$cfg "$@" > $f 2>&1
        ok=FAIL; grep -q Successfully $f && ok=ok
        printf "%d sigma=%-5s %-12s %-8s %8s s  committed %10s  rolled_back %10s  gvts %6s  %s\n" $rep $sigma $tag $lay \
            "$(awk '/Execution Time/ {print $NF; exit}' $f)" \
            "$(awk '/Events Committed/ {print $NF; exit}' $f)" \
            "$(awk '/Events Rolled Back/ {print $NF; exit}' $f)" \
            "$(awk '/Total GVT/ {print $NF; exit}' $f)" $ok
      done
    done
  done
done
