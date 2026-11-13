#!/bin/bash -l
#SBATCH -J packruns
#SBATCH -t 02:00:00
#SBATCH -N 1 -n 1
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/packruns_%j.out
# Pack raw trace files (GVT traces, per-PE logs, strace and perf output) of
# every finished run folder in $WORK/charades-runs into raw_traces.tar.xz,
# check the archive lists every file, then delete the originals.
# Run CSVs, summaries, job scripts and logs stay as they are.
set -u
cd /work2/09863/rrao/stampede3/charades-runs
SKIP=" "
for d in */; do
  d=${d%/}
  [[ "$SKIP" == *" $d "* ]] && { echo "$d: skipped (in use)"; continue; }
  ( set -euo pipefail; cd "$d"
    list=$(mktemp)
    find . -type f \( -name 'gvt_waves_*.csv' -o -name 'gvt_ranks_*.csv' -o -name 'gvt_trace.csv' -o -name 'gvt_pe_*.csv' \
      -o -name 'gvt_rec_*.csv' -o -name 'recv_parts_*.csv' -o -name 'pe_stats.csv' -o -regex '.*/gvt_[0-9]+\.out' \
      -o -name 'sk.*' -o -name 'perf*.data*' -o -name '*.tar' \) ! -name 'raw_traces.tar.xz' | sort > $list
    n=$(wc -l < $list)
    if [ "$n" -eq 0 ]; then echo "$d: nothing"; rm $list; exit 0; fi
    if [ -e raw_traces.tar.xz ]; then echo "$d: raw_traces.tar.xz exists, skipped"; rm $list; exit 0; fi
    before=$(tr '\n' '\0' < $list | du -ck --files0-from=- | tail -1 | cut -f1)
    tar -cf - -T $list | xz -T 24 -6 > raw_traces.tar.xz
    m=$(xz -dc raw_traces.tar.xz | tar -tf - | wc -l)
    if [ "$m" -ne "$n" ]; then echo "$d: archive lists $m of $n files, originals kept"; rm $list; exit 0; fi
    tr '\n' '\0' < $list | xargs -0 rm -f
    find . -type d -empty -delete
    echo "$d: $n files, $before KB -> $(du -k raw_traces.tar.xz | cut -f1) KB"
    rm $list )
done
echo PACK DONE
