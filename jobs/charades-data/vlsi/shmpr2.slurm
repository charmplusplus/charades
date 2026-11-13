#!/bin/bash -l
#SBATCH -J shmpr2
#SBATCH -t 01:15:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/shmpr2_%j.out
# Reconverse PR #319 after review (RESULTS.md section 220): the branch at
# 4b1740a against the branch before review (4159d3e), on Stampede3, 2 nodes.
# Charm++ recharm 3d409d45d: charm-shm-pr (Reconverse 4159d3e, built by job
# 3681031) and charm-shm-pr2 (Reconverse 4b1740a, built here); LCI 1287c59c.
# Charades: charades-shm-pr (ae0dbd3) and charades-shm-pr2 (f5e8179, which
# adds the pool-full and bytes-used statistics; same engine code).
#   1. builds: charm-shm-pr2 on node 0, the standalone Reconverse branch on
#      node 1, then charades-shm-pr2
#   2. Reconverse's IPC tests on node 1 (srun, 30 s cap; ipc-onenode left out:
#      it hangs on main too, section 219)
#   3. node 0, +ipc, 2 x 23: VLSI b19 (as in section 219), 2 reps each of
#      pr, pr2 (default segment, 11.5 MiB) and pr2 with ++ipcpoolsize 8 MiB;
#      PHOLD uniform and sigma 100, pr and pr2, 2 reps
#   4. node 0, +ipc, 4 x 11 (pemap one socket per process): VLSI b19 with pr2
#      at its default (16.5 MiB) and at 8 MiB, 2 reps
# Submit: sbatch -p skx-dev -N 2 -n 96 -x c455-081 shmpr2.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/shmpr2/j${SLURM_JOB_ID:-dry}; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
LCI=$W/lci-1287c59c; RC=$W/reconverse-shmpr
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}"
[ "$(git -C $LCI rev-parse --short=8 HEAD)" = 1287c59c ] || { log "LCI tree not at 1287c59c"; exit 1; }
[ "$(git -C $W/charm-shm-pr/contrib/reconverse rev-parse --short=7 HEAD)" = 4159d3e ] || { log "charm-shm-pr reconverse not at 4159d3e"; exit 1; }
[ "$(git -C $W/charm-shm-pr2/contrib/reconverse rev-parse --short=7 HEAD)" = 4b1740a ] || { log "charm-shm-pr2 reconverse not at 4b1740a"; exit 1; }
[ "$(git -C $RC rev-parse --short=7 HEAD)" = 4b1740a ] || { log "standalone reconverse not at 4b1740a"; exit 1; }
[ "$(git -C $W/charades-shm-pr2 rev-parse --short=7 HEAD)" = f5e8179 ] || { log "charades-shm-pr2 not at f5e8179"; exit 1; }
for k in pr pr2; do
  grep -q "CHARM_DIR = $W/charm-shm-$k/" $W/charades-shm-$k/src/config.mk || { log "charades-shm-$k does not point at charm-shm-$k"; exit 1; }
  grep -q "CHARADES_SRC *= *$W/charades-shm-$k/src" $W/charades-shm-$k/src/config.mk || { log "charades-shm-$k config.mk points elsewhere"; exit 1; }
done
[ -x $W/charades-shm-pr/models/vlsi/vlsi ] || { log "charades-shm-pr is not built"; exit 1; }
[ -x $W/charades-runs/srun1.sh ] || { log "missing srun1.sh"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }

# ---- 1. builds
( cd $W/charm-shm-pr2 && ./build charm++ reconverse-linux-x86_64 --disable-fortran -j46 \
    --with-cmake-args="-DFETCHCONTENT_SOURCE_DIR_LCI=$LCI" > $OUT/build_charm_pr2.log 2>&1
  echo "exit $?" >> $OUT/build_charm_pr2.log ) &
ssh -o StrictHostKeyChecking=no ${NL[1]} "module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 cmake >/dev/null 2>&1;
  cmake -S $RC -B $RC/build >/dev/null && cmake --build $RC/build -j46" > $OUT/build_rc.log 2>&1; echo "exit $?" >> $OUT/build_rc.log &
wait
for f in build_charm_pr2 build_rc; do log "$f: $(tail -1 $OUT/$f.log)"; done
grep -q "exit 0" $OUT/build_charm_pr2.log || { log "Charm++ build FAILED"; exit 1; }
so=$(ls $W/charm-shm-pr2/reconverse-linux-x86_64/lib/libreconverse.* 2>/dev/null | head -1)
log "charm-shm-pr2: $so; CmiIpcPoolFullSends: $( (nm -D $so 2>/dev/null; nm $so 2>/dev/null) | grep -c CmiIpcPoolFullSends)"
( cd $W/charades-shm-pr2/src && { make -j8 > $OUT/build_charades_pr2.log 2>&1 || make -j1 >> $OUT/build_charades_pr2.log 2>&1; } || exit 1
  for m in vlsi phold/simple; do
    ( cd ../models/$m && { make -j8 >> $OUT/build_charades_pr2.log 2>&1 || make -j1 >> $OUT/build_charades_pr2.log 2>&1; } ) || exit 1
  done; echo "exit 0" >> $OUT/build_charades_pr2.log )
tail -1 $OUT/build_charades_pr2.log | grep -q "exit 0" || { log "Charades pr2 build FAILED"; exit 1; }
ldd $W/charades-shm-pr2/models/vlsi/vlsi | grep -q "charm-shm-pr2/" || { log "charades-shm-pr2 vlsi does not link charm-shm-pr2"; exit 1; }
log "BUILDS DONE"

# ---- 2. Reconverse's IPC tests on node 1, in the background
export SHMPR_NODE=${NL[1]}
( source $W/charades-shm-pr2/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $RC/build && ctest -R "ipc" -E "^ipc-onenode$" -j1 --timeout 30 > $OUT/ctest_ipc.log 2>&1; echo "exit $?" >> $OUT/ctest_ipc.log ) &
CTEST_PID=$!

export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536 HFI_NO_CPUAFFINITY=1
export CAP=300 VLSI_NETLISTS=$W/I99T/i99t
VARGS="+mempool_remote_free --blocked-time=1 --commit-digest=1 --fossil-lazy=1 --batch=32 +ipc"
PM2="+lci_ndevices 23 +pemap 2-46:2,3-47:2"
PM4="+lci_ndevices 11 +pemap 2-44:2,3-45:2"
LB="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 +ipc"
vl() { # tag tree-kind procs:PEs:cores pemap-args extra
  local tag=$1 k=$2 ppn pepp cpt; IFS=: read -r ppn pepp cpt <<< "$3"
  ( export TREE=charades-shm-$k NODES=1 PPN=$ppn PEPP=$pepp CPT=$cpt AGG=off WORKLOADS=vlsi:b19:1:1 ARMS=w:5000 END=12500000 \
      BUCKETS=2500 LPC=128 LPS_PER_PE=128 EXTRA_ARGS="$4 $VARGS ${5:-}" SRUN_ARGS="-w ${NL[0]}"
    RUNS=$OUT/$tag $W/charades-shm-$k/scripts/stampede3/ctl_sweep.sh 1 $OUT/$tag.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/$tag /" )
  rm -f $OUT/$tag/ctl_sweep/logs/*.digest.csv; }
ph() { # tag tree-kind agg workload
  ( export TREE=charades-shm-$2 NODES=1 PPN=2 PEPP=23 CPT=24 AGG=$3 WORKLOADS="$4" ARMS=w:300 END=2048000 BUCKETS=8 \
      LPS_PER_PE=128 LPC=16 EXTRA_ARGS="$LB" SRUN_ARGS="-w ${NL[0]}"
    RUNS=$OUT/$1 $W/charades-shm-$2/scripts/stampede3/ctl_sweep.sh 1 $OUT/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }

# ---- 3. 2 x 23
for rep in 1 2; do
  for k in $([ $rep = 1 ] && echo "pr pr2 pr2s" || echo "pr2s pr2 pr"); do
    case $k in
      pr2s) vl vlsi2_pr2s_r$rep pr2 2:23:24 "$PM2" "++ipcpoolsize 8388608" ;;
      *)    vl vlsi2_${k}_r$rep $k 2:23:24 "$PM2" ;;
    esac
  done
  for k in $([ $rep = 1 ] && echo "pr pr2" || echo "pr2 pr"); do
    ph uni_${k}_r$rep $k wps:512 steady:100:1000:1.0
    ph g100_${k}_r$rep $k pp:2048 gauss:100:1000:100
  done
  log "2x23 REP $rep DONE"
done

# ---- 4. 4 x 11
for rep in 1 2; do
  for k in $([ $rep = 1 ] && echo "pr2 pr2s" || echo "pr2s pr2"); do
    case $k in
      pr2s) vl vlsi4_pr2s_r$rep pr2 4:11:12 "$PM4" "++ipcpoolsize 8388608" ;;
      *)    vl vlsi4_pr2_r$rep pr2 4:11:12 "$PM4" ;;
    esac
  done
  log "4x11 REP $rep DONE"
done

wait $CTEST_PID
log "ctest: $(grep -E 'tests passed|exit' $OUT/ctest_ipc.log | tr '\n' ' ')"
grep -E "\*\*\*Failed|\*\*\*Timeout|Failed  |Exception" $OUT/ctest_ipc.log | head -10
grep -h "Converse> +ipc: PE" $OUT/*/ctl_sweep/logs/*.log 2>/dev/null | sort | uniq -c | head
log "SHMPR2 DONE"
