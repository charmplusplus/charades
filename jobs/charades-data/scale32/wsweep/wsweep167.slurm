#!/bin/bash -l
#SBATCH -J wsweep167
#SBATCH -t 00:50:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/wsweep167_%j.out
# Job K (charades RESULTS.md section 167): where is the best fixed window at 16
# and 32 nodes, how far GVT trails the slowest PE at each W, and how far the
# controller (kappa 0.20) falls short. --localalloc launch (ctl_sweep.sh
# default), end time 2,048,000, untraced; the sampler on every node.
#   3 reps; per rep and workload, 32 nodes then the allocation's first 16:
#   W 250, 300, 400, 500, 600 and the controller (q:0.001), the arm order
#   rotating by rep. Workloads: sigma 100 (PP 2,048), sigma 2,000 (PP 512),
#   uniform (WPs 512).
# Submit: sbatch -p skx -N 32 -n 1536 -x c455-081 wsweep167.slurm
set -u
NN=32
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/wsweep167/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-alloc; S=$W/$T/scripts/stampede3/ctl_sweep.sh
NL=($(scontrol show hostnames $SLURM_JOB_NODELIST))
join() { local IFS=,; echo "$*"; }
N32=$(join ${NL[@]:0:$NN}); N16=$(join ${NL[@]:0:16})
log "job $SLURM_JOB_ID ($NN nodes); nodes ${NL[*]}"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram-alloc log --oneline -1 | cut -c1-40); reconverse $(git -C $W/charm-pads-exp/contrib/reconverse log --oneline -1 | cut -c1-40)"
B=$W/$T/models/phold/simple/phold
strings $B | grep -q "Slowest PE's lead over GVT" || { log "binary lacks the GVT-lag statistic"; exit 1; }
grep -q 'NUMA_WRAP-numactl --localalloc' $S && grep -q "Slowest PE" $S || { log "ctl_sweep.sh lacks the numactl launch or the gvt_lag column"; exit 1; }
gate() { # output file
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/$T/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $W/$T/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
    python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" \
      agg_deadline_bucket_pp_diag agg_deadline_bucket_pp agg_inputbuf_bucket_wps bucket_window > $1 2>&1 )
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
END=2048000 G100=gauss:100:1000:100 G2000=gauss:100:1000:2000 UNI=steady:100:1000:1.0
cs() { # tag nodes nodelist agg workload arms end [extra Charades flags]
  ( export NODES=$2 AGG=$4 END=$7 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="$L ${8:-}" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" ); }
SMP=
smp_start() {
  srun --overlap -N $NN --ntasks-per-node=1 -c 1 --cpu-bind=none -w $N32 -J hfi \
    python3 $W/$T/scripts/stampede3/hfi_sampler.py $OUT/hfi 0.1 > $OUT/hfi.log 2>&1 &
  SMP=$!; sleep 3
  kill -0 $SMP 2>/dev/null && log "sampler up (pid $SMP)" || log "SAMPLER FAILED: $(head -3 $OUT/hfi.log)"; }
smp_stop() {
  [ -n "$SMP" ] || return
  kill -TERM $SMP 2>/dev/null
  for i in $(seq 1 30); do kill -0 $SMP 2>/dev/null || break; sleep 1; done
  kill -0 $SMP 2>/dev/null && { log "sampler still up; scancel its step"; scancel --signal=TERM --full $SLURM_JOB_ID.$(sacct -j $SLURM_JOB_ID -n -o JobID,JobName | awk '$2=="hfi"{split($1,a,"."); print a[2]; exit}') 2>/dev/null; sleep 10; }
  log "sampler stopped: $(ls $OUT/hfi 2>/dev/null | grep -c '\.csv$') node files"; SMP=; }
smp_start
cs warm32 $NN $N32 pp:2048 $G100 w:250 512000
log "WARM DONE"
ORDER=("w:250 w:300 w:400 w:500 w:600 q:0.001" "q:0.001 w:600 w:500 w:400 w:300 w:250" "w:400 q:0.001 w:250 w:600 w:300 w:500")
for rep in 1 2 3; do
  A="${ORDER[$((rep - 1))]}"
  cs g100_r$rep  32 $N32 pp:2048 $G100  "$A" $END
  cs g100_r$rep  16 $N16 pp:2048 $G100  "$A" $END
  cs g2000_r$rep 32 $N32 pp:512  $G2000 "$A" $END
  cs g2000_r$rep 16 $N16 pp:512  $G2000 "$A" $END
  cs uni_r$rep   32 $N32 wps:512 $UNI   "$A" $END
  cs uni_r$rep   16 $N16 wps:512 $UNI   "$A" $END
  log "REP $rep DONE"
done
smp_stop
log "WSWEEP167 DONE"
