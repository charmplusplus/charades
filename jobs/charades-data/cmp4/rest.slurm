#!/bin/bash -l
#SBATCH -J cmp4rest
#SBATCH -p skx
#SBATCH -N 4
#SBATCH --ntasks-per-node=48
#SBATCH -t 02:00:00
#SBATCH -A TG-ASC050039N
#SBATCH -o /work2/09863/rrao/stampede3/charades-runs/cmp4/rest_%j.out
# Rep 3 of the three-engine comparison, then whatever of rep 2 job 3633783 cut off.
R=/work2/09863/rrao/stampede3/charades-runs; C=$R/cmp4
cd $R
TUNE=0 bash cmp4_rest.sh 3 3 >> $C/log_r3.txt 2>&1
b="adapt"
[ "$(grep -cE "_w[0-9]+_r2 " $C/deva/results.txt)" -ge 39 ] || b="deva $b"
[ "$(grep -c "_r2 rc" $C/ross/results.txt)" -ge 9 ] || b="ross $b"
{ [ "$(grep -c ",ok,\|,stall,\|,fail," $C/hi_off_r2.csv 2>/dev/null)" -ge 9 ] && [ "$(grep -c ",ok,\|,stall,\|,fail," $C/lo_off_r2.csv 2>/dev/null)" -ge 3 ]; } || b="off $b"
[ "$(grep -c ",ok,\|,stall,\|,fail," $C/ph_pp_r2.csv 2>/dev/null)" -ge 8 ] || b="pp $b"
echo "rep 2 leftovers: $b" >> $C/log_r3.txt
TUNE=0 BLOCKS="$b" bash cmp4_rest.sh 2 2 >> $C/log_r3.txt 2>&1
