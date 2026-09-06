"""Label native sRGB PNGs without decoding or changing any image samples."""
import struct
import zlib
from pathlib import Path


def tag_srgb(path: Path) -> None:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG: {path}")
    position = 8
    chunks = []
    while position < len(data):
        length = struct.unpack_from(">I", data, position)[0]
        chunk = data[position:position + length + 12]
        if len(chunk) != length + 12:
            raise ValueError(f"Truncated PNG: {path}")
        if zlib.crc32(chunk[4:-4]) & 0xffffffff != struct.unpack(">I", chunk[-4:])[0]:
            raise ValueError(f"Corrupt PNG chunk: {path}")
        if chunk[4:8] not in (b"sRGB", b"gAMA", b"cHRM", b"iCCP", b"cICP"):
            chunks.append(chunk)
        position += length + 12
    if not chunks or chunks[0][4:8] != b"IHDR":
        raise ValueError(f"PNG missing first IHDR: {path}")
    payload = b"sRGB\x00"
    srgb = struct.pack(">I", 1) + payload + struct.pack(">I", zlib.crc32(payload) & 0xffffffff)
    result = data[:8] + chunks[0] + srgb + b"".join(chunks[1:])
    # All original IDAT chunks are copied verbatim; only profile metadata changes.
    if result != data:
        path.write_bytes(result)
