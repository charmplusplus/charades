#!/bin/bash
# rnr.sh <label> <cap> [env assignments...]: run the sigma=2000 2x8 bucketed
# case and report hfi1 RnrNak/RcResend/RcTimeOut deltas on every node.
label=$1 cap=$2; shift 2
S=$WORK/charades/scripts/stampede3
G=$WORK/charades-runs/gvt_cost/gauss_2000; T=$WORK/charades/tests/test_configs/bucket
nodes=$(scontrol show hostnames $(squeue -h -u $USER -t R -o "%j %N" | awk '$1 ~ /^idv/ {print $2; exit}'))
snap() { for n in $nodes; do ssh -o "StrictHostKeyChecking no" -o LogLevel=ERROR $n \
    'c=/sys/class/infiniband/hfi1_0/ports/1/hw_counters; echo $(hostname -s) $(cat $c/RnrNak) $(cat $c/RcResend) $(cat $c/RcTimeOut) $(cat $c/RxPkt) $(cat $c/RcSeqNak) $(cat $c/OtherNak)'; done; }
before=$(snap)
env "$@" $S/try.sh $cap 2 2 16 $label -- $G $T
after=$(snap)
paste <(echo "$before") <(echo "$after") | awk '{printf "  %s RnrNak +%d RcResend +%d RcTimeOut +%d RxPkt +%d RcSeqNak +%d OtherNak +%d\n", $1, $9-$2, $10-$3, $11-$4, $12-$5, $13-$6, $14-$7}'
