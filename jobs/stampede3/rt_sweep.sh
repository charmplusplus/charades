#!/bin/bash
# Runtime settings sweep on the production build (charades-prod), 4 nodes,
# Gaussian PHOLD sigma 2,000, high slack, end 512,000, W 250, htram PP 64.
# One factor at a time from the base: 2 processes x 23 PEs per node, pinned by
# +pemap to one socket each (cores 0 and 1 left for the OS), +lci_ndevices 8.
W=/work2/09863/rrao/stampede3; OUT=$W/charades-runs/rtsweep; mkdir -p $OUT
cd $W/charades-qd && source scripts/stampede3/env.sh
S=$W/charades-qd/scripts/stampede3/ctl_sweep.sh
export TREE=charades-prod MARGINS=8 AGG=pp:64 LPS_PER_PE=128 LPC=16 END=512000 \
  WORKLOADS="gauss:100:1000:2000" ARMS="w:250"
P2="+pemap 2-46:2,3-47:2"                 # 2 procs/node x 23 PEs
P1="+pemap 2-46:2,3-47:2"                 # 1 proc/node x 46 PEs
P4="+pemap 2-22:2,26-46:2,3-23:2,27-47:2" # 4 procs/node x 11 PEs
P2_64="+pemap 2-16:2,3-17:2"              # 2 procs/node x 8 PEs
run() {  # name, then VAR=value ... for this config
  local name=$1; shift
  ( export "$@"; RUNS=$OUT/$name $S 1 $OUT/${name}_r$rep.csv | grep -E " (ok|fail|stall) " | sed "s/^/$name /" )
}
# smoke: does the pemap bind where we think?
RUNS=$OUT/smoke PPN=2 PEPP=23 CPT=24 END=64000 EXTRA_ARGS="+lci_ndevices 8 $P2 +showcpuaffinity" $S 1 $OUT/smoke.csv
grep -hE "affinity|set PE (0|22|23|45|46) " $OUT/smoke/ctl_sweep/logs/*.out | sort -u | head -12
for rep in 1 2; do
  echo "=== rep $rep"
  # 1. layout and pinning
  run old_2x24_nopin  PPN=2 PEPP=24 "EXTRA_ARGS=+lci_ndevices 8"
  run 2x23_nopin      PPN=2 PEPP=23 CPT=24 "EXTRA_ARGS=+lci_ndevices 8"
  run base_2x23_pin   PPN=2 PEPP=23 CPT=24 "EXTRA_ARGS=+lci_ndevices 8 $P2"
  run 1x46_pin        PPN=1 PEPP=46 CPT=48 SRUN_ARGS=--cpu-bind=none "EXTRA_ARGS=+lci_ndevices 8 $P1"
  run 4x11_pin        PPN=4 PEPP=11 CPT=12 SRUN_ARGS=--cpu-bind=none "EXTRA_ARGS=+lci_ndevices 8 $P4"
  # 2. LCI devices
  for d in 1 2 4 16 23; do
    run 2x23_pin_ndev$d PPN=2 PEPP=23 CPT=24 "EXTRA_ARGS=+lci_ndevices $d $P2"
  done
  # 3. progress polling: which threads poll, and how often
  for t in 2 4 23; do
    run 2x23_pin_pollthread$t PPN=2 PEPP=23 CPT=24 "EXTRA_ARGS=+lci_ndevices 8 $P2 +backend_poll_thread $t"
  done
  for f in 16 256; do
    run 2x23_pin_pollfreq$f PPN=2 PEPP=23 CPT=24 "EXTRA_ARGS=+lci_ndevices 8 $P2 +backend_poll_freq $f"
  done
  # 4. LCI packet size
  for ps in 16384 32768; do
    run 2x23_pin_pkt$ps PPN=2 PEPP=23 CPT=24 LCI_ATTR_PACKET_SIZE=$ps "EXTRA_ARGS=+lci_ndevices 8 $P2"
  done
  # 5. 64-core layout, pinned or not
  run 64_2x8_nopin PPN=2 PEPP=8 "EXTRA_ARGS=+lci_ndevices 8"
  run 64_2x8_pin   PPN=2 PEPP=8 CPT=24 "EXTRA_ARGS=+lci_ndevices 8 $P2_64"
done
echo SWEEP DONE
