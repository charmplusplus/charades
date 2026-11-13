#!/bin/bash -l
#SBATCH -J scale23
#SBATCH -t 01:58:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/scale23_%j.out
# Weak scaling 1/4/16 nodes in one allocation with +lci_ndevices 23, Charades
# and Devastator, 3 reps; plus glibc no-trim (mtrim) against the defaults at
# 16 nodes, for both engines (charades RESULTS.md section 93).
# Submit: sbatch -p skx -N 16 -n 768 -x c455-081 scale23.slurm   (or skx-dev)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/scale23/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh; D=$W/devastator
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-50)"
MTRIM="glibc.malloc.trim_threshold=1073741824:glibc.malloc.top_pad=67108864"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
cs() { # tag nodes agg end workloads arms   (env TUN: GLIBC_TUNABLES)
  ( [ -n "${TUN:-}" ] && export GLIBC_TUNABLES=$TUN
    export NODES=$2 AGG=$3 END=$4 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="+lci_ndevices 23 +pemap 2-46:2,3-47:2"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
dv() { # tag nodes end lookahead mean sigma window extra...   (env TUN)
  local tag=$1 n=$2 end=$3 la=$4 mean=$5 sig=$6 w=$7; shift 7
  ( [ -n "${TUN:-}" ] && export GLIBC_TUNABLES=$TUN
    export WINDOW=$w RUNS=$OUT/deva LPS_PER_RANK=128 START=15 LOOKAHEAD=$la MEAN=$mean SIGMA=$sig END=$end CAP=90 AFFINITY=0
    LABEL=${tag}_n${n}_s${sig}_w${w}_r$rep bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p$((2 * n))w23 $n --rng=clcg4 "$@" | head -1 ); }
HI="gauss:100:1000:100 gauss:100:1000:500 gauss:100:1000:1000 gauss:100:1000:2000 gauss:100:1000:4000 steady:100:1000:1.0"
LO="gauss:10:200:500 gauss:10:200:2000"
SIGS="100 500 1000 2000 4000"
cs warm 16 pp:512 512000 gauss:100:1000:100 w:250
cs warm2 16 pp:512 512000 gauss:100:1000:100 w:250
for rep in 1 2 3; do
  for n in 16 4 1; do
    for a in pp:512 pp:2048; do
      t=${a/:/}
      cs hi_${t}_n${n}_r$rep $n $a 512000 "$HI" "w:250 w:400 w:600 q:0.001"
      cs lo_${t}_n${n}_r$rep $n $a 128000 "$LO" "w:50 w:100 w:200 q:0.001"
    done
    cs uni_wps512_n${n}_r$rep $n wps:512 512000 steady:100:1000:1.0 "w:250 w:400 w:600 q:0.001"
    cs lo2k_wps512_n${n}_r$rep $n wps:512 128000 gauss:10:200:2000 "w:50 w:100 w:200 q:0.001"
    WS="500 1000"; [ $n = 16 ] && WS="500 1000 2000"
    for w in $WS; do
      for sig in $SIGS; do dv hi $n 512000 100 1000 $sig $w; done
      dv hi $n 512000 100 1000 0 $w --remote=1.0
    done
    for w in 100 200 400; do for sig in 500 2000; do dv lo $n 128000 10 200 $sig $w; done; done
    log "REP $rep N $n DONE"
  done
  # glibc no-trim at 16 nodes: Charades at the settings that won in job 3641926
  # (plus the controller), Devastator at its best W
  export TUN=$MTRIM
  for a in pp:512 pp:2048; do
    t=${a/:/}
    cs mt_hi_${t}_n16_r$rep 16 $a 512000 "$HI" "w:400 q:0.001"
    cs mt_lo_${t}_n16_r$rep 16 $a 128000 "$LO" "w:50 q:0.001"
  done
  cs mt_uni_wps512_n16_r$rep 16 wps:512 512000 steady:100:1000:1.0 "w:400 q:0.001"
  cs mt_lo2k_wps512_n16_r$rep 16 wps:512 128000 gauss:10:200:2000 "w:50 q:0.001"
  for sig in $SIGS; do dv mthi 16 512000 100 1000 $sig 1000; done
  dv mthi 16 512000 100 1000 0 1000 --remote=1.0
  for sig in 500 2000; do dv mtlo 16 128000 10 200 $sig 200; done
  unset TUN
  log "REP $rep MTRIM DONE"
done
log "SCALE23 DONE"
