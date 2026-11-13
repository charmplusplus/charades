#!/bin/bash -l
#SBATCH -J numa63
#SBATCH -t 00:40:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/numa63_%j.out
# Job N16 (charades RESULTS.md section 163): are the TLB-shootdown bursts at a
# fixed time after setup automatic NUMA balancing, and does turning it off for
# our processes (numactl --localalloc: a non-default memory policy, which NUMA
# balancing skips) remove the 1.5-2.0 s dip? And does binding each process's
# CPUs and memory to its own socket from launch (numabind.sh) do better?
# 16 nodes, W 400, end time 2,048,000, untraced; the sampler (hfi1,
# interrupts, /proc/vmstat) on every node.
#   3 reps, interleaved: sigma 100 (PP 2,048) default / localalloc / bind /
#   5 s start delay; sigma 2,000 (PP 512) and uniform (WPs 512) default /
#   localalloc / bind
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 numa63.slurm
#         sbatch -p skx     -N 16 -n 768 -x c455-081 numa63.slurm  (cancel the loser)
set -u
NN=16
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/numa63/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-alloc; S=$W/$T/scripts/stampede3/ctl_sweep.sh
NL=($(scontrol show hostnames $SLURM_JOB_NODELIST))
join() { local IFS=,; echo "$*"; }
N16=$(join ${NL[@]:0:$NN})
log "job $SLURM_JOB_ID ($NN nodes); nodes ${NL[*]}"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram-alloc log --oneline -1 | cut -c1-40); reconverse $(git -C $W/charm-pads-exp/contrib/reconverse log --oneline -1 | cut -c1-40)"
B=$W/$T/models/phold/simple/phold
strings $B | grep -q "Start delay: the clock starts" && strings $B | grep -q "agg-pp-alloc must be 0 or 1" || { log "binary lacks --start-delay-ms or --agg-pp-alloc"; exit 1; }
log "numa_balancing per node: $(srun -N $NN --ntasks-per-node=1 -w $N16 -J nb bash -c 'echo $(cat /proc/sys/kernel/numa_balancing)' 2>&1 | sort | uniq -c | tr '\n' ' ')"
log "THP: $(srun -N 1 -n 1 -w ${NL[0]} -J thp cat /sys/kernel/mm/transparent_hugepage/enabled 2>&1)"
log "numactl --localalloc under srun: $(srun -N 1 -n 1 -c 24 -w ${NL[0]} -J nshow numactl --localalloc numactl --show 2>&1 | tr '\n' ';')"
log "numactl --hardware: $(srun -N 1 -n 1 -c 24 -w ${NL[0]} -J nhw numactl --hardware 2>&1 | head -4 | tr '\n' ';')"
log "numabind under srun (2 tasks): $(srun -N 1 -n 2 -c 24 -w ${NL[0]} -J nbind $W/$T/scripts/stampede3/numabind.sh true 2>&1 | tr '\n' ';')"
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
cs() { # tag nodes nodelist agg workload arms end [extra Charades flags]; NUMA=local: under numactl --localalloc; NUMA=bind: under numabind.sh
  ( export NODES=$2 AGG=$4 END=$7 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="$L ${8:-}" SRUN_ARGS="-w $3"
    [ "${NUMA:-}" = local ] && export BIN_WRAP="numactl --localalloc"
    [ "${NUMA:-}" = bind ] && export BIN_WRAP=$W/$T/scripts/stampede3/numabind.sh
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" ); }
SMP=
smp_start() {
  srun --overlap -N $NN --ntasks-per-node=1 -c 1 --cpu-bind=none -w $N16 -J hfi \
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
cs warm16 $NN $N16 pp:2048 $G100 w:250 512000
log "WARM DONE"
for rep in 1 2 3; do
  cs g100_def_r$rep             $NN $N16 pp:2048 $G100  w:400 $END
  NUMA=local cs g100_numa_r$rep $NN $N16 pp:2048 $G100  w:400 $END
  NUMA=bind cs g100_bind_r$rep  $NN $N16 pp:2048 $G100  w:400 $END
  cs g100_delay_r$rep           $NN $N16 pp:2048 $G100  w:400 $END "--start-delay-ms=5000"
  cs g2000_def_r$rep             $NN $N16 pp:512 $G2000 w:400 $END
  NUMA=local cs g2000_numa_r$rep $NN $N16 pp:512 $G2000 w:400 $END
  NUMA=bind cs g2000_bind_r$rep  $NN $N16 pp:512 $G2000 w:400 $END
  cs uni_def_r$rep             $NN $N16 wps:512 $UNI w:400 $END
  NUMA=local cs uni_numa_r$rep $NN $N16 wps:512 $UNI w:400 $END
  NUMA=bind cs uni_bind_r$rep  $NN $N16 wps:512 $UNI w:400 $END
  log "REP $rep DONE"
done
smp_stop
log "NUMA63 DONE"
