#!/bin/bash -l
# build_f3.sh: tree charades-f3 at charades 8a34d51 (the hold scan fix) on charm-pads-perf, as charades-abl
set -u
W=/work2/09863/rrao/stampede3; T=$W/charades-f3
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 >/dev/null 2>&1
[ -d $T ] || git clone -q https://github.com/charmplusplus/charades $T
cd $T && git fetch -q && git checkout -q 8a34d51 || exit 1
sed "s#/charades-abl/#/charades-f3/#" $W/charades-abl/src/config.mk > src/config.mk
grep -n "charades-" src/config.mk
( cd src && (make -j8 > ../build_src.log 2>&1 || make -j1 >> ../build_src.log 2>&1) ) || { echo "src build failed"; tail -20 build_src.log; exit 1; }
for m in models/phold/simple models/traffic models/dragonfly; do
  ( cd $m && (make -j4 > build.log 2>&1 || make -j1 >> build.log 2>&1) ) || { echo "$m build failed"; tail -20 $m/build.log; exit 1; }
done
ls -la models/phold/simple/phold models/traffic/traffic models/dragonfly/dragonfly
echo BUILD_F3_DONE
