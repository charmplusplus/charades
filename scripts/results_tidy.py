#!/usr/bin/env python3
"""Keep the results notebook in order (results/README in RESULTS.md, "How to read it").

Each topic file results/<topic>.md has: a title and intro, a contents table,
"## Current" (intro, then sections), optional unnumbered parts ("## ..."), and
"## Earlier" (intro, then sections). A section is "### §N · title" up to the
next "### §" or "## " line. results/INDEX.md holds every section's status.

This script, from INDEX.md's statuses:
  - puts each section under Current or Earlier (superseded / historical /
    "not for use" go to Earlier; a design follows its results: "results in N",
    else the next non-design section of the same file), in number order;
  - rewrites each file's contents table;
  - checks that every §N in INDEX.md is in exactly the file INDEX.md names, and
    that no section text is lost (the multiset of non-structural lines is the
    same before and after).
Usage: results_tidy.py [--check]   (from anywhere; --check writes nothing)
"""
import collections, os, re, sys
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
RES = os.path.join(ROOT, 'results')
CHECK = '--check' in sys.argv

def read_index():
    rows = {}
    for l in open(os.path.join(RES, 'INDEX.md')).read().split('\n'):
        m = re.match(r'\| (\d+) \| ([^|]*) \| ([^|]*) \| (.*) \| ([^|]*) \| \[([\w.-]+)\]\([\w.-]+\) \|\s*$', l)
        if m: rows[int(m.group(1))] = dict(date=m.group(2).strip(), status=m.group(5).strip(), file=m.group(6))
    return rows

def parse(path):
    L = open(path).read().rstrip('\n').split('\n')
    i_cur = L.index('## Current'); i_ear = L.index('## Earlier') if '## Earlier' in L else None
    head = L[:i_cur]
    # the contents table: from '| § | date' to the first non-table line
    t0 = next(i for i, l in enumerate(head) if l.startswith('| § | date |'))
    t1 = t0
    while t1 < len(head) and head[t1].startswith('|'): t1 += 1
    pre, post = head[:t0], head[t1:]
    # parts: list of (heading line, intro lines, sections) ; sections: dict n -> lines
    parts, cur = [], None
    secs = {}
    for l in L[i_cur:]:
        if l.startswith('## '):
            cur = dict(h=l, intro=[], order=[], body=[]); parts.append(cur); sec = None; continue
        m = re.match(r'### §(\d+) · ', l)
        if m:
            if int(m.group(1)) == sec: secs[sec].append(l); continue   # a second heading of the same section (§114)
            sec = int(m.group(1)); secs[sec] = [l]; cur['order'].append(sec); continue
        if cur['order'] and sec is not None: secs[sec].append(l)
        else: cur['intro'].append(l)
    return pre, post, parts, secs

def eff(n, idx, file_secs, seen=()):
    st = idx[n]['status'].lower()
    if st.startswith('not for use') or st.startswith('superseded by'): return 'Earlier'
    if st.startswith('superseded in part'): return 'Current'
    if st.startswith('superseded') or st.startswith('historical'): return 'Earlier'
    if st.startswith('design'):
        r = re.search(r'results in (\d+)', st); tgt = int(r.group(1)) if r else None
        if tgt is None:
            for k in sorted(k for k in file_secs if k > n)[:6]:
                if not idx[k]['status'].lower().startswith('design'): tgt = k; break
        if tgt is not None and tgt in idx and tgt not in seen: return eff(tgt, idx, file_secs, seen + (n,))
    return 'Current'

def short(h):
    t = re.sub(r'^### §\d+ · ', '', h)
    t = re.sub(r'\s*\((design|implementation|analysis)?[^()]*20\d\d-\d\d-\d\d[^()]*\)\s*$', '', t)
    return t if len(t) <= 110 else t[:107].rstrip() + '…'

idx = read_index()
bad = []
seen_in = collections.defaultdict(list)
for f in sorted(os.listdir(RES)):
    if not f.endswith('.md') or f in ('INDEX.md', 'history.md'): continue
    path = os.path.join(RES, f)
    before = open(path).read()
    pre, post, parts, secs = parse(path)
    for n in secs: seen_in[n].append(f)
    for n in secs:
        if n not in idx: bad.append(f'§{n} in {f} has no INDEX row')
        elif idx[n]['file'] != f: bad.append(f'§{n} is in {f} but INDEX says {idx[n]["file"]}')
    part = {n: eff(n, idx, secs) for n in secs if n in idx}
    cur = sorted(n for n in secs if part.get(n) == 'Current'); old = sorted(n for n in secs if part.get(n) == 'Earlier')
    out = pre + ['| § | date | status | section |', '|---|---|---|---|']
    out += [f"| {n} | {idx[n]['date']} | {idx[n]['status']} | {short(secs[n][0])} |" for n in cur + old]
    out += post
    def strip(sec):
        s = list(sec)
        while s and s[-1] == '': s.pop()
        return s + ['']
    other = [p for p in parts if p['h'] not in ('## Current', '## Earlier')]
    pc = next(p for p in parts if p['h'] == '## Current')
    pe = next((p for p in parts if p['h'] == '## Earlier'), None)
    out += ['## Current'] + pc['intro']
    for n in cur: out += strip(secs[n])
    for p in other:
        out += [p['h']] + p['intro']
        while out[-1] == '': out.pop()
        out.append('')
    if old:
        intro = pe['intro'] if pe else ['', 'Superseded or historical sections, in the order they were written. Their numbers came from an older stack, launch or setting, or a later section replaced them; each says which.', '']
        out += ['## Earlier'] + intro
        for n in old: out += strip(secs[n])
    while out[-1] == '': out.pop()
    after = '\n'.join(out) + '\n'
    # no text lost: compare non-structural lines
    norm = lambda t: collections.Counter(l for l in t.split('\n') if l.strip() and not l.startswith('| ') and not l.startswith('|---') and not l.startswith('## '))
    if norm(before) != norm(after):
        d1, d2 = norm(before) - norm(after), norm(after) - norm(before)
        bad.append(f'{f}: text would change (BUG): lost {list(d1.items())[:3]}, gained {list(d2.items())[:3]}')
    elif after != before:
        print(f'{f}: {"would reorder / rewrite contents" if CHECK else "tidied"} ({len(cur)} current, {len(old)} earlier)')
        if not CHECK: open(path, 'w').write(after)
for n, fs in seen_in.items():
    if len(fs) > 1: bad.append(f'§{n} appears in {fs}')
for n in idx:
    if n not in seen_in and n != 0 and idx[n]['file'] != 'runtime.md': bad.append(f'§{n} in INDEX but in no file')
if 0 not in seen_in: bad.append('§0 missing')
print('problems:', bad if bad else 'none')
sys.exit(1 if bad else 0)
