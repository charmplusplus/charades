import re, collections
L = open('stub_cmds.txt').read().strip().split('\n')
FORBID = re.compile(r'--blocked-time|--ctl-log|--commit-digest|--stats|--comm-stats|trace|--commit-log|--trace-lp|\+trace|--log')
groups = collections.defaultdict(list); bad = []
for l in L:
    if FORBID.search(l): bad.append(l)
    t = l.split()
    if 'phold-gauss-p' in l:   # Devastator
        lab = re.search(r'-J pg_(\S+)', l).group(1)
        m = re.match(r'(warm_\w+|d_(\w+?)_(\d+)_w(\d+)_r(\d))$', lab)
        binary = re.search(r'phold-gauss-p\d+w23', l).group(0)
        srun = l.split(' stdbuf')[0]
        srun = re.sub(r' -J \S+', '', re.sub(r'-w \S+', '-w <nodes>', srun))
        args = l.split(binary)[1].strip()
        if m.group(1).startswith('warm'): key = ('D-warm', m.group(1))
        else: key = ('D', m.group(2) + '_' + m.group(3))
        groups[key].append((srun + ' ' + binary, args, m.group(4) if not m.group(1).startswith('warm') else 'warm'))
    else:   # Charades
        p = re.search(r'/stub/n(\d+)/(\S+?)/ctl_sweep/(\S+) (\S+/test_configs/\S+) (.*)$', l)
        N, tag, cfg, gcfg, rest = p.groups()
        binary = re.search(r'models/\S+', l).group(0)
        srun = re.sub(r' -J \S+', '', re.sub(r'-w \S+', '-w <nodes>', l.split(' numactl')[0]))
        w = re.search(r'--optimism-window=(\d+)', rest)
        arm = 'W' + w.group(1) if w else ('ctl' if '--ctl=3' in rest else '?')
        flags = re.sub(r'--optimism-window=\d+ ', '--optimism-window=W ', rest)
        part = 'C' if tag.startswith('c_') else ('D-C' if tag.startswith('d_') else 'C-warm')
        cell = re.sub(r'_r\d$', '', tag)
        groups[(part, cell + ' n' + N)].append((srun + ' numactl --localalloc ' + binary.split('/')[-1] + ' +pe ' + re.search(r'\+pe (\d+)', l).group(1) + ' ' + re.sub(r'.*/', '', cfg) + ' ' + gcfg.split('/')[-1], flags, arm))
print('commands %d; with a diagnostic flag: %d' % (len(L), len(bad)))
for b in bad[:5]: print('  BAD', b[:300])
tot = collections.Counter()
for k in sorted(groups):
    v = groups[k]; tot[k[0]] += len(v)
    arms = collections.Counter(a for _, _, a in v)
    print('\n%s %s: %d runs; arms %s' % (k[0], k[1], len(v), dict(sorted(arms.items()))))
    for (launch, flags) in sorted({(s, f) for s, f, _ in v}):
        print('   launch:', launch); print('   flags :', flags)
print('\ntotals', dict(tot))
