#!/bin/bash -l
#SBATCH -J l64b
#SBATCH -t 00:45:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/l64b_%j.out
# Job L64b (charades results/aggregation.md section 273; user decision
# 2026-11-10: rerun L64 (section 272: machine at half speed) with a control).
# Job L64's design (section 271). Charades only,
# 64 nodes, one 64-node stream (as P64), tree charades-pplpad (charades branch
# pp-pad), htram htram-pplpad (branch pp-pad), the paper launch. F1's PHOLD
# settings (end 2,048,000, bucket 8, 128 LPs per PE, 2 x 23 PEs), uniform only.
# Timing, 5 reps, settings and arms reversed in even reps, no diagnostics:
#   wps:512        WPs 512, F1's uniform setting
#   pp:512:l1:p1   PP 512 with --agg-pp-local=1 --agg-pp-pad=1 (section 270)
# each at the controller (mb:0) and W 400, and a control in every rep:
#   P64's own tree and binary (charades-r5, 85a2aad, its ctl_sweep.sh) running
#   WPs 512 at W 400, its commands identical to P64's apart from the nodes.
# Probe: before the gate, one control run; below PROBE_MIN M committed ev/s
# (900, 0.90 of P64's 998.9) the job stops (the machine is slow).
# Submit (64 nodes is above skx-dev's limit, so skx only, no twin):
#   sbatch -p skx -N 64 -n 3072 -x c455-081 l64b.slurm
# STUB=1 (login node, fake srun first in PATH, SLURM_JOB_ID and
# SLURM_JOB_NODELIST set): print every command, no gate.
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
STUB=${STUB:-0}
OUT=$W/charades-runs/l64/b_j${SLURM_JOB_ID:-dry}; [ $STUB = 1 ] && OUT=$W/charades-runs/l64/stub_b
mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
[ $STUB = 1 ] && export PATH=$W/charades-runs/f4b250/stubbin:$PATH
T=charades-pplpad; C=$W/$T; H=$W/htram-pplpad; S=$C/scripts/stampede3/ctl_sweep.sh; B=$C/models/phold/simple/phold
T5=charades-r5; C5=$W/$T5; S5=$C5/scripts/stampede3/ctl_sweep.sh; B5=$C5/models/phold/simple/phold; PROBE_MIN=${PROBE_MIN:-900}
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
N=64; NL64=$(join ${NL[@]:0:64})
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
[ "$(git -C $C5 rev-parse --short=7 HEAD)" = 85a2aad ] && [ -z "$(git -C $C5 status --porcelain -uno)" ] || { log "$T5 not at a clean 85a2aad"; exit 1; }
[ -x $B5 ] || { log "missing $B5"; exit 1; }
for s in ctl-reach-buckets "the base before and after" "PER-PE WITH A SHARED SPARE LIST"; do
  strings $B5 | grep -q "$s" || { log "$B5 lacks $s"; exit 1; }
done
ldd $B5 | grep -q charm-pads-perf/ || { log "$B5 does not link charm-pads-perf"; exit 1; }
grep -q "mb)   extra" $S5 || { log "$T5's ctl_sweep.sh lacks the mb arm"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }
[ $STUB = 1 ] || [ ${#NL[@]} -ge $N ] || { log "need $N nodes, got ${#NL[@]}"; exit 1; }

export TREE=$T PPN=2 PEPP=23 CPT=24 LPC=16
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
cs() { # tag agg workload arms end bucket lps_per_pe cap
  ( export NODES=$N AGG=$2 WORKLOADS="$3" ARMS="$4" END=$5 BUCKETS=$6 LPS_PER_PE=$7 CAP=$8 \
      EXTRA_ARGS="$L" SRUN_ARGS="-w $NL64"
    RUNS=$OUT/n$N/$1 $S 1 $OUT/n$N/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$N $1 /" )
  rm -f $OUT/n$N/$1/ctl_sweep/logs/*.digest.csv $OUT/n$N/$1/ctl_sweep/gvt_*.out; }
csok() { [ $STUB = 1 ] || tail -n +2 $OUT/n$N/$1.csv 2>/dev/null | cut -d, -f11 | grep -qx ok; }
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
ord() { [ $(($2 % 2)) = 1 ] && echo "$1" || rev "$1"; }   # list rep: reversed in even reps
cs5() { ( S=$S5; export TREE=$T5; cs "$@" ); }   # the same run on P64's tree and binary
rate() { [ $STUB = 1 ] && { echo 999; return; }; tail -n +2 $OUT/n$N/$1.csv 2>/dev/null | awk -F, '$11 == "ok" {printf "%.0f", $17 / 1e6}'; }
END=2048000

# ---- probe: P64's binary, WPs 512 at W 400; stop if the machine is slow
{ cs5 probe_r5 wps:512 steady:100:1000:1.0 w:400 $END 8 128 150; } > $OUT/stream_probe.log 2>&1
PR=$(rate probe_r5); log "PROBE: P64's binary WPs 512 W 400 at ${PR:-no result} M ev/s (P64 998.9; stop below $PROBE_MIN)"
[ -n "$PR" ] && [ "$PR" -ge $PROBE_MIN ] || { log "MACHINE SLOW OR PROBE FAILED: stopping before the gate"; exit 1; }

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
  log "GATE DONE"
fi

tag() { echo "$1" | sed 's/:/_/g'; }   # pp:512:l1:p1 -> pp_512_l1_p1

# ---- warm-up: local 1 with padded counters at 64 nodes once, short; the job stops if it fails
{
  cs warm_l1p1 pp:512:l1:p1 steady:100:1000:1.0 w:400 256000 8 128 150
  csok warm_l1p1 || { log "WARM-UP FAILED"; exit 1; }
} > $OUT/stream_warm.log 2>&1 || { log "WARM-UP FAILED"; cat $OUT/stream_warm.log; exit 1; }
log "WARM-UP DONE"

# ---- 64 nodes, 5 reps, timing
{
  for rep in 1 2 3 4 5; do
    for a in $(ord "r5 wps:512 pp:512:l1:p1" $rep); do
      if [ $a = r5 ]; then cs5 uni_r5_wps_512_r$rep wps:512 steady:100:1000:1.0 w:400 $END 8 128 150
      else cs uni_$(tag $a)_r$rep $a steady:100:1000:1.0 "$(ord 'mb:0 w:400' $rep)" $END 8 128 150; fi
    done
    log "N $N REP $rep DONE"
  done
} > $OUT/stream_n64.log 2>&1
grep -h -E ' (fail|stall) ' $OUT/stream_n64.log | head -30
du -sh $OUT
log "L64B DONE"
