#!/bin/bash
# Per-copy activity of b19 x N on the Mac (one process, 8 PEs, W 2,500, buckets of 2,500)
D=/private/tmp/claude-501/-Users-ritvik/c7e3af75-4002-496f-9d21-06bf9bc195f4/scratchpad/copies
V=/Users/ritvik/charades/models/vlsi; B=$D/../vlsi/cad-polito-it_i99t/i99t/b19/b19.bench
cd $D
for spec in 4:5000 4:1000 8:1000 16:1000 32:1000; do
  n=${spec%%:*} cyc=${spec##*:}
  printf '%s\n' "netlist=$B" "copies=$n" "span=1" "lps-per-chare=128" "chunk=512" "end-time=$((cyc * 2500))" > cfg_${n}_${cyc}
  t0=$(date +%s)
  /usr/bin/time -l perl -e 'alarm 1800; exec @ARGV' $V/vlsi +pe 8 cfg_${n}_${cyc} /Users/ritvik/charades/tests/test_configs/bucket \
      --optimism-window=2500 --gvt-bucket-size=2500 --copy-stats=1 > b19_${n}_${cyc}.out 2>&1
  echo "copies $n cycles $cyc rc=$? $(( $(date +%s) - t0 )) s; $(grep -E 'Events Committed' b19_${n}_${cyc}.out | head -1 | tr -s ' \t' ' '); RSS $(grep 'maximum resident' b19_${n}_${cyc}.out | awk '{printf "%.1f GB", $1/1e9}')"
done
echo ALL DONE
