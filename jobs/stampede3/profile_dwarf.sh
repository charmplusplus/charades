#!/bin/bash
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/profile; cd $W/charades-qd && source scripts/stampede3/env.sh
NODE0=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -1)
export MARGINS=8 AGG=pp:64 LPS_PER_PE=128 LPC=16 WORKLOADS="gauss:100:1000:2000" ARMS="w:250" PPN=2 PEPP=23 CPT=24 END=2048000 TREE=charades-prod EXTRA_ARGS="+lci_ndevices 4 +pemap 2-46:2,3-47:2"
( RUNS=$OUT/dwarf $W/charades-qd/scripts/stampede3/ctl_sweep.sh 1 $OUT/dwarf.csv ) &
sp=$!; sleep 9
ssh -o "StrictHostKeyChecking no" -o LogLevel=ERROR $NODE0 '
  p=$(pgrep -u $USER "^phold$" | head -1); echo "pid $p"
  perf record -q -F 199 --call-graph dwarf,16384 -p $p -o /tmp/perf_dwarf.data -- sleep 2 >/dev/null 2>&1
  ls -la /tmp/perf_dwarf.data; cp /tmp/perf_dwarf.data '$OUT'/'
wait $sp; echo DWARF DONE
