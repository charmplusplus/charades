#!/bin/bash -l
#SBATCH -J vdiag200
#SBATCH -t 00:45:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/vdiag200_%j.out
# VLSI job V4 (charades RESULTS.md section 200): one process per node against
# shared memory between the node's two processes, in both engines. b19 x N
# (one copy per node, span 1, balanced layout), direct sends, buckets of
# 2,500 ps, 5,000 cycles, --copy-stats=1; 1 and 4 nodes side by side; 2 reps,
# arm order reversed in rep 2. Builds and their checks ran in job vbuild200.
#   nodes 0-3: the 4-node series; node 4: the 1-node series
#   Charades (charades-vlsi c7373b4, with the message-pool fix of section 201,
#     and charades-shmem, the same commit on Charm++ --enable-shmem; --localalloc launch, --blocked-time=1,
#     --commit-digest=1):
#     A 2 x 23 W 2,500 (reference); B 1 x 46 W 2,500 / 5,000 / 10,000;
#     C 2 x 23 on charades-shmem W 2,500 / 5,000 / 10,000; D 2 x 23 +ipc W 2,500;
#     C with --comm-stats=1 at W 2,500
#   Devastator: p2w23 / p8w23 and p1w46 / p4w46, W 2,500 / 5,000 / 10,000
#   rep 1 only, 1 node: --pe-stats=1 --gvt-trace=1 for B and C at W 2,500;
#     perf (user cycles, task 0) of B and C
# Submit: sbatch -p skx-dev -N 5 -n 240 -x c455-081 vdiag200.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/vdiag200/j$SLURM_JOB_ID; mkdir -p $OUT/perf/B $OUT/perf/C
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
TV=charades-vlsi; TS=charades-shmem; D=$W/devastator
PW=$W/$TV/scripts/stampede3/perfwrap.sh; DB=$D/bin/ofi-psm2
NETLIST=$W/I99T/i99t/b19/b19.bench
NL=($(scontrol show hostnames $SLURM_JOB_NODELIST))
join() { local IFS=,; echo "$*"; }
log "job $SLURM_JOB_ID; nodes ${NL[*]}; on $(hostname -s)"
for t in $TV $TS; do
  log "$t $(git -C $W/$t log --oneline -1 | cut -c1-60)"
  strings $W/$t/models/vlsi/vlsi | grep -q "copy-stats" || { log "$t vlsi binary lacks --copy-stats"; exit 1; }
  strings $W/$t/models/vlsi/vlsi | grep -q "Shared-Memory Messages Received" || { log "$t vlsi binary lacks the shared-memory count"; exit 1; }
done
[ "$(git -C $W/$TV rev-parse HEAD)" = "$(git -C $W/$TS rev-parse HEAD)" ] || { log "$TV and $TS are on different commits"; exit 1; }
ldd $W/$TS/models/vlsi/vlsi | grep -q charm-pads-shmem || { log "$TS does not link charm-pads-shmem"; exit 1; }
grep -q "CMK_USE_SHMEM 1" $W/charm-pads-shmem/reconverse-linux-x86_64/include/conv-autoconfig.h || { log "charm-pads-shmem lacks CMK_USE_SHMEM"; exit 1; }
for b in $NETLIST $PW $DB/vlsi-p2w23 $DB/vlsi-p8w23 $DB/vlsi-p1w46 $DB/vlsi-p4w46; do
  [ -e $b ] || { log "missing $b"; exit 1; }
done

# ---- gate: the VLSI test tier on 2 nodes (charades-vlsi)
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/$TV/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $W/$TV/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model VLSI \
    agg_ctl_measured_fast_bucket_pp agg_deadline_bucket_pp agg_deadline_bucket_wps bucket_window ctl_measured_bucket > $OUT/gate.txt 2>&1 )
tail -3 $OUT/gate.txt
grep -q "Failed: *0/" $OUT/gate.txt && grep -q "Timed out: *0/" $OUT/gate.txt || {
  i=0; for f in $(grep -E " (FAIL|TIMEOUT) " $OUT/gate.txt | awk '{print $NF}'); do i=$((i+1)); cp $f $OUT/gate_fail_$i.out 2>/dev/null; done
  log "GATE FAILED (outputs in $OUT/gate_fail_*.out)"; exit 1; }
log "GATE DONE"

export CAP=300 VLSI_NETLISTS=$W/I99T/i99t
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1 --commit-digest=1 --copy-stats=1"
V_END=12500000 CAPX=300
cs() { # tag nodes nodelist tree procs:PEs:cores arms [engine args] [perf dir]
  local tag=$1 N=$2 nl=$3 tree=$4 lay=$5 arms=$6 extra=${7:-} pf=${8:-} ppn pepp cpt
  IFS=: read -r ppn pepp cpt <<< "$lay"
  ( export TREE=$tree NODES=$N PPN=$ppn PEPP=$pepp CPT=$cpt AGG=off WORKLOADS=vlsi:b19:1:1 ARMS="$arms" END=$V_END \
      BUCKETS=2500 LPC=128 LPS_PER_PE=128 EXTRA_ARGS="$L $extra" SRUN_ARGS="-w $nl"
    [ -n "$pf" ] && export BIN_WRAP=$PW PERF_DIR=$OUT/perf/$pf
    RUNS=$OUT/n$N/$tag $W/$tree/scripts/stampede3/ctl_sweep.sh 1 $OUT/n$N/$tag.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$N $tag /" )
  rm -f $OUT/n$N/$tag/ctl_sweep/logs/*.digest.csv; }
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
arms() { # nodes nodelist rep
  local N=$1 nl=$2 rep=$3 steps a W3="w:2500 w:5000 w:10000" w
  steps="A B C D Ccs d2 d1"
  [ $((rep % 2)) = 0 ] && { steps=$(rev "$steps"); W3=$(rev "$W3"); }
  for a in $steps; do
    case $a in
      A)   cs s1_A_r$rep   $N $nl $TV 2:23:24 w:2500 ;;
      B)   cs s1_B_r$rep   $N $nl $TV 1:46:48 "$W3" ;;
      C)   cs s1_C_r$rep   $N $nl $TS 2:23:24 "$W3" ;;
      D)   cs s1_D_r$rep   $N $nl $TV 2:23:24 w:2500 "+ipc" ;;
      Ccs) cs s1_Ccs_r$rep $N $nl $TS 2:23:24 w:2500 "--comm-stats=1" ;;
      d2)  for w in ${W3//w:/}; do dv d2 $N $nl 2:23 $w $rep; done ;;
      d1)  for w in ${W3//w:/}; do dv d1 $N $nl 1:46 $w $rep; done ;;
    esac
  done; }
extras() { # nodes nodelist (rep 1 only, 1 node)
  local N=$1 nl=$2
  [ $N = 1 ] || return
  cs peB $N $nl $TV 1:46:48 w:2500 "--pe-stats=1 --gvt-trace=1"
  cs peC $N $nl $TS 2:23:24 w:2500 "--pe-stats=1 --gvt-trace=1"
  cs perfB $N $nl $TV 1:46:48 w:2500 "" B
  cs perfC $N $nl $TS 2:23:24 w:2500 "" C; }
stream() { # nodes nodelist
  local N=$1 nl=$2
  arms $N $nl 1; log "N $N REP 1 DONE"
  extras $N $nl; log "N $N EXTRAS DONE"
  arms $N $nl 2; log "N $N REP 2 DONE"; }
stream 4 $(join ${NL[@]:0:4}) > $OUT/stream_n4.log 2>&1 &
stream 1 ${NL[4]} > $OUT/stream_n1.log 2>&1 &
wait
grep -h -E ' (fail|stall) |status=(fail|stall)' $OUT/stream_n*.log | head -20
for e in B C; do
  f=$(ls $OUT/perf/$e/*.data 2>/dev/null | head -1)
  [ -n "$f" ] && perf report -i $f --stdio --no-children --sort dso,sym --percent-limit 0.3 2>/dev/null | head -200 > $OUT/perf/$e.report.txt
done
ls -la $OUT/perf/*.report.txt 2>/dev/null
log "VDIAG200 DONE"
