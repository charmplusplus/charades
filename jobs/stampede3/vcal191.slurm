#!/bin/bash -l
#SBATCH -J vcal191
#SBATCH -t 02:00:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/vcal191_%j.out
# VLSI calibration (charades RESULTS.md section 191): b19 x N (one copy per
# node) at 1 and 4 nodes in three engines; 2 reps, engine and arm order
# reversed in rep 2; 5,000 clock cycles (12,500,000 ps).
#   node 0 (the batch host): after the gate, builds Devastator's vlsi binaries for 1-32
#     nodes (ofi-psm2, p2w23 ... p64w23), Charades' models/vlsi on the
#     include path; Devastator's runs wait for it
#   nodes 1-4: the 4-node series; node 5: the 1-node series
#   Charades (charades-vlsi, --localalloc launch, --blocked-time=1,
#     --commit-digest=1): span 1, PP 2,048, buckets of 500 ps, 128 LPs per
#     chare: W 1,250 / 2,500 / 5,000 / 10,000 / 20,000 ps and the frozen
#     controller; at W 5,000 also WPs 512, direct sends, 512 LPs per chare,
#     buckets of 2,500 ps. 4 nodes also span 4 (each copy over all 4
#     nodes): W 2,500 / 5,000 / 10,000, the controller, direct at W 5,000
#   Devastator: span 1 W 1,250 ... 20,000 and its adaptive window; span 4
#     W 2,500 / 5,000 / 10,000
#   ROSS: span 1 batch 2 / 8 / 32, GVT interval 64; span 4 batch 8
#   ROSS on dragonfly (section 189's open edge): batch 2, GVT interval 64
#     and 256, half the F5 size
# An arm of Devastator or ROSS that hits its cap in rep 1 is skipped in rep 2.
# Submit: sbatch -p skx-dev -N 6 -n 288 -x c455-081 vcal191.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/vcal191/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-vlsi; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh; D=$W/devastator; RB=$W/ROSS/build/models
NETLIST=$W/I99T/i99t/b19/b19.bench
NL=($(scontrol show hostnames $SLURM_JOB_NODELIST))
join() { local IFS=,; echo "$*"; }
log "job $SLURM_JOB_ID; nodes ${NL[*]}; on $(hostname -s)"
log "charades $(git -C $C log --oneline -1 | cut -c1-60); ROSS $(git -C $W/ROSS log --oneline -1 | cut -c1-20)"
strings $C/models/vlsi/vlsi | grep -q "VLSI Model Configuration" || { log "no Charades vlsi binary"; exit 1; }
grep -q "vlsi:<circuit>" $S || { log "ctl_sweep.sh lacks the vlsi workload"; exit 1; }
for b in $RB/vlsi/vlsi $RB/dragonfly/dragonfly $NETLIST $D/devastator/bench/vlsi.cxx; do
  [ -e $b ] || { log "missing $b"; exit 1; }
done

# ---- gate on nodes 1-2: the VLSI test tier
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model VLSI \
    agg_ctl_measured_fast_bucket_pp agg_deadline_bucket_pp agg_deadline_bucket_wps bucket_window ctl_measured_bucket > $OUT/gate.txt 2>&1 )
tail -3 $OUT/gate.txt
grep -q "Failed: *0/" $OUT/gate.txt && grep -q "Timed out: *0/" $OUT/gate.txt || { log "GATE FAILED"; exit 1; }
log "GATE DONE"

# ---- Devastator's vlsi binaries on the batch host, in the background (after
# the gate, whose runs may land on this node)
( CXX_PPFLAGS="-I$C/models/vlsi" BENCHES="vlsi" LAYOUTS="2:23 4:23 8:23 16:23 32:23 64:23" STOCK=0 PAR=0 \
    bash $D/build_stampede3.sh ofi-psm2 > $OUT/deva_build.txt 2>&1
  echo "build rc=$?" >> $OUT/deva_build.txt; touch $OUT/deva_built ) &
log "Devastator build started"


export TREE=$T PPN=2 PEPP=23 CPT=24 CAP=300 VLSI_NETLISTS=$W/I99T/i99t
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1 --commit-digest=1"
V_END=12500000 DF_END=160000000 DF_GEN=150000 CAPX=300
cs() { # tag nodes nodelist agg workload arms bucket lpc
  ( export NODES=$2 AGG=$4 WORKLOADS="$5" ARMS="$6" END=$V_END BUCKETS=$7 LPC=$8 LPS_PER_PE=$8 \
      EXTRA_ARGS="$L" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" ); }
skipped() { [ -e $OUT/n$1/skip_$2 ]; }
dv() { # tag nodes nodelist span window|adaptive rep
  local tag=$1 N=$2 nl=$3 span=$4 w=$5 rep=$6 f=$OUT/n$2/deva/$1_r$6.out
  skipped $N dv_$tag && { echo "n$N dv $tag r$rep skipped"; return; }
  mkdir -p $OUT/n$N/deva
  ( export GASNET_BACKTRACE=1 GASNET_OFI_SPAWNER=pmi FI_PROVIDER=psm2; unset FI_PROVIDER_PATH
    if [ $w = adaptive ]; then unset deva_static_look_dt; else export deva_static_look_dt=$w; fi
    t0=$(date +%s.%N)
    timeout -s TERM $CAPX srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -J dv_${tag}_n$N -w $nl -N $N -n $((2 * N)) \
      --ntasks-per-node=2 -c 24 --cpu-bind=cores -m block:block \
      stdbuf -oL $D/bin/ofi-psm2/vlsi-p$((2 * N))w23 --netlist=$NETLIST --copies=$N --span=$span --end-time=$V_END > $f 2>&1
    rc=$?; wall=$(printf %.1f "$(echo "$(date +%s.%N) - $t0" | bc)")
    line=$(grep -m1 '^VLSI_RESULT' $f)
    v() { tr ' ' '\n' <<< "$line" | sed -n "s/^$1=//p"; }
    st=ok; [ -z "$line" ] && st=fail; [ $rc = 124 ] && st=stall
    [ $st = stall ] && [ $rep = 1 ] && touch $OUT/n$N/skip_dv_$tag
    echo "engine=deva app=vlsi nodes=$N span=$span rep=$rep arm=$w status=$st rc=$rc wall=$wall committed=$(v committed) executed=$(v executed) rolled_back=$(v rolled_back) gate_changes=$(v gate_changes) run_s=$(v wall_s) M_ev_s=$(awk -v r="$(v committed_per_s)" 'BEGIN{if (r != "") printf "%.2f", r / 1e6}') deterministic=$(v deterministic)" \
      | tee -a $OUT/deva.txt | sed "s/^/n$N /" | cut -c1-200 )
}
ross() { # tag nodes nodelist app span batch gvt_interval rep
  local tag=$1 N=$2 nl=$3 app=$4 span=$5 ba=$6 gi=$7 rep=$8 f=$OUT/n$2/ross/$1_r$8.out margs
  skipped $N ross_$tag && { echo "n$N ross $tag r$rep skipped"; return; }
  mkdir -p $OUT/n$N/ross
  if [ $app = vlsi ]; then
    margs="--netlist=$NETLIST --copies=$N --span=$span --end=$V_END"
  else
    local s; case $N in 1) s="13 4" ;; 4) s="16 10" ;; esac; set -- $s
    margs="--routers-per-group=$1 --global-channels=$2 --terminals-per-router=4 --traffic=1 --routing=0 --arrive-rate=500 --gen-time=$DF_GEN --end=$DF_END"
  fi
  ( module load mvapich/3.0 >/dev/null 2>&1
    unset FI_PROVIDER FI_PROVIDER_PATH LCI_ATTR_BACKEND LCI_ATTR_OFI_PROVIDER_NAME LCI_ATTR_PACKET_SIZE PSM2_MULTI_EP
    t0=$(date +%s.%N)
    timeout -s TERM $CAPX srun --mpi=pmi2 --kill-on-bad-exit=1 -J ross_${tag}_n$N -w $nl -N $N -n $((46 * N)) --ntasks-per-node=46 \
      $RB/$app/$app --synch=3 --read-buffer=1 --extramem=800000 --batch=$ba --gvt-interval=$gi $margs > $f 2>&1
    rc=$?; wall=$(printf %.1f "$(echo "$(date +%s.%N) - $t0" | bc)")
    st=ok; grep -q 'Net Events Processed' $f || st=fail; [ $rc = 124 ] && st=stall
    [ $st = stall ] && [ $rep = 1 ] && touch $OUT/n$N/skip_ross_$tag
    echo "engine=ross app=$app nodes=$N span=$span rep=$rep arm=$tag status=$st rc=$rc wall=$wall committed=$(awk '/Net Events Processed/{print $NF; exit}' $f) M_ev_s=$(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' $f) efficiency=$(awk '/Efficiency/{print $(NF-1); exit}' $f) gate_changes=$(awk -F. '/Gate output changes/{print $NF; exit}' $f) run_s=$(awk '/Running Time/{print $(NF-1); exit}' $f)" \
      | tee -a $OUT/ross.txt | sed "s/^/n$N /" | cut -c1-200 )
}
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
ord() { [ $((rep % 2)) = 1 ] && echo "$1" || rev "$1"; }
charades() { # nodes nodelist rep
  local N=$1 nl=$2 rep=$3
  cs s1_pp2048_r$rep $N $nl pp:2048 vlsi:b19:1:1 "$(ord 'w:1250 w:2500 w:5000 w:10000 w:20000 mb:0')" 500 128
  cs s1_wps512_r$rep $N $nl wps:512 vlsi:b19:1:1 w:5000 500 128
  cs s1_direct_r$rep $N $nl off     vlsi:b19:1:1 w:5000 500 128
  cs s1_lpc512_r$rep $N $nl pp:2048 vlsi:b19:1:1 w:5000 500 512
  cs s1_b2500_r$rep  $N $nl pp:2048 vlsi:b19:1:1 w:5000 2500 128
  if [ $N = 4 ]; then
    cs s4_pp2048_r$rep $N $nl pp:2048 vlsi:b19:1:4 "$(ord 'w:2500 w:5000 w:10000 mb:0')" 500 128
    cs s4_direct_r$rep $N $nl off     vlsi:b19:1:4 w:5000 500 128
  fi; }
devastator() { # nodes nodelist rep
  local N=$1 nl=$2 rep=$3 w
  while [ ! -e $OUT/deva_built ]; do sleep 10; done
  [ -x $D/bin/ofi-psm2/vlsi-p$((2 * N))w23 ] || { echo "n$N no Devastator vlsi binary"; return; }
  for w in $(ord '1250 2500 5000 10000 20000 adaptive'); do dv s1_$w $N $nl 1 $w $rep; done
  if [ $N = 4 ]; then for w in $(ord '2500 5000 10000'); do dv s4_$w $N $nl 4 $w $rep; done; fi; }
rossall() { # nodes nodelist rep
  local N=$1 nl=$2 rep=$3 s
  for s in $(ord 'b2g64:2:64 b8g64:8:64 b32g64:32:64'); do
    IFS=: read -r t ba gi <<< "$s"; ross vlsi_s1_$t $N $nl vlsi 1 $ba $gi $rep
  done
  [ $N = 4 ] && ross vlsi_s4_b8g64 $N $nl vlsi 4 8 64 $rep
  for s in $(ord 'b2g64:2:64 b2g256:2:256'); do
    IFS=: read -r t ba gi <<< "$s"; ross df_$t $N $nl dragonfly 1 $ba $gi $rep
  done; }
stream() { # nodes nodelist
  local N=$1 nl=$2
  for rep in 1 2; do
    if [ $rep = 1 ]; then charades $N $nl $rep; rossall $N $nl $rep; devastator $N $nl $rep
    else devastator $N $nl $rep; rossall $N $nl $rep; charades $N $nl $rep; fi
    log "N $N REP $rep DONE"
  done; }
stream 4 $(join ${NL[@]:1:4}) > $OUT/stream_n4.log 2>&1 &
stream 1 ${NL[5]} > $OUT/stream_n1.log 2>&1 &
wait
tail -3 $OUT/deva_build.txt; grep -E "vlsi" $D/logs/build-summary.txt | tail -6
grep -h -E ' (fail|stall) |status=(fail|stall)' $OUT/stream_n*.log | head -20
log "VCAL191 DONE"
