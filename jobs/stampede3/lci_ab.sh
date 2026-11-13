#!/bin/bash
# LCI PR #214 review changes on native psm2 (2 nodes):
#  1. ctest of the new branch (9effa44a: FI_CONTEXT only, no op_ctx cache,
#     dead branch removed) with every test launched across 2 nodes;
#  2. message rate, old (77d16300: FI_CONTEXT2 + per-thread op_ctx cache)
#     against new, interleaved: lci_bench_many2many_am, 8-byte AMs.
# Usage (on the idev node): lci_ab.sh <reps>
W=/work2/09863/rrao/stampede3; A=$W/lci_ab; OUT=$A/runs; mkdir -p $OUT
export XPORT=psm2; source $W/charades-qd/scripts/stampede3/env.sh
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 cmake >/dev/null 2>&1
nodes=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -2 | paste -sd,)
echo "# $(date '+%F %T') job $SLURM_JOB_ID nodes $nodes FI_PROVIDER=$FI_PROVIDER LCI_ATTR_OFI_PROVIDER_NAME=$LCI_ATTR_OFI_PROVIDER_NAME"
( cd $A/new/build && SLURM_NODELIST=$nodes timeout 900 ctest -j1 --timeout 120 > $OUT/ctest_new.log 2>&1; tail -5 $OUT/ctest_new.log; grep -E "\*\*\*|Failed" $OUT/ctest_new.log | head )
export OMP_PLACES=cores OMP_PROC_BIND=close
for rep in $(seq 1 ${1:-5}); do
  for t in 1 8 23; do
    for v in old new; do
      r=$(timeout 300 srun --mpi=pmi2 -w $nodes -N 2 --ntasks-per-node=1 -c 48 -J ab_$v \
            env OMP_NUM_THREADS=$t $A/$v/build/bin/lci_bench_many2many_am -s 8 -n 4000000 -t $t -d $t -m 1024 2>&1 |
          awk '/Global message rate/ {print $(NF-1)}')
      echo "rep=$rep threads=$t version=$v Mmsgs_per_s=${r:-NA}" | tee -a $OUT/rates.txt
    done
  done
done
echo LCI_AB DONE
