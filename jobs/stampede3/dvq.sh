# dvq.sh <tag> <binary> <tasks> <cpus per task> <W> [VAR=value ...]: one Devastator VLSI run (b19 x 1) on the idev node
W=/work2/09863/rrao/stampede3; DB=$W/devastator/bin/ofi-psm2; out=$W/charades-runs/devap1/dvq; mkdir -p $out
tag=$1 bin=$2 n=$3 c=$4 w=$5; shift 5
f=$out/${tag}_w$w.out
env "$@" GASNET_BACKTRACE=1 GASNET_OFI_SPAWNER=pmi FI_PROVIDER=psm2 deva_static_look_dt=$w FI_PROVIDER_PATH= \
  timeout -s TERM 120 srun --mpi=pmi2 --kill-on-bad-exit=1 -N 1 -n $n --ntasks-per-node=$n -c $c ${BIND:---cpu-bind=cores} -m ${DIST:-block:block} \
  stdbuf -oL $DB/$bin --netlist=$W/I99T/i99t/b19/b19.bench --copies=1 --span=1 --chunk=512 --end-time=12500000 > $f 2>&1
printf "%-28s W %5s %-26s %s\n" "$tag" "$w" "$*" "$(grep -m1 -o "committed=[0-9]* .*committed_per_s=[^ ]*" $f | sed "s/ executed.*committed_per_s=/ rate=/" || echo FAILED)"
