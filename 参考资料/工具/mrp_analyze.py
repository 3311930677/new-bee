# -*- coding: utf-8 -*-
"""MRP(MRPG) 容器结构分析：头部解析 / 字符串表 / zlib 流探测"""
import sys, struct, zlib, re, os

def hexdump(data, base=0, length=512):
    out = []
    for i in range(0, min(length, len(data)), 16):
        chunk = data[i:i+16]
        hexs = ' '.join('%02X' % b for b in chunk)
        asci = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
        out.append('%08X  %-47s  %s' % (base + i, hexs, asci))
    return '\n'.join(out)

def find_strings(data, minlen=4):
    res = []
    for m in re.finditer(rb'[\x20-\x7e]{%d,}' % minlen, data):
        res.append((m.start(), m.group().decode('ascii')))
    return res

def main(path):
    data = open(path, 'rb').read()
    print('file      :', os.path.basename(path))
    print('size      :', len(data))
    print('magic     :', data[:4])
    print()
    print('--- header (first 256 bytes) ---')
    print(hexdump(data, 0, 256))
    print()

    # 头部前 4 个 uint32
    if data[:4] == b'MRPG':
        vals = struct.unpack_from('<4I', data, 4)
        print('header u32:', vals)
        print()

    # zlib 流探测
    streams = []
    for i in range(len(data) - 2):
        if data[i] == 0x78 and data[i+1] in (0x01, 0x9C, 0xDA):
            try:
                d = zlib.decompressobj()
                out = d.decompress(data[i:i+200000])
                if len(out) > 64:
                    streams.append((i, len(out), d.unused_data[:0]))
            except Exception:
                pass
    print('--- zlib streams: %d ---' % len(streams))
    for off, ln, _ in streams[:20]:
        print('  offset=%d  inflated=%d bytes' % (off, ln))
    print()

    # 字符串
    strs = find_strings(data)
    print('--- strings (>=4): %d ---' % len(strs))
    for off, s in strs[:120]:
        print('  %08X  %s' % (off, s[:100]))

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else
         r'd:\战场女神\mythroad\240x320\gwy\xaqd.mrp')
