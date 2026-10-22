# Source in every shell that runs Charades on Stampede3 (Omni-Path).
# LCI works here over libfabric verbs;ofi_rxm (or tcp), and over native psm2
# with XPORT=psm2 below: the default ibv aborts (hfi1 reports inline size 0),
# opx fails at init. Set
# FI_PROVIDER unconditionally: the impi module exports FI_PROVIDER=opx.
export LCI_ATTR_BACKEND=ofi
export LCI_ATTR_OFI_PROVIDER_NAME="verbs;ofi_rxm"
export FI_PROVIDER=verbs,ofi_rxm
# libfabric 2.7.0 fixes the RxM-over-verbs segfault at exit (~10% of runs on
# the system 2.6.0a1). stage_libfabric.sh copies it to node-local /tmp: read
# from $WORK, a job's first launch stalled for minutes.
if [ -e /tmp/libfabric_$USER/libfabric.so.1 ]; then
    export LD_LIBRARY_PATH=/tmp/libfabric_$USER${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    export FI_PROVIDER_PATH=/tmp/no_fi_dso_$USER
else
    echo "env.sh: libfabric 2.7.0 not staged on $(hostname -s); using the system one" >&2
fi
# XPORT=psm2: LCI over Omni-Path's native psm2 provider instead. Needs an LCI
# with FI_CONTEXT and FI_SOURCE support (LCI branch ofi-psm2-native) and the
# system libfabric, since the 2.7.0 build has no psm2 provider.
if [ "${XPORT:-verbs}" = psm2 ]; then
    export LCI_ATTR_OFI_PROVIDER_NAME=psm2 FI_PROVIDER=psm2 PSM2_MULTI_EP=1
    export LD_LIBRARY_PATH=$(echo "$LD_LIBRARY_PATH" | tr : '\n' | grep -v "^/tmp/libfabric_" | paste -sd:)
    unset FI_PROVIDER_PATH
fi
# In an ssh shell on an idev node, take the job's SLURM_* variables from the
# file idev's own shell sources, so srun launches steps as at the idev prompt.
if [ -z "${SLURM_JOB_ID:-}" ]; then
    f=$(ls -t /tmp/idev_${USER}_bash_env.* 2>/dev/null | head -1)
    [ -n "$f" ] && source <(grep -E "^(export +|declare -x +)?SLURM_" "$f")
fi
