#!/bin/bash -l
#SBATCH -J charades_prod
#SBATCH -p skx-dev
#SBATCH -N 4
#SBATCH --ntasks-per-node=48
#SBATCH -t 02:00:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /work2/09863/rrao/stampede3/charades-runs/prod/job_%j.out
# Production build of Charm++/Reconverse/LCI, then the three-engine reference
# points on three Charades builds, interleaved by rep:
#   charades-qd      the Debug runtime every earlier number used (-O0, error checking, tracing)
#   charades-prodrt  production runtime, Charades flags unchanged (-O3, asserts, PDES_TIMED)
#   charades-prod    production runtime + Charades -DNDEBUG, htram without PDES_TIMED
# plus Devastator at its best fixed W as a same-job anchor.
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/prod; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
fail() { log "FAILED: $*"; exit 1; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
command -v cmake >/dev/null || fail "no cmake"
log "job $SLURM_JOB_ID on $SLURM_JOB_NODELIST; gcc $(gcc -dumpfullversion)"

# 1. Charm++ on Reconverse, production
cd $W/charm-pads-prod || fail "no charm-pads-prod"
if [ ! -x reconverse-linux-x86_64/bin/charmc ]; then
  log "building charm-pads-prod (--with-production)"
  ./build charm++ reconverse-linux-x86_64 --with-production --disable-fortran -j48 > build.log 2>&1 \
    || { tail -30 build.log; fail "charm build"; }
fi
B=$W/charm-pads-prod/reconverse-linux-x86_64
log "build type: $(grep ^CMAKE_BUILD_TYPE: $B/CMakeCache.txt)"
log "reconverse: $(grep CXX_FLAGS $B/reconverse/CMakeFiles/reconverse.dir/flags.make)"
log "ck: $(grep CXX_FLAGS $B/src/ck-core/CMakeFiles/ck.dir/flags.make)"
log "lci: $(find $B/_deps/lci-build -name flags.make | head -1 | xargs grep CXX_FLAGS)"
log "macros: $(grep -E "define CMK_(ERROR_CHECKING|TRACE_ENABLED)\b" $B/include/conv-autoconfig.h | tr '\n' ' ')"
log "charmc BUILDOPTS: $(grep BUILDOPTS $B/include/conv-mach-opt.sh)"
grep -q -- "-O3" $B/reconverse/CMakeFiles/reconverse.dir/flags.make || fail "reconverse not -O3"
grep -q "define CMK_ERROR_CHECKING 0" $B/include/conv-autoconfig.h || fail "error checking still on"

# 2. Charades builds, all three from clean (a bad config.mk once mixed objects
# between trees). charades-qd links the Debug runtime, the others production.
for t in charades-qd charades-prodrt charades-prod; do
  cd $W/$t || fail "no $t"
  grep -q "^CHARADES_SRC *= *$W/$t/src" src/config.mk || fail "$t: CHARADES_SRC is not its own tree"
  log "building $t ($(git log --oneline -1 | cut -c1-40)) against $(grep ^CHARM_DIR src/config.mk)"
  { make -s -C src clean && make -s -C models/phold/simple clean && make -s -C src && make -s -C models/phold/simple; } > $OUT/build_$t.log 2>&1     || { tail -20 $OUT/build_$t.log; fail "$t build"; }
  ls -la models/phold/simple/phold
done
ldd $W/charades-prod/models/phold/simple/phold | grep -E "liblci|libck|reconverse" | head -3

# 3. runs
cd $W/charades-qd || fail "no charades-qd"
source scripts/stampede3/env.sh
srun -N 4 --ntasks-per-node=1 --mpi=none bash $W/charades-runs/stage_libfabric.sh || fail "staging"
source scripts/stampede3/env.sh
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export RUNS=$OUT MARGINS=8 LPS_PER_PE=128 LPC=16
D=$W/devastator
for rep in 1 2; do
  for t in charades-qd charades-prodrt charades-prod; do
    export TREE=$t
    log "rep $rep, $t"
    AGG=pp:64 PPN=2 PEPP=8  END=512000 WORKLOADS="gauss:100:1000:2000" ARMS="w:250 w:500 q:0.003" $S 1 $OUT/${t}_64hi_r$rep.csv
    AGG=pp:64 PPN=2 PEPP=8  END=128000 WORKLOADS="gauss:10:200:2000"   ARMS="w:50 w:100 q:0.003"  $S 1 $OUT/${t}_64lo_r$rep.csv
    AGG=pp:64 PPN=2 PEPP=24 END=512000 WORKLOADS="gauss:100:1000:2000" ARMS="w:175 w:250 w:350 w:500 q:0.003" $S 1 $OUT/${t}_full_r$rep.csv
    AGG=off   PPN=2 PEPP=8  END=128000 WORKLOADS="gauss:100:1000:2000" ARMS="w:250" $S 1 $OUT/${t}_64direct_r$rep.csv
    AGG=off   PPN=2 PEPP=24 END=128000 WORKLOADS="gauss:100:1000:2000" ARMS="w:250" $S 1 $OUT/${t}_fulldirect_r$rep.csv
  done
  log "rep $rep, devastator anchors"
  WINDOW=1000 END=512000 SIGMA=2000 RUNS=$OUT bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p8w8 4
  WINDOW=1000 END=512000 SIGMA=2000 LPS_PER_RANK=128 RUNS=$OUT bash $D/run_phold.sh $D/bin/ofi-psm2/phold-gauss-p8w23 4
done
log "ALL DONE"
