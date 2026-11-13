#!/bin/bash -l
#SBATCH -J aauto
#SBATCH -t 01:00:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/auto4_%j.out
# --agg-auto validation and LPs per chare at lookahead 10 (charades RESULTS.md section 69)
# Submit: sbatch -p skx-dev -N 16 -n 768 auto.slurm ; sbatch -p skx -N 4 -n 192 auto.slurm
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
N=$SLURM_NNODES
OUT=$W/charades-runs/auto4/n$N; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-nw; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID, $N nodes; charades $(git -C $W/$T log --oneline -1 | cut -c1-60)"
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
export TREE=$T NODES=$N LPS_PER_PE=128 CAP=60 PPN=2 PEPP=23 CPT=24
cs() { # tag agg end workloads arms lpc extra
  ( export AGG=$2 END=$3 WORKLOADS="$4" ARMS="$5" LPC=$6 EXTRA_ARGS="$P $7"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
HI="gauss:100:1000:100 gauss:100:1000:500 gauss:100:1000:1000 gauss:100:1000:2000 gauss:100:1000:4000 steady:100:1000:1.0"
LO="gauss:10:200:500 gauss:10:200:2000"
cs warm pp:512 512000 gauss:100:1000:100 w:250 16 ""
cs warm2 pp:512 512000 gauss:100:1000:100 w:250 16 ""
# Canary: the --agg-auto cases that segfaulted or hung before htram 97db88e
cs canary pp:512 512000 "gauss:100:1000:100 gauss:100:1000:500" "w:250" 16 "--agg-auto=1"
cs canary2 pp:512 128000 "gauss:10:200:500" "w:50" 16 "--agg-auto=1"
if [ "$(cat $OUT/canary.csv $OUT/canary2.csv | grep -c ",ok,")" != 3 ]; then log "CANARY FAILED: stopping"; exit 1; fi
log "canary ok"
for rep in 1 2; do
  for v in pp:512: pp:2048: wps:512: pp:512:auto; do
    a=${v%:*} x=${v##*:} t=${a/:/}${x}
    e=""; [ "$x" = auto ] && e="--agg-auto=1"
    cs hi_${t}_r$rep $a 512000 "$HI" "w:250 w:400 w:600 q:0.001" 16 "$e"
    cs lo_${t}_r$rep $a 128000 "$LO" "w:50 w:100 q:0.001" 16 "$e"
  done
  for pz in 500 2000; do
    cs pause${pz}_r$rep pp:512 512000 "gauss:100:1000:100 gauss:100:1000:2000" "w:250" 16 "--blocked-pause-ns=$pz"
  done
  log "REP $rep DONE"
done
log "AUTO DONE"
