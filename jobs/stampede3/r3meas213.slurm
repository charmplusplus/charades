#!/bin/bash -l
#SBATCH -J r3meas213
#SBATCH -t 00:50:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/r3meas213_%j.out
# Closing the gap, round 3 (charades RESULTS.md section 213), 1 node.
#   Build charades-r3 (the round-3 commit) on the node; gate: the change tier
#   on 1 node (1 x 4, 2 x 2, 4 x 2) for VLSI, Simple PHOLD, traffic and
#   dragonfly, then VLSI and Simple PHOLD again with --fossil-lazy=1.
#   VLSI b19 x 1, 1 x 46, --fossil-lazy=1 --batch=32, W 5,000, buckets of
#   2,500 ps, --blocked-time=1 --commit-digest=1; 3 reps, arm order rotated:
#     base  charades-perf (5b14290, the tree of the scaling job)
#     cd    charades-r3 --direct-execute=0 --msg-pool=1 (fossil list, inline
#           accessors, mapper shift, attempt_gvt and fast-path route changes)
#     cda   charades-r3 --msg-pool=1 (+ the direct call)
#     all   charades-r3 (+ the pool's spare list)
#   2 x 23 over +ipc: base and all, 2 reps
#   Simple PHOLD at 2 x 23 over LCI (the paper's launch): sigma 100 (PP 2,048)
#   and uniform (WPs 512), W 300, base and all, 2 reps
#   perf of the simulation alone (perfwrap_d.sh) for base and all
# Submit: sbatch -p skx -N 1 -n 48 -x c455-081 r3meas213.slurm (skx-dev once job a is done)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/r3meas213/j${SLURM_JOB_ID:-dry}; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
TB=charades-perf; TR=charades-r3; NODE=$(hostname -s)
log "job ${SLURM_JOB_ID:-dry} on $NODE"
for t in $TB $TR; do log "$t $(git -C $W/$t log --oneline -1 | cut -c1-70)"; done
grep -q "CHARADES_SRC *= *$W/$TR/src" $W/$TR/src/config.mk || { log "$TR config.mk does not point at $TR"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }

# ---- build charades-r3 on the node
# a fresh tree's parallel make can compile a file before charmc has made the
# .decl.h it includes (3679870): retry serially
( cd $W/$TR/src && { make -j8 > $OUT/build_lib.log 2>&1 || make -j1 >> $OUT/build_lib.log 2>&1; } ) || { log "lib build FAILED"; tail -5 $OUT/build_lib.log; exit 1; }
for m in vlsi phold/simple traffic dragonfly; do
  ( cd $W/$TR/models/$m && { make -j8 > $OUT/build_$(basename $m).log 2>&1 || make -j1 >> $OUT/build_$(basename $m).log 2>&1; } ) || { log "$m build FAILED"; exit 1; }
done
for m in vlsi/vlsi phold/simple/phold; do
  strings $W/$TR/models/$m | grep -q "direct-execute" || { log "$TR $m lacks --direct-execute"; exit 1; }
  strings $W/$TR/models/$m | grep -q "Message Pool Misses" || { log "$TR $m lacks the pool counters"; exit 1; }
  ldd $W/$TR/models/$m | grep -q charm-pads-perf/ || { log "$TR $m does not link charm-pads-perf"; exit 1; }
done
log "BUILD DONE"

# ---- gate
gate() { # tag extra-run-args models...
  local tag=$1 args=$2; shift 2
  local ms=(); for m in "$@"; do ms+=(--model "$m"); done
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/$TR/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $W/$TR/tests; export CHARADES_RUN_ARGS="+mempool_remote_free $args"
    python3 test.py --tier change --no-build --launcher srun --nodes 1 "${ms[@]}" \
      bucket_window bucket_pool agg_ctl_measured_fast_bucket_pp ctl_measured_bucket bucket_rbchare > $OUT/gate_$tag.txt 2>&1 )
  tail -2 $OUT/gate_$tag.txt
  grep -q "Failed: *0/" $OUT/gate_$tag.txt && grep -q "Timed out: *0/" $OUT/gate_$tag.txt; }
gate eager "" VLSI "Simple PHOLD" Traffic Dragonfly || { log "GATE FAILED (eager)"; exit 1; }
gate lazy "--fossil-lazy=1" VLSI "Simple PHOLD" || { log "GATE FAILED (lazy)"; exit 1; }
log "GATE DONE"

export CAP=300 VLSI_NETLISTS=$W/I99T/i99t
LV="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --commit-digest=1 --fossil-lazy=1 --batch=32"
LB="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1"
cs() { # tag tree procs:PEs:cores extra
  local tag=$1 tree=$2 lay=$3 extra=${4:-} ppn pepp cpt
  IFS=: read -r ppn pepp cpt <<< "$lay"
  ( export TREE=$tree NODES=1 PPN=$ppn PEPP=$pepp CPT=$cpt AGG=off WORKLOADS=vlsi:b19:1:1 ARMS=w:5000 END=12500000 \
      BUCKETS=2500 LPC=128 LPS_PER_PE=128 EXTRA_ARGS="$LV $extra" SRUN_ARGS="-w $NODE"
    RUNS=$OUT/$tag $W/$tree/scripts/stampede3/ctl_sweep.sh 1 $OUT/$tag.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/$tag /" )
  rm -f $OUT/$tag/ctl_sweep/logs/*.digest.csv; }
csb() { # tag tree agg workload
  ( export TREE=$2 NODES=1 PPN=2 PEPP=23 CPT=24 AGG=$3 WORKLOADS="$4" ARMS=w:300 END=2048000 BUCKETS=8 LPS_PER_PE=128 LPC=16 \
      EXTRA_ARGS="$LB" SRUN_ARGS="-w $NODE"
    RUNS=$OUT/$1 $W/$2/scripts/stampede3/ctl_sweep.sh 1 $OUT/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
arm() { # name rep
  case $1 in
    base) cs base_r$2 $TB 1:46:48 ;;
    cd)   cs cd_r$2   $TR 1:46:48 "--direct-execute=0 --msg-pool=1" ;;
    cda)  cs cda_r$2  $TR 1:46:48 "--msg-pool=1" ;;
    all)  cs all_r$2  $TR 1:46:48 ;;
    ipcbase) cs ipcbase_r$2 $TB 2:23:24 "+ipc" ;;
    ipcall)  cs ipcall_r$2  $TR 2:23:24 "+ipc" ;;
  esac; }
cs warm $TR 1:46:48
for rep in 1 2 3; do
  case $rep in 1) o="base cd cda all" ;; 2) o="all cda cd base" ;; 3) o="cd all base cda" ;; esac
  for a in $o; do arm $a $rep; done
  log "VLSI REP $rep DONE"
done
for rep in 1 2; do
  [ $rep = 1 ] && o="ipcbase ipcall" || o="ipcall ipcbase"
  for a in $o; do arm $a $rep; done
  for t in $([ $rep = 1 ] && echo "$TB $TR" || echo "$TR $TB"); do
    k=$([ $t = $TB ] && echo base || echo all)
    csb g100_${k}_r$rep $t pp:2048 gauss:100:1000:100
    csb uni_${k}_r$rep  $t wps:512 steady:100:1000:1.0
  done
  log "IPC/PHOLD REP $rep DONE"
done

# ---- profiles of the simulation alone
for t in $TB $TR; do
  k=$([ $t = $TB ] && echo base || echo all); D=$OUT/prof_$k; mkdir -p $D
  ( export BIN_WRAP=$W/charades-runs/perfwrap_d.sh PERF_DIR=$D; cs prof_$k $t 1:46:48 )
  f=$(ls $D/*.data 2>/dev/null | head -1)
  [ -n "$f" ] && perf report -i $f --stdio --no-children --sort dso,sym --percent-limit 0.3 2>/dev/null | head -150 > $D/report.txt
  rm -f $D/*.data
done
log "R3MEAS213 DONE"
