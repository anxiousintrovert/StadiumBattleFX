import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "build_all_move_specs.py"
SPEC = importlib.util.spec_from_file_location("build_all_move_specs", MODULE_PATH)
module = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(module)


class CompleteMoveSpecTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.moves_path = ROOT.parent / "Gen1Recomp" / "data" / "generated" / "moves.lua"
        cls.rows = module.parse_moves(cls.moves_path)

    def test_complete_ordered_roster(self):
        self.assertEqual(165, len(self.rows))
        self.assertEqual(list(range(1, 166)), [row["id"] for row in self.rows])

    def test_every_move_gets_a_complete_presentation(self):
        for row in self.rows:
            spec = module.presentation(row)
            self.assertIn(spec["delivery"], {"contact", "projectile", "beam", "status", "screen"})
            self.assertIn(spec["anchor"], {"attacker", "target"})
            self.assertIn(spec["visual"], {
                "impact", "rush", "slash", "punch", "kick", "bite",
                "grapple", "needle", "leaf", "orb", "wind", "sound",
                "stream", "wave", "beam", "storm", "electric", "psychic",
                "drain", "ground", "status", "barrier", "heal", "transform",
                "explosion", "flash", "mist", "haze",
            })
            self.assertIn(spec["cinematic"], {
                "melee", "combo", "sustained", "aerial", "field", "status",
                "self", "explosion", "ranged",
            })
            self.assertGreaterEqual(spec["hits"], 1)
            self.assertGreater(spec["duration"], spec["impactAt"])
            self.assertEqual("portable-behavior-v2", spec["calibration"])

    def test_representative_special_cases(self):
        by_key = {row["key"]: module.presentation(row) for row in self.rows}
        self.assertEqual("beam", by_key["HYPER_BEAM"]["delivery"])
        self.assertEqual("screen", by_key["EXPLOSION"]["delivery"])
        self.assertEqual("attacker", by_key["RECOVER"]["anchor"])
        self.assertEqual(4, by_key["FURY_ATTACK"]["hits"])
        self.assertEqual("slash", by_key["SLASH"]["visual"])
        self.assertEqual("ground", by_key["EARTHQUAKE"]["visual"])
        self.assertEqual("explosion", by_key["EXPLOSION"]["cinematic"])
        self.assertEqual("screen", by_key["FLASH"]["delivery"])
        self.assertEqual("flash", by_key["FLASH"]["visual"])
        self.assertEqual("mist", by_key["MIST"]["visual"])
        self.assertEqual("haze", by_key["HAZE"]["visual"])
        self.assertEqual(
            by_key["DOUBLESLAP"]["cinematic"],
            by_key["FURY_ATTACK"]["cinematic"],
        )

    def test_generator_is_deterministic(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "AllMoveSpecs.lua"
            module.write_lua(output, self.rows)
            checked_in = ROOT / "lib" / "effects" / "AllMoveSpecs.lua"
            self.assertEqual(
                checked_in.read_text(encoding="utf-8"),
                output.read_text(encoding="utf-8"),
            )


if __name__ == "__main__":
    unittest.main()
