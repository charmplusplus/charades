#!/bin/bash
# Window controller sweep on PHOLD: fixed optimism windows against the
# delay-quantile rule (--ctl=1) and Devastator's hill climb (--ctl=2), on
# steady and phase-changing workloads, under the bucketed GVT. Run on the
# idev master node of an allocation with at least max(NODES) nodes.
#
# Usage: ctl_sweep.sh <reps> [out.csv]
# Knobs (environment):
#   NODES="4", PPN=2 (processes per node), PEPP=8 (PEs per process),
#   LPS_PER_PE=128, START=15 (start events per LP), END=64000, CAP=180 (s),
#   WORKLOADS="steady:10:200:0.5 steady:100:1000:0.5
#              phases:10:200:100:1000:0.5:8000"
#     steady:<lookahead>:<mean>:<remote>
#     phases:<lookahead>:<mean>:<alt lookahead>:<alt mean>:<remote>:<length>
#     gauss:<lookahead>:<mean>:<sigma> (Gaussian destinations, sigma in LP ids)
#   ARMS="w:25 w:50 w:100 w:250 w:500 q:0.02 q:0.05 q:0.1 hill:250"
#     w:<W> a fixed window; q:<epsilon> the quantile rule (calibrated: the
#     share of events rolled back; from the smallest window); qb:<epsilon>
#     the bare bound (primary stragglers per event); hill:<W0> the hill
#     climb from W0, deciding every 8 GVT updates like the quantile rule;
#     hill1:<W0> the same deciding after every GVT update (Devastator's
#     design, where the counts ride on the GVT reduction); dry:<W> fixed W
#     with the quantile rule running but not applied (--ctl-dry, its cost);
#     blk: blocking GVT, no window (the value is ignored)
#   BUCKETS="8" (bucketed GVT bucket sizes), MARGINS="0" (deadline policy:
#     --agg-horizon-margin values, the horizon being W + margin),
#   AGG="pp:64" (htram mode:buffer with the deadline policy, so the horizon
#     follows the window; "off" sends directly), TREE=charades-qd,
#   EXTRA_ARGS="+lci_ndevices 8" (appended to every run).
# One CSV row per run; a run that hits CAP is cancelled with scancel (never
# SIGKILL srun, which orphans the step) and recorded as status=stall.
reps=${1:-2}
source "$(dirname "$0")/env.sh"
NODES=${NODES:-4} PPN=${PPN:-2} PEPP=${PEPP:-8} LPS_PER_PE=${LPS_PER_PE:-128}
START=${START:-15} END=${END:-64000} CAP=${CAP:-180} TREE=${TREE:-charades-qd}
WORKLOADS=${WORKLOADS:-"steady:10:200:0.5 steady:100:1000:0.5 phases:10:200:100:1000:0.5:8000"}
ARMS=${ARMS:-"w:25 w:50 w:100 w:250 w:500 q:0.02 q:0.05 q:0.1 hill:250"}
AGG=${AGG:-pp:64} BUCKETS=${BUCKETS:-8} MARGINS=${MARGINS:-0}
EXTRA_ARGS=${EXTRA_ARGS-"+lci_ndevices 8"}
C=$WORK/$TREE
out=${RUNS:-$WORK/charades-runs}/ctl_sweep; mkdir -p $out/logs; cd $out
csv=${2:-$out/sweep_$(date +%Y%m%d_%H%M%S).csv}
echo "rep,nodes,procs,pes,lps,workload,agg,bucket,margin,arm,status,wall_s,exec_s,committed,rolled_back,efficiency,event_rate,gvts,remote_sends,agg_events_per_msg,ctl_rounds,final_window,mean_window,stragglers_per_event,alpha" > $csv
echo "writing $csv (tree $TREE, $(git -C $C log --oneline -1 | cut -c1-40))"

stat() { awk -v k="$1" 'index($0, k) {print $NF; exit}' "$2"; }
mode_num() { case $1 in wps) echo 0;; wsp) echo 1;; pp) echo 2;; ww) echo 3;; esac; }

run_one() {  # nodes procs pes cfg arm label
  local N=$1 n=$2 pe=$3 cfg=$4 arm=$5 label=$6
  local f=logs/$label.out kind=${arm%%:*} val=${arm##*:}
  local extra=() gvtcfg=bucket
  case $kind in
    blk)  gvtcfg=blocking ;;
    w)    extra+=(--optimism-window=$val) ;;
    q)    extra+=(--ctl=1 --ctl-epsilon=$val) ;;
    qb)   extra+=(--ctl=1 --ctl-epsilon=$val --ctl-calibrate=0) ;;
    hill) extra+=(--optimism-window=$val --ctl=2) ;;
    hill1) extra+=(--optimism-window=$val --ctl=2 --ctl-interval=1) ;;
    dry)  extra+=(--optimism-window=$val --ctl=1 --ctl-dry=1) ;;
  esac
  extra+=(--gvt-bucket-size=$bucket)
  if [ "$AGG" != off ]; then
    extra+=(--aggregation=1 --agg-mode=$(mode_num ${AGG%%:*}) --agg-buffer=${AGG##*:}
            --agg-policy=1 --agg-horizon-margin=$margin)
  fi
  extra+=(${EXTRA_ARGS:-})
  srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -N $N -n $n -c $((pe / n)) -J cs_$label \
      $C/models/phold/simple/phold +pe $pe $cfg $C/tests/test_configs/$gvtcfg "${extra[@]}" \
      > $f 2>&1 &
  local sp=$! t0=$(date +%s.%N) status=ok
  while kill -0 $sp 2>/dev/null; do
    sleep 0.1
    if (( $(echo "$(date +%s.%N) - $t0 > $CAP" | bc) )); then
      status=stall
      local st=$(squeue -h -s -j $SLURM_JOB_ID -o "%i %j" | awk -v j=cs_$label '$2==j {print $1}')
      [ -n "$st" ] && scancel $st
      break
    fi
  done
  wait $sp 2>/dev/null; local rc=$?
  local wall=$(echo "$(date +%s.%N) - $t0" | bc)
  if [ $status = ok ] && { [ $rc -ne 0 ] || ! grep -q "Simulation Executed Successfully" $f; }; then
    status=fail
  fi
  local fw=$(stat 'Final window' $f) mw=$(stat 'Time-weighted mean window' $f)
  [ $kind = w ] && fw=$val mw=$val
  [ $kind = blk ] && fw=none mw=none
  echo "$rep,$N,$n,$pe,$lps,$wl,$AGG,$bucket,$margin,$arm,$status,$(printf %.2f $wall),$(stat 'Execution Time' $f),$(stat 'Events Committed' $f),$(stat 'Events Rolled Back' $f),$(stat 'Efficiency' $f),$(stat 'Event Rate' $f),$(stat 'Total GVT Computations' $f),$(stat 'Remote Sends' $f),$(stat 'Events per htram Message' $f),$(stat 'Rounds' $f),$fw,$mw,$(stat 'Stragglers per executed event' $f),$(stat 'Final alpha' $f)" >> $csv
  printf "%-60s %-5s %7.2fs\n" $label $status $wall
}

for rep in $(seq $reps); do
  for N in $NODES; do
    n=$((N * PPN)); pe=$((n * PEPP)); lps=$((pe * LPS_PER_PE))
    for wl in $WORKLOADS; do
      IFS=: read -r kind a b c d e f <<< "$wl"
      cfg=$out/${wl//:/_}_${lps}_${START}_${END}
      printf '%s\n' "num-lps=$lps" "lps-per-chare=16" "end-time=$END" \
          "start-events=$START" > $cfg
      if [ $kind = steady ]; then
        printf '%s\n' "lookahead=$a" "mean=$b" "remote=$c" >> $cfg
      elif [ $kind = gauss ]; then
        printf '%s\n' "lookahead=$a" "mean=$b" "sigma=$c" >> $cfg
      else
        printf '%s\n' "lookahead=$a" "mean=$b" "alt-lookahead=$c" "alt-mean=$d" \
            "remote=$e" "phase-length=$f" >> $cfg
      fi
      for bucket in $BUCKETS; do
       for margin in $MARGINS; do
        for arm in $ARMS; do
          run_one $N $n $pe $cfg $arm r${rep}_n${N}_${wl//:/_}_${AGG//:/}_b${bucket}_m${margin}_${arm//:/}
        done
       done
      done
    done
  done
done
echo "done: $csv"
