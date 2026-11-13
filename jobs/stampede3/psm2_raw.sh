#!/bin/bash
# psm2_native.sh without the output filter: <N> <procs> <pes> <end> [extra]
W=/work2/09863/rrao/stampede3
cd $W/charades-qd && source scripts/stampede3/env.sh >/dev/null 2>&1
unset FI_PROVIDER_PATH
export LCI_LOG_LEVEL=${LCI_LOG_LEVEL:-warn} LCI_ATTR_BACKEND=ofi LCI_ATTR_OFI_PROVIDER_NAME=psm2 FI_PROVIDER=psm2 PSM2_MULTI_EP=1 ${PSM2_EXTRA:-}
export LD_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | tr : "\n" | grep -v libfabric_ | paste -sd:)
N=$1 n=$2 pe=$3 end=$4; shift 4
timeout -s TERM ${TMO:-120} srun --mpi=pmi2 --kill-on-bad-exit=1 -N $N -n $n -c $((48 * N / n)) ${SRUN_ARGS:-} $W/charades-exp/models/phold/simple/phold +pe $pe ${EXTRA_ARGS:-} \
  $W/charades-runs/tune1/base/ctl_sweep/gauss_100_1000_2000_23552_15_512000 $W/charades-qd/tests/test_configs/bucket \
  --end-time=$end --optimism-window=250 --aggregation=1 --agg-mode=2 --agg-buffer=512 --agg-policy=1 --agg-horizon-margin=8 "$@" 2>&1
echo "rc=$?"
