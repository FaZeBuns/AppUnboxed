#!/usr/bin/env python3
"""Rewrites the SDK version in a 64-bit Mach-O's LC_BUILD_VERSION command.

The iPhone Duo runs any app stamped with an older SDK in letterboxed
compatibility mode, whatever SDK it was really compiled against. Stamping the
binary as 27.1 gets the full dual-screen canvas. Sign the binary AFTER
stamping; changing it afterwards invalidates the signature.

Usage:  python3 stamp_sdk.py <mach-o binary> [version, default 27.1]
"""
import struct
import sys

LC_BUILD_VERSION = 0x32
MH_MAGIC_64 = 0xFEEDFACF


def stamp(path, version="27.1"):
    major, minor = (int(x) for x in version.split(".")[:2])
    new_sdk = (major << 16) | (minor << 8)
    with open(path, "rb") as f:
        data = bytearray(f.read())
    if len(data) < 32 or struct.unpack_from("<I", data, 0)[0] != MH_MAGIC_64:
        raise SystemExit(f"{path}: not a thin 64-bit Mach-O binary")
    count = struct.unpack_from("<I", data, 16)[0]
    offset = 32
    patched = False
    for _ in range(count):
        cmd, size = struct.unpack_from("<II", data, offset)
        if cmd == LC_BUILD_VERSION:
            old = struct.unpack_from("<I", data, offset + 16)[0]
            struct.pack_into("<I", data, offset + 16, new_sdk)
            print(f"SDK stamp {old >> 16}.{(old >> 8) & 0xFF} -> {major}.{minor}")
            patched = True
        offset += size
    if not patched:
        raise SystemExit(f"{path}: no LC_BUILD_VERSION command found")
    with open(path, "wb") as f:
        f.write(data)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    stamp(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "27.1")
