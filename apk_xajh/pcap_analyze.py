import struct, sys, re
from collections import Counter, defaultdict

def parse_pcapng(path):
    data = open(path, 'rb').read()
    pos = 0
    if_tsresol = 6  # default microseconds
    link_type = 1
    packets = []  # (ts_sec_float, bytes)
    endian = '<'
    while pos + 12 <= len(data):
        btype, blen = struct.unpack(endian + 'II', data[pos:pos+8])
        if btype == 0x0A0D0D0A:  # SHB - check endianness
            bom, = struct.unpack('<I', data[pos+8:pos+12])
            endian = '<' if bom == 0x1A2B3C4D else '>'
        elif btype == 0x00000001:  # IDB
            link_type = struct.unpack(endian + 'H', data[pos+8:pos+10])[0]
            # options: if_tsresol = 9
            opt_off = pos + 16  # skip linktype(2)+reserved(2)+snaplen(4)
            end = pos + blen - 4
            while opt_off + 4 <= end:
                code, olen = struct.unpack(endian + 'HH', data[opt_off:opt_off+4])
                if code == 0: break
                if code == 9:
                    val = data[opt_off+4]
                    if_tsresol = val
                opt_off += 4 + ((olen + 3) // 4) * 4
        elif btype == 0x00000006:  # Enhanced Packet Block
            iface, ts_h, ts_l, caplen, origlen = struct.unpack(endian + 'IIIII', data[pos+8:pos+28])
            ts = ((ts_h << 32) | ts_l) / (10 ** if_tsresol)
            pkt = data[pos+28:pos+28+caplen]
            packets.append((ts, pkt))
        elif btype == 0x00000003:  # Simple Packet Block
            origlen, = struct.unpack(endian + 'I', data[pos+8:pos+12])
            caplen = min(origlen, blen - 16)
            packets.append((None, data[pos+12:pos+12+caplen]))
        pos += blen
    return link_type, packets

def parse_eth_ipv4(pkt):
    """return (src, dst, proto, sport, dport, payload) for TCP/UDP or None"""
    if len(pkt) < 34: return None
    etype = struct.unpack('>H', pkt[12:14])[0]
    off = 14
    if etype == 0x8100:  # vlan
        etype = struct.unpack('>H', pkt[16:18])[0]; off = 18
    if etype != 0x0800: return None
    ip = pkt[off:]
    if len(ip) < 20: return None
    ihl = (ip[0] & 0xf) * 4
    total_len = struct.unpack('>H', ip[2:4])[0]
    proto = ip[9]
    src = '.'.join(str(b) for b in ip[12:16])
    dst = '.'.join(str(b) for b in ip[16:20])
    if proto not in (6, 17): return None
    transport = ip[ihl:total_len]
    if proto == 6 and len(transport) >= 20:
        sport, dport = struct.unpack('>HH', transport[:4])
        doff = (transport[12] >> 4) * 4
        return ('tcp', src, dst, sport, dport, transport[doff:])
    elif proto == 17 and len(transport) >= 8:
        sport, dport = struct.unpack('>HH', transport[:4])
        ln = struct.unpack('>H', transport[4:6])[0]
        return ('udp', src, dst, sport, dport, transport[8:ln])
    return None

def analyze(path):
    print('#' * 60)
    print('FILE:', path)
    link_type, packets = parse_pcapng(path)
    print(f'link_type={link_type}, packets={len(packets)}')
    if packets:
        tss = [t for t, _ in packets if t]
        if tss:
            import datetime
            print('time range:', datetime.datetime.fromtimestamp(min(tss)), '->', datetime.datetime.fromtimestamp(max(tss)))
    hosts = Counter()
    dns = []
    http_reqs = []
    tls_sni = Counter()
    convs = Counter()
    mrp_hits = []
    other_ports = Counter()
    for i, (ts, pkt) in enumerate(packets):
        r = parse_eth_ipv4(pkt)
        if not r: continue
        proto, src, dst, sport, dport, payload = r
        convs[(src, dst, dport if dport != 80 and dport != 443 else ('http' if dport==80 else 'https'))] += 1
        if proto == 'udp' and dport == 53 and payload and len(payload) > 12:
            try:
                q = payload[12:]
                parts = []
                p = 0
                while p < len(q) and q[p]:
                    if q[p] & 0xc0: break
                    parts.append(q[p+1:p+1+q[p]].decode('idna'))
                    p += q[p] + 1
                if parts: dns.append('.'.join(parts))
            except Exception: pass
        if not payload: continue
        # HTTP request detection
        head = payload[:64]
        if head.startswith((b'GET ', b'POST ', b'PUT ', b'HEAD ', b'DELETE ')):
            try:
                line = payload.split(b'\r\n', 1)[0].decode('latin1')
                hh = payload.split(b'\r\n\r\n', 1)[0].decode('latin1')
                host = re.search(r'(?i)^Host:\s*(.+)$', hh, re.M)
                http_reqs.append((line, host.group(1).strip() if host else '-', len(payload)))
            except Exception: pass
        # TLS SNI
        if payload[0] == 0x16 and b'\x00\x00' in payload[:16]:
            m = re.search(rb'\x00\x00([\x20-\x7e]{4,60})\x00\x17\x00\x00\xff\x01', payload)
            if m: tls_sni[m.group(1).decode('latin1')] += 1
            else:
                # generic SNI extraction: server_name extension
                for mm in re.finditer(rb'\x00\x00([a-z0-9\-]{2,10}(?:\.[a-z0-9\-]{2,20}){1,5})', payload[:600], re.I):
                    tls_sni[mm.group(1).decode()] += 1
                    break
        # MRP / game keywords in payload
        if re.search(rb'\.mrp|elevensky|skymobi|x8ds|xaqd', payload, re.I):
            mrp_hits.append((i, src, dst, sport, dport, payload[:80]))
        # non-standard ports
        if proto == 'tcp' and dport not in (80, 443, 53, 137, 138, 139, 445, 1900, 5037, 5554, 27042, 27043) and sport not in (80, 443):
            other_ports[(dst, dport)] += 1

    print('\n== DNS queries ==')
    for d, c in Counter(dns).most_common(40): print(f'  {c:3d}x {d}')
    print('\n== TLS SNI ==')
    for h, c in tls_sni.most_common(40): print(f'  {c:3d}x {h}')
    print('\n== HTTP requests ==')
    for line, host, sz in http_reqs[:60]: print(f'  [{sz:6d}] {host} {line[:110]}')
    print(f'  (total {len(http_reqs)})')
    print('\n== TCP convs (top) ==')
    for (src, dst, port), c in convs.most_common(25): print(f'  {c:5d} pkts  {src} -> {dst} :{port}')
    print('\n== MRP/skymobi keyword hits ==', len(mrp_hits))
    for i, src, dst, sp, dp, p in mrp_hits[:20]:
        print(f'  pkt#{i} {src}->{dst}:{dp} {p[:70]!r}')
    print()

for p in sys.argv[1:]:
    analyze(p)
