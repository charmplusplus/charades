module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 cmake >/dev/null 2>&1
W=/work2/09863/rrao/stampede3
for t in charades-perf charades-perfshm; do
  ( cd $W/$t/src && make -j16 > build.log 2>&1 || { echo "$t lib FAILED"; tail -5 build.log; exit 1; }
    for m in vlsi phold/simple traffic dragonfly; do (cd ../models/$m && make -j8 > build.log 2>&1) || { echo "$t $m FAILED"; tail -5 ../models/$m/build.log; }; done
    echo "$t $(git log --oneline -1 | cut -c1-12) built"; strings ../models/vlsi/vlsi | grep -c "fossil-lazy"; ldd ../models/vlsi/vlsi | grep -o "charm-pads-[a-z]*" | sort -u )
done
