#!/bin/bash -l
#SBATCH -p skx
#SBATCH -t 01:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /work2/09863/rrao/stampede3/charades-runs/scale/job_%j.out
# Scaling check at 16 and 32 nodes (charades RESULTS.md "Scaling check at 16
# and 32 nodes", design 2026-10-23). Not paper numbers: does anything break or
# degrade at scale? Weak-scaled Gaussian PHOLD, 128 LPs per PE/rank, full nodes.
# Submit with: sbatch -N <nodes> -n <48*nodes> -J scale<nodes> \
#   --export=ALL,SCALE_NODES="<node counts to run>",REPS=2 scale.slurm
# Order within a rep (most important first): Charades htram, Devastator, ROSS,
# Charades direct, Charades LCI devices.
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/scale; mkdir -p $OUT
NL=${SCALE_NODES:-$SLURM_JOB_NUM_NODES} REPS=${REPS:-2}
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
log "job $SLURM_JOB_ID on $SLURM_JOB_NUM_NODES nodes ($SLURM_JOB_NODELIST); runs at nodes: $NL; reps $REPS"

T=charades-main; S=$W/$T/scripts/stampede3/ctl_sweep.sh
B=$W/$T/models/phold/simple/phold
[ -x $B ] && strings $B | grep -q ctl-sparse-waves || { log "FAILED: $B missing or lacks --ctl-sparse-waves"; exit 1; }
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-50)"

# Devastator: the process count is compiled in (2 per node), so build each
# layout this job needs if it is missing (compute node, node-local tree).
D=$W/devastator
for N in $NL; do
  db=$D/bin/ofi-psm2/phold-gauss-p$((2 * N))w23
  if [ ! -x $db ]; then
    log "building $(basename $db)"
    LAYOUTS="$((2 * N)):23" STOCK=0 PAR=0 bash $D/build_stampede3.sh ofi-psm2 > $OUT/deva_build_${SLURM_JOB_ID}_p$((2 * N)).log 2>&1
    [ -x $db ] && log "built $db" || log "Devastator build FAILED for N=$N (log $OUT/deva_build_${SLURM_JOB_ID}_p$((2 * N)).log)"
  fi
done

export TREE=$T LPS_PER_PE=128 LPC=16 CAP=120 PPN=2 PEPP=23 CPT=24
P="+pemap 2-46:2,3-47:2"
alive() { grep -q ",ok," "$1" 2>/dev/null; }
cs() { # tag nodes agg workloads arms ndev
  local f=$OUT/$1_n$2_r$rep.csv
  ( export NODES=$2 AGG=$3 END=512000 WORKLOADS="$4" ARMS="$5" EXTRA_ARGS="+lci_ndevices $6 $P"
    RUNS=$OUT/$1 $S 1 $f | grep -E " (ok|fail|stall) " | sed "s/^/$1 n$2 /" )
  alive $f
}
dv() { # nodes sigma window
  local db=$D/bin/ofi-psm2/phold-gauss-p$(($1 * 2))w23
  [ -x $db ] || { log "skip Devastator N=$1 (no binary)"; return; }
  ( export WINDOW=$3 RUNS=$OUT/deva LPS_PER_RANK=128 START=15 LOOKAHEAD=100 MEAN=1000 SIGMA=$2 END=512000 CAP=90 AFFINITY=0
    LABEL=deva_n$1_s$2_w$3_r$rep bash $D/run_phold.sh $db $1 --rng=clcg4 | head -1 )
}
ross() { # nodes sigma
  local n=$(($1 * 46)) f=$OUT/ross/ross_n$1_s$2_r$rep.out; mkdir -p $OUT/ross
  ( module load mvapich/3.0 >/dev/null 2>&1
    unset FI_PROVIDER FI_PROVIDER_PATH LCI_ATTR_BACKEND LCI_ATTR_OFI_PROVIDER_NAME LCI_ATTR_PACKET_SIZE PSM2_MULTI_EP
    timeout -s TERM 300 srun --mpi=pmi2 --kill-on-bad-exit=1 -J ross_n$1 -N $1 -n $n --ntasks-per-node=46 \
      $W/ROSS/build/models/phold-gauss/phold-gauss --synch=3 --read-buffer=1 --start-events=15 --sigma=$2 \
      --extramem=800000 --num-lps=$((n * 128)) --lookahead=100 --mean=1000 --end=512000 > $f 2>&1
    echo "ross n$1 s$2 r$rep rc=$? committed $(awk '/Net Events Processed/{print $NF; exit}' $f) M_ev_s $(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' $f) eff $(awk '/Efficiency/{print $(NF-1); exit}' $f) time $(awk '/Running Time/{print $(NF-1); exit}' $f)" | tee -a $OUT/ross/results.txt )
}

for rep in $(seq $REPS); do
  for N in $NL; do
    log "rep $rep, $N nodes"
    if ! cs htram $N pp:512 "gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0" "q:0.001 w:150 w:250 w:400" 16; then
      log "no Charades htram run finished at $N nodes: skipping the other Charades runs there"; skipc=1
    else skipc=0; fi
    dv $N 100 1000; dv $N 2000 1000; dv $N 2000 500
    ross $N 2000
    if [ $skipc = 0 ]; then
      cs direct $N off "gauss:100:1000:2000" "q:0.001 w:250 w:500" 16
      cs ndev8 $N pp:512 "gauss:100:1000:2000" "w:250" 8
      cs ndev32 $N pp:512 "gauss:100:1000:2000" "w:250" 32
    fi
  done
  log "REP $rep DONE"
done
log "SCALE DONE"
