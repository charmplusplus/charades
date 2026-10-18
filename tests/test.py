"""Charades correctness tests for Charm++ on Reconverse.

Every model configuration carries an expected-events value that the simulator
checks itself (it aborts on a mismatch), so a test passes when the run exits 0
and reports success. Each model configuration is run under every
synchronization configuration in test_configs/, at several PE counts, in one
process and across processes.

Usage: python3 test.py [--quick] [--all] [--no-build] [--launcher lcrun|srun]
                       [--timeout SECONDS] [test_config ...]
"""

import argparse
import glob
import os
import platform
import signal
import subprocess
import sys
import time

test_dir = os.path.dirname(os.path.abspath(__file__))
src_dir = os.path.join(test_dir, '..', 'src')
model_dir = os.path.abspath(os.path.join(test_dir, '..', 'models'))

# Known to hang at more than one PE on every runtime (not Reconverse-specific):
# the CD GVT, and the phased GVT (issue #11). Run them with --all.
KNOWN_BROKEN = {'cd', 'phased'}


def charm_dir():
  """CHARM_DIR from src/config.mk, which the model Makefiles also use."""
  with open(os.path.join(src_dir, 'config.mk')) as f:
    for line in f:
      key, _, value = line.partition('=')
      if key.strip() == 'CHARM_DIR':
        return value.strip()
  sys.exit('CHARM_DIR not set in src/config.mk')


class Launch:
  """How to start a run: number of processes and total PEs."""
  def __init__(self, procs, pes):
    self.procs, self.pes = procs, pes
    self.name = str(pes) if procs == 1 else '%dx%d' % (procs, pes // procs)

  def command(self, exe, args, launcher):
    run = [exe, '+pe', str(self.pes)] + args
    if self.procs == 1:
      return run
    if launcher.kind == 'srun':
      return ['srun', '--mpi=pmi2', '-n', str(self.procs)] + run
    return [launcher.lcrun, '-n', str(self.procs)] + run


class Launcher:
  def __init__(self, kind, charm):
    self.kind = kind
    self.lcrun = None
    if kind == 'lcrun':
      found = glob.glob(os.path.join(charm, '*', '_deps', 'lci-src', 'lcrun'))
      self.lcrun = found[0] if found else None


class Model:
  def __init__(self, name, root, exe):
    self.name, self.root = name, os.path.join(model_dir, root)
    self.exe = os.path.join(self.root, exe)
    cfg_dir = os.path.join(self.root, 'test_configs')
    self.cfgs = sorted(os.path.join(cfg_dir, c) for c in os.listdir(cfg_dir)
                       if os.path.isfile(os.path.join(cfg_dir, c)))


MODELS = [
  Model('Simple PHOLD', 'phold/simple', 'phold'),
  Model('Imbalanced PHOLD', 'phold/imbalanced', 'phold'),
  Model('Example', 'example', 'example'),
]


def main():
  parser = argparse.ArgumentParser(description='Run the Charades test matrix.')
  parser.add_argument('configs', nargs='*',
                      help='test_configs to run (default: all working ones)')
  parser.add_argument('--quick', action='store_true',
                      help='only +pe 1, +pe 4 and 2 processes x 2 PEs')
  parser.add_argument('--all', action='store_true',
                      help='include the known-broken GVTs (cd, phased)')
  parser.add_argument('--no-build', action='store_true',
                      help='do not rebuild the models first')
  parser.add_argument('--launcher', choices=['lcrun', 'srun'],
                      default='lcrun',
                      help='multi-process launcher: lcrun (Mac) or srun')
  # Generous for Reconverse builds without the idle-progress-poll scheduler
  # fix, where each quiescence-detection GVT round costs ~11 ms with one PE
  # per process and the conservative long config takes ~70-80 s at 2x1 and
  # 4x1. With the fix the slowest run takes ~5 s.
  parser.add_argument('--timeout', type=float, default=180.0,
                      help='seconds before a run counts as hung')
  opts = parser.parse_args()

  charm = charm_dir()
  launcher = Launcher(opts.launcher, charm)
  env = dict(os.environ)
  libvar = 'DYLD_LIBRARY_PATH' if platform.system() == 'Darwin' \
      else 'LD_LIBRARY_PATH'
  env[libvar] = os.path.join(charm, 'lib') + \
      (':' + env[libvar] if env.get(libvar) else '')

  cfg_path = os.path.join(test_dir, 'test_configs')
  names = sorted(os.listdir(cfg_path))
  if opts.configs:
    unknown = set(opts.configs) - set(names)
    if unknown:
      sys.exit('Unknown test configs: ' + ', '.join(sorted(unknown)))
    names = [n for n in names if n in opts.configs]
  elif not opts.all:
    names = [n for n in names if n not in KNOWN_BROKEN]

  launches = [Launch(1, 1), Launch(1, 2), Launch(1, 3), Launch(1, 4),
              Launch(2, 2), Launch(2, 4), Launch(4, 4)]
  if opts.quick:
    launches = [Launch(1, 1), Launch(1, 4), Launch(2, 4)]
  if opts.launcher == 'lcrun' and launcher.lcrun is None:
    print('lcrun not found under %s; skipping multi-process runs' % charm)
    launches = [l for l in launches if l.procs == 1]

  if not opts.no_build:
    for m in MODELS:
      subprocess.run(['make', '-s', '-C', m.root], check=True)

  results = []
  for m in MODELS:
    for mcfg in m.cfgs:
      for name in names:
        tcfg = os.path.join(cfg_path, name)
        for launch in launches:
          # The sequential scheduler only runs on one PE.
          if name == 'sequential' and launch.pes > 1:
            continue
          results.append(run(m, mcfg, name, tcfg, launch, launcher, env,
                             opts.timeout))

  passed = sum(r == 'pass' for r in results)
  failed = sum(r == 'fail' for r in results)
  hung = sum(r == 'timeout' for r in results)
  print('================')
  print('Passed:    %d/%d' % (passed, len(results)))
  print('Failed:    %d/%d' % (failed, len(results)))
  print('Timed out: %d/%d' % (hung, len(results)))
  sys.exit(0 if passed == len(results) else 1)


def run(model, mcfg, name, tcfg, launch, launcher, env, timeout):
  outdir = os.path.join(test_dir, 'test_output',
                        os.path.relpath(model.root, model_dir),
                        os.path.basename(mcfg), name, launch.name)
  os.makedirs(outdir, exist_ok=True)
  out_path = os.path.join(outdir, 'test.out')
  cmd = launch.command(model.exe, [mcfg, tcfg], launcher)
  label = '%-17s %-8s %-19s %-5s' % (model.name, os.path.basename(mcfg),
                                    name, launch.name)
  start = time.time()
  with open(out_path, 'w') as out:
    # Own process group, so a hung multi-process run's ranks die with the
    # launcher instead of lingering and skewing later runs.
    proc = subprocess.Popen(cmd, stdout=out, stderr=subprocess.STDOUT,
                            cwd=outdir, env=env, start_new_session=True)
    try:
      rc = proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
      os.killpg(proc.pid, signal.SIGKILL)
      proc.wait()
      rc = None
  elapsed = time.time() - start
  with open(out_path) as out:
    ok = 'Simulation Executed Successfully!' in out.read()
  if rc is None:
    status = 'timeout'
  elif rc == 0 and ok:
    status = 'pass'
  else:
    status = 'fail'
  print('%s %-7s %6.2fs%s' % (label, status.upper(), elapsed,
                              '' if status == 'pass' else '  ' + out_path))
  return status


if __name__ == '__main__':
  main()
