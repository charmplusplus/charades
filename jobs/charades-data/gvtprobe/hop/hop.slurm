#!/bin/bash -l
#SBATCH -J hop1
#SBATCH -p skx-dev
#SBATCH -N 1
#SBATCH -n 48
#SBATCH -t 00:25:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /work2/09863/rrao/stampede3/charades-runs/gvtprobe/hop_%j.out
# One node: message hop and reduction cost with 1 vs 2 processes, poll settings, perf.
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W; O=$W/charades-runs/gvtprobe; RB=$O/redbench/redbench
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 >/dev/null 2>&1
export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $W/charades-main/scripts/stampede3/env.sh >/dev/null 2>&1
r() { # label nprocs pes args...
  local lab=$1 n=$2 pe=$3; shift 3
  local pm="+pemap 2-46:2,3-47:2"; [ $n = 1 ] && pm="+pemap 2-46:2"
  timeout -s TERM 120 srun --mpi=pmi2 --kill-on-bad-exit=1 -N 1 -n $n -c $((48 / n)) -J $lab $RB +pe $pe +lci_ndevices 16 $pm "$@" > $O/hop_$lab.out 2>&1
  echo "$lab rc=$? $(grep -hE "PINGPONG|REDBENCH" $O/hop_$lab.out)"
}
for rep in 1 2; do
  r p1_same_r$rep 1 23 -p 1 -r 100000
  r p2_same_r$rep 2 46 -p 1 -r 100000
  r p2_cross_r$rep 2 46 -p 23 -r 100000
  r p2_same_pt23_r$rep 2 46 -p 1 -r 100000 +backend_poll_thread 23
  r p2_same_pf1_r$rep 2 46 -p 1 -r 100000 +backend_poll_freq 1
  r p2_same_nd1_r$rep 2 46 -p 1 -r 100000 +lci_ndevices 1
  r red1_23_r$rep 1 23 -r 20000
  r red2_46_r$rep 2 46 -r 20000
  r red2_46_pt23_r$rep 2 46 -r 20000 +backend_poll_thread 23
  r red2_46_pf1_r$rep 2 46 -r 20000 +backend_poll_freq 1
  r red2_2_r$rep 2 2 -r 20000
done
# perf: 2-process same-process ping-pong, both processes recorded via one srun
timeout -s TERM 120 srun --mpi=pmi2 --kill-on-bad-exit=1 -N 1 -n 2 -c 24 -J perf bash -c \
  "perf record -F 2000 -g -o $O/hop_perf_\$SLURM_PROCID.data $RB +pe 46 +lci_ndevices 16 +pemap 2-46:2,3-47:2 -p 1 -r 300000 > $O/hop_perf_\$SLURM_PROCID.out 2>&1"
for i in 0 1; do perf report -i $O/hop_perf_$i.data --no-children --sort symbol --stdio 2>/dev/null | grep -E "^ +[0-9]" | head -25 > $O/hop_perf_${i}_top.txt; done
echo HOP DONE
