#!/bin/bash
# SUPERSEDED (2026-10-22): use ctl_sweep.sh, whose defaults are full nodes
# (2 x 23 PEs, psm2, charades-exp). This script keeps the old 2 x 8 PE
# layout on the Debug-runtime tree and is kept only to reproduce old runs.
# Aggregation sweep on uniform PHOLD: remote events sent directly vs. through
# htram, over htram's aggregation modes, buffer sizes and urgency, for each
# GVT setup, remote fraction and node count. Needs a tree built with
# HTRAM_DIR set (src/htram.mk). Run on the idev master node of an allocation
# with at least max(NODES) nodes.
#
# Usage: agg_sweep.sh <reps> [out.csv]
# Knobs (environment): NODES="4", REMOTES="0.5", GVTS="bucket:250"
#   (gvt config:optimism window, e.g. "blocking:0 bucket:250"),
#   MODES="wps wsp pp ww", BUFFERS="16 64 256 1024", URGENTS="0",
#   POLICIES="eager" (eager and/or deadline), HORIZONS="0" (deadline policy:
#   --agg-horizon values; 0 = twice the window), SLACKS="100:1000" (PHOLD
#   lookahead:mean pairs; e.g. "10:200" leaves events little timestamp slack),
#   DIRECT=1 (also run without aggregation), GVT_FLUSH=2, SCOPE=0,
#   PPN=2 (processes per node), PEPP=8 (PEs per process), LPS_PER_PE=128,
#   START=15 (start events per LP), END=32000, CAP=120 (s), TREE=charades-qd,
#   EXTRA_ARGS="+lci_ndevices 8" (appended to every run).
# One CSV row per run, with --comm-stats on; a run that hits CAP is cancelled
# with scancel (never SIGKILL srun, which orphans the step) and recorded as
# status=stall.
reps=${1:-2}
source "$(dirname "$0")/env.sh"
NODES=${NODES:-4} REMOTES=${REMOTES:-0.5} GVTS=${GVTS:-bucket:250}
MODES=${MODES:-"wps wsp pp ww"} BUFFERS=${BUFFERS:-"16 64 256 1024"}
URGENTS=${URGENTS:-0} DIRECT=${DIRECT:-1} POLICIES=${POLICIES:-eager} HORIZONS=${HORIZONS:-0}
SLACKS=${SLACKS:-100:1000} GVT_FLUSH=${GVT_FLUSH:-2} SCOPE=${SCOPE:-0}
PPN=${PPN:-2} PEPP=${PEPP:-8} LPS_PER_PE=${LPS_PER_PE:-128} START=${START:-15}
END=${END:-32000} CAP=${CAP:-120} TREE=${TREE:-charades-qd}
EXTRA_ARGS=${EXTRA_ARGS-"+lci_ndevices 8"}
C=$WORK/$TREE
out=${RUNS:-$WORK/charades-runs}/agg_sweep; mkdir -p $out/logs; cd $out
csv=${2:-$out/sweep_$(date +%Y%m%d_%H%M%S).csv}
echo "rep,nodes,procs,pes,lps,remote,lookahead,mean,gvt,window,agg_mode,agg_buffer,agg_policy,agg_horizon,agg_urgent,status,wall_s,exec_s,committed,rolled_back,efficiency,event_rate,gvts,remote_sends,anti_sends,send_call_us,send_pct,lat_proc_mean_us,lat_proc_p50_us,lat_node_mean_us,lat_node_p50_us,lat_other_mean_us,lat_other_p50_us,agg_items,agg_urgent_sent,agg_direct,agg_msgs,agg_events_per_msg,agg_bytes_per_msg,msgs_full,msgs_urgent,msgs_idle,msgs_gvt,msgs_round,stragglers_pct,slack_p10,slack_p50" > $csv
echo "writing $csv (tree $TREE, $(git -C $C log --oneline -1 | cut -c1-40))"

stat() { awk -v k="$1" 'index($0, k) {print $NF; exit}' "$2"; }
mode_num() { case $1 in wps) echo 0;; wsp) echo 1;; pp) echo 2;; ww) echo 3;; esac; }

run_one() {  # nodes procs pes cfg gvt window mode buffer policy horizon urgent label
  local N=$1 n=$2 pe=$3 cfg=$4 gvt=$5 w=$6 mode=$7 buf=$8 pol=$9 hor=${10} urg=${11} label=${12}
  local f=logs/$label.out
  local extra=(--comm-stats=1); [ "$w" != 0 ] && extra+=(--optimism-window=$w)
  if [ $mode != off ]; then
    extra+=(--aggregation=1 --agg-mode=$(mode_num $mode) --agg-buffer=$buf
            --agg-urgent=$urg --agg-gvt-flush=$GVT_FLUSH --agg-scope=$SCOPE
            --agg-policy=$( [ $pol = deadline ] && echo 1 || echo 0) --agg-horizon=$hor)
  fi
  extra+=(${EXTRA_ARGS:-})
  srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -N $N -n $n -c $((pe / n)) -J as_$label \
      $C/models/phold/simple/phold +pe $pe $cfg $C/tests/test_configs/$gvt "${extra[@]}" \
      > $f 2>&1 &
  local sp=$! t0=$(date +%s.%N) status=ok
  while kill -0 $sp 2>/dev/null; do
    sleep 0.1
    if (( $(echo "$(date +%s.%N) - $t0 > $CAP" | bc) )); then
      status=stall
      local st=$(squeue -h -s -j $SLURM_JOB_ID -o "%i %j" | awk -v j=as_$label '$2==j {print $1}')
      [ -n "$st" ] && scancel $st
      break
    fi
  done
  wait $sp 2>/dev/null; local rc=$?
  local wall=$(echo "$(date +%s.%N) - $t0" | bc)
  if [ $status = ok ] && { [ $rc -ne 0 ] || ! grep -q "Simulation Executed Successfully" $f; }; then
    status=fail
  fi
  echo "$rep,$N,$n,$pe,$lps,$remote,$la,$mean,$gvt,$w,$mode,$buf,$pol,$hor,$urg,$status,$(printf %.2f $wall),$(stat 'Execution Time' $f),$(stat 'Events Committed' $f),$(stat 'Events Rolled Back' $f),$(stat 'Efficiency' $f),$(stat 'Event Rate' $f),$(stat 'Total GVT Computations' $f),$(stat 'Remote Sends' $f),$(stat 'Anti Event Sends' $f),$(stat 'Mean Send Call' $f),$(stat 'Send Calls %' $f),$(stat 'Same Process: Mean' $f),$(stat 'Same Process: p50' $f),$(stat 'Same Node: Mean' $f),$(stat 'Same Node: p50' $f),$(stat 'Other Node: Mean' $f),$(stat 'Other Node: p50' $f),$(stat 'Events Through htram' $f),$(stat 'Events Shipped Urgently' $f),$(stat 'Events Sent Directly' $f),$(stat 'htram Messages' $f),$(stat 'Events per htram Message' $f),$(stat 'Bytes per htram Message' $f),$(stat 'Messages: Buffer Full' $f),$(stat 'Messages: Urgent Event' $f),$(stat 'Messages: Idle Flush' $f),$(stat 'Messages: GVT Update' $f),$(stat 'Messages: GVT Round' $f),$(stat 'Remote Stragglers %' $f),$(stat 'Slack p10' $f),$(stat 'Slack p50' $f)" >> $csv
  printf "%-52s %-5s %7.2fs\n" $label $status $wall
}

for rep in $(seq $reps); do
  for N in $NODES; do
    n=$((N * PPN)); pe=$((n * PEPP)); lps=$((pe * LPS_PER_PE))
    for remote in $REMOTES; do
     for sl in $SLACKS; do
      la=${sl%%:*} mean=${sl##*:}
      cfg=$out/uniform_${lps}_${START}_${END}_${remote}_la${la}_m${mean}
      printf '%s\n' "num-lps=$lps" "lps-per-chare=16" "end-time=$END" "lookahead=$la" \
          "mean=$mean" "start-events=$START" "remote=$remote" > $cfg
      for g in $GVTS; do
        gvt=${g%%:*} w=${g##*:}
        tag=r${rep}_n${N}_u${remote}_la${la}m${mean}_${gvt}_w$w
        [ "$DIRECT" = 1 ] && run_one $N $n $pe $cfg $gvt $w off 0 - 0 0 ${tag}_direct
        for mode in $MODES; do
          for buf in $BUFFERS; do
            # PP ships its shared buffer at exactly this many items, copied in 16 at a time
            [ $mode = pp ] && (( buf % 16 )) && continue
            for pol in $POLICIES; do
              if [ $pol = deadline ]; then
                for hor in $HORIZONS; do
                  run_one $N $n $pe $cfg $gvt $w $mode $buf deadline $hor 0 ${tag}_${mode}_b${buf}_dl$hor
                done
              else
                for urg in $URGENTS; do
                  run_one $N $n $pe $cfg $gvt $w $mode $buf eager 0 $urg ${tag}_${mode}_b${buf}_u$urg
                done
              fi
            done
          done
        done
      done
     done
    done
  done
done
echo "done: $csv"
