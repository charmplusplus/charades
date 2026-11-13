#!/bin/bash
# Devastator: pick a conduit (exact-count smoke test), then Gaussian PHOLD at
# our settings: 4 nodes x 2 processes x 8 workers (64 ranks, 8,192 LPs) and
# x 23 workers (184 ranks, 8,464 LPs), sigma 100 and 2,000, both slack levels
D=$WORK/devastator
bash -l $D/smoke_conduits.sh 4
C=$(cat $D/runs/conduit_choice.4n 2>/dev/null)
echo "conduit: ${C:-none}"
[ -n "$C" ] || exit 1
R=$D/run_phold.sh
for s in 2000 100; do
  END=64000 SIGMA=$s bash $R $D/bin/$C/phold-gauss-p8w8 4
done
END=64000 SIGMA=2000 LOOKAHEAD=10 MEAN=200 bash $R $D/bin/$C/phold-gauss-p8w8 4
END=64000 SIGMA=2000 WINDOW=250 bash $R $D/bin/$C/phold-gauss-p8w8 4
END=64000 SIGMA=2000 LPS_PER_RANK=46 bash $R $D/bin/$C/phold-gauss-p8w23 4
END=64000 SIGMA=2000 LPS_PER_RANK=46 LOOKAHEAD=10 MEAN=200 bash $R $D/bin/$C/phold-gauss-p8w23 4
END=64000 SIGMA=2000 bash $R $D/bin/$C/phold-gauss-p8w8 4
echo DEVA DONE
cat $D/runs/results.txt | tail -12
