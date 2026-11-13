#!/bin/bash
# skx job: stage A rep 3 again (cut off by the end of job 3629783), then
# stages B and C, then the LCI PR psm2 check.
R=/work2/09863/rrao/stampede3/charades-runs
FIRST=3 bash $R/full_rerun2.sh A 3 > $R/full_A3.log 2>&1
bash $R/full_rerun2.sh "B C" 3 > $R/full_BC.log 2>&1
bash $R/lci_ab.sh 5 > $R/lci_ab.log 2>&1
echo CHAIN DONE >> $R/full_BC.log
