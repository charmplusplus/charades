#!/bin/bash -l
#SBATCH -J f5scale187
#SBATCH -t 01:55:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/f5scale187_%j.out
# F5 (charades RESULTS.md section 187): traffic and dragonfly weak scaling in
# Charades, Devastator and ROSS, full sizes (dragonfly arrival 500 ns
# generating 300,000 ns; traffic 64 x 46.N, end 12,000,000), arms set by the
# calibration job (section 186's rules and 187's results):
#   Charades (--localalloc launch, --blocked-time=1, --commit-digest=1):
#     dragonfly WPs 512: the frozen controller (mb), W 10,000, W 20,000;
#       direct sends at W 10,000 and 20,000
#     traffic PP 2,048: mb, W 500, W 1,000; WPs 512 at W 500; direct at W 500
#   Devastator (CLCG4): dragonfly W 10,000 / 20,000 / 40,000 ps, traffic
#     W 1,000 / 2,000 / 4,000
#   ROSS: dragonfly optimistic batch 4 and 2 / GVT interval 64 (a); batch 2
#     and 1 x GVT interval 64 and 16 (big, rossdf: section 188, batch 2 beat
#     4 by up to 1.88x at 16 nodes); traffic optimistic batch 64 and 128 /
#     GVT interval 64, and conservative
# Engines interleaved per rep; engine and arm order reversed in even reps.
# An arm of Devastator or ROSS that hits its cap in rep 1 is skipped after.
# First argument:
#   a    16 nodes: the 8-, 4-, 2- and 1-node series side by side, then 16
#        nodes alone; 3 reps
#   big  32 nodes: dragonfly and traffic at 16 nodes side by side on the two
#        halves (3 reps), then both at 32 nodes (5 reps)
#   rossdf  16 nodes, ROSS on dragonfly only, the four settings above: the
#        8-, 4-, 2- and 1-node series side by side, then 16; 3 reps (F5c)
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 f5scale187.slurm a (and skx)
#         sbatch -p skx -N 32 -n 1536 -x c455-081 -t 02:40:00 f5scale187.slurm big
#         sbatch -p skx-dev -N 16 -n 768 -x c455-081 -t 01:00:00 f5scale187.slurm rossdf
set -u
G=${1:-a}
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/f5scale187/${G}_j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-phaseb; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh; D=$W/devastator; RB=$W/ROSS/build/models
NL=($(scontrol show hostnames $SLURM_JOB_NODELIST))
join() { local IFS=,; echo "$*"; }
log "job $SLURM_JOB_ID group $G; nodes ${NL[*]}"
log "charades $(git -C $C log --oneline -1 | cut -c1-60); ROSS $(git -C $W/ROSS log --oneline -1 | cut -c1-20); devastator $(git -C $D/devastator log --oneline -1 2>/dev/null | cut -c1-20)"
for b in $C/models/traffic/traffic $C/models/dragonfly/dragonfly; do
  strings $b | grep -q "the base before and after" || { log "$b lacks --ctl-bracket"; exit 1; }
  strings $b | grep -q "Commit Digest" || { log "$b lacks --commit-digest"; exit 1; }
done
for b in $RB/traffic/traffic $RB/dragonfly/dragonfly $D/bin/ofi-psm2/{traffic,dragonfly}-p{2,4,8,16,32,64}w23; do
  [ -x $b ] || { log "missing $b"; exit 1; }
done

ENGINES="charades devastator ross" ROSS_DF="b4g64:3:4:64 b2g64:3:2:64"
[ $G != a ] && ROSS_DF="b2g64:3:2:64 b1g64:3:1:64 b2g16:3:2:16 b1g16:3:1:16"
[ $G = rossdf ] && ENGINES=ross
if [ $G != rossdf ]; then
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model Dragonfly --model Traffic \
    agg_ctl_measured_fast_bucket_pp agg_deadline_bucket_wps bucket_window ctl_measured_bucket > $OUT/gate.txt 2>&1 )
tail -3 $OUT/gate.txt
grep -q "Failed: *0/" $OUT/gate.txt && grep -q "Timed out: *0/" $OUT/gate.txt || { log "GATE FAILED"; exit 1; }
log "GATE DONE"
fi
log "engines: $ENGINES; ROSS on dragonfly: $ROSS_DF"

export TREE=$T PPN=2 PEPP=23 CPT=24 CAP=300 LPC=16
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1 --commit-digest=1"
TR_END=12000000 DF_END=310000000 DF_GEN=300000 CAPX=300
shape() { case $1 in 1) echo "13 4" ;; 2) echo "15 6" ;; 4) echo "16 10" ;; 8) echo "22 12" ;; 16) echo "28 14" ;; 32) echo "36 18" ;; esac; }
cs() { # tag nodes nodelist agg workload arms end bucket lps_per_pe
  ( export NODES=$2 AGG=$4 WORKLOADS="$5" ARMS="$6" END=$7 BUCKETS=$8 LPS_PER_PE=$9 \
      EXTRA_ARGS="$L" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" ); }
margs() { # model nodes: model arguments shared by ROSS and Devastator
  if [ $1 = traffic ]; then
    echo "--num-x=64 --num-y=$((46 * $2)) --total-cars=$((46 * $2 * 64 * 16)) --lookahead=100 --mean=1000 --trip-radius=3"
  else
    set -- $(shape $2)
    echo "--routers-per-group=$1 --global-channels=$2 --terminals-per-router=4 --traffic=1 --routing=0 --arrive-rate=500 --gen-time=$DF_GEN"
  fi; }
skipped() { [ -e $OUT/n$1/skip_$2 ]; }
dv() { # tag nodes nodelist model window rep
  local tag=$1 N=$2 nl=$3 m=$4 w=$5 rep=$6 f=$OUT/n$2/deva/$1_r$6.out end
  skipped $N dv_$tag && { echo "n$N dv $tag r$rep skipped"; return; }
  mkdir -p $OUT/n$N/deva
  [ $m = traffic ] && end=$TR_END || end=$DF_END
  ( export GASNET_BACKTRACE=1 GASNET_OFI_SPAWNER=pmi FI_PROVIDER=psm2 deva_static_look_dt=$w; unset FI_PROVIDER_PATH
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
ord() { [ $((rep % 2)) = 1 ] && echo "$1" || rev "$1"; }
df_engines() { # nodes nodelist rep
  local N=$1 nl=$2 rep=$3 e w s df=dragonfly:$(shape $1 | tr ' ' ':'):4:1:500:$DF_GEN
  for e in $(ord "$ENGINES"); do
    case $e in
      charades)
        cs df_wps512_r$rep $N $nl wps:512 $df "$(ord 'mb:0 w:10000 w:20000')" $DF_END 1000 128
        cs df_direct_r$rep $N $nl off     $df "$(ord 'w:10000 w:20000')" $DF_END 1000 128 ;;
      devastator) for w in $(ord '10000 20000 40000'); do dv df_$w $N $nl dragonfly $w $rep; done ;;
      ross) for s in $(ord "$ROSS_DF"); do
              IFS=: read -r t sy ba gi <<< "$s"; ross df_$t $N $nl dragonfly $sy $ba $gi $rep; done ;;
    esac
  done; }
tr_engines() { # nodes nodelist rep
  local N=$1 nl=$2 rep=$3 e w s tw=traffic:100:1000:64:16:0:0:3
  for e in $(ord "$ENGINES"); do
    case $e in
      charades)
        cs tr_pp2048_r$rep $N $nl pp:2048 $tw "$(ord 'mb:0 w:500 w:1000')" $TR_END 8 64
        cs tr_wps512_r$rep $N $nl wps:512 $tw w:500 $TR_END 8 64
        cs tr_direct_r$rep $N $nl off     $tw w:500 $TR_END 8 64 ;;
      devastator) for w in $(ord '1000 2000 4000'); do dv tr_$w $N $nl traffic $w $rep; done ;;
      ross) for s in $(ord 'b64g64:3:64:64 b128g64:3:128:64 cons:2:16:16'); do
              IFS=: read -r t sy ba gi <<< "$s"; ross tr_$t $N $nl traffic $sy $ba $gi $rep; done ;;
    esac
  done; }
stream() { # nodes nodelist apps reps
  local N=$1 nl=$2 apps=$3 reps=$4 a
  [ $G != rossdf ] && cs warm_tr $N $nl pp:2048 traffic:100:1000:64:16:0:0:3 w:500 1000000 8 64
  for rep in $(seq $reps); do
    for a in $(ord "$apps"); do ${a}_engines $N $nl $rep; done
    log "N $N REP $rep DONE"
  done; }
if [ $G = big ]; then
  stream 16 $(join ${NL[@]:0:16}) df 3 > $OUT/stream_n16df.log 2>&1 &
  stream 16 $(join ${NL[@]:16:16}) tr 3 > $OUT/stream_n16tr.log 2>&1 &
  wait
  log "16 DONE"
  stream 32 $(join ${NL[@]:0:32}) "df tr" 5 > $OUT/stream_n32.log 2>&1
  log "32 DONE"
else
  [ $G = rossdf ] && APPS=df || APPS="df tr"
  stream 8 $(join ${NL[@]:0:8}) "$APPS" 3 > $OUT/stream_n8.log 2>&1 &
  stream 4 $(join ${NL[@]:8:4}) "$APPS" 3 > $OUT/stream_n4.log 2>&1 &
  stream 2 $(join ${NL[@]:12:2}) "$APPS" 3 > $OUT/stream_n2.log 2>&1 &
  stream 1 ${NL[14]} "$APPS" 3 > $OUT/stream_n1.log 2>&1 &
  wait
  log "1/2/4/8 DONE"
  stream 16 $(join ${NL[@]:0:16}) "$APPS" 3 > $OUT/stream_n16.log 2>&1
  log "16 DONE"
fi
grep -h -E ' (fail|stall) |status=(fail|stall)' $OUT/stream_n*.log | head -20
log "F5SCALE187 $G DONE"
