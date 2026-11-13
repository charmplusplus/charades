import re, collections
L = open('stub_cmds.txt').read().strip().split('\n')
FORBID = re.compile(r'--blocked-time|--ctl-log|--commit-digest|--stats|--comm-stats|trace|--commit-log|--report-interval|--trace-lp|\+trace')
bad = [l for l in L if FORBID.search(l)]
print('commands %d; with a diagnostic flag: %d' % (len(L), len(bad)))
g = collections.defaultdict(lambda: collections.Counter())
for l in L:
    if '/charades-r5/models/' in l:
        p = re.search(r'/stub/n(\d+)/(\S+?)/ctl_sweep/(\S+) \S+/test_configs/(\S+) (.*)$', l)
        N, tag, cfg, gcfg, rest = p.groups()
        cell = re.sub(r'_r\d$|_\d+$', '', tag)
        w = re.search(r'--optimism-window=(\d+)', rest)
        arm = 'W' if w else ('ctl' if '--ctl=3' in rest else '?')
        flags = re.sub(r'--optimism-window=\d+', '--optimism-window=W', rest)
        g[('Charades n%s %s' % (N, cell), re.sub(r'_\d+_15_', '_<lps>_15_', cfg) + ' ' + gcfg + ' | ' + flags)][arm] += 1
    elif 'ROSS/build' in l:
        b = re.search(r'models/(\S+?)/(\S+)', l).group(2)
        tag = re.search(r'-J (\S+)', l).group(1)
        n = re.search(r' -N (\d+) -n (\d+)', l).groups()
        args = l.split(b, 1)[1].strip()
        args = re.sub(r'--max-opt-lookahead=\d+', '--max-opt-lookahead=X', args)
        g[('ROSS n%s %s' % (n[0], re.sub(r'_(opt|cons|optw\d+|w\d+)_r\d.*|_n\d+$', '', tag.replace('ross_', ''))), '-n %s %s %s' % (n[1], b, args))][re.sub(r'.*?_(opt|cons|optw\d+|w\d+)_.*', r'\1', tag)] += 1
    else:
        m = re.search(r'(phold-gauss|traffic|dragonfly)-p(\d+)w23', l)
        tag = re.search(r'-J (\S+)', l).group(1)
        args = l.split(m.group(0), 1)[1].strip()
        srun = re.sub(r' -J \S+| -w \S+', '', l.split(' stdbuf')[0])
        cell = re.sub(r'^(pg_|dv_)', '', re.sub(r'_w?\d+_r\d.*$|_n\d+$', '', tag))
        g[('Devastator p%s %s' % (m.group(2), cell), srun + ' | ' + args)][re.sub(r'.*_w?(\d+)_r\d.*', r'\1', tag)] += 1
tot = collections.Counter()
for (k, v), c in sorted(g.items()):
    tot[k.split()[0]] += sum(c.values())
    print('%s: %s\n    %s' % (k, dict(sorted(c.items())), v[:400]))
print('totals', dict(tot))
