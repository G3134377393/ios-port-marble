#!/usr/bin/env python3
"""Unwrap Apple IM4P (DER) -> raw payload, e.g. the LZFSE-compressed device tree."""
import pathlib, sys

src = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "assets/DeviceTree.d22ap.im4p")
dst = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else "adt.lzfse")
d = src.read_bytes()


def tlv(buf, off):
    tag = buf[off]; off += 1
    l = buf[off]; off += 1
    if l & 0x80:
        n = l & 0x7f
        l = int.from_bytes(buf[off:off + n], "big"); off += n
    return tag, l, off


tag, ln, off = tlv(d, 0)
end = off + ln
payload = None
while off < end:
    tag, l, body = tlv(d, off)
    if tag == 0x04:
        payload = d[body:body + l]
        break
    off = body + l
assert payload is not None, "no OCTET STRING payload"
dst.write_bytes(payload)
print("wrote %s (%d bytes) magic=%s" % (dst, len(payload), payload[:4].hex()))
