#!/usr/bin/env python3
"""Sample /proc for one process every 0.5 s until it exits.
Per thread: t tid comm cpus_allowed last_cpu run_ns wait_ns slices vcsw nvcsw minflt majflt utime stime
Per CPU (lines starting 'C'): t cpu irq softirq system (jiffies, cumulative)."""
import os, sys, time
pid, out = sys.argv[1], sys.argv[2]
LIGHT = os.environ.get("SCHED_MODE") == "light"  # only /proc/<pid>/task/*/stat, every 1 s
f = open(out, "w")
f.write(f"# pid {pid} host {os.uname().nodename} localid {os.environ.get('SLURM_LOCALID')} procid {os.environ.get('SLURM_PROCID')}\n")
t0 = time.time()
while os.path.exists(f"/proc/{pid}"):
    t = time.time() - t0
    try:
        for tid in os.listdir(f"/proc/{pid}/task"):
            d = f"/proc/{pid}/task/{tid}"
            try:
                st = open(f"{d}/stat").read()
                if LIGHT:
                    x = st[st.rindex(")") + 2:].split()
                    f.write(f"L {t:.2f} {tid} {x[36]} {x[7]} {x[11]} {x[12]}\n")
                    continue
                run, wait, sl = open(f"{d}/schedstat").read().split()
                comm = st[st.index("(") + 1:st.rindex(")")].replace(" ", "_")
                x = st[st.rindex(")") + 2:].split()  # x[0] = field 3
                stat = {k: v.strip() for k, v in
                        (l.split(":", 1) for l in open(f"{d}/status") if ":" in l)}
                f.write(f"T {t:.2f} {tid} {comm} {stat['Cpus_allowed_list']} {x[36]} {run} {wait} {sl} "
                        f"{stat['voluntary_ctxt_switches']} {stat['nonvoluntary_ctxt_switches']} {x[7]} {x[9]} {x[11]} {x[12]}\n")
            except (OSError, ValueError, KeyError, IndexError):
                pass
        for l in ([] if LIGHT else open("/proc/stat")):
            if l.startswith("cpu") and l[3].isdigit():
                v = l.split()
                f.write(f"C {t:.2f} {v[0][3:]} {v[6]} {v[7]} {v[3]}\n")
    except OSError:
        break
    f.flush()
    time.sleep(1.0 if LIGHT else 0.5)
f.close()
