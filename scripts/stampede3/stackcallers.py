#!/usr/bin/env python3
"""Read `perf script` output (stacks) on stdin; for each leaf symbol matching a
pattern, count the chain of the next few caller frames. Shares are of all samples."""
import collections, re, sys
pats = [re.compile(p) for p in sys.argv[1:]] or [re.compile('pthread_mutex')]
depth = 5
stacks = []; cur = []
for line in sys.stdin:
    if not line.strip():
        if cur: stacks.append(cur)
        cur = []
        continue
    if line[0] in ' \t':
        parts = line.split(None, 1)
        if len(parts) == 2:
            sym = re.sub(r'\+0x[0-9a-f]+', '', parts[1].rsplit(' (', 1)[0]).strip()
            cur.append(sym[:70])
if cur: stacks.append(cur)
n = len(stacks)
print('%d samples' % n)
for p in pats:
    c = collections.Counter(); tot = 0
    for s in stacks:
        if s and p.search(s[0]):
            tot += 1
            frames = [f for f in s[1:] if not f.startswith('[unknown]') and 'plt' not in f]
            c[' <- '.join(frames[:depth])] += 1
    print('\n== leaf ~ %s: %.2f%% of samples' % (p.pattern, 100.0 * tot / n))
    for k, v in c.most_common(8):
        print('  %5.2f%%  %s' % (100.0 * v / n, k))
