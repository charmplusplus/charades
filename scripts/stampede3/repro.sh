#!/bin/bash
# repro.sh <reps> <procs> <pes> <model dir> <model cfg> <test cfg> [tree]
# Run one case until it fails (STOP= to keep going); keep cores
# (systemd-coredump) for the failure. Run on the idev master node.
reps=$1 procs=$2 pes=$3 mdir=$4 mcfg=$5 tcfg=$6 tree=${7:-charades}
source "$(dirname "$0")/env.sh"
ulimit -c unlimited
C=$WORK/$tree
exe=$(ls $C/models/$mdir/* -d | while read f; do [ -x "$f" ] && [ -f "$f" ] && echo $f; done | head -1)
out=${RUNS:-$WORK/charades-runs}/repro/$(basename $mdir)_${mcfg}_${tcfg}_${procs}x$pes
mkdir -p $out; cd $out
fails=0
for i in $(seq $reps); do
    srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -N 1 -n $procs -c $((pes / procs)) \
        $exe +pe $pes $C/models/$mdir/test_configs/$mcfg $C/tests/test_configs/$tcfg > run.out 2>&1
    rc=$?
    if [ $rc -ne 0 ] || ! grep -q "Simulation Executed Successfully" run.out; then
        fails=$((fails + 1)); cp run.out fail.$i.out
        echo "rep $i: rc=$rc"; tail -n 3 run.out
        [ -n "${STOP-1}" ] && break
    fi
done
echo "$fails failures in $i runs ($exe)"
