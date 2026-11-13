module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 cmake >/dev/null 2>&1
W=/work2/09863/rrao/stampede3
for c in charm-pads-perf charm-pads-perfshm; do (cd $W/$c/reconverse-linux-x86_64 && make -j46 > rebuild.log 2>&1; echo "$c make rc=$?"; tail -1 rebuild.log); done
