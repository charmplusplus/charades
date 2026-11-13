#!/bin/bash
# Charades over LCI's native ibv backend (no libfabric RxM).
# Usage: ibv_try.sh <tree> <N> <procs> <pes> <end> [extra]
W=/work2/09863/rrao/stampede3
cd $W/charades-qd && source scripts/stampede3/env.sh >/dev/null 2>&1
unset FI_PROVIDER FI_PROVIDER_PATH LCI_ATTR_OFI_PROVIDER_NAME
export LCI_ATTR_BACKEND=ibv LCI_ATTR_MAX_INJECT_SIZE=0 LCI_ATTR_IBV_TD_STRATEGY=none ${IBV_EXTRA:-}
tree=$1 N=$2 n=$3 pe=$4 end=$5; shift 5
timeout -s TERM ${CAP:-120} srun --mpi=pmi2 --kill-on-bad-exit=1 -N $N -n $n -c $((48 * N / n)) $W/$tree/models/phold/simple/phold +pe $pe \
  $W/charades-runs/tune1/base/ctl_sweep/gauss_100_1000_2000_23552_15_512000 $W/charades-qd/tests/test_configs/bucket \
  --end-time=$end --optimism-window=250 --aggregation=1 --agg-mode=2 --agg-buffer=512 --agg-policy=1 --agg-horizon-margin=8 "$@" 2>&1 \
  | sed "s/hooks\./hooks.\n/g" | grep -vE "reg_cache|^\s*$" | grep -iE "Assert|error|Event Rate|Events Committed|Successfully|Execution Time|abort" | sort | uniq -c | head -10
echo "rc=${PIPESTATUS[0]}"
