#!/bin/bash -l
#SBATCH -J alloc58
#SBATCH -t 00:40:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/alloc58_%j.out
# Job A16 (charades RESULTS.md section 158): does PP's start-up ramp follow
# glibc's handling of htram PP's ~1.2 MB per-send shared-buffer allocations?
# sigma 2,000, W 400, end time 2,048,000, untraced; the hfi1 sampler (now with
# TLB-shootdown, function-call and rescheduling interrupts) on every node.
#   3 reps, interleaved: PP 512; WPs 512; PP 512 with a fixed 32 MB mmap
#   threshold (GLIBC_TUNABLES); PP 512 with no trimming (trim threshold 1 GB,
#   top pad 64 MB, which also pins the mmap threshold at 128 KB)
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 alloc58.slurm
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/alloc58/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-lprb; S=$W/$T/scripts/stampede3/ctl_sweep.sh
NL=($(scontrol show hostnames $SLURM_JOB_NODELIST))
join() { local IFS=,; echo "$*"; }
N16=$(join ${NL[@]:0:16})
log "job $SLURM_JOB_ID; nodes ${NL[*]}"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-40); reconverse $(git -C $W/charm-pads-exp/contrib/reconverse log --oneline -1 | cut -c1-40)"
strings $W/$T/models/phold/simple/phold | grep -q "Start delay: the clock starts" || { log "binary lacks --start-delay-ms"; exit 1; }
gate() { # output file
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/$T/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $W/$T/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
    python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" \
      agg_deadline_bucket_pp_diag agg_deadline_bucket_pp > $1 2>&1 )
  tail -4 $1; grep -E "FAIL|TIMEOUT" $1 | head
  grep -q "Failed: *0/" $1 && grep -q "Timed out: *0/" $1; }
if ! gate $OUT/gate.txt; then
  bad=$(grep -E "FAIL|TIMEOUT" $OUT/gate.txt | awk '{print $NF}' | grep "test.out$")
  if [ -n "$bad" ] && [ -z "$(for f in $bad; do grep -L "Input/output error" $f; done)" ]; then
    log "GATE: /work2 read errors only; rerunning"
    gate $OUT/gate2.txt || { log "GATE FAILED"; exit 1; }
  else log "GATE FAILED"; exit 1; fi
fi
log "GATE DONE"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=150 PPN=2 PEPP=23 CPT=24
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
END=2048000 G2000=gauss:100:1000:2000 G4000=gauss:100:1000:4000
cs() { # tag nodes nodelist agg workload arms end [extra Charades flags]
  ( export NODES=$2 AGG=$4 END=$7 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="$L ${8:-}" SRUN_ARGS="-w $3"
    [ -n "${GT:-}" ] && export GLIBC_TUNABLES=$GT
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" ); }
smp_start() {
  srun --overlap -N 16 --ntasks-per-node=1 -c 1 --cpu-bind=none -w $N16 -J hfi \
    python3 $W/$T/scripts/stampede3/hfi_sampler.py $OUT/hfi 0.1 > $OUT/hfi.log 2>&1 &
  SMP=$!; sleep 3
  kill -0 $SMP 2>/dev/null && log "sampler up (pid $SMP)" || log "SAMPLER FAILED: $(head -3 $OUT/hfi.log)"; }
smp_start
MMAP=glibc.malloc.mmap_threshold=33554432
NOTRIM=glibc.malloc.trim_threshold=1073741824:glibc.malloc.top_pad=67108864
cs warm16 16 $N16 pp:512 $G2000 w:250 512000
log "WARM DONE"
for rep in 1 2 3; do
  cs g2000_pp_r$rep      16 $N16 pp:512  $G2000 w:400 $END
  cs g2000_wps_r$rep     16 $N16 wps:512 $G2000 w:400 $END
  GT=$MMAP   cs g2000_ppmmap_r$rep   16 $N16 pp:512 $G2000 w:400 $END
  GT=$NOTRIM cs g2000_ppnotrim_r$rep 16 $N16 pp:512 $G2000 w:400 $END
  log "REP $rep DONE"
done
kill -TERM $SMP 2>/dev/null; for i in $(seq 1 30); do kill -0 $SMP 2>/dev/null || break; sleep 1; done
log "sampler stopped: $(ls $OUT/hfi 2>/dev/null | grep -c '\.csv$') node files"
log "ALLOC58 DONE"
