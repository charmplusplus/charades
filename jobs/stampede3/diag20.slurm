#!/bin/bash -l
#SBATCH -J sdiag20
#SBATCH -t 01:00:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag20_%j.out
# Where the cross-process reduction's time goes: Charades' own process tree
# with per-hop times, a flat tree, smaller scheduler passes; charades cf2a484,
# htram 699c3a9, Reconverse 22871c6 (charades RESULTS.md section 117).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 diag20.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/sdiag20/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-50); htram $(git -C $W/htram log --oneline -1 | cut -c1-50); reconverse $(git -C $W/charm-pads-exp/contrib/reconverse log --oneline -1 | cut -c1-50)"
# Gate: the tree configs on 2 nodes, psm2 transport; stop if any fails
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/$T/scripts/stampede3/env.sh >/dev/null
  cd $W/$T/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" \
    bucket_tree2 bucket_treeflat bucket_window_tree2 bucket_window_treeflat agg_bucket_pp_tree2 \
    agg_bucket_pp_treeflat agg_ctl_sparse_bucket_pp_tree2 agg_ctl_sparse_bucket_pp_treeflat \
    bucket_gvt_trace2_tree2 > $OUT/gate.txt 2>&1 )
tail -4 $OUT/gate.txt; grep -E "FAIL|TIMEOUT" $OUT/gate.txt | head
if ! grep -q "Failed: *0/" $OUT/gate.txt || ! grep -q "Timed out: *0/" $OUT/gate.txt; then log "GATE FAILED"; exit 1; fi
log "GATE DONE"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
S2K=gauss:100:1000:2000; S4K=gauss:100:1000:4000; UNI=steady:100:1000:1.0
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free"
cs() { # tag nodes agg workloads arms extra
  ( export NODES=$2 AGG=$3 END=512000 WORKLOADS="$4" ARMS="$5" EXTRA_ARGS="$L $6"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
declare -A R=([charm]="" [tree4]="--gvt-wave-tree=4" [flat]="--gvt-wave-tree=64" [ar]="--gvt-wave-allreduce=1")
cs warm 16 pp:512 gauss:100:1000:100 w:250 ""
cs warm2 16 pp:512 gauss:100:1000:100 w:250 ""
for rep in 1 2; do
  for n in 16 4; do
    for r in charm tree4 flat ar; do
      cs A_${r}_T_n${n}_r$rep $n pp:512 $S2K w:400 "${R[$r]} --gvt-trace=2"
      cs A_${r}_off_n${n}_r$rep $n pp:512 $S2K w:400 "${R[$r]}"
    done
  done
  log "A REP $rep DONE"
  for n in 16 4; do
    for b in 4 8; do
      cs B_b${b}_off_n${n}_r$rep $n pp:512 $S2K w:400 "--batch=$b"
    done
  done
  for b in 4 8; do cs B_b${b}_T_n16_r$rep 16 pp:512 $S2K w:400 "--batch=$b --gvt-trace=2"; done
  log "B REP $rep DONE"
  for r in charm flat; do
    cs C_${r}_s4k_r$rep 16 pp:512 $S4K "w:400 q:0.001" "${R[$r]}"
    cs C_${r}_uni_r$rep 16 wps:512 $UNI "w:400 q:0.001" "${R[$r]}"
  done
  log "C REP $rep DONE"
done
log "SDIAG20 DONE"
