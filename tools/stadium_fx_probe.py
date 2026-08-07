#!/usr/bin/env python3
"""Read-only Pokemon Stadium ROM identification and binary probe.

This tool never writes ROM-derived output. It prints revision metadata and is
the reference implementation for byte-order normalization and bounded reads.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path


EXPECTED_SIZE = 32 * 1024 * 1024
EXPECTED_MD5 = "ed1378bc12115f71209a77844965ba50"
BATTLE_DATA_BASE = 0x70D3A0
SPECIES_BATTLE_STRIDE = 0xB90
MOVE_ROW_WIDTH = 0x10
GEN1_SPECIES_COUNT = 151
STADIUM_MOVE_COUNT = 165
MAGIC = {
    b"\x80\x37\x12\x40": "z64",
    b"\x37\x80\x40\x12": "v64",
    b"\x40\x12\x37\x80": "n64",
}


class StadiumRomError(ValueError):
    """A cleanly reportable ROM compatibility or bounds error."""


def detect_byte_order(data: bytes) -> str:
    if len(data) < 4:
        raise StadiumRomError("ROM is too small to contain an N64 header")
    try:
        return MAGIC[data[:4]]
    except KeyError as exc:
        raise StadiumRomError("file does not have a recognized N64 ROM byte order") from exc


def normalize(data: bytes) -> tuple[bytes, str]:
    order = detect_byte_order(data)
    if order == "z64":
        return data, order
    if order == "v64":
        if len(data) % 2:
            raise StadiumRomError("v64 ROM length is not divisible by two")
        out = bytearray(len(data))
        out[0::2], out[1::2] = data[1::2], data[0::2]
        return bytes(out), order
    if len(data) % 4:
        raise StadiumRomError("n64 ROM length is not divisible by four")
    out = bytearray(len(data))
    out[0::4], out[1::4] = data[3::4], data[2::4]
    out[2::4], out[3::4] = data[1::4], data[0::4]
    return bytes(out), order


@dataclass(frozen=True)
class Reader:
    data: bytes

    def _range(self, offset: int, width: int) -> slice:
        if not isinstance(offset, int) or not isinstance(width, int):
            raise StadiumRomError("ROM offset and width must be integers")
        if offset < 0 or width < 0:
            raise StadiumRomError("ROM offset and width cannot be negative")
        if offset > len(self.data) or width > len(self.data) - offset:
            raise StadiumRomError(
                f"ROM read 0x{offset:X}..0x{offset + width:X} "
                f"exceeds size 0x{len(self.data):X}"
            )
        return slice(offset, offset + width)

    def read(self, offset: int, width: int) -> bytes:
        return self.data[self._range(offset, width)]

    def u8(self, offset: int) -> int:
        return self.read(offset, 1)[0]

    def u16be(self, offset: int) -> int:
        return int.from_bytes(self.read(offset, 2), "big")

    def u32be(self, offset: int) -> int:
        return int.from_bytes(self.read(offset, 4), "big")


def open_rom(path: Path) -> tuple[Reader, dict[str, object]]:
    normalized, order = normalize(path.read_bytes())
    if len(normalized) != EXPECTED_SIZE:
        raise StadiumRomError(
            f"unsupported Stadium ROM size: {len(normalized)} bytes; "
            f"expected {EXPECTED_SIZE}"
        )
    digest = hashlib.md5(normalized).hexdigest()
    if digest != EXPECTED_MD5:
        raise StadiumRomError(
            "unsupported Pokemon Stadium ROM; expected Pokemon Stadium (USA) v1.0"
        )
    reader = Reader(normalized)
    report = {
        "path": str(path.resolve()),
        "source_order": order,
        "normalized_magic": reader.read(0, 4).hex(),
        "size": len(normalized),
        "md5": digest,
        "revision": "Pokemon Stadium (USA) v1.0",
    }
    return reader, report


def inspect_rom(path: Path) -> dict[str, object]:
    _, report = open_rom(path)
    return report


def species_move_row_offset(species_id: int, move_id: int) -> int:
    """Return the ROM offset of a species-specific body-animation row.

    This is the 16-byte model/body-animation mapping, not the procedural VFX
    program. The formula is verified against pret/pokestadium fragment 62's
    D_80075BD0 table and func_84302658 loader.
    """
    if not 1 <= species_id <= GEN1_SPECIES_COUNT:
        raise StadiumRomError(
            f"species ID must be in 1..{GEN1_SPECIES_COUNT}; got {species_id}"
        )
    if not 1 <= move_id <= STADIUM_MOVE_COUNT:
        raise StadiumRomError(
            f"move ID must be in 1..{STADIUM_MOVE_COUNT}; got {move_id}"
        )
    return (
        BATTLE_DATA_BASE
        + (species_id - 1) * SPECIES_BATTLE_STRIDE
        + (move_id - 1) * MOVE_ROW_WIDTH
    )


def species_move_row(reader: Reader, species_id: int, move_id: int) -> dict[str, object]:
    offset = species_move_row_offset(species_id, move_id)
    row = reader.read(offset, MOVE_ROW_WIDTH)
    return {
        "kind": "species_body_animation_row",
        "species_id": species_id,
        "move_id": move_id,
        "offset": offset,
        "offset_hex": f"0x{offset:X}",
        "bytes_hex": row.hex(),
        "bytes": list(row),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path, help="path to a user-supplied Stadium ROM")
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    parser.add_argument("--species", type=int, help="inspect a Gen I species body-animation row")
    parser.add_argument("--move", type=int, help="move ID used with --species")
    args = parser.parse_args()
    if (args.species is None) != (args.move is None):
        parser.error("--species and --move must be supplied together")
    try:
        reader, report = open_rom(args.rom)
        if args.species is not None:
            report["body_animation_row"] = species_move_row(
                reader, args.species, args.move
            )
    except (OSError, StadiumRomError) as exc:
        parser.error(str(exc))
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        for key, value in report.items():
            print(f"{key}: {value}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
