#!/bin/bash
# Phase-changing PHOLD, then the traffic characterisation, back to back on
# the 4 nodes of the running allocation. Usage: phase_traffic.sh <reps>
N=$(scontrol show hostnames $(squeue -h -u $USER -t R -o "%N" | head -1) | paste -sd,)
$WORK/charades-runs/phase_ab_frozen.sh $N ${1:-3} > $WORK/charades-runs/phase_ab.log 2>&1
$WORK/charades-runs/traffic_char_frozen.sh $N ${1:-3} > $WORK/charades-runs/traffic_char.log 2>&1
echo BOTH DONE
