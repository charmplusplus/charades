#!/bin/bash
# Controller level vs dynamics, --agg-scope ablation, sigma 100 profile
# (charades CONTEXT.md "Controller level, --agg-scope, sigma 100 profile",
# design 2026-10-23). Full nodes: ctl_sweep.sh defaults.
# Usage: diag1.sh "<stages: A B C>" <reps>
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/diag1; mkdir -p $OUT
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
D=$W/devastator; DB=$D/bin/ofi-psm2/phold-gauss-p8w23
NODE0=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -1)
export NODES=4 LPS_PER_PE=128 LPC=16 CAP=120
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
STAGES=${1:-"A B C"} REPS=${2:-3}
log() { echo "[$(date +%T)] $*"; }
cs() { # tag agg end workloads arms extra
  ( export AGG=$2 END=$3 WORKLOADS="$4" ARMS="$5" EXTRA_ARGS="$P $6"
    RUNS=$OUT/$1 $S 1 $OUT/$1_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }

perf_node0() {  # name pattern delay secs dwarf(0/1)
  local name=$1 pat=$2 delay=$3 secs=$4 dwarf=$5
  sleep $delay
  ssh -o "StrictHostKeyChecking no" -o LogLevel=ERROR $NODE0 "
    pids=\$(pgrep -u \$USER '$pat' | paste -sd,)
    echo \"$name: pids \$pids\"
    perf stat -e task-clock,cycles,instructions,branch-misses,cache-misses,LLC-load-misses -p \$pids -- sleep 2 2> $OUT/perfstat_$name.txt >/dev/null
    perf record -q -F 499 --call-graph lbr -p \$pids -o /tmp/perf_$name.data -- sleep $secs >/dev/null 2>&1
    perf report -i /tmp/perf_$name.data --stdio --no-children --sort dso,symbol --percent-limit 0.2 2>/dev/null | grep -v '^#' | grep -v '^\$' | head -150 > $OUT/perf_${name}_self.txt
    perf report -i /tmp/perf_$name.data --stdio --no-children --sort dso 2>/dev/null | grep -v '^#' | grep -v '^\$' | head -30 > $OUT/perf_${name}_dso.txt
    perf report -i /tmp/perf_$name.data --stdio --children --sort symbol -g none --percent-limit 1 2>/dev/null | grep -v '^#' | grep -v '^\$' | head -120 > $OUT/perf_${name}_incl.txt
    cp /tmp/perf_$name.data $OUT/
    if [ $dwarf = 1 ]; then
      p=\$(pgrep -u \$USER '$pat' | head -1)
      perf record -q -F 199 --call-graph dwarf,16384 -p \$p -o $OUT/perf_${name}_dwarf.data -- sleep 2 >/dev/null 2>&1
    fi
  "
}

for st in $STAGES; do
  case $st in
  A)
    for rep in $(seq $REPS); do
      cs ctl_level pp:512 512000 "gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0" \
         "w:200 w:250 w:300 w:350 w:400 q:0.001 q:0.0005 q:0.0003"
      log "A REP $rep DONE"
    done ;;
  B)
    for rep in $(seq $REPS); do
      cs scope0_hi pp:512 512000 "gauss:100:1000:100 gauss:100:1000:2000" "w:250"
      cs scope1_hi pp:512 512000 "gauss:100:1000:100 gauss:100:1000:2000" "w:250" "--agg-scope=1"
      cs direct_hi off    512000 "gauss:100:1000:100 gauss:100:1000:2000" "w:250"
      cs scope0_lo pp:512 128000 "gauss:10:200:500" "w:50"
      cs scope1_lo pp:512 128000 "gauss:10:200:500" "w:50" "--agg-scope=1"
      cs direct_lo off    128000 "gauss:10:200:500" "w:50"
      log "B REP $rep DONE"
    done ;;
  C)
    log "perf: Charades sigma 100"
    ( export AGG=pp:512 END=4096000 WORKLOADS="gauss:100:1000:100" ARMS="w:250" EXTRA_ARGS="$P"
      RUNS=$OUT/perf_charades $S 1 $OUT/perf_charades.csv | grep -E " (ok|fail|stall) " ) &
    sp=$!; perf_node0 charades_s100 '^phold$' 6 4 1; wait $sp
    log "perf: Devastator sigma 100 (W 1000)"
    ( export RUNS=$OUT/perf_deva LPS_PER_RANK=128 START=15 LOOKAHEAD=100 MEAN=1000 SIGMA=100 END=4096000 CAP=60 AFFINITY=0 WINDOW=1000
      LABEL=perf_s100_w1000 bash $D/run_phold.sh $DB 4 | head -1 ) &
    sp=$!; perf_node0 deva_s100 '^phold-gauss' 3 3 0; wait $sp
    log "C DONE" ;;
  esac
done
log "DIAG1 DONE"
