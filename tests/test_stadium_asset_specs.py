from __future__ import annotations

import importlib.util
import os
import re
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_SPEC = importlib.util.spec_from_file_location(
    "extract_stadium_assets", ROOT / "tools" / "extract_thunder_shock.py"
)
assert MODULE_SPEC and MODULE_SPEC.loader
EXTRACT = importlib.util.module_from_spec(MODULE_SPEC)
sys.modules[MODULE_SPEC.name] = EXTRACT
MODULE_SPEC.loader.exec_module(EXTRACT)

SPEC_PATTERN = re.compile(
    r'\{ name = "([^"]+)", member = 0x([0-9A-F]+), '
    r'slot = 0x([0-9A-F]+), offset = 0x([0-9A-F]+),\s*'
    r'format = "([^"]+)", width = (\d+), height = (\d+), '
    r'frames = (\d+), bytes = 0x([0-9A-F]+) \}',
    re.IGNORECASE,
)


def asset_specs() -> list[tuple[str, int, int, int, str, int, int, int, int]]:
    source = (ROOT / "lib" / "StadiumAssets.lua").read_text(encoding="utf-8")
    return [
        (name, int(member, 16), int(slot, 16), int(offset, 16), fmt,
         int(width), int(height), int(frames), int(byte_count, 16))
        for name, member, slot, offset, fmt, width, height, frames, byte_count
        in SPEC_PATTERN.findall(source)
    ]


class StadiumAssetSpecTests(unittest.TestCase):
    def test_names_and_format_sizes(self) -> None:
        specs = asset_specs()
        self.assertEqual(36, len(specs))
        self.assertEqual(36, len({row[0] for row in specs}))
        factors = {"i4": 1 / 2, "ia8": 1, "rgba16": 2}
        for name, _, _, _, fmt, width, height, frames, byte_count in specs:
            with self.subTest(name=name):
                self.assertIn(fmt, factors)
                self.assertEqual(width * height * frames * factors[fmt], byte_count)


@unittest.skipUnless(os.environ.get("STADIUM_ROM"), "set STADIUM_ROM for cartridge integration tests")
class StadiumAssetRomTests(unittest.TestCase):
    def test_all_ranges_match_stadium_one_archive(self) -> None:
        reader, _ = EXTRACT.PROBE.open_rom(Path(os.environ["STADIUM_ROM"]))
        fragments: dict[int, bytes] = {}
        for name, member, slot, offset, _, _, _, _, byte_count in asset_specs():
            if member not in fragments:
                blob = EXTRACT.archive_entry(reader, EXTRACT.EFFECT_ARCHIVE, member)
                fragments[member] = EXTRACT.decompress_member(blob)
            fragment = fragments[member]
            with self.subTest(name=name):
                self.assertEqual(offset, EXTRACT.find_asset_offset(fragment, slot))
                self.assertLessEqual(offset + byte_count, len(fragment))


if __name__ == "__main__":
    unittest.main()
