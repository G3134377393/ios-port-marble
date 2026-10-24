#!/usr/bin/env python3
"""Pack Qualcomm split firmware (adsp2.mdt + adsp2.bNN) into a SWEETFW1 blob.

The blob is handed to the kernel through the payload's RAMDisk slot, so
sweet_adsp.c can load the ADSP without any filesystem support.

Container (little endian):
    char     magic[8]      "SWEETFW1"
    uint32   version       1
    uint32   count
    uint32   entries_off   24
    uint32   reserved
    struct { char name[32]; uint32 off; uint32 size; } entries[count]
    data ..., each file 4-byte aligned

Usage:
    mkfwblob.py SRCDIR OUT [--prefix adsp2]
"""
import argparse
import os
import struct
import sys

HDR = struct.Struct('<8sIIII')
ENT = struct.Struct('<32sII')
MAGIC = b'SWEETFW1'


def collect(srcdir, prefix):
    names = []
    for name in sorted(os.listdir(srcdir)):
        if name == prefix + '.mdt' or (name.startswith(prefix + '.b') and
                                       name[len(prefix) + 2:].isdigit()):
            names.append(name)
    if prefix + '.mdt' not in names:
        sys.exit('error: %s.mdt not found in %s' % (prefix, srcdir))
    return names


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('srcdir')
    ap.add_argument('out')
    ap.add_argument('--prefix', default='adsp2')
    a = ap.parse_args()

    names = collect(a.srcdir, a.prefix)
    entries_off = HDR.size
    data_off = entries_off + ENT.size * len(names)
    data_off = (data_off + 3) & ~3

    payload = bytearray()
    entries = []
    for name in names:
        blob = open(os.path.join(a.srcdir, name), 'rb').read()
        while len(payload) % 4:
            payload.append(0)
        entries.append((name, data_off + len(payload), len(blob)))
        payload += blob

    out = bytearray()
    out += HDR.pack(MAGIC, 1, len(entries), entries_off, 0)
    for name, off, size in entries:
        out += ENT.pack(name.encode(), off, size)
    out += bytes(data_off - len(out))
    out += payload

    with open(a.out, 'wb') as f:
        f.write(out)

    mdt = open(os.path.join(a.srcdir, a.prefix + '.mdt'), 'rb').read()
    print('packed %d files, %d bytes -> %s' % (len(entries), len(out), a.out))
    print('  mdt %d bytes, blob %d bytes' % (len(mdt), len(out)))
    for name, off, size in entries:
        if name.endswith('.mdt'):
            print('  %-12s off=%#x size=%d' % (name, off, size))


if __name__ == '__main__':
    main()
