#!/bin/bash -l
#SBATCH -J pl267
#SBATCH -t 01:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/pl267_%j.out
# Job PL16 (charades results/aggregation.md section 267; user decision
# 2026-11-09: try per-process flushing in PP). Charades only, 16 nodes, one
# stream, 5 reps, tree charades-ppl (charades branch pp-local on 85a2aad's
# code, htram branch pp-local), the paper launch, no diagnostics in any arm.
# F1's PHOLD settings (scale240.slurm / s64_262.slurm: end 2,048,000, bucket
# 8, 128 LPs per PE, 2 x 23 PEs per node) on three workloads:
#   uniform    WPs 512 (F1's setting), PP 512 (local 16, today's PP),
#              PP 512 local 4, PP 512 local 1
#   sigma 2,000 and sigma 4,000
#              PP 512 (F1's setting), PP 512 local 4, PP 512 local 1
# each at fixed W 400 and the controller (mb:0). "local N" is
# --agg-pp-local=N (ctl_sweep.sh AGG pp:512:lN): a PE copies its events into
# the process's shared buffer every N events instead of every 16, and a due
# flush sends the shared buffer with the flushing PE's events added.
# Workloads and htram settings in reverse order in even reps.
# Submit (twin guard): sbatch -p skx -N 16 -n 768 -x c455-081 pl267.slurm
#   then sbatch -p skx-dev -N 16 -n 768 -x c455-081 --export=ALL,TWIN=<skx id> pl267.slurm
#   then echo <skx-dev id> > $TWF
# The copy that starts first cancels the other if it is still pending; a copy
# that starts second exits.
# STUB=1 (login node, fake srun first in PATH, SLURM_JOB_ID and
# SLURM_JOB_NODELIST set): print every command, no gate.
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
STUB=${STUB:-0}
OUT=$W/charades-runs/pl267/j${SLURM_JOB_ID:-dry}; [ $STUB = 1 ] && OUT=$W/charades-runs/pl267/stub
mkdir -p $OUT
TWF=$W/charades-runs/pl267/pl267.twin
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
[ $STUB = 1 ] && export PATH=$W/charades-runs/f4b250/stubbin:$PATH
T=charades-ppl; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh; B=$C/models/phold/simple/phold
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
N=16; NL16=$(join ${NL[@]:0:16})
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}"
log "charades $(git -C $C log --oneline -1 | cut -c1-60); htram $(git -C $W/htram-ppl log --oneline -1 | cut -c1-60)"
[ "$(git -C $C rev-parse --abbrev-ref HEAD)" = pp-local ] || { log "$T not on branch pp-local"; exit 1; }
[ -z "$(git -C $C status --porcelain -uno)" ] || { log "$T has uncommitted changes"; exit 1; }
grep -q "^HTRAM_DIR *= *$W/htram-ppl$" $C/src/config.mk || { log "$T does not build htram-ppl"; exit 1; }
grep -q "^CHARADES_SRC *= *$W/$T/src$" $C/src/config.mk || { log "$T config.mk points at another tree"; exit 1; }
[ -x $B ] || { log "missing $B"; exit 1; }
for s in ctl-reach-buckets "the base before and after" "PER-PE WITH A SHARED SPARE LIST" agg-pp-local; do
  strings $B | grep -q "$s" || { log "$B lacks $s"; exit 1; }
done
ldd $B | grep -q charm-pads-perf/ || { log "$B does not link charm-pads-perf"; exit 1; }
grep -q 'alocal#l' $S || { log "ctl_sweep.sh lacks the local field"; exit 1; }
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

gate() { # output file, then test.py's model and config arguments
  local f=$1; shift
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
    python3 test.py --tier change --no-build --launcher srun --nodes 2 "$@" > $f 2>&1 )
  tail -4 $f; grep -E "FAIL|TIMEOUT" $f | head
  grep -q "Failed: *0/" $f && grep -q "Timed out: *0/" $f && grep -q "Passed: *[1-9]" $f; }
gate2() { # name, then test.py's arguments: once more if the only failures are /work2 read errors
  local g=$1; shift
  gate $OUT/gate_$g.txt "$@" && return 0
  local bad=$(grep -E "FAIL|TIMEOUT" $OUT/gate_$g.txt | awk '{print $NF}' | grep "test.out$")
  if [ -n "$bad" ] && [ -z "$(for f in $bad; do grep -L -E "Input/output error|Synch Protocol\.+2$" $f; done)" ]; then
    log "GATE $g: /work2 read errors only; rerunning"; gate $OUT/gate_${g}2.txt "$@"
  else return 1; fi; }
if [ $STUB = 0 ]; then
  gate2 phold --model "Simple PHOLD" agg_deadline_bucket_pp agg_inputbuf_bucket_wps agg_ctl_measured_bucket_pp \
    agg_deadline_bucket_pp_local1 agg_deadline_bucket_pp_local4 agg_ctl_measured_bucket_pp_local1 agg_bucket_pp_local1 \
    || { log "GATE FAILED"; exit 1; }
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
END=2048000; ARMS="mb:0 w:400"
plcell() { # workload rep
  local wl=$1 rep=$2 cw aggs a
  case $wl in
    uni)   cw=steady:100:1000:1.0;  aggs="wps:512 pp:512 pp:512:l4 pp:512:l1" ;;
    g2000) cw=gauss:100:1000:2000;  aggs="pp:512 pp:512:l4 pp:512:l1" ;;
    g4000) cw=gauss:100:1000:4000;  aggs="pp:512 pp:512:l4 pp:512:l1" ;;
  esac
  for a in $(ord "$aggs" $rep); do cs ${wl}_${a//:/}_r$rep $a $cw "$(ord "$ARMS" $rep)" $END 8 128 150; done; }

# ---- warm-up: the new setting once, short; the job stops if it fails
{
  cs warm_pp512l1 pp:512:l1 steady:100:1000:1.0 w:400 256000 8 128 150
  csok warm_pp512l1 || { log "WARM-UP FAILED"; exit 1; }
} > $OUT/stream_warm.log 2>&1 || { log "WARM-UP FAILED"; cat $OUT/stream_warm.log; exit 1; }
log "WARM-UP DONE"

# ---- 16 nodes, 5 reps
{
  for rep in 1 2 3 4 5; do
    for wl in $(ord "uni g2000 g4000" $rep); do plcell $wl $rep; done
    log "N $N REP $rep DONE"
  done
} > $OUT/stream_n16.log 2>&1
grep -h -E ' (fail|stall) ' $OUT/stream_n16.log | head -30
du -sh $OUT
log "PL267 DONE"
