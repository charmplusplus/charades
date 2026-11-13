#!/bin/bash
# Single-worker profiles on the idev node: Charades (+pe 1) and Devastator
# (p1w1), b19 x 1, 500 cycles, W 2,500, buckets of 2,500 (RESULTS.md 203).
# Usage (on the node): bash perf1w.sh <tag> [extra Charades args]; TREE=charades-vlsi
W=/work2/09863/rrao/stampede3; tag=$1; shift
O=$W/charades-runs/perf1w/$tag; mkdir -p $O; cd $O
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 >/dev/null 2>&1
C=$W/${TREE:-charades-vlsi}; D=$W/devastator
export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
B=$W/I99T/i99t/b19/b19.bench
printf '%s\n' "netlist=$B" copies=1 span=1 lps-per-chare=128 chunk=512 end-time=1250000 > cfg
PF="perf record -q -e cycles:u -F 1999 ${PERF_G:-}"
srun --mpi=pmi2 -N 1 -n 1 -c 24 numactl --localalloc $PF -o charades.data -- \
  $C/models/vlsi/vlsi +pe 1 cfg $C/tests/test_configs/bucket +pemap 2 +lci_ndevices 1 +mempool_remote_free \
  --optimism-window=2500 --gvt-bucket-size=2500 "$@" > charades.out 2>&1
echo "charades rc=$? $(grep -E 'Execution Time|Events Committed|Event Rate' charades.out | head -3 | tr -s ' \t' ' ' | paste -sd';')"
if [ "${DEVA:-1}" = 1 ]; then
  ( export GASNET_OFI_SPAWNER=pmi FI_PROVIDER=psm2 deva_static_look_dt=2500; unset FI_PROVIDER_PATH
    srun --mpi=pmi2 -N 1 -n 1 -c 24 --cpu-bind=cores $PF -o deva.data -- \
      $D/bin/ofi-psm2/vlsi-p1w1 --netlist=$B --copies=1 --span=1 --chunk=512 --end-time=1250000 > deva.out 2>&1 )
  echo "deva rc=$? $(grep -m1 VLSI_RESULT deva.out | tr ' ' '\n' | grep -E '^(committed|wall_s|committed_per_s)=' | paste -sd' ')"
fi
for e in charades deva; do
  [ -f $e.data ] && perf report -i $e.data --stdio --no-children --sort dso,sym --percent-limit 0.4 2>/dev/null | grep -v "^#" | grep -v "^$" | head -60 > $e.report.txt
done
echo "reports in $O"
