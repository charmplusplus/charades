#!/bin/bash -l
#SBATCH -J pp60
#SBATCH -t 00:40:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/pp60_%j.out
# Job P16 (charades RESULTS.md section 160): htram PP's shared buffers allocated
# at their own limit (--agg-pp-alloc=1) against htram's largest size (default),
# and WPs 512, on the four workloads that use PP. 16 nodes, W 400, end time
# 2,048,000, untraced, 3 reps interleaved. Tree charades-alloc (htram
# pp-alloc-limit).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 pp60.slurm
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/pp60/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-alloc; S=$W/$T/scripts/stampede3/ctl_sweep.sh
NL=($(scontrol show hostnames $SLURM_JOB_NODELIST))
join() { local IFS=,; echo "$*"; }
N16=$(join ${NL[@]:0:16})
log "job $SLURM_JOB_ID; nodes ${NL[*]}"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-40); reconverse $(git -C $W/charm-pads-exp/contrib/reconverse log --oneline -1 | cut -c1-40)"
strings $W/$T/models/phold/simple/phold | grep -q "allocated at their own limit" || { log "binary lacks --agg-pp-alloc"; exit 1; }
gate() { # output file
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/$T/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $W/$T/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
    python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" \
      agg_deadline_bucket_pp_alloc agg_auto_bigpp_alloc agg_deadline_bucket_pp > $1 2>&1 )
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
END=2048000
cs() { # tag nodes nodelist agg workload arms end [extra Charades flags]
  ( export NODES=$2 AGG=$4 END=$7 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="$L ${8:-}" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" ); }
cs warm16 16 $N16 pp:512 gauss:100:1000:2000 w:250 512000
log "WARM DONE"
for rep in 1 2 3; do
  for spec in 100:pp:2048 1000:pp:2048 2000:pp:512 4000:pp:512; do
    sig=${spec%%:*}; agg=${spec#*:}; W_=gauss:100:1000:$sig
    cs g${sig}_pp_r$rep      16 $N16 $agg    $W_ w:400 $END
    cs g${sig}_ppalloc_r$rep 16 $N16 $agg    $W_ w:400 $END "--agg-pp-alloc=1"
    cs g${sig}_wps_r$rep     16 $N16 wps:512 $W_ w:400 $END
  done
  log "REP $rep DONE"
done
log "PP60 DONE"
