#!/usr/bin/env python3
"""Split ~/charades/RESULTS.md into a front page and results/<topic>.md files
(2026-11-07). Text moves unchanged; headings gain their section label (§N);
every source line is accounted for exactly once (see the check at the end)."""
import json, re, os, sys, collections
R = '/Users/ritvik/charades'
HERE = os.path.dirname(os.path.abspath(__file__))
L = open(f'{HERE}/RESULTS.orig.md').read().split('\n')
secs = json.load(open(f'{HERE}/secs.json'))
topic = {int(k): v['topic'] for k, v in json.load(open(f'{HERE}/mapping.json')).items()}
used = collections.Counter()      # source line index -> times emitted
kind = {}                         # source line index -> 'same' / 'changed' / 'dropped'
def take(i, how='same'): used[i] += 1; kind[i] = how; return L[i]

pos = lambda s: L.index(s)
P_CUR, P_REREAD, P_INDEX = pos('## Current numbers'), pos('## Re-read, 2026-10-28: repeats and dropped threads'), pos('## Index of runs')
P_RUNS, P_MAC, P_LCI, P_PLAN = pos('## Stampede3 runs, in order'), pos('## Baseline verification on the Mac'), pos('## LCI on native psm2 (PR uiuc-hpc/lci#214)'), pos('## Plan history: the next-steps list as of 2026-10-21')

TOPICS = [  # file, title, scope
 ('phold', 'PHOLD: performance and weak scaling', 'Gaussian and uniform PHOLD in Charades, Devastator and ROSS: σ sweeps, full nodes, long runs, weak scaling from 1 to 32 nodes, and the paper runs F1.'),
 ('applications', 'Traffic and dragonfly', 'The two applications ported from Charades to ROSS and Devastator (phase B), the traffic count fix, and the paper runs F5 at 1–32 nodes.'),
 ('vlsi', 'VLSI (b19 × N)', "Gate-level simulation of copies of ITC'99's b19: the model and its layout, the gap to Devastator and how it closed, commits, and the paper's VLSI row."),
 ('controller', 'The optimism-window controller', "Every controller design and test: the delay-quantile rule, the aggregation bound, the measured-cost rule and its freeze, where the best window lies at scale, robustness (F4), and the controller's own cost (CC)."),
 ('aggregation', 'Aggregation through htram', "Message cost, htram's modes and buffers, the deadline flush policy, choosing htram automatically, input buffers, PP's allocation and start-up, flush timing, and F2 (htram against direct sends)."),
 ('hold', "The PADS'19 hold (F3)", "Mikida and Kale's hold of events past a cutoff, run as a baseline beside the window."),
 ('engine', 'The engine: GVT, rollback and per-event cost', "What paces the bucketed GVT at scale, rollback depth and unit, the same-process fast path, and the rounds that closed Charades' per-event gap to Devastator."),
 ('runtime', 'Runtime, transport and the machine', 'Reconverse builds and settings, native psm2 through LCI, LCI devices, the late-rank investigation, the message pool, NUMA balancing, shared memory between processes, and the slow node.'),
 ('baselines', 'ROSS and Devastator as baselines', "First runs and feasibility, ROSS's optimism window on PHOLD, and the Mac checks that both engines commit Charades' counts."),
 ('methods', 'Methods', 'How runs are made and checked: run length and warm-up, and the flag check that keeps diagnostics out of timing runs.'),
]
NAME = {t: f'{t}.md' for t, _, _ in TOPICS}

# ---- status corrections: sections a later one replaced in the paper table
SUPERSEDED = {142: '§242', 143: '§243', 188: '§244, then §248', 189: '§244', 217: '§239 at 1–16 nodes', 244: '§248'}
# ---- the index rows
idx_rows = {}
for i in range(P_INDEX, P_RUNS):
    m = re.match(r'\| (\d+) \| ', L[i])
    if m: idx_rows[int(m.group(1))] = i
def status(n):
    if n in SUPERSEDED: return 'superseded'
    if n == 0: return 'historical'
    return secs[str(n)]['status']
def part(n, seen=()):
    st = status(n).lower()
    if st.startswith('not for use') or st.startswith('superseded by'): return 'earlier'
    if st.startswith('superseded in part'): return 'current'
    if st.startswith('superseded') or st.startswith('historical'): return 'earlier'
    if st.startswith('design'):
        r = re.search(r'results in (\d+)', st); tgt = int(r.group(1)) if r else None
        if tgt is None:
            for k in sorted(k for k in topic if topic[k] == topic[n] and k > n)[:6]:
                if not status(k).lower().startswith('design'): tgt = k; break
        return part(tgt, seen + (n,)) if tgt is not None and tgt not in seen else 'current'
    return 'current'

def short(h):
    t = re.sub(r'^### ', '', h)
    t = re.sub(r'\s*\((design|implementation|analysis)?[^()]*20\d\d-\d\d-\d\d[^()]*\)\s*$', '', t)
    return t if len(t) <= 110 else t[:107].rstrip() + '…'

def section_text(n):
    out = []
    for hi, (b, e) in enumerate(secs[str(n)]['lines']):
        for i in range(b, e):
            if i == b:
                out.append(L[i].replace('### ', f'### §{n} · ', 1)); used[i] += 1; kind[i] = 'changed'
                if n in SUPERSEDED and hi == 0:
                    out += ['', f'> **Superseded (2026-11-07):** the paper table now comes from {SUPERSEDED[n]}.']
            else:
                out.append(take(i))
    while out and out[-1] == '': out.pop()
    return out

os.makedirs(f'{R}/results', exist_ok=True)
# ---- topic files
for t, title, scope in TOPICS:
    ns = sorted(n for n in topic if topic[n] == t)
    cur = [n for n in ns if part(n) == 'current']; old = [n for n in ns if part(n) == 'earlier']
    o = [f'# {title}', '',
         f'{scope} Part of the Charades results: the current paper tables are on the front page, [../RESULTS.md](../RESULTS.md), and every section\'s date, job, status and file is in [INDEX.md](INDEX.md). Sections keep the numbers (§N) they had in the single RESULTS.md they came from (split 2026-11-07); "section N" anywhere means §N.',
         '', '| § | date | status | section |', '|---|---|---|---|']
    for n in cur + old:
        o.append(f"| {n} | {secs[str(n)]['date']} | {status(n)} | {short(secs[str(n)]['heads'][0])} |")
    o += ['', '## Current', '', 'Current findings, and designs with their results, in the order they were written.', '']
    for n in cur: o += section_text(n) + ['']
    if t == 'baselines':
        o += ['## Checks on the Mac', '']
        for i in range(P_MAC + 1, P_LCI):
            o.append(take(i))
        used[P_MAC] += 1; kind[P_MAC] = 'dropped'
        while o[-1] == '': o.pop()
        o.append('')
    if t == 'runtime':
        o += ['## LCI on native psm2 (PR uiuc-hpc/lci#214)', '']
        for i in range(P_LCI + 1, P_PLAN): o.append(take(i))
        used[P_LCI] += 1; kind[P_LCI] = 'dropped'
        while o[-1] == '': o.pop()
        o.append('')
    if old:
        o += ['## Earlier', '', 'Superseded or historical sections, in the order they were written. Their numbers came from an older stack, launch or setting, or a later section replaced them; each says which.', '']
        for n in old: o += section_text(n) + ['']
    while o[-1] == '': o.pop()
    open(f'{R}/results/{t}.md', 'w').write('\n'.join(o) + '\n')
    print(f'{t}.md: {len(cur)} current, {len(old)} earlier, {len(o)} lines')

# ---- history
o = ['# History', '', 'Notes on the work itself, moved from the single RESULTS.md (split 2026-11-07): the re-read of 2026-10-28 and the plan as it stood on 2026-10-21. Front page: [../RESULTS.md](../RESULTS.md).', '']
for i in range(P_REREAD, P_INDEX): o.append(take(i))
while o[-1] == '': o.pop()
o.append('')
for i in range(P_PLAN, len(L)): o.append(take(i))
while o and o[-1] == '': o.pop()
open(f'{R}/results/history.md', 'w').write('\n'.join(o) + '\n')

# ---- index
o = ['# Index of runs', '',
     'Every section of the Charades results, by number (§N, in the order written), with its date, job, status and the file that holds it. Front page: [../RESULTS.md](../RESULTS.md). '
     'Statuses as in each section; the six marked "superseded" on 2026-11-07 were replaced in the paper table by the section named in their status line.', '']
used[P_INDEX] += 1; kind[P_INDEX] = 'dropped'
for i in range(P_INDEX + 1, P_RUNS):
    l = L[i]
    m = re.match(r'\| (\d+) \| (.*) \| ([^|]*) \|\s*$', l)
    if l.startswith('| # |'):
        o.append('| § | date | job | run | status | file |'); used[i] += 1; kind[i] = 'changed'
    elif l.startswith('|---'):
        o.append('|---|---|---|---|---|---|'); used[i] += 1; kind[i] = 'changed'
        o.append('| 0 | 2026-10-19 | — | QD poll fix on the Mac | historical | [runtime.md](runtime.md) |')
    elif m:
        n = int(m.group(1)); st = m.group(3).strip()
        if n in SUPERSEDED: st = f'superseded by {SUPERSEDED[n]} (was: {st})'
        o.append(f'| {n} | {m.group(2)} | {st} | [{NAME[topic[n]]}]({NAME[topic[n]]}) |'); used[i] += 1; kind[i] = 'changed'
    else:
        o.append(take(i))
while o[-1] == '': o.pop()
open(f'{R}/results/INDEX.md', 'w').write('\n'.join(o) + '\n')

# ---- front page
o = []
for i in range(0, P_CUR):
    if i == 2:
        o.append('This page holds the current paper tables. Every design and result, with its predictions, job IDs and status, is in a topic file under [`results/`](results/), listed below; [`results/INDEX.md`](results/INDEX.md) gives every section\'s number, date, job, status and file. '
                 'Raw CSVs and logs stay where each section says (`$WORK/charades-runs/` on Stampede3; copies of recent ones in `~/charades-data/`). Goals, build notes and open issues are in `CONTEXT.md`; the paper\'s claims, figures and the work left are in `PAPER.md`.')
        used[i] += 1; kind[i] = 'changed'
    elif L[i].startswith('- **Renamed 2026-10-27: "inbox" is now "input buffer"**'):
        assert L[i].count('in this file and in the code') == 1
        o.append(L[i].replace('in this file and in the code', 'in these files and in the code')); used[i] += 1; kind[i] = 'changed'
    elif L[i].startswith('- Write new designs and results at the end of'):
        o += ['- **Sections** are numbered §0, §1, … in the order they were written; "section N" or "RESULTS.md N" anywhere means §N, and [`results/INDEX.md`](results/INDEX.md) says which file holds it.',
              '- **New work** gets the next § number and goes in the topic file it belongs to, under "Current", with a status line; add its row to `results/INDEX.md`. When it replaces an earlier section in a paper table, mark that one superseded in the index and in its status line, and move it under "Earlier".']
        used[i] += 1; kind[i] = 'changed'
    else:
        o.append(take(i))
o += ['## Where everything is', '',
      'Split on 2026-11-07 from one file of 11,400 lines and 249 sections; the text moved unchanged, and each section kept its number.', '',
      '| file | what | sections |', '|---|---|---|']
for t, title, scope in TOPICS:
    ns = sorted(n for n in topic if topic[n] == t)
    o.append(f'| [results/{t}.md](results/{t}.md) | **{title}.** {scope} | {len(ns)} |')
o += ['| [results/history.md](results/history.md) | The re-read of 2026-10-28 and the plan history | — |',
      '| [results/INDEX.md](results/INDEX.md) | Every section by number, with its date, job, status and file | 249 |', '']
for i in range(P_CUR, P_REREAD): o.append(take(i))
while o[-1] == '': o.pop()
open(f'{R}/RESULTS.md', 'w').write('\n'.join(o) + '\n')

# ---- structural lines dropped: the "Stampede3 runs, in order" heading and the blank line after it
for i in (P_RUNS, P_RUNS + 1):
    if i not in kind: used[i] += 1; kind[i] = 'dropped'
# ---- the check: every source line emitted (or dropped on purpose) exactly once
bad = [i for i in range(len(L)) if used[i] != 1]
c = collections.Counter(kind.values())
print('source lines', len(L), dict(c), 'not exactly once:', len(bad), bad[:10])
print('dropped:', [(i, L[i][:60]) for i in range(len(L)) if kind.get(i) == 'dropped'])
sys.exit(1 if bad else 0)
