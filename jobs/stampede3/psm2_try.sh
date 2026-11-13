#!/bin/bash
# Charades over LCI's OFI backend on native psm2 (charm-pads-exp's patched LCI,
# LCI_OFI_PROGRESS_UNSPEC=1). Usage: psm2_try.sh <N> <procs> <pes> <end> [extra]
W=/work2/09863/rrao/stampede3
cd $W/charades-qd && source scripts/stampede3/env.sh >/dev/null 2>&1
unset FI_PROVIDER_PATH
export LCI_ATTR_BACKEND=ofi LCI_ATTR_OFI_PROVIDER_NAME=psm2 FI_PROVIDER=psm2 PSM2_MULTI_EP=1 LCI_OFI_PROGRESS_UNSPEC=1 ${PSM2_EXTRA:-}
export LD_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | tr : '\n' | grep -v libfabric_ | paste -sd:)
N=$1 n=$2 pe=$3 end=$4; shift 4
timeout -s TERM 120 srun --mpi=pmi2 --kill-on-bad-exit=1 -N $N -n $n -c $((48 * N / n)) $W/charades-exp/models/phold/simple/phold +pe $pe \
  $W/charades-runs/tune1/base/ctl_sweep/gauss_100_1000_2000_23552_15_512000 $W/charades-qd/tests/test_configs/bucket \
  --end-time=$end --optimism-window=250 --aggregation=1 --agg-mode=2 --agg-buffer=512 --agg-policy=1 --agg-horizon-margin=8 "$@" 2>&1 \
  | sed "s/hooks\./hooks.\n/g" | grep -vE "reg_cache|^\s*$" | grep -iE "Protocol|Provider name|Assert|error|Event Rate|Events Committed|Successfully|Execution Time" | sort | uniq -c | head -12
echo "rc=${PIPESTATUS[0]}"
