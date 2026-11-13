#!/bin/bash
# Follow-ups to rt_sweep.sh: what runs on the freed core, two free cores per
# process, ndev 4 vs 8, W and the controller on the best layout, Devastator anchor.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/rtsweep2; mkdir -p $OUT
cd $W/charades-qd && source scripts/stampede3/env.sh
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-prod MARGINS=8 AGG=pp:64 LPS_PER_PE=128 LPC=16 END=512000 \
  WORKLOADS="gauss:100:1000:2000" ARMS="w:250"
P23="+pemap 2-46:2,3-47:2"; P22="+pemap 4-46:2,5-47:2"
run() { local name=$1; shift
  ( export "$@"; RUNS=$OUT/$name $S 1 $OUT/${name}_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$name /" ); }
# 1. threads per process and their CPU time, sampled mid-run on the first node
rep=0
( export PPN=2 PEPP=23 CPT=24 "EXTRA_ARGS=+lci_ndevices 8 $P23" END=2048000; RUNS=$OUT/threads $S 1 $OUT/threads.csv ) &
sp=$!; sleep 15
node=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -1)
ssh -o "StrictHostKeyChecking no" -o LogLevel=ERROR $node 'for p in $(pgrep -u $USER -f "simple/phold"); do echo "pid $p: $(ls /proc/$p/task | wc -l) threads"; ps -L -o tid=,psr=,pcpu=,comm= -p $p | sort -k3 -rn | head -30; done' > $OUT/threads.txt 2>&1
wait $sp
for rep in 1 2 3; do
  echo "=== rep $rep"
  run 2x23_ndev4 PPN=2 PEPP=23 CPT=24 "EXTRA_ARGS=+lci_ndevices 4 $P23"
  run 2x23_ndev8 PPN=2 PEPP=23 CPT=24 "EXTRA_ARGS=+lci_ndevices 8 $P23"
  run 2x22_ndev4 PPN=2 PEPP=22 CPT=24 "EXTRA_ARGS=+lci_ndevices 4 $P22"
  run 2x22_ndev8 PPN=2 PEPP=22 CPT=24 "EXTRA_ARGS=+lci_ndevices 8 $P22"
  run 64_2x8_ndev4 PPN=2 PEPP=8 CPT=24 "EXTRA_ARGS=+lci_ndevices 4 +pemap 2-16:2,3-17:2"
done
for rep in 1 2; do
  run 2x23_ndev4_arms PPN=2 PEPP=23 CPT=24 "EXTRA_ARGS=+lci_ndevices 4 $P23" "ARMS=w:175 w:350 q:0.003"
  WINDOW=1000 END=512000 SIGMA=2000 LPS_PER_RANK=128 RUNS=$OUT bash $W/devastator/run_phold.sh $W/devastator/bin/ofi-psm2/phold-gauss-p8w23 4 | head -1
done
echo SWEEP2 DONE
