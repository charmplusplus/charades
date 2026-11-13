#!/bin/bash -l
#SBATCH -J gc258
#SBATCH -t 01:55:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/gc258_%j.out
# Job GC (charades results/controller.md section 258; user decision
# 2026-11-08: do the grid check). Job AG32 (section 257) found a fixed window
# between two grid points 8-15% faster than both (W 75 on lookahead 10). This
# job refines the fixed-W grids behind claims 2 and 3, on tree charades-r5
# (85a2aad), with the paper launch only (no diagnostics):
# Part C (claim 2, robustness): F4b's cells (section 251) at 4 and 16 nodes,
#   Charades only: a grid in steps of 15-25% around F4b's best fixed W (with
#   F4b's best W) and the frozen controller; F4b's sizes and htram settings.
#   Phase-changing PHOLD is left out: its grid is already in steps of 25
#   around its best (W 75).
# Part D (claim 3, Charades / Devastator): F1's cells at 1-8 nodes (sections
#   242-243) where Devastator's best W was the end of its grid or Charades led
#   by less than 1.20: Devastator over a grid in steps of sqrt(2) around F1's
#   best W (with that W), one octave past it at an end (1.5 octaves where the
#   next W ran below 0.90 of the best); Charades' controller at F1's htram
#   settings beside it; F1's sizes and launches (run_phold.sh, CLCG4).
# 5 reps; arm and cell order reversed in even reps (and, in part D, which
# engine goes first); a warm-up run of each engine (not counted) starts each
# stream.
#   1. gate, 2 nodes: change tier (Simple PHOLD, traffic, dragonfly)
#   2. side by side: Devastator-grid streams D1a (node 0), D1b (node 1), D2
#      (nodes 2-3), D4 (nodes 4-7); Charades C4a (nodes 8-11), C4b (12-15)
#   3. D8 (nodes 0-7)
#   4. C16 (nodes 0-15)
# Submit the skx copy first: sbatch -p skx -N 16 -n 768 -x c455-081 gc258.slurm;
# then the skx-dev copy with --export=ALL,TWIN=<skx id>; then write the
# skx-dev id to $TWF.
# STUB=1 (login node, fake srun first in PATH, SLURM_JOB_ID and
# SLURM_JOB_NODELIST set): print every command, no gate.
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
STUB=${STUB:-0}
OUT=$W/charades-runs/gc258/j${SLURM_JOB_ID:-dry}; [ $STUB = 1 ] && OUT=$W/charades-runs/gc258/stub
mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
[ $STUB = 1 ] && export PATH=$W/charades-runs/f4b250/stubbin:$PATH   # its srun appends its command line to $STUBLOG
T=charades-r5; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh; D=$W/devastator; DB=$D/bin/ofi-psm2; RP=$D/run_phold.sh
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}"
log "charades $(git -C $C log --oneline -1 | cut -c1-60)"
[ "$(git -C $C rev-parse --short=7 HEAD)" = 85a2aad ] || { log "$T not at 85a2aad"; exit 1; }
grep -q "mb)   extra" $S || { log "ctl_sweep.sh lacks the mb arm"; exit 1; }
for b in $C/models/phold/simple/phold $C/models/traffic/traffic $C/models/dragonfly/dragonfly; do
  [ -x $b ] || { log "missing $b"; exit 1; }
  for s in ctl-reach-buckets "the base before and after" "PER-PE WITH A SHARED SPARE LIST"; do
    strings $b | grep -q "$s" || { log "$b lacks $s"; exit 1; }
  done
  ldd $b | grep -q charm-pads-perf/ || { log "$b does not link charm-pads-perf"; exit 1; }
done
for p in 2 4 8 16; do [ -x $DB/phold-gauss-p${p}w23 ] || { log "missing $DB/phold-gauss-p${p}w23"; exit 1; }; done
[ -f $RP ] || { log "missing $RP"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }

if [ $STUB = 1 ]; then
  # run_phold.sh refuses login nodes; the stub runs a copy without that one check
  sed '/not on a login node/d' $RP > $OUT/run_phold_stub.sh; RP=$OUT/run_phold_stub.sh
else
# TWIN (sbatch --export=ALL,TWIN=<job id>): the same job queued elsewhere. The
# copy that starts first runs and cancels the other; one that starts second exits.
# The first-submitted copy reads the other's ID from $TWF, written after both.
TWF=$W/charades-runs/gc258/gc258.twin
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

# ---- part C: F4b's workloads (f4b250.slurm cspec), refined grids
cspec() { # workload nodes -> "agg workload end bucket lps|fixed arms"
  local df=16:10 lo="w:250 w:300 w:350 w:400" g
  [ $2 = 16 ] && { df=28:14; lo="w:250 w:300 w:350 w:400 w:450"; }
  case $1 in
    la10)  echo "pp:512 gauss:10:200:500 512000 8 128|w:40 w:50 w:60 w:75 w:100" ;;      # F4b best 50 (grid 25/50/100/300)
    g100)  echo "pp:2048 gauss:100:1000:100 2048000 8 128|$lo" ;;                       # F4b best 300 (grid 100-400)
    g2000) echo "pp:512 gauss:100:1000:2000 2048000 8 128|$lo" ;;                       # F4b best 300; 300/400 level at 16 nodes
    uni)   echo "wps:512 steady:100:1000:1.0 2048000 8 128|w:250 w:300 w:350 w:400" ;;  # F4b best 300
    tr)    if [ $2 = 4 ]; then g="w:350 w:425 w:500 w:600"; else g="w:600 w:675 w:750 w:875"; fi
           echo "pp:2048 traffic:100:1000:64:16:0:0:3 6000000 8 64|$g" ;;               # F4b best 500 (the grid's bottom) / 750
    df)    echo "wps:512 dragonfly:$df:4:1:500:150000 160000000 1000 128|w:12500 w:15000 w:17500 w:20000" ;;  # F4b best 20,000
  esac; }
charades() { # workload nodes nodelist rep
  local spec fixed agg cw end bk lps
  spec=$(cspec $1 $2); fixed=${spec#*|}; read -r agg cw end bk lps <<< "${spec%%|*}"
  cs c_$1_r$4 $2 $3 $agg $cw "$(ord "$fixed mb:0" $4)" $end $bk $lps 180; }
cseries() { # stream nodes nodelist workloads...
  local s=$1 N=$2 nl=$3 rep wl; shift 3
  cs warm_$s $N $nl pp:2048 gauss:100:1000:100 w:300 512000 8 128 180
  for rep in 1 2 3 4 5; do
    for wl in $(ord "$*" $rep); do charades $wl $N $nl $rep; done
    log "$s REP $rep DONE"
  done; }

# ---- part D: F1's workloads (scale240.slurm spec) and Devastator launch
fspec() { # workload -> CW AGGS (Charades), LA MEAN SIG REM END (Devastator)
  LA=100; MEAN=1000; REM=0; END=2048000
  case $1 in
    g100)  CW=gauss:100:1000:100;  AGGS="pp:2048"; SIG=100 ;;
    g500)  CW=gauss:100:1000:500;  AGGS="pp:2048"; SIG=500 ;;
    g1000) CW=gauss:100:1000:1000; AGGS="pp:2048 pp:512"; SIG=1000 ;;
    g2000) CW=gauss:100:1000:2000; AGGS="pp:512";  SIG=2000 ;;
    g4000) CW=gauss:100:1000:4000; AGGS="pp:512";  SIG=4000 ;;
    uni)   CW=steady:100:1000:1.0; AGGS="pp:512 wps:512"; SIG=0; REM=1.0 ;;
    l10g500)  CW=gauss:10:200:500;  AGGS="pp:2048"; SIG=500;  LA=10; MEAN=200; END=512000 ;;
    l10g2000) CW=gauss:10:200:2000; AGGS="pp:512 wps:512"; SIG=2000; LA=10; MEAN=200; END=512000 ;;
  esac; }
dgrid() { # cell (workload_nodes) -> Devastator's W grid; F1's best W in the comment
  case $1 in
    g100_1)     echo 1000 1400 2000 2800 4000 ;;   # 2,000, the grid's top; 1,000 level with it
    g500_1)     echo 250 350 500 700 1000 ;;       # 500, the bottom; 1,000 at 0.99
    g1000_1)    echo 700 1000 1400 ;;              # 1,000; Charades ahead 1.13
    g2000_1)    echo 250 350 500 700 ;;            # 500, the bottom; 1,000 at 0.92
    g4000_1)    echo 175 250 350 500 700 ;;        # 500, the bottom; 1,000 at 0.89
    uni_1)      echo 175 250 350 500 700 ;;        # 500, the bottom; 1,000 at 0.84
    l10g500_1)  echo 50 70 100 140 200 ;;          # 100, the bottom; 200 level with it; Charades ahead 1.08
    l10g2000_1) echo 35 50 70 100 140 ;;           # 100, the bottom; 200 at 0.86
    g500_2)     echo 700 1000 1400 ;;              # 1,000; Charades ahead 1.19
    g4000_2)    echo 250 350 500 700 ;;            # 500, the bottom; 1,000 at 0.94
    uni_2)      echo 175 250 350 500 700 ;;        # 500, the bottom; 1,000 at 0.90
    l10g500_2)  echo 140 200 280 ;;                # 200; Charades ahead 1.09
    uni_4)      echo 250 350 500 700 ;;            # 500, the bottom; 1,000 at 0.92
    uni_8)      echo 250 350 500 700 1000 ;;       # 500, the bottom; 1,000 at 0.99
  esac; }
dv() { # tag nodes nodelist window stream (F1's dv)
  local db=$DB/phold-gauss-p$(($2 * 2))w23 extra=()
  [ "$REM" != 0 ] && extra=(--remote=$REM)
  ( export WINDOW=$4 RUNS=$OUT/n$2/deva_$5 LPS_PER_RANK=128 START=15 LOOKAHEAD=$LA MEAN=$MEAN SIGMA=$SIG END=$END CAP=200 AFFINITY=0 SRUN_EXTRA="-w $3"
    LABEL=$1 bash $RP $db $2 --rng=clcg4 "${extra[@]}" | head -1 | sed "s/^/n$2 /" | cut -c1-120 ); }
dcell() { # cell nodelist rep stream
  local c=$1 wl=${1%_*} N=${1##*_} nl=$2 rep=$3 s=$4 e a w
  fspec $wl
  for e in $(ord "c d" $rep); do
    if [ $e = c ]; then
      for a in $AGGS; do cs d_${c}_${a/:/}_r$rep $N $nl $a $CW mb:0 $END 8 128 150; done
    else
      for w in $(ord "$(dgrid $c)" $rep); do dv d_${c}_w${w}_r$rep $N $nl $w $s; done
    fi
  done; }
dseries() { # stream nodes nodelist cells...
  local s=$1 N=$2 nl=$3 rep c; shift 3
  fspec g100; cs warm_$s $N $nl pp:2048 $CW w:300 512000 8 128 150; dv warm_$s $N $nl 1000 $s
  for rep in 1 2 3 4 5; do
    for c in $(ord "$*" $rep); do dcell $c $nl $rep $s; done
    log "$s REP $rep DONE"
  done; }

# ---- 2. side by side
dseries D1a 1 ${NL[0]} g100_1 g500_1 g1000_1 g2000_1 > $OUT/stream_d1a.log 2>&1 &
dseries D1b 1 ${NL[1]} g4000_1 uni_1 l10g500_1 l10g2000_1 > $OUT/stream_d1b.log 2>&1 &
dseries D2 2 $(join ${NL[@]:2:2}) g500_2 g4000_2 uni_2 l10g500_2 > $OUT/stream_d2.log 2>&1 &
dseries D4 4 $(join ${NL[@]:4:4}) uni_4 > $OUT/stream_d4.log 2>&1 &
cseries C4a 4 $(join ${NL[@]:8:4}) la10 g100 g2000 > $OUT/stream_c4a.log 2>&1 &
cseries C4b 4 $(join ${NL[@]:12:4}) uni tr df > $OUT/stream_c4b.log 2>&1 &
wait
log "PHASE 2 DONE"
# ---- 3. Devastator grid at 8 nodes
dseries D8 8 $(join ${NL[@]:0:8}) uni_8 > $OUT/stream_d8.log 2>&1
log "PHASE 3 DONE"
# ---- 4. Charades grid at 16 nodes
cseries C16 16 $(join ${NL[@]:0:16}) la10 g100 g2000 uni tr df > $OUT/stream_c16.log 2>&1
log "PHASE 4 DONE"
grep -h -E ' (fail|stall) |status=(fail|stall)' $OUT/stream_*.log | grep -v warm_ | head -40
log "GC258 DONE"
