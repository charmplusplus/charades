#!/bin/bash -l
#SBATCH -J vwin229
#SBATCH -t 00:40:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/vwin229_%j.out
# Job VW (charades RESULTS.md section 229): the steady cost of a VLSI window
# between one and two clock periods. Charades round 3 (charades-r3, the binaries
# of job VS2), b19 x N, one copy per node, 1 x 46, --fossil-lazy=1 --batch=32,
# buckets of 2,500 ps, 5,000 cycles: W 2,500 / 3,125 / 3,750 / 5,000, 3 reps,
# arm order reversed in rep 2.
#   4 nodes (nodes 0-3) and 8 nodes (nodes 4-11) side by side, then 16 nodes
# Submit: sbatch -p skx -N 16 -n 768 -x c455-081 vwin229.slurm
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/vwin229/j${SLURM_JOB_ID:-dry}; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T3=charades-r3; C3=$W/$T3
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}"
[ "$(git -C $C3 rev-parse --short=7 HEAD)" = ae0dbd3 ] || { log "$T3 not at ae0dbd3"; exit 1; }
strings $C3/models/vlsi/vlsi | grep -q "direct-execute" || { log "$C3 vlsi lacks round 3"; exit 1; }
ldd $C3/models/vlsi/vlsi | grep -q charm-pads-perf/ || { log "$C3 vlsi does not link charm-pads-perf"; exit 1; }
[ -e $W/I99T/i99t/b19/b19.bench ] || { log "missing b19 netlist"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }

# ---- gate: the change tier on 2 nodes, VLSI, lazy fossils (as job VS2)
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C3/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $C3/tests; export CHARADES_RUN_ARGS="+mempool_remote_free --fossil-lazy=1"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model VLSI \
    agg_ctl_measured_fast_bucket_pp bucket_window ctl_measured_bucket > $OUT/gate.txt 2>&1 )
tail -3 $OUT/gate.txt
grep -q "Failed: *0/" $OUT/gate.txt && grep -q "Timed out: *0/" $OUT/gate.txt || { log "GATE FAILED"; exit 1; }
log "GATE DONE"

export TREE=$T3 PPN=1 PEPP=46 CPT=48 CAP=300 VLSI_NETLISTS=$W/I99T/i99t
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1 --commit-digest=1 --copy-stats=1 --fossil-lazy=1 --batch=32"
V_END=12500000
cs() { # tag nodes nodelist arms [end]
  ( export NODES=$2 AGG=off WORKLOADS=vlsi:b19:1:1 ARMS="$4" END=${5:-$V_END} BUCKETS=2500 LPC=128 LPS_PER_PE=128 \
      EXTRA_ARGS="$L" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $C3/scripts/stampede3/ctl_sweep.sh 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" )
  rm -f $OUT/n$2/$1/ctl_sweep/logs/*.digest.csv $OUT/n$2/$1/ctl_sweep/gvt_*.out; }
ARMS="w:2500 w:3125 w:3750 w:5000"
REV="w:5000 w:3750 w:3125 w:2500"
stream() { # nodes nodelist
  local N=$1 nl=$2 rep
  cs warm $N $nl w:2500 1250000
  for rep in 1 2 3; do
    cs W_r$rep $N $nl "$([ $rep = 2 ] && echo "$REV" || echo "$ARMS")"
    log "N $N REP $rep DONE"
  done; }
stream 4 $(join ${NL[@]:0:4}) > $OUT/stream_n4.log 2>&1 &
stream 8 $(join ${NL[@]:4:8}) > $OUT/stream_n8.log 2>&1 &
wait
log "4/8 DONE"
stream 16 $(join ${NL[@]:0:16}) > $OUT/stream_n16.log 2>&1
log "16 DONE"
grep -h -E ' (fail|stall) ' $OUT/stream_n*.log | head -20
log "VWIN229 DONE"
