#!/bin/bash -l
#SBATCH -J vscale238
#SBATCH -t 00:50:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/vscale238_%j.out
# Job VS3 (charades RESULTS.md section 238): the paper's VLSI row at 1-16 nodes
# with VLSI's new setting (section 236), b19 x N, one copy per node, 5,000
# cycles, Devastator in the same allocation.
#   Charades charades-r5 (85a2aad: round 3, eager commits by default,
#   --ctl-reach-buckets=2), 1 x 46, --batch=32, buckets of 2,500 ps:
#     E:w5000  eager commits, W 5,000 (the new setting)
#     E:w2500  eager commits, W 2,500
#     L:w2500  lazy commits (--fossil-lazy=1), W 2,500 (VS2's setting from 4 nodes up)
#     E:mb0    the frozen controller (--ctl=3, bracketed, reach 2 buckets), eager commits
#   d2  Devastator 2 x 23, W 2,500 / 5,000 / 10,000 (as VS2)
# --pe-stats=1 on every Charades run. From 4 nodes up, copy 2's node (the third
# of the run's nodes) is sampled before and after each Charades run:
# /proc/stat and /proc/interrupts (PE 105 = rank 13, pinned to core 28 by
# +pemap), to find what slows that PE in slow reps (sections 234, 236).
# Engines interleaved per rep; engine and arm order reversed in rep 2.
#   8, 4, 2 and 1 nodes side by side (nodes 0-7 / 8-11 / 12-13 / 14), then 16.
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 vscale238.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/vscale238/j${SLURM_JOB_ID:-dry}; mkdir -p $OUT
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
for n in 1 2 4 8 16; do [ -x $DB/vlsi-p$((2 * n))w23 ] || { log "missing $DB/vlsi-p$((2 * n))w23"; exit 1; }; done
[ -e $NETLIST ] || { log "missing $NETLIST"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }
[ ${#NL[@]} -ge 16 ] || { log "need 16 nodes, got ${#NL[@]}"; exit 1; }

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
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1 --commit-digest=1 --copy-stats=1 --pe-stats=1 --batch=32"
V_END=12500000 CAPX=300
opt() { case $1 in E) echo "" ;; L) echo "--fossil-lazy=1" ;; esac; }
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
CH=(E:w5000 E:w2500 L:w2500 E:mb0)
DW=(2500 5000 10000)
rev() { local a=("$@") out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
engines() { # nodes nodelist rep
  local N=$1 nl=$2 rep=$3 x e ch dw es
  if [ $rep = 2 ]; then ch=($(rev "${CH[@]}")); dw=($(rev "${DW[@]}")); es="devastator charades"
  else ch=("${CH[@]}"); dw=("${DW[@]}"); es="charades devastator"; fi
  for e in $es; do
    case $e in
      charades) for x in "${ch[@]}"; do cs r$rep $N $nl ${x%%:*} ${x##*:} || return 1; done ;;
      devastator) for x in "${dw[@]}"; do dv $N $nl $x $rep; done ;;
    esac
  done; }
stream() { # nodes nodelist
  local N=$1 nl=$2 rep
  cs warm $N $nl E w2500 1250000 || return 1
  for rep in 1 2 3; do engines $N $nl $rep || return 1; log "N $N REP $rep DONE"; done; }

stream 8 $(join ${NL[@]:0:8}) > $OUT/stream_n8.log 2>&1 &
stream 4 $(join ${NL[@]:8:4}) > $OUT/stream_n4.log 2>&1 &
stream 2 $(join ${NL[@]:12:2}) > $OUT/stream_n2.log 2>&1 &
stream 1 ${NL[14]} > $OUT/stream_n1.log 2>&1 &
wait
log "1/2/4/8 DONE"
stream 16 $(join ${NL[@]:0:16}) > $OUT/stream_n16.log 2>&1
log "16 DONE"
grep -h -E ' (fail|stall) |status=(fail|stall)|WRONG' $OUT/stream_n*.log | head -20
du -sh $OUT
log "VSCALE238 DONE"
