#!/usr/bin/env python3
"""Extract Thunder Shock's verified electric texture from a supplied ROM.

Only the one I4 texture proven by the fragment-62 trace is written. The full
ROM, compressed archive member, and decompressed fragment are never cached.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import struct
import sys
import zlib
from pathlib import Path


PROBE_PATH = Path(__file__).with_name("stadium_fx_probe.py")
SPEC = importlib.util.spec_from_file_location("stadium_fx_probe", PROBE_PATH)
assert SPEC and SPEC.loader
PROBE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = PROBE
SPEC.loader.exec_module(PROBE)


CACHE_VERSION = 1
EFFECT_ARCHIVE = 0x8CC000
THUNDER_SHOCK_BUNDLE = 0x0F
ELECTRIC_ASSET_SLOT = 0x13
FRAGMENT_VRAM_BASE = 0x8FF00000
ELECTRIC_OFFSET = 0x4860
FRAME_WIDTH = 32
FRAME_HEIGHT = 96
FRAME_COUNT = 8
FRAME_BYTES = FRAME_WIDTH * FRAME_HEIGHT // 2
TEXTURE_BYTES = FRAME_BYTES * FRAME_COUNT


def be32(data: bytes, offset: int) -> int:
    if offset < 0 or offset + 4 > len(data):
        raise PROBE.StadiumRomError(f"truncated data at 0x{offset:X}")
    return struct.unpack_from(">I", data, offset)[0]


def archive_entry(reader: PROBE.Reader, archive_offset: int, index: int) -> bytes:
    if reader.u32be(archive_offset + 4) != 0:
        raise PROBE.StadiumRomError("effect archive has an invalid header")
    count = reader.u32be(archive_offset + 12)
    if count <= 0 or count >= 4096 or not 0 <= index < count:
        raise PROBE.StadiumRomError(f"effect archive does not contain member {index}")
    record = archive_offset + 0x10 + index * 0x10
    relative = reader.u32be(record)
    size = reader.u32be(record + 4)
    return reader.read(archive_offset + relative, size)


def yay0(data: bytes, base: int = 0) -> bytes:
    if data[base : base + 4] != b"Yay0":
        raise PROBE.StadiumRomError("archive member is not Yay0")
    size = be32(data, base + 4)
    if size > 16 * 1024 * 1024:
        raise PROBE.StadiumRomError("Yay0 output size is unreasonably large")
    mask_pos = base + 0x10
    link_pos = base + be32(data, base + 8)
    chunk_pos = base + be32(data, base + 12)
    out = bytearray()
    mask = 0
    bits = 0

    while len(out) < size:
        if bits == 0:
            mask = be32(data, mask_pos)
            mask_pos += 4
            bits = 32
        if mask & 0x80000000:
            if chunk_pos >= len(data):
                raise PROBE.StadiumRomError("truncated Yay0 literal stream")
            out.append(data[chunk_pos])
            chunk_pos += 1
        else:
            if link_pos + 2 > len(data):
                raise PROBE.StadiumRomError("truncated Yay0 link stream")
            link = struct.unpack_from(">H", data, link_pos)[0]
            link_pos += 2
            distance = (link & 0x0FFF) + 1
            count = link >> 12
            if count == 0:
                if chunk_pos >= len(data):
                    raise PROBE.StadiumRomError("truncated Yay0 count stream")
                count = data[chunk_pos] + 0x12
                chunk_pos += 1
            else:
                count += 2
            copy_pos = len(out) - distance
            if copy_pos < 0:
                raise PROBE.StadiumRomError("invalid Yay0 back-reference")
            for _ in range(count):
                if len(out) >= size:
                    break
                out.append(out[copy_pos])
                copy_pos += 1
        mask = (mask << 1) & 0xFFFFFFFF
        bits -= 1
    return bytes(out)


def decompress_member(blob: bytes) -> bytes:
    if blob[:8] == b"PERS-SZP":
        return yay0(blob, be32(blob, 8))
    if blob[:4] == b"Yay0":
        return yay0(blob)
    return blob


def find_asset_offset(fragment: bytes, slot: int) -> int:
    if fragment[8:16] != b"FRAGMENT":
        raise PROBE.StadiumRomError("effect bundle is not a Stadium fragment")
    table = be32(fragment, 0x10)
    for pos in range(table, min(len(fragment), table + 0x1000), 8):
        kind = fragment[pos]
        if kind == 0:
            break
        entry_slot = struct.unpack_from(">h", fragment, pos + 2)[0]
        pointer = be32(fragment, pos + 4)
        if entry_slot == slot:
            if pointer < FRAGMENT_VRAM_BASE:
                raise PROBE.StadiumRomError("effect asset pointer has an unexpected base")
            offset = pointer - FRAGMENT_VRAM_BASE
            if offset >= len(fragment):
                raise PROBE.StadiumRomError("effect asset pointer exceeds its fragment")
            return offset
    raise PROBE.StadiumRomError(f"effect bundle does not map runtime asset slot 0x{slot:X}")


def i4_atlas_rgba(texture: bytes) -> tuple[int, int, bytes]:
    if len(texture) != TEXTURE_BYTES:
        raise PROBE.StadiumRomError(
            f"electric texture is {len(texture)} bytes; expected {TEXTURE_BYTES}"
        )
    width = FRAME_WIDTH * FRAME_COUNT
    rgba = bytearray(width * FRAME_HEIGHT * 4)
    for frame in range(FRAME_COUNT):
        frame_data = texture[frame * FRAME_BYTES : (frame + 1) * FRAME_BYTES]
        for pixel in range(FRAME_WIDTH * FRAME_HEIGHT):
            packed = frame_data[pixel // 2]
            intensity = packed >> 4 if pixel % 2 == 0 else packed & 0x0F
            x = frame * FRAME_WIDTH + pixel % FRAME_WIDTH
            y = pixel // FRAME_WIDTH
            out = (y * width + x) * 4
            rgba[out : out + 4] = bytes((255, 255, 255, intensity * 17))
    return width, FRAME_HEIGHT, bytes(rgba)


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    body = kind + payload
    return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body))


def encode_png(width: int, height: int, rgba: bytes) -> bytes:
    stride = width * 4
    scanlines = b"".join(
        b"\0" + rgba[y * stride : (y + 1) * stride] for y in range(height)
    )
    return b"".join(
        (
            b"\x89PNG\r\n\x1a\n",
            png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)),
            png_chunk(b"IDAT", zlib.compress(scanlines, 9)),
            png_chunk(b"IEND", b""),
        )
    )


def extract(rom_path: Path, output_dir: Path) -> dict[str, object]:
    reader, rom_report = PROBE.open_rom(rom_path)
    member = archive_entry(reader, EFFECT_ARCHIVE, THUNDER_SHOCK_BUNDLE)
    fragment = decompress_member(member)
    asset_offset = find_asset_offset(fragment, ELECTRIC_ASSET_SLOT)
    if asset_offset != ELECTRIC_OFFSET:
        raise PROBE.StadiumRomError(
            f"electric texture moved to 0x{asset_offset:X}; expected 0x{ELECTRIC_OFFSET:X}"
        )
    texture = fragment[asset_offset : asset_offset + TEXTURE_BYTES]
    width, height, rgba = i4_atlas_rgba(texture)
    png = encode_png(width, height, rgba)

    output_dir.mkdir(parents=True, exist_ok=True)
    png_path = output_dir / "electric_i4_atlas.png"
    manifest_path = output_dir / "manifest.json"
    png_path.write_bytes(png)
    manifest = {
        "cache_version": CACHE_VERSION,
        "effect": "thunder_shock",
        "move_id": 84,
        "source_rom_md5": rom_report["md5"],
        "source_archive": f"0x{EFFECT_ARCHIVE:X}",
        "source_member": THUNDER_SHOCK_BUNDLE,
        "runtime_asset_slot": f"0x{ELECTRIC_ASSET_SLOT:X}",
        "fragment_offset": f"0x{asset_offset:X}",
        "source_format": "N64 I4",
        "frame_width": FRAME_WIDTH,
        "frame_height": FRAME_HEIGHT,
        "frame_count": FRAME_COUNT,
        "atlas_width": width,
        "atlas_height": height,
        "texture_sha256": hashlib.sha256(texture).hexdigest(),
        "atlas_sha256": hashlib.sha256(png).hexdigest(),
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path, help="verified Pokemon Stadium (USA) v1.0 ROM")
    parser.add_argument("output", type=Path, help="ignored private-cache output directory")
    args = parser.parse_args()
    try:
        report = extract(args.rom, args.output)
    except (OSError, PROBE.StadiumRomError) as exc:
        parser.error(str(exc))
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
