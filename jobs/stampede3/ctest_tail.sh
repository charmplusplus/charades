#!/bin/bash -l
# The branch's remaining ctest (tests 129-133), 30 s per test, inside the idev job.
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 cmake >/dev/null 2>&1
W=/work2/09863/rrao/stampede3; O=$W/charades-runs/shmpr/idev
JOB=$(squeue -u rrao -h -o "%i %j" | awk '$2 ~ /^idv/ {print $1; exit}')
export SLURM_JOB_ID=$JOB SLURM_JOBID=$JOB SHMPR_NODE=$(hostname -s) XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536
source $W/charades-shm-pr/scripts/stampede3/env.sh >/dev/null 2>&1
cd $W/reconverse-shmpr/build && ctest -j1 --timeout 30 -I 129,133 > $O/ctest_129_133.log 2>&1
grep -E " Test +#|tests passed" $O/ctest_129_133.log
for s in $(squeue -h -s -j $JOB -o "%i %j" | awk '$2 !~ /^(batch|extern|interactive)$/ {print $1}'); do scancel $s; done
