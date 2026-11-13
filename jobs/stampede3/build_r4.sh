#!/bin/bash -l
# build_r4.sh: tree charades-r4 at charades 609212b (--fossil-rounds, --fossil-finish) on charm-pads-perf, as charades-f3
set -u
W=/work2/09863/rrao/stampede3; T=$W/charades-r4
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 >/dev/null 2>&1
[ -d $T ] || git clone -q https://github.com/charmplusplus/charades $T
cd $T && git fetch -q && git checkout -q 609212b || exit 1
sed "s#/charades-f3/#/charades-r4/#" $W/charades-f3/src/config.mk > src/config.mk
grep -n "charades-" src/config.mk
( cd src && (make -j8 > ../build_src.log 2>&1 || make -j1 >> ../build_src.log 2>&1) ) || { echo "src build failed"; tail -20 build_src.log; exit 1; }
for m in models/vlsi models/phold/simple; do
  ( cd $m && (make -j4 > build.log 2>&1 || make -j1 >> build.log 2>&1) ) || { echo "$m build failed"; tail -20 $m/build.log; exit 1; }
done
ls -la models/vlsi/vlsi models/phold/simple/phold
for s in fossil-rounds fossil-finish "PER-PE WITH A SHARED SPARE LIST" direct-execute; do printf '%-34s %s\n' "$s" $(strings models/vlsi/vlsi | grep -c -- "$s"); done
ldd models/vlsi/vlsi | grep -c charm-pads-perf/
echo BUILD_R4_DONE
