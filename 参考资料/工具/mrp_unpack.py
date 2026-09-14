# -*- coding: utf-8 -*-
"""MRP(MRPG) 解包器
文件表条目: [u32 name_len][name(name_len 字节, 含 NUL)][u32 offset][u32 size][u32 flag]
条目中各文件数据可能为 zlib 压缩, 解压后输出到 outdir
"""
import sys, struct, zlib, os, io

def parse(path):
    data = open(path, 'rb').read()
    assert data[:4] == b'MRPG', 'not MRPG'
    hdr_size = struct.unpack_from('<I', data, 4)[0]
    pos = 0xF0
    entries = []
    while pos + 4 <= len(data):
        nlen = struct.unpack_from('<I', data, pos)[0]
        if nlen == 0 or nlen > 256:
            break
        name = data[pos+4:pos+4+nlen]
        if b'\x00' in name:
            name = name[:name.index(b'\x00')]
        try:
            nm = name.decode('ascii')
        except Exception:
            break
        off_pos = pos + 4 + nlen
        if off_pos + 12 > len(data):
            break
        off, size, flag = struct.unpack_from('<III', data, off_pos)
        if off > len(data) or size > len(data):
            break
        entries.append((nm, off, size, flag, pos))
        pos = off_pos + 12
    return data, hdr_size, entries

def try_inflate(buf):
    import gzip
    if buf[:2] == b'\x1f\x8b':
        try:
            out = gzip.decompress(buf)
            if len(out) > 0:
                return out, 'gzip'
        except Exception:
            pass
    for wbits in (15, -15):
        try:
            d = zlib.decompressobj(wbits)
            out = d.decompress(buf)
            if len(out) > 0:
                return out, 'zlib'
        except Exception:
            pass
    return None, None

def main(path, outdir):
    data, hdr_size, entries = parse(path)
    os.makedirs(outdir, exist_ok=True)
    print('entries: %d   hdr_size(u32@4)=%d   filesize=%d' % (len(entries), hdr_size, len(data)))
    print()
    print('%-24s %10s %10s %6s  %s' % ('name', 'offset', 'size', 'flag', 'status'))
    print('-' * 78)
    total_raw = total_inf = 0
    for nm, off, size, flag, tpos in entries:
        blob = data[off:off+size]
        status = 'raw'
        out = blob
        if blob[:2] == b'\x1f\x8b' or blob[:3] in (b'\x78\x01', b'\x78\x9c', b'\x78\xda'):
            inf, kind = try_inflate(blob)
            if inf is not None:
                out = inf
                status = '%s->%d' % (kind, len(inf))
            else:
                status = 'compress?FAIL'
        total_raw += size
        total_inf += len(out)
        # 输出文件
        safe = nm.replace('/', '_').replace('\\', '_')
        fp = os.path.join(outdir, safe)
        with open(fp, 'wb') as f:
            f.write(out)
        print('%-30s %10d %10d %6d  %s' % (nm, off, size, flag, status))
    print()
    print('total raw=%d  total out=%d' % (total_raw, total_inf))

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else r'd:\战场女神\mythroad\240x320\gwy\xaqd.mrp',
         sys.argv[2] if len(sys.argv) > 2 else r'd:\战场女神\原始数据\xaqd_unpack')
