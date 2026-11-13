"""Flag audit for jobs P64, A64 and V8 (charades results/phold.md section 262):
every command of a stub run, grouped by cell and arm, with its flags; any
diagnostic flag is an error."""
import re, sys, collections
FORBID = re.compile(r'--blocked-time|--ctl-log|--stats|--comm-stats|trace|--commit-log|--report-interval|--trace-lp|\+trace|--pe-stats|--copy-stats')
for f in sys.argv[1:]:
    L = open(f).read().strip().split('\n')
    print('#', f, 'commands %d' % len(L))
    dig = [l for l in L if '--commit-digest' in l]
    bad = [l for l in L if FORBID.search(l)]
    print('  with a diagnostic flag: %d; with --commit-digest (check arms): %d' % (len(bad), len(dig)))
    g = collections.defaultdict(collections.Counter); tot = collections.Counter()
    for l in L:
        if '/charades-r5/models/' in l:
            p = re.search(r'/(?:stub\w*)/n(\d+)/(\S+?)/ctl_sweep/(\S+) \S+/test_configs/(\S+) (.*)$', l)
            N, tag, cfg, gcfg, rest = p.groups()
            ppn = re.search(r'--ntasks-per-node[= ](\d+)', l); cpt = re.search(r'(?:-c|--cpus-per-task)[= ](\d+)', l)
            cell = re.sub(r'_r\d$|/r\d/.*$|/warm/.*$', '', tag)
            w = re.search(r'--optimism-window=(\d+)', rest)
            arm = ('W%s' % w.group(1)) if w else ('ctl' if '--ctl=3' in rest else '?')
            flags = re.sub(r'--optimism-window=\d+', '--optimism-window=W', rest)
            layout = 'ppn %s c %s' % (ppn.group(1) if ppn else '?', cpt.group(1) if cpt else '?')
            g[('Charades n%s %s' % (N, cell), layout + ' | ' + re.sub(r'_\d+_15_', '_<lps>_15_', cfg) + ' ' + gcfg + ' | ' + flags)][arm] += 1; tot['Charades'] += 1
        elif 'ROSS/build' in l:
            b = re.search(r'models/(\S+?)/(\S+)', l).group(2)
            tag = re.search(r'-J (\S+)', l).group(1)
            n = re.search(r' -N (\d+) -n (\d+)', l).groups()
            args = re.sub(r'--max-opt-lookahead=(\d+)', r'--max-opt-lookahead=X', l.split(b, 1)[1].strip())
            arm = re.sub(r'^ross_', '', tag); arm = re.sub(r'_n\d+$', '', arm)
            cell = re.sub(r'_(opt|cons|optw\d+|w\d+)(_r\d)?$', '', re.sub(r'_r\d$', '', arm))
            mo = re.search(r'--max-opt-lookahead=(\d+)', l)
            g[('ROSS n%s %s' % (n[0], cell), '-n %s %s %s' % (n[1], b, args))][re.sub(r'.*_(opt|cons|optw\d+|w\d+)(_r\d)?$', r'\1', re.sub(r'_r\d$', '', arm))] += 1; tot['ROSS'] += 1
        else:
            m = re.search(r'(phold-gauss|traffic|dragonfly|vlsi)-p(\d+)w23', l)
            if not m: print('  UNKNOWN', l[:200]); continue
            tag = re.search(r'-J (\S+)', l).group(1)
            args = l.split(m.group(0), 1)[1].strip()
            srun = re.sub(r' -J \S+| -w \S+', '', l.split(' stdbuf')[0].split(' ' + m.group(0))[0])
            g[('Devastator %s p%s' % (m.group(1), m.group(2)), srun + ' | ' + args)][re.sub(r'^(pg_|dv_)', '', tag)] += 1; tot['Devastator'] += 1
    for (k, v), c in sorted(g.items()):
        print('  %s: %s\n      %s' % (k, dict(sorted(c.items())), v[:420]))
    print('  totals', dict(tot)); print()
