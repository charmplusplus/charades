# Round 2: which flag makes PHOLD hang at 1 x 4 (srun -n 1 -c 4 +pe 4) with
# "+ipc --fossil-lazy=1 --pass-loop=16" (idev 3679189 gate, steps 90/93/96/99).
# Each variant: one run, 40 s cap; a hang gets gdb backtraces of every thread at 15 s.
W=/work2/09863/rrao/stampede3; T=$W/charades-perf; O=$W/charades-runs/r2bisect; mkdir -p $O
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 >/dev/null 2>&1; module load python3 >/dev/null 2>&1
source <(grep -E "^export +SLURM" /tmp/idev_${USER}_bash_env.$(squeue -u $USER -h -t R -o "%i %j" | awk "\$2 ~ /^idv/ {print \$1; exit}"))
export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $T/scripts/stampede3/env.sh >/dev/null 2>&1
M=$T/models/phold/simple; CFG="$M/test_configs/base $T/tests/test_configs/bucket_window"
i=0
for v in "+ipc --fossil-lazy=1 --pass-loop=16" "+ipc --pass-loop=16" "--fossil-lazy=1 --pass-loop=16" "+ipc --fossil-lazy=1" \
         "+ipc --fossil-lazy=1 --pass-loop=16 +backend_poll_single" "--pass-loop=16"; do
  i=$((i+1)); f=$O/v$i.out
  ( cd $O && timeout -s TERM 40 srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -N 1 -n 1 -c 4 $M/phold +pe 4 $CFG +mempool_remote_free $v > $f 2>&1 ) &
  sp=$!; hung=
  for s in $(seq 15); do sleep 1; kill -0 $sp 2>/dev/null || break; done
  if kill -0 $sp 2>/dev/null; then
    pid=$(pgrep -u $USER -x phold | head -1); hung=yes
    [ -n "$pid" ] && gdb -p $pid -batch -ex "thread apply all bt 14" > $O/v$i.gdb 2>&1
  fi
  wait $sp; rc=$?
  ok=$(grep -c "Simulation Executed Successfully" $f)
  printf "v%d [%s]: rc=%s ok=%s %s\n" $i "$v" $rc $ok "${hung:+HUNG at 15 s (gdb v$i.gdb)}"
done
squeue -u $USER -h -s -o "%i %j %M" | grep -v "\.extern\|\.batch\|\.interactive"
