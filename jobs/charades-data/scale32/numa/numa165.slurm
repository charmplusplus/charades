#!/bin/bash -l
#SBATCH -J numa165
#SBATCH -t 00:40:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/numa165_%j.out
# Job N32 (charades RESULTS.md section 165): numactl --localalloc (automatic
# NUMA balancing kept away) at 32 nodes for Charades and Devastator; the
# controller with per-LP rollback; 16 -> 32 efficiency; the slow-run state.
# End time 2,048,000, untraced; the sampler (hfi1, interrupts, /proc/vmstat) on
# every node throughout.
#   A. Charades W 400, 3 reps: sigma 100 (PP 2,048), sigma 2,000 (PP 512),
#      uniform (WPs 512), each with --localalloc (the launch) and without,
#      back to back, the order alternating by rep
#   B. Charades controller (q:0.001), --localalloc, 3 reps: sigma 100, 2,000
#   C. Devastator W 1,000, 2 reps: sigma 100 and uniform, with and without
#   D. 16 nodes (the first 16): sigma 100 W 400, --localalloc, 2 reps
# Submit: sbatch -p skx -N 32 -n 1536 -x c455-081 numa165.slurm
set -u
NN=32
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/numa165/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-alloc; S=$W/$T/scripts/stampede3/ctl_sweep.sh; D=$W/devastator
NL=($(scontrol show hostnames $SLURM_JOB_NODELIST))
join() { local IFS=,; echo "$*"; }
N32=$(join ${NL[@]:0:$NN}); N16=$(join ${NL[@]:0:16})
log "job $SLURM_JOB_ID ($NN nodes); nodes ${NL[*]}"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram-alloc log --oneline -1 | cut -c1-40); reconverse $(git -C $W/charm-pads-exp/contrib/reconverse log --oneline -1 | cut -c1-40)"
B=$W/$T/models/phold/simple/phold
strings $B | grep -q "agg-pp-alloc must be 0 or 1" || { log "binary lacks --agg-pp-alloc"; exit 1; }
grep -q 'NUMA_WRAP-numactl --localalloc' $S || { log "ctl_sweep.sh lacks the numactl launch"; exit 1; }
grep -q 'BIN_WRAP:-} stdbuf' $D/run_phold.sh || { log "run_phold.sh lacks BIN_WRAP"; exit 1; }
log "numa_balancing per node: $(srun -N $NN --ntasks-per-node=1 -w $N32 -J nb bash -c 'cat /proc/sys/kernel/numa_balancing' 2>/dev/null | sort | uniq -c | tr '\n' ' ')"
gate() { # output file
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/$T/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $W/$T/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
    python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" \
      agg_deadline_bucket_pp_diag agg_deadline_bucket_pp agg_deadline_bucket_pp_bigalloc agg_inputbuf_bucket_wps bucket_window > $1 2>&1 )
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
cs() { # tag nodes nodelist agg workload arms end [extra Charades flags]; BAL=1: without numactl (balancing on)
  ( export NODES=$2 AGG=$4 END=$7 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="$L ${8:-}" SRUN_ARGS="-w $3"
    [ -n "${BAL:-}" ] && export NUMA_WRAP=
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" ); }
dv() { # tag nodes nodelist window workload-remote sigma; LOC=1: under numactl --localalloc
  local db=$D/bin/ofi-psm2/phold-gauss-p$(($2 * 2))w23 extra=()
  [ "$5" != 0 ] && extra=(--remote=$5)
  ( export WINDOW=$4 RUNS=$OUT/n$2/deva LPS_PER_RANK=128 START=15 LOOKAHEAD=100 MEAN=1000 SIGMA=$6 END=$END CAP=200 AFFINITY=0 SRUN_EXTRA="-w $3"
    [ -n "${LOC:-}" ] && export BIN_WRAP="numactl --localalloc"
    LABEL=$1 bash $D/run_phold.sh $db $2 --rng=clcg4 "${extra[@]}" | head -1 | sed "s/^/n$2 /" | cut -c1-120 ); }
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
pair() { # rep tag agg workload: --localalloc and without, the order alternating by rep
  if [ $(($1 % 2)) = 1 ]; then cs $2_loc_r$1 $NN $N32 $3 $4 w:400 $END; BAL=1 cs $2_bal_r$1 $NN $N32 $3 $4 w:400 $END
  else BAL=1 cs $2_bal_r$1 $NN $N32 $3 $4 w:400 $END; cs $2_loc_r$1 $NN $N32 $3 $4 w:400 $END; fi; }
for rep in 1 2 3; do
  pair $rep g100 pp:2048 $G100
  pair $rep g2000 pp:512 $G2000
  pair $rep uni wps:512 $UNI
  log "A REP $rep DONE"
done
for rep in 1 2 3; do
  cs g100_ctl_r$rep  $NN $N32 pp:2048 $G100  q:0.001 $END
  cs g2000_ctl_r$rep $NN $N32 pp:512  $G2000 q:0.001 $END
done
log "B DONE"
for rep in 1 2; do
  LOC=1 dv g100_w1000_loc_r$rep $NN $N32 1000 0 100
  dv g100_w1000_bal_r$rep $NN $N32 1000 0 100
  LOC=1 dv uni_w1000_loc_r$rep $NN $N32 1000 1.0 0
  dv uni_w1000_bal_r$rep $NN $N32 1000 1.0 0
done
log "C DONE"
for rep in 1 2; do cs g100_loc_r$rep 16 $N16 pp:2048 $G100 w:400 $END; done
log "D DONE"
smp_stop
log "NUMA165 DONE"
