#!/bin/bash
# cmp1n.sh <out tag> <spec> ... : b19 x 1 on 1 node, direct sends, W 2,500,
# buckets of 2,500, 5,000 cycles; REPS reps (default 2), specs alternating
# within each rep. spec = tree:procs:PEs:cores[:extra engine/runtime args]
# (+lci_ndevices 23 unless the extra args set it). Run on an idev node.
W=/work2/09863/rrao/stampede3; O=$W/charades-runs/cmp1n/$1; shift; mkdir -p $O
module use /opt/apps/modulefiles >/dev/null 2>&1; module load gcc/13.2.0 >/dev/null 2>&1; module load python3 >/dev/null 2>&1
export CAP=${CAP:-300} VLSI_NETLISTS=$W/I99T/i99t
L="+pemap ${PEMAP:-2-46:2,3-47:2} +mempool_remote_free --blocked-time=1 --commit-digest=1"
for rep in $(seq ${REPS:-2}); do
  for spec in "$@"; do
    IFS=: read -r tree ppn pepp cpt extra <<< "$spec"
    nd="+lci_ndevices 23"; [[ "$extra" == *lci_ndevices* ]] && nd=""
    tag=$(echo "${tree}_${ppn}x${pepp}_${extra}" | tr -c 'A-Za-z0-9_+=.\n-' '_')
    ( export TREE=$tree NODES=1 PPN=$ppn PEPP=$pepp CPT=$cpt AGG=off WORKLOADS=vlsi:b19:1:1 ARMS="${ARMS_SET:-w:${WIN:-2500}}" \
        END=12500000 BUCKETS=${BUCKET:-2500} LPC=128 LPS_PER_PE=128 EXTRA_ARGS="$L $nd $extra"
      RUNS=$O/${tag}_r$rep $W/$tree/scripts/stampede3/ctl_sweep.sh 1 $O/${tag}_r$rep.csv >/dev/null 2>&1 )
    f=$(ls $O/${tag}_r$rep/ctl_sweep/logs/*.out 2>/dev/null | head -1)
    awk -F, -v t="$tag r$rep" 'NR==2 {printf "%-60s %-5s %6.2f M ev/s  blk %5s  min %5s  digest %s\n", t, $11, $14/$13/1e6, $31, $32, $NF}' $O/${tag}_r$rep.csv
    rm -f $O/${tag}_r$rep/ctl_sweep/logs/*.digest.csv
  done
done
