#!/bin/bash -l
#SBATCH -J sdiag7
#SBATCH -t 00:40:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/sdiag7_%j.out
# Rank 0's page faults: where they come from (perf page-faults, process 0)
# and whether glibc malloc settings stop them (charades RESULTS.md section 91).
# Submit: sbatch -p skx-dev -N 4 -n 192 -x c455-081 diag7.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
R=$W/charades-runs; OUT=$R/sdiag7/j$SLURM_JOB_ID; mkdir -p $OUT
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake >/dev/null 2>&1
T=charades-diag; S=$W/$T/scripts/stampede3/ctl_sweep.sh
log "job $SLURM_JOB_ID; nodes $(scontrol show hostnames $SLURM_JOB_NODELIST | tr '\n' ' ')"
log "charades $(git -C $W/$T log --oneline -1 | cut -c1-60); htram $(git -C $W/htram log --oneline -1 | cut -c1-50)"
export TREE=$T LPS_PER_PE=128 LPC=16 CAP=60 PPN=2 PEPP=23 CPT=24
# malloc arms: default; no trim (trim threshold 1 GB, top pad 64 MB; the mmap
# threshold then stays fixed at 128 KB); no trim and no mmap churn (mmap threshold 32 MB)
declare -A TUN=([m0]="" [mtrim]="glibc.malloc.trim_threshold=1073741824:glibc.malloc.top_pad=67108864"
  [mall]="glibc.malloc.trim_threshold=1073741824:glibc.malloc.top_pad=67108864:glibc.malloc.mmap_threshold=33554432")
cs() { # tag malloc-arm workload W extra   (env WRAP=sched|pf)
  ( [ -n "${TUN[$2]}" ] && export GLIBC_TUNABLES=${TUN[$2]}
    case "${WRAP:-}" in
      sched) mkdir -p $OUT/$1; export BIN_WRAP=$R/schedwrap.sh SCHED_DIR=$OUT/$1 ;;
      pf) mkdir -p $OUT/$1; export BIN_WRAP=$R/pfwrap.sh PERF_DIR=$OUT/$1 ;;
    esac
    export NODES=4 AGG=pp:512 END=512000 WORKLOADS="$3" ARMS="w:$4" EXTRA_ARGS="+lci_ndevices 23 +pemap 2-46:2,3-47:2 $5"
    RUNS=$OUT/$1 $S 1 $OUT/$1.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
cs warm m0 gauss:100:1000:100 250 ""
cs warm2 m0 gauss:100:1000:100 250 ""
for rep in 1 2; do
  for m in m0 mtrim mall; do
    for wl in gauss:100:1000:100 gauss:100:1000:2000; do
      t=${m}_${wl//:/_}_w400_r$rep
      WRAP=sched cs S_$t $m $wl 400 "--gvt-trace=3 --pe-stats=1"
      cs off_$t $m $wl 400 ""
    done
  done
  log "REP $rep DONE"
done
for wl in gauss:100:1000:100 gauss:100:1000:2000; do
  t=m0_${wl//:/_}_w400; d=$OUT/P_$t
  WRAP=pf cs P_$t m0 $wl 400 "--gvt-trace=3"
  for f in $d/pf.*.data; do
    [ -e "$f" ] || continue
    perf report -i $f --stdio -q --no-children --sort pid --percent-limit 0.5 > ${f%.data}.pid.txt 2>/dev/null
    perf report -i $f --stdio -q --no-children --sort pid,sym -G --percent-limit 2 > ${f%.data}.callers.txt 2>/dev/null
  done
done
log "SDIAG7 DONE"
