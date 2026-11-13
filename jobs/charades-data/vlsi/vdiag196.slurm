#!/bin/bash -l
#SBATCH -J vdiag196
#SBATCH -t 00:50:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/vdiag196_%j.out
# VLSI diagnostic, job V2 (charades RESULTS.md section 196): Charades only,
# b19 x N (one copy per node, balanced layout), 1 and 4 nodes side by side;
# 2 reps, arm order reversed in rep 2; 5,000 cycles (12,500,000 ps).
#   nodes 0-3: the 4-node series; node 4: the 1-node series (gate first on 0-1)
#   direct sends, W 2,500, buckets of 500 ps: --batch 4 / 16 / 64 (H1 and wave
#     pace together); --gvt-wave-events=16 and --wave-batch=4 (wave pace only, H2)
#   direct sends, buckets of 2,500 ps: W 2,500 and 5,000 (H2)
#   the frozen controller: direct sends with buckets of 500 and 2,500 ps;
#     PP 2,048 with buckets of 2,500 ps
#   WPs 512, W 2,500, buckets of 2,500 ps
#   rep 1 only: --gvt-trace=1 (every count wave) at direct W 2,500, buckets
#     of 500 and of 2,500 ps
# Submit: sbatch -p skx-dev -N 5 -n 240 -x c455-081 vdiag196.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/vdiag196/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-vlsi; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh; D=$W/devastator; RB=$W/ROSS/build/models
NETLIST=$W/I99T/i99t/b19/b19.bench
NL=($(scontrol show hostnames $SLURM_JOB_NODELIST))
join() { local IFS=,; echo "$*"; }
log "job $SLURM_JOB_ID; nodes ${NL[*]}; on $(hostname -s)"
log "charades $(git -C $C log --oneline -1 | cut -c1-60)"
strings $C/models/vlsi/vlsi | grep -q "layout-bins" || { log "Charades vlsi binary lacks the balanced layout"; exit 1; }

grep -q "vlsi:<circuit>" $S || { log "ctl_sweep.sh lacks the vlsi workload"; exit 1; }
for b in $NETLIST; do
  [ -e $b ] || { log "missing $b"; exit 1; }
done

# ---- gate: the VLSI test tier on 2 nodes
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model VLSI \
    agg_ctl_measured_fast_bucket_pp agg_deadline_bucket_pp agg_deadline_bucket_wps bucket_window ctl_measured_bucket > $OUT/gate.txt 2>&1 )
tail -3 $OUT/gate.txt
grep -q "Failed: *0/" $OUT/gate.txt && grep -q "Timed out: *0/" $OUT/gate.txt || {
  i=0; for f in $(grep -E " (FAIL|TIMEOUT) " $OUT/gate.txt | awk '{print $NF}'); do i=$((i+1)); cp $f $OUT/gate_fail_$i.out 2>/dev/null; done
  log "GATE FAILED (outputs in $OUT/gate_fail_*.out)"; exit 1; }
log "GATE DONE"

export TREE=$T PPN=2 PEPP=23 CPT=24 CAP=300 VLSI_NETLISTS=$W/I99T/i99t
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1 --commit-digest=1"
V_END=12500000
cs() { # tag nodes nodelist agg workload arms bucket lpc [extra engine args]
  ( export NODES=$2 AGG=$4 WORKLOADS="$5" ARMS="$6" END=$V_END BUCKETS=$7 LPC=$8 LPS_PER_PE=$8 \
      EXTRA_ARGS="$L ${9:-}" SRUN_ARGS="-w $3"
    RUNS=$OUT/n$2/$1 $S 1 $OUT/n$2/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$2 $1 /" ); }
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
charades() { # nodes nodelist rep
  local N=$1 nl=$2 rep=$3 b steps
  steps="batch4 batch16 batch64 wavev16 waveb4 b2500 ctl_direct ctl_direct_b2500 ctl_pp_b2500 wps_b2500"
  [ $((rep % 2)) = 0 ] && steps=$(rev "$steps")
  for st in $steps; do
    case $st in
      batch*)           b=${st#batch}; cs s1_direct_batch${b}_r$rep $N $nl off vlsi:b19:1:1 w:2500 500 128 "--batch=$b" ;;
      wavev16)          cs s1_direct_wavev16_r$rep $N $nl off vlsi:b19:1:1 w:2500 500 128 "--gvt-wave-events=16" ;;
      waveb4)           cs s1_direct_waveb4_r$rep $N $nl off vlsi:b19:1:1 w:2500 500 128 "--wave-batch=4" ;;
      b2500)            cs s1_direct_b2500_r$rep $N $nl off vlsi:b19:1:1 "$([ $((rep % 2)) = 1 ] && echo 'w:2500 w:5000' || echo 'w:5000 w:2500')" 2500 128 ;;
      ctl_direct)       cs s1_direct_ctl_r$rep $N $nl off vlsi:b19:1:1 mb:0 500 128 ;;
      ctl_direct_b2500) cs s1_direct_ctl_b2500_r$rep $N $nl off vlsi:b19:1:1 mb:0 2500 128 ;;
      ctl_pp_b2500)     cs s1_pp2048_ctl_b2500_r$rep $N $nl pp:2048 vlsi:b19:1:1 mb:0 2500 128 ;;
      wps_b2500)        cs s1_wps512_b2500_r$rep $N $nl wps:512 vlsi:b19:1:1 w:2500 2500 128 ;;
    esac
  done; }
traces() { # nodes nodelist
  cs trace_b500 $1 $2 off vlsi:b19:1:1 w:2500 500 128 "--gvt-trace=1"
  cs trace_b2500 $1 $2 off vlsi:b19:1:1 w:2500 2500 128 "--gvt-trace=1"; }
stream() { # nodes nodelist
  local N=$1 nl=$2
  charades $N $nl 1; log "N $N REP 1 DONE"
  traces $N $nl; log "N $N TRACES DONE"
  charades $N $nl 2; log "N $N REP 2 DONE"; }
stream 4 $(join ${NL[@]:0:4}) > $OUT/stream_n4.log 2>&1 &
stream 1 ${NL[4]} > $OUT/stream_n1.log 2>&1 &
wait
grep -h -E ' (fail|stall) ' $OUT/stream_n*.log | head -20
ls $OUT/n*/trace_*/ctl_sweep/gvt_trace.csv 2>/dev/null
log "VDIAG196 DONE"
