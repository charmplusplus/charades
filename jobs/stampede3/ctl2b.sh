#!/bin/bash
# Follow-ups to ctl2.sh in the same allocation:
# (1) perf: where the controller's cost goes (fixed W 250 with the controller
#     running vs not), lookahead 100 / mean 1000, sigma 2000;
# (2) kappa 0.20 with the histogram every 32nd wave, alpha from 1 or 0.006.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/ctl2; S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export NODES=4 LPS_PER_PE=128 LPC=16 CAP=120
P="+lci_ndevices 16 +pemap 2-46:2,3-47:2"
NODE0=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -1)
log() { echo "[$(date +%T)] $*"; }
cs() { ( export TREE=$2 AGG=$3 END=$4 WORKLOADS="$5" ARMS="$6" EXTRA_ARGS="$P $7"
    RUNS=$OUT/$1 $S 1 $OUT/$1_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$1 /" ); }
perf_node0() {  # name delay secs
  sleep $2
  ssh -o "StrictHostKeyChecking no" -o LogLevel=ERROR $NODE0 "
    pids=\$(pgrep -u \$USER '^phold\$' | paste -sd,)
    perf stat -e task-clock,cycles,instructions -p \$pids -- sleep 2 2> $OUT/perfstat_$1.txt >/dev/null
    perf record -q -F 499 --call-graph lbr -p \$pids -o /tmp/perf_$1.data -- sleep $3 >/dev/null 2>&1
    perf report -i /tmp/perf_$1.data --stdio --no-children --sort dso,symbol --percent-limit 0.1 2>/dev/null | grep -E '^ +[0-9]' | head -120 > $OUT/perf_$1_self.txt
    perf report -i /tmp/perf_$1.data --stdio --children --sort symbol -g none --percent-limit 0.3 2>/dev/null | grep -E '^ +[0-9]' | head -150 > $OUT/perf_$1_incl.txt"
}
rep=1
for arm in w:250 dry:250; do
  log "perf $arm"
  ( export TREE=charades-ctl AGG=pp:512 END=4096000 WORKLOADS="gauss:100:1000:2000" ARMS="$arm" EXTRA_ARGS="$P"
    RUNS=$OUT/perf_${arm/:/} $S 1 $OUT/perf_${arm/:/}.csv | grep -E " (ok|fail|stall) " ) &
  sp=$!; perf_node0 ${arm/:/} 7 5; wait $sp
done
K20="--ctl-agg-kappa=0.20 --ctl-hist-waves=32"
for rep in 1 2 3; do
  cs hi_b charades-ctl pp:512 512000 "gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0" "w:250 w:300"
  cs hi_k20 charades-ctl pp:512 512000 "gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0" "q:0.001" "$K20"
  cs hi_k20a charades-ctl pp:512 512000 "gauss:100:1000:100 gauss:100:1000:2000 steady:100:1000:1.0" "q:0.001" "$K20 --ctl-alpha-init=0.006"
  cs lo_b charades-ctl pp:512 128000 "gauss:10:200:500 gauss:10:200:2000 steady:10:200:1.0" "w:50"
  cs lo_k20 charades-ctl pp:512 128000 "gauss:10:200:500 gauss:10:200:2000 steady:10:200:1.0" "q:0.001" "$K20"
  cs lo_k20a charades-ctl pp:512 128000 "gauss:10:200:500 gauss:10:200:2000 steady:10:200:1.0" "q:0.001" "$K20 --ctl-alpha-init=0.006"
  cs ph_b charades-ctl pp:512 256000 "phases:10:200:100:1000:1.0:32000 phases:10:200:100:1000:0.5:32000" "w:100"
  cs ph_k20 charades-ctl pp:512 256000 "phases:10:200:100:1000:1.0:32000 phases:10:200:100:1000:0.5:32000" "q:0.001" "$K20"
  cs ph_k20a charades-ctl pp:512 256000 "phases:10:200:100:1000:1.0:32000 phases:10:200:100:1000:0.5:32000" "q:0.001" "$K20 --ctl-alpha-init=0.006"
  cs tr_b charades-ctl pp:512 512000 "traffic:100:1000:128:15:0:0 traffic:100:1000:128:15:0.5:32" "w:250 w:500"
  cs tr_k20 charades-ctl pp:512 512000 "traffic:100:1000:128:15:0:0 traffic:100:1000:128:15:0.5:32" "q:0.001" "$K20"
  cs tr_k20a charades-ctl pp:512 512000 "traffic:100:1000:128:15:0:0 traffic:100:1000:128:15:0.5:32" "q:0.001" "$K20 --ctl-alpha-init=0.006"
  log "B REP $rep DONE"
done
log "CTL2B DONE"
