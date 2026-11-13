#!/bin/bash
# Devastator's own window on phase-changing PHOLD (charades CONTEXT.md,
# design 2026-10-22). Run inside the 4-node allocation (ssh shell on the
# idev node). Same workload as phase_ab.sh: phases:10:200:100:1000:<remote>:32000,
# end 256,000, 128 LPs per rank, 15 start events; 8 procs x 8 workers.
set -u
export WORK=/work2/09863/rrao/stampede3
D=$WORK/devastator
B=$D/bin/ofi-psm2/phold-gauss-p8w8
export RUNS=$WORK/charades-runs/phase_deva LPS_PER_RANK=128 START=15 \
       LOOKAHEAD=10 MEAN=200 SIGMA=0 END=256000 CAP=180 AFFINITY=0
for rep in 1 2 3; do
  for rem in 0.5 1.0; do
    for arm in adaptive 50 100 250 500 1000 2000; do
      if [ $arm = adaptive ]; then unset WINDOW; else export WINDOW=$arm; fi
      LABEL=deva_r${rem}_${arm}_rep$rep bash $D/run_phold.sh $B 4 --remote=$rem \
        --phase-length=32000 --alt-lookahead=100 --alt-mean=1000
    done
  done
done
