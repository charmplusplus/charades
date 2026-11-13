#!/bin/bash -l
#SBATCH -J ul277
#SBATCH -t 00:45:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/ul277_%j.out
# Job UL (charades results/aggregation.md section 277, results in 278; user
# decision 2026-11-12: padded local 1 becomes a candidate htram setting for
# uniform in the tables, which take Charades' controller at the better setting
# per node count). Uniform PHOLD on F1's settings (end 2,048,000, bucket 8,
# margin 8, 128 LPs per PE, 2 x 23 PEs per node, the paper launch), Charades
# only, no diagnostics in a run:
#   new        charades-r6 (main 9f7480a, htram pdes 978e065): PP 512 with
#              --agg-pp-local=1 --agg-pp-pad=1, the controller (mb:0) and F1's
#              fixed W (W 300 / 400; at 64 nodes P64's W 400 / 500)
#   reference  charades-r5 (85a2aad, F1's and P64's binary): the table's setting
#              at that node count (1: WPs 512; 2, 4, 8: PP 512; 16, 32, 64:
#              WPs 512), the controller only; its commands are F1's apart from
#              the nodes and the output paths
# Reps: 3 at 1-16 nodes, 5 at 32 and 64 (as F1 and P64); in even reps the two
# settings and the new setting's arms run in reverse order.
# First argument:
#   small  16 nodes: 8, 4, 2 and 1 nodes side by side on nodes 1-15 (node 0,
#          the batch host, idle), then 16 nodes on all 16
#   n32    32 nodes
#   n64    64 nodes
# Probe, before the gate: the reference binary, WPs 512 at W 400 at the job's
# largest node count; below 0.90 of F1's median there (16: 383.3, 32: 639.5;
# 64: P64's 998.9) the job stops (the machine is slow).
# Network record between runs only (section 275; sysfs counters, no fabric
# manager queries, which fail on compute nodes, section 276): at the start,
# after the probe, then after the side-by-side streams and the 16-node stream
# (small) or after each rep (n32, n64). Files in $OUT/net.
# Submit (X = c455-081,c483-111,c494-023,c501-071,c503-084,c503-094,c503-102,c504-104):
#   small  sbatch -p skx -N 16 -n 768 -x $X ul277.slurm small
#          then sbatch -p skx-dev -N 16 -n 768 -x $X --export=ALL,TWIN=<skx id> ul277.slurm small
#          then echo <skx-dev id> > $TWF
#   n32    sbatch -p skx -N 32 -n 1536 -x $X ul277.slurm n32
#   n64    sbatch -p skx -N 64 -n 3072 -x $X ul277.slurm n64
# STUB=1 (login node, fake srun first in PATH, SLURM_JOB_ID and
# SLURM_JOB_NODELIST set): print every command, no gate.
set -u
G=${1:-}
case $G in
  small) NMAX=16; PROBE_REF=383.3 ;;
  n32)   NMAX=32; PROBE_REF=639.5 ;;
  n64)   NMAX=64; PROBE_REF=998.9 ;;
  *) echo "first argument: small, n32 or n64"; exit 1 ;;
esac
W=/work2/09863/rrao/stampede3; export WORK=$W
STUB=${STUB:-0}
OUT=$W/charades-runs/ul277/${G}_j${SLURM_JOB_ID:-dry}; [ $STUB = 1 ] && OUT=$W/charades-runs/ul277/stub_$G
mkdir -p $OUT
TWF=$W/charades-runs/ul277/ul277_small.twin
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
[ $STUB = 1 ] && export PATH=$W/charades-runs/f4b250/stubbin:$PATH
T=charades-r6; C=$W/$T; H=$W/htram-r6; S=$C/scripts/stampede3/ctl_sweep.sh; B=$C/models/phold/simple/phold
T5=charades-r5; C5=$W/$T5; S5=$C5/scripts/stampede3/ctl_sweep.sh; B5=$C5/models/phold/simple/phold
PROBE_MIN=$(awk -v r=$PROBE_REF 'BEGIN {printf "%d", 0.9 * r}')
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry} group $G; nodes ${NL[*]:-none}"
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
[ "$(git -C $C5 rev-parse --short=7 HEAD)" = 85a2aad ] && [ -z "$(git -C $C5 status --porcelain -uno)" ] || { log "$T5 not at a clean 85a2aad"; exit 1; }
[ -x $B5 ] || { log "missing $B5"; exit 1; }
for s in ctl-reach-buckets "the base before and after" "PER-PE WITH A SHARED SPARE LIST"; do
  strings $B5 | grep -q "$s" || { log "$B5 lacks $s"; exit 1; }
done
ldd $B5 | grep -q charm-pads-perf/ || { log "$B5 does not link charm-pads-perf"; exit 1; }
grep -q "mb)   extra" $S5 || { log "$T5's ctl_sweep.sh lacks the mb arm"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }
if [ $STUB = 0 ]; then
  if [ $G = small ]; then
    # TWIN: the same job queued in the other partition. The copy that starts
    # first runs and cancels the other; one that starts second exits.
    TWIN=${TWIN:-$(cat $TWF 2>/dev/null)}
    if [ -n "${TWIN:-}" ] && [ "$TWIN" != "$SLURM_JOB_ID" ]; then
      st=$(squeue -h -j $TWIN -o %T 2>/dev/null)
      [ "$st" = PENDING ] || { log "twin $TWIN is ${st:-not queued}: exiting"; exit 0; }
      scancel $TWIN && log "twin $TWIN was pending: cancelled"
    fi
  fi
  [ ${#NL[@]} -ge $NMAX ] || { log "need $NMAX nodes, got ${#NL[@]}"; exit 1; }
fi

export PPN=2 PEPP=23 CPT=24 LPC=16
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
WL=steady:100:1000:1.0; END=2048000; NEW=pp:512:l1:p1
cs() { # tree (r6 or r5), tag, nodes, node list, agg, arms, end
  local s=$S tree=$T
  [ $1 = r5 ] && { s=$S5; tree=$T5; }
  ( export TREE=$tree NODES=$3 AGG=$5 WORKLOADS=$WL ARMS="$6" END=$7 BUCKETS=8 LPS_PER_PE=128 CAP=150 \
      EXTRA_ARGS="$L" SRUN_ARGS="-w $4"
    RUNS=$OUT/n$3/$2 $s 1 $OUT/n$3/$2.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$3 $2 /" )
  rm -f $OUT/n$3/$2/ctl_sweep/logs/*.digest.csv $OUT/n$3/$2/ctl_sweep/gvt_*.out; }
csok() { [ $STUB = 1 ] || tail -n +2 $OUT/n$1/$2.csv 2>/dev/null | cut -d, -f11 | grep -qx ok; }   # nodes, tag
rate() { [ $STUB = 1 ] && { echo 999; return; }; tail -n +2 $OUT/n$1/$2.csv 2>/dev/null | awk -F, '$11 == "ok" {printf "%.0f", $17 / 1e6}'; }
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
ord() { [ $(($2 % 2)) = 1 ] && echo "$1" || rev "$1"; }   # list, rep: reversed in even reps
tag() { echo "$1" | sed 's/:/_/g'; }                      # pp:512:l1:p1 -> pp_512_l1_p1
refagg() { case $1 in 1) echo wps:512 ;; 2|4|8) echo pp:512 ;; *) echo wps:512 ;; esac; }   # the table's setting
grid() { [ $1 = 64 ] && echo "mb:0 w:400 w:500" || echo "mb:0 w:300 w:400"; }

# ---- network record (section 275), between runs only; sysfs counters
NETD=$OUT/net; mkdir -p $NETD
NETSCRIPT='PATH=$PATH:/usr/sbin; h=$(hostname -s); D=/sys/class/infiniband/hfi1_0
echo "$h time $(date +%s.%N)"
grep -H . $D/ports/1/counters/* $D/hw_counters/* $D/ports/1/hw_counters/* 2>/dev/null | grep -v ":0$" | sed "s|^$D/|$h |"'
seg() { # label: every node's nonzero network-card counters, one task per node
  local f=$NETD/$1.nodes got
  timeout -s TERM 120 srun --kill-on-bad-exit=1 -N ${#NL[@]} -n ${#NL[@]} --ntasks-per-node=1 --cpu-bind=none -J netsnap_$1 \
    bash -c "$NETSCRIPT" > $f 2>&1 || log "netsnap $1: srun failed or timed out"
  [ $STUB = 1 ] && bash -c "$NETSCRIPT" > $f 2>&1   # stub: the login node stands in for the nodes
  got=$(awk '$2 == "time"' $f | wc -l); [ $STUB = 1 ] || [ $got = ${#NL[@]} ] || log "netsnap $1: $got of ${#NL[@]} nodes reported"; }

stream() { # nodes, node list, reps, record after each rep (0/1)
  local n=$1 nl=$2 reps=$3 rec=$4 rep a ra
  ra=$(refagg $n)
  cs r6 warm_l1p1 $n $nl $NEW w:400 256000
  csok $n warm_l1p1 || { log "WARM-UP FAILED at $n nodes"; return 1; }
  for rep in $(seq $reps); do
    for a in $(ord "ref new" $rep); do
      if [ $a = ref ]; then cs r5 uni_ref_$(tag $ra)_r$rep $n $nl $ra mb:0 $END
      else cs r6 uni_$(tag $NEW)_r$rep $n $nl $NEW "$(ord "$(grid $n)" $rep)" $END; fi
    done
    log "N $n REP $rep DONE"
    [ $rec = 1 ] && seg n${n}_rep$rep
  done
  return 0; }

seg start
# ---- probe: the reference binary, WPs 512 at W 400 at the largest node count; stop if the machine is slow
{ cs r5 probe_r5 $NMAX $(join ${NL[@]:0:$NMAX}) wps:512 w:400 $END; } > $OUT/stream_probe.log 2>&1
seg probe
PR=$(rate $NMAX probe_r5); log "PROBE: reference WPs 512 W 400 at $NMAX nodes, ${PR:-no result} M ev/s (F1/P64 $PROBE_REF; stop below $PROBE_MIN)"
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

if [ $G = small ]; then
  stream 8 $(join ${NL[@]:1:8}) 3 0 > $OUT/stream_n8.log 2>&1 &
  stream 4 $(join ${NL[@]:9:4}) 3 0 > $OUT/stream_n4.log 2>&1 &
  stream 2 $(join ${NL[@]:13:2}) 3 0 > $OUT/stream_n2.log 2>&1 &
  stream 1 ${NL[15]} 3 0 > $OUT/stream_n1.log 2>&1 &
  wait
  log "1/2/4/8 DONE"; seg sides
  stream 16 $(join ${NL[@]:0:16}) 3 0 > $OUT/stream_n16.log 2>&1 || log "16-node stream stopped"
  log "16 DONE"; seg n16
else
  stream $NMAX $(join ${NL[@]:0:$NMAX}) 5 1 > $OUT/stream_n$NMAX.log 2>&1 || { log "$NMAX-node stream stopped"; cat $OUT/stream_n$NMAX.log | tail -5; }
  log "$NMAX DONE"
fi
grep -h -E ' (fail|stall) |FAILED' $OUT/stream_n*.log | head -30
du -sh $OUT
log "UL277 $G DONE"
