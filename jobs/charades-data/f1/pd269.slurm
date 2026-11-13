#!/bin/bash -l
#SBATCH -J pd269
#SBATCH -t 01:15:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/pd269_%j.out
# Job PD16 (charades results/aggregation.md section 269; user decision
# 2026-11-09: one bounded diagnostic of section 268's local 1). Charades only,
# 16 nodes, one stream, tree charades-pplpad (charades branch pp-pad on
# pp-local), htram htram-pplpad (branch pp-pad on pp-local), the paper launch.
# F1's PHOLD settings (end 2,048,000, bucket 8, 128 LPs per PE, 2 x 23 PEs).
# Part A, timing (W 400 only, 5 reps; settings and workloads reversed in even
# reps; no diagnostics). AGG pp:512:l<N>:p<M> is --agg-pp-local=N
# --agg-pp-pad=M (pad 0 packed counters, 1 one destination per cache line in
# each array, 2 one cache line per destination holding all four):
#   uniform     wps:512, pp:512, pp:512::p1, pp:512::p2,
#               pp:512:l1, pp:512:l1:p1, pp:512:l1:p2
#   sigma 4,000 pp:512, pp:512::p2, pp:512:l1, pp:512:l1:p1, pp:512:l1:p2
# Part B, profiles (check runs after part A, not timing): uniform W 400, one
# run each of wps:512, pp:512, pp:512:l1, pp:512:l1:p1, pp:512:l1:p2 with
# perfwrap_d.sh (perf record cycles:u at 1,999 Hz in task 0, one process of
# 23 PEs, from 3 s after launch), reported in the job.
# Submit (twin guard): sbatch -p skx -N 16 -n 768 -x c455-081 pd269.slurm
#   then sbatch -p skx-dev -N 16 -n 768 -x c455-081 --export=ALL,TWIN=<skx id> pd269.slurm
#   then echo <skx-dev id> > $TWF
# STUB=1 (login node, fake srun first in PATH, SLURM_JOB_ID and
# SLURM_JOB_NODELIST set): print every command, no gate, no perf reports.
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
STUB=${STUB:-0}
OUT=$W/charades-runs/pd269/j${SLURM_JOB_ID:-dry}; [ $STUB = 1 ] && OUT=$W/charades-runs/pd269/stub
mkdir -p $OUT
TWF=$W/charades-runs/pd269/pd269.twin
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
[ $STUB = 1 ] && export PATH=$W/charades-runs/f4b250/stubbin:$PATH
T=charades-pplpad; C=$W/$T; H=$W/htram-pplpad; S=$C/scripts/stampede3/ctl_sweep.sh; B=$C/models/phold/simple/phold
PW=$W/charades-runs/perfwrap_d.sh
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
N=16; NL16=$(join ${NL[@]:0:16})
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}"
log "charades $(git -C $C log --oneline -1 | cut -c1-60); htram $(git -C $H log --oneline -1 | cut -c1-60)"
[ "$(git -C $C rev-parse --abbrev-ref HEAD)" = pp-pad ] || { log "$T not on branch pp-pad"; exit 1; }
[ "$(git -C $H rev-parse --abbrev-ref HEAD)" = pp-pad ] || { log "htram-pplpad not on branch pp-pad"; exit 1; }
[ -z "$(git -C $C status --porcelain -uno)" ] && [ -z "$(git -C $H status --porcelain -uno)" ] || { log "uncommitted changes"; exit 1; }
grep -q "^HTRAM_DIR *= *$H$" $C/src/config.mk || { log "$T does not build $H"; exit 1; }
grep -q "^CHARADES_SRC *= *$C/src$" $C/src/config.mk || { log "$T config.mk points at another tree"; exit 1; }
[ -x $B ] || { log "missing $B"; exit 1; }
for s in ctl-reach-buckets "the base before and after" "PER-PE WITH A SHARED SPARE LIST" agg-pp-local agg-pp-pad; do
  strings $B | grep -q "$s" || { log "$B lacks $s"; exit 1; }
done
ldd $B | grep -q charm-pads-perf/ || { log "$B does not link charm-pads-perf"; exit 1; }
grep -q 'apad#p' $S || { log "ctl_sweep.sh lacks the pad field"; exit 1; }
[ -x $PW ] && grep -q -- "-D" $PW || { log "missing $PW"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }
if [ $STUB = 0 ]; then
  TWIN=${TWIN:-$(cat $TWF 2>/dev/null)}
  if [ -n "${TWIN:-}" ] && [ "$TWIN" != "$SLURM_JOB_ID" ]; then
    st=$(squeue -h -j $TWIN -o %T 2>/dev/null)
    [ "$st" = PENDING ] || { log "twin $TWIN is ${st:-not queued}: exiting"; exit 0; }
    scancel $TWIN && log "twin $TWIN was pending: cancelled"
  fi
  [ ${#NL[@]} -ge $N ] || { log "need $N nodes, got ${#NL[@]}"; exit 1; }
fi

gate() { # output file, extra run args, then test.py's model and config arguments
  local f=$1 x=$2; shift 2
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free $x"
    python3 test.py --tier change --no-build --launcher srun --nodes 2 "$@" > $f 2>&1 )
  tail -4 $f; grep -E "FAIL|TIMEOUT" $f | head
  grep -q "Failed: *0/" $f && grep -q "Timed out: *0/" $f && grep -q "Passed: *[1-9]" $f; }
gate2() { # name, extra run args, then test.py's arguments: once more if the only failures are /work2 read errors
  local g=$1 x=$2; shift 2
  gate $OUT/gate_$g.txt "$x" "$@" && return 0
  local bad=$(grep -E "FAIL|TIMEOUT" $OUT/gate_$g.txt | awk '{print $NF}' | grep "test.out$")
  if [ -n "$bad" ] && [ -z "$(for f in $bad; do grep -L -E "Input/output error|Synch Protocol\.+2$" $f; done)" ]; then
    log "GATE $g: /work2 read errors only; rerunning"; gate $OUT/gate_${g}2.txt "$x" "$@"
  else return 1; fi; }
if [ $STUB = 0 ]; then
  PPC="agg_deadline_bucket_pp agg_ctl_measured_bucket_pp agg_deadline_bucket_pp_local1 agg_ctl_measured_bucket_pp_local1 agg_bucket_pp_local1"
  gate2 phold "" --model "Simple PHOLD" $PPC agg_inputbuf_bucket_wps || { log "GATE FAILED"; exit 1; }
  gate2 pad1 "--agg-pp-pad=1" --model "Simple PHOLD" $PPC || { log "GATE FAILED (pad 1)"; exit 1; }
  gate2 pad2 "--agg-pp-pad=2" --model "Simple PHOLD" $PPC || { log "GATE FAILED (pad 2)"; exit 1; }
  log "GATE DONE"
fi

export TREE=$T PPN=2 PEPP=23 CPT=24 LPC=16
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
cs() { # tag agg workload arms end bucket lps_per_pe cap
  ( export NODES=$N AGG=$2 WORKLOADS="$3" ARMS="$4" END=$5 BUCKETS=$6 LPS_PER_PE=$7 CAP=$8 \
      EXTRA_ARGS="$L" SRUN_ARGS="-w $NL16"
    RUNS=$OUT/n$N/$1 $S 1 $OUT/n$N/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$N $1 /" )
  rm -f $OUT/n$N/$1/ctl_sweep/logs/*.digest.csv $OUT/n$N/$1/ctl_sweep/gvt_*.out; }
csok() { [ $STUB = 1 ] || tail -n +2 $OUT/n$N/$1.csv 2>/dev/null | cut -d, -f11 | grep -qx ok; }
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
ord() { [ $(($2 % 2)) = 1 ] && echo "$1" || rev "$1"; }   # list rep: reversed in even reps
END=2048000
tag() { echo "$1" | sed 's/::/:l16:/; s/:/_/g'; }   # pp:512::p2 -> pp_512_l16_p2
pdcell() { # workload rep
  local wl=$1 rep=$2 cw aggs a
  case $wl in
    uni)   cw=steady:100:1000:1.0; aggs="wps:512 pp:512 pp:512::p1 pp:512::p2 pp:512:l1 pp:512:l1:p1 pp:512:l1:p2" ;;
    g4000) cw=gauss:100:1000:4000; aggs="pp:512 pp:512::p2 pp:512:l1 pp:512:l1:p1 pp:512:l1:p2" ;;
  esac
  for a in $(ord "$aggs" $rep); do cs ${wl}_$(tag $a)_r$rep $a $cw w:400 $END 8 128 150; done; }

# ---- warm-up: the new layout once, short; the job stops if it fails
{
  cs warm_l1p2 pp:512:l1:p2 steady:100:1000:1.0 w:400 256000 8 128 150
  csok warm_l1p2 || { log "WARM-UP FAILED"; exit 1; }
} > $OUT/stream_warm.log 2>&1 || { log "WARM-UP FAILED"; cat $OUT/stream_warm.log; exit 1; }
log "WARM-UP DONE"

# ---- part A: 16 nodes, 5 reps, timing
{
  for rep in 1 2 3 4 5; do
    for wl in $(ord "uni g4000" $rep); do pdcell $wl $rep; done
    log "N $N REP $rep DONE"
  done
} > $OUT/stream_n16.log 2>&1
grep -h -E ' (fail|stall) ' $OUT/stream_n16.log | head -30
log "PART A DONE"

# ---- part B: profiles (check runs), then reports on this node
{
  for a in wps:512 pp:512 pp:512:l1 pp:512:l1:p1 pp:512:l1:p2; do
    t=prof_$(tag $a); mkdir -p $OUT/perf/$t
    ( export BIN_WRAP=$PW PERF_DIR=$OUT/perf/$t PERF_DELAY_MS=3000; cs $t $a steady:100:1000:1.0 w:400 $END 8 128 150 )
  done
} > $OUT/stream_prof.log 2>&1
grep -h -E ' (fail|stall) ' $OUT/stream_prof.log | head
if [ $STUB = 0 ]; then
  for d in $OUT/perf/prof_*; do
    f=$(ls $d/perf.*.data 2>/dev/null | head -1); [ -n "$f" ] || { log "no perf data in $d"; continue; }
    perf report -i $f --stdio --no-children --sort symbol --percent-limit 0.3 > $d/report_symbol.txt 2>/dev/null
    perf report -i $f --stdio --no-children --sort dso > $d/report_dso.txt 2>/dev/null
    # instruction-level view of the htram send path, by the symbol names the report printed
    for fn in copyLocalToNodeBuf insertValue insert shipSharedWithLocalPP flushDue; do
      sym=$(grep -o "HTram::$fn([^)]*)" $d/report_symbol.txt | head -1)
      [ -n "$sym" ] && perf annotate -i $f --stdio "$sym" > $d/annotate_$fn.txt 2>/dev/null
    done
  done
fi
log "PART B DONE"
du -sh $OUT
log "PD269 DONE"
