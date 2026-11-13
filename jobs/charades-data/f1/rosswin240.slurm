#!/bin/bash -l
#SBATCH -J rosswin240
#SBATCH -t 01:30:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/rosswin240_%j.out
# Job RW (charades RESULTS.md section 240): ROSS's optimism window
# (--max-opt-lookahead) on F1's eight Gaussian PHOLD workloads, never tried on
# PHOLD. ROSS optimistic, batch 16 / GVT interval 64 (A0's best, section 141),
# without a window and over a window grid (lookahead 100: 250 / 500 / 1,000 /
# 2,000 / 4,000; lookahead 10: 50 / 100 / 200 / 400 / 800); 1 and 4 nodes side
# by side, A0's run length (end time 512,000; lookahead 10: 128,000), 1 rep.
# At the end it writes ROSS's best window per workload at 4 nodes (0 if no
# window beats none) to $W/charades-runs/f1_240/ross_windows.txt, which F1's
# jobs (scale240.slurm) read when their ROSS arms run.
# Submit: sbatch -p skx-dev -N 5 -n 240 -x c455-081 rosswin240.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/f1_240/rosswin_j${SLURM_JOB_ID:-dry}; mkdir -p $OUT
RWF=$W/charades-runs/f1_240/ross_windows.txt
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 python3 >/dev/null 2>&1
RB=$W/ROSS/build/models/phold-gauss/phold-gauss
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}; ROSS $(git -C $W/ROSS log --oneline -1 | cut -c1-30)"
[ -x $RB ] || { log "missing $RB"; exit 1; }
strings $RB | grep -q max-opt-lookahead || { log "$RB lacks --max-opt-lookahead"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }
[ ${#NL[@]} -ge 5 ] || { log "need 5 nodes"; exit 1; }

spec() { # workload -> SIG REM LA MEAN END GRID
  LA=100; MEAN=1000; REM=0; END=512000; GRID="250 500 1000 2000 4000"
  case $1 in
    g100) SIG=100 ;; g500) SIG=500 ;; g1000) SIG=1000 ;; g2000) SIG=2000 ;; g4000) SIG=4000 ;;
    uni) SIG=0; REM=1.0 ;;
    l10g500)  SIG=500;  LA=10; MEAN=200; END=128000; GRID="50 100 200 400 800" ;;
    l10g2000) SIG=2000; LA=10; MEAN=200; END=128000; GRID="50 100 200 400 800" ;;
  esac; }
ross() { # tag nodes nodelist max_opt_lookahead (0 = none)
  local n=$(($2 * 46)) f=$OUT/n$2/$1.out mo=""; mkdir -p $OUT/n$2
  [ $4 != 0 ] && mo="--max-opt-lookahead=$4"
  ( module load mvapich/3.0 >/dev/null 2>&1
    unset FI_PROVIDER FI_PROVIDER_PATH LCI_ATTR_BACKEND LCI_ATTR_OFI_PROVIDER_NAME LCI_ATTR_PACKET_SIZE PSM2_MULTI_EP
    timeout -s TERM 360 srun --mpi=pmi2 --kill-on-bad-exit=1 -J ross_$1 -w $3 -N $2 -n $n --ntasks-per-node=46 \
      $RB --synch=3 --read-buffer=1 --start-events=15 --sigma=$SIG --remote=$REM \
      --extramem=800000 --num-lps=$((n * 128)) --lookahead=$LA --mean=$MEAN --end=$END \
      --batch=16 --gvt-interval=64 $mo > $f 2>&1
    local rc=$?
    echo "label=$1 wl=$WL nodes=$2 window=$4 rc=$rc committed=$(awk '/Net Events Processed/{print $NF; exit}' $f) M_ev_s=$(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' $f) efficiency=$(awk '/Efficiency/{print $(NF-1); exit}' $f) running_s=$(awk '/Running Time/{print $(NF-1); exit}' $f)" \
      | tee -a $OUT/results.txt | sed "s/^/n$2 /" )
}
series() { # nodes nodelist
  local N=$1 nl=$2 w
  for WL in g100 g500 g1000 g2000 g4000 uni l10g500 l10g2000; do
    spec $WL
    for w in 0 $GRID; do ross ${WL}_w${w} $N $nl $w; done
    log "N $N $WL DONE"
  done; }
series 1 ${NL[0]} > $OUT/stream_n1.log 2>&1 &
series 4 $(join ${NL[@]:1:4}) > $OUT/stream_n4.log 2>&1 &
wait
log "RUNS DONE"
# ROSS's best window per workload at 4 nodes (0: no window beats none)
python3 - $OUT/results.txt > $RWF.new <<'EOF'
import sys
best = {}
for line in open(sys.argv[1]):
    kv = dict(t.split('=', 1) for t in line.split() if '=' in t)
    if kv.get('nodes') != '4' or not kv.get('M_ev_s'):
        continue
    r = float(kv['M_ev_s'])
    if kv['wl'] not in best or r > best[kv['wl']][1]:
        best[kv['wl']] = (kv['window'], r)
for wl, (w, r) in sorted(best.items()):
    print(wl, w, f'{r:.2f}')
EOF
mv $RWF.new $RWF; cat $RWF
log "ROSSWIN240 DONE"
