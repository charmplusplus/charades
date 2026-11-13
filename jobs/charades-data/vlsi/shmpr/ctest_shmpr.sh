#!/bin/bash -l
# Run the standalone Reconverse branch's ctest inside job $1 on node $2 (srun1.sh launches every test's processes there).
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 cmake >/dev/null 2>&1
W=/work2/09863/rrao/stampede3
export SLURM_JOB_ID=$1 SLURM_JOBID=$1 SHMPR_NODE=$2 XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536
source $W/charades-shm-pr/scripts/stampede3/env.sh >/dev/null 2>&1
L=$W/charades-runs/shmpr/j$1/ctest2.log
cd $W/reconverse-shmpr/build && { ctest -j1 --timeout 180 > $L 2>&1; echo "exit $?" >> $L; }
