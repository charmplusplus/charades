#!/bin/bash -l
#SBATCH -J vcommit235
#SBATCH -t 00:45:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/vcommit235_%j.out
# Job VC (charades RESULTS.md section 235): VLSI's commit setting and its
# controller row. Tree charades-r4 (charades 609212b: round 3 plus
# --fossil-rounds / --fossil-finish, defaults unchanged), b19 x N, one copy per
# node, 1 x 46, 5,000 cycles, direct sends, --pe-stats=1. Commit settings:
#   L   lazy, as VS2 (--fossil-lazy=1, 4 rounds)    E   eager (--fossil-lazy=0)
#   R1  lazy, --fossil-rounds=1                     F   lazy, --fossil-finish=1
# Arms: L at W 2,500 and 5,000; E, R1, F at W 5,000 (buckets of 2,500 ps); the
# frozen controller (mb:0) with buckets of 2,500 under L (VS2's row) and with
# buckets of 5,000 under E, R1, F. 3 reps, arm order reversed in rep 2.
#   1, 2, 4 and 8 nodes side by side (nodes 0 / 1-2 / 3-6 / 7-14), then 16.
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 vcommit235.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/vcommit235/j${SLURM_JOB_ID:-dry}; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T4=charades-r4; C4=$W/$T4; S=$C4/scripts/stampede3/ctl_sweep.sh
B=$C4/models/vlsi/vlsi
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}"
[ "$(git -C $C4 rev-parse --short=7 HEAD)" = 609212b ] || { log "$T4 not at 609212b"; exit 1; }
# not fossil-rounds: gcc builds that 13-character string from immediates, so
# strings cannot see it; an unknown flag aborts, so the gate checks it
for f in fossil-finish "PER-PE WITH A SHARED SPARE LIST" direct-execute pe-stats; do
  strings $B | grep -q -- "$f" || { log "$B lacks $f"; exit 1; }
done
ldd $B | grep -q charm-pads-perf/ || { log "$B does not link charm-pads-perf"; exit 1; }
grep -q "mb)   extra" $S || { log "ctl_sweep.sh lacks the mb arm"; exit 1; }
[ -e $W/I99T/i99t/b19/b19.bench ] || { log "missing b19 netlist"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }
[ ${#NL[@]} -ge 16 ] || { log "need 16 nodes, got ${#NL[@]}"; exit 1; }

# ---- gate: the change tier on 2 nodes, VLSI, lazy commits (as VS2 and RA),
# plus the three lazy-commit configs
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C4/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $C4/tests; export CHARADES_RUN_ARGS="+mempool_remote_free --fossil-lazy=1"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model VLSI \
    agg_ctl_measured_fast_bucket_pp bucket_window ctl_measured_bucket > $OUT/gate.txt 2>&1
  export CHARADES_RUN_ARGS="+mempool_remote_free"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model VLSI \
    bucket_window_lazy bucket_window_lazy_rounds1 bucket_window_lazy_finish > $OUT/gate2.txt 2>&1 )
tail -3 $OUT/gate.txt $OUT/gate2.txt
for g in gate gate2; do
  grep -q "Failed: *0/" $OUT/$g.txt && grep -q "Timed out: *0/" $OUT/$g.txt || { log "GATE FAILED ($g)"; exit 1; }
done
log "GATE DONE"

export TREE=$T4 PPN=1 PEPP=46 CPT=48 CAP=300 VLSI_NETLISTS=$W/I99T/i99t
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1 --commit-digest=1 --copy-stats=1 --pe-stats=1 --batch=32"
V_END=12500000
opt() { case $1 in
  L)  echo "--fossil-lazy=1" ;;
  E)  echo "--fossil-lazy=0" ;;
  R1) echo "--fossil-lazy=1 --fossil-rounds=1" ;;
  F)  echo "--fossil-lazy=1 --fossil-finish=1" ;;
esac; }
# setting:ctl_sweep arm:bucket. Not named ARMS: that is ctl_sweep.sh's
# variable, and bash does not export arrays (section 233's first submission)
RUN_ARMS=(L:w2500:2500 L:w5000:2500 E:w5000:2500 R1:w5000:2500 F:w5000:2500
          L:mb0:2500 E:mb0:5000 R1:mb0:5000 F:mb0:5000)

# one run per ctl_sweep call, so that each run's pe_stats.csv lands in its own directory
cs() { # rep nodes nodelist setting arm bucket [end]
  local rep=$1 N=$2 nl=$3 s=$4 a=$5 bk=$6 end=${7:-$V_END}
  local arm=$(echo $a | sed -E 's/^(w|mb)([0-9]+)$/\1:\2/')
  local d=$OUT/n$N/$rep/${s}_${a}_b$bk; mkdir -p $OUT/n$N/$rep
  ( export NODES=$N AGG=off WORKLOADS=vlsi:b19:1:1 ARMS="$arm" END=$end BUCKETS=$bk LPC=128 LPS_PER_PE=128 \
      EXTRA_ARGS="$L $(opt $s)" SRUN_ARGS="-w $nl"
    RUNS=$d $S 1 $d.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$N $rep $s /" )
  # exactly one run, of the arm asked for
  [ "$(tail -n +2 $d.csv | cut -d, -f10 | tr '\n' ' ')" = "$arm " ] || { log "WRONG ARMS in $d.csv"; return 1; }
  rm -f $d/ctl_sweep/logs/*.digest.csv $d/ctl_sweep/gvt_*.out; }
stream() { # nodes nodelist rep
  local N=$1 nl=$2 rep=$3 x list=("${RUN_ARMS[@]}")
  if [ $rep = r2 ]; then list=(); for ((i = ${#RUN_ARMS[@]} - 1; i >= 0; i--)); do list+=(${RUN_ARMS[i]}); done; fi
  for x in "${list[@]}"; do IFS=: read -r s a bk <<< "$x"; cs $rep $N $nl $s $a $bk || return 1; done
  log "N $N $rep DONE"; }
series() { # nodes nodelist
  local N=$1 nl=$2 rep
  cs warm $N $nl L w2500 2500 1250000 || return 1
  for rep in r1 r2 r3; do stream $N $nl $rep || return 1; done; }

# ---- 1, 2, 4 and 8 nodes side by side
series 1 ${NL[0]} > $OUT/stream_n1.log 2>&1 &
series 2 $(join ${NL[@]:1:2}) > $OUT/stream_n2.log 2>&1 &
series 4 $(join ${NL[@]:3:4}) > $OUT/stream_n4.log 2>&1 &
series 8 $(join ${NL[@]:7:8}) > $OUT/stream_n8.log 2>&1 &
wait
log "1/2/4/8 DONE"
grep -h -E " (fail|stall) |WRONG" $OUT/stream_n*.log | head -20

# ---- 16 nodes
series 16 $(join ${NL[@]:0:16}) > $OUT/stream_n16.log 2>&1
log "16 DONE"
grep -h -E " (fail|stall) |WRONG" $OUT/stream_n*.log | head -20
du -sh $OUT
log "VCOMMIT235 DONE"
