#!/bin/bash -l
#SBATCH -J s64_262
#SBATCH -t 04:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/s64_262_%j.out
# Jobs P64 and A64 (charades results/phold.md section 262; user decision
# 2026-11-08: run 64 nodes). The paper's tables at 64 nodes, three engines,
# one 64-node stream (as F1-32, F5-32b and V32b ran their 32-node streams),
# 5 reps, tree charades-r5 (85a2aad), the paper launch, no diagnostics in any
# timing arm. First argument:
#   p  P64, PHOLD: F1's eight workloads and sigma 1,000 with PP 512 (Charades
#      only), F1's arms (scale240.slurm) with:
#        Charades fixed W 300 / 400 / 500 (lookahead 10: 50 / 75 / 100) beside
#          the controller (F1: 300 / 400 and 50 / 100; job AG32 found W 400
#          and W 75 best at 32 nodes, section 257), F1's htram settings;
#          direct sends at W 300 and 400 on uniform and sigma 4,000 (bundling
#          at 64 nodes; AG32's best direct W was 300)
#        Devastator W 500 / 1,000 / 2,000 / 4,000 (lookahead 10: 100 / 200 /
#          400), as F1-32
#        ROSS optimistic, conservative, and optimistic with its window
#          (f1_240/ross_windows.txt), as F1
#   a  A64, applications: traffic and dragonfly with F5's arms
#      (f5scale240.slurm) and VLSI with V32b's (vscale240.slurm), with:
#        dragonfly's 64-node shape a = 46, h = 22 (1,013 groups, 46,598
#          routers, 15.83 per PE, most-loaded PE / mean 1.011; 32 nodes:
#          a = 36, h = 18, 15.9 per PE)
#        Charades dragonfly W 15,000 beside 10,000 / 20,000 (job GC, section
#          259: W 15,000 4.5-4.8% over 20,000); traffic W 1,500 beside 500 /
#          1,000 (AG32: W 1,000 best at 32 nodes)
#        check arms: dg (--commit-digest=1) at F5's best fixed W for the
#          digest check, and VLSI G:w5000 (--commit-digest=1); F5's od/ri and
#          V32b's O/R are left out
#      apps in reverse order in even reps, as the engines and arms
# The first runs of each engine at 64 nodes (Devastator's p128w23 builds and
# ROSS at 2,944 ranks have never run): a short warm-up run of each engine;
# if Charades' fails the job stops, if Devastator's or ROSS's fails that
# engine is dropped from the job. An arm of Devastator or ROSS that hits its
# cap in rep 1 is skipped after (caps: Devastator 200 s on PHOLD, 400 s on
# the applications; ROSS 480 s on PHOLD, 400 s on the applications; F1 and F5:
# 200, 360 and 300 s; the longest 32-node run took 147 s).
# Submit: sbatch -p skx -N 64 -n 3072 -x c455-081 -t 04:30:00 s64_262.slurm p
#         sbatch -p skx -N 64 -n 3072 -x c455-081 -t 02:45:00 s64_262.slurm a
# Allocation: about 3.1 h (p) and 1.6 h (a) at 64 nodes, 300 node-hours.
# STUB=1 (login node, fake srun first in PATH, SLURM_JOB_ID and
# SLURM_JOB_NODELIST set): print every command, no gate.
set -u
G=${1:-p}; case $G in p|a) ;; *) echo "mode p or a"; exit 1 ;; esac
W=/work2/09863/rrao/stampede3; export WORK=$W
STUB=${STUB:-0}
OUT=$W/charades-runs/s64_262/${G}_j${SLURM_JOB_ID:-dry}; [ $STUB = 1 ] && OUT=$W/charades-runs/s64_262/stub_$G
mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
[ $STUB = 1 ] && export PATH=$W/charades-runs/f4b250/stubbin:$PATH   # its srun appends its command line to $STUBLOG
T=charades-r5; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh; D=$W/devastator; DB=$D/bin/ofi-psm2; RP=$D/run_phold.sh
RBP=$W/ROSS/build/models/phold-gauss/phold-gauss; RBM=$W/ROSS/build/models
RWF=$W/charades-runs/f1_240/ross_windows.txt; NETLIST=$W/I99T/i99t/b19/b19.bench
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
N=64; NL64=$(join ${NL[@]:0:64})
log "job ${SLURM_JOB_ID:-dry} mode $G; nodes ${NL[*]:-none}"
log "charades $(git -C $C log --oneline -1 | cut -c1-60); ROSS $(git -C $W/ROSS log --oneline -1 | cut -c1-20); devastator $(git -C $D/devastator log --oneline -1 2>/dev/null | cut -c1-20)"
[ "$(git -C $C rev-parse --short=7 HEAD)" = 85a2aad ] || { log "$T not at 85a2aad"; exit 1; }
grep -q "mb)   extra" $S || { log "ctl_sweep.sh lacks the mb arm"; exit 1; }
if [ $G = p ]; then BINS="$C/models/phold/simple/phold"; else BINS="$C/models/traffic/traffic $C/models/dragonfly/dragonfly $C/models/vlsi/vlsi"; fi
for b in $BINS; do
  [ -x $b ] || { log "missing $b"; exit 1; }
  for s in ctl-reach-buckets "the base before and after" "PER-PE WITH A SHARED SPARE LIST"; do
    strings $b | grep -q "$s" || { log "$b lacks $s"; exit 1; }
  done
  ldd $b | grep -q charm-pads-perf/ || { log "$b does not link charm-pads-perf"; exit 1; }
done
if [ $G = p ]; then
  [ -x $DB/phold-gauss-p128w23 ] || { log "missing $DB/phold-gauss-p128w23"; exit 1; }
  [ -x $RBP ] && strings $RBP | grep -q max-opt-lookahead || { log "ROSS phold-gauss missing or lacks --max-opt-lookahead"; exit 1; }
  [ -f $RP ] && [ -f $RWF ] || { log "missing $RP or $RWF"; exit 1; }
else
  for b in $DB/{traffic,dragonfly,vlsi}-p128w23 $RBM/traffic/traffic $RBM/dragonfly/dragonfly; do [ -x $b ] || { log "missing $b"; exit 1; }; done
  strings $C/models/dragonfly/dragonfly | grep -q "Commit Digest" || { log "dragonfly lacks --commit-digest"; exit 1; }
  [ -e $NETLIST ] || { log "missing $NETLIST"; exit 1; }
fi
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }
[ ${#NL[@]} -ge $N ] || { log "need $N nodes, got ${#NL[@]}"; exit 1; }

gate() { # output file, then test.py's model and config arguments
  local f=$1; shift
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
    python3 test.py --tier change --no-build --launcher srun --nodes 2 "$@" > $f 2>&1 )
  tail -4 $f; grep -E "FAIL|TIMEOUT" $f | head
  grep -q "Failed: *0/" $f && grep -q "Timed out: *0/" $f && grep -q "Passed: *[1-9]" $f; }
gate2() { # name, then test.py's arguments: once more if the only failures are /work2 read errors
  local g=$1; shift
  gate $OUT/gate_$g.txt "$@" && return 0
  local bad=$(grep -E "FAIL|TIMEOUT" $OUT/gate_$g.txt | awk '{print $NF}' | grep "test.out$")
  if [ -n "$bad" ] && [ -z "$(for f in $bad; do grep -L "Input/output error" $f; done)" ]; then
    log "GATE $g: /work2 read errors only; rerunning"; gate $OUT/gate_${g}2.txt "$@"
  else return 1; fi; }
if [ $STUB = 1 ]; then
  # run_phold.sh refuses login nodes; the stub runs a copy without that one check
  sed '/not on a login node/d' $RP > $OUT/run_phold_stub.sh; RP=$OUT/run_phold_stub.sh
elif [ $G = p ]; then
  gate2 phold --model "Simple PHOLD" agg_deadline_bucket_pp agg_inputbuf_bucket_wps bucket_window agg_bucket_pp agg_ctl_measured_bucket_pp ctl_measured_bucket || { log "GATE FAILED"; exit 1; }
  log "GATE DONE"
else
  gate2 apps --model Dragonfly --model Traffic agg_ctl_measured_fast_bucket_pp agg_deadline_bucket_wps bucket_window ctl_measured_bucket || { log "GATE FAILED"; exit 1; }
  gate2 vlsi --model VLSI agg_ctl_measured_fast_bucket_pp bucket_window ctl_measured_bucket || { log "GATE FAILED"; exit 1; }
  log "GATE DONE"
fi

export TREE=$T PPN=2 PEPP=23 CPT=24 LPC=16
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
cs() { # tag agg workload arms end bucket lps_per_pe cap [extra Charades flags]
  ( export NODES=$N AGG=$2 WORKLOADS="$3" ARMS="$4" END=$5 BUCKETS=$6 LPS_PER_PE=$7 CAP=$8 \
      EXTRA_ARGS="$L ${9:-}" SRUN_ARGS="-w $NL64"
    RUNS=$OUT/n$N/$1 $S 1 $OUT/n$N/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$N $1 /" )
  rm -f $OUT/n$N/$1/ctl_sweep/logs/*.digest.csv $OUT/n$N/$1/ctl_sweep/gvt_*.out; }
csok() { [ $STUB = 1 ] || tail -n +2 $OUT/n$N/$1.csv 2>/dev/null | cut -d, -f11 | grep -qx ok; }   # tag: its run finished
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
ord() { [ $(($2 % 2)) = 1 ] && echo "$1" || rev "$1"; }   # list rep: reversed in even reps
skipped() { [ -e $OUT/n$N/skip_$1 ]; }
ENGINES="charades devastator ross"
drop() { ENGINES=$(echo $ENGINES | tr ' ' '\n' | grep -vx $1 | tr '\n' ' '); log "$1 FAILED ITS 64-NODE WARM-UP: dropped (engines: $ENGINES)"; }

# ---- P64: F1 (scale240.slurm) at 64 nodes
f1spec() {
  ARMS="mb:0 w:300 w:400 w:500"; DW="500 1000 2000 4000"; RWD="1000 2000"; LA=100; MEAN=1000; REM=0; END=2048000; CH_ONLY=0; DIRECT=0
  case $1 in
    g100)  CW=gauss:100:1000:100;  AGGS="pp:2048"; SIG=100 ;;
    g500)  CW=gauss:100:1000:500;  AGGS="pp:2048"; SIG=500 ;;
    g1000) CW=gauss:100:1000:1000; AGGS="pp:2048"; SIG=1000 ;;
    g1000x) CW=gauss:100:1000:1000; AGGS="pp:512"; SIG=1000; CH_ONLY=1 ;;
    g2000) CW=gauss:100:1000:2000; AGGS="pp:512";  SIG=2000 ;;
    g4000) CW=gauss:100:1000:4000; AGGS="pp:512";  SIG=4000; DIRECT=1 ;;
    uni)   CW=steady:100:1000:1.0; AGGS="pp:512 wps:512"; SIG=0; REM=1.0; DIRECT=1 ;;
    l10g500)  CW=gauss:10:200:500;  AGGS="pp:2048"; SIG=500;  LA=10; MEAN=200; END=512000; ARMS="mb:0 w:50 w:75 w:100"; DW="100 200 400"; RWD="200 400" ;;
    l10g2000) CW=gauss:10:200:2000; AGGS="pp:512 wps:512"; SIG=2000; LA=10; MEAN=200; END=512000; ARMS="mb:0 w:50 w:75 w:100"; DW="100 200 400"; RWD="200 400" ;;
  esac; }
f1dv() { # tag window rep runs_subdir
  local tag=$1 w=$2 rep=$3 sub=${4:-deva} extra=()
  skipped dv_${tag%_r*} && { echo "n$N $tag skipped"; return; }
  [ "$REM" != 0 ] && extra=(--remote=$REM)
  ( export WINDOW=$w RUNS=$OUT/n$N/$sub LPS_PER_RANK=128 START=15 LOOKAHEAD=$LA MEAN=$MEAN SIGMA=$SIG END=$END CAP=200 AFFINITY=0 SRUN_EXTRA="-w $NL64"
    LABEL=$tag bash $RP $DB/phold-gauss-p$((2 * N))w23 $N --rng=clcg4 "${extra[@]}" | head -1 | sed "s/^/n$N /" | cut -c1-120 )
  [ $rep = 1 ] && grep -q "^label=$tag .*status=stall" $OUT/n$N/$sub/results.txt 2>/dev/null && touch $OUT/n$N/skip_dv_${tag%_r*}; }
f1ross() { # tag synch batch gvt_interval max_opt_lookahead (0 = none) rep
  local tag=$1 n=$((N * 46)) f=$OUT/n$N/ross/$1.out mo="" rc
  skipped ross_${tag%_r*} && { echo "n$N $tag skipped"; return; }
  mkdir -p $OUT/n$N/ross
  [ $5 != 0 ] && mo="--max-opt-lookahead=$5"
  ( module load mvapich/3.0 >/dev/null 2>&1
    unset FI_PROVIDER FI_PROVIDER_PATH LCI_ATTR_BACKEND LCI_ATTR_OFI_PROVIDER_NAME LCI_ATTR_PACKET_SIZE PSM2_MULTI_EP
    timeout -s TERM 480 srun --mpi=pmi2 --kill-on-bad-exit=1 -J ross_$tag -w $NL64 -N $N -n $n --ntasks-per-node=46 \
      $RBP --synch=$2 --read-buffer=1 --start-events=15 --sigma=$SIG --remote=$REM \
      --extramem=800000 --num-lps=$((n * 128)) --lookahead=$LA --mean=$MEAN --end=$END \
      --batch=$3 --gvt-interval=$4 $mo > $f 2>&1
    rc=$?
    echo "label=$tag nodes=$N synch=$2 batch=$3 gvt_interval=$4 window=$5 rc=$rc committed=$(awk '/Net Events Processed/{print $NF; exit}' $f) M_ev_s=$(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' $f) efficiency=$(awk '/Efficiency/{print $(NF-1); exit}' $f) running_s=$(awk '/Running Time/{print $(NF-1); exit}' $f)" | tee -a $OUT/n$N/ross/results.txt | sed "s/^/n$N /" )
  [ $6 = 1 ] && grep -q "^label=$tag .*rc=124 " $OUT/n$N/ross/results.txt && touch $OUT/n$N/skip_ross_${tag%_r*}; }
rwin() { local w=$(awk -v k=$1 '$1 == k {print $2}' $RWF 2>/dev/null); if [ -n "$w" ]; then echo $w; else echo "$RWD"; fi; }
p64cell() { # workload rep
  local wl=$1 rep=$2 e a w
  f1spec $wl
  for e in $(ord "$ENGINES" $rep); do
    case $e in
      charades)
        for a in $(ord "$AGGS" $rep); do cs ${wl}_${a/:/}_r$rep $a $CW "$(ord "$ARMS" $rep)" $END 8 128 150; done
        [ $DIRECT = 1 ] && cs ${wl}_off_r$rep off $CW "$(ord 'w:300 w:400' $rep)" $END 8 128 150 ;;
      devastator) [ $CH_ONLY = 1 ] || for w in $(ord "$DW" $rep); do f1dv ${wl}_w${w}_r$rep $w $rep; done ;;
      ross) if [ $CH_ONLY = 0 ]; then
              f1ross ${wl}_opt_r$rep 3 16 64 0 $rep
              f1ross ${wl}_cons_r$rep 2 16 16 0 $rep
              for w in $(rwin ${wl%x}); do [ $w != 0 ] && f1ross ${wl}_optw${w}_r$rep 3 16 64 $w $rep; done
            fi ;;
    esac
  done; }

# ---- A64: F5 (f5scale240.slurm) and VLSI (vscale240.slurm) at 64 nodes
ROSS_DF="w2500:3:2:64:2500 w5000:3:2:64:5000 w7500:3:2:64:7500"
ROSS_TR="w1000:3:64:64:1000 w2000:3:64:64:2000 cons:2:16:16:0"
TR_END=12000000 DF_END=310000000 DF_GEN=300000 V_END=12500000 CAPX=400 DFA=46 DFH=22
margs() { # model: arguments shared by ROSS and Devastator
  if [ $1 = traffic ]; then
    echo "--num-x=64 --num-y=$((46 * N)) --total-cars=$((46 * N * 64 * 16)) --lookahead=100 --mean=1000 --trip-radius=3"
  else
    echo "--routers-per-group=$DFA --global-channels=$DFH --terminals-per-router=4 --traffic=1 --routing=0 --arrive-rate=500 --gen-time=$DF_GEN"
  fi; }
f5dv() { # tag model window rep
  local tag=$1 m=$2 w=$3 rep=$4 f=$OUT/n$N/deva_f5/$1_r$4.out end st
  skipped dv_$tag && { echo "n$N dv $tag r$rep skipped"; return; }
  mkdir -p $OUT/n$N/deva_f5
  [ $m = traffic ] && end=$TR_END || end=$DF_END
  ( export GASNET_BACKTRACE=1 GASNET_OFI_SPAWNER=pmi FI_PROVIDER=psm2 deva_static_look_dt=$w; unset FI_PROVIDER_PATH
    t0=$(date +%s.%N)
    timeout -s TERM $CAPX srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -J dv_${tag}_n$N -w $NL64 -N $N -n $((2 * N)) \
      --ntasks-per-node=2 -c 24 --cpu-bind=cores -m block:block \
      stdbuf -oL $DB/$m-p$((2 * N))w23 $(margs $m) --end-time=$end --rng=clcg4 > $f 2>&1
    rc=$?; wall=$(printf %.1f "$(echo "$(date +%s.%N) - $t0" | bc)")
    line=$(grep -m1 -E '^(TRAFFIC|DRAGONFLY)_RESULT' $f)
    v() { tr ' ' '\n' <<< "$line" | sed -n "s/^$1=//p"; }
    st=ok; [ -z "$line" ] && st=fail; [ $rc = 124 ] && st=stall
    [ $st = stall ] && [ $rep = 1 ] && touch $OUT/n$N/skip_dv_$tag
    echo "engine=deva app=$m nodes=$N rep=$rep arm=$w status=$st rc=$rc wall=$wall committed=$(v committed) executed=$(v executed) rolled_back=$(v rolled_back) run_s=$(v wall_s) M_ev_s=$(awk -v r="$(v committed_per_s)" 'BEGIN{if (r != "") printf "%.2f", r / 1e6}') deterministic=$(v deterministic)" \
      | tee -a $OUT/deva_f5.txt | sed "s/^/n$N /" | cut -c1-200 ); }
f5ross() { # tag model synch batch gvt_interval rep max_opt_lookahead (0 = none)
  local tag=$1 m=$2 rep=$6 f=$OUT/n$N/ross_f5/$1_r$6.out end mo=""
  [ "${7:-0}" != 0 ] && mo="--max-opt-lookahead=$7"
  skipped ross_$tag && { echo "n$N ross $tag r$rep skipped"; return; }
  mkdir -p $OUT/n$N/ross_f5
  [ $m = traffic ] && end=$TR_END || end=$DF_END
  ( module load mvapich/3.0 >/dev/null 2>&1
    unset FI_PROVIDER FI_PROVIDER_PATH LCI_ATTR_BACKEND LCI_ATTR_OFI_PROVIDER_NAME LCI_ATTR_PACKET_SIZE PSM2_MULTI_EP
    t0=$(date +%s.%N)
    timeout -s TERM $CAPX srun --mpi=pmi2 --kill-on-bad-exit=1 -J ross_${tag}_n$N -w $NL64 -N $N -n $((46 * N)) --ntasks-per-node=46 \
      $RBM/$m/$m --synch=$3 --read-buffer=1 --extramem=800000 --batch=$4 --gvt-interval=$5 $mo $(margs $m) --end=$end > $f 2>&1
    rc=$?; wall=$(printf %.1f "$(echo "$(date +%s.%N) - $t0" | bc)")
    st=ok; grep -q 'Net Events Processed' $f || st=fail; [ $rc = 124 ] && st=stall
    [ $st = stall ] && [ $rep = 1 ] && touch $OUT/n$N/skip_ross_$tag
    echo "engine=ross app=$m nodes=$N rep=$rep arm=$tag window=${7:-0} status=$st rc=$rc wall=$wall committed=$(awk '/Net Events Processed/{print $NF; exit}' $f) M_ev_s=$(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' $f) efficiency=$(awk '/Efficiency/{print $(NF-1); exit}' $f) run_s=$(awk '/Running Time/{print $(NF-1); exit}' $f)" \
      | tee -a $OUT/ross_f5.txt | sed "s/^/n$N /" | cut -c1-200 ); }
vopt() { case $1 in E) echo "" ;; L) echo "--fossil-lazy=1" ;; G) echo "--commit-digest=1" ;; esac; }
vcs() { # rep setting arm [end]: VLSI, 1 x 46, one run per ctl_sweep call
  local rep=$1 s=$2 a=$3 end=${4:-$V_END}
  local arm=$(echo $a | sed -E 's/^(w|mb)([0-9]+)$/\1:\2/')
  local d=$OUT/n$N/vlsi/$rep/${s}_$a; mkdir -p $OUT/n$N/vlsi/$rep
  ( export NODES=$N AGG=off WORKLOADS=vlsi:b19:1:1 ARMS="$arm" END=$end BUCKETS=2500 LPC=128 LPS_PER_PE=128 CAP=300 \
      PPN=1 PEPP=46 CPT=48 VLSI_NETLISTS=$W/I99T/i99t EXTRA_ARGS="$L --batch=32 $(vopt $s)" SRUN_ARGS="-w $NL64"
    RUNS=$d $S 1 $d.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$N vlsi $rep $s /" )
  [ $STUB = 1 ] && return 0
  [ "$(tail -n +2 $d.csv | cut -d, -f10 | tr '\n' ' ')" = "$arm " ] || { log "WRONG ARMS in $d.csv"; return 1; }
  rm -f $d/ctl_sweep/logs/*.digest.csv $d/ctl_sweep/gvt_*.out; }
vdv() { # window rep: Devastator 2 x 23, as V32b
  local w=$1 rep=$2 p=$((2 * N)) f=$OUT/n$N/deva_vlsi/w$1_r$2.out
  skipped dv_vlsi_$w && { echo "n$N dv vlsi W $w r$rep skipped"; return; }
  mkdir -p $OUT/n$N/deva_vlsi
  ( export GASNET_BACKTRACE=1 GASNET_OFI_SPAWNER=pmi FI_PROVIDER=psm2 deva_static_look_dt=$w; unset FI_PROVIDER_PATH
    t0=$(date +%s.%N)
    timeout -s TERM $CAPX srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -J dv_vlsi_n$N -w $NL64 -N $N -n $p \
      --ntasks-per-node=2 -c 24 --cpu-bind=cores -m block:block \
      stdbuf -oL $DB/vlsi-p${p}w23 --netlist=$NETLIST --copies=$N --span=1 --chunk=512 --end-time=$V_END > $f 2>&1
    rc=$?; wall=$(printf %.1f "$(echo "$(date +%s.%N) - $t0" | bc)")
    line=$(grep -m1 '^VLSI_RESULT' $f)
    v() { tr ' ' '\n' <<< "$line" | sed -n "s/^$1=//p"; }
    st=ok; [ -z "$line" ] && st=fail; [ $rc = 124 ] && st=stall
    [ $st = stall ] && [ $rep = 1 ] && touch $OUT/n$N/skip_dv_vlsi_$w
    echo "engine=deva app=vlsi nodes=$N layout=p${p}w23 window=$w rep=$rep status=$st rc=$rc wall=$wall committed=$(v committed) executed=$(v executed) rolled_back=$(v rolled_back) run_s=$(v wall_s) M_ev_s=$(awk -v r="$(v committed_per_s)" 'BEGIN{if (r != "") printf "%.2f", r / 1e6}') deterministic=$(v deterministic)" \
      | tee -a $OUT/deva_vlsi.txt | sed "s/^/n$N /" | cut -c1-200 ); }
a64app() { # app rep
  local app=$1 rep=$2 e w s t sy ba gi ml x
  local df=dragonfly:$DFA:$DFH:4:1:500:$DF_GEN tw=traffic:100:1000:64:16:0:0:3
  for e in $(ord "$ENGINES" $rep); do
    case $app:$e in
      df:charades)
        cs df_wps512_r$rep wps:512 $df "$(ord 'mb:0 w:10000 w:15000 w:20000' $rep)" $DF_END 1000 128 300
        cs df_direct_r$rep off     $df "$(ord 'w:10000 w:20000' $rep)" $DF_END 1000 128 300
        cs df_dg_r$rep wps:512 $df w:10000 $DF_END 1000 128 300 "--commit-digest=1" ;;
      df:devastator) for w in $(ord '10000 20000 40000' $rep); do f5dv df_$w dragonfly $w $rep; done ;;
      df:ross) for s in $(ord "$ROSS_DF" $rep); do
                 IFS=: read -r t sy ba gi ml <<< "$s"; f5ross df_$t dragonfly $sy $ba $gi $rep $ml; done ;;
      tr:charades)
        cs tr_pp2048_r$rep pp:2048 $tw "$(ord 'mb:0 w:500 w:1000 w:1500' $rep)" $TR_END 8 64 300
        cs tr_wps512_r$rep wps:512 $tw w:500 $TR_END 8 64 300
        cs tr_direct_r$rep off     $tw w:500 $TR_END 8 64 300
        cs tr_dg_r$rep pp:2048 $tw w:500 $TR_END 8 64 300 "--commit-digest=1" ;;
      tr:devastator) for w in $(ord '1000 2000 4000' $rep); do f5dv tr_$w traffic $w $rep; done ;;
      tr:ross) for s in $(ord "$ROSS_TR" $rep); do
                 IFS=: read -r t sy ba gi ml <<< "$s"; f5ross tr_$t traffic $sy $ba $gi $rep $ml; done ;;
      vlsi:charades) for x in $(ord "E:w5000 E:w2500 L:w2500 E:mb0 G:w5000" $rep); do vcs r$rep ${x%%:*} ${x##*:}; done ;;
      vlsi:devastator) for w in $(ord '2500 5000 10000' $rep); do vdv $w $rep; done ;;
      vlsi:ross) ;;
    esac
  done; }

# ---- warm-up: the first 64-node run of each engine
{
  if [ $G = p ]; then
    f1spec g100
    cs warm pp:2048 $CW w:300 512000 8 128 150; csok warm || { log "CHARADES WARM-UP FAILED"; exit 1; }
    f1dv warm_w1000 1000 0 deva_warm
    [ $STUB = 1 ] || grep -q "^label=warm_w1000 .*status=ok" $OUT/n$N/deva_warm/results.txt 2>/dev/null || drop devastator
    f1ross warm_opt 3 16 64 0 0
    [ $STUB = 1 ] || grep -q "^label=warm_opt .*rc=0 committed=[0-9]" $OUT/n$N/ross/results.txt 2>/dev/null || drop ross
  else
    cs warm_tr pp:2048 traffic:100:1000:64:16:0:0:3 w:500 1000000 8 64 300; csok warm_tr || { log "CHARADES WARM-UP FAILED"; exit 1; }
    vcs warm E w2500 1250000
    f5dv warm_tr_1000 traffic 1000 0
    [ $STUB = 1 ] || grep -q "rep=0 arm=1000 status=ok" $OUT/deva_f5.txt 2>/dev/null || drop devastator
    f5ross warm_tr_w1000 traffic 3 64 64 0 1000
    [ $STUB = 1 ] || grep -q "rep=0 arm=warm_tr_w1000 .*status=ok" $OUT/ross_f5.txt 2>/dev/null || drop ross
  fi
  echo "engines after the warm-up: $ENGINES" > $OUT/engines.txt
} > $OUT/stream_warm.log 2>&1
log "WARM-UP DONE; engines: $ENGINES"

# ---- 64 nodes, 5 reps
{
  for rep in 1 2 3 4 5; do
    if [ $G = p ]; then
      for wl in $(ord "g100 g500 g1000 g1000x g2000 g4000 uni l10g500 l10g2000" $rep); do p64cell $wl $rep; done
    else
      for a in $(ord "df tr vlsi" $rep); do a64app $a $rep; done
    fi
    log "N $N REP $rep DONE"
  done
} > $OUT/stream_n64.log 2>&1
grep -h -E ' (fail|stall) |status=(fail|stall)|rc=[1-9]|WRONG' $OUT/stream_n64.log | head -30
du -sh $OUT
log "S64_262 $G DONE"
