W=/work2/09863/rrao/stampede3
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 >/dev/null 2>&1; module load python3 >/dev/null 2>&1
G="agg_ctl_measured_fast_bucket_pp agg_deadline_bucket_pp agg_deadline_bucket_wps bucket_window ctl_measured_bucket"
for spec in "charades-perf:+mempool_remote_free +ipc" "charades-perfshm:+mempool_remote_free" "charades-perf:+mempool_remote_free +ipc --fossil-lazy=1"; do
  tree=${spec%%:*}; ra=${spec#*:}
  ( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/$tree/scripts/stampede3/env.sh >/dev/null 2>&1
    cd $W/$tree/tests; export CHARADES_RUN_ARGS="$ra"
    python3 test.py --tier change --no-build --launcher srun --nodes 1 --launch 2x2 --launch 4x2 --model VLSI $G 2>&1 | tail -3 | paste -sd" " | sed "s|^|$tree [$ra]: |" )
done
