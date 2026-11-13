module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 cmake >/dev/null 2>&1
W=/work2/09863/rrao/stampede3; cd $W/charm-pads-perfshm
./build charm++ reconverse-linux-x86_64 --with-production --enable-shmem -j46 "--with-cmake-args=-DFETCHCONTENT_SOURCE_DIR_LCI=$W/charm-pads-exp/reconverse-linux-x86_64/_deps/lci-src" > build.log 2>&1
echo "build rc=$?"; tail -1 build.log; grep -n "CMK_USE_SHMEM" reconverse-linux-x86_64/include/conv-autoconfig.h
