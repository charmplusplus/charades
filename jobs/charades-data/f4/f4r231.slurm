#!/bin/bash -l
#SBATCH -J f4r231
#SBATCH -t 00:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/f4r231_%j.out
# Job F4R (charades RESULTS.md section 231): rerun of F4's phase-changing PHOLD
# cell at 16 nodes (job 3684492's rep 2 was hit by an episode on the machine,
# section 230). Charades' arms only, as in f4227.slurm: W 50, 75, 100, 150,
# 250, 300, the frozen controller (mb:0) and Devastator's rule in Charades
# (hill:8); 3 reps, arm order reversed in rep 2.
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 f4r231.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/f4r231/j${SLURM_JOB_ID:-dry}; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-f3; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}"
[ "$(git -C $C rev-parse --short=7 HEAD)" = 8a34d51 ] || { log "$T not at 8a34d51"; exit 1; }
grep -q "mb)   extra" $S && grep -q "hill) extra" $S || { log "ctl_sweep.sh lacks the mb or hill arm"; exit 1; }
b=$C/models/phold/simple/phold
strings $b | grep -q "PER-PE WITH A SHARED SPARE LIST" || { log "$b is not round 3"; exit 1; }
ldd $b | grep -q "charm-pads-perf/" || { log "$b does not link charm-pads-perf"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }

# ---- gate: the controller and the hill climb on 2 nodes (Simple PHOLD)
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" \
    ctl_hill agg_ctl_measured_bucket_pp > $OUT/gate.txt 2>&1 )
tail -3 $OUT/gate.txt
grep -q "Failed: *0/" $OUT/gate.txt && grep -q "Timed out: *0/" $OUT/gate.txt || { log "GATE FAILED"; exit 1; }
log "GATE DONE"

export TREE=$T PPN=2 PEPP=23 CPT=24 CAP=180 LPC=16 START=15
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1 --commit-digest=1"
N16=$(join ${NL[@]:0:16}); mkdir -p $OUT/n16
ARMS="w:50 w:75 w:100 w:150 w:250 w:300 mb:0 hill:8"
REV="hill:8 mb:0 w:300 w:250 w:150 w:100 w:75 w:50"
for rep in 1 2 3; do
  ( export NODES=16 AGG=pp:512 WORKLOADS=phases:10:200:100:1000:0.5:8000 ARMS="$([ $rep = 2 ] && echo "$REV" || echo "$ARMS")" \
      END=1024000 BUCKETS=8 LPS_PER_PE=128 EXTRA_ARGS="$L" SRUN_ARGS="-w $N16"
    RUNS=$OUT/n16/phases_r$rep $S 1 $OUT/n16/phases_r$rep.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n16 phases_r$rep /" )
  rm -f $OUT/n16/phases_r$rep/ctl_sweep/logs/*.digest.csv $OUT/n16/phases_r$rep/ctl_sweep/gvt_*.out
  log "REP $rep DONE"
done
log "F4R231 DONE"
