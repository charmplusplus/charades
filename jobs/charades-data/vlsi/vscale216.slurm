#!/bin/bash -l
#SBATCH -J vscale216
#SBATCH -t 01:00:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/vscale216_%j.out
# VLSI at 1-32 nodes with round 3 (charades RESULTS.md section 216): job VS
# (vscale212.slurm, section 212) with Charades on charades-r3 (round 3,
# sections 213 and 215), b19 x N, one copy per node, 5,000 cycles.
#   C3  Charades charades-r3, 1 x 46, --fossil-lazy=1 --batch=32, buckets of
#       2,500 ps: the controller (mb), W 2,500, W 5,000; and once per node
#       count W 2,500 with --gvt-trace=1 (gt)
#   C   Charades charades-perf (the tree of job a), same arms (group big2 only)
#   d2  Devastator 2 x 23, W 2,500 / 5,000 / 10,000 (every group)
#   d1, ROSS as in vscale212.slurm (group big2 only)
#   Layout check (group a2, the 1- and 4-node streams after their VLSI reps):
#   charades-r3 at 1 x 46 and 2 x 23 on sigma 100 (PP 2,048, W 300), uniform
#   (WPs 512, W 300), traffic (PP 2,048, W 500), dragonfly (WPs 512,
#   W 10,000), V5's sizes; 2 reps
# Engines interleaved per rep; engine and arm order reversed in even reps.
# First argument:
#   a2    16 nodes: the 8-, 4-, 2- and 1-node series side by side, then 16
#         nodes alone; 3 reps
#   big2  32 nodes, 5 reps (replaces job big, 3679725)
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 vscale216.slurm a2 (and skx)
#         sbatch -p skx -N 32 -n 1536 -x c455-081 -t 01:30:00 vscale216.slurm big2
set -u
G=${1:-a2}
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/vscale216/${G}_j${SLURM_JOB_ID:-dry}; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-perf; C=$W/$T; T3=charades-r3; C3=$W/$T3; D=$W/devastator; DB=$D/bin/ofi-psm2
RB=$W/ROSS/build/models; TV=$W/charades-vlsi
NETLIST=$W/I99T/i99t/b19/b19.bench
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry} group $G; nodes ${NL[*]:-none}"
log "charades $(git -C $C log --oneline -1 | cut -c1-60); charades-r3 $(git -C $C3 log --oneline -1 | cut -c1-60); ROSS $(git -C $W/ROSS log --oneline -1 | cut -c1-20)"
strings $C/models/vlsi/vlsi | grep -q "fossil-lazy" || { log "$C vlsi lacks --fossil-lazy"; exit 1; }
for m in vlsi/vlsi phold/simple/phold traffic/traffic dragonfly/dragonfly; do
  strings $C3/models/$m | grep -q "direct-execute" || { log "$C3 $m lacks round 3"; exit 1; }
  ldd $C3/models/$m | grep -q charm-pads-perf/ || { log "$C3 $m does not link charm-pads-perf"; exit 1; }
done
grep -q "gvt_trace.csv logs" $C3/scripts/stampede3/ctl_sweep.sh || { log "$C3 ctl_sweep.sh does not keep gvt_trace.csv"; exit 1; }
ldd $C/models/vlsi/vlsi | grep -q charm-pads-perf/ || { log "$T does not link charm-pads-perf"; exit 1; }
strings $RB/vlsi/vlsi | grep -q "layout-bins" || { log "ROSS vlsi lacks the balanced layout"; exit 1; }
if [ $G = big2 ]; then NS="32"; else NS="1 2 4 8 16"; fi
for n in $NS; do [ -x $DB/vlsi-p$((2 * n))w23 ] || { log "missing $DB/vlsi-p$((2 * n))w23"; exit 1; }; done
for b in $NETLIST $RB/vlsi/vlsi $TV/models/vlsi/vlsi.h; do [ -e $b ] || { log "missing $b"; exit 1; }; done
MISSING=""; for n in $NS; do [ -x $DB/vlsi-p${n}w46 ] || MISSING="$MISSING $n:46"; done
log "Devastator 1 x 46 binaries to build:${MISSING:- none}"
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }

# ---- Devastator's missing 1 x 46 binaries, on the last node, in the background
if [ -n "$MISSING" ]; then
  ssh -o StrictHostKeyChecking=no ${NL[-1]} "WORK=$W CXX_PPFLAGS=-I$TV/models/vlsi BENCHES=vlsi LAYOUTS='${MISSING# }' STOCK=0 PAR=0 bash -l $D/build_stampede3.sh ofi-psm2" > $OUT/deva_build.txt 2>&1 \
    && touch $OUT/deva_built || touch $OUT/deva_build_failed &
  log "Devastator build of$MISSING started on ${NL[-1]}"
else touch $OUT/deva_built; fi

# ---- gate: the change tier on 2 nodes, VLSI, lazy fossils (charades-r3)
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C3/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $C3/tests; export CHARADES_RUN_ARGS="+mempool_remote_free --fossil-lazy=1"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model VLSI \
    agg_ctl_measured_fast_bucket_pp bucket_window ctl_measured_bucket > $OUT/gate.txt 2>&1 )
tail -3 $OUT/gate.txt
grep -q "Failed: *0/" $OUT/gate.txt && grep -q "Timed out: *0/" $OUT/gate.txt || { log "GATE FAILED"; exit 1; }
log "GATE DONE"

export PPN=1 PEPP=46 CPT=48 CAP=300 VLSI_NETLISTS=$W/I99T/i99t
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1 --commit-digest=1 --copy-stats=1 --fossil-lazy=1 --batch=32"
V_END=12500000 CAPX=300 CAPR=240
cs() { # tag nodes nodelist arms [end] [tree] [extra flags]
  local tree=${6:-$T3}
  ( export TREE=$tree NODES=$2 AGG=off WORKLOADS=vlsi:b19:1:1 ARMS="$4" END=${5:-$V_END} BUCKETS=2500 LPC=128 LPS_PER_PE=128 \
      EXTRA_ARGS="$L ${7:-}" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $W/$tree/scripts/stampede3/ctl_sweep.sh 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" )
  rm -f $OUT/n$2/$1/ctl_sweep/logs/*.digest.csv; }
LB="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1"
csb() { # tag nodes nodelist procs:PEs:cores agg workload arms end bucket lps_per_pe [extra flags]
  local ppn pepp cpt; IFS=: read -r ppn pepp cpt <<< "$4"
  ( export TREE=$T3 NODES=$2 PPN=$ppn PEPP=$pepp CPT=$cpt AGG=$5 WORKLOADS="$6" ARMS="$7" END=$8 BUCKETS=$9 LPS_PER_PE=${10} LPC=16 \
      EXTRA_ARGS="$LB ${11:-}" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $C3/scripts/stampede3/ctl_sweep.sh 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" )
  rm -f $OUT/n$2/$1/ctl_sweep/logs/*.digest.csv; }
wl() { # workload nodes -> agg spec end bucket lps_per_pe W digest-flag (V5's)
  case $1 in
    g100)    echo "pp:2048 gauss:100:1000:100 2048000 8 128 300 -" ;;
    uni)     echo "wps:512 steady:100:1000:1.0 2048000 8 128 300 -" ;;
    traffic) echo "pp:2048 traffic:100:1000:64:16:0:0:3 6000000 8 64 500 --commit-digest=1" ;;
    df)      if [ $2 = 1 ]; then s=13:4; else s=16:10; fi
             echo "wps:512 dragonfly:$s:4:1:500:150000 160000000 1000 128 10000 --commit-digest=1" ;;
  esac; }
layout() { # nodes nodelist: round 3 at 1 x 46 against 2 x 23 on the other workloads, 2 reps
  local N=$1 nl=$2 rep w lay agg spec end bk lps win dg
  for rep in 1 2; do
    for w in $([ $rep = 1 ] && echo "g100 uni traffic df" || echo "df traffic uni g100"); do
      read -r agg spec end bk lps win dg <<< "$(wl $w $N)"; [ "$dg" = - ] && dg=
      for lay in $([ $rep = 1 ] && echo "1:46:48 2:23:24" || echo "2:23:24 1:46:48"); do
        csb L_${w}_p${lay%%:*}_r$rep $N $nl $lay $agg $spec w:$win $end $bk $lps "$dg"
      done
    done
    log "N $N LAYOUT REP $rep DONE"
  done; }
skipped() { [ -e $OUT/n$1/skip_$2 ]; }
dv() { # tag(d1|d2) nodes nodelist window rep
  local tag=$1 N=$2 nl=$3 w=$4 rep=$5 ppn wk f=$OUT/n$2/deva/$1_w$4_r$5.out
  [ $tag = d1 ] && { ppn=1; wk=46; } || { ppn=2; wk=23; }
  local p=$((ppn * N)) bin=$DB/vlsi-p$((ppn * N))w$wk
  skipped $N dv_${tag}_$w && { echo "n$N dv $tag W $w r$rep skipped"; return; }
  if [ $tag = d1 ]; then
    while [ ! -e $OUT/deva_built ] && [ ! -e $OUT/deva_build_failed ]; do sleep 10; done
  fi
  [ -x $bin ] || { echo "n$N dv $tag r$rep: no binary $bin"; return; }
  mkdir -p $OUT/n$N/deva
  ( export GASNET_BACKTRACE=1 GASNET_OFI_SPAWNER=pmi FI_PROVIDER=psm2 deva_static_look_dt=$w; unset FI_PROVIDER_PATH
    [ $tag = d1 ] && export HFI_NO_CPUAFFINITY=1
    t0=$(date +%s.%N)
    timeout -s TERM $CAPX srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -J dv_${tag}_n$N -w $nl -N $N -n $p \
      --ntasks-per-node=$ppn -c $((48 / ppn)) --cpu-bind=cores -m block:block \
      stdbuf -oL $bin --netlist=$NETLIST --copies=$N --span=1 --chunk=512 --end-time=$V_END > $f 2>&1
    rc=$?; wall=$(printf %.1f "$(echo "$(date +%s.%N) - $t0" | bc)")
    line=$(grep -m1 '^VLSI_RESULT' $f)
    v() { tr ' ' '\n' <<< "$line" | sed -n "s/^$1=//p"; }
    st=ok; [ -z "$line" ] && st=fail; [ $rc = 124 ] && st=stall
    [ $st = stall ] && [ $rep = 1 ] && touch $OUT/n$N/skip_dv_${tag}_$w
    echo "engine=deva app=vlsi nodes=$N layout=p${p}w$wk window=$w rep=$rep arm=$tag status=$st rc=$rc wall=$wall committed=$(v committed) executed=$(v executed) rolled_back=$(v rolled_back) gate_changes=$(v gate_changes) run_s=$(v wall_s) M_ev_s=$(awk -v r="$(v committed_per_s)" 'BEGIN{if (r != "") printf "%.2f", r / 1e6}') deterministic=$(v deterministic)" \
      | tee -a $OUT/deva.txt | sed "s/^/n$N /" | cut -c1-200 )
}
ross() { # tag nodes nodelist batch gvt_interval max_opt_lookahead rep
  local tag=$1 N=$2 nl=$3 ba=$4 gi=$5 ml=$6 rep=$7 f=$OUT/n$2/ross/$1_r$7.out
  skipped $N ross_$tag && { echo "n$N ross $tag r$rep skipped"; return; }
  mkdir -p $OUT/n$N/ross
  ( module load mvapich/3.0 >/dev/null 2>&1
    unset FI_PROVIDER FI_PROVIDER_PATH LCI_ATTR_BACKEND LCI_ATTR_OFI_PROVIDER_NAME LCI_ATTR_PACKET_SIZE PSM2_MULTI_EP
    t0=$(date +%s.%N)
    timeout -s TERM $CAPR srun --mpi=pmi2 --kill-on-bad-exit=1 -J ross_${tag}_n$N -w $nl -N $N -n $((46 * N)) --ntasks-per-node=46 \
      $RB/vlsi/vlsi --synch=3 --read-buffer=1 --extramem=800000 --batch=$ba --gvt-interval=$gi --max-opt-lookahead=$ml \
      --netlist=$NETLIST --copies=$N --span=1 --end=$V_END > $f 2>&1
    rc=$?; wall=$(printf %.1f "$(echo "$(date +%s.%N) - $t0" | bc)")
    st=ok; grep -q 'Net Events Processed' $f || st=fail; [ $rc = 124 ] && st=stall
    [ $st = stall ] && [ $rep = 1 ] && touch $OUT/n$N/skip_ross_$tag
    echo "engine=ross app=vlsi nodes=$N rep=$rep arm=$tag status=$st rc=$rc wall=$wall committed=$(awk '/Net Events Processed/{print $NF; exit}' $f) M_ev_s=$(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' $f) efficiency=$(awk '/Efficiency/{print $(NF-1); exit}' $f) gate_changes=$(awk -F. '/Gate output changes/{print $NF; exit}' $f) run_s=$(awk '/Running Time/{print $(NF-1); exit}' $f)" \
      | tee -a $OUT/ross.txt | sed "s/^/n$N /" | cut -c1-200 )
}
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
ord() { [ $((rep % 2)) = 1 ] && echo "$1" || rev "$1"; }
engines() { # nodes nodelist rep
  local N=$1 nl=$2 rep=$3 e w s t ba gi ml
  for e in $(ord "$ENGINES"); do
    case $e in
      charades) cs C3_r$rep $N $nl "$(ord 'mb:0 w:2500 w:5000')"
                [ $G = big2 ] && cs C_r$rep $N $nl "$(ord 'mb:0 w:2500 w:5000')" $V_END $T ;;
      devastator) for t in $(ord "$DV"); do for w in $(ord '2500 5000 10000'); do dv $t $N $nl $w $rep; done; done ;;
      ross) for s in $(ord 'b8m2500:8:64:2500 b8m5000:8:64:5000 b2m5000:2:64:5000'); do
              IFS=: read -r t ba gi ml <<< "$s"; ross $t $N $nl $ba $gi $ml $rep; done ;;
    esac
  done; }
stream() { # nodes nodelist reps
  local N=$1 nl=$2 reps=$3
  cs warm $N $nl w:2500 1250000
  for rep in $(seq $reps); do engines $N $nl $rep; log "N $N REP $rep DONE"; done
  # once per node count: W 2,500 with --gvt-trace=1 (count waves, for the cycle's split)
  cs C3gt $N $nl w:2500 $V_END $T3 --gvt-trace=1
  if [ $G = a2 ] && { [ $N = 1 ] || [ $N = 4 ]; }; then layout $N $nl; fi; }
if [ $G = big2 ]; then ENGINES="charades devastator ross"; DV="d2 d1"; else ENGINES="charades devastator"; DV="d2"; fi
if [ $G = big2 ]; then
  # the build node is in the 32-node runs: no run starts while it compiles
  while [ ! -e $OUT/deva_built ] && [ ! -e $OUT/deva_build_failed ]; do sleep 10; done
  stream 32 $(join ${NL[@]:0:32}) 5 > $OUT/stream_n32.log 2>&1
  log "32 DONE"
else
  stream 8 $(join ${NL[@]:0:8}) 3 > $OUT/stream_n8.log 2>&1 &
  stream 4 $(join ${NL[@]:8:4}) 3 > $OUT/stream_n4.log 2>&1 &
  stream 2 $(join ${NL[@]:12:2}) 3 > $OUT/stream_n2.log 2>&1 &
  stream 1 ${NL[14]} 3 > $OUT/stream_n1.log 2>&1 &
  wait
  log "1/2/4/8 DONE"
  stream 16 $(join ${NL[@]:0:16}) 3 > $OUT/stream_n16.log 2>&1
  log "16 DONE"
fi
grep -h -E ' (fail|stall) |status=(fail|stall)' $OUT/stream_n*.log | head -20
log "VSCALE216 $G DONE"
