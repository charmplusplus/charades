#!/bin/bash
# Longer runs of all three engines, 4 nodes, Gaussian PHOLD sigma 2000:
# high slack (lookahead 100 / mean 1000, end 512,000) and low slack
# (lookahead 10 / mean 200, end 128,000); 64 ranks/PEs and full nodes
W=$WORK; out=$W/charades-runs/compare_long; mkdir -p $out
# Charades (htram PP 64, deadline margin 8; best fixed W and the controller at event share 0.001)
cd $W/charades-qd && source scripts/stampede3/env.sh
export RUNS=$out TREE=charades-qd MARGINS=8 AGG=pp:64
END=512000 WORKLOADS="gauss:100:1000:2000" ARMS="w:250 qev:0.001" scripts/stampede3/ctl_sweep.sh 2 $out/charades_hi.csv
END=128000 WORKLOADS="gauss:10:200:2000" ARMS="w:50 qev:0.001" scripts/stampede3/ctl_sweep.sh 2 $out/charades_lo.csv
PPN=2 PEPP=24 LPS_PER_PE=44 LPC=4 END=512000 WORKLOADS="gauss:100:1000:2000" ARMS="w:250" scripts/stampede3/ctl_sweep.sh 1 $out/charades_full_hi.csv
echo CHARADES DONE
# Devastator (adaptive window; ofi-psm2)
D=$W/devastator; C=ofi-psm2
for rep in 1 2; do
  END=512000 SIGMA=2000 RUNS=$out bash $D/run_phold.sh $D/bin/$C/phold-gauss-p8w8 4
  END=128000 SIGMA=2000 LOOKAHEAD=10 MEAN=200 RUNS=$out bash $D/run_phold.sh $D/bin/$C/phold-gauss-p8w8 4
done
END=512000 SIGMA=2000 LPS_PER_RANK=46 RUNS=$out bash $D/run_phold.sh $D/bin/$C/phold-gauss-p8w23 4
echo DEVA DONE
# ROSS optimistic, stock with --read-buffer=1 (psm2)
module load mvapich/3.0 >/dev/null 2>&1
unset FI_PROVIDER FI_PROVIDER_PATH
export LD_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | tr : '\n' | grep -v libfabric_ | paste -sd:)
P=$W/ROSS/build/models/phold-gauss/phold-gauss
cd $out
r() { local l=$1 N=$2 n=$3; shift 3
  timeout -s TERM 400 srun --mpi=pmi2 --kill-on-bad-exit=1 -N $N -n $n --ntasks-per-node=$((n / N)) $P --synch=3 --read-buffer=1 --start-events=15 --sigma=2000 --extramem=800000 "$@" > ross_$l.out 2>&1
  echo "ross $l rc=$? committed $(awk '/Net Events Processed/{print $NF; exit}' ross_$l.out) M ev/s $(awk '/Event Rate/{printf "%.2f", $NF/1e6; exit}' ross_$l.out) eff $(awk '/Efficiency/{print $(NF-1); exit}' ross_$l.out) time $(awk '/Running Time/{print $(NF-1); exit}' ross_$l.out)"; }
for rep in 1 2; do
  r hi_4x16_$rep 4 64 --num-lps=8192 --lookahead=100 --mean=1000 --end=512000
  r lo_4x16_$rep 4 64 --num-lps=8192 --lookahead=10 --mean=200 --end=128000
done
r hi_4x48 4 192 --num-lps=8448 --lookahead=100 --mean=1000 --end=512000
echo ALL DONE
