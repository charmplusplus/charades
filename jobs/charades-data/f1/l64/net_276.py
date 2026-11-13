#!/usr/bin/env python3
"""Job L64b rerun (charades results/aggregation.md section 275, results in 276):
the network record taken between runs. For each segment (start, probe, gate,
warm, rep1..rep5) it gives, per node, the change in the network card's counters
since the previous record, and the fabric manager's samples for the segment.

Counters (all counts of events on the node's own port, during the segment):
  lost: packets thrown away. RcvHdrOvr<N> = the card found the input queue of
        receive context N full and dropped the whole packet (a host that did
        not poll in time); PktDrop, XmitDscd, TxDropped, port_xmit_discards =
        dropped on the way out; port_rcv_errors, excessive_buffer_overrun_errors
        = bad or overrunning packets on the way in. A lost packet costs a PSM2
        resend after PSM2_ERRCHK_TIMEOUT (160 ms).
  link: repairs on the cable: DcRxReplay/DcTxReplay (link-level resends),
        link_error_recovery, local_link_integrity_errors, DcRecvErr, DcUnctblErr.
        The fabric manager clears the 32- and 8-bit ones every 2 minutes, so a
        drop in value is reported as 'cleared' and the later value as a lower bound.
  wait: port_xmit_wait / TxWait = time the port had data but no credit from the
        switch (back-pressure from the fabric), raw counter units.
Usage: net_276.py <job dir>"""
import collections, glob, os, re, statistics as st, sys
J = sys.argv[1]; NET = os.path.join(J, 'net')
ORDER = ['start', 'probe', 'gate', 'warm'] + ['rep%d' % i for i in range(1, 6)]
LOST = ['RcvHdrOvr*', 'PktDrop', 'XmitDscd', 'TxDropped', 'port_xmit_discards', 'port_rcv_errors',
        'excessive_buffer_overrun_errors', 'DRIVER_EgrBufFull', 'DRIVER_EgrHdrFull']
LINK = ['DcRxReplay', 'DcTxReplay', 'link_error_recovery', 'local_link_integrity_errors', 'DcRecvErr',
        'DcUnctblErr', 'link_downed', 'symbol_error']
WAIT = ['port_xmit_wait', 'TxWait']

def load(label):
    f = os.path.join(NET, label + '.nodes')
    if not os.path.exists(f): return None
    nodes = collections.defaultdict(dict); links = collections.defaultdict(dict); t = {}
    for line in open(f, errors='replace'):
        p = line.rstrip('\n').split(' ', 1)
        if len(p) < 2: continue
        h, rest = p
        if rest.startswith('time '): t[h] = float(rest.split()[1]); continue
        if rest.startswith('opainfo '): links[h][rest.split()[1].rstrip(':')] = rest; continue
        m = re.match(r'(\S+?):(-?\d+)$', rest)
        if not m: continue
        name = m.group(1).split('/')[-1].split(',')[0]
        if name.startswith('RcvHdrOvr'): nodes[h]['RcvHdrOvr*'] = nodes[h].get('RcvHdrOvr*', 0) + int(m.group(2)); nodes[h][name] = int(m.group(2))
        else: nodes[h][name] = nodes[h].get(name, 0) + int(m.group(2))
    return dict(nodes=nodes, links=links, t=t)

def delta(a, b, keys):
    out = {}; cleared = []
    for k in keys:
        x, y = a.get(k, 0), b.get(k, 0)
        if y < x: cleared.append(k); out[k] = y
        elif y > x: out[k] = y - x
    return out, cleared

def link_flags(h, li):
    bad = []
    s = ' '.join(li.values())
    if 'PortState' in li and 'Active' not in li['PortState']: bad.append('not Active')
    m = re.search(r'LinkWidth\s+Act: (\d)', s);  bad += [] if not m or m.group(1) == '4' else ['width %s' % m.group(1)]
    m = re.search(r'ActTx: (\d)\s+Rx: (\d)', s); bad += [] if not m or m.groups() == ('4', '4') else ['downgraded Tx %s Rx %s' % m.groups()]
    m = re.search(r'Link Quality: (\d)', s);     bad += [] if not m or m.group(1) == '5' else ['quality %s' % m.group(1)]
    m = re.search(r'LinkSpeed\s+Act: (\S+)', s); bad += [] if not m or m.group(1) == '25Gb' else ['speed %s' % m.group(1)]
    return bad

snaps = [(l, load(l)) for l in ORDER]; snaps = [(l, s) for l, s in snaps if s]
print('records: %s' % ' '.join(l for l, _ in snaps))
for l, s in snaps:
    for h in sorted(s['links']):
        b = link_flags(h, s['links'][h])
        if b: print('  LINK %s %s: %s' % (l, h, ', '.join(b)))
for (la, a), (lb, b) in zip(snaps, snaps[1:]):
    hosts = sorted(set(a['t']) & set(b['t']))   # a node missing from either record has no delta
    missing = sorted(set(b['t']) - set(a['t']))
    dur = st.median(b['t'][h] - a['t'][h] for h in hosts if h in a['t'] and h in b['t']) if hosts else 0
    print('\n# %s (%s -> %s, %.0f s, %d nodes in both records%s)' % (lb, la, lb, dur, len(hosts),
          '; no earlier record for %d: %s' % (len(missing), ' '.join(missing)) if missing else ''))
    lost_tot = collections.Counter(); rows = []
    waits = {}
    for h in hosts:
        dl, cl1 = delta(a['nodes'].get(h, {}), b['nodes'].get(h, {}), LOST)
        dk, cl2 = delta(a['nodes'].get(h, {}), b['nodes'].get(h, {}), LINK)
        dw, _ = delta(a['nodes'].get(h, {}), b['nodes'].get(h, {}), WAIT)
        waits[h] = dw.get('port_xmit_wait', 0)
        ctx = [k for k in b['nodes'].get(h, {}) if k.startswith('RcvHdrOvr') and k != 'RcvHdrOvr*'
               and b['nodes'][h][k] > a['nodes'].get(h, {}).get(k, 0)]
        lost_tot.update(dl)
        if dl or dk or cl1 or cl2:
            rows.append((sum(dl.values()), h, dl, dk, cl1 + cl2, ctx))
    print('  lost packets, all nodes: %s' % (dict(lost_tot) or 'none'))
    for n, h, dl, dk, cl, ctx in sorted(rows, reverse=True)[:15]:
        print('  %-9s lost %s  link %s%s%s' % (h, dl or '-', dk or '-', '  cleared %s' % cl if cl else '',
              '  contexts %s' % ','.join(sorted(c[9:] for c in ctx)) if ctx else ''))
    w = sorted(waits.values())
    if w and w[-1]:
        md = st.median(w)
        top = sorted(waits.items(), key=lambda x: -x[1])[:3]
        print('  xmit wait per node: median %d, max %d (max / median %.1f); top %s' % (md, w[-1], w[-1] / md if md else float('inf'),
              ', '.join('%s %d' % x for x in top)))

# fabric manager: summaries and focus ports touching our nodes or their racks' edge switches
ours = set(h for _, s in snaps for h in s['nodes'])
racks = set(h.split('-')[0][1:] for h in ours)
def touches(name): # a node of ours, or an edge switch in one of our racks (s<rack>-U/L)
    n = name.split()[0] if name else ''
    return n in ours or (n.startswith('s') and n[1:].split('-')[0] in racks)
for l, _ in snaps:
    f = os.path.join(NET, l + '.pa')
    if not os.path.exists(f): continue
    txt = open(f, errors='replace').read()
    print('\n# fabric manager, %s' % l)
    err = re.findall(r'^opapaquery: (.*)$', txt, flags=re.M)
    if err and not re.search(r'ImageTime', txt):
        print('  every query failed: %s (%d times)' % (err[0], len(err))); continue
    for blk in re.split(r'^=== sample ', txt, flags=re.M)[1:]:
        k = blk.split('\n', 1)[0]
        it = re.search(r'ImageTime: (.+)', blk); ig = re.search(r'Integrity\s+Max\s+(\d+)\s+Buckets:\s+([\d ]+)', blk)
        cg = re.search(r'Congestion\s+Max\s+(\d+)\s+Buckets:\s+([\d ]+)', blk); ds = re.search(r'Discards:\s+(\S+)', blk)
        print('  sample %s %s: integrity max %s buckets [%s]; congestion max %s buckets [%s]; discards %s' % (
            k, it.group(1) if it else '?', ig.group(1) if ig else '?', ig.group(2).strip() if ig else '',
            cg.group(1) if cg else '?', cg.group(2).strip() if cg else '', ds.group(1) if ds else '?'))
        for fo in ['integrity', 'congestion']:
            m = re.search(r'--- focus %s\n(.*?)(?=\n--- focus|\Z)' % fo, blk, flags=re.S)
            if not m: continue
            for e in re.findall(r'(\d+):LID:\S+\s+Port:(\d+).*?Value:\s+(\d+)\s+nbrValue:\s+(\d+).*?Name: (.*?)\n.*?Neighbor Name: (.*?)\n', m.group(1), flags=re.S):
                i, port, v, nv, name, nbr = e
                if (int(v) or int(nv)) and (touches(name) or touches(nbr)):
                    print('    %s #%s: %s port %s value %s <-> %s value %s' % (fo, i, name, port, v, nbr, nv))
