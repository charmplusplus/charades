#!/bin/bash -l
#SBATCH -J scale240
#SBATCH -t 02:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/scale240_%j.out
# F1 on the final defaults (charades RESULTS.md section 240): weak scaling,
# Gaussian PHOLD, Charades against Devastator and ROSS, long runs, engines
# interleaved per rep; A1/A2's layout (scale32.slurm, sections 141-153) with:
#   Charades charades-r5 (85a2aad: round 3, per-LP rollback, --agg-pp-alloc=1,
#     the frozen controller with --ctl-reach-buckets=2; ctl_sweep's numactl
#     --localalloc launch): the controller (mb:0) and W 300 / 400 (lookahead
#     10: 50 / 100), A1's htram settings
#   Devastator W 500 / 1,000 / 2,000 (lookahead 10: 100 / 200 / 400), plus
#     4,000 at 32 nodes; CLCG4
#   ROSS optimistic batch 16 / GVT interval 64, conservative, and optimistic
#     with its window (--max-opt-lookahead): the value job RW wrote to
#     f1_240/ross_windows.txt for that workload, or two values if it has none
# First argument:
#   a, b  16 nodes: workload group a (σ 100, σ 1,000, σ 4,000, lookahead 10
#         σ 2,000) or b (σ 500, σ 2,000, uniform, lookahead 10 σ 500; σ 1,000
#         with PP 512, Charades only) at 8, 4, 2 and 1 nodes side by side, then
#         16 nodes; 3 reps
#   big   32 nodes: all eight workloads at 32 nodes, 5 reps
# Submit: sbatch -p skx -N 16 -n 768 -x c455-081 scale240.slurm a   (b likewise)
#         sbatch -p skx -N 32 -n 1536 -x c455-081 -t 04:00:00 scale240.slurm big
set -u
G=${1:-a}
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/f1_240/${G}_j${SLURM_JOB_ID:-dry}; mkdir -p $OUT
RWF=$W/charades-runs/f1_240/ross_windows.txt
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-r5; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh; D=$W/devastator; RB=$W/ROSS/build/models/phold-gauss/phold-gauss
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry} group $G; nodes ${NL[*]:-none}"
log "charades $(git -C $C log --oneline -1 | cut -c1-50); ROSS $(git -C $W/ROSS log --oneline -1 | cut -c1-20)"
[ "$(git -C $C rev-parse --short=7 HEAD)" = 85a2aad ] || { log "$T not at 85a2aad"; exit 1; }
b=$C/models/phold/simple/phold
for s in ctl-reach-buckets "the base before and after" "PER-PE WITH A SHARED SPARE LIST"; do
  strings $b | grep -q "$s" || { log "$b lacks $s"; exit 1; }
done
ldd $b | grep -q charm-pads-perf/ || { log "$b does not link charm-pads-perf"; exit 1; }
grep -q "mb)   extra" $S || { log "ctl_sweep.sh lacks the mb arm"; exit 1; }
[ -x $RB ] && strings $RB | grep -q max-opt-lookahead || { log "ROSS phold-gauss missing or lacks --max-opt-lookahead"; exit 1; }
NS="1 2 4 8 16"; [ $G = big ] && NS=32
for n in $NS; do [ -x $D/bin/ofi-psm2/phold-gauss-p$((2 * n))w23 ] || { log "missing Devastator phold-gauss-p$((2 * n))w23"; exit 1; }; done
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }
# TWIN (sbatch --export=ALL,TWIN=<job id>): the same job queued elsewhere. The
# copy that starts first runs and cancels the other; one that starts second exits.
if [ -n "${TWIN:-}" ]; then
  st=$(squeue -h -j $TWIN -o %T 2>/dev/null)
  [ "$st" = PENDING ] || { log "twin $TWIN is ${st:-not queued}: exiting"; exit 0; }
  scancel $TWIN && log "twin $TWIN was pending: cancelled"
fi

WA="g100 g1000 g4000 l10g2000"; WB="g500 g2000 uni l10g500 g1000x"
# Per workload: Charades workload, htram settings, arms; the PHOLD parameters
# for Devastator and ROSS (lookahead mean sigma remote end), Devastator's W and
# ROSS's fallback windows
spec() {
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
  esac
}
gate() { # output file
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
    python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" \
      agg_deadline_bucket_pp agg_inputbuf_bucket_wps bucket_window agg_bucket_pp agg_ctl_measured_bucket_pp ctl_measured_bucket > $1 2>&1 )
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
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=150 PPN=2 PEPP=23 CPT=24
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
cs() { # tag nodes nodelist agg workload arms end [extra Charades flags]
  ( export NODES=$2 AGG=$4 END=$7 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="$L ${8:-}" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" )
  rm -f $OUT/n$2/$1/ctl_sweep/gvt_*.out; }
dv() { # tag nodes nodelist window
  local db=$D/bin/ofi-psm2/phold-gauss-p$(($2 * 2))w23 extra=()
  [ "$REM" != 0 ] && extra=(--remote=$REM)
  ( export WINDOW=$4 RUNS=$OUT/n$2/deva LPS_PER_RANK=128 START=15 LOOKAHEAD=$LA MEAN=$MEAN SIGMA=$SIG END=$END CAP=200 AFFINITY=0 SRUN_EXTRA="-w $3"
    LABEL=$1 bash $D/run_phold.sh $db $2 --rng=clcg4 "${extra[@]}" | head -1 | sed "s/^/n$2 /" | cut -c1-120 ); }
ross() { # tag nodes nodelist synch batch gvt_interval max_opt_lookahead (0 = none)
  local n=$(($2 * 46)) f=$OUT/n$2/ross/$1.out mo=""; mkdir -p $OUT/n$2/ross
  [ $7 != 0 ] && mo="--max-opt-lookahead=$7"
  ( module load mvapich/3.0 >/dev/null 2>&1
    unset FI_PROVIDER FI_PROVIDER_PATH LCI_ATTR_BACKEND LCI_ATTR_OFI_PROVIDER_NAME LCI_ATTR_PACKET_SIZE PSM2_MULTI_EP
    timeout -s TERM 360 srun --mpi=pmi2 --kill-on-bad-exit=1 -J ross_$1 -w $3 -N $2 -n $n --ntasks-per-node=46 \
      $RB --synch=$4 --read-buffer=1 --start-events=15 --sigma=$SIG --remote=$REM \
      --extramem=800000 --num-lps=$((n * 128)) --lookahead=$LA --mean=$MEAN --end=$END \
      --batch=$5 --gvt-interval=$6 $mo > $f 2>&1
    local rc=$?
    echo "label=$1 nodes=$2 synch=$4 batch=$5 gvt_interval=$6 window=$7 rc=$rc committed=$(awk '/Net Events Processed/{print $NF; exit}' $f) M_ev_s=$(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' $f) efficiency=$(awk '/Efficiency/{print $(NF-1); exit}' $f) running_s=$(awk '/Running Time/{print $(NF-1); exit}' $f)" | tee -a $OUT/n$2/ross/results.txt | sed "s/^/n$2 /" )
}
rwin() { # workload: ROSS's window from job RW, else the fallback pair
  local w=$(awk -v k=$1 '$1 == k {print $2}' $RWF 2>/dev/null)
  if [ -n "$w" ]; then echo $w; else echo "$RWD"; fi; }
stream() { # nodes nodelist workloads reps
  local N=$1 nl=$2 wls=$3 reps=$4 rep wl a w
  spec g100; cs warm_${wls%% *} $N $nl pp:2048 $CW w:300 512000
  for rep in $(seq $reps); do
    for wl in $wls; do
      spec $wl
      [ $N = 32 ] && [ $LA = 100 ] && DW="$DW 4000"
      for a in $AGGS; do cs ${wl}_${a/:/}_r$rep $N $nl $a $CW "$ARMS" $END; done
      [ $CH_ONLY = 1 ] && continue
      for w in $DW; do dv ${wl}_w${w}_r$rep $N $nl $w; done
      ross ${wl}_opt_r$rep $N $nl 3 16 64 0
      ross ${wl}_cons_r$rep $N $nl 2 16 16 0
      for w in $(rwin ${wl%x}); do [ $w != 0 ] && ross ${wl}_optw${w}_r$rep $N $nl 3 16 64 $w; done
    done
    log "N $N REP $rep DONE"
  done
}
log "ROSS windows file: $(cat $RWF 2>/dev/null | tr '\n' ';' || echo none)"
if [ $G = big ]; then
  stream 32 $(join ${NL[@]:0:32}) "$WA ${WB% g1000x}" 5 > $OUT/stream_n32.log 2>&1
  log "32 DONE"
else
  [ $G = a ] && WLS=$WA || WLS=$WB
  stream 8 $(join ${NL[@]:0:8}) "$WLS" 3 > $OUT/stream_n8.log 2>&1 &
  stream 4 $(join ${NL[@]:8:4}) "$WLS" 3 > $OUT/stream_n4.log 2>&1 &
  stream 2 $(join ${NL[@]:12:2}) "$WLS" 3 > $OUT/stream_n2.log 2>&1 &
  stream 1 ${NL[14]} "$WLS" 3 > $OUT/stream_n1.log 2>&1 &
  wait
  log "1/2/4/8 DONE"
  stream 16 $(join ${NL[@]:0:16}) "$WLS" 3 > $OUT/stream_n16.log 2>&1
  log "16 DONE"
fi
grep -h -E ' (fail|stall) |rc=[1-9]' $OUT/stream_n*.log | head -20
log "SCALE240 $G DONE"
