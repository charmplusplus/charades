#!/bin/bash -l
#SBATCH -J deva64build
#SBATCH -N 1
#SBATCH -n 48
#SBATCH -t 00:45:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/deva64build_%j.out
# Devastator binaries for 64 nodes (user decision 2026-11-07: build, no runs
# yet): 2 processes x 23 workers per node = p128w23, for phold-gauss, traffic,
# dragonfly and vlsi, GASNet ofi-conduit over psm2, the same source and build
# script as the 1-32-node binaries (sources unchanged since those builds).
# Builds only; nothing is run. A built binary needs 64 nodes to start.
# Submit: sbatch -p skx-dev -x c455-081 deva64build.slurm, and an skx copy with
# --export=ALL,TWIN=<skx-dev id>; then write the skx id to $TWF.
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W; D=$W/devastator
log() { echo "[$(date +%T)] $*"; }
TWF=$W/charades-runs/deva64build.twin
TWIN=${TWIN:-$(cat $TWF 2>/dev/null)}
if [ -n "${TWIN:-}" ]; then
  st=$(squeue -h -j $TWIN -o %T 2>/dev/null)
  [ "$st" = PENDING ] || { log "twin $TWIN is ${st:-not queued}: exiting"; exit 0; }
  scancel $TWIN && log "twin $TWIN was pending: cancelled"
fi
log "job $SLURM_JOB_ID on $(hostname -s)"
BS=${BS:-"phold-gauss traffic dragonfly vlsi"}   # BS=vlsi: VLSI alone (the first job built the other three)
# vlsi.cxx compiles Charades' own netlist reader (models/vlsi/netlist.C), so all
# engines build the same circuit; it is unchanged since 017e722 (2026-11-02),
# before the 1-32-node VLSI builds, and identical in charades-r5, r4 and f3
export CXX_PPFLAGS="-I$W/charades-r5/models/vlsi"
for b in $BS; do
  [ -e $D/bin/ofi-psm2/$b-p128w23 ] && { log "$b-p128w23 exists: not overwriting"; exit 1; }
done
LAYOUTS="128:23" BENCHES="$BS" STOCK=0 PAR=0 bash $D/build_stampede3.sh ofi-psm2
for b in $BS; do
  f=$D/bin/ofi-psm2/$b-p128w23
  if [ -x $f ]; then
    log "OK $f $(stat -c %s $f) bytes (p64w23: $(stat -c %s $D/bin/ofi-psm2/$b-p64w23)); $(ldd $f | grep -c 'not found') libraries not found; $(ldd $f | grep -oE 'lib(fabric|psm2|pmi2)[^ ]*' | sort -u | tr '\n' ' ')"
  else
    log "MISSING $f"
  fi
done
log "DEVA64BUILD DONE"
