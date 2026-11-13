import csv,glob,collections,statistics as st,sys
pat=sys.argv[1] if len(sys.argv)>1 else '*_r[123].csv'
d=collections.defaultdict(lambda: collections.defaultdict(list)); W=collections.defaultdict(list); bad=collections.Counter()
for f in glob.glob(pat):
    tag=f.rsplit('_r',1)[0]; grp,arm=tag.split('_',1)
    if grp=='long': continue
    for r in csv.DictReader(open(f)):
        a=r['arm'] if arm=='anchor' else arm
        if r['status']!='ok': bad[(grp,r['workload'],a)]+=1; continue
        d[(grp,r['workload'])][a].append(float(r['event_rate'])/1e6)
        if r['mean_window'] not in ('none',''): W[(grp,r['workload'],a)].append(float(r['mean_window']))
order=['old','new','k13','k17','k22','full']
print('ratio = median rate / median rate of the best fixed W in the same workload (higher is better); mean W in parentheses')
for k in sorted(d):
    arms=d[k]; fixed={a:st.median(v) for a,v in arms.items() if a.startswith('w:')}
    bw=max(fixed,key=fixed.get); b=fixed[bw]
    cells=[f"{a} {st.median(arms[a])/b:.2f} (W{st.median(W[(k[0],k[1],a)]):.0f})" for a in order if a in arms]
    dry=[a for a in arms if a.startswith('dry')]
    print(f"{k[0]:3s} {k[1]:34s} best {bw}={b:.1f} | "+' | '.join(cells)+(f" | {dry[0]} {st.median(arms[dry[0]])/b:.2f}" if dry else '')+ (f"  BAD {dict((x[2],c) for x,c in bad.items() if x[:2]==k)}" if any(x[:2]==k for x in bad) else ''))
