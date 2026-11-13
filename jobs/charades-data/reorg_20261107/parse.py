import re, json
L = open('/Users/ritvik/charades/RESULTS.md').read().split('\n')
s0 = L.index('## Stampede3 runs, in order'); s1 = L.index('## Baseline verification on the Mac')
hl = [i for i in range(s0, s1) if L[i].startswith('### ')]
idx = {}
for l in L[160:415]:
    m = re.match(r'\| (\d+) \| ([^|]*) \| ([^|]*) \| (.*) \| ([^|]*) \|\s*$', l)
    if m: idx[int(m.group(1))] = dict(date=m.group(2).strip(), job=m.group(3).strip(), run=m.group(4).strip(), status=m.group(5).strip())
secs = {}
for k, i in enumerate(hl, 1):
    n = 0 if k == 1 else (k - 1 if k <= 115 else k - 2)
    end = hl[k] if k < len(hl) else s1
    secs.setdefault(n, dict(n=n, heads=[], lines=[]))
    secs[n]['heads'].append(L[i]); secs[n]['lines'].append((i, end))
for n, s in secs.items(): s.update(idx.get(n, dict(date='2026-10-19', job='—', run=s['heads'][0][4:], status='historical')))
json.dump(secs, open('/private/tmp/claude-501/-Users-ritvik/c7e3af75-4002-496f-9d21-06bf9bc195f4/scratchpad/reorg/secs.json', 'w'), ensure_ascii=False)
print(len(secs), 'sections;', sum(len(s['heads']) for s in secs.values()), 'headings;', 'missing index rows:', [n for n in secs if n not in idx])
