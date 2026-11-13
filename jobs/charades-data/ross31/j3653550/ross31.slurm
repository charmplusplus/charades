#!/bin/bash -l
#SBATCH -J ross31
#SBATCH -t 01:00:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/ross31_%j.out
# A0: ROSS tuning before the paper-grade scaling runs. Optimistic ROSS
# (--read-buffer=1) over --batch {4,16,64} x --gvt-interval {16,64,256}, and
# conservative ROSS, on Gaussian PHOLD sigma 100 and 2,000, uniform, and
# lookahead 10 sigma 2,000; 4 and 16 nodes, 46 ranks per node, 128 LPs per
# rank, end time 512,000 (128,000 at lookahead 10), 1 rep (charades RESULTS.md
# section 140).
# Submit: sbatch -p skx-dev -N 16 -n 736 -x c455-081 ross31.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/ross31/j$SLURM_JOB_ID; mkdir -p $OUT/out
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 mvapich/3.0 >/dev/null 2>&1
unset FI_PROVIDER FI_PROVIDER_PATH LCI_ATTR_BACKEND LCI_ATTR_OFI_PROVIDER_NAME LCI_ATTR_PACKET_SIZE PSM2_MULTI_EP
B=$W/ROSS/build/models/phold-gauss/phold-gauss
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "ROSS $(git -C $W/ROSS log --oneline -1 | cut -c1-60); $(md5sum $B | cut -c1-12)"
CSV=$OUT/ross.csv
echo "nodes,ranks,workload,synch,batch,gvt_interval,rc,committed,M_ev_s,efficiency,running_s,total_s" > $CSV
# workload: name lookahead mean sigma remote end
WLS="s100:100:1000:100:0:512000 s2000:100:1000:2000:0:512000 uniform:100:1000:0:1.0:512000 la10s2000:10:200:2000:0:128000"
ross() { # nodes workload synch batch gvt_interval
  local N=$1 n=$(($1 * 46)) synch=$3 b=$4 gi=$5
  IFS=: read -r name la mean sig rem end <<< "$2"
  local f=$OUT/out/n${N}_${name}_s${synch}_b${b}_g${gi}.out
  timeout -s TERM 400 srun --mpi=pmi2 --kill-on-bad-exit=1 -J ross_n$N -N $N -n $n --ntasks-per-node=46 \
    $B --synch=$synch --read-buffer=1 --start-events=15 --sigma=$sig --remote=$rem \
    --extramem=800000 --num-lps=$((n * 128)) --lookahead=$la --mean=$mean --end=$end \
    --batch=$b --gvt-interval=$gi > $f 2>&1
  local rc=$?
  echo "$N,$n,$name,$synch,$b,$gi,$rc,$(awk '/Net Events Processed/{print $NF; exit}' $f),$(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' $f),$(awk '/Efficiency/{print $(NF-1); exit}' $f),$(awk '/Running Time/{print $(NF-1); exit}' $f),$(awk '/Total Time/{print $NF; exit}' $f)" | tee -a $CSV
}
for N in 4 16; do
  for wl in $WLS; do
    ross $N $wl 2 16 16
    for b in 4 16 64; do for gi in 16 64 256; do ross $N $wl 3 $b $gi; done; done
  done
  log "N $N DONE"
done
log "ROSS31 DONE"
