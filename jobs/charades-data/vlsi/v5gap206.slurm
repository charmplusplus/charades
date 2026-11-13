#!/bin/bash -l
#SBATCH -J v5gap206
#SBATCH -t 01:15:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/v5gap206_%j.out
# Job V5 (charades RESULTS.md section 206): round 1's settings at 1 and 4
# nodes in both engines, and lazy fossils on the other six workloads.
#   nodes 0-3: the 4-node series; node 4: the 1-node series; 2 reps, arm order
#   reversed in rep 2.
#   Part A, VLSI (b19 x N, one copy per node, span 1, --chunk=512, 5,000
#   cycles, direct sends, buckets of 2,500 ps unless noted, --copy-stats=1
#   --commit-digest=1 --blocked-time=1):
#     R  1 x 46 W 5,000, eager fossils, batch 16
#     L  1 x 46 --fossil-lazy=1 --batch=32, W 2,500 / 5,000 / 10,000
#     Lc as L, the frozen controller (mb), buckets of 5,000 ps
#     I  2 x 23 +ipc, as L, W 5,000
#     S  2 x 23 on charades-perfshm (Charm++ --enable-shmem), as L, W 5,000
#     N  2 x 23 over LCI, as L, W 5,000
#     Devastator 2 x 23 (and 1 x 46 with DEVA_P1=1) W 2,500 / 5,000 / 10,000
#   Part B, lazy fossils elsewhere (2 x 23 over LCI; job N's sizes, htram
#   settings and buckets): per workload eager (e) and lazy (l) fossils at two
#   W and mb; +ipc with lazy fossils at the first W (i); the paper's tree
#   charades-phaseb at the first W (p)
# Submit: sbatch -p skx-dev -N 5 -n 240 -x c455-081 v5gap206.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/v5gap206/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 >/dev/null 2>&1; module load cmake >/dev/null 2>&1; module load python3 >/dev/null 2>&1
DEVA_P1=${DEVA_P1:-0}
TP=charades-perf; TS=charades-perfshm; TO=charades-phaseb; D=$W/devastator; DB=$D/bin/ofi-psm2
NETLIST=$W/I99T/i99t/b19/b19.bench
NL=($(scontrol show hostnames $SLURM_JOB_NODELIST))
join() { local IFS=,; echo "$*"; }
log "job $SLURM_JOB_ID; nodes ${NL[*]}; on $(hostname -s); DEVA_P1=$DEVA_P1"
for t in $TP $TS $TO; do log "$t $(git -C $W/$t log --oneline -1 | cut -c1-60)"; done
[ "$(git -C $W/$TP rev-parse HEAD)" = "$(git -C $W/$TS rev-parse HEAD)" ] || { log "$TP and $TS are on different commits"; exit 1; }
for m in vlsi/vlsi phold/simple/phold traffic/traffic dragonfly/dragonfly; do
  for t in $TP $TS; do
    strings $W/$t/models/$m | grep -q "fossil-lazy" || { log "$t $m lacks --fossil-lazy"; exit 1; }
  done
  # the paper's tree predates VLSI; Part B runs only the other models in it
  [ $m = vlsi/vlsi ] || [ -x $W/$TO/models/$m ] || { log "missing $TO $m"; exit 1; }
done
ldd $W/$TP/models/vlsi/vlsi | grep -q charm-pads-perf/ || { log "$TP does not link charm-pads-perf"; exit 1; }
ldd $W/$TS/models/vlsi/vlsi | grep -q charm-pads-perfshm/ || { log "$TS does not link charm-pads-perfshm"; exit 1; }
grep -q "CMK_USE_SHMEM 1" $W/charm-pads-perfshm/reconverse-linux-x86_64/include/conv-autoconfig.h || { log "charm-pads-perfshm lacks CMK_USE_SHMEM"; exit 1; }
for b in $NETLIST $DB/vlsi-p2w23 $DB/vlsi-p8w23; do [ -e $b ] || { log "missing $b"; exit 1; }; done
[ $DEVA_P1 = 1 ] && for b in $DB/vlsi-p1w46 $DB/vlsi-p4w46; do [ -e $b ] || { log "missing $b"; exit 1; }; done

# ---- gate: the change tier on 2 nodes with lazy fossils (charades-perf)
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/$TP/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $W/$TP/tests; export CHARADES_RUN_ARGS="+mempool_remote_free --fossil-lazy=1"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model VLSI --model "Simple PHOLD" --model Traffic --model Dragonfly \
    agg_ctl_measured_fast_bucket_pp bucket_window > $OUT/gate.txt 2>&1 )
tail -3 $OUT/gate.txt
grep -q "Failed: *0/" $OUT/gate.txt && grep -q "Timed out: *0/" $OUT/gate.txt || {
  i=0; for f in $(grep -E " (FAIL|TIMEOUT) " $OUT/gate.txt | awk '{print $NF}'); do i=$((i+1)); cp $f $OUT/gate_fail_$i.out 2>/dev/null; done
  log "GATE FAILED (outputs in $OUT/gate_fail_*.out)"; exit 1; }
log "GATE DONE"

export CAP=300 VLSI_NETLISTS=$W/I99T/i99t
LV="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1 --commit-digest=1 --copy-stats=1"
LB="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1"
LAZY="--fossil-lazy=1 --batch=32"
V_END=12500000 CAPX=300
cs() { # tag nodes nodelist tree procs:PEs:cores arms [extra flags] [bucket]
  local tag=$1 N=$2 nl=$3 tree=$4 lay=$5 arms=$6 extra=${7:-} bk=${8:-2500} ppn pepp cpt
  IFS=: read -r ppn pepp cpt <<< "$lay"
  ( export TREE=$tree NODES=$N PPN=$ppn PEPP=$pepp CPT=$cpt AGG=off WORKLOADS=vlsi:b19:1:1 ARMS="$arms" END=$V_END \
      BUCKETS=$bk LPC=128 LPS_PER_PE=128 EXTRA_ARGS="$LV $extra" SRUN_ARGS="-w $nl"
    RUNS=$OUT/n$N/$tag $W/$tree/scripts/stampede3/ctl_sweep.sh 1 $OUT/n$N/$tag.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$N $tag /" )
  rm -f $OUT/n$N/$tag/ctl_sweep/logs/*.digest.csv; }
csb() { # tag nodes nodelist tree agg workload arms end bucket lps_per_pe [extra flags]
  ( export TREE=$4 NODES=$2 PPN=2 PEPP=23 CPT=24 AGG=$5 WORKLOADS="$6" ARMS="$7" END=$8 BUCKETS=$9 LPS_PER_PE=${10} LPC=16 \
      EXTRA_ARGS="$LB ${11:-}" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $W/$4/scripts/stampede3/ctl_sweep.sh 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" )
  rm -f $OUT/n$2/$1/ctl_sweep/logs/*.digest.csv; }
dv() { # tag nodes nodelist procs-per-node:workers window rep
  local tag=$1 N=$2 nl=$3 pw=$4 w=$5 rep=$6
  local ppn=${pw%%:*} wk=${pw##*:} f=$OUT/n$2/deva/$1_w$5_r$6.out
  local p=$((ppn * N)); local bin=$DB/vlsi-p${p}w${wk}
  [ -x $bin ] || { echo "n$N dv $tag r$rep: no binary $bin"; return; }
  mkdir -p $OUT/n$N/deva
  ( export GASNET_BACKTRACE=1 GASNET_OFI_SPAWNER=pmi FI_PROVIDER=psm2 deva_static_look_dt=$w
    unset FI_PROVIDER_PATH
    t0=$(date +%s.%N)
    timeout -s TERM $CAPX srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -J dv_${tag}_n$N -w $nl -N $N -n $p \
      --ntasks-per-node=$ppn -c $((48 / ppn)) --cpu-bind=cores -m block:block \
      stdbuf -oL $bin --netlist=$NETLIST --copies=$N --span=1 --chunk=512 --end-time=$V_END > $f 2>&1
    rc=$?; wall=$(printf %.1f "$(echo "$(date +%s.%N) - $t0" | bc)")
    line=$(grep -m1 '^VLSI_RESULT' $f)
    v() { tr ' ' '\n' <<< "$line" | sed -n "s/^$1=//p"; }
    st=ok; [ -z "$line" ] && st=fail; [ $rc = 124 ] && st=stall
    echo "engine=deva app=vlsi nodes=$N layout=p${p}w$wk window=$w rep=$rep arm=$tag status=$st rc=$rc wall=$wall committed=$(v committed) executed=$(v executed) rolled_back=$(v rolled_back) gate_changes=$(v gate_changes) run_s=$(v wall_s) M_ev_s=$(awk -v r="$(v committed_per_s)" 'BEGIN{if (r != "") printf "%.2f", r / 1e6}') deterministic=$(v deterministic)" \
      | tee -a $OUT/deva.txt | sed "s/^/n$N /" | cut -c1-200 )
}
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
partA() { # nodes nodelist rep
  local N=$1 nl=$2 rep=$3 a w steps="R L Lc I S N d2" W3="w:2500 w:5000 w:10000"
  [ $DEVA_P1 = 1 ] && steps="$steps d1"
  [ $((rep % 2)) = 0 ] && { steps=$(rev "$steps"); W3=$(rev "$W3"); }
  for a in $steps; do
    case $a in
      R)  cs A_R_r$rep  $N $nl $TP 1:46:48 w:5000 ;;
      L)  cs A_L_r$rep  $N $nl $TP 1:46:48 "$W3" "$LAZY" ;;
      Lc) cs A_Lc_r$rep $N $nl $TP 1:46:48 mb:0 "$LAZY" 5000 ;;
      I)  cs A_I_r$rep  $N $nl $TP 2:23:24 w:5000 "$LAZY +ipc" ;;
      S)  cs A_S_r$rep  $N $nl $TS 2:23:24 w:5000 "$LAZY" ;;
      N)  cs A_N_r$rep  $N $nl $TP 2:23:24 w:5000 "$LAZY" ;;
      d2) for w in ${W3//w:/}; do dv d2 $N $nl 2:23 $w $rep; done ;;
      d1) for w in ${W3//w:/}; do dv d1 $N $nl 1:46 $w $rep; done ;;
    esac
  done; }
wl() { # workload nodes -> agg spec end bucket lps_per_pe W1 W2 digest-flag
  case $1 in
    phases)  echo "pp:512 phases:10:200:100:1000:0.5:8000 1024000 8 128 100 150 -" ;;
    g100)    echo "pp:2048 gauss:100:1000:100 2048000 8 128 300 500 -" ;;
    g2000)   echo "pp:512 gauss:100:1000:2000 2048000 8 128 300 500 -" ;;
    uni)     echo "wps:512 steady:100:1000:1.0 2048000 8 128 300 500 -" ;;
    traffic) echo "pp:2048 traffic:100:1000:64:16:0:0:3 6000000 8 64 500 750 --commit-digest=1" ;;
    df)      if [ $2 = 1 ]; then s=13:4; else s=16:10; fi
             echo "wps:512 dragonfly:$s:4:1:500:150000 160000000 1000 128 10000 20000 --commit-digest=1" ;;
  esac; }
partB() { # nodes nodelist rep
  local N=$1 nl=$2 rep=$3 w g agg spec end bk lps w1 w2 dg arms
  local wls="phases g100 g2000 uni traffic df" grps="e l i p"
  [ $((rep % 2)) = 0 ] && { wls=$(rev "$wls"); grps=$(rev "$grps"); }
  for w in $wls; do
    read -r agg spec end bk lps w1 w2 dg <<< "$(wl $w $N)"
    [ "$dg" = - ] && dg=
    arms="w:$w1 w:$w2 mb:0"; [ $((rep % 2)) = 0 ] && arms=$(rev "$arms")
    for g in $grps; do
      case $g in
        e) csb B_${w}_e_r$rep $N $nl $TP $agg $spec "$arms" $end $bk $lps "$dg" ;;
        l) csb B_${w}_l_r$rep $N $nl $TP $agg $spec "$arms" $end $bk $lps "--fossil-lazy=1 $dg" ;;
        i) csb B_${w}_i_r$rep $N $nl $TP $agg $spec w:$w1 $end $bk $lps "--fossil-lazy=1 +ipc $dg" ;;
        p) csb B_${w}_p_r$rep $N $nl $TO $agg $spec w:$w1 $end $bk $lps "$dg" ;;
      esac
    done
  done; }
stream() { # nodes nodelist
  local N=$1 nl=$2
  partA $N $nl 1; log "N $N A REP 1 DONE"
  partB $N $nl 1; log "N $N B REP 1 DONE"
  partB $N $nl 2; log "N $N B REP 2 DONE"
  partA $N $nl 2; log "N $N A REP 2 DONE"; }
stream 4 $(join ${NL[@]:0:4}) > $OUT/stream_n4.log 2>&1 &
stream 1 ${NL[4]} > $OUT/stream_n1.log 2>&1 &
wait
grep -h -E ' (fail|stall) |status=(fail|stall)' $OUT/stream_n*.log | head -20
log "V5GAP206 DONE"
