#!/bin/bash -l
#SBATCH -J rahead233
#SBATCH -t 00:50:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/rahead233_%j.out
# Job RA (charades RESULTS.md section 233): where Charades' cost of running
# ahead goes on VLSI. VS2's binaries (charades-r3, ae0dbd3, round 3), b19 x N,
# one copy per node, 1 x 46, buckets of 2,500 ps, 5,000 cycles, direct sends.
# W 2,500 / 3,750 / 5,000, each with four settings:
#   D  VS2's (--fossil-lazy=1 --batch=32)   G  D + --gvt-wave-events=0
#   E  --fossil-lazy=0 --batch=32           GE E + --gvt-wave-events=0
# and B8 (D with --batch=8) at W 5,000 only. --pe-stats=1 on every run; one rep
# traced (--gvt-trace=5 --comm-stats=1). Arm order reversed in rep 2.
#   4 nodes: reps 1-3 and the traced rep side by side on four node sets;
#   then 16 nodes: reps 1-3, then the traced rep.
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 rahead233.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/rahead233/j${SLURM_JOB_ID:-dry}; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T3=charades-r3; C3=$W/$T3; S=$C3/scripts/stampede3/ctl_sweep.sh
B=$C3/models/vlsi/vlsi
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}"
[ "$(git -C $C3 rev-parse --short=7 HEAD)" = ae0dbd3 ] || { log "$T3 not at ae0dbd3"; exit 1; }
strings $B | grep -q "direct-execute" || { log "$B lacks round 3"; exit 1; }
for f in gvt-wave-events fossil-lazy pe-stats comm-stats exec_parts_ gvt_rec_; do
  strings $B | grep -q -- "$f" || { log "$B lacks $f"; exit 1; }
done
ldd $B | grep -q charm-pads-perf/ || { log "$B does not link charm-pads-perf"; exit 1; }
[ -e $W/I99T/i99t/b19/b19.bench ] || { log "missing b19 netlist"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }
[ ${#NL[@]} -ge 16 ] || { log "need 16 nodes, got ${#NL[@]}"; exit 1; }

# ---- gate: the change tier on 2 nodes, VLSI, lazy fossils (as jobs VS2 and VW)
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C3/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $C3/tests; export CHARADES_RUN_ARGS="+mempool_remote_free --fossil-lazy=1"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model VLSI \
    agg_ctl_measured_fast_bucket_pp bucket_window ctl_measured_bucket > $OUT/gate.txt 2>&1 )
tail -3 $OUT/gate.txt
grep -q "Failed: *0/" $OUT/gate.txt && grep -q "Timed out: *0/" $OUT/gate.txt || { log "GATE FAILED"; exit 1; }
log "GATE DONE"

export TREE=$T3 PPN=1 PEPP=46 CPT=48 CAP=300 VLSI_NETLISTS=$W/I99T/i99t
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1 --commit-digest=1 --copy-stats=1 --pe-stats=1"
TR="--gvt-trace=5 --comm-stats=1"
V_END=12500000
opt() { case $1 in
  D)  echo "--fossil-lazy=1 --batch=32" ;;
  G)  echo "--fossil-lazy=1 --batch=32 --gvt-wave-events=0" ;;
  E)  echo "--fossil-lazy=0 --batch=32" ;;
  GE) echo "--fossil-lazy=0 --batch=32 --gvt-wave-events=0" ;;
  B8) echo "--fossil-lazy=1 --batch=8" ;;
esac; }
# not named ARMS: that is ctl_sweep.sh's variable, and bash does not export
# arrays, so ctl_sweep ran its default arms (first submission, 3685764)
RUN_ARMS=(D:2500 G:2500 E:2500 GE:2500 D:3750 G:3750 E:3750 GE:3750 D:5000 G:5000 E:5000 GE:5000 B8:5000)

# one run per ctl_sweep call, so that each run's per-PE files (written to the
# working directory) land in its own directory
cs() { # rep nodes nodelist setting W traced [end]
  local rep=$1 N=$2 nl=$3 s=$4 w=$5 tr=$6 end=${7:-$V_END}
  local d=$OUT/n$N/$rep/${s}_w$w; mkdir -p $OUT/n$N/$rep
  ( export NODES=$N AGG=off WORKLOADS=vlsi:b19:1:1 ARMS="w:$w" END=$end BUCKETS=2500 LPC=128 LPS_PER_PE=128 \
      EXTRA_ARGS="$L $(opt $s)$([ $tr = 1 ] && echo " $TR")" SRUN_ARGS="-w $nl"
    RUNS=$d $S 1 $d.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$N $rep $s /" )
  # exactly one run, at the W asked for
  [ "$(tail -n +2 $d.csv | cut -d, -f10 | tr '\n' ' ')" = "w:$w " ] || { log "WRONG ARMS in $d.csv"; return 1; }
  ( cd $d/ctl_sweep || exit 0
    rm -f logs/*.digest.csv gvt_*.out
    if [ $N -gt 4 ]; then  # keep gvt_rec for node 2 (copy 2) and PE 0 only
      for f in gvt_rec_*.csv; do
        [ -e "$f" ] || continue
        p=${f#gvt_rec_}; p=${p%.csv}
        [ $p -eq 0 ] || [ $((p / 46)) -eq 2 ] || rm -f $f
      done
    fi
    shopt -s nullglob
    z=(gvt_rec_*.csv gvt_ranks_*.csv gvt_waves_*.csv gvt_pe_*.csv recv_parts_*.csv)
    [ ${#z[@]} -gt 0 ] && gzip -q "${z[@]}"
    true ); }
stream() { # nodes nodelist rep traced
  local N=$1 nl=$2 rep=$3 tr=$4 a list=("${RUN_ARMS[@]}")
  if [ $rep = r2 ]; then list=(); for ((i = ${#RUN_ARMS[@]} - 1; i >= 0; i--)); do list+=(${RUN_ARMS[i]}); done; fi
  for a in "${list[@]}"; do cs $rep $N $nl ${a%%:*} ${a##*:} $tr || return 1; done
  log "N $N $rep DONE"; }

# ---- 4 nodes: four node sets side by side, each with its own warm-up run
for k in 0 1 2 3; do
  nl=$(join ${NL[@]:$((4 * k)):4}); rep=$([ $k = 3 ] && echo t || echo r$((k + 1))); tr=$([ $k = 3 ] && echo 1 || echo 0)
  ( cs warm$k 4 $nl D 2500 0 1250000 && stream 4 $nl $rep $tr ) > $OUT/stream_n4_$rep.log 2>&1 &
done
wait
log "4 DONE"
cat $OUT/stream_n4_*.log | grep -E " (fail|stall) " | head -20

# ---- 16 nodes
N16=$(join ${NL[@]:0:16})
( cs warm 16 $N16 D 2500 0 1250000 || exit 1
  for rep in r1 r2 r3; do stream 16 $N16 $rep 0 || exit 1; done
  stream 16 $N16 t 1 ) > $OUT/stream_n16.log 2>&1
log "16 DONE"
grep -h -E " (fail|stall) " $OUT/stream_n*.log | head -20
du -sh $OUT
log "RAHEAD233 DONE"
