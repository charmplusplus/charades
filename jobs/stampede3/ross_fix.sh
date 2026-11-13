#!/bin/bash
# ROSS optimistic abort: build the patched copy, then control / workaround /
# fix runs (see ~/pdes-baselines/ross-debug/REPORT.md on the Mac)
module load mvapich/3.0 >/dev/null 2>&1
if [ -z "${SLURM_JOB_ID:-}" ]; then
  f=$(ls -t /tmp/idev_${USER}_bash_env.* 2>/dev/null | head -1)
  [ -n "$f" ] && source <(grep -E "^(export +|declare -x +)?SLURM_" "$f")
fi
cd $WORK && rsync -a --exclude build ROSS/ ROSS-fix/ && cd ROSS-fix && git checkout -q -- . && git apply $WORK/ross-fix.patch && echo "patch applied"
rm -rf build && cmake -S . -B build -DROSS_BUILD_MODELS=ON -DCMAKE_BUILD_TYPE=Release > $WORK/charades-runs/rossfix_cmake.log 2>&1 && cmake --build build -j24 > $WORK/charades-runs/rossfix_build.log 2>&1; echo "build rc $?"
STOCK=$WORK/ROSS/build/models/phold-gauss/phold-gauss
FIX=$WORK/ROSS-fix/build/models/phold-gauss/phold-gauss
A="--synch=3 --num-lps=8192 --start-events=15 --lookahead=100 --mean=1000 --sigma=2000 --end=64000 --extramem=400000"
A48="--synch=3 --num-lps=8448 --start-events=15 --lookahead=100 --mean=1000 --sigma=2000 --end=64000 --extramem=400000"
mkdir -p $WORK/charades-runs/rossfix && cd $WORK/charades-runs/rossfix
r() {  # label N n binary args...
  local l=$1 N=$2 n=$3; shift 3
  ( timeout -s TERM 400 srun --mpi=pmi2 --kill-on-bad-exit=1 -N $N -n $n --ntasks-per-node=$((n / N)) "$@" > $l.out 2>&1 ); local rc=$?
  echo "$l rc=$rc committed $(awk '/Net Events Processed/{print $NF; exit}' $l.out) M ev/s $(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' $l.out) eff $(awk '/Efficiency/{print $(NF-1); exit}' $l.out) held $(grep -m1 -i 'held' $l.out | awk '{print $NF}') $(grep -m1 -oE 'never look|still waiting|rror: [^ ]+' $l.out)"
}
for rep in 1 2; do
  r ctl_stock_2x16_$rep 2 32 $STOCK $A
  r rb1_stock_2x16_$rep 2 32 $STOCK $A --read-buffer=1
  r fix_2x16_$rep 2 32 $FIX $A
done
FI_PROVIDER=tcp r fix_tcp_2x16 2 32 $FIX $A
r fix_4x16 4 64 $FIX $A
r fix_4x48 4 192 $FIX $A48
r rb1_stock_4x48 4 192 $STOCK $A48 --read-buffer=1
r fix_4x48_b 4 192 $FIX $A48
echo ROSS DONE
