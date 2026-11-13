#!/bin/bash -l
#SBATCH -J vscale240
#SBATCH -t 01:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/vscale240_%j.out
# VLSI at 32 nodes for F5 (charades RESULTS.md section 240): job VS3's arms
# (vscale238.slurm, section 238) in a 32-node allocation. b19 x N, one copy per
# node, 5,000 cycles, Devastator in the same allocation. First, 16 nodes on each
# half side by side (3 reps each: does a 16-node run inside a 32-node
# allocation meet the slow count waves of section 228?), then 32 nodes, 5 reps.
#   Charades charades-r5 (85a2aad: round 3, eager commits by default,
#   --ctl-reach-buckets=2), 1 x 46, --batch=32, buckets of 2,500 ps:
#     E:w5000  eager commits, W 5,000 (the new setting)
#     E:w2500  eager commits, W 2,500
#     L:w2500  lazy commits (--fossil-lazy=1), W 2,500 (VS2's setting from 4 nodes up)
#     E:mb0    the frozen controller (--ctl=3, bracketed, reach 2 buckets), eager commits
#   d2  Devastator 2 x 23, W 2,500 / 5,000 / 10,000 (as VS2)
# --pe-stats=1 on the O arm only (since section 247). From 4 nodes up, copy 2's node (the third
# of the run's nodes) is sampled before and after each Charades run:
# /proc/stat and /proc/interrupts (PE 105 = rank 13, pinned to core 28 by
# +pemap), to find what slows that PE in slow reps (sections 234, 236).
# Engines interleaved per rep; engine and arm order reversed in rep 2.
# Since 2026-11-06 (section 247): Charades timing arms run the paper launch only
# (+lci_ndevices 23 +pemap ... +mempool_remote_free --batch=32; no --ctl-log,
# --blocked-time, --commit-digest, --copy-stats or --pe-stats: --ctl-log cost
# the controller 2-6%, section 246). Check arms at E W 5,000, every rep:
#   O:w5000  the old diagnostics (--blocked-time=1 --commit-digest=1
#            --copy-stats=1 --pe-stats=1): the digest check, the per-PE stats
#            for slow reps, and their cost
#   G:w5000  --commit-digest=1 only (mode a)
#   R:w5000  --report-interval=1000000, no GVT progress lines (mode a)
# First argument:
#   a    16 nodes: VS3's layout (vscale238.slurm), 8, 4, 2 and 1 nodes side by
#        side (nodes 0-7 / 8-11 / 12-13 / 14), then 16; 3 reps
#   big  32 nodes: 16 nodes on each half side by side (3 reps), then 32 (5 reps)
# Submit: sbatch -p skx -N 32 -n 1536 -x c455-081 -t 01:45:00 vscale240.slurm big
#         sbatch -p skx-dev -N 16 -n 768 -x c455-081 -t 00:50:00 vscale240.slurm a
set -u
G=${1:-big}
case $G in a) NS="1 2 4 8 16"; NN=16 ;; big) NS="16 32"; NN=32 ;; *) echo "mode a or big"; exit 1 ;; esac
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/f1_240/vlsi${G/big/32}_j${SLURM_JOB_ID:-dry}; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T5=charades-r5; C5=$W/$T5; S=$C5/scripts/stampede3/ctl_sweep.sh; B=$C5/models/vlsi/vlsi
D=$W/devastator; DB=$D/bin/ofi-psm2; NETLIST=$W/I99T/i99t/b19/b19.bench
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}"
[ "$(git -C $C5 rev-parse --short=7 HEAD)" = 85a2aad ] || { log "$T5 not at 85a2aad"; exit 1; }
for f in ctl-reach-buckets "Trials past it" fossil-finish "PER-PE WITH A SHARED SPARE LIST" direct-execute pe-stats; do
  strings $B | grep -q -- "$f" || { log "$B lacks $f"; exit 1; }
done
ldd $B | grep -q charm-pads-perf/ || { log "$B does not link charm-pads-perf"; exit 1; }
grep -q "mb)   extra" $S || { log "ctl_sweep.sh lacks the mb arm"; exit 1; }
for n in $NS; do [ -x $DB/vlsi-p$((2 * n))w23 ] || { log "missing $DB/vlsi-p$((2 * n))w23"; exit 1; }; done
[ -e $NETLIST ] || { log "missing $NETLIST"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }
# Twin guard: TWIN (environment) or $TWF (written after both copies are
# submitted) names the same job queued elsewhere; the copy that starts first
# cancels it, one that starts second exits.
TWF=$W/charades-runs/f1_240/vscale240_$G.twin
TWIN=${TWIN:-$(cat $TWF 2>/dev/null)}
if [ -n "${TWIN:-}" ]; then
  st=$(squeue -h -j $TWIN -o %T 2>/dev/null)
  [ "$st" = PENDING ] || { log "twin $TWIN is ${st:-not queued}: exiting"; exit 0; }
  scancel $TWIN && log "twin $TWIN was pending: cancelled"
fi
[ ${#NL[@]} -ge $NN ] || { log "need $NN nodes, got ${#NL[@]}"; exit 1; }

# ---- gate: the change tier on 2 nodes, VLSI, eager commits
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C5/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $C5/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model VLSI \
    agg_ctl_measured_fast_bucket_pp bucket_window ctl_measured_bucket > $OUT/gate.txt 2>&1 )
tail -3 $OUT/gate.txt
grep -q "Failed: *0/" $OUT/gate.txt && grep -q "Timed out: *0/" $OUT/gate.txt || { log "GATE FAILED"; exit 1; }
grep -q "Passed: *[1-9]" $OUT/gate.txt || { log "GATE RAN NOTHING"; exit 1; }
log "GATE DONE"

export TREE=$T5 PPN=1 PEPP=46 CPT=48 CAP=300 VLSI_NETLISTS=$W/I99T/i99t
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --batch=32"
V_END=12500000 CAPX=300
opt() { case $1 in E) echo "" ;; L) echo "--fossil-lazy=1" ;; O) echo "--blocked-time=1 --commit-digest=1 --copy-stats=1 --pe-stats=1" ;;
  G) echo "--commit-digest=1" ;; R) echo "--report-interval=1000000" ;; esac; }
snap() { # node file: copy 2's node, every CPU's times and interrupt counts
  ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 $1 'date +%s.%N; cat /proc/stat; cat /proc/interrupts' > $2 2>&1 || true; }
# one run per ctl_sweep call, so that each run's pe_stats.csv lands in its own directory
cs() { # rep nodes nodelist setting arm [end]
  local rep=$1 N=$2 nl=$3 s=$4 a=$5 end=${6:-$V_END}
  local arm=$(echo $a | sed -E 's/^(w|mb)([0-9]+)$/\1:\2/')
  local d=$OUT/n$N/$rep/${s}_$a; mkdir -p $OUT/n$N/$rep
  local n2=$(echo $nl | cut -d, -f3)
  [ $N -ge 4 ] && snap $n2 $d.snap0
  ( export NODES=$N AGG=off WORKLOADS=vlsi:b19:1:1 ARMS="$arm" END=$end BUCKETS=2500 LPC=128 LPS_PER_PE=128 \
      EXTRA_ARGS="$L $(opt $s)" SRUN_ARGS="-w $nl"
    RUNS=$d $S 1 $d.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$N $rep $s /" )
  [ $N -ge 4 ] && snap $n2 $d.snap1
  # exactly one run, of the arm asked for
  [ "$(tail -n +2 $d.csv | cut -d, -f10 | tr '\n' ' ')" = "$arm " ] || { log "WRONG ARMS in $d.csv"; return 1; }
  rm -f $d/ctl_sweep/logs/*.digest.csv $d/ctl_sweep/gvt_*.out; }
dv() { # nodes nodelist window rep: Devastator 2 x 23, as VS2
  local N=$1 nl=$2 w=$3 rep=$4 p=$((2 * $1)) f=$OUT/n$1/deva/w$3_r$4.out
  local bin=$DB/vlsi-p${p}w23
  [ -e $OUT/n$N/skip_dv_$w ] && { echo "n$N dv W $w r$rep skipped"; return; }
  mkdir -p $OUT/n$N/deva
  ( export GASNET_BACKTRACE=1 GASNET_OFI_SPAWNER=pmi FI_PROVIDER=psm2 deva_static_look_dt=$w; unset FI_PROVIDER_PATH
    t0=$(date +%s.%N)
    timeout -s TERM $CAPX srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -J dv_n$N -w $nl -N $N -n $p \
      --ntasks-per-node=2 -c 24 --cpu-bind=cores -m block:block \
      stdbuf -oL $bin --netlist=$NETLIST --copies=$N --span=1 --chunk=512 --end-time=$V_END > $f 2>&1
    rc=$?; wall=$(printf %.1f "$(echo "$(date +%s.%N) - $t0" | bc)")
    line=$(grep -m1 '^VLSI_RESULT' $f)
    v() { tr ' ' '\n' <<< "$line" | sed -n "s/^$1=//p"; }
    st=ok; [ -z "$line" ] && st=fail; [ $rc = 124 ] && st=stall
    [ $st = stall ] && [ $rep = 1 ] && touch $OUT/n$N/skip_dv_$w
    echo "engine=deva app=vlsi nodes=$N layout=p${p}w23 window=$w rep=$rep status=$st rc=$rc wall=$wall committed=$(v committed) executed=$(v executed) rolled_back=$(v rolled_back) run_s=$(v wall_s) M_ev_s=$(awk -v r="$(v committed_per_s)" 'BEGIN{if (r != "") printf "%.2f", r / 1e6}') deterministic=$(v deterministic)" \
      | tee -a $OUT/deva.txt | sed "s/^/n$N /" | cut -c1-200 )
}
CH=(E:w5000 E:w2500 L:w2500 E:mb0 O:w5000)
[ $G = a ] && CH+=(G:w5000 R:w5000)
DW=(2500 5000 10000)
rev() { local a=("$@") out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
engines() { # nodes nodelist rep [half]
  local N=$1 nl=$2 rep=$3 h=${4:-} x e ch dw es
  if [ $rep = 2 ]; then ch=($(rev "${CH[@]}")); dw=($(rev "${DW[@]}")); es="devastator charades"
  else ch=("${CH[@]}"); dw=("${DW[@]}"); es="charades devastator"; fi
  for e in $es; do
    case $e in
      charades) for x in "${ch[@]}"; do cs r$rep$h $N $nl ${x%%:*} ${x##*:} || return 1; done ;;
      devastator) for x in "${dw[@]}"; do dv $N $nl $x $rep$h; done ;;
    esac
  done; }
stream() { # nodes nodelist reps [half]
  local N=$1 nl=$2 reps=$3 half=${4:-} rep
  cs warm$half $N $nl E w2500 1250000 || return 1
  for rep in $(seq $reps); do engines $N $nl $rep $half || return 1; log "N $N$half REP $rep DONE"; done; }

if [ $G = big ]; then
  # ---- 16 nodes on each half, side by side
  stream 16 $(join ${NL[@]:0:16}) 3 A > $OUT/stream_n16A.log 2>&1 &
  stream 16 $(join ${NL[@]:16:16}) 3 B > $OUT/stream_n16B.log 2>&1 &
  wait
  log "16 DONE"
  # ---- 32 nodes
  stream 32 $(join ${NL[@]:0:32}) 5 > $OUT/stream_n32.log 2>&1
  log "32 DONE"
else
  # ---- VS3's layout: 8, 4, 2 and 1 nodes side by side, then 16
  stream 8 $(join ${NL[@]:0:8}) 3 > $OUT/stream_n8.log 2>&1 &
  stream 4 $(join ${NL[@]:8:4}) 3 > $OUT/stream_n4.log 2>&1 &
  stream 2 $(join ${NL[@]:12:2}) 3 > $OUT/stream_n2.log 2>&1 &
  stream 1 ${NL[14]} 3 > $OUT/stream_n1.log 2>&1 &
  wait
  log "1/2/4/8 DONE"
  stream 16 $(join ${NL[@]:0:16}) 3 > $OUT/stream_n16.log 2>&1
  log "16 DONE"
fi
grep -h -E ' (fail|stall) |status=(fail|stall)|WRONG' $OUT/stream_n*.log | head -20
du -sh $OUT
log "VSCALE240 $G DONE"
