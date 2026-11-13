#!/bin/bash -l
#SBATCH -J f5cal186
#SBATCH -t 01:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/f5cal186_%j.out
# F5 calibration (charades RESULTS.md section 186): each engine's settings on
# traffic and dragonfly at 1 and 4 nodes, the two series side by side on 5
# nodes; 2 reps, engine and arm order reversed in rep 2; half the paper-grade
# sizes (job M/N's: dragonfly arrival 500 ns generating 150,000 ns, traffic
# end 6,000,000).
#   Charades: W grid and the frozen controller (mb); direct sends at two W;
#     traffic also WPs 512 at W 500. --localalloc launch, --blocked-time=1,
#     --ctl-log=1, --commit-digest=1
#   Devastator: W grid and its adaptive window (CLCG4)
#   ROSS: conservative and four optimistic batch / GVT-interval settings
# An arm of Devastator or ROSS that hits its cap in rep 1 is skipped in rep 2.
# Submit: sbatch -p skx-dev -N 5 -n 240 -x c455-081 f5cal186.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/f5cal186/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-phaseb; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh; D=$W/devastator; RB=$W/ROSS/build/models
NL=($(scontrol show hostnames $SLURM_JOB_NODELIST))
join() { local IFS=,; echo "$*"; }
log "job $SLURM_JOB_ID; nodes ${NL[*]}"
log "charades $(git -C $C log --oneline -1 | cut -c1-60); ROSS $(git -C $W/ROSS log --oneline -1 | cut -c1-20); devastator $(git -C $D/devastator log --oneline -1 2>/dev/null | cut -c1-20)"
for b in $C/models/traffic/traffic $C/models/dragonfly/dragonfly; do
  strings $b | grep -q "the base before and after" || { log "$b lacks --ctl-bracket"; exit 1; }
  strings $b | grep -q "Commit Digest" || { log "$b lacks --commit-digest"; exit 1; }
done
for b in $RB/traffic/traffic $RB/dragonfly/dragonfly $D/bin/ofi-psm2/{traffic,dragonfly}-p{2,8}w23; do
  [ -x $b ] || { log "missing $b"; exit 1; }
done

( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model Dragonfly --model Traffic \
    agg_ctl_measured_fast_bucket_pp agg_deadline_bucket_wps bucket_window ctl_measured_bucket > $OUT/gate.txt 2>&1 )
tail -3 $OUT/gate.txt
grep -q "Failed: *0/" $OUT/gate.txt && grep -q "Timed out: *0/" $OUT/gate.txt || { log "GATE FAILED"; exit 1; }
log "GATE DONE"

export TREE=$T PPN=2 PEPP=23 CPT=24 CAP=300 LPC=16
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1 --commit-digest=1"
TR_END=6000000 DF_END=160000000 DF_GEN=150000 CAPX=240
cs() { # tag nodes nodelist agg workload arms end bucket lps_per_pe
  ( export NODES=$2 AGG=$4 WORKLOADS="$5" ARMS="$6" END=$7 BUCKETS=$8 LPS_PER_PE=$9 \
      EXTRA_ARGS="$L" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" ); }
# model arguments shared by ROSS and Devastator (end time added per engine)
margs() { # model nodes
  local N=$2
  if [ $1 = traffic ]; then
    echo "--num-x=64 --num-y=$((46 * N)) --total-cars=$((46 * N * 64 * 16)) --lookahead=100 --mean=1000 --trip-radius=3"
  else
    local s; case $N in 1) s="13 4" ;; 2) s="15 6" ;; 4) s="16 10" ;; 8) s="22 12" ;; 16) s="28 14" ;; 32) s="36 18" ;; esac
    set -- $s
    echo "--routers-per-group=$1 --global-channels=$2 --terminals-per-router=4 --traffic=1 --routing=0 --arrive-rate=500 --gen-time=$DF_GEN"
  fi; }
skipped() { [ -e $OUT/n$1/skip_$2 ]; }
dv() { # tag nodes nodelist model window|adaptive rep
  local tag=$1 N=$2 nl=$3 m=$4 w=$5 rep=$6 f=$OUT/n$2/deva/$1_r$6.out end
  skipped $N dv_$tag && { echo "n$N dv $tag r$rep skipped"; return; }
  mkdir -p $OUT/n$N/deva
  [ $m = traffic ] && end=$TR_END || end=$DF_END
  ( export GASNET_BACKTRACE=1 GASNET_OFI_SPAWNER=pmi FI_PROVIDER=psm2; unset FI_PROVIDER_PATH
    if [ $w = adaptive ]; then unset deva_static_look_dt; else export deva_static_look_dt=$w; fi
    t0=$(date +%s.%N)
    timeout -s TERM $CAPX srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -J dv_${tag}_n$N -w $nl -N $N -n $((2 * N)) \
      --ntasks-per-node=2 -c 24 --cpu-bind=cores -m block:block \
      stdbuf -oL $D/bin/ofi-psm2/$m-p$((2 * N))w23 $(margs $m $N) --end-time=$end --rng=clcg4 > $f 2>&1
    rc=$?; wall=$(printf %.1f "$(echo "$(date +%s.%N) - $t0" | bc)")
    line=$(grep -m1 -E '^(TRAFFIC|DRAGONFLY)_RESULT' $f)
    v() { tr ' ' '\n' <<< "$line" | sed -n "s/^$1=//p"; }
    st=ok; [ -z "$line" ] && st=fail; [ $rc = 124 ] && st=stall
    [ $st = stall ] && [ $rep = 1 ] && touch $OUT/n$N/skip_dv_$tag
    echo "engine=deva app=$m nodes=$N rep=$rep arm=$w status=$st rc=$rc wall=$wall committed=$(v committed) executed=$(v executed) rolled_back=$(v rolled_back) run_s=$(v wall_s) M_ev_s=$(awk -v r="$(v committed_per_s)" 'BEGIN{if (r != "") printf "%.2f", r / 1e6}') deterministic=$(v deterministic)" \
      | tee -a $OUT/deva.txt | sed "s/^/n$N /" | cut -c1-200 )
}
ross() { # tag nodes nodelist model synch batch gvt_interval rep
  local tag=$1 N=$2 nl=$3 m=$4 rep=$8 f=$OUT/n$2/ross/$1_r$8.out end
  skipped $N ross_$tag && { echo "n$N ross $tag r$rep skipped"; return; }
  mkdir -p $OUT/n$N/ross
  [ $m = traffic ] && end=$TR_END || end=$DF_END
  ( module load mvapich/3.0 >/dev/null 2>&1
    unset FI_PROVIDER FI_PROVIDER_PATH LCI_ATTR_BACKEND LCI_ATTR_OFI_PROVIDER_NAME LCI_ATTR_PACKET_SIZE PSM2_MULTI_EP
    t0=$(date +%s.%N)
    timeout -s TERM $CAPX srun --mpi=pmi2 --kill-on-bad-exit=1 -J ross_${tag}_n$N -w $nl -N $N -n $((46 * N)) --ntasks-per-node=46 \
      $RB/$m/$m --synch=$5 --read-buffer=1 --extramem=800000 --batch=$6 --gvt-interval=$7 $(margs $m $N) --end=$end > $f 2>&1
    rc=$?; wall=$(printf %.1f "$(echo "$(date +%s.%N) - $t0" | bc)")
    st=ok; grep -q 'Net Events Processed' $f || st=fail; [ $rc = 124 ] && st=stall
    [ $st = stall ] && [ $rep = 1 ] && touch $OUT/n$N/skip_ross_$tag
    echo "engine=ross app=$m nodes=$N rep=$rep arm=$tag status=$st rc=$rc wall=$wall committed=$(awk '/Net Events Processed/{print $NF; exit}' $f) M_ev_s=$(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' $f) efficiency=$(awk '/Efficiency/{print $(NF-1); exit}' $f) run_s=$(awk '/Running Time/{print $(NF-1); exit}' $f)" \
      | tee -a $OUT/ross.txt | sed "s/^/n$N /" | cut -c1-200 )
}
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
charades() { # nodes nodelist rep
  local N=$1 nl=$2 rep=$3 df
  case $N in 1) df=dragonfly:13:4:4:1:500:$DF_GEN ;; 4) df=dragonfly:16:10:4:1:500:$DF_GEN ;; esac
  cs df_wps512_r$rep    $N $nl wps:512  $df "$(ord 'w:5000 w:10000 w:20000 w:40000 mb:0')" $DF_END 1000 128
  cs df_direct_r$rep    $N $nl off      $df "$(ord 'w:10000 w:20000')" $DF_END 1000 128
  cs tr_pp2048_r$rep    $N $nl pp:2048  traffic:100:1000:64:16:0:0:3 "$(ord 'w:250 w:500 w:1000 w:2000 mb:0')" $TR_END 8 64
  cs tr_wps512_r$rep    $N $nl wps:512  traffic:100:1000:64:16:0:0:3 w:500 $TR_END 8 64
  cs tr_direct_r$rep    $N $nl off      traffic:100:1000:64:16:0:0:3 "$(ord 'w:500 w:1000')" $TR_END 8 64; }
devastator() { # nodes nodelist rep
  local w
  for w in $(ord '5000 10000 20000 40000 80000 adaptive'); do dv df_$w $1 $2 dragonfly $w $3; done
  for w in $(ord '250 500 1000 2000 4000 adaptive'); do dv tr_$w $1 $2 traffic $w $3; done; }
rossall() { # nodes nodelist rep
  local m s
  for m in dragonfly traffic; do
    for s in $(ord 'cons:2:16:16 b16g64:3:16:64 b16g256:3:16:256 b4g64:3:4:64 b64g64:3:64:64'); do
      IFS=: read -r t sy ba gi <<< "$s"
      ross ${m:0:2}_$t $1 $2 $m $sy $ba $gi $3
    done
  done; }
stream() { # nodes nodelist
  local N=$1 nl=$2
  for rep in 1 2; do
    ord() { [ $rep = 1 ] && echo "$1" || rev "$1"; }
    if [ $rep = 1 ]; then charades $N $nl $rep; devastator $N $nl $rep; rossall $N $nl $rep
    else rossall $N $nl $rep; devastator $N $nl $rep; charades $N $nl $rep; fi
    log "N $N REP $rep DONE"
  done; }
stream 4 $(join ${NL[@]:0:4}) > $OUT/stream_n4.log 2>&1 &
stream 1 ${NL[4]} > $OUT/stream_n1.log 2>&1 &
wait
grep -h -E ' (fail|stall) |status=(fail|stall)' $OUT/stream_n*.log | head -20
log "F5CAL186 DONE"
