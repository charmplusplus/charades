#!/bin/bash
# Charades (1 process, 4 PEs) against Devastator (4 rank threads) on the Mac:
# rolled-back share at the same window, sigma 100 (section 146 follow-up)
C=~/charades; D=~/pdes-baselines/deva-mac/pg-threads-r4
for W in 400 800 1600; do
  f=ch_w$W.out
  perl -e 'alarm 120; exec @ARGV' $C/models/phold/simple/phold +pe 4 cfg_g100 $C/tests/test_configs/bucket --optimism-window=$W > $f 2>&1
  printf "Charades   W %-5s committed %s rolled %s rate %s ts_rb %s\n" $W "$(awk '/Events Committed/{print $NF; exit}' $f)" "$(awk '/Events Rolled Back/{print $NF; exit}' $f)" "$(awk '/Event Rate/{print $NF; exit}' $f)" "$(awk '/Timestamp Rollback Calls/{print $NF; exit}' $f)"
  r=$(deva_static_look_dt=$W perl -e 'alarm 120; exec @ARGV' $D --num-lps=512 --start-events=15 --lookahead=100 --mean=1000 --sigma=100 --end-time=512000 --rng=clcg4 2>&1 | grep PHOLD_GAUSS_RESULT)
  get() { tr ' ' '\n' <<<"$r" | sed -n "s/^$1=//p"; }
  printf "Devastator W %-5s committed %s rolled %s rate %s\n" $W "$(get committed)" "$(get rolled_back)" "$(get committed_per_s)"
done
