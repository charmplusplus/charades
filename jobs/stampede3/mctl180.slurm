#!/bin/bash -l
#SBATCH -J mctl180
#SBATCH -t 01:00:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/mctl180_%j.out
# Job M (charades RESULTS.md section 180): the measured-cost controller
# (--ctl=3, main 0e158d5) against the quantile rule (q:0.001) and fixed
# windows, at 16 nodes then the allocation's first 4, 2 reps (arm order
# reversed in rep 2). --localalloc launch, --blocked-time=1, untraced.
#   PHOLD lookahead 100 / mean 1,000, end 2,048,000:
#     sigma 100 (PP 2,048): W 300, q, m;  sigma 2,000 (PP 512): W 100, 300, q, m;
#     uniform (WPs 512): W 300, q, m
#   PHOLD lookahead 10 / mean 200, sigma 500 (PP 512), end 512,000:
#     W 50, 100, 200, 300, q, m
#   phase-changing PHOLD (lookahead 10 / mean 200 and 100 / 1,000 every
#     8,000; remote 0.5; PP 512), end 1,024,000: W 100, 250, 500, q, m
#   traffic (64 x 46N, 16 cars per intersection, trip radius 3; PP 2,048),
#     end 6,000,000: W 250, 1,000, q, m
#   dragonfly (16 nodes a=28 h=14, 4 nodes a=16 h=10; p=4; uniform; arrival
#     500 ns, generating 150,000 ns; WPs 512; buckets 1,000 ps), end
#     160,000,000 ps: W 10,000, 20,000, q, m
# Submit: sbatch -p skx-dev -N 16 -n 768 -x c455-081 mctl180.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/mctl180/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-phaseb; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh
NL=($(scontrol show hostnames $SLURM_JOB_NODELIST))
join() { local IFS=,; echo "$*"; }
N16=$(join ${NL[@]:0:16}); N4=$(join ${NL[@]:0:4})
log "job $SLURM_JOB_ID; nodes ${NL[*]}"
log "charades $(git -C $C log --oneline -1 | cut -c1-60)"
for b in $C/models/phold/simple/phold $C/models/traffic/traffic $C/models/dragonfly/dragonfly; do
  strings $b | grep -q "measured cost (PE time" || { log "$b lacks --ctl=3"; exit 1; }
done
grep -q "m)    extra" $S || { log "ctl_sweep.sh lacks the m arm"; exit 1; }
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model "Simple PHOLD" --model Dragonfly \
    agg_ctl_measured_bucket_pp agg_ctl_measured_fast_bucket_pp bucket_window > $OUT/gate.txt 2>&1 )
tail -3 $OUT/gate.txt
grep -q "Failed: *0/" $OUT/gate.txt && grep -q "Timed out: *0/" $OUT/gate.txt || { log "GATE FAILED"; exit 1; }
log "GATE DONE"

export TREE=$T PPN=2 PEPP=23 CPT=24 CAP=300 LPC=16
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1"
cs() { # tag nodes nodelist agg workload arms end [bucket] [lps per PE]
  ( export NODES=$2 AGG=$4 WORKLOADS="$5" ARMS="$6" END=$7 BUCKETS=${8:-8} LPS_PER_PE=${9:-128} \
      EXTRA_ARGS="$L" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" ); }
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
for rep in 1 2; do
  ord() { [ $rep = 1 ] && echo "$1" || rev "$1"; }
  for n in 16 4; do
    if [ $n = 16 ]; then nl=$N16 df=dragonfly:28:14:4:1:500:150000; else nl=$N4 df=dragonfly:16:10:4:1:500:150000; fi
    cs g100_r$rep  $n $nl pp:2048 gauss:100:1000:100  "$(ord 'w:300 q:0.001 m:0')" 2048000
    cs g2000_r$rep $n $nl pp:512  gauss:100:1000:2000 "$(ord 'w:100 w:300 q:0.001 m:0')" 2048000
    cs uni_r$rep   $n $nl wps:512 steady:100:1000:1.0 "$(ord 'w:300 q:0.001 m:0')" 2048000
    cs la10_r$rep  $n $nl pp:512  gauss:10:200:500    "$(ord 'w:50 w:100 w:200 w:300 q:0.001 m:0')" 512000
    cs phases_r$rep $n $nl pp:512 phases:10:200:100:1000:0.5:8000 "$(ord 'w:100 w:250 w:500 q:0.001 m:0')" 1024000
    cs traffic_r$rep $n $nl pp:2048 traffic:100:1000:64:16:0:0:3 "$(ord 'w:250 w:1000 q:0.001 m:0')" 6000000 8 64
    cs df_r$rep    $n $nl wps:512 $df "$(ord 'w:10000 w:20000 q:0.001 m:0')" 160000000 1000
    log "N $n REP $rep DONE"
  done
done
log "MCTL180 DONE"
