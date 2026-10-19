#!/bin/bash
# A/B: Charades on pinned Reconverse (tree charades) vs. idle-progress-poll
# (tree charades-qd), quiescence-heavy configs, 1 PE per process.
# Prints one line per run: rep tree cfg layout exec_time wall status. With
# QDLOOP=<dir> holding <charm tree>/qdloop builds of a back-to-back CkStartQD
# loop, also prints the QD round time (ms) for each tree and layout.
# Usage: ab_qd.sh <reps> [model cfg]   (run on the idev master node)
reps=${1:-3} mcfg=${2:-long}
source "$(dirname "$0")/env.sh"
out=${RUNS:-$WORK/charades-runs}/ab_qd; mkdir -p $out; cd $out
# layout = nodes:procs:pes
layouts="1:1:1 1:2:2 1:4:4 2:2:2 2:4:4 2:8:8"
charm_of() { [ $1 = charades ] && echo charm-pads || echo charm-pads-qd; }
for rep in $(seq $reps); do
  if [ -n "${QDLOOP:-}" ]; then
    for lay in $layouts; do
      IFS=: read N n pe <<< "$lay"
      for tree in charades charades-qd; do
        r=$(timeout -s TERM -k 30 300 srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 \
            -N $N -n $n -c $((pe / n)) $QDLOOP/$(charm_of $tree)/qdloop 500 +pe $pe 2>&1 |
            awk '/QDLOOP/ {sub("per_round=", "", $(NF-1)); print $(NF-1)}')
        printf "%d %-12s %-13s %-6s %10s\n" $rep $tree qdloop $lay "${r:-FAIL}"
      done
    done
  fi
  for cfg in conservative blocking; do
    for lay in $layouts; do
      IFS=: read N n pe <<< "$lay"
      for tree in charades charades-qd; do
        C=$WORK/$tree
        t0=$(date +%s.%N)
        timeout -s TERM -k 30 300 srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 \
            -N $N -n $n -c $((pe / n)) $C/models/phold/simple/phold +pe $pe \
            $C/models/phold/simple/test_configs/$mcfg $C/tests/test_configs/$cfg \
            > run.out 2>&1
        rc=$?
        t1=$(date +%s.%N)
        ex=$(awk '/Execution Time/ {print $NF; exit}' run.out)
        ok=FAIL; grep -q "Simulation Executed Successfully" run.out && [ $rc -eq 0 ] && ok=ok
        [ $ok = ok ] || cp run.out fail_${rep}_${tree}_${cfg}_${lay//:/x}.out
        printf "%d %-12s %-13s %-6s %10s %8.2f %s\n" $rep $tree $cfg $lay "${ex:-NA}" \
            $(echo "$t1 - $t0" | bc) $ok
      done
    done
  done
done
