#!/usr/bin/env python3
"""Extract Stadium's complete Gen-I species/move body synchronization matrix.

The output is private cache data derived from the user's ROM. No timing field
is interpreted or normalized: each row retains all sixteen source bytes and
its exact ROM address so controller semantics can be added without re-ripping.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path


PROBE_PATH = Path(__file__).with_name("stadium_fx_probe.py")
SPEC = importlib.util.spec_from_file_location("stadium_fx_probe", PROBE_PATH)
assert SPEC and SPEC.loader
PROBE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = PROBE
SPEC.loader.exec_module(PROBE)


def extract(rom_path: Path) -> dict[str, object]:
    reader, rom = PROBE.open_rom(rom_path)
    species_rows: list[dict[str, object]] = []
    digest = hashlib.sha256()
    nonzero = [0] * 16
    for species_id in range(1, PROBE.GEN1_SPECIES_COUNT + 1):
        moves: list[list[int]] = []
        base = PROBE.species_move_row_offset(species_id, 1)
        for move_id in range(1, PROBE.STADIUM_MOVE_COUNT + 1):
            offset = PROBE.species_move_row_offset(species_id, move_id)
            raw = list(reader.read(offset, PROBE.MOVE_ROW_WIDTH))
            digest.update(bytes(raw))
            for field, value in enumerate(raw):
                if value: nonzero[field] += 1
            moves.append(raw)
        species_rows.append({"speciesId": species_id, "romOffset": base, "moves": moves})
    return {
        "schema": 1,
        "sourceRomMd5": rom["md5"],
        "speciesCount": PROBE.GEN1_SPECIES_COUNT,
        "moveCount": PROBE.STADIUM_MOVE_COUNT,
        "rowBytes": PROBE.MOVE_ROW_WIDTH,
        "matrixSha256": digest.hexdigest(),
        "nonzeroByByteOffset": {f"0x{i:02X}": count for i, count in enumerate(nonzero)},
        "species": species_rows,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        result = extract(args.rom)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, separators=(",", ":")) + "\n", encoding="utf-8")
    except (OSError, PROBE.StadiumRomError) as exc:
        parser.error(str(exc))
    print(json.dumps({key: result[key] for key in (
        "sourceRomMd5", "speciesCount", "moveCount", "matrixSha256", "nonzeroByByteOffset"
    )}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
