#!/bin/bash -l
#SBATCH -J topo
#SBATCH -t 00:05:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/topo_%j.out
# One skx node's layout: CPUs, NUMA, caches, the Omni-Path adapter's NUMA node
# and interrupt placement.
echo "== host $(hostname)"; echo "== lscpu"; lscpu
echo "== numactl -H"; numactl -H 2>/dev/null || echo "(no numactl)"
echo "== /sys numa nodes"; for n in /sys/devices/system/node/node*; do echo "$(basename $n): cpus $(cat $n/cpulist)"; done
echo "== hfi1 devices"; for d in /sys/class/infiniband/*; do echo "$(basename $d): numa_node $(cat $d/device/numa_node 2>/dev/null) local_cpus $(cat $d/device/local_cpulist 2>/dev/null)"; done
echo "== hfi1 / network interrupts (CPU affinity)"
grep -iE "hfi1|mlx|eth|ib" /proc/interrupts | while read -r irq rest; do i=${irq%:}; echo "IRQ $i $(echo $rest | awk '{print $(NF-1), $NF}') affinity $(cat /proc/irq/$i/smp_affinity_list 2>/dev/null) eff $(cat /proc/irq/$i/effective_affinity_list 2>/dev/null)"; done | head -80
echo "== interrupt totals per CPU (first 12 CPUs), top sources"
awk 'NR==1{next} {s=0; for(i=2;i<=13;i++) s+=$i; if (s>0) print $1, s, $NF}' /proc/interrupts | sort -k2 -nr | head -25
echo "== irqbalance"; systemctl is-active irqbalance 2>/dev/null; pgrep -a irqbalance
echo "== isolcpus / nohz"; cat /proc/cmdline
