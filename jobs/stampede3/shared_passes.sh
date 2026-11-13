#!/bin/bash
# Step 1 measurements: controller on the GVT's count waves vs. its own
# reduction. Runs on the idev master node via nd.
cd $WORK/charades-qd && source scripts/stampede3/env.sh
export RUNS=$WORK/charades-runs/shared TREE=charades-qd MARGINS=8 AGG=pp:64
S=scripts/stampede3/ctl_sweep.sh
# A: cost (the controller runs, the window stays fixed)
END=256000 WORKLOADS="gauss:100:1000:2000" \
  ARMS="w:250 dry:250 drys8:250 drysc8:250 drys1:250 drysc1:250" $S 4 $RUNS/a_high.csv
END=64000 WORKLOADS="gauss:10:200:2000" \
  ARMS="w:50 dry:50 drys8:50 drysc8:50 drys1:50 drysc1:50" $S 4 $RUNS/a_low.csv
# B: live control at epsilon 0.003
END=256000 WORKLOADS="gauss:100:1000:2000 steady:100:1000:1.0" \
  ARMS="w:250 q:0.003 qs8:0.003 qsc1:0.003 qs1:0.003" $S 3 $RUNS/b_high.csv
END=64000 WORKLOADS="gauss:10:200:2000 steady:10:200:1.0" \
  ARMS="w:50 q:0.003 qs8:0.003 qsc1:0.003 qs1:0.003" $S 3 $RUNS/b_low.csv
# C: the hill climb every 8 GVT updates, every GVT update, every wave
END=256000 WORKLOADS="gauss:100:1000:2000 steady:100:1000:1.0" \
  ARMS="hill:250 hill1:250 hills:250 hills:50" $S 3 $RUNS/c_high.csv
END=64000 WORKLOADS="gauss:10:200:2000 steady:10:200:1.0" \
  ARMS="hill:250 hill1:250 hills:250 hills:50" $S 3 $RUNS/c_low.csv
echo ALL DONE
