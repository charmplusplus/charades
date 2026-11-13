#!/bin/bash -l
#SBATCH -J packruns2
#SBATCH -t 02:00:00
#SBATCH -N 1 -n 1
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/packruns2_%j.out
# Second pass of packruns.slurm, restart-safe and 8 folders at a time.
# A verified archive gets a .raw_traces.ok marker before any original is
# deleted; an archive without the marker is partial (a killed run) and is
# redone from the originals, which are still all there.
set -u
cd /work2/09863/rrao/stampede3/charades-runs
pack() {
  d=$1; cd "$d" || exit 0
  if [ -e raw_traces.tar.xz ] && [ ! -e .raw_traces.ok ]; then
    # complete (killed while deleting originals) or cut off mid-write?
    if xz -t raw_traces.tar.xz 2>/dev/null; then touch .raw_traces.ok; echo "$d: archive complete, finishing"
    else rm -f raw_traces.tar.xz; echo "$d: partial archive removed, redoing"; fi
  fi
  list=$(mktemp)
  find . -type f \( -name 'gvt_waves_*.csv' -o -name 'gvt_ranks_*.csv' -o -name 'gvt_trace.csv' -o -name 'gvt_pe_*.csv' \
    -o -name 'gvt_rec_*.csv' -o -name 'recv_parts_*.csv' -o -name 'pe_stats.csv' -o -regex '.*/gvt_[0-9]+\.out' \
    -o -name 'sk.*' -o -name 'perf*.data*' -o -name '*.tar' \) ! -name 'raw_traces.tar.xz' | sort > $list
  n=$(wc -l < $list)
  if [ -e .raw_traces.ok ]; then
    # verified earlier, killed while deleting: finish deleting what the archive holds
    [ "$n" -eq 0 ] && { rm $list; exit 0; }
    { tr '\n' '\0' < $list | xargs -0 rm -f; find . -type d -empty -delete; }
    echo "$d: finished deleting $n files of a verified archive"; rm $list; exit 0
  fi
  if [ "$n" -eq 0 ]; then rm $list; exit 0; fi
  tar -cf - -T $list | xz -T 4 -6 > raw_traces.tar.xz
  m=$(xz -dc raw_traces.tar.xz | tar -tf - | wc -l)
  if [ "$m" -ne "$n" ]; then echo "$d: archive lists $m of $n files, originals kept"; rm -f raw_traces.tar.xz; rm $list; exit 0; fi
  touch .raw_traces.ok
  tr '\n' '\0' < $list | xargs -0 rm -f
  find . -type d -empty -delete
  echo "$d: $n files -> $(du -k raw_traces.tar.xz | cut -f1) KB"
  rm $list
}
export -f pack
# Folders the first pass finished (archive present, no originals left) get
# the marker; then every folder goes through pack, 8 at a time
for d in */; do d=${d%/}
  if [ -e "$d/raw_traces.tar.xz" ] && [ ! -e "$d/.raw_traces.ok" ] && grep -q "^$d: [0-9]* files" /scratch/09863/rrao/charades-jobs/packruns_3648027.out; then touch "$d/.raw_traces.ok"; fi
done
ls -d */ | sed 's|/$||' | xargs -P 8 -I{} bash -c 'pack "$@"' _ {}
echo PACK2 DONE
