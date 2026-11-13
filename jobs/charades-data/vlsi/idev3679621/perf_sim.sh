W=/work2/09863/rrao/stampede3
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 >/dev/null 2>&1; module load python3 >/dev/null 2>&1
source <(grep -E "^export +SLURM" /tmp/idev_${USER}_bash_env.$(squeue -u $USER -h -t R -o "%i %j" | awk "\$2 ~ /^idv/ {print \$1; exit}"))
export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/charades-perf/scripts/stampede3/env.sh >/dev/null 2>&1
cd $W/charades-runs
for a in "1:--pass-loop=1 +backend_poll_single" "16:--pass-loop=16"; do
  t=${a%%:*}; x=${a#*:}; D=$W/charades-runs/prof_sim_$t; rm -rf $D cmp1n/prof_sim_$t; mkdir -p $D
  BIN_WRAP=$W/charades-runs/perfwrap_d.sh PERF_DIR=$D WIN=5000 REPS=1 bash cmp1n.sh prof_sim_$t "charades-perf:1:46:48:--fossil-lazy=1 --batch=32 $x"
  f=$(ls $D/*.data | head -1); perf report -i $f --stdio --no-children --sort dso,sym --percent-limit 0.3 2>/dev/null | head -150 > $D/report.txt
  echo "== $x"; perf report -i $f --stdio --no-children --sort dso 2>/dev/null | grep -v "^#" | grep -v "^$" | head -4; grep -v "^#" $D/report.txt | grep -v "^$" | head -24
done
