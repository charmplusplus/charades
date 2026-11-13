# Devastator VLSI at one process x 46 workers stalls after setup (RESULTS.md 202).
# Usage (on the idev node, SLURM vars sourced): devap1.sh <tag> <binary> <netlist> [srun binding args]
# Runs it, and 40 s in records each thread: CPU, use, affinity; then perf for 5 s.
W=/work2/09863/rrao/stampede3; D=$W/devastator; DB=$D/bin/ofi-psm2
tag=$1 bin=$2 net=$3; shift 3; bind=${*:---cpu-bind=cores}
out=$W/charades-runs/devap1/$tag; mkdir -p $out
export ${EXTRA_ENV:-} GASNET_BACKTRACE=1 GASNET_OFI_SPAWNER=pmi FI_PROVIDER=psm2 deva_static_look_dt=5000; unset FI_PROVIDER_PATH
t0=$(date +%s)
srun --mpi=pmi2 --kill-on-bad-exit=1 -N 1 -n 1 --ntasks-per-node=1 -c 48 $bind -m block:block \
  stdbuf -oL $DB/$bin --netlist=$net --copies=1 --span=1 --chunk=512 --end-time=12500000 > $out/run.out 2>&1 &
sp=$!
for i in $(seq 40); do sleep 1; grep -q VLSI_RESULT $out/run.out && break; done
pid=$(pgrep -u $USER -x $bin | head -1)
if [ -n "$pid" ]; then
  ps -L -o tid,psr,pcpu,stat,wchan:20,comm -p $pid > $out/threads.txt
  for t in /proc/$pid/task/*; do echo "$(basename $t) $(taskset -cp $(basename $t) 2>&1 | sed "s/.*: //")"; done > $out/affinity.txt
  cat /proc/$pid/status | grep -E "Threads|Cpus_allowed_list|voluntary" > $out/status.txt
  gdb -p $pid -batch -ex "thread apply all bt 12" > $out/gdb.txt 2>&1
  perf record -o $out/perf.data -p $pid -- sleep 5 > /dev/null 2>&1
  perf report -i $out/perf.data --stdio --no-children --sort tid,sym --percent-limit 0.5 2>/dev/null | head -80 > $out/perf.txt
  scancel -s KILL ${SLURM_JOB_ID}.$(squeue -j $SLURM_JOB_ID -s -h -o %i | awk -F. "\$2 ~ /^[0-9]+\$/" | tail -1 | cut -d. -f2) 2>/dev/null
fi
kill $sp 2>/dev/null; wait $sp 2>/dev/null
echo "$tag: $(( $(date +%s) - t0 )) s; result: $(grep -m1 -o "committed_per_s=[^ ]*" $out/run.out || echo none); pid ${pid:-gone}"
