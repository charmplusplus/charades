#!/bin/bash
# Full-node Charades (Gaussian sigma 2000, high slack, end 512000, W 250, PP 512)
# over a chosen LCI transport. Usage: xport_try.sh <rxm|ibv> <tree> <ppn> <pemap> [extra]
W=/work2/09863/rrao/stampede3
cd $W/charades-qd && source scripts/stampede3/env.sh >/dev/null 2>&1
xp=$1 tree=$2 ppn=$3 pemap=$4; shift 4
if [ $xp = ibv ]; then
  unset FI_PROVIDER FI_PROVIDER_PATH LCI_ATTR_OFI_PROVIDER_NAME
  export LCI_ATTR_BACKEND=ibv LCI_ATTR_MAX_INJECT_SIZE=0 LCI_ATTR_IBV_TD_STRATEGY=none
fi
n=$((4 * ppn)); pe=184
out=$(timeout -s TERM 150 srun --mpi=pmi2 --kill-on-bad-exit=1 -N 4 -n $n -c $((48 / ppn)) $W/$tree/models/phold/simple/phold +pe $pe \
  $W/charades-runs/tune1/base/ctl_sweep/gauss_100_1000_2000_23552_15_512000 $W/charades-qd/tests/test_configs/bucket \
  --optimism-window=250 --aggregation=1 --agg-mode=2 --agg-buffer=512 --agg-policy=1 --agg-horizon-margin=8 \
  +lci_ndevices 4 +pemap $pemap "$@" 2>&1 | sed "s/hooks\./hooks.\n/g" | grep -vE "reg_cache")
rc=$?
rate=$(echo "$out" | awk '/Event Rate/ {print $NF; exit}')
comm=$(echo "$out" | awk '/Events Committed/ {print $NF; exit}')
printf "%-4s %-14s %dx%-3d rate %s M/s committed %s %s\n" $xp $tree $ppn $((pe / ppn)) \
  "$(echo "$rate" | awk '{printf "%.2f", $1/1e6}')" "$comm" "$(echo "$out" | grep -qi 'Successfully' && echo ok || echo FAIL)"
