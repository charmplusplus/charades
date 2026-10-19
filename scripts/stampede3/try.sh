#!/bin/bash
# try.sh <cap s> <N> <n> <pes> <label> -- <phold args...>
# Run Gaussian-style PHOLD once with a time cap; on timeout cancel the step
# with scancel (never SIGKILL srun: that orphans the step).
cap=$1 N=$2 n=$3 pe=$4 label=$5; shift 6
source "$(dirname "$0")/env.sh"
out=${RUNS:-$WORK/charades-runs}/try; mkdir -p $out; cd $out
f=run.$label
srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -N $N -n $n -c $((pe / n)) -J try_$label \
    stdbuf -oL $WORK/${TREE:-charades}/models/phold/simple/phold +pe $pe "$@" > $f 2>&1 &
sp=$!
t0=$(date +%s)
while kill -0 $sp 2>/dev/null; do
    sleep 1
    if [ $(( $(date +%s) - t0 )) -ge $cap ]; then
        st=$(squeue -h -s -j $SLURM_JOB_ID -o "%i %j" | awk -v j=try_$label '$2==j {print $1}')
        [ -n "$st" ] && scancel $st
        wait $sp 2>/dev/null
        echo "$label: TIMEOUT after ${cap}s, $(grep -c '^GVT' $f) GVT lines, last: $(grep '^GVT' $f | tail -n 1)"
        exit 1
    fi
done
echo "$label: $(( $(date +%s) - t0 ))s exec $(awk '/Execution Time/ {print $NF; exit}' $f) committed $(awk '/Events Committed/ {print $NF; exit}' $f) $(grep -q Successfully $f && echo ok || echo FAIL)"
