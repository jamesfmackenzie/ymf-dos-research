#!/usr/bin/env python3
"""Minimal LE (DOS4GW) extractor: prints header/objects, writes obj<N>.bin per object
plus manifest.txt (obj, base, size, flags). Usage: leparse.py setupds.exe outdir"""
import struct, sys, os

def main(path, outdir):
    d = open(path, 'rb').read()
    le = struct.unpack_from('<I', d, 0x3C)[0]
    assert d[le:le+2] == b'LE'
    u32 = lambda o: struct.unpack_from('<I', d, le+o)[0]
    npages, pagesize, lastpage = u32(0x14), u32(0x28), u32(0x2C)
    objtab, nobj, pmaptab, datapages = u32(0x40), u32(0x44), u32(0x48), u32(0x80)
    print('entry: obj%d+0x%X  stack: obj%d+0x%X' % (u32(0x18), u32(0x1C), u32(0x20), u32(0x24)))
    os.makedirs(outdir, exist_ok=True)
    manifest = []
    for i in range(nobj):
        size, base, flags, pmi, npg, _ = struct.unpack_from('<IIIIII', d, le + objtab + i*24)
        img = bytearray()
        for p in range(pmi, pmi + npg):
            e = le + pmaptab + (p-1)*4  # LE page map entry: 4 bytes
            hi, lo, ptype = struct.unpack_from('>HBB', d, e)  # page# (24-bit BE), type
            n = (hi << 8) | lo
            off = datapages + (n-1)*pagesize
            ln = lastpage if n == npages else pagesize
            if ptype == 0:
                img += d[off:off+ln].ljust(pagesize, b'\0')
            else:
                img += b'\0' * pagesize  # zero-fill / unsupported (iterated)
                print('  WARN page %d type %d' % (p, ptype))
        img = bytes(img[:max(size, 0)]) if size <= len(img) else bytes(img).ljust(size, b'\0')
        open(os.path.join(outdir, 'obj%d.bin' % (i+1)), 'wb').write(img)
        manifest.append('obj%d base=0x%X size=0x%X flags=0x%X' % (i+1, base, size, flags))
        print(manifest[-1])
    open(os.path.join(outdir, 'manifest.txt'), 'w').write('\n'.join(manifest) + '\n')
    print('fixups: fixpagetab=0x%X fixrectab=0x%X (not applied)' % (u32(0x68), u32(0x6C)))

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
