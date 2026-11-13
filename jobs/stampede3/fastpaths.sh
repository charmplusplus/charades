#!/bin/bash
# The per-event fast paths (charades 4bb324b, htram 50acab7) one at a time and
# together, on the production build with the best launch settings.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/fastpaths; mkdir -p $OUT
cd $W/charades-qd && source scripts/stampede3/env.sh
(cd $W/charades-prod && make -s -C src && make -s -C models/phold/simple) > $OUT/build.log 2>&1 || { tail -20 $OUT/build.log; exit 1; }
echo "built $(git -C $W/charades-prod log --oneline -1 | cut -c1-50)"
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-prod MARGINS=8 AGG=pp:64 LPS_PER_PE=128 LPC=16
FULL="PPN=2 PEPP=23 CPT=24"; PF="+lci_ndevices 4 +pemap 2-46:2,3-47:2"
L64="PPN=2 PEPP=8 CPT=24";   P64="+lci_ndevices 4 +pemap 2-16:2,3-17:2"
ALL="--agg-inbox=1 --event-index=1 --msg-pool=1"
run() {  # name layout pin flags workload end arms
  local name=$1 lay=$2 pin=$3 flags=$4 wl=$5 end=$6 arms=$7
  ( export $lay END=$end WORKLOADS="$wl" ARMS="$arms" "EXTRA_ARGS=$pin $flags"
    RUNS=$OUT/$name $S 1 $OUT/${name}_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$name /" )
}
HI="gauss:100:1000:2000"; LO="gauss:10:200:2000"
for rep in 1 2 3; do
  echo "=== rep $rep"
  run full_base  "$FULL" "$PF" ""                  $HI 512000 w:250
  run full_hash  "$FULL" "$PF" "--event-index=1"   $HI 512000 w:250
  run full_pool  "$FULL" "$PF" "--msg-pool=1"      $HI 512000 w:250
  run full_inbox "$FULL" "$PF" "--agg-inbox=1"     $HI 512000 w:250
  run full_all   "$FULL" "$PF" "$ALL"              $HI 512000 w:250
  run 64hi_base  "$L64" "$P64" ""     $HI 512000 w:250
  run 64hi_all   "$L64" "$P64" "$ALL" $HI 512000 w:250
  run 64lo_base  "$L64" "$P64" ""     $LO 128000 w:50
  run 64lo_all   "$L64" "$P64" "$ALL" $LO 128000 w:50
done
for rep in 1 2; do
  echo "=== W and the controller with all three, rep $rep"
  run full_all_arms "$FULL" "$PF" "$ALL" $HI 512000 "w:175 w:250 w:350 q:0.003 q:0.001"
done
echo FASTPATHS DONE
