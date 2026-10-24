#!/usr/bin/env python3
"""Minimal Android boot image v4 builder for fastboot boot.

Header v4 layout (1584 bytes):
  magic[8], kernel_size, ramdisk_size, os_version, header_size,
  reserved[4], header_version, cmdline[1536]
Sections are 4096-byte aligned.
"""
import argparse
import struct

PAGE = 4096
HDR_SIZE = 1584


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernel", required=True)
    ap.add_argument("--ramdisk", required=True)
    ap.add_argument("--cmdline", default="")
    ap.add_argument("--os-version", type=lambda x: int(x, 0), default=0)
    ap.add_argument("--signature-size", type=int, default=4096)
    ap.add_argument("-o", required=True)
    a = ap.parse_args()

    kernel = open(a.kernel, "rb").read()
    ramdisk = open(a.ramdisk, "rb").read()
    cmdline = a.cmdline.encode()
    if len(cmdline) >= 1536:
        raise SystemExit("cmdline too long")
    if a.signature_size not in (0, 4096):
        raise SystemExit("signature_size must be 0 or 4096")

    hdr = struct.pack(
        "<8sIIII4II1536sI",
        b"ANDROID!", len(kernel), len(ramdisk), a.os_version, HDR_SIZE,
        0, 0, 0, 0, 4, cmdline, a.signature_size,
    )
    assert len(hdr) == HDR_SIZE

    out = bytearray()
    out += hdr + b"\0" * ((-len(hdr)) % PAGE)
    out += kernel + b"\0" * ((-len(kernel)) % PAGE)
    out += ramdisk + b"\0" * ((-len(ramdisk)) % PAGE)
    if a.signature_size:
        out += b"\0" * a.signature_size
    open(a.o, "wb").write(out)
    print(f"wrote {a.o}: kernel={len(kernel)} ramdisk={len(ramdisk)} "
          f"sig={a.signature_size} total={len(out)}")


if __name__ == "__main__":
    main()
