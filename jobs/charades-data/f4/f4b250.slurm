#!/bin/bash -l
#SBATCH -J f4b250
#SBATCH -t 01:55:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/f4b250_%j.out
# Job F4b (charades results/controller.md section 250): F4 (sections 227, 230)
# rerun without diagnostics. F4 passed --blocked-time=1 --ctl-log=1
# --commit-digest=1 to every Charades arm; the log printed only in the
# controller and hill-climb arms and cost them 2-6% (section 246).
# The same plan as F4: robustness of the window policies on job N's seven
# workloads (section 182) at 4 and 16 nodes, each engine on its own fixed-W
# grid in the same allocation:
#   Charades (tree charades-r5 = charades 85a2aad; F4 ran 8a34d51, and the code
#     between them changes no default except --ctl-reach-buckets=2, which moves
#     no trial on these workloads; numactl --localalloc as before):
#     fixed W grid; the frozen controller (mb:0, --ctl=3 bracketed); Devastator's
#     rule in Charades (hill:<bucket>, --ctl=2 from one bucket)
#   Devastator 2 x 23 (--rng=clcg4): fixed W grid; its own adaptive window
#   Workloads, sizes and htram settings as in F4 (cspec, dspec below).
# Changes from F4:
#   - Timing arms carry the paper launch only (section 247).
#   - Check arm "old", every rep: the controller with F4's three flags, for
#     the digest check (one digest per cell, as F4's) and their cost.
#   - 3 reps (F4: 2); arm and workload order reversed in rep 2.
#   - A Devastator window or Charades hill climb that hits its cap (or, at
#     16 nodes, that hit it at 4 nodes) is skipped after; F4's adaptive window
#     stalled in both reps on phases and g2000 at 4 nodes.
#   - A short warm-up run starts each stream (not counted).
#   1. gate, 2 nodes: change tier (Simple PHOLD, traffic, dragonfly)
#   2. 4 nodes, four streams side by side: Charades A (phases la10 g100 g2000),
#      Charades B (uni tr df), Devastator A, Devastator B, on nodes 0-3, 4-7,
#      8-11, 12-15
#   3. 16 nodes: Charades, then Devastator, per rep (Devastator first in rep 2)
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 f4b250.slurm, and an skx
# copy with --export=ALL,TWIN=<skx-dev id>; then write the skx id to $TWF.
# STUB=1 (login node, with a fake srun first in PATH): print every command, no gate.
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
STUB=${STUB:-0}
OUT=$W/charades-runs/f4b250/j${SLURM_JOB_ID:-dry}; [ $STUB = 1 ] && OUT=$W/charades-runs/f4b250/stub
mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
[ $STUB = 1 ] && export PATH=$W/charades-runs/f4b250/stubbin:$PATH   # its srun appends its command line to $STUBLOG
T=charades-r5; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh; D=$W/devastator; DB=$D/bin/ofi-psm2
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}"
log "charades $(git -C $C log --oneline -1 | cut -c1-60); devastator $(git -C $D/devastator log --oneline -1 2>/dev/null | cut -c1-20)"
[ "$(git -C $C rev-parse --short=7 HEAD)" = 85a2aad ] || { log "$T not at 85a2aad"; exit 1; }
grep -q "mb)   extra" $S && grep -q "hill) extra" $S || { log "ctl_sweep.sh lacks the mb or hill arm"; exit 1; }
for b in $C/models/phold/simple/phold $C/models/traffic/traffic $C/models/dragonfly/dragonfly; do
  [ -x $b ] || { log "missing $b"; exit 1; }
  strings $b | grep -q "the base before and after" || { log "$b lacks --ctl-bracket"; exit 1; }
  strings $b | grep -q "ctl-reach-buckets" || { log "$b lacks --ctl-reach-buckets"; exit 1; }
  strings $b | grep -q "Commit Digest" || { log "$b lacks --commit-digest"; exit 1; }
  strings $b | grep -q "PER-PE WITH A SHARED SPARE LIST" || { log "$b is not round 3"; exit 1; }
  ldd $b | grep -q "charm-pads-perf/" || { log "$b does not link charm-pads-perf"; exit 1; }
done
for m in phold-gauss traffic dragonfly; do for p in 8 32; do
  [ -x $DB/$m-p${p}w23 ] || { log "missing $DB/$m-p${p}w23"; exit 1; }
done; done
strings $DB/phold-gauss-p8w23 | grep -q alt-lookahead || { log "phold-gauss lacks phases"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }
if [ $STUB = 0 ]; then
# TWIN (sbatch --export=ALL,TWIN=<job id>): the same job queued elsewhere. The
# copy that starts first runs and cancels the other; one that starts second exits.
# The first-submitted copy reads the other's ID from $TWF, written after both.
TWF=$W/charades-runs/f4b250/f4b250.twin
TWIN=${TWIN:-$(cat $TWF 2>/dev/null)}
if [ -n "${TWIN:-}" ]; then
  st=$(squeue -h -j $TWIN -o %T 2>/dev/null)
  [ "$st" = PENDING ] || { log "twin $TWIN is ${st:-not queued}: exiting"; exit 0; }
  scancel $TWIN && log "twin $TWIN was pending: cancelled"
fi

# ---- 1. gate (a rerun if the only failures are /work2 read errors)
gate() { # output file
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
    python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" --model Traffic --model Dragonfly \
      ctl_hill agg_ctl_measured_bucket_pp bucket_window > $1 2>&1 )
  tail -3 $1; grep -E "FAIL|TIMEOUT" $1 | head
  grep -q "Failed: *0/" $1 && grep -q "Timed out: *0/" $1 && grep -q "Passed: *[1-9]" $1; }
if ! gate $OUT/gate.txt; then
  bad=$(grep -E "FAIL|TIMEOUT" $OUT/gate.txt | awk '{print $NF}' | grep "test.out$")
  if [ -n "$bad" ] && [ -z "$(for f in $bad; do grep -L "Input/output error" $f; done)" ]; then
    log "GATE: /work2 read errors only; rerunning"
    gate $OUT/gate2.txt || { log "GATE FAILED"; exit 1; }
  else log "GATE FAILED"; exit 1; fi
fi
log "GATE DONE"
fi

export TREE=$T PPN=2 PEPP=23 CPT=24 CAP=180 LPC=16 START=15
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
OLD="--blocked-time=1 --ctl-log=1 --commit-digest=1"   # F4's flags: check arm only
CAPD=120
cs() { # tag nodes nodelist agg workload arms end bucket lps_per_pe [extra Charades flags]
  ( export NODES=$2 AGG=$4 WORKLOADS="$5" ARMS="$6" END=$7 BUCKETS=$8 LPS_PER_PE=$9 \
      EXTRA_ARGS="$L ${10:-}" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" )
  rm -f $OUT/n$2/$1/ctl_sweep/logs/*.digest.csv $OUT/n$2/$1/ctl_sweep/gvt_*.out; }
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
ord() { [ $(($2 % 2)) = 1 ] && echo "$1" || rev "$1"; }   # list rep: reversed in even reps
# workload -> Charades: agg spec end bucket lps; fixed-W arms. Devastator: model args; W grid
cspec() { # workload nodes
  local df=16:10; [ $2 = 16 ] && df=28:14
  case $1 in
    phases) echo "pp:512 phases:10:200:100:1000:0.5:8000 1024000 8 128|w:50 w:75 w:100 w:150 w:250 w:300" ;;
    la10)   echo "pp:512 gauss:10:200:500 512000 8 128|w:25 w:50 w:100 w:300" ;;
    g100)   echo "pp:2048 gauss:100:1000:100 2048000 8 128|w:100 w:200 w:300 w:400" ;;
    g2000)  echo "pp:512 gauss:100:1000:2000 2048000 8 128|w:100 w:200 w:300 w:400" ;;
    uni)    echo "wps:512 steady:100:1000:1.0 2048000 8 128|w:100 w:200 w:300 w:400" ;;
    tr)     echo "pp:2048 traffic:100:1000:64:16:0:0:3 6000000 8 64|w:500 w:750 w:1000" ;;
    df)     echo "wps:512 dragonfly:$df:4:1:500:150000 160000000 1000 128|w:10000 w:20000 w:40000" ;;
  esac; }
dspec() { # workload nodes -> model|args|W grid
  local wl=$1 n=$2 s="16 10"; [ $n = 16 ] && s="28 14"; set -- $s
  local P="--lp-per-rank=128 --start-events=15 --rng=clcg4"
  case $wl in
    warm)   echo "phold-gauss|$P --lookahead=100 --mean=1000 --sigma=100 --end-time=512000|1000" ;;
    phases) echo "phold-gauss|$P --lookahead=10 --mean=200 --sigma=0 --remote=0.5 --phase-length=8000 --alt-lookahead=100 --alt-mean=1000 --alt-remote=0.5 --end-time=1024000|100 250 500" ;;
    la10)   echo "phold-gauss|$P --lookahead=10 --mean=200 --sigma=500 --end-time=512000|100 200 400" ;;
    g100)   echo "phold-gauss|$P --lookahead=100 --mean=1000 --sigma=100 --end-time=2048000|500 1000 2000 4000" ;;
    g2000)  echo "phold-gauss|$P --lookahead=100 --mean=1000 --sigma=2000 --end-time=2048000|500 1000 2000" ;;
    uni)    echo "phold-gauss|$P --lookahead=100 --mean=1000 --sigma=0 --remote=1.0 --end-time=2048000|250 500 1000 2000" ;;
    tr)     echo "traffic|--num-x=64 --num-y=$((46 * n)) --total-cars=$((46 * n * 64 * 16)) --lookahead=100 --mean=1000 --trip-radius=3 --end-time=6000000 --rng=clcg4|1000 2000 4000" ;;
    df)     echo "dragonfly|--routers-per-group=$1 --global-channels=$2 --terminals-per-router=4 --traffic=1 --routing=0 --arrive-rate=500 --gen-time=150000 --end-time=160000000 --rng=clcg4|10000 20000 40000" ;;
  esac; }
# an arm that hit its cap: skipped in later reps, and at 16 nodes if it hit it at 4
capped() { [ -e $OUT/capped_$1 ]; }
charades() { # workload nodes nodelist rep
  local wl=$1 N=$2 nl=$3 rep=$4 spec fixed agg cw end bk lps arms
  spec=$(cspec $wl $N); fixed=${spec#*|}; read -r agg cw end bk lps <<< "${spec%%|*}"
  arms="$fixed mb:0"
  if capped c_${wl}_hill; then echo "n$N ${wl} r$rep hill skipped: it hit its cap before"
  else arms="$arms hill:$bk"; fi
  cs ${wl}_r$rep $N $nl $agg $cw "$(ord "$arms" $rep)" $end $bk $lps
  awk -F, 'NR > 1 && $10 ~ /^hill:/ && $11 == "stall" {s = 1} END {exit !s}' $OUT/n$N/${wl}_r$rep.csv && touch $OUT/capped_c_${wl}_hill
  cs ${wl}_old_r$rep $N $nl $agg $cw mb:0 $end $bk $lps "$OLD"; }
dv() { # workload nodes nodelist window|adaptive rep
  local wl=$1 N=$2 nl=$3 w=$4 rep=$5 spec m args f res=$OUT/deva.txt
  [ $wl = warm ] && res=$OUT/deva_warm.txt
  spec=$(dspec $wl $N); m=${spec%%|*}; args=${spec#*|}; args=${args%|*}
  f=$OUT/n$N/deva/${wl}_w${w}_r$rep.out; mkdir -p $OUT/n$N/deva
  ( export GASNET_BACKTRACE=1 GASNET_OFI_SPAWNER=pmi FI_PROVIDER=psm2; unset FI_PROVIDER_PATH
    if [ $w = adaptive ]; then unset deva_static_look_dt; else export deva_static_look_dt=$w; fi
    t0=$(date +%s.%N)
    timeout -s TERM $CAPD srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -J dv_${wl}_n$N -w $nl -N $N -n $((2 * N)) \
      --ntasks-per-node=2 -c 24 --cpu-bind=cores -m block:block \
      stdbuf -oL $DB/$m-p$((2 * N))w23 $args > $f 2>&1
    rc=$?; wall=$(printf %.1f "$(echo "$(date +%s.%N) - $t0" | bc)")
    line=$(grep -m1 -E '^(PHOLD_GAUSS|TRAFFIC|DRAGONFLY)_RESULT' $f)
    v() { tr ' ' '\n' <<< "$line" | sed -n "s/^$1=//p"; }
    st=ok; [ -z "$line" ] && st=fail; [ $rc = 124 ] && st=stall
    [ $st = stall ] && touch $OUT/capped_d_${wl}_$w
    echo "engine=deva wl=$wl nodes=$N rep=$rep window=$w status=$st rc=$rc wall=$wall committed=$(v committed) executed=$(v executed) rolled_back=$(v rolled_back) efficiency=$(v efficiency) run_s=$(v wall_s) M_ev_s=$(awk -v r="$(v committed_per_s)" 'BEGIN{if (r != "") printf "%.2f", r / 1e6}') window_mean=$(v window_mean) window_last=$(v window_last) deterministic=$(v deterministic)" \
      | tee -a $res | sed "s/^/n$N /" | cut -c1-200 ) ; }
devastator() { # workload nodes nodelist rep
  local wl=$1 N=$2 nl=$3 rep=$4 spec w
  spec=$(dspec $wl $N)
  for w in $(ord "${spec##*|} adaptive" $rep); do
    if capped d_${wl}_$w; then echo "n$N dv $wl W $w r$rep skipped: it hit its cap before"; continue; fi
    dv $wl $N $nl $w $rep
  done; }
warm() { # engine nodes nodelist
  if [ $1 = charades ]; then cs warm $2 $3 pp:2048 gauss:100:1000:100 w:300 512000 8 128
  else dv warm $2 $3 1000 0; fi; }
series() { # engine nodes nodelist workloads...
  local e=$1 N=$2 nl=$3 rep wl; shift 3
  warm $e $N $nl
  for rep in 1 2 3; do
    for wl in $(ord "$*" $rep); do $e $wl $N $nl $rep; done
    log "n$N $e $* REP $rep DONE"
  done; }

# ---- 2. 4 nodes, side by side
series charades 4 $(join ${NL[@]:0:4}) phases la10 g100 g2000 > $OUT/stream_ca4.log 2>&1 &
series charades 4 $(join ${NL[@]:4:4}) uni tr df > $OUT/stream_cb4.log 2>&1 &
series devastator 4 $(join ${NL[@]:8:4}) phases la10 g100 g2000 > $OUT/stream_da4.log 2>&1 &
series devastator 4 $(join ${NL[@]:12:4}) uni tr df > $OUT/stream_db4.log 2>&1 &
wait
log "4-NODE PHASE DONE"

# ---- 3. 16 nodes: per rep, Charades then Devastator (Devastator first in rep 2)
N16=$(join ${NL[@]:0:16}); WLS="phases la10 g100 g2000 uni tr df"
{ warm charades 16 $N16; warm devastator 16 $N16; } >> $OUT/stream_16.log 2>&1
for rep in 1 2 3; do
  for e in $(ord "charades devastator" $rep); do
    for wl in $(ord "$WLS" $rep); do $e $wl 16 $N16 $rep; done
  done >> $OUT/stream_16.log 2>&1
  log "n16 REP $rep DONE"
done
log "16-NODE PHASE DONE"
grep -h -E ' (fail|stall) |status=(fail|stall)|skipped' $OUT/stream_*.log | head -40
log "F4B250 DONE"
