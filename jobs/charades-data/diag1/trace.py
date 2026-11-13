import glob,statistics as st,collections,sys
for f in sorted(glob.glob(sys.argv[1])):
    rows=[]
    for l in open(f):
        if l.startswith('CTL round'):
            s=l.split(); rows.append(dict(zip(s[1::2],s[2::2])))
    W=[int(r['window']) for r in rows]; ex=[int(r['executed']) for r in rows]; rb=[int(r['rolled_back']) for r in rows]
    ms=[float(r['round_ms']) for r in rows]; g=[int(r['gvt']) for r in rows]
    b=collections.defaultdict(lambda:[0,0,0,0.0,0])
    for i,(w,e,r,m) in enumerate(zip(W,ex,rb,ms)):
        k=(w//50)*50; b[k][0]+=1; b[k][1]+=e; b[k][2]+=r; b[k][3]+=m
        if i>0: b[k][4]+=g[i]-g[i-1]
    T=sum(ms)
    print(f.split('/')[-1][:55], 'rounds',len(W),'W p10/med/p90',sorted(W)[len(W)//10],int(st.median(W)),sorted(W)[9*len(W)//10],'max',max(W))
    print('   W-bin: time% | rolled-back% | GVT advance per ms')
    for k,v in sorted(b.items()):
        print(f"   {k:4d}-{k+49}: {100*v[3]/T:5.1f}% | {100*v[2]/max(v[1],1):6.3f}% | {v[4]/max(v[3],1e-9):7.1f}")
