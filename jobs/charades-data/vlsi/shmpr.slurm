#!/bin/bash -l
#SBATCH -J shmpr
#SBATCH -t 01:15:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/shmpr_%j.out
# Reconverse PR branch shmem-pool-queues (the shared-memory pool rewrite) on
# Stampede3, 2 nodes. Charm++ recharm 3d409d45d built twice, identical but
# for contrib/reconverse: main (5471ba0, "base") and the PR branch ("pr");
# both with LCI 1287c59c (upstream's pin, native psm2) from a prefetched tree.
#   1. builds: both Charm++ trees on node 0; the standalone Reconverse branch
#      with its tests on node 1; then Charades (round 3's code, ae0dbd3)
#      against each Charm++ tree
#   2. Reconverse's ctest on node 1 (every process of a test on one node)
#   3. the +ipc one-process start-up hang (RESULTS.md section 211): Simple
#      PHOLD at 1 x 4 with +ipc, base and pr, cap 60 s
#   4. Charades' change tier with +ipc at 2 x 2 and 4 x 2, pr then base
#   5. 1 node, 2 x 23 over +ipc, base against pr: VLSI b19 (lazy fossils,
#      batch 32, W 5,000, buckets of 2,500) 3 reps; Simple PHOLD sigma 100 (PP
#      2,048) and uniform (WPs 512) at W 300, 2 reps; pr over LCI (no +ipc)
#      for reference
#   6. 2 nodes, 2 x 23 over +ipc: VLSI b19 x 2, base and pr, 2 reps
# Submit: sbatch -p skx-dev -N 2 -n 96 -x c455-081 shmpr.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/shmpr/j${SLURM_JOB_ID:-dry}; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
LCI=$W/lci-1287c59c; RC=$W/reconverse-shmpr
NL=($(scontrol show hostnames ${SLURM_JOB_NODELIST:-}))
join() { local IFS=,; echo "$*"; }
log "job ${SLURM_JOB_ID:-dry}; nodes ${NL[*]:-none}"
[ "$(git -C $LCI rev-parse --short=8 HEAD)" = 1287c59c ] || { log "LCI tree not at 1287c59c"; exit 1; }
[ "$(git -C $W/charm-shm-base/contrib/reconverse rev-parse --short=7 HEAD)" = 5471ba0 ] || { log "base reconverse not at 5471ba0"; exit 1; }
PRC=$(git -C $RC rev-parse --short=7 HEAD)
[ "$(git -C $W/charm-shm-pr/contrib/reconverse rev-parse --short=7 HEAD)" = $PRC ] || { log "pr trees at different commits"; exit 1; }
for k in base pr; do
  log "charm-shm-$k: charm $(git -C $W/charm-shm-$k log --oneline -1 | cut -c1-40); reconverse $(git -C $W/charm-shm-$k/contrib/reconverse log --oneline -1 | cut -c1-60)"
  grep -q "CHARM_DIR = $W/charm-shm-$k/" $W/charades-shm-$k/src/config.mk || { log "charades-shm-$k does not point at charm-shm-$k"; exit 1; }
  grep -q "CHARADES_SRC *= *$W/charades-shm-$k/src" $W/charades-shm-$k/src/config.mk || { log "charades-shm-$k config.mk points elsewhere"; exit 1; }
done
[ -x $W/charades-runs/srun1.sh ] || { log "missing srun1.sh"; exit 1; }
[ -z "${SLURM_JOB_ID:-}" ] && { log "dry run: checks passed"; exit 0; }

# ---- 1. builds
for k in base pr; do
  ( cd $W/charm-shm-$k && ./build charm++ reconverse-linux-x86_64 --disable-fortran -j23 \
      --with-cmake-args="-DFETCHCONTENT_SOURCE_DIR_LCI=$LCI" > $OUT/build_charm_$k.log 2>&1
    echo "exit $?" >> $OUT/build_charm_$k.log ) &
done
ssh -o StrictHostKeyChecking=no ${NL[1]} "module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 cmake >/dev/null 2>&1;
  cmake -S $RC -B $RC/build -DCMAKE_BUILD_TYPE=Release -DRECONVERSE_BUILD_TESTS=ON -DRECONVERSE_AUTOFETCH_LCI2=ON \
    -DFETCHCONTENT_SOURCE_DIR_LCI=$LCI -DRECONVERSE_TEST_LAUNCHER=$W/charades-runs/srun1.sh && cmake --build $RC/build -j46" \
  > $OUT/build_rc.log 2>&1; echo "exit $?" >> $OUT/build_rc.log &
wait
for f in build_charm_base build_charm_pr build_rc; do log "$f: $(tail -1 $OUT/$f.log)"; done
grep -q "exit 0" $OUT/build_charm_base.log && grep -q "exit 0" $OUT/build_charm_pr.log || { log "Charm++ build FAILED"; exit 1; }
for k in base pr; do
  so=$(ls $W/charm-shm-$k/reconverse-linux-x86_64/lib/libreconverse.* 2>/dev/null | head -1)
  log "charm-shm-$k: $so; CmiDeliverIpcInbox: $(nm -D $so 2>/dev/null | grep -c CmiDeliverIpcInbox || nm $so | grep -c CmiDeliverIpcInbox)"
  grep -E "^FETCHCONTENT_SOURCE_DIR_LCI" $W/charm-shm-$k/reconverse-linux-x86_64/CMakeCache.txt
done
for k in base pr; do
  ( cd $W/charades-shm-$k/src && { make -j8 > $OUT/build_charades_$k.log 2>&1 || make -j1 >> $OUT/build_charades_$k.log 2>&1; } || exit 1
    for m in vlsi phold/simple traffic dragonfly; do
      ( cd ../models/$m && { make -j8 >> $OUT/build_charades_$k.log 2>&1 || make -j1 >> $OUT/build_charades_$k.log 2>&1; } ) || exit 1
    done; echo "exit 0" >> $OUT/build_charades_$k.log ) &
done
wait
for k in base pr; do
  tail -1 $OUT/build_charades_$k.log | grep -q "exit 0" || { log "Charades $k build FAILED"; exit 1; }
  ldd $W/charades-shm-$k/models/vlsi/vlsi | grep -q "charm-shm-$k/" || { log "charades-shm-$k vlsi does not link charm-shm-$k"; exit 1; }
done
log "BUILDS DONE"

# ---- 2. Reconverse's tests on node 1, in the background
export SHMPR_NODE=${NL[1]}
( source $W/charades-shm-pr/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $RC/build && ctest -j1 --timeout 180 > $OUT/ctest.log 2>&1; echo "exit $?" >> $OUT/ctest.log ) &
CTEST_PID=$!

export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536
export CAP=300 VLSI_NETLISTS=$W/I99T/i99t
LV="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --commit-digest=1 --fossil-lazy=1 --batch=32"
LB="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1"
cs() { # tag tree-kind nodes nodelist procs:PEs:cores extra
  local tag=$1 k=$2 N=$3 nl=$4 lay=$5 extra=${6:-} ppn pepp cpt
  IFS=: read -r ppn pepp cpt <<< "$lay"
  ( export TREE=charades-shm-$k NODES=$N PPN=$ppn PEPP=$pepp CPT=$cpt AGG=off WORKLOADS=vlsi:b19:1:1 ARMS=w:5000 END=12500000 \
      BUCKETS=2500 LPC=128 LPS_PER_PE=128 EXTRA_ARGS="$LV $extra" SRUN_ARGS="-w $nl"
    RUNS=$OUT/$tag $W/charades-shm-$k/scripts/stampede3/ctl_sweep.sh 1 $OUT/$tag.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/$tag /" )
  rm -f $OUT/$tag/ctl_sweep/logs/*.digest.csv; }
csb() { # tag tree-kind nodelist procs:PEs:cores agg workload extra
  local ppn pepp cpt; IFS=: read -r ppn pepp cpt <<< "$4"
  ( export TREE=charades-shm-$2 NODES=1 PPN=$ppn PEPP=$pepp CPT=$cpt AGG=$5 WORKLOADS="$6" ARMS=w:300 END=2048000 BUCKETS=8 \
      LPS_PER_PE=128 LPC=16 EXTRA_ARGS="${LBX:-$LB} ${7:-}" SRUN_ARGS="-w $3"
    RUNS=$OUT/$1 $W/charades-shm-$2/scripts/stampede3/ctl_sweep.sh 1 $OUT/$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }

# ---- 3. the one-process +ipc start-up hang
for k in base pr; do
  # no +pemap: srun -c 4 grants 4 cores
  ( export CAP=60 LBX="+mempool_remote_free --blocked-time=1"; csb hang_$k $k ${NL[0]} 1:4:4 off steady:100:1000:0.5 "+ipc" )
done
log "HANG CHECK DONE"

# ---- 4. Charades' change tier with +ipc at 2 x 2 and 4 x 2 (node 0)
for k in pr base; do
  ( source $W/charades-shm-$k/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $W/charades-shm-$k/tests; export CHARADES_RUN_ARGS="+mempool_remote_free +ipc"
    python3 test.py --tier change --no-build --launcher srun --nodes 1 --launch 2x2 --launch 4x2 \
      --model VLSI --model "Simple PHOLD" --model Traffic --model Dragonfly \
      bucket_window bucket_pool agg_ctl_measured_fast_bucket_pp ctl_measured_bucket > $OUT/gate_$k.txt 2>&1 )
  log "gate $k: $(grep -E 'Passed|Failed|Timed out' $OUT/gate_$k.txt | tr -s ' ' | tr '\n' ' ')"
done

# ---- 5. 1 node, 2 x 23 over +ipc, base against pr
for rep in 1 2 3; do
  for k in $([ $((rep % 2)) = 1 ] && echo "base pr" || echo "pr base"); do
    cs vlsi_ipc_${k}_r$rep $k 1 ${NL[0]} 2:23:24 "+ipc"
    [ $rep -le 2 ] && csb g100_ipc_${k}_r$rep $k ${NL[0]} 2:23:24 pp:2048 gauss:100:1000:100 "+ipc"
    [ $rep -le 2 ] && csb uni_ipc_${k}_r$rep $k ${NL[0]} 2:23:24 wps:512 steady:100:1000:1.0 "+ipc"
  done
  log "1-NODE REP $rep DONE"
done
cs vlsi_lci_pr_r1 pr 1 ${NL[0]} 2:23:24

# ---- 6. 2 nodes (after the tests on node 1)
wait $CTEST_PID
log "ctest: $(grep -E 'tests passed|exit' $OUT/ctest.log | tr '\n' ' ')"
grep -E "\*\*\*Failed|\*\*\*Timeout|Failed  |Exception" $OUT/ctest.log | head -10
for rep in 1 2; do
  for k in $([ $rep = 1 ] && echo "base pr" || echo "pr base"); do
    ( export WORKLOADS=vlsi:b19:1:1; cs vlsi2n_ipc_${k}_r$rep $k 2 $(join ${NL[@]:0:2}) 2:23:24 "+ipc" )
  done
done
log "SHMPR DONE"
