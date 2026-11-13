#!/bin/bash -l
#SBATCH -J abl222
#SBATCH -t 01:45:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/abl222_%j.out
# Job ABL (charades RESULTS.md section 222): F2 and F3 on PHOLD and traffic,
# and ROSS's optimism window on traffic and dragonfly. 16 nodes.
#   1. gate, 2 nodes: Charades' change tier (Simple PHOLD, traffic) with the
#      hold, eager htram, the controller with htram, and a fixed window
#   2. 4 nodes, groups side by side: nodes 0-3 sigma 100 then traffic; 4-7
#      sigma 2,000 then uniform; 8-11 ROSS's window and Charades' controller
#      at 4 nodes; node 12 the same at 1 node
#   3. 16 nodes: sigma 100, sigma 2,000, uniform, traffic
# Arms per workload and rep (A, B = 250, 400 on PHOLD; 500, 1,000 on traffic):
#   direct (w:A w:B mb:0), eager htram (--agg-policy=0; same), deadline htram
#   (same), PADS'19 hold (direct, no window, --gvt-adaptive-buckets=1,
#   --gvt-reserve-buckets K: 8 32 128 on PHOLD, 16 64 256 on traffic).
#   2 reps, order reversed in rep 2.
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 abl222.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/abl222/j${SLURM_JOB_ID:-dry}; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-abl; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh; RB=$W/ROSS/build/models
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}"
[ "$(git -C $C rev-parse --short=7 HEAD)" = bb858a4 ] || { log "$T not at bb858a4"; exit 1; }
grep -q "AGG_POLICY" $S || { log "ctl_sweep.sh lacks AGG_POLICY"; exit 1; }
for b in $C/models/phold/simple/phold $C/models/traffic/traffic $C/models/dragonfly/dragonfly; do
  [ -x $b ] || { log "missing $b"; exit 1; }
  strings $b | grep -q "the base before and after" || { log "$b lacks --ctl-bracket"; exit 1; }
  strings $b | grep -q "Commit Digest" || { log "$b lacks --commit-digest"; exit 1; }
  strings $b | grep -q "PER-PE WITH A SHARED SPARE LIST" || { log "$b is not round 3"; exit 1; }
  ldd $b | grep -q "charm-pads-perf/" || { log "$b does not link charm-pads-perf"; exit 1; }
done
for b in $RB/traffic/traffic $RB/dragonfly/dragonfly; do [ -x $b ] || { log "missing $b"; exit 1; }; done
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }

# ---- 1. gate
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" --model Traffic \
    bucket_hold agg_bucket_pp agg_ctl_measured_fast_bucket_pp bucket_window > $OUT/gate.txt 2>&1 )
tail -3 $OUT/gate.txt
grep -q "Failed: *0/" $OUT/gate.txt && grep -q "Timed out: *0/" $OUT/gate.txt || { log "GATE FAILED"; exit 1; }
log "GATE DONE"

export TREE=$T PPN=2 PEPP=23 CPT=24 CAP=150 LPC=16 START=15
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1 --commit-digest=1"
TR_END=12000000 DF_END=310000000 DF_GEN=300000 CAPX=300
TW=traffic:100:1000:64:16:0:0:3
cs() { # tag nodes nodelist agg workload arms end bucket lps_per_pe [policy] [extra]
  ( export NODES=$2 AGG=$4 WORKLOADS="$5" ARMS="$6" END=$7 BUCKETS=$8 LPS_PER_PE=$9 AGG_POLICY=${10:-1} \
      EXTRA_ARGS="$L ${11:-}" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" ); }
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
spec() { # workload -> CW MODE A B KS END LPP
  case $1 in
    g100)  CW=gauss:100:1000:100;  MODE=pp:2048; A=250; B=400;  KS="8 32 128";  END=2048000;  LPP=128 ;;
    g2000) CW=gauss:100:1000:2000; MODE=pp:512;  A=250; B=400;  KS="8 32 128";  END=2048000;  LPP=128 ;;
    uni)   CW=steady:100:1000:1.0; MODE=wps:512; A=250; B=400;  KS="8 32 128";  END=2048000;  LPP=128 ;;
    tr)    CW=$TW;                 MODE=pp:2048; A=500; B=1000; KS="16 64 256"; END=$TR_END; LPP=64 ;;
  esac; }
abl() { # workload nodes nodelist rep
  local wl=$1 N=$2 nl=$3 rep=$4 g k
  spec $wl
  local arms="w:$A w:$B mb:0" groups="direct eager deadline hold" ks="$KS"
  if [ $rep = 2 ]; then arms=$(rev "$arms"); groups=$(rev "$groups"); ks=$(rev "$ks"); fi
  for g in $groups; do
    case $g in
      direct)   cs ${wl}_direct_r$rep   $N $nl off   $CW "$arms" $END 8 $LPP ;;
      eager)    cs ${wl}_eager_r$rep    $N $nl $MODE $CW "$arms" $END 8 $LPP 0 ;;
      deadline) cs ${wl}_deadline_r$rep $N $nl $MODE $CW "$arms" $END 8 $LPP 1 ;;
      hold)     for k in $ks; do
                  # 90 s cap: nothing bounds same-chare events without a window
                  CAP=90 cs ${wl}_hold${k}_r$rep $N $nl off $CW w:0 $END 8 $LPP 1 "--gvt-adaptive-buckets=1 --gvt-reserve-buckets=$k"
                done ;;
    esac
  done; }
series() { # nodes nodelist workloads...
  local N=$1 nl=$2 rep wl; shift 2
  for rep in 1 2; do
    for wl in "$@"; do abl $wl $N $nl $rep; done
    log "n$N $* REP $rep DONE"
  done; }
# ROSS, from f5scale187.slurm, with --max-opt-lookahead (0 = none)
shape() { case $1 in 1) echo "13 4" ;; 4) echo "16 10" ;; 16) echo "28 14" ;; esac; }
margs() { # model nodes
  if [ $1 = traffic ]; then
    echo "--num-x=64 --num-y=$((46 * $2)) --total-cars=$((46 * $2 * 64 * 16)) --lookahead=100 --mean=1000 --trip-radius=3"
  else
    set -- $(shape $2)
    echo "--routers-per-group=$1 --global-channels=$2 --terminals-per-router=4 --traffic=1 --routing=0 --arrive-rate=500 --gen-time=$DF_GEN"
  fi; }
ross() { # tag nodes nodelist model batch gvt_interval max_opt_lookahead rep
  local tag=$1 N=$2 nl=$3 m=$4 ba=$5 gi=$6 ml=$7 rep=$8 f=$OUT/n$2/ross/$1_r$8.out end mo=
  mkdir -p $OUT/n$N/ross
  [ $m = traffic ] && end=$TR_END || end=$DF_END
  [ $ml != 0 ] && mo="--max-opt-lookahead=$ml"
  ( module load mvapich/3.0 >/dev/null 2>&1
    unset FI_PROVIDER FI_PROVIDER_PATH LCI_ATTR_BACKEND LCI_ATTR_OFI_PROVIDER_NAME LCI_ATTR_PACKET_SIZE PSM2_MULTI_EP
    t0=$(date +%s.%N)
    timeout -s TERM $CAPX srun --mpi=pmi2 --kill-on-bad-exit=1 -J ross_${tag}_n$N -w $nl -N $N -n $((46 * N)) --ntasks-per-node=46 \
      $RB/$m/$m --synch=3 --read-buffer=1 --extramem=800000 --batch=$ba --gvt-interval=$gi $mo $(margs $m $N) --end=$end > $f 2>&1
    rc=$?; wall=$(printf %.1f "$(echo "$(date +%s.%N) - $t0" | bc)")
    st=ok; grep -q 'Net Events Processed' $f || st=fail; [ $rc = 124 ] && st=stall
    echo "engine=ross app=$m nodes=$N rep=$rep arm=$tag window=$ml status=$st rc=$rc wall=$wall committed=$(awk '/Net Events Processed/{print $NF; exit}' $f) M_ev_s=$(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' $f) efficiency=$(awk '/Efficiency/{print $(NF-1); exit}' $f) run_s=$(awk '/Running Time/{print $(NF-1); exit}' $f)" \
      | tee -a $OUT/ross.txt | sed "s/^/n$N /" | cut -c1-220 )
}
rossgroup() { # nodes nodelist: ROSS's window arms and Charades' controller
  local N=$1 nl=$2 rep ml df=dragonfly:$(shape $1 | tr ' ' ':'):4:1:500:$DF_GEN
  for rep in 1 2; do
    local tw="0 250 500 1000 2000" dw="0 5000 10000 20000 40000"
    [ $rep = 2 ] && { tw=$(rev "$tw"); dw=$(rev "$dw"); }
    for ml in $tw; do ross tr_w$ml $N $nl traffic 64 64 $ml $rep; done
    for ml in $dw; do ross df_w$ml $N $nl dragonfly 2 64 $ml $rep; done
    cs df_wps512_r$rep $N $nl wps:512 $df mb:0 $DF_END 1000 128
    [ $N = 1 ] && cs tr_pp2048_r$rep $N $nl pp:2048 $TW mb:0 $TR_END 8 64
    log "n$N ross REP $rep DONE"
  done; }

# ---- 2. 4 nodes (and 1), side by side
series 4 $(join ${NL[@]:0:4}) g100 tr > $OUT/stream_a4.log 2>&1 &
series 4 $(join ${NL[@]:4:4}) g2000 uni > $OUT/stream_b4.log 2>&1 &
rossgroup 4 $(join ${NL[@]:8:4}) > $OUT/stream_r4.log 2>&1 &
rossgroup 1 ${NL[12]} > $OUT/stream_r1.log 2>&1 &
wait
log "4-NODE PHASE DONE"

# ---- 3. 16 nodes
series 16 $(join ${NL[@]:0:16}) g100 g2000 uni tr > $OUT/stream_16.log 2>&1
log "16-NODE PHASE DONE"
grep -h -E ' (fail|stall) |status=(fail|stall)' $OUT/stream_*.log | head -30
log "ABL222 DONE"
