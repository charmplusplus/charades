#!/bin/bash
# Fair-share receive cap (LCI 8c867a6c on the PR branch) on psm2: the 23x23
# hang, and old (PR cb204aaf build = "new") vs fixed at 8, 16, 23 threads.
W=/work2/09863/rrao/stampede3; A=$W/lci_ab; OUT=$A/fs; mkdir -p $OUT
source $W/charades-qd/scripts/stampede3/env.sh >/dev/null 2>&1
export XPORT=psm2 LCI_ATTR_OFI_PROVIDER_NAME=psm2 FI_PROVIDER=psm2 PSM2_MULTI_EP=1
export OMP_PLACES=cores OMP_PROC_BIND=close
nodes=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -2 | paste -sd,)
run() { # build threads nmsgs label
  timeout -s TERM 60 srun --mpi=pmi2 --kill-on-bad-exit=1 -w $nodes -N 2 --ntasks-per-node=1 -c 48 -J fs_$4 \
    env OMP_NUM_THREADS=$2 $A/$1/build/bin/lci_bench_many2many_am -s 8 -n $3 -t $2 -d $2 -m 1024 > $OUT/$4.out 2>&1
  echo "$4 rc=$? $(grep -h 'Global message rate' $OUT/$4.out | grep -o '[0-9.]* Mmsgs/s') alerts=$(grep -c 'Deadlock alert' $OUT/$4.out)"
}
for rep in 1 2 3; do
  for t in 8 16 23; do
    for b in nits fs; do run $b $t 4000000 ${b}_t${t}_rep$rep; done
  done
done
echo FS DONE
