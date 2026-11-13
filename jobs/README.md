# Job, build and analysis scripts

These are the scripts behind the measurements in [`RESULTS.md`](../RESULTS.md) and [`results/`](../results/). They are copied here with their original relative paths, so a path the notebook cites can be found directly:

| the notebook says | the file is in |
|---|---|
| `~/charades-data/<path>` (the Mac, where jobs were designed and analysed) | [`charades-data/<path>`](charades-data/) |
| `$WORK/charades-runs/<path>` (Stampede3, where jobs ran) | [`stampede3/<path>`](stampede3/) |

**What is here:**
- **`charades-data/`:** Slurm job scripts, analysis scripts (`*.py`), shell scripts, `flag_table*.txt` and `stub_cmds*.txt` (the per-arm flags and the srun commands from each job's stub run, checked before submitting), and the `*summary*.txt` outputs the notebook's numbers come from. Collected 2026-11-13; 385 files.
- **`stampede3/`:** the scripts in Stampede3's run folder: Slurm jobs, interactive-session scripts, runtime build scripts (`build_perf.sh`, `build_charades_perf.sh`, `rebuild_perf.sh`, `build_charm.sh`, `build_perfshm.sh`), `env.sh`, the `perfwrap_*.sh` profiling wrappers, the diagnostic patches that were applied there, and `f4b250/stubbin/srun` (the fake srun the stub runs use). Collected 2026-11-13; 323 files. Many are one-off diagnostics from October.
- **Some files exist in both folders** under the same name. Where they differ (`repro.sh`, `scale.slurm`, `hang20s.sh`), the `stampede3/` copy is the one that ran.

**Not here:**
- Run outputs and raw data (about 16 GB on the Mac, more on Stampede3).
- Profiles and traces.
- The `ctl_sweep` and `logs` folders inside each job's output.

**Paths are absolute.** The scripts assume the original layout:
- `$WORK` = `/work2/09863/rrao/stampede3`;
- Charades trees in `$WORK/charades-<name>`;
- the runtime in `$WORK/charm-pads-perf`;
- htram in `$WORK/htram-<name>`;
- analysis folders under `~/charades-data`.

**The code the paper runs used:**

| component | where |
|---|---|
| Charades | this repository: `charades-r5` = 85a2aad (F1, P64, A64 and the other paper tables), `charades-r6` = 9f7480a (padded local 1 and later) |
| htram | [UIUC-PPL/htram](https://github.com/UIUC-PPL/htram), branch `pdes` (978e065 for `charades-r6`) |
| Reconverse | [charmplusplus/reconverse](https://github.com/charmplusplus/reconverse), branch `pads27-runtime` (75719d5; `$WORK/charm-pads-perf`); `pads27-runtime-shm` (371fdc8) for the shared-memory pool runs |
| LCI | [ritvikrao/lci](https://github.com/ritvikrao/lci), branch `pads27-psm2` (82ff447: upstream ca88ce2c plus the first version of the native psm2 change later merged, revised, as uiuc-hpc/lci#214). The runtime was built with `FETCHCONTENT_SOURCE_DIR_LCI` pointing at this tree; see `stampede3/build_perf.sh` |
| Charm++ | [charmplusplus/charm](https://github.com/charmplusplus/charm), commit 9d6a55780 on branch `recharm`, with `contrib/reconverse` at the Reconverse commit above |
| ROSS | [ritvikrao/ROSS](https://github.com/ritvikrao/ROSS), branch `pads27` (models phold-gauss, traffic, dragonfly, vlsi on dc3a6a0). Branch `early-anti-messages` holds a fix not used in the runs, which used `--read-buffer=1` |
| Devastator | [ritvikrao/devastator](https://github.com/ritvikrao/devastator), branch `pads27` (Charades-matched benchmarks, opt-in GASNet configure flags, and the Stampede3 build scripts in `stampede3/`) |
