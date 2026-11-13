#!/bin/bash -l
#SBATCH -J sdiag14
#SBATCH -t 01:50:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag14_%j.out
# A: --gvt-wave-events 32/64/128 at 1, 4 and 16 nodes over the 8 scaling
# workloads; B: htram receives split into parts (--gvt-trace=3); charades
# 859fe1a, htram 04457e0 (charades RESULTS.md section 106).
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 diag14.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/sdiag14/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-60)"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
HI="gauss:100:1000:100 gauss:100:1000:500 gauss:100:1000:1000 gauss:100:1000:2000 gauss:100:1000:4000 steady:100:1000:1.0"
LO="gauss:10:200:500 gauss:10:200:2000"
UNI=steady:100:1000:1.0; S2K=gauss:100:1000:2000
cs() { # tag nodes agg end workloads arms extra
  ( export NODES=$2 AGG=$3 END=$4 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="+lci_ndevices 23 +pemap 2-46:2,3-47:2 $7"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm 16 pp:512 512000 gauss:100:1000:100 w:250 ""
cs warm2 16 pp:512 512000 gauss:100:1000:100 w:250 ""
# B first: the receive breakdown
for rep in 1 2; do
  for n in 16 4; do
    cs R_uni_wps512_n${n}_r$rep $n wps:512 512000 $UNI w:400 "--gvt-trace=3"
    cs R_uni_pp512_n${n}_r$rep $n pp:512 512000 $UNI w:400 "--gvt-trace=3"
    cs R_s2k_pp512_n${n}_r$rep $n pp:512 512000 $S2K w:400 "--gvt-trace=3"
  done
done
log "B DONE"
for rep in 1 2; do
  for n in 16 4 1; do
    for k in 32 64 128; do
      E="--gvt-wave-events=$k"
      cs k${k}_hi_pp512_n${n}_r$rep $n pp:512 512000 "$HI" "w:400 q:0.001" "$E"
      cs k${k}_lo_pp512_n${n}_r$rep $n pp:512 128000 "$LO" "w:50 q:0.001" "$E"
      cs k${k}_uni_wps512_n${n}_r$rep $n wps:512 512000 $UNI "w:400 q:0.001" "$E"
    done
    log "REP $rep N $n DONE"
  done
done
log "SDIAG14 DONE"
