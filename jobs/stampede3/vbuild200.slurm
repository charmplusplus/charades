#!/bin/bash -l
#SBATCH -J vbuild200
#SBATCH -t 00:50:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/vbuild200_%j.out
# Builds and checks for VLSI job V4 (charades RESULTS.md section 200), on skx
# compute nodes: LCI compiles with -march=native and the login nodes are
# Sapphire Rapids.
#   node 0: Charm++ with --enable-shmem in $WORK/charm-pads-shmem (charm-pads-exp's
#     source: Charm++ 9d6a55780, Reconverse pads-dest-device 22871c6; the same
#     patched LCI source through FETCHCONTENT_SOURCE_DIR_LCI), then Charades
#     main in $WORK/charades-shmem built against it
#   node 1 (ssh, in parallel): Devastator's vlsi with one process per node
#     (ofi-psm2 p1w46, p4w46)
# Then checks on nodes 0-1:
#   the VLSI change tier (gate configs) with the shmem tree on 1 node (2 x 2 and
#     4 x 2: the processes share the node, so the pool carries their messages)
#     and on 2 nodes (default shapes); with charades-vlsi and Reconverse's +ipc
#     on 1 node (2 x 2, 4 x 2)
#   one b19 run each at 1 node, 2 x 23, W 2,500: charades-vlsi, shmem tree,
#     charades-vlsi +ipc (rate and shared-memory message count; a preview only)
# Submit: sbatch -p skx-dev -N 2 -n 96 -x c455-081 vbuild200.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/vbuild200/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
NL=($(scontrol show hostnames $SLURM_JOB_NODELIST))
CE=$W/charm-pads-exp; CS=$W/charm-pads-shmem; TS=$W/charades-shmem; TV=$W/charades-vlsi; D=$W/devastator
log "job $SLURM_JOB_ID; nodes ${NL[*]}; on $(hostname -s) ($(lscpu | grep 'Model name' | sed 's/.*: *//'))"
[ -d $CS/src ] && [ ! -e $CS/reconverse-linux-x86_64 ] || { log "$CS missing, or already built"; exit 1; }
[ ! -e $TS ] || { log "$TS already exists"; exit 1; }

# ---- node 1: Devastator, one process per node (background)
ssh -o StrictHostKeyChecking=no ${NL[1]} "WORK=$W CXX_PPFLAGS=-I$TV/models/vlsi BENCHES=vlsi LAYOUTS='1:46 4:46' STOCK=0 PAR=0 bash -l $D/build_stampede3.sh ofi-psm2" > $OUT/deva_build.txt 2>&1 &
dpid=$!
log "Devastator build started on ${NL[1]}"

# ---- node 0: Charm++ with --enable-shmem
cd $CS
./build charm++ reconverse-linux-x86_64 --with-production --enable-shmem -j46 \
  "--with-cmake-args=-DFETCHCONTENT_SOURCE_DIR_LCI=$CE/reconverse-linux-x86_64/_deps/lci-src" > $OUT/charm_build.txt 2>&1
rc=$?
tail -5 $OUT/charm_build.txt
grep -n "CMK_USE_SHMEM" $CS/reconverse-linux-x86_64/include/conv-autoconfig.h
grep -E "^FETCHCONTENT_SOURCE_DIR_LCI|^CMK_USE_SHMEM" $CS/reconverse-linux-x86_64/CMakeCache.txt
[ $rc = 0 ] && grep -q "CMK_USE_SHMEM 1" $CS/reconverse-linux-x86_64/include/conv-autoconfig.h || { log "CHARM++ SHMEM BUILD FAILED (rc $rc)"; wait $dpid; exit 1; }
log "Charm++ shmem built"

# ---- Charades main against it
git clone -q $TV $TS && git -C $TS log --oneline -1
sed -e "s|/charades-vlsi/|/charades-shmem/|g" -e "s|/charm-pads-exp/|/charm-pads-shmem/|g" $TV/src/config.mk > $TS/src/config.mk
grep -E "^(CHARADES_SRC|CHARM_DIR|HTRAM_DIR)" $TS/src/config.mk
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $TS/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $TS/src && { make -j46 > $OUT/charades_src.txt 2>&1 || make -j46 >> $OUT/charades_src.txt 2>&1; } && \
  cd $TS/models/vlsi && make > $OUT/charades_vlsi.txt 2>&1 )
rc=$?
ldd $TS/models/vlsi/vlsi | grep -E "reconverse|charm"
strings $TS/models/vlsi/vlsi | grep -q "Shared-Memory Messages Received" && [ $rc = 0 ] || { log "CHARADES SHMEM BUILD FAILED (rc $rc)"; tail -20 $OUT/charades_src.txt $OUT/charades_vlsi.txt; wait $dpid; exit 1; }
log "Charades shmem built"

wait $dpid
tail -4 $OUT/deva_build.txt
ls -la $D/bin/ofi-psm2/vlsi-p1w46 $D/bin/ofi-psm2/vlsi-p4w46 2>&1
log "BUILDS DONE"

# ---- checks
G="agg_ctl_measured_fast_bucket_pp agg_deadline_bucket_pp agg_deadline_bucket_wps bucket_window ctl_measured_bucket"
gate() { # tag tree runargs test.py-args...
  local tag=$1 tree=$2 ra=$3; shift 3
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $tree/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $tree/tests; export CHARADES_RUN_ARGS="$ra"
    python3 test.py --tier change --no-build --launcher srun --model VLSI "$@" $G > $OUT/gate_$tag.txt 2>&1 )
  echo "gate $tag: $(grep -E '^(Passed|Failed|Timed out)' $OUT/gate_$tag.txt | tr -s ' ' | paste -sd' ')"; }
gate shmem_1node $TS "+mempool_remote_free" --nodes 1 --launch 2x2 --launch 4x2
gate shmem_2nodes $TS "+mempool_remote_free" --nodes 2
gate ipc_1node $TV "+mempool_remote_free +ipc" --nodes 1 --launch 2x2 --launch 4x2

export CAP=300 VLSI_NETLISTS=$W/I99T/i99t
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1 --commit-digest=1"
smoke() { # tag tree [extra]
  ( export TREE=$(basename $2) NODES=1 PPN=2 PEPP=23 CPT=24 AGG=off WORKLOADS=vlsi:b19:1:1 ARMS=w:2500 END=12500000 \
      BUCKETS=2500 LPC=128 LPS_PER_PE=128 EXTRA_ARGS="$L ${3:-}" SRUN_ARGS="-w ${NL[0]}"
    RUNS=$OUT/smoke_$1 $2/scripts/stampede3/ctl_sweep.sh 1 $OUT/smoke_$1.csv 2>/dev/null | grep -E " (ok|fail|stall) " )
  local f=$(ls $OUT/smoke_$1/ctl_sweep/logs/*.out 2>/dev/null | head -1)
  echo "smoke $1: $(awk -F, 'NR==2 {printf "%s committed %s in %s s = %.2f M ev/s, digest %s", $11, $14, $13, $14/$13/1e6, $NF}' $OUT/smoke_$1.csv); $(grep -E 'Shared-Memory Messages Received' $f | tr -s ' \t' ' ')"; }
smoke ref $TV
smoke shmem $TS
smoke ipc $TV "+ipc"
rm -f $OUT/smoke_*/ctl_sweep/logs/*.digest.csv
log "VBUILD200 DONE"
