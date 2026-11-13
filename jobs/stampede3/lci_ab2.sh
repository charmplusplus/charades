#!/bin/bash
# LCI PR #214 on native psm2, second try (lci_ab.sh: the ctest launcher was
# mangled, and 1-thread benchmark runs hung for both versions).
#  1. 1-thread diagnostic (new), output kept, at two message counts;
#  2. old vs new message rate at 8 and 23 threads, interleaved;
#  3. ctest of new, each test across 2 nodes.
W=/work2/09863/rrao/stampede3; A=$W/lci_ab; OUT=$A/runs; mkdir -p $OUT
export XPORT=psm2; source $W/charades-qd/scripts/stampede3/env.sh
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 cmake >/dev/null 2>&1
nodes=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -2 | paste -sd,)
export OMP_PLACES=cores OMP_PROC_BIND=close
run() { # version threads nmsgs label
  timeout -s TERM ${T:-120} srun --mpi=pmi2 --kill-on-bad-exit=1 -w $nodes -N 2 --ntasks-per-node=1 -c 48 -J ab_$1 \
    env OMP_NUM_THREADS=$2 $A/$1/build/bin/lci_bench_many2many_am -s 8 -n $3 -t $2 -d $2 -m 1024 > $OUT/$4.out 2>&1
  echo "$4 rc=$? Mmsgs_per_s=$(awk '/Global message rate/ {print $(NF-1)}' $OUT/$4.out)"
}
echo "# $(date '+%F %T') job $SLURM_JOB_ID nodes $nodes"
T=60 run new 1 100000 diag_new_t1_n1e5
T=60 run new 2 100000 diag_new_t2_n1e5
for rep in 1 2 3 4 5; do for t in 8 23; do for v in old new; do
  run $v $t 4000000 ab_${v}_t${t}_rep$rep | tee -a $OUT/rates2.txt
done; done; done
( cd $A/new/build && timeout -s TERM 1200 ctest -j1 --timeout 120 > $OUT/ctest_new2.log 2>&1; tail -4 $OUT/ctest_new2.log; grep -E "\*\*\*" $OUT/ctest_new2.log | head -20 )
echo LCI_AB2 DONE
