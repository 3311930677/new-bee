# -*- coding: utf-8 -*-
"""把 xaqd.mrp 解出的 .dat 精灵帧转为可直接查看的 .png
.dat 结构: 可能为 gzip(png) / 纯 png / [<=16 字节小头]+png / 裸 16bit 像素
"""
import os, re, gzip, io, struct

SRC = r'd:\战场女神\原始数据\xaqd_unpack'
DST = r'd:\战场女神\原始数据\xaqd_png'
PNG_SIG = b'\x89PNG\r\n\x1a\n'

def to_png(b):
    """返回 (png_bytes, note) 或 (None, note)"""
    if b[:len(PNG_SIG)] == PNG_SIG:
        return b, 'png'
    # 小头 + png
    i = b.find(PNG_SIG, 0, 24)
    if i > 0:
        return b[i:], 'png+%d' % i
    return None, 'raw'

def main():
    os.makedirs(DST, exist_ok=True)
    stat = {'png': 0, 'png+': 0, 'raw': 0, 'gzip_nested': 0}
    raw_list = []
    for n in sorted(os.listdir(SRC)):
        if not n.endswith('.dat'):
            continue
        b = open(os.path.join(SRC, n), 'rb').read()
        if b[:2] == b'\x1f\x8b':
            try:
                b = gzip.decompress(b)
                stat['gzip_nested'] += 1
            except Exception:
                pass
        png, note = to_png(b)
        if png is not None:
            out = os.path.join(DST, n.replace('.dat', '.png'))
            open(out, 'wb').write(png)
            stat['png' if note == 'png' else 'png+'] += 1
        else:
            stat['raw'] += 1
            raw_list.append((n, len(b), b[:12].hex()))
    print('转换结果:', stat)
    print('非 PNG 的裸像素帧 (%d 个):' % len(raw_list))
    for n, l, h in raw_list[:40]:
        print('   %-12s %7d  %s' % (n, l, h))

if __name__ == '__main__':
    main()
