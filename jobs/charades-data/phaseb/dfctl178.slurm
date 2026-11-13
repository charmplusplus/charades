#!/bin/bash -l
#SBATCH -J dfctl178
#SBATCH -t 01:00:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/dfctl178_%j.out
# Job D (charades RESULTS.md section 178): why the controller reaches only
# 0.29-0.41 of the best fixed W on dragonfly (section 177): start-up or its
# rollback target. Long runs (arrival 500 ns, generating 300,000 ns, end
# 310,000,000 ps), uniform traffic, at 4 nodes (a=16 h=10 p=4) then 1 node
# (a=13 h=4 p=4); WPs 512, GVT buckets 1,000 ps; --localalloc launch,
# --blocked-time=1. 3 reps:
#   W 2,500 / 5,000 / 10,000 / 20,000 ps (order rotating by rep);
#   the controller at epsilon 0.001 (default), 0.01 and 0.03, with --ctl-log;
#   the controller at epsilon 0.001 started from alpha 0.005 (section 177's
#   final alpha) instead of 1;
#   rep 1 only: PP 512 and direct sends at W 10,000.
# Submit: sbatch -p skx-dev -N 4 -n 192 -x c455-081 dfctl178.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/dfctl178/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-phaseb; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh
NL=($(scontrol show hostnames $SLURM_JOB_NODELIST))
join() { local IFS=,; echo "$*"; }
N4=$(join ${NL[@]:0:4}); N1=${NL[0]}
log "job $SLURM_JOB_ID; nodes ${NL[*]}"
log "charades $(git -C $C log --oneline -1 | cut -c1-60)"
B=$C/models/dragonfly/dragonfly
strings $B | grep -q "Time Blocked at Window" || { log "dragonfly binary lacks --blocked-time"; exit 1; }
grep -q "dragonfly:<a>" $S || { log "ctl_sweep.sh lacks the dragonfly workload"; exit 1; }
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model Dragonfly \
    bucket_window agg_deadline_bucket_pp_blocked > $OUT/gate.txt 2>&1 )
tail -3 $OUT/gate.txt
grep -q "Failed: *0/" $OUT/gate.txt && grep -q "Timed out: *0/" $OUT/gate.txt || { log "GATE FAILED"; exit 1; }
log "GATE DONE"

export TREE=$T PPN=2 PEPP=23 CPT=24 CAP=300
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1"
END=310000000
DF4=dragonfly:16:10:4:1:500:300000 DF1=dragonfly:13:4:4:1:500:300000
cs() { # tag nodes nodelist agg workload arms [extra Charades flags]
  ( export NODES=$2 AGG=$4 END=$END BUCKETS=1000 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="$L ${7:-}" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" ); }
ORDER=("w:2500 w:5000 w:10000 w:20000" "w:20000 w:10000 w:5000 w:2500" "w:10000 w:2500 w:20000 w:5000")
for rep in 1 2 3; do
  for n in 4 1; do
    if [ $n = 4 ]; then nl=$N4 wl=$DF4; else nl=$N1 wl=$DF1; fi
    cs fixed_r$rep $n $nl wps:512 $wl "${ORDER[$((rep - 1))]}"
    cs ctl_r$rep $n $nl wps:512 $wl "q:0.001 q:0.01 q:0.03" "--ctl-log=1"
    cs ctla_r$rep $n $nl wps:512 $wl "q:0.001" "--ctl-log=1 --ctl-alpha-init=0.005"
    if [ $rep = 1 ]; then
      cs pp_r1 $n $nl pp:512 $wl "w:10000"
      cs direct_r1 $n $nl off $wl "w:10000"
    fi
  done
  log "REP $rep DONE"
done
log "DFCTL178 DONE"
