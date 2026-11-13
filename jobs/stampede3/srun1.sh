#!/bin/bash
# ctest launcher for Reconverse's tests on Stampede3 (shmpr.slurm): every
# process of a test on one node ($SHMPR_NODE), threads not pinned by srun.
# ctest calls it as: srun1.sh -n <procs> <test> <args>
exec srun --mpi=pmi2 --kill-on-bad-exit=1 -N 1 -w ${SHMPR_NODE:?} --cpu-bind=none "$@"
