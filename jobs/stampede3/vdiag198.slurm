#!/bin/bash -l
#SBATCH -J vdiag198
#SBATCH -t 00:40:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /scratch/09863/rrao/charades-jobs/vdiag198_%j.out
# VLSI step-cost diagnostic, job V3 (charades RESULTS.md section 198): why a
# Charades clock cycle takes 1.8x Devastator's at the same window. b19 x N
# (one copy per node, span 1, balanced layout), direct sends, W 2,500 ps,
# buckets of 2,500 ps, 5,000 cycles (12,500,000 ps); 1 and 4 nodes side by
# side; 2 reps, arm order reversed in rep 2.
#   gate on 2 nodes, then Devastator's single-worker vlsi binary (ofi-psm2,
#     p1w1) built on the batch host; then the two series
#   nodes 0-3: the 4-node series; node 4: the 1-node series
#   Charades (charades-vlsi 5f6983a, --localalloc launch, --blocked-time=1,
#     --commit-digest=1): 2 x 23 PEs per node (the reference); 1 x 46 on the
#     same cores (no hops between processes); each with --comm-stats=1
#     (send-to-receive latency by class). 1 node also: W 10,000; one copy on
#     a single PE (500 cycles, 1,250,000 ps)
#   Devastator: p2w23 / p8w23 at W 2,500 (the same-job reference). 1 node
#     also: W 10,000; one copy on a single worker (p1w1, 500 cycles)
#   rep 1 only: --pe-stats=1 --gvt-trace=1 at W 2,500 (1 and 4 nodes) and
#     W 10,000 (1 node); perf (user cycles, task 0) of both engines at 1 node
# Submit: sbatch -p skx-dev -N 5 -n 240 -x c455-081 vdiag198.slurm (and skx)
set -u
W=/work2/09863/rrao/stampede3; export WORK=$W
OUT=$W/charades-runs/vdiag198/j$SLURM_JOB_ID; mkdir -p $OUT/perf/charades $OUT/perf/deva
log() { echo "[$(date +%T)] $*"; }
module use /opt/apps/modulefiles >/dev/null 2>&1
module load gcc/13.2.0 cmake python3 >/dev/null 2>&1
T=charades-vlsi; C=$W/$T; S=$C/scripts/stampede3/ctl_sweep.sh; D=$W/devastator
PW=$C/scripts/stampede3/perfwrap.sh; DB=$D/bin/ofi-psm2
NETLIST=$W/I99T/i99t/b19/b19.bench
NL=($(scontrol show hostnames $SLURM_JOB_NODELIST))
join() { local IFS=,; echo "$*"; }
log "job $SLURM_JOB_ID; nodes ${NL[*]}; on $(hostname -s)"
log "charades $(git -C $C log --oneline -1 | cut -c1-60)"
strings $C/models/vlsi/vlsi | grep -q "layout-bins" || { log "Charades vlsi binary lacks the balanced layout"; exit 1; }
strings $C/models/vlsi/vlsi | grep -q "blocked_s" || { log "Charades vlsi binary lacks pe_stats blocked_s"; exit 1; }
grep -q "vlsi:<circuit>" $S || { log "ctl_sweep.sh lacks the vlsi workload"; exit 1; }
grep -q "layout-bins" $D/devastator/bench/vlsi.cxx || { log "Devastator vlsi.cxx lacks the balanced layout"; exit 1; }
for b in $NETLIST $PW $DB/vlsi-p2w23 $DB/vlsi-p8w23; do
  [ -e $b ] || { log "missing $b"; exit 1; }
done
command -v perf >/dev/null || { log "no perf"; exit 1; }

# ---- gate: the VLSI test tier on 2 nodes
( export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536; source $C/scripts/stampede3/env.sh >/dev/null 2>&1
  cd $C/tests; export CHARADES_RUN_ARGS="+mempool_remote_free"
  python3 test.py --tier change --no-build --launcher srun --nodes 2 --model VLSI \
    agg_ctl_measured_fast_bucket_pp agg_deadline_bucket_pp agg_deadline_bucket_wps bucket_window ctl_measured_bucket > $OUT/gate.txt 2>&1 )
tail -3 $OUT/gate.txt
grep -q "Failed: *0/" $OUT/gate.txt && grep -q "Timed out: *0/" $OUT/gate.txt || {
  i=0; for f in $(grep -E " (FAIL|TIMEOUT) " $OUT/gate.txt | awk '{print $NF}'); do i=$((i+1)); cp $f $OUT/gate_fail_$i.out 2>/dev/null; done
  log "GATE FAILED (outputs in $OUT/gate_fail_*.out)"; exit 1; }
log "GATE DONE"

# ---- Devastator's single-worker binary, on the batch host, before any timed run
( CXX_PPFLAGS="-I$C/models/vlsi" BENCHES="vlsi" LAYOUTS="1:1" STOCK=0 PAR=0 \
    bash $D/build_stampede3.sh ofi-psm2 > $OUT/deva_build.txt 2>&1
  echo "build rc=$?" >> $OUT/deva_build.txt )
tail -2 $OUT/deva_build.txt
[ -x $DB/vlsi-p1w1 ] && log "Devastator p1w1 built" || log "NO Devastator p1w1 binary: its single-worker arm is skipped"

export TREE=$T CAP=300 VLSI_NETLISTS=$W/I99T/i99t
L="+lci_ndevices 23 +pemap 2-46:2,3-47:2 +mempool_remote_free --blocked-time=1 --ctl-log=1 --commit-digest=1"
L1="+lci_ndevices 1 +pemap 2 +mempool_remote_free --blocked-time=1 --ctl-log=1 --commit-digest=1"
V_END=12500000 E1=1250000 CAPX=300
cs() { # tag nodes nodelist procs:PEs:cores end arms [engine args] [perf]
  local tag=$1 N=$2 nl=$3 lay=$4 end=$5 arms=$6 extra=${7:-} pf=${8:-} ppn pepp cpt l=$L
  IFS=: read -r ppn pepp cpt <<< "$lay"; [ $pepp = 1 ] && l=$L1
  ( export NODES=$N PPN=$ppn PEPP=$pepp CPT=$cpt AGG=off WORKLOADS=vlsi:b19:1:1 ARMS="$arms" END=$end BUCKETS=2500 \
      LPC=128 LPS_PER_PE=128 EXTRA_ARGS="$l $extra" SRUN_ARGS="-w $nl"
    [ -n "$pf" ] && export BIN_WRAP=$PW PERF_DIR=$OUT/perf/charades
    RUNS=$OUT/n$N/$tag $S 1 $OUT/n$N/$tag.csv 2>/dev/null | grep -E " (ok|fail|stall) " | sed "s/^/n$N $tag /" ); }
dv() { # tag nodes nodelist procs:workers window end copies rep [perf]
  local tag=$1 N=$2 nl=$3 pw=$4 w=$5 end=$6 copies=$7 rep=$8 pf=${9:-}
  local p=${pw%%:*} wk=${pw##*:} f=$OUT/n$2/deva/$1_r$8.out
  local bin=$DB/vlsi-p${p}w${wk} wrap=""
  [ -x $bin ] || { echo "n$N dv $tag r$rep: no binary $bin"; return; }
  [ -n "$pf" ] && wrap=$PW
  mkdir -p $OUT/n$N/deva
  ( export GASNET_BACKTRACE=1 GASNET_OFI_SPAWNER=pmi FI_PROVIDER=psm2 deva_static_look_dt=$w PERF_DIR=$OUT/perf/deva
    unset FI_PROVIDER_PATH
    t0=$(date +%s.%N)
    timeout -s TERM $CAPX srun --mpi=pmi2 --kill-on-bad-exit=1 --wait=30 -J dv_${tag}_n$N -w $nl -N $N -n $p \
      --ntasks-per-node=$((p / N)) -c 24 --cpu-bind=cores -m block:block \
      $wrap stdbuf -oL $bin --netlist=$NETLIST --copies=$copies --span=1 --chunk=512 --end-time=$end > $f 2>&1
    rc=$?; wall=$(printf %.1f "$(echo "$(date +%s.%N) - $t0" | bc)")
    line=$(grep -m1 '^VLSI_RESULT' $f)
    v() { tr ' ' '\n' <<< "$line" | sed -n "s/^$1=//p"; }
    st=ok; [ -z "$line" ] && st=fail; [ $rc = 124 ] && st=stall
    echo "engine=deva app=vlsi nodes=$N layout=p${p}w$wk window=$w end=$end copies=$copies rep=$rep arm=$tag status=$st rc=$rc wall=$wall committed=$(v committed) executed=$(v executed) rolled_back=$(v rolled_back) gate_changes=$(v gate_changes) run_s=$(v wall_s) M_ev_s=$(awk -v r="$(v committed_per_s)" 'BEGIN{if (r != "") printf "%.2f", r / 1e6}') deterministic=$(v deterministic)" \
      | tee -a $OUT/deva.txt | sed "s/^/n$N /" | cut -c1-200 )
}
rev() { local a=($1) out=() i; for ((i=${#a[@]}-1; i>=0; i--)); do out+=(${a[i]}); done; echo "${out[*]}"; }
arms() { # nodes nodelist rep
  local N=$1 nl=$2 rep=$3 steps a
  steps="c_ref c_1p c_cs c_1pcs d_ref"
  [ $N = 1 ] && steps="$steps c_w10k d_w10k c_1w d_1w"
  [ $((rep % 2)) = 0 ] && steps=$(rev "$steps")
  for a in $steps; do
    case $a in
      c_ref)  cs s1_ref_r$rep  $N $nl 2:23:24 $V_END w:2500 ;;
      c_1p)   cs s1_1p_r$rep   $N $nl 1:46:48 $V_END w:2500 ;;
      c_cs)   cs s1_cs_r$rep   $N $nl 2:23:24 $V_END w:2500 "--comm-stats=1" ;;
      c_1pcs) cs s1_1pcs_r$rep $N $nl 1:46:48 $V_END w:2500 "--comm-stats=1" ;;
      c_w10k) cs s1_w10k_r$rep $N $nl 2:23:24 $V_END w:10000 ;;
      c_1w)   cs s1_1w_r$rep   $N $nl 1:1:24  $E1   w:2500 ;;
      d_ref)  dv ref  $N $nl $((2 * N)):23 2500  $V_END $N $rep ;;
      d_w10k) dv w10k $N $nl $((2 * N)):23 10000 $V_END $N $rep ;;
      d_1w)   dv 1w   $N $nl 1:1           2500  $E1    1  $rep ;;
    esac
  done; }
extras() { # nodes nodelist (rep 1 only)
  local N=$1 nl=$2
  cs pe2500 $N $nl 2:23:24 $V_END w:2500 "--pe-stats=1 --gvt-trace=1"
  if [ $N = 1 ]; then
    cs pe10k $N $nl 2:23:24 $V_END w:10000 "--pe-stats=1 --gvt-trace=1"
    cs perf $N $nl 2:23:24 $V_END w:2500 "" perf
    dv perf $N $nl 2:23 2500 $V_END 1 1 perf
  fi; }
stream() { # nodes nodelist
  local N=$1 nl=$2
  arms $N $nl 1; log "N $N REP 1 DONE"
  extras $N $nl; log "N $N EXTRAS DONE"
  arms $N $nl 2; log "N $N REP 2 DONE"; }
stream 4 $(join ${NL[@]:0:4}) > $OUT/stream_n4.log 2>&1 &
stream 1 ${NL[4]} > $OUT/stream_n1.log 2>&1 &
wait
grep -h -E ' (fail|stall) |status=(fail|stall)' $OUT/stream_n*.log | head -20
for e in charades deva; do
  f=$(ls $OUT/perf/$e/*.data 2>/dev/null | head -1)
  [ -n "$f" ] && perf report -i $f --stdio --no-children --sort dso,sym --percent-limit 0.3 2>/dev/null | head -200 > $OUT/perf/$e.report.txt
done
ls -la $OUT/perf/*.report.txt 2>/dev/null
log "VDIAG198 DONE"
