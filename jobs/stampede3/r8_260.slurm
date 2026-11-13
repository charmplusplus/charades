#!/bin/bash -l
#SBATCH -J r8_260
#SBATCH -t 01:58:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/r8_260_%j.out
# Job R8 (charades results/phold.md section 260; user decision 2026-11-08:
# rerun the 8-node columns). Job GC (section 259) found that a run on node 0
# (the batch host, which runs every stream's srun clients and polling loops)
# is slowed while several streams run side by side, Devastator more than
# Charades; F1's and F5's 8-node streams ran on nodes 0-7 beside three other
# streams. This job reruns, with node 0 left idle:
#   S8 (nodes 1-8): F1's 8-node column (scale240.slurm: eight PHOLD workloads
#     and sigma 1,000 with PP 512, Charades / Devastator / ROSS, F1's arms) and
#     F5's (f5scale240.slurm: dragonfly and traffic, the three engines, F5's
#     timing arms; F5's check arms od, dg, ri are left out); 3 reps
#   S1 (node 9, beside S8; 1-node runs do not use the network): GC's four
#     1-node cells that ran on node 0 (gc258.slurm part D: sigma 100, 500,
#     1,000, 2,000; Devastator's finer grid and Charades' controller); 5 reps
#   then a check (nodes 1-8): uniform at 8 nodes, Devastator W 500 and 1,000
#     and Charades' controller (PP 512), alone and with load streams on nodes
#     9-14 (Devastator uniform at 4 nodes, Charades uniform at 2 nodes, run in
#     loops), alternating per rep; 3 reps; skipped if less than 18 minutes remain
# Tree charades-r5 (85a2aad); no diagnostics in any command.
# Submit the skx copy first: sbatch -p skx -N 15 -n 720 -x c455-081 r8_260.slurm;
# then the skx-dev copy with --export=ALL,TWIN=<skx id>; then write the
# skx-dev id to $TWF.
# STUB=1 (login node, fake srun first in PATH, SLURM_JOB_ID and
# SLURM_JOB_NODELIST set): print every command, no gate.
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
STUB=${STUB:-0}
OUT=$W/charades-runs/r8_260/j${SLURM_JOB_ID:-dry}; [ $STUB = 1 ] && OUT=$W/charades-runs/r8_260/stub
mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
[ $STUB = 1 ] && export PATH=$W/charades-runs/f4b250/stubbin:$PATH   # its srun appends its command line to $STUBLOG
T=charades-r5; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh; D=$W/devastator; DB=$D/bin/ofi-psm2; RP=$D/run_phold.sh
RBP=$W/ROSS/build/models/phold-gauss/phold-gauss; RBM=$W/ROSS/build/models
RWF=$W/charades-runs/f1_240/ross_windows.txt
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}; node 0 (${NL[0]:-}) stays idle"
log "charades $(git -C $C log --oneline -1 | cut -c1-60); ROSS $(git -C $W/ROSS log --oneline -1 | cut -c1-20)"
[ "$(git -C $C rev-parse --short=7 HEAD)" = 85a2aad ] || { log "$T not at 85a2aad"; exit 1; }
grep -q "mb)   extra" $S || { log "ctl_sweep.sh lacks the mb arm"; exit 1; }
for b in $C/models/phold/simple/phold $C/models/traffic/traffic $C/models/dragonfly/dragonfly; do
  [ -x $b ] || { log "missing $b"; exit 1; }
  for s in ctl-reach-buckets "the base before and after" "PER-PE WITH A SHARED SPARE LIST"; do
    strings $b | grep -q "$s" || { log "$b lacks $s"; exit 1; }
  done
  ldd $b | grep -q charm-pads-perf/ || { log "$b does not link charm-pads-perf"; exit 1; }
done
for b in $DB/phold-gauss-p{2,4,8,16}w23 $DB/{traffic,dragonfly}-p16w23 $RBM/traffic/traffic $RBM/dragonfly/dragonfly; do
  [ -x $b ] || { log "missing $b"; exit 1; }
done
[ -x $RBP ] && strings $RBP | grep -q max-opt-lookahead || { log "ROSS phold-gauss missing or lacks --max-opt-lookahead"; exit 1; }
[ -f $RP ] && [ -f $RWF ] || { log "missing $RP or $RWF"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }

if [ $STUB = 1 ]; then
  # run_phold.sh refuses login nodes; the stub runs a copy without that one check
  sed '/not on a login node/d' $RP > $OUT/run_phold_stub.sh; RP=$OUT/run_phold_stub.sh
else
# TWIN (sbatch --export=ALL,TWIN=<job id>): the same job queued elsewhere. The
# copy that starts first runs and cancels the other; one that starts second exits.
# The first-submitted copy reads the other's ID from $TWF, written after both.
TWF=$W/charades-runs/r8_260/r8_260.twin
TWIN=${TWIN:-$(cat $TWF 2>/dev/null)}
if [ -n "${TWIN:-}" ]; then
  st=$(squeue -h -j $TWIN -o %T 2>/dev/null)
  [ "$st" = PENDING ] || { log "twin $TWIN is ${st:-not queued}: exiting"; exit 0; }
  scancel $TWIN && log "twin $TWIN was pending: cancelled"
fi
gate() { # output file
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
    python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" --model Traffic --model Dragonfly \
      bucket_window agg_ctl_measured_bucket_pp agg_inputbuf_bucket_wps > $1 2>&1 )
  tail -4 $1; grep -E "FAIL|TIMEOUT" $1 | head
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

export TREE=$T PPN=2 PEPP=23 CPT=24 LPC=16 START=15
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
cs() { # tag nodes nodelist agg workload arms end bucket lps_per_pe cap
  ( export NODES=$2 AGG=$4 WORKLOADS="$5" ARMS="$6" END=$7 BUCKETS=$8 LPS_PER_PE=$9 CAP=${10} \
      EXTRA_ARGS="$L" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" )
  rm -f $OUT/n$2/$1/ctl_sweep/logs/*.digest.csv $OUT/n$2/$1/ctl_sweep/gvt_*.out; }
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
ord() { [ $(($2 % 2)) = 1 ] && echo "$1" || rev "$1"; }   # list rep: reversed in even reps

# ---- F1 (scale240.slurm): spec, Devastator through run_phold.sh, ROSS
f1spec() {
  ARMS="mb:0 w:300 w:400"; DW="500 1000 2000"; RWD="1000 2000"; LA=100; MEAN=1000; REM=0; END=2048000; CH_ONLY=0
  case $1 in
    g100)  CW=gauss:100:1000:100;  AGGS="pp:2048"; SIG=100 ;;
    g500)  CW=gauss:100:1000:500;  AGGS="pp:2048"; SIG=500 ;;
    g1000) CW=gauss:100:1000:1000; AGGS="pp:2048"; SIG=1000 ;;
    g1000x) CW=gauss:100:1000:1000; AGGS="pp:512"; SIG=1000; CH_ONLY=1 ;;
    g2000) CW=gauss:100:1000:2000; AGGS="pp:512";  SIG=2000 ;;
    g4000) CW=gauss:100:1000:4000; AGGS="pp:512";  SIG=4000 ;;
    uni)   CW=steady:100:1000:1.0; AGGS="pp:512 wps:512"; SIG=0; REM=1.0 ;;
    l10g500)  CW=gauss:10:200:500;  AGGS="pp:2048"; SIG=500;  LA=10; MEAN=200; END=512000; ARMS="mb:0 w:50 w:100"; DW="100 200 400"; RWD="200 400" ;;
    l10g2000) CW=gauss:10:200:2000; AGGS="pp:512 wps:512"; SIG=2000; LA=10; MEAN=200; END=512000; ARMS="mb:0 w:50 w:100"; DW="100 200 400"; RWD="200 400" ;;
  esac; }
f1dv() { # tag nodes nodelist window runs_subdir
  local db=$DB/phold-gauss-p$(($2 * 2))w23 extra=()
  [ "$REM" != 0 ] && extra=(--remote=$REM)
  ( export WINDOW=$4 RUNS=$OUT/n$2/${5:-deva} LPS_PER_RANK=128 START=15 LOOKAHEAD=$LA MEAN=$MEAN SIGMA=$SIG END=$END CAP=200 AFFINITY=0 SRUN_EXTRA="-w $3"
    LABEL=$1 bash $RP $db $2 --rng=clcg4 "${extra[@]}" | head -1 | sed "s/^/n$2 /" | cut -c1-120 ); }
f1ross() { # tag nodes nodelist synch batch gvt_interval max_opt_lookahead (0 = none)
  local n=$(($2 * 46)) f=$OUT/n$2/ross/$1.out mo=""; mkdir -p $OUT/n$2/ross
  [ $7 != 0 ] && mo="--max-opt-lookahead=$7"
  ( module load mvapich/3.0 >/dev/null 2>&1
    unset FI_PROVIDER FI_PROVIDER_PATH LCI_ATTR_BACKEND LCI_ATTR_OFI_PROVIDER_NAME LCI_ATTR_PACKET_SIZE PSM2_MULTI_EP
    timeout -s TERM 360 srun --mpi=pmi2 --kill-on-bad-exit=1 -J ross_$1 -w $3 -N $2 -n $n --ntasks-per-node=46 \
      $RBP --synch=$4 --read-buffer=1 --start-events=15 --sigma=$SIG --remote=$REM \
      --extramem=800000 --num-lps=$((n * 128)) --lookahead=$LA --mean=$MEAN --end=$END \
      --batch=$5 --gvt-interval=$6 $mo > $f 2>&1
    local rc=$?
    echo "label=$1 nodes=$2 synch=$4 batch=$5 gvt_interval=$6 window=$7 rc=$rc committed=$(awk '/Net Events Processed/{print $NF; exit}' $f) M_ev_s=$(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' $f) efficiency=$(awk '/Efficiency/{print $(NF-1); exit}' $f) running_s=$(awk '/Running Time/{print $(NF-1); exit}' $f)" | tee -a $OUT/n$2/ross/results.txt | sed "s/^/n$2 /" )
}
rwin() { local w=$(awk -v k=$1 '$1 == k {print $2}' $RWF 2>/dev/null); if [ -n "$w" ]; then echo $w; else echo "$RWD"; fi; }
f1cell() { # workload nodes nodelist rep (F1's stream body, one workload)
  local wl=$1 N=$2 nl=$3 rep=$4 a w
  f1spec $wl
  for a in $AGGS; do cs ${wl}_${a/:/}_r$rep $N $nl $a $CW "$ARMS" $END 8 128 150; done
  [ $CH_ONLY = 1 ] && return
  for w in $DW; do f1dv ${wl}_w${w}_r$rep $N $nl $w; done
  f1ross ${wl}_opt_r$rep $N $nl 3 16 64 0
  f1ross ${wl}_cons_r$rep $N $nl 2 16 16 0
  for w in $(rwin ${wl%x}); do [ $w != 0 ] && f1ross ${wl}_optw${w}_r$rep $N $nl 3 16 64 $w; done; }

# ---- F5 (f5scale240.slurm): timing arms only
ENGINES="charades devastator ross"
ROSS_DF="w2500:3:2:64:2500 w5000:3:2:64:5000 w7500:3:2:64:7500"
ROSS_TR="w1000:3:64:64:1000 w2000:3:64:64:2000 cons:2:16:16:0"
TR_END=12000000 DF_END=310000000 DF_GEN=300000 CAPX=300
shape() { case $1 in 1) echo "13 4" ;; 2) echo "15 6" ;; 4) echo "16 10" ;; 8) echo "22 12" ;; 16) echo "28 14" ;; 32) echo "36 18" ;; esac; }
margs() { # model nodes
  if [ $1 = traffic ]; then
    echo "--num-x=64 --num-y=$((46 * $2)) --total-cars=$((46 * $2 * 64 * 16)) --lookahead=100 --mean=1000 --trip-radius=3"
  else
    set -- $(shape $2)
    echo "--routers-per-group=$1 --global-channels=$2 --terminals-per-router=4 --traffic=1 --routing=0 --arrive-rate=500 --gen-time=$DF_GEN"
  fi; }
f5dv() { # tag nodes nodelist model window rep
  local tag=$1 N=$2 nl=$3 m=$4 w=$5 rep=$6 f=$OUT/n$2/deva_f5/$1_r$6.out end
  mkdir -p $OUT/n$N/deva_f5
  [ $m = traffic ] && end=$TR_END || end=$DF_END
  ( export GASNET_BACKTRACE=1 GASNET_OFI_SPAWNER=pmi FI_PROVIDER=psm2 deva_static_look_dt=$w; unset FI_PROVIDER_PATH
    t0=$(date +%s.%N)
    timeout -s TERM $CAPX srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -J dv_${tag}_n$N -w $nl -N $N -n $((2 * N)) \
      --ntasks-per-node=2 -c 24 --cpu-bind=cores -m block:block \
      stdbuf -oL $DB/$m-p$((2 * N))w23 $(margs $m $N) --end-time=$end --rng=clcg4 > $f 2>&1
    rc=$?; wall=$(printf %.1f "$(echo "$(date +%s.%N) - $t0" | bc)")
    line=$(grep -m1 -E '^(TRAFFIC|DRAGONFLY)_RESULT' $f)
    v() { tr ' ' '\n' <<< "$line" | sed -n "s/^$1=//p"; }
    st=ok; [ -z "$line" ] && st=fail; [ $rc = 124 ] && st=stall
    echo "engine=deva app=$m nodes=$N rep=$rep arm=$w status=$st rc=$rc wall=$wall committed=$(v committed) executed=$(v executed) rolled_back=$(v rolled_back) run_s=$(v wall_s) M_ev_s=$(awk -v r="$(v committed_per_s)" 'BEGIN{if (r != "") printf "%.2f", r / 1e6}') deterministic=$(v deterministic)" \
      | tee -a $OUT/deva_f5.txt | sed "s/^/n$N /" | cut -c1-200 ); }
f5ross() { # tag nodes nodelist model synch batch gvt_interval rep max_opt_lookahead (0 = none)
  local tag=$1 N=$2 nl=$3 m=$4 rep=$8 f=$OUT/n$2/ross_f5/$1_r$8.out end mo=""
  [ "${9:-0}" != 0 ] && mo="--max-opt-lookahead=$9"
  mkdir -p $OUT/n$N/ross_f5
  [ $m = traffic ] && end=$TR_END || end=$DF_END
  ( module load mvapich/3.0 >/dev/null 2>&1
    unset FI_PROVIDER FI_PROVIDER_PATH LCI_ATTR_BACKEND LCI_ATTR_OFI_PROVIDER_NAME LCI_ATTR_PACKET_SIZE PSM2_MULTI_EP
    t0=$(date +%s.%N)
    timeout -s TERM $CAPX srun --mpi=pmi2 --kill-on-bad-exit=1 -J ross_${tag}_n$N -w $nl -N $N -n $((46 * N)) --ntasks-per-node=46 \
      $RBM/$m/$m --synch=$5 --read-buffer=1 --extramem=800000 --batch=$6 --gvt-interval=$7 $mo $(margs $m $N) --end=$end > $f 2>&1
    rc=$?; wall=$(printf %.1f "$(echo "$(date +%s.%N) - $t0" | bc)")
    st=ok; grep -q 'Net Events Processed' $f || st=fail; [ $rc = 124 ] && st=stall
    echo "engine=ross app=$m nodes=$N rep=$rep arm=$tag window=${9:-0} status=$st rc=$rc wall=$wall committed=$(awk '/Net Events Processed/{print $NF; exit}' $f) M_ev_s=$(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' $f) efficiency=$(awk '/Efficiency/{print $(NF-1); exit}' $f) run_s=$(awk '/Running Time/{print $(NF-1); exit}' $f)" \
      | tee -a $OUT/ross_f5.txt | sed "s/^/n$N /" | cut -c1-200 ); }
f5app() { # app nodes nodelist rep
  local app=$1 N=$2 nl=$3 rep=$4 e w s t sy ba gi ml
  local df=dragonfly:$(shape $N | tr ' ' ':'):4:1:500:$DF_GEN tw=traffic:100:1000:64:16:0:0:3
  for e in $(ord "$ENGINES" $rep); do
    case $app:$e in
      df:charades)
        cs df_wps512_r$rep $N $nl wps:512 $df "$(ord 'mb:0 w:10000 w:20000' $rep)" $DF_END 1000 128 300
        cs df_direct_r$rep $N $nl off     $df "$(ord 'w:10000 w:20000' $rep)" $DF_END 1000 128 300 ;;
      df:devastator) for w in $(ord '10000 20000 40000' $rep); do f5dv df_$w $N $nl dragonfly $w $rep; done ;;
      df:ross) for s in $(ord "$ROSS_DF" $rep); do
                 IFS=: read -r t sy ba gi ml <<< "$s"; f5ross df_$t $N $nl dragonfly $sy $ba $gi $rep $ml; done ;;
      tr:charades)
        cs tr_pp2048_r$rep $N $nl pp:2048 $tw "$(ord 'mb:0 w:500 w:1000' $rep)" $TR_END 8 64 300
        cs tr_wps512_r$rep $N $nl wps:512 $tw w:500 $TR_END 8 64 300
        cs tr_direct_r$rep $N $nl off     $tw w:500 $TR_END 8 64 300 ;;
      tr:devastator) for w in $(ord '1000 2000 4000' $rep); do f5dv tr_$w $N $nl traffic $w $rep; done ;;
      tr:ross) for s in $(ord "$ROSS_TR" $rep); do
                 IFS=: read -r t sy ba gi ml <<< "$s"; f5ross tr_$t $N $nl traffic $sy $ba $gi $rep $ml; done ;;
    esac
  done; }

# ---- GC's 1-node cells (gc258.slurm part D)
fspec() { LA=100; MEAN=1000; REM=0; END=2048000
  case $1 in
    g100)  CW=gauss:100:1000:100;  AGGS="pp:2048"; SIG=100 ;;
    g500)  CW=gauss:100:1000:500;  AGGS="pp:2048"; SIG=500 ;;
    g1000) CW=gauss:100:1000:1000; AGGS="pp:2048 pp:512"; SIG=1000 ;;
    g2000) CW=gauss:100:1000:2000; AGGS="pp:512";  SIG=2000 ;;
  esac; }
dgrid() { case $1 in
    g100_1)  echo 1000 1400 2000 2800 4000 ;;
    g500_1)  echo 250 350 500 700 1000 ;;
    g1000_1) echo 700 1000 1400 ;;
    g2000_1) echo 250 350 500 700 ;;
  esac; }
dcell() { # cell nodelist rep
  local c=$1 wl=${1%_*} N=${1##*_} nl=$2 rep=$3 e a w
  fspec $wl
  for e in $(ord "c d" $rep); do
    if [ $e = c ]; then for a in $AGGS; do cs d_${c}_${a/:/}_r$rep $N $nl $a $CW mb:0 $END 8 128 150; done
    else for w in $(ord "$(dgrid $c)" $rep); do f1dv d_${c}_w${w}_r$rep $N $nl $w deva_s1; done; fi
  done; }

# ---- streams
s8() { # nodelist (8 nodes)
  local nl=$1 rep wl
  f1spec g100; cs warm_s8 8 $nl pp:2048 $CW w:300 512000 8 128 150; f1dv warm_s8 8 $nl 1000 deva_warm
  for rep in 1 2 3; do
    for wl in $(ord "g100 g500 g1000 g1000x g2000 g4000 uni l10g500 l10g2000" $rep); do f1cell $wl 8 $nl $rep; done
    for wl in $(ord "df tr" $rep); do f5app $wl 8 $nl $rep; done
    log "S8 REP $rep DONE"
  done; }
s1() { # node
  local nl=$1 rep c
  fspec g100; cs warm_s1 1 $nl pp:2048 $CW w:300 512000 8 128 150; f1dv warm_s1 1 $nl 1000 deva_warm
  for rep in 1 2 3 4 5; do
    for c in $(ord "g100_1 g500_1 g1000_1 g2000_1" $rep); do dcell $c $nl $rep; done
    log "S1 REP $rep DONE"
  done; }

# ---- 1. S8 (nodes 1-8) beside S1 (node 9); node 0 idle
s8 $(join ${NL[@]:1:8}) > $OUT/stream_s8.log 2>&1 &
s1 ${NL[9]} > $OUT/stream_s1.log 2>&1 &
wait
log "PHASE 1 DONE"

# ---- 2. check: uniform at 8 nodes alone and with load streams on nodes 9-14
loads() { # run the load streams until $OUT/stop_load exists
  local k=0
  ( f1spec uni; while [ ! -e $OUT/stop_load ]; do k=$((k + 1)); f1dv load_d4_$k 4 $(join ${NL[@]:9:4}) 500 deva_load; [ $STUB = 1 ] && break; done ) &
  ( f1spec uni; while [ ! -e $OUT/stop_load ]; do k=$((k + 1)); cs load_c2_$k 2 $(join ${NL[@]:13:2}) pp:512 $CW mb:0 $END 8 128 150; [ $STUB = 1 ] && break; done ) &
  wait; }
chk() { # mode rep
  local nl=$(join ${NL[@]:1:8}) w
  f1spec uni
  cs chk_$1_pp512_r$2 8 $nl pp:512 $CW mb:0 $END 8 128 150
  for w in $(ord "500 1000" $2); do f1dv chk_$1_w${w}_r$2 8 $nl $w deva_chk; done; }
if [ $SECONDS -gt $(( (118 - 18) * 60 )) ]; then
  log "CHECK SKIPPED: $((SECONDS / 60)) minutes used"
else
  {
    for rep in 1 2 3; do
      for m in $(ord "alone load" $rep); do
        if [ $m = load ]; then
          rm -f $OUT/stop_load; loads & lp=$!; [ $STUB = 1 ] || sleep 20   # the load runs start (srun launch ~5 s)
          chk load $rep
          touch $OUT/stop_load; wait $lp
        else chk alone $rep; fi
      done
      log "CHECK REP $rep DONE"
    done
  } > $OUT/stream_check.log 2>&1
  log "PHASE 2 DONE"
fi
grep -h -E ' (fail|stall) |status=(fail|stall)|rc=[1-9]' $OUT/stream_*.log | grep -v -E 'warm_|load_' | head -30
log "R8_260 DONE"
