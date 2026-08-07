import importlib.util
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "build_move_roster.py"
SPEC = importlib.util.spec_from_file_location("build_move_roster", MODULE_PATH)
module = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(module)


class MoveRosterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source_path = (
            ROOT.parent
            / "PokemonStadiumRecomp"
            / "disasm"
            / "src"
            / "fragments"
            / "62"
            / "fragment62_315D50.c"
        )
        cls.manifest_path = ROOT.parent / "Gen1Recomp" / "tools" / "rom_manifest_yellow.json"

    def roster(self):
        source = self.source_path.read_text(encoding="utf-8")
        names = module.load_move_names(self.manifest_path)
        return module.build_roster(source, names)

    def test_all_gen1_moves_are_present(self):
        roster = self.roster()
        self.assertEqual(165, len(roster))
        self.assertEqual((1, "POUND"), (roster[0]["id"], roster[0]["key"]))
        self.assertEqual((165, "STRUGGLE"), (roster[-1]["id"], roster[-1]["key"]))

    def test_thunder_shock_dispatch_and_resources(self):
        move = self.roster()[83]
        self.assertEqual([0x3B], move["primary"])
        self.assertEqual([0x08], move["impact"])
        self.assertEqual([0x0F], move["primaryResources"])
        self.assertEqual([], move["impactResources"])

    def test_padding_after_terminator_is_ignored(self):
        pound = self.roster()[0]
        self.assertEqual([], pound["primary"])
        self.assertEqual([0x2C], pound["impact"])
        self.assertEqual([0x18], pound["impactResources"])


if __name__ == "__main__":
    unittest.main()
