# Round 2 (charades RESULTS.md section 210) on an idev node: rebuild the runtimes with
# Reconverse bab3df1 (75719d5 / 371fdc8 here), gate --pass-loop, measure.
# Usage: round2.sh build | gate | measure | perf
W=/work2/09863/rrao/stampede3
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 >/dev/null 2>&1; module load cmake >/dev/null 2>&1; module load python3 >/dev/null 2>&1
source <(grep -E "^export +SLURM" /tmp/idev_${USER}_bash_env.$(squeue -u $USER -h -t R -o "%i %j" | awk "\$2 ~ /^idv/ {print \$1; exit}"))
case $1 in
build)
  for c in charm-pads-perf charm-pads-perfshm; do (cd $W/$c/reconverse-linux-x86_64 && make -j46 > rebuild_r2.log 2>&1; echo "$c make rc=$?"; tail -1 rebuild_r2.log); done
  for c in charm-pads-perf charm-pads-perfshm; do nm -D $W/$c/reconverse-linux-x86_64/lib/libreconverse.so 2>/dev/null | grep -c CmiPeHasPendingWork || find $W/$c/reconverse-linux-x86_64 -name "libreconverse*" | head -3; done ;;
gate)
  export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/charades-perf/scripts/stampede3/env.sh >/dev/null 2>&1
  for ra in "+mempool_remote_free --pass-loop=16" "+mempool_remote_free --pass-loop=16 +ipc --fossil-lazy=1"; do
    ( cd $W/charades-perf/tests; export CHARADES_RUN_ARGS="$ra"
      python3 test.py --tier change --no-build --launcher srun --nodes 1 --launch 1x4 --launch 2x2 --launch 4x2 --model VLSI --model "Simple PHOLD" --model Traffic --model Dragonfly \
        bucket_window agg_ctl_measured_fast_bucket_pp agg_deadline_bucket_wps 2>&1 | tail -3 | paste -sd" " | sed "s|^|[$ra]: |" )
  done ;;
measure)
  export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/charades-perf/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $W/charades-runs; rm -rf cmp1n/r2
  B="--fossil-lazy=1 --batch=32 --gvt-trace=1"
  WIN=5000 REPS=2 bash cmp1n.sh r2 "charades-perf:1:46:48:$B +backend_poll_single" "charades-perf:1:46:48:$B" \
    "charades-perf:1:46:48:$B --pass-loop=4" "charades-perf:1:46:48:$B --pass-loop=16" "charades-perf:1:46:48:$B --pass-loop=64" \
    "charades-perf:2:23:24:$B +ipc" "charades-perf:2:23:24:$B +ipc --pass-loop=16" ;;
perf)
  export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/charades-perf/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $W/charades-runs; rm -rf $W/charades-runs/prof_r2 cmp1n/prof_r2; mkdir -p $W/charades-runs/prof_r2
  BIN_WRAP=$W/charades-perf/scripts/stampede3/perfwrap.sh PERF_DIR=$W/charades-runs/prof_r2 WIN=5000 REPS=1 bash cmp1n.sh prof_r2 "charades-perf:1:46:48:--fossil-lazy=1 --batch=32 --pass-loop=${2:-16}"
  f=$(ls $W/charades-runs/prof_r2/*.data | head -1); perf report -i $f --stdio --no-children --sort dso,sym --percent-limit 0.3 2>/dev/null | head -150 > $W/charades-runs/prof_r2/report.txt
  perf report -i $f --stdio --no-children --sort dso 2>/dev/null | grep -v "^#" | grep -v "^$" | head -5; grep -v "^#" $W/charades-runs/prof_r2/report.txt | grep -v "^$" | head -30 ;;
esac
