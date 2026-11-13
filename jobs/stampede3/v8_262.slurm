#!/bin/bash -l
#SBATCH -J v8_262
#SBATCH -t 00:45:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/v8_262_%j.out
# Job V8 (charades results/phold.md section 262; user decision 2026-11-08:
# rerun VLSI's 8-node column). Job VA (section 249, vscale240.slurm a) ran
# VLSI's 8-node stream on nodes 0-7 beside three other streams, so node 0 (the
# batch host) hosted every stream's srun clients and polling loops; job R8
# (section 261) found that this cost Devastator 3-10% on PHOLD, traffic and
# dragonfly at 8 nodes. This job reruns VA's 8-node timing arms with node 0
# idle, one stream on nodes 1-8, 5 reps:
#   Charades charades-r5 (85a2aad), 1 x 46, --batch=32, buckets of 2,500 ps:
#     E:w5000  eager commits, W 5,000 (VLSI's setting)
#     E:w2500  eager commits, W 2,500
#     L:w2500  lazy commits (--fossil-lazy=1), W 2,500
#     E:mb0    the frozen controller (--ctl=3, bracketed, reach 2 buckets)
#   Devastator 2 x 23, W 2,500 / 5,000 / 10,000
# VA's check arms (O, G, R) are left out; no diagnostics in any command.
# Engines and arms in reverse order in even reps. A short warm-up run of each
# engine (not counted) starts the stream.
# Submit the skx copy first: sbatch -p skx -N 9 -n 432 -x c455-081 v8_262.slurm;
# then the skx-dev copy with --export=ALL,TWIN=<skx id>; then write the
# skx-dev id to $TWF.
# STUB=1 (login node, fake srun first in PATH, SLURM_JOB_ID and
# SLURM_JOB_NODELIST set): print every command, no gate.
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
STUB=${STUB:-0}
OUT=$W/charades-runs/v8_262/j${SLURM_JOB_ID:-dry}; [ $STUB = 1 ] && OUT=$W/charades-runs/v8_262/stub
mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
[ $STUB = 1 ] && export PATH=$W/charades-runs/f4b250/stubbin:$PATH   # its srun appends its command line to $STUBLOG
T5=charades-r5; C5=$W/$T5; S=$C5/scripts/stampede3/ctl_sweep.sh; B=$C5/models/vlsi/vlsi
D=$W/devastator; DB=$D/bin/ofi-psm2; NETLIST=$W/I99T/i99t/b19/b19.bench
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}; node 0 (${NL[0]:-}) stays idle"
log "charades $(git -C $C5 log --oneline -1 | cut -c1-60)"
[ "$(git -C $C5 rev-parse --short=7 HEAD)" = 85a2aad ] || { log "$T5 not at 85a2aad"; exit 1; }
for f in ctl-reach-buckets "Trials past it" fossil-finish "PER-PE WITH A SHARED SPARE LIST" direct-execute pe-stats; do
  strings $B | grep -q -- "$f" || { log "$B lacks $f"; exit 1; }
done
ldd $B | grep -q charm-pads-perf/ || { log "$B does not link charm-pads-perf"; exit 1; }
grep -q "mb)   extra" $S || { log "ctl_sweep.sh lacks the mb arm"; exit 1; }
[ -x $DB/vlsi-p16w23 ] || { log "missing $DB/vlsi-p16w23"; exit 1; }
[ -e $NETLIST ] || { log "missing $NETLIST"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }
[ ${#NL[@]} -ge 9 ] || { log "need 9 nodes, got ${#NL[@]}"; exit 1; }

if [ $STUB != 1 ]; then
# TWIN (sbatch --export=ALL,TWIN=<job id>): the same job queued elsewhere. The
# copy that starts first runs and cancels the other; one that starts second exits.
# The first-submitted copy reads the other's ID from $TWF, written after both.
TWF=$W/charades-runs/v8_262/v8_262.twin
TWIN=${TWIN:-$(cat $TWF 2>/dev/null)}
if [ -n "${TWIN:-}" ]; then
  st=$(squeue -h -j $TWIN -o %T 2>/dev/null)
  [ "$st" = PENDING ] || { log "twin $TWIN is ${st:-not queued}: exiting"; exit 0; }
  scancel $TWIN && log "twin $TWIN was pending: cancelled"
fi
# ---- gate: the change tier on 2 nodes, VLSI, eager commits (as VA)
gate() { # output file
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C5/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $C5/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
    python3 test.py --tier change --no-build --launcher srun --nodes 2 --model VLSI \
      agg_ctl_measured_fast_bucket_pp bucket_window ctl_measured_bucket > $1 2>&1 )
  tail -4 $1; grep -E "FAIL|TIMEOUT" $1 | head
  grep -q "Failed: *0/" $1 && grep -q "Timed out: *0/" $1 && grep -q "Passed: *[1-9]" $1; }
# Once more if every failed test read /work2 badly: an I/O error, or the run
# printed the engine's default protocol (2), which none of these configs uses
# (a config file that opens but cannot be read is parsed as empty; job
# 3696078, section 263)
if ! gate $OUT/gate.txt; then
  bad=$(grep -E "FAIL|TIMEOUT" $OUT/gate.txt | awk '{print $NF}' | grep "test.out$")
  if [ -n "$bad" ] && [ -z "$(for f in $bad; do grep -q -E "Input/output error|Synch Protocol\.+2$" $f || echo $f; done)" ]; then
    log "GATE: /work2 read errors only; rerunning"
    gate $OUT/gate2.txt || { log "GATE FAILED"; exit 1; }
  else log "GATE FAILED"; exit 1; fi
fi
log "GATE DONE"
fi

export TREE=$T5 PPN=1 PEPP=46 CPT=48 CAP=300 VLSI_NETLISTS=$W/I99T/i99t
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --batch=32"
V_END=12500000 CAPX=300 N=8 NL8=$(join ${NL[@]:1:8})
opt() { case $1 in E) echo "" ;; L) echo "--fossil-lazy=1" ;; esac; }
cs() { # rep setting arm [end]: one run per ctl_sweep call
  local rep=$1 s=$2 a=$3 end=${4:-$V_END}
  local arm=$(echo $a | sed -E 's/^(w|mb)([0-9]+)$/\1:\2/')
  local d=$OUT/n$N/$rep/${s}_$a; mkdir -p $OUT/n$N/$rep
  ( export NODES=$N AGG=off WORKLOADS=vlsi:b19:1:1 ARMS="$arm" END=$end BUCKETS=2500 LPC=128 LPS_PER_PE=128 \
      EXTRA_ARGS="$L $(opt $s)" SRUN_ARGS="-w $NL8"
    RUNS=$d $S 1 $d.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$N $rep $s /" )
  [ $STUB = 1 ] && return 0
  # exactly one run, of the arm asked for
  [ "$(tail -n +2 $d.csv | cut -d, -f10 | tr '\n' ' ')" = "$arm " ] || { log "WRONG ARMS in $d.csv"; return 1; }
  rm -f $d/ctl_sweep/logs/*.digest.csv $d/ctl_sweep/gvt_*.out; }
dv() { # window rep: Devastator 2 x 23, as VA
  local w=$1 rep=$2 p=$((2 * N)) f=$OUT/n$N/deva/w$1_r$2.out
  mkdir -p $OUT/n$N/deva
  ( export GASNET_BACKTRACE=1 GASNET_OFI_SPAWNER=pmi FI_PROVIDER=psm2 deva_static_look_dt=$w; unset FI_PROVIDER_PATH
    t0=$(date +%s.%N)
    timeout -s TERM $CAPX srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -J dv_n$N -w $NL8 -N $N -n $p \
      --ntasks-per-node=2 -c 24 --cpu-bind=cores -m block:block \
      stdbuf -oL $DB/vlsi-p${p}w23 --netlist=$NETLIST --copies=$N --span=1 --chunk=512 --end-time=$V_END > $f 2>&1
    rc=$?; wall=$(printf %.1f "$(echo "$(date +%s.%N) - $t0" | bc)")
    line=$(grep -m1 '^VLSI_RESULT' $f)
    v() { tr ' ' '\n' <<< "$line" | sed -n "s/^$1=//p"; }
    st=ok; [ -z "$line" ] && st=fail; [ $rc = 124 ] && st=stall
    echo "engine=deva app=vlsi nodes=$N layout=p${p}w23 window=$w rep=$rep status=$st rc=$rc wall=$wall committed=$(v committed) executed=$(v executed) rolled_back=$(v rolled_back) run_s=$(v wall_s) M_ev_s=$(awk -v r="$(v committed_per_s)" 'BEGIN{if (r != "") printf "%.2f", r / 1e6}') deterministic=$(v deterministic)" \
      | tee -a $OUT/deva.txt | sed "s/^/n$N /" | cut -c1-200 ); }
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
ord() { [ $(($2 % 2)) = 1 ] && echo "$1" || rev "$1"; }   # list rep: reversed in even reps
CH="E:w5000 E:w2500 L:w2500 E:mb0"; DW="2500 5000 10000"
{
  cs warm E w2500 1250000 || exit 1
  dv 2500 warm
  for rep in 1 2 3 4 5; do
    for e in $(ord "charades devastator" $rep); do
      case $e in
        charades) for x in $(ord "$CH" $rep); do cs r$rep ${x%%:*} ${x##*:} || exit 1; done ;;
        devastator) for w in $(ord "$DW" $rep); do dv $w $rep; done ;;
      esac
    done
    log "N $N REP $rep DONE"
  done
} > $OUT/stream_n8.log 2>&1
grep -h -E ' (fail|stall) |status=(fail|stall)|WRONG' $OUT/stream_n8.log | grep -v -E ' warm |rep=warm' | head -20
du -sh $OUT
log "V8_262 DONE"
