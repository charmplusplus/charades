#!/bin/bash
cd $WORK/charades-qd && source scripts/stampede3/env.sh
export RUNS=$WORK/charades-runs/shared TREE=charades-qd MARGINS=8 AGG=pp:64
S=scripts/stampede3/ctl_sweep.sh
END=256000 WORKLOADS="gauss:100:1000:2000 steady:100:1000:1.0" ARMS="w:250 qsc8:0.003" $S 3 $RUNS/d_high.csv
END=64000 WORKLOADS="gauss:10:200:2000 steady:10:200:1.0" ARMS="w:50 qsc8:0.003" $S 3 $RUNS/d_low.csv
echo D DONE
# ROSS: build with Intel MPI, then a 1-node smoke test
module use /opt/apps/modulefiles >/dev/null 2>&1
module load intel/24.0 impi/21.11 2>&1 | tail -2 || true
module list 2>&1 | tail -3
cd $WORK/ROSS && rm -rf build && cmake -S . -B build -DROSS_BUILD_MODELS=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=gcc > $WORK/charades-runs/ross_cmake.log 2>&1; echo "cmake rc $?"
cmake --build build -j24 > $WORK/charades-runs/ross_build.log 2>&1; echo "build rc $?"
ls -la build/models/phold-gauss/phold-gauss
mkdir -p $WORK/charades-runs/ross && cd $WORK/charades-runs/ross
unset FI_PROVIDER FI_PROVIDER_PATH LD_PRELOAD
srun --mpi=pmi2 -N 1 -n 16 $WORK/ROSS/build/models/phold-gauss/phold-gauss --synch=3 --num-lps=2048 --start-events=15 --lookahead=100 --mean=1000 --sigma=2000 --end=64000 --extramem=200000 > smoke1.out 2>&1; echo "ross smoke rc $?"
grep -E "Net Events Processed|Event Rate|Efficiency|Running Time|Error|error" smoke1.out | head
echo ALL D DONE
