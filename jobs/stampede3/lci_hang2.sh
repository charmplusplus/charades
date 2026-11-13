#!/bin/bash
# Classify the psm2 hangs: (1) 23x23 repeated, how many devices each rank had
# created when it stopped; (2) 1 thread x 4M with a larger psm2 unexpected
# queue (PSM2_MQ_RECVREQS_MAX).
W=/work2/09863/rrao/stampede3; A=$W/lci_ab; OUT=$A/hang2; mkdir -p $OUT
source $W/charades-qd/scripts/stampede3/env.sh >/dev/null 2>&1
export XPORT=psm2 LCI_ATTR_OFI_PROVIDER_NAME=psm2 FI_PROVIDER=psm2 PSM2_MULTI_EP=1
export OMP_PLACES=cores OMP_PROC_BIND=close LCI_LOG_LEVEL=info
nodes=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -2 | paste -sd,)
run() { # label timeout threads devices nmsgs [env...]
  local l=$1 t=$2 th=$3 d=$4 n=$5; shift 5
  timeout -s TERM $t srun --mpi=pmi2 --kill-on-bad-exit=1 -w $nodes -N 2 --ntasks-per-node=1 -c 48 -J h_$l \
    env OMP_NUM_THREADS=$th "$@" $A/new/build/bin/lci_bench_many2many_am -s 8 -n $n -t $th -d $d -m 1024 > $OUT/$l.out 2>&1
  local rc=$?
  echo "$l rc=$rc devices r0=$(grep -c '^0:.*Device [0-9]* created' $OUT/$l.out) r1=$(grep -c '^1:.*Device [0-9]* created' $OUT/$l.out) alerts=$(grep -c 'Deadlock alert' $OUT/$l.out) $(grep -h 'Global message rate' $OUT/$l.out | grep -o '[0-9.]* Mmsgs/s') $(grep -ho 'Exhausted [0-9]* MQ[^(]*' $OUT/$l.out | head -1)"
}
for i in 1 2 3 4 5 6; do run h1_$i 40 23 23 400000 X=1; done
run h1_np 40 23 23 400000 LCI_ATTR_NPACKETS=131072
run h1_d18 40 18 18 400000 X=1
run h1_d19 40 19 19 400000 X=1
run h2_base 90 1 1 4000000 X=1
run h2_big 150 1 1 4000000 PSM2_MQ_RECVREQS_MAX=16777216
echo HANG2 DONE
