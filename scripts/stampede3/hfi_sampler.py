#!/usr/bin/env python3
"""Per-node Omni-Path (hfi1) counter sampler (charades RESULTS.md section 154).

Every PERIOD seconds (default 0.1) records the Unix time and a set of hfi1
counters: the port's transmit wait and flow-stall ticks (back-pressure from
the switch), packets and words in and out, and the driver's receive-overflow
counters (eager buffers or header queue full, receive overflow, per-context
header-queue overflows summed), and the node's TLB-shootdown, function-call
and rescheduling interrupts from /proc/interrupts, summed over CPUs. Run one
per node. Writes OUTDIR/<host>.csv on SIGTERM or SIGINT (and every 5 s), plus
OUTDIR/<host>_all_{start,end}.txt with every counter of the port and device.

Usage: hfi_sampler.py OUTDIR [PERIOD_S]
"""
import os, signal, socket, sys, time

out = sys.argv[1]
period = float(sys.argv[2]) if len(sys.argv) > 2 else 0.1
host = socket.gethostname().split('.')[0]
dev = '/sys/class/infiniband/hfi1_0'
port = dev + '/ports/1/hw_counters/'
devc = dev + '/hw_counters/'
NAMES = [
    (port, 'TxWait'), (port, 'TxFlowStall,32'), (port, 'TxPkt'), (port, 'RxPkt'),
    (port, 'TxWords'), (port, 'RxWords'), (port, 'DmaWait'),
    (devc, 'DRIVER_EgrBufFull'), (devc, 'DRIVER_EgrHdrFull'),
    (devc, 'RcvOverflow,32'), (devc, 'SeqDrop0'), (devc, 'RxCtxEgrS,32'),
    (devc, 'PioWait'), (devc, 'SendSched'), (devc, 'TidWait'), (devc, 'KmemWait'),
    (devc, 'RcvLimit'), (devc, 'Intr'), (devc, 'DRIVER_KernIntr'),
]
os.makedirs(out, exist_ok=True)


def opened(path):
    try:
        return os.open(path, os.O_RDONLY)
    except OSError:
        return -1


fds = [opened(d + n) for d, n in NAMES]
ovr = [opened(port + f) for f in sorted(os.listdir(port)) if f.startswith('RcvHdrOvr')]


def irqs():
    """TLB shootdowns, function-call and rescheduling interrupts, summed over CPUs"""
    out = {'TLB:': -1, 'CAL:': -1, 'RES:': -1}
    try:
        for line in open('/proc/interrupts'):
            f = line.split()
            if f and f[0] in out:
                out[f[0]] = sum(int(x) for x in f[1:] if x.isdigit())
    except OSError:
        pass
    return [out['TLB:'], out['CAL:'], out['RES:']]


def value(fd):
    if fd < 0:
        return -1
    try:
        return int(os.pread(fd, 64, 0).split()[0])
    except (OSError, ValueError, IndexError):
        return -1


def dump_all(tag):
    with open(os.path.join(out, '%s_all_%s.txt' % (host, tag)), 'w') as f:
        f.write('# CPUs this sampler may run on: %s\n' % sorted(os.sched_getaffinity(0)))
        for d in (port, devc):
            for n in sorted(os.listdir(d)):
                try:
                    f.write('%s%s %s\n' % (d[len(dev):], n, open(d + n).read().split()[0]))
                except (OSError, IndexError):
                    pass


rows = []
csv = os.path.join(out, host + '.csv')
header = 'unix_s,' + ','.join(n.split(',')[0] for _, n in NAMES) + ',RcvHdrOvr_sum,TLB,CAL,RES\n'


def flush():
    with open(csv, 'w') as f:
        f.write(header)
        f.writelines(rows)


stop = []
signal.signal(signal.SIGTERM, lambda *a: stop.append(1))
signal.signal(signal.SIGINT, lambda *a: stop.append(1))
dump_all('start')
last_flush = time.time()
nxt = time.time()
while not stop:
    now = time.time()
    v = [value(fd) for fd in fds]
    rows.append('%.3f,%s,%d,%s\n' % (now, ','.join(map(str, v)), sum(value(fd) for fd in ovr), ','.join(map(str, irqs()))))
    if now - last_flush > 5:
        flush()
        last_flush = now
    nxt += period
    time.sleep(max(0.0, nxt - time.time()))
flush()
dump_all('end')
