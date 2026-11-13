#!/bin/bash -l
#SBATCH -J scale
#SBATCH -t 01:50:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/scale_%j.out
# Weak scaling, 1-16 nodes in one allocation, Charades and Devastator; then
# one process per node and --comm-stats at 16 nodes (charades RESULTS.md section 77).
# Submit: sbatch -p skx -N 16 -n 768 scale.slurm   (or skx-dev)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/scale/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-nw; S=$W/$T/scripts/stampede3/ctl_sweep.sh; D=$W/devastator
log "job $SLURM_JOB_ID, $SLURM_NNODES nodes; charades $(git -C $W/$T log --oneline -1 | cut -c1-60)"
# Devastator binaries for 2 and 8 nodes, and 1 node rebuilt from the same
# source as the 4- and 16-node ones (p2w23 predates the phases change)
for p in 2 4 16; do f=$D/bin/ofi-psm2/phold-gauss-p${p}w23; [ -e $f ] && cp -p $f $f.pre-scale; done
log "building Devastator p2 p4 p16"
LAYOUTS="2:23 4:23 16:23" STOCK=0 PAR=0 bash $D/build_stampede3.sh ofi-psm2 2>&1 | tail -6
P2="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60
cs() { # tag nodes ppn agg end workloads arms extra
  ( export NODES=$2 AGG=$4 END=$5 WORKLOADS="$6" ARMS="$7"
    if [ $3 = 1 ]; then export PPN=1 PEPP=46 CPT=48 EXTRA_ARGS="+lci_ndevices 16 +pemap 2-47 $8"
    else export PPN=2 PEPP=23 CPT=24 EXTRA_ARGS="$P2 $8"; fi
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
dv() { # tag nodes end lookahead mean sigma window extra...
  local tag=$1 n=$2 end=$3 la=$4 mean=$5 sig=$6 w=$7; shift 7
  ( export WINDOW=$w RUNS=$OUT/deva LPS_PER_RANK=128 START=15 LOOKAHEAD=$la MEAN=$mean SIGMA=$sig END=$end CAP=90 AFFINITY=0
    LABEL=${tag}_n${n}_s${sig}_w${w}_r$rep bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p$((2 * n))w23 $n --rng=clcg4 "$@" | head -1 ); }
HI="gauss:100:1000:100 gauss:100:1000:500 gauss:100:1000:1000 gauss:100:1000:2000 gauss:100:1000:4000 steady:100:1000:1.0"
LO="gauss:10:200:500 gauss:10:200:2000"
# Warm every node: a first launch on an untouched node can print nothing until the cap
cs warm 16 2 pp:512 512000 gauss:100:1000:100 w:250 ""
cs warm2 16 2 pp:512 512000 gauss:100:1000:100 w:250 ""
for rep in 1 2; do
  for n in 16 8 4 2 1; do
    for a in pp:512 pp:2048; do
      t=${a/:/}
      cs hi_${t}_n${n}_r$rep $n 2 $a 512000 "$HI" "w:250 w:400 w:600 q:0.001" ""
      cs lo_${t}_n${n}_r$rep $n 2 $a 128000 "$LO" "w:50 w:100 w:200 q:0.001" ""
    done
    cs uni_wps512_n${n}_r$rep $n 2 wps:512 512000 steady:100:1000:1.0 "w:250 w:400 w:600 q:0.001" ""
    cs lo2k_wps512_n${n}_r$rep $n 2 wps:512 128000 gauss:10:200:2000 "w:50 w:100 w:200 q:0.001" ""
    for w in 500 1000; do
      for sig in 100 500 1000 2000 4000; do dv hi $n 512000 100 1000 $sig $w; done
      dv hi $n 512000 100 1000 0 $w --remote=1.0
    done
    for w in 100 200 400; do for sig in 500 2000; do dv lo $n 128000 10 200 $sig $w; done; done
    log "REP $rep N $n DONE"
  done
done
# One process per node (46 PEs) against two (2 x 23) at 16 nodes, where messages are smallest
for rep in 1 2; do
  for ppn in 1 2; do
    for a in pp:512 pp:2048; do
      t=${a/:/}
      cs ppn${ppn}_hi_${t}_r$rep 16 $ppn $a 512000 "gauss:100:1000:2000 gauss:100:1000:4000 steady:100:1000:1.0" "w:250 w:400 w:600" ""
      cs ppn${ppn}_lo_${t}_r$rep 16 $ppn $a 128000 gauss:10:200:2000 "w:50 w:100 w:200" ""
    done
  done
  log "PPN REP $rep DONE"
done
# Send-call time and send-to-receive latency at 16 nodes
cs comm 16 2 pp:512 512000 "gauss:100:1000:2000 steady:100:1000:1.0" "w:250 w:600" "--comm-stats=1"
log "SCALE DONE"
