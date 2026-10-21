#!/bin/bash
# Repeat one PHOLD configuration under the bucketed GVT with --gvt-trace=1,
# each run in its own directory (gvt_trace.csv, run.out), to compare runs
# that land in different GVT modes. Run on the idev master node.
#
# Usage: gvt_modes.sh <reps> <name> [phold args...]
#   e.g. gvt_modes.sh 8 hs_w250 --lookahead=100 --mean=1000 --remote=0.5 \
#          --optimism-window=250
# Knobs (environment): NODES=4, PPN=2, PEPP=8, LPS_PER_PE=128, START=15,
#   END=128000, AGG="pp:64" (deadline policy, margin MARGIN=8; "off" sends
#   directly), CAP=120 (s), TREE=charades-qd, EXTRA_ARGS="+lci_ndevices 8".
# Prints one line per run: rate (M committed events/s), GVT computations,
# wall time; writes $RUNS/gvt_modes/<name>/r<i>/.
reps=${1:?reps}; name=${2:?name}; shift 2
source "$(dirname "$0")/env.sh"
NODES=${NODES:-4} PPN=${PPN:-2} PEPP=${PEPP:-8} LPS_PER_PE=${LPS_PER_PE:-128}
START=${START:-15} END=${END:-128000} AGG=${AGG:-pp:64} MARGIN=${MARGIN:-8}
CAP=${CAP:-120} TREE=${TREE:-charades-qd}
EXTRA_ARGS=${EXTRA_ARGS-"+lci_ndevices 8"}
C=$WORK/$TREE
n=$((NODES * PPN)); pe=$((n * PEPP)); lps=$((pe * LPS_PER_PE))
base=${RUNS:-$WORK/charades-runs}/gvt_modes/$name; mkdir -p $base
mode_num() { case $1 in wps) echo 0;; wsp) echo 1;; pp) echo 2;; ww) echo 3;; esac; }
agg=()
if [ "$AGG" != off ]; then
  agg=(--aggregation=1 --agg-mode=$(mode_num ${AGG%%:*}) --agg-buffer=${AGG##*:}
       --agg-policy=1 --agg-horizon-margin=$MARGIN)
fi
echo "$name: $(git -C $C log --oneline -1 | cut -c1-50); args: $*"
for i in $(seq $reps); do
  d=$base/r$i; mkdir -p $d; cd $d
  t0=$(date +%s.%N)
  timeout -s TERM $CAP srun --mpi=pmi2 --kill-on-bad-exit=1 -N $NODES -n $n -c $PEPP \
      $C/models/phold/simple/phold +pe $pe $C/tests/test_configs/bucket \
      --num-lps=$lps --lps-per-chare=16 --end-time=$END --start-events=$START \
      --gvt-trace=1 "${agg[@]}" "$@" ${EXTRA_ARGS:-} > run.out 2>&1
  rc=$?
  printf "r%-3d rc %-3d rate %6.2f  gvts %6s  wall %6.2fs\n" $i $rc \
      "$(awk '/Event Rate/ {print $NF/1e6; exit}' run.out)" \
      "$(awk '/Total GVT Computations/ {print $NF; exit}' run.out)" \
      "$(echo "$(date +%s.%N) - $t0" | bc)"
done
