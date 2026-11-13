#!/bin/bash -l
#SBATCH -J f4227
#SBATCH -t 01:50:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/f4227_%j.out
# Job F4 (charades RESULTS.md section 227): robustness of the window policies
# on job N's seven workloads (section 182) at 4 and 16 nodes, each engine on
# its own fixed-W grid in the same allocation:
#   Charades (tree charades-f3 = charades 8a34d51, round 3, on charm-pads-perf):
#     fixed W grid; the frozen controller (mb:0, --ctl=3 bracketed); Devastator's
#     rule in Charades (hill:<bucket>, --ctl=2 from one bucket, its smallest W)
#   Devastator 2 x 23 (--rng=clcg4): fixed W grid; its own adaptive window
#   Workloads, sizes and htram settings as in job N:
#     phases  phase-changing PHOLD (10/200 and 100/1,000 every 8,000; remote 0.5), PP 512
#     la10    lookahead 10 / mean 200, sigma 500, PP 512
#     g100    sigma 100, PP 2,048;  g2000 sigma 2,000, PP 512;  uni uniform, WPs 512
#     tr      traffic (64 x 46N, 16 cars per intersection, trip radius 3), PP 2,048
#     df      dragonfly (16/10 at 4 nodes, 28/14 at 16; arrival 500, generating 150,000), WPs 512
#   2 reps, arm order reversed in rep 2.
#   1. gate, 2 nodes: change tier (Simple PHOLD, traffic, dragonfly)
#   2. 4 nodes, four streams side by side: Charades A (phases la10 g100 g2000),
#      Charades B (uni tr df), Devastator A, Devastator B, on nodes 0-3, 4-7,
#      8-11, 12-15
#   3. 16 nodes: Charades, then Devastator, per rep. Devastator's adaptive window
#      and Charades' hill climb run at 16 nodes only for workloads where every
#      4-node run of that arm finished.
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 f4227.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/f4227/j${SLURM_JOB_ID:-dry}; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-f3; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh; D=$W/devastator; DB=$D/bin/ofi-psm2
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}"
[ "$(git -C $C rev-parse --short=7 HEAD)" = 8a34d51 ] || { log "$T not at 8a34d51"; exit 1; }
grep -q "mb)   extra" $S && grep -q "hill) extra" $S || { log "ctl_sweep.sh lacks the mb or hill arm"; exit 1; }
for b in $C/models/phold/simple/phold $C/models/traffic/traffic $C/models/dragonfly/dragonfly; do
  [ -x $b ] || { log "missing $b"; exit 1; }
  [ $b -nt $C/src/gvt/bucketed.C ] || { log "$b is older than bucketed.C"; exit 1; }
  strings $b | grep -q "the base before and after" || { log "$b lacks --ctl-bracket"; exit 1; }
  strings $b | grep -q "Commit Digest" || { log "$b lacks --commit-digest"; exit 1; }
  strings $b | grep -q "PER-PE WITH A SHARED SPARE LIST" || { log "$b is not round 3"; exit 1; }
  ldd $b | grep -q "charm-pads-perf/" || { log "$b does not link charm-pads-perf"; exit 1; }
done
for m in phold-gauss traffic dragonfly; do for p in 8 32; do
  [ -x $DB/$m-p${p}w23 ] || { log "missing $DB/$m-p${p}w23"; exit 1; }
done; done
strings $DB/phold-gauss-p8w23 | grep -q alt-lookahead || { log "phold-gauss lacks phases"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }

# ---- 1. gate
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" --model Traffic --model Dragonfly \
    ctl_hill agg_ctl_measured_bucket_pp bucket_window > $OUT/gate.txt 2>&1 )
tail -3 $OUT/gate.txt
grep -q "Failed: *0/" $OUT/gate.txt && grep -q "Timed out: *0/" $OUT/gate.txt || { log "GATE FAILED"; exit 1; }
log "GATE DONE"

export TREE=$T PPN=2 PEPP=23 CPT=24 CAP=180 LPC=16 START=15
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1 --commit-digest=1"
CAPD=120
cs() { # tag nodes nodelist agg workload arms end bucket lps_per_pe
  ( export NODES=$2 AGG=$4 WORKLOADS="$5" ARMS="$6" END=$7 BUCKETS=$8 LPS_PER_PE=$9 EXTRA_ARGS="$L" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" ); }
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
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
    phases) echo "phold-gauss|$P --lookahead=10 --mean=200 --sigma=0 --remote=0.5 --phase-length=8000 --alt-lookahead=100 --alt-mean=1000 --alt-remote=0.5 --end-time=1024000|100 250 500" ;;
    la10)   echo "phold-gauss|$P --lookahead=10 --mean=200 --sigma=500 --end-time=512000|100 200 400" ;;
    g100)   echo "phold-gauss|$P --lookahead=100 --mean=1000 --sigma=100 --end-time=2048000|500 1000 2000 4000" ;;
    g2000)  echo "phold-gauss|$P --lookahead=100 --mean=1000 --sigma=2000 --end-time=2048000|500 1000 2000" ;;
    uni)    echo "phold-gauss|$P --lookahead=100 --mean=1000 --sigma=0 --remote=1.0 --end-time=2048000|250 500 1000 2000" ;;
    tr)     echo "traffic|--num-x=64 --num-y=$((46 * n)) --total-cars=$((46 * n * 64 * 16)) --lookahead=100 --mean=1000 --trip-radius=3 --end-time=6000000 --rng=clcg4|1000 2000 4000" ;;
    df)     echo "dragonfly|--routers-per-group=$1 --global-channels=$2 --terminals-per-router=4 --traffic=1 --routing=0 --arrive-rate=500 --gen-time=150000 --end-time=160000000 --rng=clcg4|10000 20000 40000" ;;
  esac; }
# a 4-node arm that did not finish in every rep: skip it at 16 nodes
unfinished4() { [ -e $OUT/n4/unfinished_$1 ]; }
charades() { # workload nodes nodelist rep
  local wl=$1 N=$2 nl=$3 rep=$4 spec fixed agg cw end bk lps arms
  spec=$(cspec $wl $N); fixed=${spec#*|}; read -r agg cw end bk lps <<< "${spec%%|*}"
  arms="$fixed mb:0"
  if [ $N = 16 ] && unfinished4 c_${wl}_hill; then echo "n$N ${wl} hill skipped: not every 4-node run finished"
  else arms="$arms hill:$bk"; fi
  [ $rep = 2 ] && arms=$(rev "$arms")
  cs ${wl}_r$rep $N $nl $agg $cw "$arms" $end $bk $lps
  if [ $N = 4 ] && awk -F, 'NR > 1 && $10 ~ /^hill:/ && $11 != "ok" {bad = 1} END {exit !bad}' $OUT/n4/${wl}_r$rep.csv; then
    touch $OUT/n4/unfinished_c_${wl}_hill; fi; }
dv() { # workload nodes nodelist window|adaptive rep
  local wl=$1 N=$2 nl=$3 w=$4 rep=$5 spec m args f
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
    [ $N = 4 ] && [ $st != ok ] && touch $OUT/n4/unfinished_d_${wl}_$w
    echo "engine=deva wl=$wl nodes=$N rep=$rep window=$w status=$st rc=$rc wall=$wall committed=$(v committed) executed=$(v executed) rolled_back=$(v rolled_back) efficiency=$(v efficiency) run_s=$(v wall_s) M_ev_s=$(awk -v r="$(v committed_per_s)" 'BEGIN{if (r != "") printf "%.2f", r / 1e6}') window_mean=$(v window_mean) window_last=$(v window_last) deterministic=$(v deterministic)" \
      | tee -a $OUT/deva.txt | sed "s/^/n$N /" | cut -c1-200 ) ; }
devastator() { # workload nodes nodelist rep
  local wl=$1 N=$2 nl=$3 rep=$4 spec ws w
  spec=$(dspec $wl $N); ws="${spec##*|} adaptive"
  [ $rep = 2 ] && ws=$(rev "$ws")
  for w in $ws; do
    if [ $N = 16 ] && unfinished4 d_${wl}_$w; then echo "n$N dv $wl W $w skipped: not every 4-node run finished"; continue; fi
    dv $wl $N $nl $w $rep
  done; }
series() { # engine nodes nodelist workloads...
  local e=$1 N=$2 nl=$3 rep wl; shift 3
  for rep in 1 2; do
    for wl in $([ $rep = 1 ] && echo "$@" || rev "$*"); do $e $wl $N $nl $rep; done
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
for rep in 1 2; do
  for e in $([ $rep = 1 ] && echo "charades devastator" || echo "devastator charades"); do
    for wl in $([ $rep = 1 ] && echo $WLS || rev "$WLS"); do $e $wl 16 $N16 $rep; done
  done >> $OUT/stream_16.log 2>&1
  log "n16 REP $rep DONE"
done
log "16-NODE PHASE DONE"
grep -h -E ' (fail|stall) |status=(fail|stall)|skipped' $OUT/stream_*.log | head -40
log "F4227 DONE"
