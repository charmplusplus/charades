#!/bin/bash -l
#SBATCH -J scale32
#SBATCH -t 01:55:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/scale32_%j.out
# A1: paper-grade weak scaling, 1/2/4/8/16 nodes, Charades against Devastator
# and ROSS on Gaussian PHOLD; long runs; 3 reps; engines interleaved per rep.
# The 8-, 4-, 2- and 1-node series run side by side on disjoint nodes of the
# allocation, then 16 nodes alone (charades RESULTS.md section 141).
# First argument: a or b (16 nodes: that workload group at 1/2/4/8/16 nodes), or
# big (32 nodes: group a and group b at 16 nodes side by side on the two
# halves, then all eight workloads at 32 nodes, where Devastator adds W 4,000),
# or n32 (A2r, section 144: 32 nodes alone, all eight workloads without g1000x;
# the controller runs again at the end of each block, tag _qlast; no W 4,000;
# then traced runs, W 400, σ 100 / σ 2,000 / uniform, at 16 and 32 nodes).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 scale32.slurm a (b: skx)
#         sbatch -p skx -N 32 -n 1536 -x c455-081 -t 02:40:00 scale32.slurm big
#         sbatch -p skx -N 32 -n 1536 -x c455-081 -t 03:15:00 scale32.slurm n32
set -u
G=${1:-a}
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/scale32/${G}_j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh; D=$W/devastator; RB=$W/ROSS/build/models/phold-gauss/phold-gauss
NL=($(scontrol show hostnames $SLURM_JOB_NODELIST))
log "job $SLURM_JOB_ID group $G; nodes ${NL[*]}"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-50); htram $(git -C $W/htram log --oneline -1 | cut -c1-40); reconverse $(git -C $W/charm-pads-exp/contrib/reconverse log --oneline -1 | cut -c1-40); charm $(git -C $W/charm-pads-exp log --oneline -1 | cut -c1-40); ROSS $(git -C $W/ROSS log --oneline -1 | cut -c1-20)"
WA="g100 g1000 g4000 l10g2000"; WB="g500 g2000 uni l10g500 g1000x"
# Per workload: Charades workload, htram settings, arms; the PHOLD parameters
# for Devastator and ROSS (lookahead mean sigma remote end) and Devastator's W
spec() {
  ARMS="q:0.001 w:250 w:400"; DW="500 1000 2000"; LA=100; MEAN=1000; REM=0; END=2048000; CH_ONLY=0
  case $1 in
    g100)  CW=gauss:100:1000:100;  AGGS="pp:2048"; SIG=100 ;;
    g500)  CW=gauss:100:1000:500;  AGGS="pp:2048"; SIG=500 ;;
    g1000) CW=gauss:100:1000:1000; AGGS="pp:2048"; SIG=1000 ;;
    # Charades only: section 140 fixed PP 2,048 at sigma <= 1,000, but on 1
    # node PP 512 is 9% faster at sigma 1,000 (section 130); both, every N
    g1000x) CW=gauss:100:1000:1000; AGGS="pp:512 pp:2048"; SIG=1000; CH_ONLY=1 ;;
    g2000) CW=gauss:100:1000:2000; AGGS="pp:512";  SIG=2000 ;;
    g4000) CW=gauss:100:1000:4000; AGGS="pp:512";  SIG=4000 ;;
    uni)   CW=steady:100:1000:1.0; AGGS="pp:512 wps:512"; SIG=0; REM=1.0 ;;
    l10g500)  CW=gauss:10:200:500;  AGGS="pp:2048"; SIG=500;  LA=10; MEAN=200; END=512000; ARMS="q:0.001 w:50 w:100"; DW="100 200 400" ;;
    l10g2000) CW=gauss:10:200:2000; AGGS="pp:512 wps:512"; SIG=2000; LA=10; MEAN=200; END=512000; ARMS="q:0.001 w:50 w:100"; DW="100 200 400" ;;
  esac
}
gate() { # output file
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/$T/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $W/$T/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
    python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" \
      agg_deadline_bucket_pp agg_inputbuf_bucket_wps bucket_window agg_bucket_pp agg_ctl_sparse_bucket_pp > $1 2>&1 )
  tail -4 $1; grep -E "FAIL|TIMEOUT" $1 | head
  grep -q "Failed: *0/" $1 && grep -q "Timed out: *0/" $1; }
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
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" ); }
dv() { # tag nodes nodelist window
  local db=$D/bin/ofi-psm2/phold-gauss-p$(($2 * 2))w23 extra=()
  [ "$REM" != 0 ] && extra=(--remote=$REM)
  ( export WINDOW=$4 RUNS=$OUT/n$2/deva LPS_PER_RANK=128 START=15 LOOKAHEAD=$LA MEAN=$MEAN SIGMA=$SIG END=$END CAP=200 AFFINITY=0 SRUN_EXTRA="-w $3"
    LABEL=$1 bash $D/run_phold.sh $db $2 --rng=clcg4 "${extra[@]}" | head -1 | sed "s/^/n$2 /" | cut -c1-120 ); }
ross() { # tag nodes nodelist synch batch gvt_interval
  local n=$(($2 * 46)) f=$OUT/n$2/ross/$1.out; mkdir -p $OUT/n$2/ross
  ( module load mvapich/3.0 >/dev/null 2>&1
    unset FI_PROVIDER FI_PROVIDER_PATH LCI_ATTR_BACKEND LCI_ATTR_OFI_PROVIDER_NAME LCI_ATTR_PACKET_SIZE PSM2_MULTI_EP
    timeout -s TERM 360 srun --mpi=pmi2 --kill-on-bad-exit=1 -J ross_$1 -w $3 -N $2 -n $n --ntasks-per-node=46 \
      $RB --synch=$4 --read-buffer=1 --start-events=15 --sigma=$SIG --remote=$REM \
      --extramem=800000 --num-lps=$((n * 128)) --lookahead=$LA --mean=$MEAN --end=$END \
      --batch=$5 --gvt-interval=$6 > $f 2>&1
    local rc=$?
    echo "label=$1 nodes=$2 synch=$4 batch=$5 gvt_interval=$6 rc=$rc committed=$(awk '/Net Events Processed/{print $NF; exit}' $f) M_ev_s=$(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' $f) efficiency=$(awk '/Efficiency/{print $(NF-1); exit}' $f) running_s=$(awk '/Running Time/{print $(NF-1); exit}' $f)" | tee -a $OUT/n$2/ross/results.txt | sed "s/^/n$2 /" )
}
stream() { # nodes nodelist workloads
  local N=$1 nl=$2 wls=$3
  spec g100; cs warm_${wls%% *} $N $nl pp:2048 $CW w:250 512000
  for rep in 1 2 3; do
    for wl in $wls; do
      spec $wl
      [ $G = big ] && [ $N = 32 ] && [ $LA = 100 ] && DW="$DW 4000"
      for a in $AGGS; do cs ${wl}_${a/:/}_r$rep $N $nl $a $CW "$ARMS" $END; done
      [ $G = n32 ] && for a in $AGGS; do cs ${wl}_${a/:/}_r${rep}_qlast $N $nl $a $CW q:0.001 $END; done
      [ $CH_ONLY = 1 ] && continue
      for w in $DW; do dv ${wl}_w${w}_r$rep $N $nl $w; done
      ross ${wl}_opt_r$rep $N $nl 3 16 64
      ross ${wl}_cons_r$rep $N $nl 2 16 16
    done
    log "N $N REP $rep DONE"
  done
}
join() { local IFS=,; echo "$*"; }
trace() { # nodes nodelist: per-process wave traces and per-PE stats, W 400 (section 144)
  local N=$1 nl=$2 a
  for wl in g100 g2000 uni; do
    spec $wl; a=${AGGS##* }
    cs ${wl}_${a/:/}_trace $N $nl $a $CW w:400 $END "--gvt-trace=2 --pe-stats=1"
  done; }
if [ $G = big ]; then
  stream 16 $(join ${NL[@]:0:16}) "$WA" > $OUT/stream_n16a.log 2>&1 &
  stream 16 $(join ${NL[@]:16:16}) "$WB" > $OUT/stream_n16b.log 2>&1 &
  wait
  log "16 DONE"
  stream 32 $(join ${NL[@]:0:32}) "$WA $WB" > $OUT/stream_n32.log 2>&1
  log "32 DONE"
elif [ $G = n32 ]; then
  stream 32 $(join ${NL[@]:0:32}) "$WA ${WB% g1000x}" > $OUT/stream_n32.log 2>&1
  log "32 DONE"
  trace 16 $(join ${NL[@]:0:16}) > $OUT/trace.log 2>&1
  trace 32 $(join ${NL[@]:0:32}) >> $OUT/trace.log 2>&1
  log "TRACE DONE"
else
  [ $G = a ] && WLS=$WA || WLS=$WB
  stream 8 $(join ${NL[@]:0:8}) "$WLS" > $OUT/stream_n8.log 2>&1 &
  stream 4 $(join ${NL[@]:8:4}) "$WLS" > $OUT/stream_n4.log 2>&1 &
  stream 2 $(join ${NL[@]:12:2}) "$WLS" > $OUT/stream_n2.log 2>&1 &
  stream 1 ${NL[14]} "$WLS" > $OUT/stream_n1.log 2>&1 &
  wait
  log "1/2/4/8 DONE"
  stream 16 $(join ${NL[@]:0:16}) "$WLS" > $OUT/stream_n16.log 2>&1
  log "16 DONE"
fi
log "SCALE32 $G DONE"
