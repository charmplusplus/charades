#!/bin/bash -l
# Build the standalone Reconverse branch (reconverse-shmpr) with its tests, on a compute node.
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 cmake >/dev/null 2>&1
W=/work2/09863/rrao/stampede3; RC=$W/reconverse-shmpr; L=${1:-$W/charades-runs/shmpr/build_rc.log}
{ cmake -S $RC -B $RC/build -DCMAKE_BUILD_TYPE=Release -DRECONVERSE_BUILD_TESTS=ON -DRECONVERSE_AUTOFETCH_LCI2=ON \
    -DFETCHCONTENT_SOURCE_DIR_LCI=$W/lci-1287c59c -DRECONVERSE_TEST_LAUNCHER=$W/charades-runs/srun1.sh \
  && cmake --build $RC/build -j46; echo "exit $?"; } > $L 2>&1
tail -1 $L
