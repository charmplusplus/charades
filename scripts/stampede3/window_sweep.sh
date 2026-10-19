#!/bin/bash
# Optimism-window sweep on Gaussian PHOLD: blocking GVT vs. bucketed GVT
# without a window vs. bucketed GVT with windows, over sigma and node count.
# Run on the idev master node of an allocation with at least max(NODES) nodes.
#
# Usage: window_sweep.sh <reps> [out.csv]
# Knobs (environment): NODES="2 4", SIGMAS="100 500 2000 8000",
#   WINDOWS="250 500 1000 2000 4000 8000", PPN=2 (processes per node),
#   PEPP=8 (PEs per process), LPS_PER_PE=128, END=32000, CAP=120 (s),
#   TREE=charades-qd.
# One CSV row per run; a run that hits CAP is cancelled with scancel (never
# SIGKILL srun, which orphans the step) and recorded as status=stall.
reps=${1:-3}
source "$(dirname "$0")/env.sh"
NODES=${NODES:-"2 4"}
SIGMAS=${SIGMAS:-"100 500 2000 8000"}
WINDOWS=${WINDOWS:-"250 500 1000 2000 4000 8000"}
PPN=${PPN:-2} PEPP=${PEPP:-8} LPS_PER_PE=${LPS_PER_PE:-128}
END=${END:-32000} CAP=${CAP:-120} TREE=${TREE:-charades-qd}
C=$WORK/$TREE
out=${RUNS:-$WORK/charades-runs}/window_sweep; mkdir -p $out/logs; cd $out
csv=${2:-$out/sweep_$(date +%Y%m%d_%H%M%S).csv}
echo "rep,nodes,procs,pes,lps,sigma,gvt,window,status,wall_s,exec_s,committed,rolled_back,efficiency,event_rate,gvts,remote_sends,anti_sends" > $csv
echo "writing $csv (tree $TREE, $(git -C $C log --oneline -1 | cut -c1-40))"

stat() { awk -v k="$1" 'index($0, k) {print $NF; exit}' "$2"; }

run_one() {  # nodes procs pes cfg gvt window label
  local N=$1 n=$2 pe=$3 cfg=$4 gvt=$5 w=$6 label=$7
  local f=logs/$label.out
  local extra=(); [ "$w" != 0 ] && extra=(--optimism-window=$w)
  srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -N $N -n $n -c $((pe / n)) -J ws_$label \
      $C/models/phold/simple/phold +pe $pe $cfg $C/tests/test_configs/$gvt "${extra[@]}" \
      > $f 2>&1 &
  local sp=$! t0=$(date +%s.%N) status=ok
  while kill -0 $sp 2>/dev/null; do
    sleep 0.1
    if (( $(echo "$(date +%s.%N) - $t0 > $CAP" | bc) )); then
      status=stall
      local st=$(squeue -h -s -j $SLURM_JOB_ID -o "%i %j" | awk -v j=ws_$label '$2==j {print $1}')
      [ -n "$st" ] && scancel $st
      break
    fi
  done
  wait $sp 2>/dev/null; local rc=$?
  local wall=$(echo "$(date +%s.%N) - $t0" | bc)
  if [ $status = ok ] && { [ $rc -ne 0 ] || ! grep -q "Simulation Executed Successfully" $f; }; then
    status=fail
  fi
  echo "$rep,$N,$n,$pe,$lps,$sigma,$gvt,$w,$status,$(printf %.2f $wall),$(stat 'Execution Time' $f),$(stat 'Events Committed' $f),$(stat 'Events Rolled Back' $f),$(stat 'Efficiency' $f),$(stat 'Event Rate' $f),$(stat 'Total GVT Computations' $f),$(stat 'Remote Sends' $f),$(stat 'Anti Event Sends' $f)" >> $csv
  printf "%-44s %-5s %7.2fs\n" $label $status $wall
}

for rep in $(seq $reps); do
  for N in $NODES; do
    n=$((N * PPN)); pe=$((n * PEPP)); lps=$((pe * LPS_PER_PE))
    for sigma in $SIGMAS; do
      cfg=$out/gauss_${lps}_$sigma
      printf '%s\n' "num-lps=$lps" "lps-per-chare=16" "end-time=$END" "lookahead=100" \
          "start-events=15" "sigma=$sigma" > $cfg
      run_one $N $n $pe $cfg blocking 0 r${rep}_n${N}_s${sigma}_blocking
      run_one $N $n $pe $cfg bucket 0 r${rep}_n${N}_s${sigma}_bucket
      for w in $WINDOWS; do
        run_one $N $n $pe $cfg bucket $w r${rep}_n${N}_s${sigma}_bucket_w$w
      done
    done
  done
done
echo "done: $csv"
