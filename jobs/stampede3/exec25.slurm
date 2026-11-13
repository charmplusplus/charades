#!/bin/bash -l
#SBATCH -J exec25
#SBATCH -t 01:00:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/exec25_%j.out
# Splitting execute() (--gvt-trace=5) on uniform at 4 and 16 nodes, sigma 4,000
# as a control; charades 0cf5341, htram 699c3a9, Reconverse 22871c6
# (charades RESULTS.md section 127).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 exec25.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/exec25/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-50); htram $(git -C $W/htram log --oneline -1 | cut -c1-50); reconverse $(git -C $W/charm-pads-exp/contrib/reconverse log --oneline -1 | cut -c1-50)"
gate() { # output file
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/$T/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $W/$T/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
    python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" \
      bucket_gvt_trace5 bucket_gvt_trace4 bucket_window agg_bucket_pp > $1 2>&1 )
  tail -4 $1; grep -E "FAIL|TIMEOUT" $1 | head
  grep -q "Failed: *0/" $1 && grep -q "Timed out: *0/" $1; }
# A failure that is only /work2 failing to read a library (Input/output error,
# as in job 3650177) gets one rerun; any other failure stops the job
if ! gate $OUT/gate.txt; then
  bad=$(grep -E "FAIL|TIMEOUT" $OUT/gate.txt | awk '{print $NF}' | grep "test.out$")
  if [ -n "$bad" ] && [ -z "$(for f in $bad; do grep -L "Input/output error" $f; done)" ]; then
    log "GATE: /work2 read errors only; rerunning"
    gate $OUT/gate2.txt || { log "GATE FAILED"; exit 1; }
  else log "GATE FAILED"; exit 1; fi
fi
log "GATE DONE"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
S4K=gauss:100:1000:4000; UNI=steady:100:1000:1.0
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
cs() { # tag nodes agg workloads extra
  ( export NODES=$2 AGG=$3 END=512000 WORKLOADS="$4" ARMS=w:400 EXTRA_ARGS="$L $5"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm 16 pp:512 gauss:100:1000:100 ""
cs warm2 16 pp:512 gauss:100:1000:100 ""
for rep in 1 2; do
  for n in 16 4; do
    cs T_uni_n${n}_r$rep $n wps:512 $UNI "--gvt-trace=5 --pe-stats=1"
    cs off_uni_n${n}_r$rep $n wps:512 $UNI ""
    cs T_s4k_n${n}_r$rep $n pp:512 $S4K "--gvt-trace=5 --pe-stats=1"
    cs off_s4k_n${n}_r$rep $n pp:512 $S4K ""
  done
  log "REP $rep DONE"
done
log "EXEC25 DONE"
