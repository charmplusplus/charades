#!/bin/bash -l
#SBATCH -J sdiag17
#SBATCH -t 01:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag17_%j.out
# +mempool_remote_free (Reconverse pads-remote-free): correctness gate on 2
# nodes, then throughput with and without at 1/4/16 nodes and the receive
# breakdown at 16, all with ring inboxes (charades RESULTS.md section 112).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 diag17.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/sdiag17/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-60); reconverse $(git -C $W/charm-pads-exp/contrib/reconverse log --oneline -1 | cut -c1-60)"
# Correctness gate: the new free path and rings on every model
( cd $W/$T/tests && CHARADES_RUN_ARGS="+mempool_remote_free --agg-inbox-mode=2" python3 test.py --tier change --launcher srun --nodes 2 \
    sequential blocking bucket bucket_window conservative agg_blocking_pp agg_inbox_bucket_pp agg_inbox_bucket_wps \
    agg_deadline_bucket_pp agg_ctl_sparse_bucket_pp > $OUT/gate.txt 2>&1 )
tail -4 $OUT/gate.txt; grep -E "FAIL|TIMEOUT" $OUT/gate.txt | head -20
log "GATE DONE"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
WL="gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0"
UNI=steady:100:1000:1.0
cs() { # tag nodes agg workloads arms extra
  ( export NODES=$2 AGG=$3 END=512000 WORKLOADS="$4" ARMS="$5" EXTRA_ARGS="+lci_ndevices 23 +pemap 2-46:2,3-47:2 --agg-inbox-mode=2 $6"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
declare -A F=([f0]="" [f1]="+mempool_remote_free")
cs warm 16 pp:512 gauss:100:1000:100 w:250 ""
cs warm2 16 pp:512 gauss:100:1000:100 w:250 ""
for rep in 1 2; do
  for f in f0 f1; do
    cs R_uni_wps512_${f}_r$rep 16 wps:512 $UNI w:400 "${F[$f]} --gvt-trace=3"
    cs R_uni_pp512_${f}_r$rep 16 pp:512 $UNI w:400 "${F[$f]} --gvt-trace=3"
  done
done
log "B DONE"
for rep in 1 2 3; do
  for n in 16 4 1; do
    for f in f0 f1; do
      cs ${f}_pp512_n${n}_r$rep $n pp:512 "$WL" "w:400 q:0.001" "${F[$f]}"
      cs ${f}_wps512_n${n}_r$rep $n wps:512 $UNI "w:400 q:0.001" "${F[$f]}"
    done
    log "REP $rep N $n DONE"
  done
done
log "SDIAG17 DONE"
