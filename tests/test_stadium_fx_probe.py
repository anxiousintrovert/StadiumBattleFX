from __future__ import annotations

import importlib.util
import os
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "stadium_fx_probe", ROOT / "tools" / "stadium_fx_probe.py"
)
assert SPEC and SPEC.loader
PROBE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = PROBE
SPEC.loader.exec_module(PROBE)


def as_v64(z64: bytes) -> bytes:
    out = bytearray(len(z64))
    out[0::2], out[1::2] = z64[1::2], z64[0::2]
    return bytes(out)


def as_n64(z64: bytes) -> bytes:
    out = bytearray(len(z64))
    out[0::4], out[1::4] = z64[3::4], z64[2::4]
    out[2::4], out[3::4] = z64[1::4], z64[0::4]
    return bytes(out)


class StadiumRomUnitTests(unittest.TestCase):
    def setUp(self) -> None:
        self.z64 = b"\x80\x37\x12\x40\x01\x02\x03\x04\x10\x20\x30\x40"

    def test_byte_orders_normalize_identically(self) -> None:
        for source, expected_order in (
            (self.z64, "z64"),
            (as_v64(self.z64), "v64"),
            (as_n64(self.z64), "n64"),
        ):
            normalized, order = PROBE.normalize(source)
            self.assertEqual(expected_order, order)
            self.assertEqual(self.z64, normalized)

    def test_raw_hash_allowlist_uses_each_dump_order(self) -> None:
        self.assertEqual("ed1378bc12115f71209a77844965ba50", PROBE.EXPECTED_SOURCE_MD5["z64"])
        self.assertEqual("3a7324ce816d5891dea074055690750a", PROBE.EXPECTED_SOURCE_MD5["v64"])
        self.assertEqual("f270920db049bf2f6b54812299c5c451", PROBE.EXPECTED_SOURCE_MD5["n64"])

    def test_bad_magic_is_rejected(self) -> None:
        with self.assertRaisesRegex(PROBE.StadiumRomError, "recognized N64"):
            PROBE.normalize(b"nope")

    def test_bounds_are_checked(self) -> None:
        reader = PROBE.Reader(self.z64)
        self.assertEqual(0x80371240, reader.u32be(0))
        self.assertEqual(0x0102, reader.u16be(4))
        with self.assertRaisesRegex(PROBE.StadiumRomError, "exceeds size"):
            reader.u32be(len(self.z64) - 3)

    def test_species_move_row_offset(self) -> None:
        self.assertEqual(PROBE.BATTLE_DATA_BASE, PROBE.species_move_row_offset(1, 1))
        self.assertEqual(
            0x71EE50,
            PROBE.species_move_row_offset(25, 84),
        )
        with self.assertRaisesRegex(PROBE.StadiumRomError, "species ID"):
            PROBE.species_move_row_offset(0, 84)
        with self.assertRaisesRegex(PROBE.StadiumRomError, "move ID"):
            PROBE.species_move_row_offset(25, 166)


@unittest.skipUnless(os.environ.get("STADIUM_ROM"), "set STADIUM_ROM for cartridge integration tests")
class StadiumRomIntegrationTests(unittest.TestCase):
    def test_supported_cartridge(self) -> None:
        report = PROBE.inspect_rom(Path(os.environ["STADIUM_ROM"]))
        self.assertEqual(PROBE.EXPECTED_MD5, report["md5"])
        self.assertEqual(PROBE.EXPECTED_SOURCE_MD5[report["source_order"]], report["source_md5"])
        self.assertEqual(PROBE.EXPECTED_SIZE, report["size"])
        self.assertEqual("80371240", report["normalized_magic"])

    def test_pikachu_thunder_shock_body_row(self) -> None:
        reader, _ = PROBE.open_rom(Path(os.environ["STADIUM_ROM"]))
        row = PROBE.species_move_row(reader, 25, 84)
        self.assertEqual("0x71EE50", row["offset_hex"])
        self.assertEqual("060464ff0d0001011e1e49000014152d", row["bytes_hex"])


if __name__ == "__main__":
    unittest.main()
