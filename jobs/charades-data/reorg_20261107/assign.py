import json, re
secs = json.load(open('secs.json'))
A = {}
def put(topic, *items):
    for it in items:
        if isinstance(it, tuple):
            for n in range(it[0], it[1] + 1): A[n] = topic
        else: A[it] = topic
put('runtime', 0, (21, 22), (25, 26), (81, 82), (85, 101), (112, 114), (133, 136), (154, 155), (162, 166), 205, (218, 221))
put('phold', (1, 2), (11, 12), (19, 20), (27, 28), (35, 36), (41, 45), (67, 68), (77, 78), (123, 124), (129, 130), (140, 144), 153, 240, 242, 243)
put('aggregation', (3, 5), (57, 58), (65, 66), (69, 76), (102, 103), (108, 111), (137, 139), (149, 150), (156, 161), (222, 223))
put('controller', (6, 8), 13, 15, (17, 18), (29, 34), (37, 40), 167, 173, 174, 176, (178, 182), 184, 185, 227, (230, 232), 237, 245, 246)
put('engine', (9, 10), (23, 24), (46, 56), (59, 64), (79, 80), (83, 84), (104, 107), (115, 120), (125, 128), (131, 132), (145, 148), (151, 152), (203, 204), (210, 211), 213, 215)
put('baselines', 14, 16, 241)
put('applications', (168, 172), 175, 177, 183, (186, 189), 194, 244, 248)
put('vlsi', (190, 193), (195, 202), (206, 209), 212, 214, (216, 217), 226, (228, 229), (233, 236), (238, 239))
put('hold', (224, 225))
put('methods', (121, 122), 247)
missing = [n for n in range(0, 249) if n not in A]; extra = [n for n in A if str(n) not in secs]
print('missing', missing, 'extra', extra)
def eff(n, seen=()):
    st = secs[str(n)]['status'].lower()
    m = re.search(r'results in (\d+)', st)
    if m and int(m.group(1)) not in seen and str(int(m.group(1))) in secs: return eff(int(m.group(1)), seen + (n,))
    w = re.match(r'[a-z]+', st).group(0) if re.match(r'[a-z]+', st) else 'historical'
    return 'current' if w in ('current', 'design', 'provisional') else 'earlier'
out = {n: dict(topic=A[n], part=eff(n)) for n in A}
json.dump(out, open('mapping.json', 'w'))
def ranges(ns):
    ns = sorted(ns); r = []; s = p = ns[0]
    for x in ns[1:]:
        if x == p + 1: p = x; continue
        r.append(f'{s}' if s == p else f'{s}–{p}'); s = p = x
    r.append(f'{s}' if s == p else f'{s}–{p}'); return ', '.join(r)
lines = {}
for n in range(249): lines[n] = sum(e - b for b, e in secs[str(n)]['lines'])
for t in ['phold', 'applications', 'vlsi', 'controller', 'aggregation', 'hold', 'engine', 'runtime', 'baselines', 'methods']:
    ns = [n for n in A if A[n] == t]; cur = [n for n in ns if out[n]['part'] == 'current']
    print(f"{t:13} {len(ns):3d} sections ({len(cur)} current), {sum(lines[n] for n in ns):5d} lines: §{ranges(ns)}")
