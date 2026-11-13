#!/bin/bash -l
# Reconverse IPC tests on node 1 of job 3682096 (srun1.sh, 30 s caps)
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 cmake >/dev/null 2>&1
W=/work2/09863/rrao/stampede3
export SLURM_JOB_ID=3682096 SLURM_JOBID=3682096 SHMPR_NODE=c455-044 XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536
source $W/charades-shm-pr2/scripts/stampede3/env.sh >/dev/null 2>&1
cd $W/reconverse-shmpr/build && ctest -R ipc -E "^ipc-onenode$" -j1 --timeout 30 > /work2/09863/rrao/stampede3/charades-runs/shmpr2/j3682096/ctest_ipc2.log 2>&1; echo "exit $?" >> /work2/09863/rrao/stampede3/charades-runs/shmpr2/j3682096/ctest_ipc2.log
tail -4 /work2/09863/rrao/stampede3/charades-runs/shmpr2/j3682096/ctest_ipc2.log
