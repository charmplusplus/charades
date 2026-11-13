#!/bin/bash
# Three engines at 4 nodes, paper grade (charades RESULTS.md, design
# 2026-10-23). Charades charades-main (eef0778), Devastator ofi-psm2 8 x 23 with
# --rng=clcg4, ROSS optimistic --read-buffer=1. Full nodes, 23,552 LPs,
# about 1.3e9 committed events per run. Run on the idev master node.
# Usage: cmp4.sh [reps] [first rep]   (TUNE=0 skips the ROSS tuning sweep and
#   reads the chosen setting from $OUT/ross_best.txt)
# Within a rep: Charades htram, Devastator fixed W, ROSS, Charades direct,
# Devastator adaptive (slowest, least needed, last). cmp4_rest.sh: the copy for
# reps after 1, with the adaptive window only where it finishes.
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/cmp4; mkdir -p $OUT/ross
REPS=${1:-3} FIRST=${2:-1}
BLOCKS=${BLOCKS:-"pp deva ross off adapt"}   # which blocks of a rep to run
has() { [[ " $BLOCKS " == *" $1 "* ]]; }
# ssh shell on the idev node: take the job's SLURM_* variables (ROSS's srun needs them)
if [ -z "${SLURM_JOB_ID:-}" ]; then
  f=$(ls -t /tmp/idev_${USER}_bash_env.* 2>/dev/null | head -1)
  [ -n "$f" ] && source <(grep -E "^(export +|declare -x +)?SLURM_" "$f")
fi
log() { echo "[$(date +%T)] $*"; }
S=$W/charades-main/scripts/stampede3/ctl_sweep.sh
D=$W/devastator; DB=$D/bin/ofi-psm2/phold-gauss-p8w23
export TREE=charades-main NODES=4 LPS_PER_PE=128 LPC=16 CAP=150 PPN=2 PEPP=23 CPT=24
export EXTRA_ARGS="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
E_HI=4096000 E_LO=768000 E_PH=2048000
HI="gauss:100:1000:100 gauss:100:1000:500 gauss:100:1000:1000 gauss:100:1000:2000 gauss:100:1000:4000 steady:100:1000:1.0"
LO="gauss:10:200:500 gauss:10:200:2000 steady:10:200:1.0"
PH="phases:10:200:100:1000:0.5:32000 phases:10:200:100:1000:1.0:32000"

cs() { # tag agg end workloads arms
  ( export AGG=$2 END=$3 WORKLOADS="$4" ARMS="$5"
    RUNS=$OUT/$1 $S 1 $OUT/$1_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
dv() { # tag end lookahead mean sigma window extra-args...
  local tag=$1 end=$2 la=$3 mean=$4 sig=$5 w=$6; shift 6
  ( [ $w = adaptive ] && unset WINDOW || export WINDOW=$w
    export RUNS=$OUT/deva LPS_PER_RANK=128 START=15 LOOKAHEAD=$la MEAN=$mean SIGMA=$sig END=$end CAP=90 AFFINITY=0
    LABEL=${tag}_s${sig}_w${w}_r$rep bash $D/run_phold.sh $DB 4 --rng=clcg4 "$@" | head -1 ); }
# ROSS in a subshell with its own MPI and none of the LCI variables
ross() { # label ranks_per_node lps end lookahead mean sigma remote batch gvt
  local f=$OUT/ross/$1.out n=$((4 * $2))
  ( module load mvapich/3.0 >/dev/null 2>&1
    unset FI_PROVIDER FI_PROVIDER_PATH LCI_ATTR_BACKEND LCI_ATTR_OFI_PROVIDER_NAME LCI_ATTR_PACKET_SIZE PSM2_MULTI_EP
    timeout -s TERM 300 srun --mpi=pmi2 --kill-on-bad-exit=1 -J ross_$1 -N 4 -n $n --ntasks-per-node=$2 \
      $W/ROSS/build/models/phold-gauss/phold-gauss --synch=3 --read-buffer=1 --start-events=15 \
      --sigma=$7 --remote=$8 --batch=$9 --gvt-interval=${10} --extramem=800000 \
      --num-lps=$3 --lookahead=$5 --mean=$6 --end=$4 > $f 2>&1
    echo "$1 rc=$? committed $(awk '/Net Events Processed/{print $NF; exit}' $f) M_ev_s $(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' $f) eff $(awk '/Efficiency/{print $(NF-1); exit}' $f) time $(awk '/Running Time/{print $(NF-1); exit}' $f)" | tee -a $OUT/ross/results.txt )
}

# ROSS tuning (once): sigma 2,000, lookahead 100, end 512,000, 46 ranks per node
if [ "${TUNE:-1}" = 1 ]; then
  rep=0
  for b in 4 16 64; do for g in 16 64 256; do
    ross tune_b${b}_g$g 46 23552 512000 100 1000 2000 0 $b $g
  done; done
  best=$(grep "^tune_b" $OUT/ross/results.txt | awk '$2=="rc=0" {print $6, $1}' | sort -g | tail -1 | awk '{print $2}')
  [ -n "$best" ] || { log "ROSS tuning: no run succeeded"; best=tune_b16_g16; }
  echo $best > $OUT/ross_best.txt
  RB=$(echo $best | sed 's/tune_b\([0-9]*\)_g.*/\1/') RG=${best##*_g}
  ross tune48_b${RB}_g$RG 48 24576 512000 100 1000 2000 0 $RB $RG
  log "ROSS tuned: batch $RB, gvt-interval $RG"
fi
best=$(cat $OUT/ross_best.txt); RB=$(echo $best | sed 's/tune_b\([0-9]*\)_g.*/\1/') RG=${best##*_g}

for rep in $(seq $FIRST $REPS); do
  if has pp; then
  log "rep $rep: Charades htram"
  cs hi_pp pp:512 $E_HI "$HI" "q:0.001 w:200 w:250 w:300"
  cs lo_pp pp:512 $E_LO "$LO" "q:0.001 w:25 w:50 w:100"
  cs ph_pp pp:512 $E_PH "$PH" "q:0.001 w:50 w:100 w:250"
  fi
  if has deva; then
  log "rep $rep: Devastator fixed W"
  for w in 250 500 1000 2000; do
    for sig in 100 500 1000 2000 4000; do dv hi $E_HI 100 1000 $sig $w; done
    dv hi $E_HI 100 1000 0 $w --remote=1.0
  done
  for w in 100 200 400; do
    for sig in 500 2000; do dv lo $E_LO 10 200 $sig $w; done
    dv lo $E_LO 10 200 0 $w --remote=1.0
  done
  for rem in 0.5 1.0; do for w in 100 250 500; do
    dv ph_r$rem $E_PH 10 200 0 $w --remote=$rem --phase-length=32000 --alt-lookahead=100 --alt-mean=1000
  done; done
  fi
  if has ross; then
  log "rep $rep: ROSS (batch $RB, gvt-interval $RG)"
  for sig in 100 500 1000 2000 4000; do ross hi_s${sig}_r$rep 46 23552 $E_HI 100 1000 $sig 0 $RB $RG; done
  ross hi_s0_r$rep 46 23552 $E_HI 100 1000 0 1.0 $RB $RG
  for sig in 500 2000; do ross lo_s${sig}_r$rep 46 23552 $E_LO 10 200 $sig 0 $RB $RG; done
  ross lo_s0_r$rep 46 23552 $E_LO 10 200 0 1.0 $RB $RG
  fi
  if has off; then
  log "rep $rep: Charades direct"
  cs hi_off off $E_HI "gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0" "q:0.001 w:250 w:500"
  cs lo_off off $E_LO "steady:10:200:1.0" "q:0.001 w:50 w:100"
  fi
  if has adapt; then
  log "rep $rep: Devastator adaptive (only where it finishes; the rest stalled in rep 1)"
  for sig in 100 500; do dv hi $E_HI 100 1000 $sig adaptive; done
  dv lo $E_LO 10 200 500 adaptive
  fi
  log "REP $rep DONE"
done
log "CMP4 DONE"
