#!/bin/bash -l
#SBATCH -J sdiag2
#SBATCH -t 00:50:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag2_%j.out
# The allocator behind --agg-pp-limit's gain; per-node speed and both engines
# with and without the slow node c455-081; where a wider window's cost goes
# (charades RESULTS.md section 81).
# Submit: sbatch -p skx-dev -N 16 -n 768 -w c455-081 diag2.slurm
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/sdiag2/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh; D=$W/devastator
SLOW=c455-081
NODES_ALL=($(scontrol show hostnames $SLURM_JOB_NODELIST))
OTHER=${NODES_ALL[-1]}; [ $OTHER = $SLOW ] && OTHER=${NODES_ALL[-2]}
log "job $SLURM_JOB_ID; nodes ${NODES_ALL[*]}; slow $SLOW; other excluded $OTHER"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-50)"
log "building Devastator p30"
LAYOUTS="30:23" STOCK=0 PAR=0 bash $D/build_stampede3.sh ofi-psm2 2>&1 | grep -E "^(OK|FAIL)"
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
cs() { # tag nodes agg end workloads arms extra [srun args]
  ( export NODES=$2 AGG=$3 END=$4 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="$P $7" SRUN_ARGS="${8:-}"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
dv() { # tag nodes sigma window srun-extra
  ( export WINDOW=$4 RUNS=$OUT/deva LPS_PER_RANK=128 START=15 LOOKAHEAD=100 MEAN=1000 SIGMA=$3 END=512000 CAP=90 AFFINITY=0 SRUN_EXTRA="$5"
    LABEL=$1_s$3_w$4_r$rep bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p$((2 * $2))w23 $2 --rng=clcg4 | head -1 ); }
cs warm 16 pp:512 512000 gauss:100:1000:100 w:250 ""
cs warm2 16 pp:512 512000 gauss:100:1000:100 w:250 ""
# N. One-node speed of every node (Charades, sigma 100 and 2,000, W 250)
for rep in 1 2; do
  for h in ${NODES_ALL[*]}; do
    cs N_${h}_r$rep 1 pp:512 512000 "gauss:100:1000:100 gauss:100:1000:2000" w:250 "" "-w $h"
  done
done
log "N DONE"
for rep in 1 2 3; do
  # M. Allocator settings on PP 512, against PP 2,048 capped at 512
  for v in base cap mmap pad; do
    a=pp:512; e=""; envs=""
    case $v in
      cap)  a=pp:2048; e="--agg-pp-limit=512" ;;
      mmap) envs="MALLOC_MMAP_THRESHOLD_=16777216 MALLOC_TRIM_THRESHOLD_=1073741824" ;;
      pad)  envs="MALLOC_TOP_PAD_=268435456 MALLOC_TRIM_THRESHOLD_=1073741824" ;;
    esac
    ( [ -n "$envs" ] && export $envs; cs M_${v}_r$rep 16 $a 512000 "gauss:100:1000:100 gauss:100:1000:2000" w:250 "$e" )
  done
  ( export MALLOC_MMAP_THRESHOLD_=16777216 MALLOC_TRIM_THRESHOLD_=1073741824
    cs M_capmmap_r$rep 16 pp:2048 512000 "gauss:100:1000:100 gauss:100:1000:2000" w:250 "--agg-pp-limit=512" )
  log "M REP $rep DONE"
  # S. Both engines on 15 nodes, with and without the slow node
  for set in without with; do
    x=$SLOW; [ $set = with ] && x=$OTHER
    cs S_${set}_r$rep 15 pp:512 512000 "gauss:100:1000:100 gauss:100:1000:2000" "w:250 w:400" "" "-x $x"
    for sig in 100 2000; do for w in 500 1000; do dv S_${set}_n15 15 $sig $w "-x $x"; done; done
  done
  log "S REP $rep DONE"
done
# W. Where a wider window's cost goes: per-process wave traces at W 250, 400, 600
for rep in 1 2; do
  for wl in gauss:100:1000:100 gauss:100:1000:2000; do
    for w in 250 400 600; do
      cs W_${wl//:/_}_w${w}_r$rep 16 pp:512 512000 $wl w:$w "--gvt-trace=2 --pe-stats=1"
    done
  done
  log "W REP $rep DONE"
done
log "SDIAG2 DONE"
