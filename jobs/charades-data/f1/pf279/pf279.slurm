#!/bin/bash -l
#SBATCH -J pf279
#SBATCH -t 00:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/pf279_%j.out
# Job PF1 (charades results/aggregation.md section 279; user decision
# 2026-11-12: profile local 1 at 1 node, where section 278 found it at 0.76 of
# the table's setting). Charades only, 1 node, tree charades-r6 (main 9f7480a,
# htram pdes 978e065; gated in job 3711818), the paper launch, uniform PHOLD on
# F1's settings (bucket 8, 128 LPs per PE, 2 x 23 PEs), fixed W 300 (the better
# fixed W at 1 node for local 1 and WPs, section 278).
# Part A, timing (end 2,048,000, 5 reps, settings reversed in even reps, no
# diagnostics). AGG pp:512:l<N>:p<M> is --agg-pp-local=N --agg-pp-pad=M:
#   wps:512        WPs 512, F1's 1-node setting
#   pp:512         PP 512, local 16, packed counters (F1's 2-8-node setting)
#   pp:512::p1     PP 512, local 16, padded counters (padding alone)
#   pp:512:l4:p1   local 4, padded (a quarter of local 1's shared-buffer copies)
#   pp:512:l1:p1   local 1, padded (the new setting)
# Part B, profiles (check runs after part A, not timing; end 8,192,000): one
# run each of wps:512, pp:512, pp:512:l4:p1 and pp:512:l1:p1 with
# perfwrap_d.sh (perf record cycles:u at 1,999 Hz in task 0, one process of 23
# PEs, from 2.5 s after launch), reported in the job.
# Submit (twin guard): sbatch -p skx -N 1 -n 48 -x $X pf279.slurm
#   then sbatch -p skx-dev -N 1 -n 48 -x $X --export=ALL,TWIN=<skx id> pf279.slurm
#   then echo <skx-dev id> > $TWF
#   X = c455-081,c483-111,c494-023,c501-071,c503-084,c503-094,c503-102,c504-104
# STUB=1 (login node, fake srun first in PATH, SLURM_JOB_ID and
# SLURM_JOB_NODELIST set): print every command, no perf reports.
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
STUB=${STUB:-0}
OUT=$W/charades-runs/pf279/j${SLURM_JOB_ID:-dry}; [ $STUB = 1 ] && OUT=$W/charades-runs/pf279/stub
mkdir -p $OUT
TWF=$W/charades-runs/pf279/pf279.twin
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
[ $STUB = 1 ] && export PATH=$W/charades-runs/f4b250/stubbin:$PATH
T=charades-r6; C=$W/$T; H=$W/htram-r6; S=$C/scripts/stampede3/ctl_sweep.sh; B=$C/models/phold/simple/phold
PW=$W/charades-runs/perfwrap_d.sh
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}"
log "charades $(git -C $C log --oneline -1 | cut -c1-60); htram $(git -C $H log --oneline -1 | cut -c1-60)"
[ "$(git -C $C rev-parse --short=7 HEAD)" = 9f7480a ] && [ -z "$(git -C $C status --porcelain -uno)" ] || { log "$T not at a clean 9f7480a"; exit 1; }
[ "$(git -C $H rev-parse --short=7 HEAD)" = 978e065 ] && [ -z "$(git -C $H status --porcelain -uno)" ] || { log "htram-r6 not at a clean 978e065"; exit 1; }
grep -q "^HTRAM_DIR *= *$H$" $C/src/config.mk || { log "$T does not build $H"; exit 1; }
grep -q "^CHARADES_SRC *= *$C/src$" $C/src/config.mk || { log "$T config.mk points at another tree"; exit 1; }
[ -x $B ] || { log "missing $B"; exit 1; }
for s in ctl-reach-buckets "the base before and after" "PER-PE WITH A SHARED SPARE LIST" agg-pp-local agg-pp-pad; do
  strings $B | grep -q "$s" || { log "$B lacks $s"; exit 1; }
done
ldd $B | grep -q charm-pads-perf/ || { log "$B does not link charm-pads-perf"; exit 1; }
grep -q 'apad#p' $S || { log "ctl_sweep.sh lacks the pad field"; exit 1; }
[ -x $PW ] && command -v perf >/dev/null || { log "missing $PW or perf"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }
if [ $STUB = 0 ]; then
  TWIN=${TWIN:-$(cat $TWF 2>/dev/null)}
  if [ -n "${TWIN:-}" ] && [ "$TWIN" != "$SLURM_JOB_ID" ]; then
    st=$(squeue -h -j $TWIN -o %T 2>/dev/null)
    [ "$st" = PENDING ] || { log "twin $TWIN is ${st:-not queued}: exiting"; exit 0; }
    scancel $TWIN && log "twin $TWIN was pending: cancelled"
  fi
fi

export TREE=$T PPN=2 PEPP=23 CPT=24 LPC=16
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
WL=steady:100:1000:1.0; END=2048000; NL1=${NL[0]}
cs() { # tag, agg, arms, end
  ( export NODES=1 AGG=$2 WORKLOADS=$WL ARMS="$3" END=$4 BUCKETS=8 LPS_PER_PE=128 CAP=150 EXTRA_ARGS="$L" SRUN_ARGS="-w $NL1"
    RUNS=$OUT/n1/$1 $S 1 $OUT/n1/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n1 $1 /" )
  rm -f $OUT/n1/$1/ctl_sweep/logs/*.digest.csv $OUT/n1/$1/ctl_sweep/gvt_*.out; }
csok() { [ $STUB = 1 ] || tail -n +2 $OUT/n1/$1.csv 2>/dev/null | cut -d, -f11 | grep -qx ok; }
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
ord() { [ $(($2 % 2)) = 1 ] && echo "$1" || rev "$1"; }   # list, rep: reversed in even reps
tag() { echo "$1" | sed 's/::/:l16:/; s/:/_/g'; }        # pp:512::p1 -> pp_512_l16_p1
SETS="wps:512 pp:512 pp:512::p1 pp:512:l4:p1 pp:512:l1:p1"

# ---- warm-up: local 1 once, short; the job stops if it fails
{ cs warm_l1p1 pp:512:l1:p1 w:300 256000; csok warm_l1p1 || { log "WARM-UP FAILED"; exit 1; }; } > $OUT/stream_warm.log 2>&1 \
  || { log "WARM-UP FAILED"; cat $OUT/stream_warm.log; exit 1; }
log "WARM-UP DONE"

# ---- part A: timing, 5 reps
{
  for rep in 1 2 3 4 5; do
    for a in $(ord "$SETS" $rep); do cs uni_$(tag $a)_r$rep $a w:300 $END; done
    log "REP $rep DONE"
  done
} > $OUT/stream_a.log 2>&1
grep -h -E ' (fail|stall) ' $OUT/stream_a.log | head -20
log "PART A DONE"

# ---- part B: profiles (check runs), then reports on this node
{
  for a in wps:512 pp:512 pp:512:l4:p1 pp:512:l1:p1; do
    t=prof_$(tag $a); mkdir -p $OUT/perf/$t
    ( export BIN_WRAP=$PW PERF_DIR=$OUT/perf/$t PERF_DELAY_MS=2500; cs $t $a w:300 8192000 )
  done
} > $OUT/stream_prof.log 2>&1
grep -h -E ' (fail|stall) ' $OUT/stream_prof.log | head
if [ $STUB = 0 ]; then
  for d in $OUT/perf/prof_*; do
    f=$(ls $d/perf.*.data 2>/dev/null | head -1); [ -n "$f" ] || { log "no perf data in $d"; continue; }
    perf report -i $f --stdio --no-children -n --sort symbol --percent-limit 0.2 > $d/report_symbol.txt 2>/dev/null
    perf report -i $f --stdio --no-children -n --sort dso > $d/report_dso.txt 2>/dev/null
    # instruction-level view of the htram send path, by the symbol names the report printed
    for fn in copyLocalToNodeBuf insertValue insert shipSharedWithLocalPP shipSharedPP flushDue flushOrder; do
      sym=$(grep -o "HTram::$fn([^)]*)" $d/report_symbol.txt | head -1)
      [ -n "$sym" ] && perf annotate -i $f --stdio "$sym" > $d/annotate_$fn.txt 2>/dev/null
    done
  done
fi
log "PART B DONE"
du -sh $OUT
log "PF279 DONE"
