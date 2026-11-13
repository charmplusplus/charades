#!/bin/bash -l
# The same five tests through srun1.sh -n 1 (20 s caps), and the ssh shell's CPU mask.
W=/work2/09863/rrao/stampede3; B=${1:-$W/reconverse-shmpr/build}
echo "ssh shell: $(taskset -cp $$ | sed 's/.*: //') nproc=$(nproc --all)/$(nproc)"
JOB=$(squeue -u rrao -h -o "%i %j" | awk '$2 ~ /^idv/ {print $1; exit}')
export SLURM_JOB_ID=$JOB SLURM_JOBID=$JOB SHMPR_NODE=$(hostname -s) XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536
source $W/charades-shm-pr/scripts/stampede3/env.sh >/dev/null 2>&1
cmd() { grep -h "add_test($1 " $B/tests -r --include=CTestTestfile.cmake | head -1 | sed -e "s/add_test($1 //" -e 's/)$//' -e 's/"//g'; }
for t in pingpong_multipairs fanout_refcount-onepe nodeq_sharing randomized_msgq-fifo ipc-onenode; do
  c=$(cmd $t); t0=$(date +%s.%N)
  timeout -s TERM 20 $W/charades-runs/srun1.sh -n 1 $c > /tmp/h20s.out 2>&1; rc=$?
  printf "%-24s srun -n 1: rc=%-3s %5.1f s  %s\n" $t $rc $(echo "$(date +%s.%N) - $t0" | bc) "$(tail -1 /tmp/h20s.out | cut -c1-70)"
done
for s in $(squeue -h -s -j $JOB -o "%i %j" | awk '$2 !~ /^(batch|extern|interactive)$/ {print $1}'); do scancel $s; done
