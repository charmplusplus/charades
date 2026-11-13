#!/bin/bash -l
#SBATCH -J f3r224
#SBATCH -t 01:55:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/f3r224_%j.out
# Job F3R (charades RESULTS.md section 224): the PADS'19 hold with PADS'19's
# release rule (every held event goes at the next GVT advance), against no
# hold with and without the local fast path; ROSS's dragonfly window below
# 5,000 ps. Tree charades-f3 = charades 8a34d51 (the hold's release scan fix)
# on charm-pads-perf. All Charades arms send directly (no htram), as PADS'19.
#   1. gate, 2 nodes: change tier (Simple PHOLD, traffic)
#   2. 4 nodes, side by side: nodes 0-3 sigma 100 then traffic; 4-7 sigma
#      2,000 then uniform; 8-11 ROSS's dragonfly window and Charades'
#      dragonfly controller at 4 nodes; node 12 the same at 1 node
#   3. 16 nodes: the same Charades arms; the hold without a window at cutoffs
#      16 and 128 only where all its 4-node runs finished
# Arms per workload and rep (B = 400 on PHOLD, 1,000 on traffic):
#   fp       w:0 w:B   no hold, local fast path on (Charades' default)
#   nofp     w:0 w:B   no hold, --local-fast-path=0 (the hold turns it off)
#   holdK    w:0       hold, cutoff K = 16, 128, 512 buckets of 8 (128, 1,024,
#                      4,096 time units: 0.13, 1 and 4 mean delays)
#   holdKw   w:B       hold beside the window, K = 16, 128
#   2 reps, order reversed in rep 2.
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 f3r224.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/f3r224/j${SLURM_JOB_ID:-dry}; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-f3; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh; RB=$W/ROSS/build/models
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}"
[ "$(git -C $C rev-parse --short=7 HEAD)" = 8a34d51 ] || { log "$T not at 8a34d51"; exit 1; }
grep -q "AGG_POLICY" $S || { log "ctl_sweep.sh lacks AGG_POLICY"; exit 1; }
[ -f $C/tests/test_configs/bucket_hold_pads19 ] || { log "no bucket_hold_pads19"; exit 1; }
for b in $C/models/phold/simple/phold $C/models/traffic/traffic $C/models/dragonfly/dragonfly; do
  [ -x $b ] || { log "missing $b"; exit 1; }
  [ $b -nt $C/src/gvt/bucketed.C ] || { log "$b is older than bucketed.C"; exit 1; }
  strings $b | grep -q "the base before and after" || { log "$b lacks --ctl-bracket"; exit 1; }
  strings $b | grep -q "Commit Digest" || { log "$b lacks --commit-digest"; exit 1; }
  strings $b | grep -q "PER-PE WITH A SHARED SPARE LIST" || { log "$b is not round 3"; exit 1; }
  ldd $b | grep -q "charm-pads-perf/" || { log "$b does not link charm-pads-perf"; exit 1; }
done
[ -x $RB/dragonfly/dragonfly ] || { log "missing ROSS dragonfly"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }

# ---- 1. gate
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" --model Traffic \
    bucket_hold_pads19 bucket_hold bucket_nofastpath bucket_window > $OUT/gate.txt 2>&1 )
tail -3 $OUT/gate.txt
grep -q "Failed: *0/" $OUT/gate.txt && grep -q "Timed out: *0/" $OUT/gate.txt || { log "GATE FAILED"; exit 1; }
log "GATE DONE"

export TREE=$T PPN=2 PEPP=23 CPT=24 CAP=150 LPC=16 START=15
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1 --commit-digest=1"
H="--gvt-adaptive-buckets=1 --gvt-clear-buckets=0 --gvt-clear-lag=0 --gvt-reserve-buckets"
TR_END=12000000 DF_END=310000000 DF_GEN=300000 CAPX=300
TW=traffic:100:1000:64:16:0:0:3
cs() { # tag nodes nodelist agg workload arms end bucket lps_per_pe [policy] [extra]
  ( export NODES=$2 AGG=$4 WORKLOADS="$5" ARMS="$6" END=$7 BUCKETS=$8 LPS_PER_PE=$9 AGG_POLICY=${10:-1} \
      EXTRA_ARGS="$L ${11:-}" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" ); }
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
spec() { # workload -> CW B END LPP
  case $1 in
    g100)  CW=gauss:100:1000:100;  B=400;  END=2048000;  LPP=128 ;;
    g2000) CW=gauss:100:1000:2000; B=400;  END=2048000;  LPP=128 ;;
    uni)   CW=steady:100:1000:1.0; B=400;  END=2048000;  LPP=128 ;;
    tr)    CW=$TW;                 B=1000; END=$TR_END; LPP=64 ;;
  esac; }
finished4() { # workload group: all its 4-node runs ok
  local f n=0 bad=0
  for f in $OUT/n4/$1_$2_r*.csv; do
    [ -f $f ] || continue; n=$((n + 1))
    bad=$((bad + $(awk -F, 'NR > 1 && $11 != "ok"' $f | wc -l)))
  done
  [ $n -gt 0 ] && [ $bad = 0 ]; }
f3() { # workload nodes nodelist rep
  local wl=$1 N=$2 nl=$3 rep=$4 g
  spec $wl
  local arms="w:0 w:$B" groups="fp nofp hold16 hold128 hold512 hold16w hold128w"
  if [ $rep = 2 ]; then arms=$(rev "$arms"); groups=$(rev "$groups"); fi
  for g in $groups; do
    case $g in
      fp)       cs ${wl}_fp_r$rep   $N $nl off $CW "$arms" $END 8 $LPP ;;
      nofp)     cs ${wl}_nofp_r$rep $N $nl off $CW "$arms" $END 8 $LPP 1 "--local-fast-path=0" ;;
      hold16|hold128)
                if [ $N = 16 ] && ! finished4 $wl $g; then echo "n$N ${wl}_${g}_r$rep skipped: not all 4-node runs finished"; continue; fi
                cs ${wl}_${g}_r$rep $N $nl off $CW w:0 $END 8 $LPP 1 "$H=${g#hold}" ;;
      hold512)  cs ${wl}_hold512_r$rep $N $nl off $CW w:0 $END 8 $LPP 1 "$H=512" ;;
      hold16w|hold128w)
                local k=${g#hold}; k=${k%w}
                cs ${wl}_${g}_r$rep $N $nl off $CW w:$B $END 8 $LPP 1 "$H=$k" ;;
    esac
  done; }
series() { # nodes nodelist workloads...
  local N=$1 nl=$2 rep wl; shift 2
  for rep in 1 2; do
    for wl in "$@"; do f3 $wl $N $nl $rep; done
    log "n$N $* REP $rep DONE"
  done; }
# ROSS, from abl222.slurm, with --max-opt-lookahead (0 = none)
shape() { case $1 in 1) echo "13 4" ;; 4) echo "16 10" ;; 16) echo "28 14" ;; esac; }
margs() { set -- $(shape $2)
  echo "--routers-per-group=$1 --global-channels=$2 --terminals-per-router=4 --traffic=1 --routing=0 --arrive-rate=500 --gen-time=$DF_GEN"; }
ross() { # tag nodes nodelist batch gvt_interval max_opt_lookahead rep
  local tag=$1 N=$2 nl=$3 ba=$4 gi=$5 ml=$6 rep=$7 f=$OUT/n$2/ross/$1_r$7.out mo=
  mkdir -p $OUT/n$N/ross
  [ $ml != 0 ] && mo="--max-opt-lookahead=$ml"
  ( module load mvapich/3.0 >/dev/null 2>&1
    unset FI_PROVIDER FI_PROVIDER_PATH LCI_ATTR_BACKEND LCI_ATTR_OFI_PROVIDER_NAME LCI_ATTR_PACKET_SIZE PSM2_MULTI_EP
    t0=$(date +%s.%N)
    timeout -s TERM $CAPX srun --mpi=pmi2 --kill-on-bad-exit=1 -J ross_${tag}_n$N -w $nl -N $N -n $((46 * N)) --ntasks-per-node=46 \
      $RB/dragonfly/dragonfly --synch=3 --read-buffer=1 --extramem=800000 --batch=$ba --gvt-interval=$gi $mo $(margs dragonfly $N) --end=$DF_END > $f 2>&1
    rc=$?; wall=$(printf %.1f "$(echo "$(date +%s.%N) - $t0" | bc)")
    st=ok; grep -q 'Net Events Processed' $f || st=fail; [ $rc = 124 ] && st=stall
    echo "engine=ross app=dragonfly nodes=$N rep=$rep arm=$tag window=$ml status=$st rc=$rc wall=$wall committed=$(awk '/Net Events Processed/{print $NF; exit}' $f) M_ev_s=$(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' $f) efficiency=$(awk '/Efficiency/{print $(NF-1); exit}' $f) run_s=$(awk '/Running Time/{print $(NF-1); exit}' $f)" \
      | tee -a $OUT/ross.txt | sed "s/^/n$N /" | cut -c1-220 )
}
rossgroup() { # nodes nodelist: ROSS's dragonfly window arms and Charades' controller
  local N=$1 nl=$2 rep ml df=dragonfly:$(shape $1 | tr ' ' ':'):4:1:500:$DF_GEN
  for rep in 1 2; do
    local dw="0 625 1250 2500 5000"
    [ $rep = 2 ] && dw=$(rev "$dw")
    for ml in $dw; do ross df_w$ml $N $nl 2 64 $ml $rep; done
    cs df_wps512_r$rep $N $nl wps:512 $df mb:0 $DF_END 1000 128
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
grep -h -E ' (fail|stall) |status=(fail|stall)|skipped' $OUT/stream_*.log | head -40
log "F3R224 DONE"
