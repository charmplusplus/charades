#!/bin/bash -l
# build_r5_apps.sh: traffic and dragonfly in charades-r5 (85a2aad), for jobs F1/F5 (RESULTS.md 240)
set -u
W=/work2/09863/rrao/stampede3; T=$W/charades-r5
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 >/dev/null 2>&1
cd $T && [ "$(git rev-parse --short=7 HEAD)" = 85a2aad ] || { echo "not at 85a2aad"; exit 1; }
for m in models/traffic models/dragonfly; do
  ( cd $m && (make -j4 > build.log 2>&1 || make -j1 >> build.log 2>&1) ) || { echo "$m build failed"; tail -20 $m/build.log; exit 1; }
done
ls -la models/traffic/traffic models/dragonfly/dragonfly models/phold/simple/phold models/vlsi/vlsi
for b in models/traffic/traffic models/dragonfly/dragonfly models/phold/simple/phold; do
  printf '%-32s ctl-reach-buckets %s, base before and after %s, Commit Digest %s, spare list %s, charm-pads-perf %s\n' $b \
    $(strings $b | grep -c ctl-reach-buckets) $(strings $b | grep -c "the base before and after") $(strings $b | grep -c "Commit Digest") \
    $(strings $b | grep -c "PER-PE WITH A SHARED SPARE LIST") $(ldd $b | grep -c charm-pads-perf/)
done
echo BUILD_R5_APPS_DONE
