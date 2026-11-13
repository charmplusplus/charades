#!/bin/bash -l
#SBATCH -J phaseb175
#SBATCH -t 01:00:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/phaseb175_%j.out
# Job C (charades RESULTS.md section 175): Phase B builds, a 1-node Charades
# calibration of dragonfly and traffic, and committed counts of all three
# engines on 2 nodes.
#   1. node 1: Devastator traffic and dragonfly, GASNet ofi-psm2, p2w23 ...
#      p64w23 (1-32 nodes) plus p2w2 and p2w3 for the count checks
#   2. node 2, meanwhile: Charades dragonfly (a=13 h=4 p=4, uniform; arrival
#      500 and 1,000 ns; generating 50,000 ns; WPs 512; W 10,000 / 50,000 /
#      200,000 ps and the controller) and traffic (64 x 46, 16 cars per
#      intersection, trip radius 3, end 500,000; PP 2,048; W 250 / 1,000 and
#      the controller); --localalloc launch, --blocked-time=1
#   3. both nodes: Charades test.py (Dragonfly, Traffic), ROSS (5 and 4
#      ranks) and Devastator (p2w3, p2w2) against the configs' expected counts
# Submit: sbatch -p skx-dev -N 2 -n 96 -x c455-081 phaseb175.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/phaseb175/j$SLURM_JOB_ID; mkdir -p $OUT/cal
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-phaseb; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh; D=$W/devastator; RB=$W/ROSS/build/models
NL=($(scontrol show hostnames $SLURM_JOB_NODELIST)); N1=${NL[0]}; N2=${NL[1]}
log "job $SLURM_JOB_ID; nodes ${NL[*]}; on $(hostname -s)"
log "charades $(git -C $C log --oneline -1 | cut -c1-60); ROSS $(git -C $W/ROSS log --oneline -1 | cut -c1-20)"
grep -q "dragonfly:<a>" $S || { log "ctl_sweep.sh lacks the dragonfly workload"; exit 1; }
for b in $C/models/dragonfly/dragonfly $C/models/traffic/traffic $RB/dragonfly/dragonfly $RB/traffic/traffic; do
  [ -x $b ] || { log "missing $b"; exit 1; }
done
grep -q rt_owner $D/devastator/bench/dragonfly.cxx || { log "Devastator dragonfly lacks the uneven partition"; exit 1; }

# ---- 1. Devastator builds on node 1 (this host), in the background
( BENCHES="traffic dragonfly" LAYOUTS="2:2 2:3 2:23 4:23 8:23 16:23 32:23 64:23" STOCK=0 PAR=0 \
    bash $D/build_stampede3.sh ofi-psm2 > $OUT/deva_build.txt 2>&1
  echo "build rc=$?" >> $OUT/deva_build.txt ) &
BP=$!
log "Devastator build started (pid $BP)"

# ---- 2. Charades calibration on node 2
export TREE=$T PPN=2 PEPP=23 CPT=24 CAP=200
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1"
cs() { # tag agg end buckets lps_per_pe workloads arms
  ( export NODES=1 AGG=$2 END=$3 BUCKETS=$4 LPS_PER_PE=$5 LPC=16 WORKLOADS="$6" ARMS="$7" \
      EXTRA_ARGS="$L" SRUN_ARGS="-w $N2"
    RUNS=$OUT/cal/$1 $S 1 $OUT/cal/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs df wps:512 60000000 1000 128 "dragonfly:13:4:4:1:500:50000 dragonfly:13:4:4:1:1000:50000" \
   "w:10000 w:50000 w:200000 q:0.001"
for f in $OUT/cal/df/ctl_sweep/logs/*.out; do
  echo "$(basename $f): $(grep -E 'Average latency|Packets finished' $f | tr -s ' \t' ' ' | tr '\n' ';')"
done
cs tr pp:2048 500000 8 64 "traffic:100:1000:64:16:0:0:3" "w:250 w:1000 q:0.001"
log "CALIBRATION DONE"

# ---- 3. counts on both nodes, once the build is done
wait $BP
log "Devastator build done: $(tail -1 $OUT/deva_build.txt)"
grep -E "^(OK|FAIL)" $D/logs/build-summary.txt | tail -16

( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model Dragonfly --model Traffic \
    bucket_window agg_deadline_bucket_pp > $OUT/gate_models.txt 2>&1 )
tail -4 $OUT/gate_models.txt; grep -E "FAIL|TIMEOUT" $OUT/gate_models.txt | head

# Charades test config -> engine arguments
args() { # model config engine
  local f=$C/models/$1/test_configs/$2 k v out=()
  while IFS='=' read -r k v || [ -n "$k" ]; do
    case $k in ''|\#*|gvt-bucket-size|buffer-size|expected-events|lps-per-chare) continue ;; esac
    if [ $3 = ross ]; then
      case $k in end-time) k=end ;; end-size) k=dest-size ;; end-x) k=dest-x ;; end-y) k=dest-y ;; esac
    else
      [ $1 = dragonfly ] && [ $k = lookahead ] && continue
    fi
    out+=("--$k=$v")
  done < $f
  echo "${out[@]}"; }
expect() { awk -F= '/^expected-events=/{print $2}' $C/models/$1/test_configs/$2; }
check() { # engine model config got
  local e=$(expect $2 $3)
  echo "$1 $2 $3 expected=$e got=$4 $([ "$4" = "$e" ] && echo OK || echo MISMATCH)"; }

( module load mvapich/3.0 >/dev/null 2>&1
  unset FI_PROVIDER FI_PROVIDER_PATH LCI_ATTR_BACKEND LCI_ATTR_OFI_PROVIDER_NAME LCI_ATTR_PACKET_SIZE PSM2_MULTI_EP
  for m in dragonfly:5:base dragonfly:5:congested dragonfly:5:gentime traffic:4:base traffic:4:trips; do
    IFS=: read -r model n cfg <<< "$m"
    o=$OUT/ross_${model}_$cfg.out
    timeout -s TERM 120 srun --mpi=pmi2 --kill-on-bad-exit=1 -J ross_chk -N 2 -n $n \
      $RB/$model/$model --synch=3 --read-buffer=1 --extramem=400000 $(args $model $cfg ross) > $o 2>&1
    check ross $model $cfg "$(awk '/Net Events Processed/{print $NF; exit}' $o)"
  done )

( export GASNET_BACKTRACE=1 GASNET_OFI_SPAWNER=pmi FI_PROVIDER=psm2
  unset FI_PROVIDER_PATH
  for m in dragonfly:p2w3:base dragonfly:p2w3:congested dragonfly:p2w3:gentime traffic:p2w2:base traffic:p2w2:trips; do
    IFS=: read -r model lay cfg <<< "$m"
    o=$OUT/deva_${model}_$cfg.out b=$D/bin/ofi-psm2/$model-$lay
    [ -x $b ] || { echo "devastator $model $cfg: no binary $b"; continue; }
    timeout -s TERM 120 srun --mpi=pmi2 --kill-on-bad-exit=1 -J deva_chk -N 2 -n 2 --ntasks-per-node=1 -c 8 \
      --cpu-bind=cores $b $(args $model $cfg deva) --rng=clcg4 > $o 2>&1
    check devastator $model $cfg "$(grep -o 'committed=[0-9]*' $o | head -1 | cut -d= -f2)"
  done )
log "PHASEB175 DONE"
