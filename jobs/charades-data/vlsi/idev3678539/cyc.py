import csv,glob,sys
for d in sys.argv[1:]:
    f=glob.glob(d+"/gvt_trace.csv")
    if not f: print(d, "no gvt_trace"); continue
    pts=sorted((float(r["result_s"]), int(r["bucket"])) for r in csv.DictReader(open(f[0])) if r["valid"]=="1")
    def at(b):
        for t,bb in pts:
            if bb>=b: return t
    out=[]
    for lo,hi in ((1960,2000),(2000,2040),(2040,2080)):
        a,b=at(lo),at(hi); out.append("%d-%d %.3f" % (lo,hi,(b-a)*1e3/(hi-lo)) if a and b else "-")
    print(d.split("/")[-2][-40:], " ms/cycle: ", "  ".join(out))
