#!/bin/bash
# Copy libfabric 2.7.0 to this node's /tmp (run once per node per job).
set -e
d=/tmp/libfabric_$USER
mkdir -p $d /tmp/no_fi_dso_$USER
cp $WORK/libfabric-2.7.0/lib/libfabric.so.1.33.0 $WORK/libfabric-2.7.0/lib/libhwloc.so.15 $d/
ln -sf libfabric.so.1.33.0 $d/libfabric.so.1
echo "staged on $(hostname -s)"
