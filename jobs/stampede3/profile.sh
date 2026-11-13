#!/bin/bash
# Profile Charades (production runtime, best launch settings) against Devastator:
# perf on node 0 mid-run, then Projections traces of short runs.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/profile; mkdir -p $OUT
PROJ=/scratch/09863/rrao/proj
log() { echo "[$(date +%T)] $*"; }
cd $W/charades-qd && source scripts/stampede3/env.sh
NODE0=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -1)
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export MARGINS=8 AGG=pp:64 LPS_PER_PE=128 LPC=16 WORKLOADS="gauss:100:1000:2000" ARMS="w:250"
FULL="PPN=2 PEPP=23 CPT=24"; P23="+lci_ndevices 4 +pemap 2-46:2,3-47:2"
P8="+lci_ndevices 4 +pemap 2-16:2,3-17:2"

# 0. builds: Charm++ production + tracing, then Charades against it
if [ ! -x $W/charm-pads-trace/reconverse-linux-x86_64/bin/charmc ]; then
  log "building charm-pads-trace"
  (cd $W/charm-pads-trace && ./build charm++ reconverse-linux-x86_64 --with-production --enable-tracing --disable-fortran -j48 > build.log 2>&1) || { tail -20 $W/charm-pads-trace/build.log; exit 1; }
fi
log "trace macros: $(grep -E "define CMK_(ERROR_CHECKING|TRACE_ENABLED)\b" $W/charm-pads-trace/reconverse-linux-x86_64/include/conv-autoconfig.h | tr "\n" " ")"
(cd $W/charades-trace && make -s -C src clean && make -s -C models/phold/simple clean && make -s -C src && make -s -C models/phold/simple) > $OUT/build_trace.log 2>&1 || { tail -20 $OUT/build_trace.log; exit 1; }
ls -la $W/charades-trace/models/phold/simple/phold

# perf on node 0: record call stacks (LBR) and counters for a few seconds mid-run
perf_node0() {  # name pattern delay secs
  local name=$1 pat=$2 delay=$3 secs=$4
  sleep $delay
  ssh -o "StrictHostKeyChecking no" -o LogLevel=ERROR $NODE0 "
    pids=\$(pgrep -u \$USER '$pat' | paste -sd,)
    echo \"$name: pids \$pids\"
    perf stat -e task-clock,cycles,instructions,branch-misses,cache-misses,LLC-load-misses,LLC-store-misses -p \$pids -- sleep 2 2> /tmp/perfstat_$name.txt >/dev/null
    perf record -q -F 499 --call-graph lbr -p \$pids -o /tmp/perf_$name.data -- sleep $secs >/dev/null 2>&1
    perf report -i /tmp/perf_$name.data --stdio --no-children --sort dso,symbol --percent-limit 0.2 2>/dev/null | grep -v '^#' | grep -v '^\$' | head -150 > $OUT/perf_${name}_self.txt
    perf report -i /tmp/perf_$name.data --stdio --no-children --sort dso 2>/dev/null | grep -v '^#' | grep -v '^\$' | head -30 > $OUT/perf_${name}_dso.txt
    perf report -i /tmp/perf_$name.data --stdio --children --sort symbol -g none --percent-limit 1 2>/dev/null | grep -v '^#' | grep -v '^\$' | head -120 > $OUT/perf_${name}_incl.txt
    cp /tmp/perfstat_$name.txt $OUT/
    cp /tmp/perf_$name.data $OUT/ 2>/dev/null
  "
}

log "perf: Charades full nodes"
( export $FULL END=2048000 "EXTRA_ARGS=$P23" TREE=charades-prod; RUNS=$OUT/perf_full $S 1 $OUT/perf_full.csv ) &
sp=$!; perf_node0 charades_full '^phold$' 8 5; wait $sp
log "perf: Charades 64 PEs"
( export PPN=2 PEPP=8 CPT=24 END=2048000 "EXTRA_ARGS=$P8" TREE=charades-prod; RUNS=$OUT/perf_64 $S 1 $OUT/perf_64.csv ) &
sp=$!; perf_node0 charades_64 '^phold$' 8 5; wait $sp
D=$W/devastator
log "perf: Devastator full nodes (W 1000)"
( WINDOW=1000 END=4096000 SIGMA=2000 LPS_PER_RANK=128 RUNS=$OUT bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p8w23 4 | head -2 ) &
sp=$!; perf_node0 deva_full '^phold-gauss' 5 4; wait $sp
log "perf: Devastator 64 ranks (W 1000)"
( WINDOW=1000 END=4096000 SIGMA=2000 RUNS=$OUT bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p8w8 4 | head -2 ) &
sp=$!; perf_node0 deva_64 '^phold-gauss' 4 3; wait $sp

# Projections: short runs, traced and untraced
for cfg in full 64; do
  if [ $cfg = full ]; then L="$FULL"; A="$P23"; else L="PPN=2 PEPP=8 CPT=24"; A="$P8"; fi
  rm -rf $PROJ/$cfg; mkdir -p $PROJ/$cfg
  log "projections: $cfg"
  ( export $L END=64000 TREE=charades-trace "EXTRA_ARGS=$A +traceroot $PROJ/$cfg +logsize 4000000"; RUNS=$OUT/proj_$cfg $S 1 $OUT/proj_$cfg.csv | grep -E " (ok|fail|stall) " )
  ( export $L END=64000 TREE=charades-prod "EXTRA_ARGS=$A"; RUNS=$OUT/untraced_$cfg $S 2 $OUT/untraced_$cfg.csv | grep -E " (ok|fail|stall) " )
  du -sh $PROJ/$cfg; ls $PROJ/$cfg | head -3
done
log "PROFILE DONE"
