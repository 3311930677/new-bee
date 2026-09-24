import struct, os, re

d = open(r'd:\new bee\apk_xajh\xaqd.mrp', 'rb').read()
COUNT = struct.unpack('<I', d[0x44:0x48])[0]
print('declared file count:', COUNT)

pos = 0xf0
entries = []
for i in range(COUNT):
    nlen, = struct.unpack('<I', d[pos:pos+4])
    if not (1 <= nlen <= 64):
        print(f'bad name_len {nlen} at 0x{pos:x}, stop')
        break
    name = d[pos+4:pos+4+nlen].rstrip(b'\x00').decode('gbk', 'replace')
    off, size, unk = struct.unpack('<III', d[pos+4+nlen:pos+16+nlen])
    entries.append((name, off, size, unk))
    pos += 16 + nlen
print(f'parsed {len(entries)} entries, table ends at 0x{pos:x}')

outdir = r'd:\new bee\apk_xajh\xaqd_files'
os.makedirs(outdir, exist_ok=True)

def sniff(data):
    if data[:2] == b'\x89PNG': return 'PNG'
    if data[:3] == b'\xff\xd8\xff': return 'JPEG'
    if data[:2] == b'BM': return 'BMP'
    if data[:4] == b'MRPG': return 'MRP'
    # GBK text ratio
    txt = sum(1 for c in data if 32 <= c < 127 or c in (10, 13, 9))
    if len(data) and txt / len(data) > 0.85: return 'text/ascii'
    try:
        data.decode('gbk'); 
        cn = sum(1 for b in data if b >= 0x80)
        if cn > len(data) * 0.2: return 'text/gbk'
    except Exception: pass
    return 'bin'

for name, off, size, unk in entries:
    data = d[off:off+size]
    fn = os.path.join(outdir, name)
    with open(fn, 'wb') as f: f.write(data)
    t = sniff(data)
    # guess from name
    print(f'{name:12s} off=0x{off:06x} size={size:7d} unk={unk} type={t} head={data[:16].hex()}')
