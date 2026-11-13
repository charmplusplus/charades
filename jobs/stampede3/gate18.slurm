#!/bin/bash -l
#SBATCH -J gate18
#SBATCH -t 01:00:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/gate18_%j.out
# Correctness gate for +mempool_remote_free with ring input buffers (the
# default), on charades main 8344576 / htram 699c3a9 / Reconverse 22871c6,
# with the psm2 transport (job O's gate lacked it and every run aborted in
# LCI's ibv backend). Pass 2 runs 2 processes x 23 PEs, the rings' real load.
# Submit: sbatch -p skx-dev -N 2 -n 96 -x c455-081 gate18.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3
OUT=$W/charades-runs/gate18/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536
source $W/charades-diag/scripts/stampede3/env.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/charades-diag log --oneline -1 | cut -c1-50); htram $(git -C $W/htram log --oneline -1 | cut -c1-50); reconverse $(git -C $W/charm-pads-exp/contrib/reconverse log --oneline -1 | cut -c1-50)"
cd $W/charades-diag/tests
export CHARADES_RUN_ARGS="+mempool_remote_free"
python3 test.py --tier change --launcher srun --nodes 2 \
  sequential blocking bucket bucket_window conservative agg_blocking_pp agg_inputbuf_bucket_pp agg_inputbuf_bucket_wps \
  agg_inputbuf0_bucket_pp agg_deadline_bucket_pp agg_ctl_sparse_bucket_pp > $OUT/pass1.txt 2>&1
tail -4 $OUT/pass1.txt; grep -E "FAIL|TIMEOUT" $OUT/pass1.txt | head
log "PASS 1 DONE"
python3 test.py --tier change --no-build --launcher srun --nodes 2 --launch 2x23 --repeat 5 \
  --model "Simple PHOLD" --model "Imbalanced PHOLD" agg_inputbuf_bucket_pp agg_inputbuf_bucket_wps agg_ctl_sparse_bucket_pp > $OUT/pass2.txt 2>&1
tail -4 $OUT/pass2.txt; grep -E "FAIL|TIMEOUT" $OUT/pass2.txt | head
log "GATE18 DONE"
