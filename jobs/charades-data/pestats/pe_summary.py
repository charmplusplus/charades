#!/usr/bin/env python3
"""Which PE is slow: per-PE spread of events and of window-blocked batches (--pe-stats)."""
import csv, glob, statistics as st
for f in sorted(glob.glob("*/ctl_sweep/pe_stats.csv")):
    rows = [{k: float(v) for k, v in r.items()} for r in csv.DictReader(open(f))]
    ex = [r["executed"] for r in rows]; cm = [r["committed"] for r in rows]
    bw = [r["batches_window"] for r in rows]; bf = [r["batches_full"] for r in rows]
    mean_ex = st.mean(ex)
    busiest = sorted(rows, key=lambda r: r["batches_window"])[:10]   # least blocked
    r0 = [r["batches_window"] for r in rows if r["rank"] == 0]
    rn = [r["batches_window"] for r in rows if r["rank"] != 0]
    by_rank = {}
    for r in rows: by_rank.setdefault(int(r["rank"]), []).append(r["batches_window"])
    lowest_rank = min(by_rank, key=lambda k: st.mean(by_rank[k]))
    print(f"{f.split('/')[0]}: PEs {len(rows)} | executed: max/mean {max(ex)/mean_ex:.3f}, min/mean {min(ex)/mean_ex:.3f}, CV {st.pstdev(ex)/mean_ex:.3f}"
          f" | committed max/mean {max(cm)/st.mean(cm):.3f}"
          f" | window-blocked batches: mean {st.mean(bw)/1e3:.0f}K, min {min(bw)/1e3:.0f}K (PE {int(busiest[0]['pe'])}, rank {int(busiest[0]['rank'])})"
          f" | rank 0 mean {st.mean(r0)/1e3:.0f}K vs others {st.mean(rn)/1e3:.0f}K"
          f" | 10 least blocked: ranks {sorted(int(r['rank']) for r in busiest)}, executed/mean {', '.join(f'{r['executed']/mean_ex:.2f}' for r in busiest[:5])}"
          f" | rank with fewest blocked on average: {lowest_rank} ({st.mean(by_rank[lowest_rank])/1e3:.0f}K)")
