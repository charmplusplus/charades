#!/bin/bash -l
# Quick check (20 s caps): do launcher-less one-process tests hang because PSM2 pins the process to one core?
W=/work2/09863/rrao/stampede3; B=${1:-$W/reconverse-shmpr/build}
export XPORT=psm2 LCI_ATTR_PACKET_SIZE=65536
source $W/charades-shm-pr/scripts/stampede3/env.sh >/dev/null 2>&1
cmd() { grep -h "add_test($1 " $B/tests -r --include=CTestTestfile.cmake | head -1 | sed -e "s/add_test($1 //" -e 's/)$//' -e 's/"//g'; }
for t in pingpong_multipairs fanout_refcount-onepe nodeq_sharing randomized_msgq-fifo ipc-onenode; do
  c=$(cmd $t); [ -z "$c" ] && { echo "$t: no command"; continue; }
  for v in pinned HFI_NO_CPUAFFINITY=1; do
    t0=$(date +%s.%N)
    if [ $v = pinned ]; then
      $c > /tmp/h20.out 2>&1 & p=$!
      sleep 3; psr=$(ps -L -o psr= -p $p 2>/dev/null | sort -u | tr '\n' ' ')
    else
      env HFI_NO_CPUAFFINITY=1 $c > /tmp/h20.out 2>&1 & p=$!
      sleep 3; psr=$(ps -L -o psr= -p $p 2>/dev/null | sort -u | tr '\n' ' ')
    fi
    for i in $(seq 17); do kill -0 $p 2>/dev/null || break; sleep 1; done
    if kill -0 $p 2>/dev/null; then kill -TERM $p; sleep 1; kill -KILL $p 2>/dev/null; st=HUNG; else wait $p; st="rc=$?"; fi
    printf "%-24s %-22s %-7s %5.1f s  cores of its threads at 3 s: %s\n" $t $v "$st" $(echo "$(date +%s.%N) - $t0" | bc) "$psr"
  done
done
