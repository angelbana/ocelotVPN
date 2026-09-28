#!/usr/bin/env python3
"""Packs the rendered PNGs into the icon Windows reads.

    python3 contrib/icons/pack-ico.py <png directory> src/ocelot.ico

An icon file is a small directory followed by the images themselves. Each entry
here is stored as PNG, which Windows has read since Vista and which keeps the
file a tenth of the size the old bitmap form would be.
"""

import pathlib
import struct
import sys

SIZES = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]


def main(source: pathlib.Path, target: pathlib.Path) -> int:
    images = []
    for side in SIZES:
        png = source / f"ocelot-{side}.png"
        data = png.read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n":
            print(f"{png} is not a PNG", file=sys.stderr)
            return 1
        images.append((side, data))

    header = struct.pack("<HHH", 0, 1, len(images))
    offset = len(header) + 16 * len(images)

    directory = b""
    body = b""
    for side, data in images:
        # 256 is written as zero: the field is one byte wide.
        byte = 0 if side >= 256 else side
        directory += struct.pack("<BBBBHHII", byte, byte, 0, 0, 1, 32, len(data), offset)
        body += data
        offset += len(data)

    target.write_bytes(header + directory + body)
    print(f"{target}: {target.stat().st_size} bytes, {len(images)} sizes")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        raise SystemExit(2)
    raise SystemExit(main(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])))
