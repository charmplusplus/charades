#!/bin/bash
# Step 1 of runtime tuning: re-sweep existing knobs on the new code (fast
# paths on by default, charades 0a4c53a), one factor at a time from the base:
# full nodes, 2 x 23 PEs pinned, +lci_ndevices 4, htram PP 64, W 250.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/tune1; mkdir -p $OUT
cd $W/charades-qd && source scripts/stampede3/env.sh
(cd $W/charades-prod && make -s -C src && make -s -C models/phold/simple) > $OUT/build.log 2>&1 || { tail -20 $OUT/build.log; exit 1; }
echo "built $(git -C $W/charades-prod log --oneline -1 | cut -c1-50)"
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-prod MARGINS=8 LPS_PER_PE=128 LPC=16 PPN=2 PEPP=23 CPT=24 \
  END=512000 WORKLOADS="gauss:100:1000:2000" ARMS="w:250"
PIN="+pemap 2-46:2,3-47:2"
run() {  # name agg ndev extra [VAR=value ...]
  local name=$1 agg=$2 nd=$3 extra=$4; shift 4
  ( export AGG=$agg "EXTRA_ARGS=+lci_ndevices $nd $PIN $extra" "$@"
    RUNS=$OUT/$name $S 1 $OUT/${name}_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$name /" )
}
for rep in 1 2 3; do
  echo "=== rep $rep"
  run base        pp:64  4 ""
  run pp128       pp:128 4 ""
  run pp256       pp:256 4 ""
  run wps64       wps:64 4 ""
  run wps256      wps:256 4 ""
  run ww64        ww:64  4 ""
  run ndev2       pp:64  2 ""
  run ndev8       pp:64  8 ""
  run pkt16k      pp:64  4 "" LCI_ATTR_PACKET_SIZE=16384
  run pollf16     pp:64  4 "+backend_poll_freq 16"
  run pollf256    pp:64  4 "+backend_poll_freq 256"
  run batch8      pp:64  4 "--batch=8"
  run batch32     pp:64  4 "--batch=32"
  run batch64     pp:64  4 "--batch=64"
  run waves64     pp:64  4 "--gvt-wave-events=64"
  run waves256    pp:64  4 "--gvt-wave-events=256"
done
echo TUNE1 DONE
