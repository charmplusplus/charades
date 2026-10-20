#!/bin/bash
# Optimism-window sweep on Gaussian PHOLD: blocking GVT vs. bucketed GVT
# without a window vs. bucketed GVT with windows, over sigma and node count.
# Run on the idev master node of an allocation with at least max(NODES) nodes.
#
# Usage: window_sweep.sh <reps> [out.csv]
# Knobs (environment): NODES="2 4", SIGMAS="100 500 2000 8000",
#   WINDOWS="250 500 1000 2000 4000 8000", PPN=2 (processes per node),
#   PEPP=8 (PEs per process), LPS_PER_PE=128, START=15 (start events per LP),
#   END=32000, CAP=120 (s), TREE=charades-qd, NOWINDOW=1 (also run bucketed
#   without a window), COMM_STATS=0 (1: --comm-stats and its columns),
#   EXTRA_ARGS (appended to every run, e.g. "+lci_ndevices 8").
#   WORKLOAD=gauss (Gaussian destinations, swept over SIGMAS) or uniform
#   (uniform destinations with probability remote, swept over REMOTES,
#   e.g. REMOTES="0 0.1 0.5 1"; the CSV's sigma column then holds remote).
# One CSV row per run; a run that hits CAP is cancelled with scancel (never
# SIGKILL srun, which orphans the step) and recorded as status=stall.
reps=${1:-3}
source "$(dirname "$0")/env.sh"
NODES=${NODES:-"2 4"}
SIGMAS=${SIGMAS:-"100 500 2000 8000"}
WINDOWS=${WINDOWS:-"250 500 1000 2000 4000 8000"}
PPN=${PPN:-2} PEPP=${PEPP:-8} LPS_PER_PE=${LPS_PER_PE:-128} START=${START:-15}
WORKLOAD=${WORKLOAD:-gauss} NOWINDOW=${NOWINDOW:-1} COMM_STATS=${COMM_STATS:-0}
[ $WORKLOAD = uniform ] && SIGMAS=${REMOTES:-"0 0.1 0.5 1"}
END=${END:-32000} CAP=${CAP:-120} TREE=${TREE:-charades-qd}
C=$WORK/$TREE
out=${RUNS:-$WORK/charades-runs}/window_sweep; mkdir -p $out/logs; cd $out
csv=${2:-$out/sweep_$(date +%Y%m%d_%H%M%S).csv}
echo "rep,nodes,procs,pes,lps,sigma,gvt,window,status,wall_s,exec_s,committed,rolled_back,efficiency,event_rate,gvts,remote_sends,anti_sends,workload,send_call_us,send_pct,lat_proc_mean_us,lat_proc_p50_us,lat_node_mean_us,lat_node_p50_us,lat_other_mean_us,lat_other_p50_us" > $csv
echo "writing $csv (tree $TREE, $(git -C $C log --oneline -1 | cut -c1-40))"

stat() { awk -v k="$1" 'index($0, k) {print $NF; exit}' "$2"; }

run_one() {  # nodes procs pes cfg gvt window label
  local N=$1 n=$2 pe=$3 cfg=$4 gvt=$5 w=$6 label=$7
  local f=logs/$label.out
  local extra=(); [ "$w" != 0 ] && extra=(--optimism-window=$w)
  [ "$COMM_STATS" = 1 ] && extra+=(--comm-stats=1)
  extra+=(${EXTRA_ARGS:-})
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
  echo "$rep,$N,$n,$pe,$lps,$sigma,$gvt,$w,$status,$(printf %.2f $wall),$(stat 'Execution Time' $f),$(stat 'Events Committed' $f),$(stat 'Events Rolled Back' $f),$(stat 'Efficiency' $f),$(stat 'Event Rate' $f),$(stat 'Total GVT Computations' $f),$(stat 'Remote Sends' $f),$(stat 'Anti Event Sends' $f),$WORKLOAD,$(stat 'Mean Send Call' $f),$(stat 'Send Calls %' $f),$(stat 'Same Process: Mean' $f),$(stat 'Same Process: p50' $f),$(stat 'Same Node: Mean' $f),$(stat 'Same Node: p50' $f),$(stat 'Other Node: Mean' $f),$(stat 'Other Node: p50' $f)" >> $csv
  printf "%-44s %-5s %7.2fs\n" $label $status $wall
}

for rep in $(seq $reps); do
  for N in $NODES; do
    n=$((N * PPN)); pe=$((n * PEPP)); lps=$((pe * LPS_PER_PE))
    for sigma in $SIGMAS; do
      cfg=$out/${WORKLOAD}_${lps}_${START}_${END}_$sigma
      if [ $WORKLOAD = uniform ]; then dist="remote=$sigma"; else dist="sigma=$sigma"; fi
      printf '%s\n' "num-lps=$lps" "lps-per-chare=16" "end-time=$END" "lookahead=100" \
          "start-events=$START" "$dist" > $cfg
      tag=${WORKLOAD:0:1}${sigma}
      run_one $N $n $pe $cfg blocking 0 r${rep}_n${N}_${tag}_blocking
      [ "$NOWINDOW" = 1 ] && run_one $N $n $pe $cfg bucket 0 r${rep}_n${N}_${tag}_bucket
      for w in $WINDOWS; do
        run_one $N $n $pe $cfg bucket $w r${rep}_n${N}_${tag}_bucket_w$w
      done
    done
  done
done
echo "done: $csv"
