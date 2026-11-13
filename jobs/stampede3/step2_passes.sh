#!/bin/bash
# Step 2 measurements (cost-aware controller, floor guard). Run on the idev
# master node via nd. CSVs in $WORK/charades-runs/step2/.
cd $WORK/charades-qd && source scripts/stampede3/env.sh
export RUNS=$WORK/charades-runs/step2 TREE=charades-qd MARGINS=8
S=scripts/stampede3/ctl_sweep.sh
HI="gauss:100:1000:100 gauss:100:1000:500 gauss:100:1000:1000 gauss:100:1000:2000 gauss:100:1000:4000 steady:100:1000:1.0"
LO="gauss:10:200:500 gauss:10:200:2000 steady:10:200:1.0"
# 1. Full nodes (2 x 24 PEs per node, 8,448 LPs as ROSS), with the per-round log
for end in 64000 256000; do
  PPN=2 PEPP=24 LPS_PER_PE=44 LPC=4 END=$end AGG=pp:64 WORKLOADS="gauss:100:1000:2000" \
    ARMS="w:250 q:0.01 qev:0.003" EXTRA_ARGS="+lci_ndevices 8 --ctl-log=1" $S 2 $RUNS/full_hi_$end.csv
done
PPN=2 PEPP=24 LPS_PER_PE=44 LPC=4 END=64000 AGG=pp:64 WORKLOADS="gauss:10:200:2000" \
  ARMS="w:50 q:0.01 qev:0.003" EXTRA_ARGS="+lci_ndevices 8 --ctl-log=1" $S 2 $RUNS/full_lo.csv
echo PART1 DONE
# 2. The gate: 9 workloads x 2 transports, time share 0.01 vs event share 0.003
END=256000 AGG=pp:64 WORKLOADS="$HI" ARMS="w:250 q:0.01 qev:0.003" $S 3 $RUNS/gate_pp_hi.csv
END=64000 AGG=pp:64 WORKLOADS="$LO" ARMS="w:50 q:0.01 qev:0.003" $S 3 $RUNS/gate_pp_lo.csv
END=256000 AGG=off WORKLOADS="$HI" ARMS="w:250 q:0.01 qev:0.003" $S 2 $RUNS/gate_off_hi.csv
END=64000 AGG=off WORKLOADS="$LO" ARMS="w:50 q:0.01 qev:0.003" $S 2 $RUNS/gate_off_lo.csv
echo PART2 DONE
# 3. Sensitivity of the time share, htram
END=256000 AGG=pp:64 WORKLOADS="gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0" \
  ARMS="q:0.005 q:0.02" $S 2 $RUNS/sens_hi.csv
END=64000 AGG=pp:64 WORKLOADS="$LO" ARMS="q:0.005 q:0.02" $S 2 $RUNS/sens_lo.csv
echo ALL DONE
