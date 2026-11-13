#!/bin/bash -l
#SBATCH -J red2
#SBATCH -p skx-dev
#SBATCH -N 16
#SBATCH -n 768
#SBATCH -t 00:25:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /work2/09863/rrao/stampede3/charades-runs/gvtprobe/red2_%j.out
# Reduction cost by mode (0 GVT tuple, 1 one int, 2 16-int array), PEs per process, node count; perf of the reduction.
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W; O=$W/charades-runs/gvtprobe/red2; mkdir -p $O; RB=$W/charades-runs/gvtprobe/redbench/redbench
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 >/dev/null 2>&1
export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/charades-main/scripts/stampede3/env.sh >/dev/null 2>&1
r() { # label nodes nprocs pes args...
  local lab=$1 N=$2 n=$3 pe=$4; shift 4
  local pm="+pemap 2-46:2,3-47:2"; [ $n = $N ] && pm="+pemap 2-46:2"
  timeout -s TERM 120 srun --mpi=pmi2 --kill-on-bad-exit=1 -N $N -n $n -c $((48 * N / n)) -J $lab $RB +pe $pe +lci_ndevices 16 $pm "$@" > $O/$lab.out 2>&1
  echo "$lab rc=$? $(grep -hE "REDBENCH" $O/$lab.out)"
}
r warm 1 1 2 -r 200 -w 10          # first launch of the job is slow (cold $WORK)
for rep in 1 2; do
  for m in 0 1 2; do
    for pe in 8 16 23; do r p1x${pe}_m${m}_r$rep 1 1 $pe -m $m; done
    r p2x23_m${m}_r$rep 1 2 46 -m $m
    r n4_m${m}_r$rep 4 8 184 -m $m
    r n16_m${m}_r$rep 16 32 736 -m $m
  done
done
timeout -s TERM 120 srun --mpi=pmi2 --kill-on-bad-exit=1 -N 1 -n 2 -c 24 -J perf bash -c \
  "perf record -F 4000 -g -o $O/perf_\$SLURM_PROCID.data $RB +pe 46 +lci_ndevices 16 +pemap 2-46:2,3-47:2 -m 0 -r 200000 > $O/perf_\$SLURM_PROCID.out 2>&1"
for i in 0 1; do
  pid=$(perf report -i $O/perf_$i.data --sort pid --stdio 2>/dev/null | grep -oE "[0-9]+:redbench" | head -1 | cut -d: -f1)
  perf report -i $O/perf_$i.data --tid=$pid --no-children --sort symbol --stdio 2>/dev/null | grep -E "^ +[0-9]" | head -40 > $O/perf_${i}_main_self.txt
  perf report -i $O/perf_$i.data --tid=$pid --children --sort symbol --stdio 2>/dev/null | grep -E "^ +[0-9]" | head -60 > $O/perf_${i}_main_incl.txt
  perf report -i $O/perf_$i.data --no-children --sort symbol --stdio 2>/dev/null | grep -E "^ +[0-9]" | head -30 > $O/perf_${i}_all_self.txt
done
echo RED2 DONE
