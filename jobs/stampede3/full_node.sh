#!/bin/bash
# Charades on full nodes (2 processes x 24 PEs per node), the same 8,448 LPs
# as ROSS at 192 ranks: htram PP 64 + deadline margin 8, and direct sends
cd $WORK/charades-qd && source scripts/stampede3/env.sh
C=$WORK/charades-qd; d=$WORK/charades-runs/fullnode; mkdir -p $d; cd $d
run() {  # label la mean args
  local l=$1 la=$2 mean=$3; shift 3
  t0=$(date +%s.%N)
  timeout -s TERM 240 srun --mpi=pmi2 --kill-on-bad-exit=1 -N 4 -n 8 -c 24 $C/models/phold/simple/phold +pe 192 \
    $C/tests/test_configs/bucket --num-lps=8448 --lps-per-chare=4 --end-time=64000 --start-events=15 \
    --lookahead=$la --mean=$mean --sigma=2000 "$@" +lci_ndevices 8 > $l.out 2>&1
  echo "$l rc=$? committed, M ev/s, eff %: $(awk '/Events Committed/{print $NF; exit}' $l.out) $(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' $l.out) $(awk '/Efficiency/{print $NF; exit}' $l.out) wall $(echo "$(date +%s.%N) - $t0" | bc | cut -c1-5)"
}
AGG="--aggregation=1 --agg-mode=2 --agg-buffer=64 --agg-policy=1 --agg-horizon-margin=8"
for rep in 1 2; do
run hi_htram_w250_$rep 100 1000 $AGG --optimism-window=250
run hi_htram_q_$rep 100 1000 $AGG --ctl=1 --ctl-epsilon=0.003
run hi_direct_w250_$rep 100 1000 --optimism-window=250
run lo_htram_w50_$rep 10 200 $AGG --optimism-window=50
run lo_htram_q_$rep 10 200 $AGG --ctl=1 --ctl-epsilon=0.003
done
