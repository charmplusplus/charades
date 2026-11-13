#!/bin/bash
# Controller: aggregation bound (kappa), gated timers, alpha init (charades
# RESULTS.md "Controller: an aggregation bound, cheaper bookkeeping, a faster
# start", design 2026-10-23). Old build: charades-exp (fe3a4ac, the controller
# as shipped). New build: charades-ctl (7ad0f97). Full nodes: ctl_sweep.sh defaults.
# Usage: ctl2.sh [reps] [long reps]
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/ctl2; mkdir -p $OUT
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export NODES=4 LPS_PER_PE=128 LPC=16 CAP=120
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
REPS=${1:-3} LREPS=${2:-2}
log() { echo "[$(date +%T)] $*"; }

log "building charades-ctl"
cd $W/charades-ctl && source scripts/stampede3/env.sh >/dev/null 2>&1
( make -s -C src clean >/dev/null; make -s -C src && make -s -C models/phold/simple && make -s -C models/traffic ) > $OUT/build.log 2>&1 \
  || { tail -20 $OUT/build.log; exit 1; }
strings models/phold/simple/phold | grep -q ctl-agg-kappa || { echo "new build lacks --ctl-agg-kappa"; exit 1; }
log "built $(git log --oneline -1 | cut -c1-60)"

cs() { # tag tree agg end workloads arms extra
  ( export TREE=$2 AGG=$3 END=$4 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="$P $7"
    RUNS=$OUT/$1 $S 1 $OUT/$1_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
K="--ctl-agg-kappa"; FULL="--ctl-agg-kappa=0.17 --ctl-hist-waves=32 --ctl-alpha-init=0.003"
group() { # prefix agg end workloads anchors dryW kappa(yes/no)
  local p=$1 agg=$2 end=$3 wl="$4" anc="$5" dw=$6 kap=$7
  cs ${p}_anchor charades-ctl $agg $end "$wl" "$anc dry:$dw"
  cs ${p}_old charades-exp $agg $end "$wl" "q:0.001"
  cs ${p}_new charades-ctl $agg $end "$wl" "q:0.001"
  if [ $kap = yes ]; then
    cs ${p}_k13 charades-ctl $agg $end "$wl" "q:0.001" "$K=0.13"
    cs ${p}_k17 charades-ctl $agg $end "$wl" "q:0.001" "$K=0.17"
    cs ${p}_k22 charades-ctl $agg $end "$wl" "q:0.001" "$K=0.22"
  fi
  cs ${p}_full charades-ctl $agg $end "$wl" "q:0.001" "$FULL"
}
for rep in $(seq $REPS); do
  group hi pp:512 512000 "gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0" "w:200 w:250 w:300" 250 yes
  group lo pp:512 128000 "gauss:10:200:500 gauss:10:200:2000 steady:10:200:1.0" "w:25 w:50 w:100" 50 yes
  group ph pp:512 256000 "phases:10:200:100:1000:1.0:32000 phases:10:200:100:1000:0.5:32000" "w:50 w:100" 100 yes
  group tr pp:512 512000 "traffic:100:1000:128:15:0:0 traffic:100:1000:128:15:0.5:32" "w:250 w:500" 500 yes
  group dhi off 512000 "gauss:100:1000:2000 steady:100:1000:1.0" "w:250 w:500" 500 no
  group dlo off 128000 "steady:10:200:1.0" "w:50 w:100" 100 no
  log "REP $rep DONE"
done
for rep in $(seq $LREPS); do
  WL="gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0"
  cs long_anchor charades-ctl pp:512 4096000 "$WL" "w:250 w:300"
  cs long_old charades-exp pp:512 4096000 "$WL" "q:0.001"
  cs long_full charades-ctl pp:512 4096000 "$WL" "q:0.001" "$FULL"
  log "LONG REP $rep DONE"
done
log "CTL2 DONE"
