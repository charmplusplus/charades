#!/bin/bash -l
#SBATCH -J ctlcost245
#SBATCH -t 00:50:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/ctlcost245_%j.out
# Job CC (charades RESULTS.md section 245): where the frozen controller's 3-7%
# against the best fixed W goes. Charades only, charades-r5 (85a2aad). PHOLD
# sigma 500 (F1's settings, PP 2,048) and traffic (F5's settings, PP 2,048,
# --commit-digest) at 16 nodes, then 1 node; 3 reps, arm order reversed in rep 2.
# Arms per cell:
#   F    fixed W grid (sigma 500: 200 300 400 600; traffic: 350 500 750 1000)
#   C    the controller (mb:0), as in F1 and F5
#   CL   C with --ctl-log=1
#   CPL  CL with --ctl-period=32 (a change of W every 34 rounds, not 10)
#   D    dry at the best fixed W (--ctl=3 --ctl-bracket=1 --ctl-dry=1)
#   DL   D with --ctl-log=1
# Twin guard: TWIN (environment) or the file $TWF names the same job queued
# elsewhere; the copy that starts first cancels it, one that starts second exits.
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 ctlcost245.slurm
#         sbatch -p skx -N 16 -n 768 -x c455-081 --export=ALL,TWIN=<that id> ctlcost245.slurm
#         then echo <skx id> > $TWF
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/f1_240/cc_j${SLURM_JOB_ID:-dry}; mkdir -p $OUT
TWF=$W/charades-runs/f1_240/ctlcost245.twin
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-r5; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}"
log "charades $(git -C $C log --oneline -1 | cut -c1-50)"
[ "$(git -C $C rev-parse --short=7 HEAD)" = 85a2aad ] || { log "$T not at 85a2aad"; exit 1; }
for b in $C/models/phold/simple/phold $C/models/traffic/traffic; do
  for s in ctl-reach-buckets "the base before and after" "PER-PE WITH A SHARED SPARE LIST" "keep the window fixed" "rounds per measured period"; do
    strings $b | grep -q "$s" || { log "$b lacks $s"; exit 1; }
  done
  ldd $b | grep -q charm-pads-perf/ || { log "$b does not link charm-pads-perf"; exit 1; }
done
grep -q "mb)   extra" $S || { log "ctl_sweep.sh lacks the mb arm"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }
TWIN=${TWIN:-$(cat $TWF 2>/dev/null)}
if [ -n "${TWIN:-}" ]; then
  st=$(squeue -h -j $TWIN -o %T 2>/dev/null)
  [ "$st" = PENDING ] || { log "twin $TWIN is ${st:-not queued}: exiting"; exit 0; }
  scancel $TWIN && log "twin $TWIN was pending: cancelled"
fi
[ ${#NL[@]} -ge 16 ] || { log "need 16 nodes"; exit 1; }

gate() { # output file
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
    python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" \
      agg_deadline_bucket_pp bucket_window agg_ctl_measured_bucket_pp ctl_measured_bucket > $1 2>&1 )
  tail -4 $1; grep -E "FAIL|TIMEOUT" $1 | head
  grep -q "Failed: *0/" $1 && grep -q "Timed out: *0/" $1 && grep -q "Passed: *[1-9]" $1; }
gate $OUT/gate.txt || { log "GATE FAILED"; exit 1; }
log "GATE DONE"

export TREE=$T LPC=16 PPN=2 PEPP=23 CPT=24 CAP=150
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
# workload: Charades workload, end, bucket, LPs per PE, launch flags, fixed W grid, best fixed W
spec() {
  case $1 in
    g500) CW=gauss:100:1000:500; END=2048000; BK=8; LPP=128; LW="$L"; GRID="w:200 w:300 w:400 w:600"
          [ $2 = 1 ] && WB=300 || WB=400 ;;
    tr)   CW=traffic:100:1000:64:16:0:0:3; END=12000000; BK=8; LPP=64; LW="$L --blocked-time=1 --commit-digest=1"
          GRID="w:350 w:500 w:750 w:1000"; WB=500 ;;
  esac; }
cs() { # tag nodes nodelist arms extra
  ( export NODES=$2 AGG=pp:2048 WORKLOADS="$CW" ARMS="$4" END=$END BUCKETS=$BK LPS_PER_PE=$LPP \
      EXTRA_ARGS="$LW ${5:-}" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" )
  rm -f $OUT/n$2/$1/ctl_sweep/logs/*.digest.csv $OUT/n$2/$1/ctl_sweep/gvt_*.out; }
DRY="--ctl=3 --ctl-bracket=1 --ctl-dry=1"
arm() { # name tag nodes nodelist
  case $1 in
    F)   cs $2_F $3 $4 "$GRID" ;;
    C)   cs $2_C $3 $4 mb:0 ;;
    CL)  cs $2_CL $3 $4 mb:0 "--ctl-log=1" ;;
    CPL) cs $2_CPL $3 $4 mb:0 "--ctl-log=1 --ctl-period=32" ;;
    D)   cs $2_D $3 $4 w:$WB "$DRY" ;;
    DL)  cs $2_DL $3 $4 w:$WB "$DRY --ctl-log=1" ;;
  esac; }
ARMS_ORDER="F C CL CPL D DL"
rev() { local x out=""; for x in "$@"; do out="$x $out"; done; echo $out; }
stream() { # nodes nodelist
  local N=$1 nl=$2 rep wl a order
  spec g500 $N; cs warm $N $nl w:300
  for rep in 1 2 3; do
    order=$ARMS_ORDER; [ $rep = 2 ] && order=$(rev $ARMS_ORDER)
    for wl in g500 tr; do
      spec $wl $N
      for a in $order; do arm $a ${wl}_r$rep $N $nl; done
    done
    log "N $N REP $rep DONE"
  done; }
stream 16 $(join ${NL[@]:0:16}) > $OUT/stream_n16.log 2>&1
log "16 DONE"
stream 1 ${NL[0]} > $OUT/stream_n1.log 2>&1
log "1 DONE"
log "CTLCOST245 DONE"
