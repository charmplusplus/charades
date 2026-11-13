#!/bin/bash -l
#SBATCH -J sdiag11
#SBATCH -t 00:40:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag11_%j.out
# Late rank 0: does it follow the process-edge LPs (--map-rotate=11) or the
# rank, and does sending on the destination PE's device (+lci_dest_device,
# Reconverse pads-dest-device 13ae1ac) fix it? (charades RESULTS.md section 100)
# Submit: sbatch -p skx-dev -N 4 -n 192 -x c455-081 diag11.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/sdiag11/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); reconverse $(git -C $W/charm-pads-exp/contrib/reconverse log --oneline -1 | cut -c1-60)"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
declare -A A=([base]="" [rot]="--map-rotate=11" [dd]="+lci_dest_device" [ddrot]="+lci_dest_device --map-rotate=11")
cs() { # tag arm workload extra
  ( export NODES=4 AGG=pp:512 END=512000 WORKLOADS="$3" ARMS="w:400" EXTRA_ARGS="+lci_ndevices 23 +pemap 2-46:2,3-47:2 ${A[$2]} $4"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm base gauss:100:1000:100 ""
cs warm2 base gauss:100:1000:100 ""
cs smoke_dd dd gauss:100:1000:100 ""
for rep in 1 2; do
  for a in base rot dd ddrot; do
    for wl in gauss:100:1000:100 gauss:100:1000:2000; do
      s=${wl##*:}
      cs T_${a}_s${s}_r$rep $a $wl "--gvt-trace=3 --pe-stats=1"
      cs off_${a}_s${s}_r$rep $a $wl ""
    done
  done
  log "REP $rep DONE"
done
log "SDIAG11 DONE"
