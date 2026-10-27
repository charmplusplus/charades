#!/bin/bash
# Window controller sweep on PHOLD: fixed optimism windows against the
# delay-quantile rule (--ctl=1) and Devastator's hill climb (--ctl=2), on
# steady and phase-changing workloads, under the bucketed GVT. Run on the
# idev master node of an allocation with at least max(NODES) nodes.
#
# Usage: ctl_sweep.sh <reps> [out.csv]
# Knobs (environment):
#   Defaults are full nodes (since 2026-10-22; runs before used PEPP=8,
#   CPT=8, AGG=pp:64, TREE=charades-qd, verbs and "+lci_ndevices 8"):
#   NODES="4", PPN=2 (processes per node), PEPP=23 (PEs per process; one
#   core per process stays free),
#   LPS_PER_PE=128, LPC=16 (LPs per chare; must divide LPS_PER_PE), START=15 (start events per LP), END=64000, CAP=180 (s),
#   WORKLOADS="steady:10:200:0.5 steady:100:1000:0.5
#              phases:10:200:100:1000:0.5:8000"
#     steady:<lookahead>:<mean>:<remote>
#     phases:<lookahead>:<mean>:<alt lookahead>:<alt mean>:<remote>:<length>
#     gauss:<lookahead>:<mean>:<sigma> (Gaussian destinations, sigma in LP ids)
#     traffic:<lookahead>:<mean>:<num-x>:<cars per intersection>:<share>:<size>
#       the traffic model on a num-x by (LPs / num-x) grid; with share > 0,
#       that share of cars starts in a size x size block at the top-left
#       corner and ends in one at the bottom-right (congestion)
#   ARMS="w:25 w:50 w:100 w:250 w:500 q:0.02 q:0.05 q:0.1 hill:250"
#     w:<W> a fixed window; q:<epsilon> the quantile rule (calibrated: the
#     share of events rolled back; from the smallest window); qb:<epsilon>
#     the bare bound (primary stragglers per event); hill:<W0> the hill
#     climb from W0, deciding every 8 GVT updates like the quantile rule;
#     hill1:<W0> the same deciding after every GVT update (Devastator's
#     design, where the counts ride on the GVT reduction); dry:<W> fixed W
#     with the quantile rule running but not applied (--ctl-dry, its cost).
#     Since 2026-10-22 the q arms calibrate with --ctl-floor=2 (the new
#     default); runs before used 0 (add --ctl-floor=0 to EXTRA_ARGS to match).
#     Since 2026-10-21 q, qb, hill, hill1 and dry use the default data path,
#     the GVT's count waves (histogram every 8th wave; a round is 8
#     waves, or 1 for hill1); qsep:, drysep:, hillsep: the same three on the
#     controller's own reduction (--ctl-reduction=0), as before that date.
#     q's epsilon is a share of events rolled back (the default); qev: the
#     same, explicitly (--ctl-cost=0); qt:<epsilon> a share of PE time lost
#     to rollbacks (--ctl-cost=1, experimental; it failed in step 2);
#     blk: blocking GVT, no window (the value is ignored);
#     qs[c]<N>:<epsilon> the quantile rule on the GVT's count waves
#     (--ctl-reduction=1, deciding every wave), the histogram on every Nth
#     wave, coarse (one bin per power of two) with c; drys[c]<N>:<W> the same
#     with fixed W (--ctl-dry, its cost); hills:<W0> the hill climb on the
#     count waves, deciding every wave (Devastator's design)
#   BUCKETS="8" (bucketed GVT bucket sizes), MARGINS="8" (deadline policy:
#     --agg-horizon-margin values, the horizon being W + margin),
#   AGG="pp:512" (htram mode:buffer with the deadline policy, so the horizon
#     follows the window; "off" sends directly), TREE=charades-exp (production
#     runtime with the psm2 LCI patch),
#   XPORT=psm2 with LCI_ATTR_PACKET_SIZE=65536 (env.sh; XPORT=verbs for the old
#     transport),
#   EXTRA_ARGS="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
#     (the current launch, RESULTS.md sections 95 and 114; appended to every run;
#     the pemap puts each process's PEs on its own socket),
#   BIN_WRAP (a command srun runs the binary through, e.g. a perf wrapper),
#   CPT=24 (cores per task for srun -c), SRUN_ARGS
#     (extra srun options, e.g. --cpu-bind=none with a +pemap in EXTRA_ARGS).
# One CSV row per run; a run that hits CAP is cancelled with scancel (never
# SIGKILL srun, which orphans the step) and recorded as status=stall.
reps=${1:-2}
export XPORT=${XPORT:-psm2}
[ $XPORT = psm2 ] && export LCI_ATTR_PACKET_SIZE=${LCI_ATTR_PACKET_SIZE:-65536}
source "$(dirname "$0")/env.sh"
NODES=${NODES:-4} PPN=${PPN:-2} PEPP=${PEPP:-23} CPT=${CPT:-24} LPS_PER_PE=${LPS_PER_PE:-128} LPC=${LPC:-16}
START=${START:-15} END=${END:-64000} CAP=${CAP:-180} TREE=${TREE:-charades-exp}
WORKLOADS=${WORKLOADS:-"steady:10:200:0.5 steady:100:1000:0.5 phases:10:200:100:1000:0.5:8000"}
ARMS=${ARMS:-"w:25 w:50 w:100 w:250 w:500 q:0.02 q:0.05 q:0.1 hill:250"}
AGG=${AGG:-pp:512} BUCKETS=${BUCKETS:-8} MARGINS=${MARGINS:-8}
EXTRA_ARGS=${EXTRA_ARGS-"+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"}
C=$WORK/$TREE
out=${RUNS:-$WORK/charades-runs}/ctl_sweep; mkdir -p $out/logs; cd $out
csv=${2:-$out/sweep_$(date +%Y%m%d_%H%M%S).csv}
echo "rep,nodes,procs,pes,lps,workload,agg,bucket,margin,arm,status,wall_s,exec_s,committed,rolled_back,efficiency,event_rate,gvts,remote_sends,agg_events_per_msg,ctl_rounds,final_window,mean_window,stragglers_per_event,alpha,count_waves,kappa,ts_rollbacks,late_stragglers" > $csv
echo "writing $csv (tree $TREE, $(git -C $C log --oneline -1 | cut -c1-40))"

stat() { awk -v k="$1" 'index($0, k) {print $NF; exit}' "$2"; }
mode_num() { case $1 in wps) echo 0;; wsp) echo 1;; pp) echo 2;; ww) echo 3;; esac; }

run_one() {  # nodes procs pes cfg arm label
  local N=$1 n=$2 pe=$3 cfg=$4 arm=$5 label=$6
  local f=logs/$label.out kind=${arm%%:*} val=${arm##*:}
  local extra=() gvtcfg=bucket
  case $kind in
    blk)  gvtcfg=blocking; extra+=(--buffer-size=655360) ;;  # the bucket config's pool (since 2026-10-22)
    w)    extra+=(--optimism-window=$val) ;;
    q)    extra+=(--ctl=1 --ctl-epsilon=$val) ;;
    qb)   extra+=(--ctl=1 --ctl-epsilon=$val --ctl-calibrate=0) ;;
    hill) extra+=(--optimism-window=$val --ctl=2) ;;
    hill1) extra+=(--optimism-window=$val --ctl=2 --ctl-interval=1) ;;
    dry)  extra+=(--optimism-window=$val --ctl=1 --ctl-dry=1) ;;
    hills) extra+=(--optimism-window=$val --ctl=2 --ctl-reduction=1 --ctl-interval=1) ;;
    qsep) extra+=(--ctl=1 --ctl-epsilon=$val --ctl-reduction=0) ;;
    qev)  extra+=(--ctl=1 --ctl-epsilon=$val --ctl-cost=0) ;;
    qt)   extra+=(--ctl=1 --ctl-epsilon=$val --ctl-cost=1) ;;
    drysep) extra+=(--optimism-window=$val --ctl=1 --ctl-dry=1 --ctl-reduction=0) ;;
    hillsep) extra+=(--optimism-window=$val --ctl=2 --ctl-reduction=0) ;;
  esac
  if [[ $kind =~ ^(qs|drys)(c?)([0-9]+)$ ]]; then
    extra+=(--ctl=1 --ctl-reduction=1 --ctl-interval=1
            --ctl-hist-waves=${BASH_REMATCH[3]})
    if [ -n "${BASH_REMATCH[2]}" ]; then
      extra+=(--ctl-hist-coarse=1)
    else
      extra+=(--ctl-hist-coarse=0)
    fi
    if [ ${BASH_REMATCH[1]} = qs ]; then
      extra+=(--ctl-epsilon=$val)
    else
      extra+=(--optimism-window=$val --ctl-dry=1)
    fi
  fi
  extra+=(--gvt-bucket-size=$bucket)
  if [ "$AGG" != off ]; then
    extra+=(--aggregation=1 --agg-mode=$(mode_num ${AGG%%:*}) --agg-buffer=${AGG##*:}
            --agg-policy=1 --agg-horizon-margin=$margin)
  fi
  extra+=(${EXTRA_ARGS:-})
  srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -N $N -n $n -c ${CPT:-$((pe / n))} ${SRUN_ARGS:-} -J cs_$label \
      ${BIN_WRAP:-} $bin +pe $pe $cfg $C/tests/test_configs/$gvtcfg "${extra[@]}" \
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
  [[ $kind =~ ^drys ]] && fw=$val mw=$val
  [ $kind = blk ] && fw=none mw=none
  echo "$rep,$N,$n,$pe,$lps,$wl,$AGG,$bucket,$margin,$arm,$status,$(printf %.2f $wall),$(stat 'Execution Time' $f),$(stat 'Events Committed' $f),$(stat 'Events Rolled Back' $f),$(stat 'Efficiency' $f),$(stat 'Event Rate' $f),$(stat 'Total GVT Computations' $f),$(stat 'Remote Sends' $f),$(stat 'Events per htram Message' $f),$(stat 'Rounds' $f),$fw,$mw,$(stat 'Stragglers per executed event' $f),$(stat 'Final alpha' $f),$(stat 'Count Reductions :' $f),$(stat 'Final kappa' $f),$(stat 'Timestamp Rollback Calls' $f),$(stat 'Late Stragglers' $f)" >> $csv
  printf "%-60s %-5s %7.2fs\n" $label $status $wall
}

for rep in $(seq $reps); do
  for N in $NODES; do
    n=$((N * PPN)); pe=$((n * PEPP)); lps=$((pe * LPS_PER_PE))
    for wl in $WORKLOADS; do
      IFS=: read -r kind a b c d e f <<< "$wl"
      cfg=$out/${wl//:/_}_${lps}_${START}_${END}
      printf '%s\n' "num-lps=$lps" "lps-per-chare=$LPC" "end-time=$END" \
          "start-events=$START" > $cfg
      bin=$C/models/phold/simple/phold
      if [ $kind = traffic ]; then
        bin=$C/models/traffic/traffic
        ny=$((lps / c))
        printf '%s\n' "num-x=$c" "num-y=$ny" "lps-per-chare=$LPC" "end-time=$END" \
            "lookahead=$a" "mean=$b" "total-cars=$((lps * d))" > $cfg
        if [ "$e" != 0 ]; then
          printf '%s\n' "percent-start=$e" "start-size=$f" "start-x=0" "start-y=0" \
              "percent-end=$e" "end-size=$f" "end-x=$((c - f))" "end-y=$((ny - f))" >> $cfg
        fi
      elif [ $kind = steady ]; then
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
