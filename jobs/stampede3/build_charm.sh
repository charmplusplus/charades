#!/bin/bash
# Build Charm++ on Reconverse in the trees named as arguments (under $WORK),
# side by side, each with half the node's cores.
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 cmake >/dev/null 2>&1
command -v cmake >/dev/null || { echo "no cmake" >&2; exit 1; }
for t in "$@"; do
    (cd $WORK/$t && ./build charm++ reconverse-linux-x86_64 --disable-fortran -j24 \
        > build.log 2>&1; echo "exit $?" >> build.log) &
done
wait
