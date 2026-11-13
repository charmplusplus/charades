#!/bin/bash -l
# On the idev node: build Reconverse main standalone, finish the branch's ctest
# (tests 117-133), and run the two tests that timed out in 3681031 on both
# builds, launched directly and through srun1.sh.
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 cmake >/dev/null 2>&1
W=/work2/09863/rrao/stampede3; O=$W/charades-runs/shmpr/idev; mkdir -p $O
JOB=$(squeue -u rrao -h -o "%i %j" | awk '$2 ~ /^idv/ {print $1; exit}')
source <(grep -E "^export +SLURM" /tmp/idev_${USER}_bash_env.$JOB 2>/dev/null)
export SLURM_JOB_ID=$JOB SLURM_JOBID=$JOB SHMPR_NODE=$(hostname -s) XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536
source $W/charades-shm-pr/scripts/stampede3/env.sh >/dev/null 2>&1
echo "job $JOB node $SHMPR_NODE"
RM=$W/reconverse-main
{ cmake -S $RM -B $RM/build -DCMAKE_BUILD_TYPE=Release -DRECONVERSE_BUILD_TESTS=ON -DRECONVERSE_AUTOFETCH_LCI2=ON \
    -DFETCHCONTENT_SOURCE_DIR_LCI=$W/lci-1287c59c -DRECONVERSE_TEST_LAUNCHER=$W/charades-runs/srun1.sh \
  && cmake --build $RM/build -j46; echo "exit $?"; } > $O/build_main.log 2>&1
echo "main build: $(tail -1 $O/build_main.log)"
cd $W/reconverse-shmpr/build && ctest -j1 --timeout 180 -I 117,133 > $O/ctest_117_133.log 2>&1
echo "branch ctest 117-133: $(grep -E 'tests passed' $O/ctest_117_133.log)"; grep -E "\*\*\*" $O/ctest_117_133.log
for b in shmpr main; do
  B=$W/reconverse-$b/build
  for t in "ipc/reconverse_ipc_test +pe 2 +ipc" "orig-converse/pingpong/reconverse_pingpong_multipairs +pe 4"; do
    set -- $t; exe=$B/tests/$1; shift
    t0=$(date +%s); timeout -s TERM 60 $exe "$@" > $O/direct_${b}_$(basename $exe).out 2>&1; rc=$?
    echo "$b direct $(basename $exe) $*: rc=$rc $(( $(date +%s) - t0 )) s; $(tail -1 $O/direct_${b}_$(basename $exe).out | cut -c1-80)"
    t0=$(date +%s); timeout -s TERM 60 $W/charades-runs/srun1.sh -n 1 $exe "$@" > $O/srun_${b}_$(basename $exe).out 2>&1; rc=$?
    echo "$b srun   $(basename $exe) $*: rc=$rc $(( $(date +%s) - t0 )) s; $(tail -1 $O/srun_${b}_$(basename $exe).out | cut -c1-80)"
  done
done
