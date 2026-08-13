import importlib.util
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "tools" / "extract_stadium_body_sync.py"
SPEC = importlib.util.spec_from_file_location("extract_stadium_body_sync", PATH)
assert SPEC and SPEC.loader
SYNC = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = SYNC
SPEC.loader.exec_module(SYNC)


class BodySyncTests(unittest.TestCase):
    def test_matrix_addresses_are_dense_and_species_strided(self):
        first = SYNC.PROBE.species_move_row_offset(1, 1)
        self.assertEqual(SYNC.PROBE.species_move_row_offset(1, 165), first + 164 * 16)
        self.assertEqual(
            SYNC.PROBE.species_move_row_offset(2, 1) - first,
            SYNC.PROBE.SPECIES_BATTLE_STRIDE,
        )

    def test_local_rom_matrix_is_lossless_when_available(self):
        rom = ROOT.parent / "Pokemon Stadium (USA).z64"
        if not rom.exists():
            self.skipTest("developer ROM is not present")
        result = SYNC.extract(rom)
        self.assertEqual(result["speciesCount"], 151)
        self.assertEqual(result["moveCount"], 165)
        self.assertEqual(len(result["species"]), 151)
        self.assertEqual(len(result["species"][24]["moves"][83]), 16)
        self.assertEqual(sum(result["nonzeroByByteOffset"].values()) > 0, True)


if __name__ == "__main__":
    unittest.main()
