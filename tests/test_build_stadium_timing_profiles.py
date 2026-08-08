import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "build_stadium_timing_profiles.py"
SPEC = importlib.util.spec_from_file_location("build_stadium_timing_profiles", MODULE_PATH)
module = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(module)


class StadiumTimingProfileTests(unittest.TestCase):
    def test_cursor_completion_and_repeated_emissions(self):
        source = """
        void func_11111111(void) {
            func_8432ECA0(0, 4, 3, callback, data, 0, 1, 2, 0, 0, 0);
            func_8432EB2C(0x23);
            func_8432EDE8(8, 4, 8, 0xA);
            func_8432F8E8(0x64, 1);
        }
        """
        timing = module.sequence_timing(
            [0], ["func_11111111"], module.function_bodies(source)
        )
        self.assertEqual({"marker": 135, "phase": 35, "last": 135}, timing)

    def test_completion_marker_controls_lifecycle(self):
        result = module.calibrate(
            {"impactAt": 44, "duration": 90},
            {"marker": 100, "phase": 35, "last": 100},
            {"marker": 0, "phase": 0, "last": 8},
        )
        self.assertEqual(43, result["impactAt"])
        self.assertEqual(104, result["duration"])
        self.assertEqual("controller-completion", result["timingEvidence"])

    def test_checked_in_profiles_are_reproducible(self):
        source_dir = ROOT.parent / "pokestadium" / "src" / "fragments" / "62"
        moves = ROOT.parent / "Gen1Recomp" / "data" / "generated" / "moves.lua"
        if not source_dir.is_dir() or not moves.is_file():
            self.skipTest("local Stadium/Gen1Recomp source trees are unavailable")
        dispatch = (source_dir / "fragment62_315D50.c").read_text(encoding="utf-8")
        source = "\n".join(
            path.read_text(encoding="utf-8") for path in sorted(source_dir.glob("*.c"))
        )
        profiles = module.build_profiles(
            module.parse_roster(ROOT / "lib" / "effects" / "StadiumMoveRoster.lua"),
            module.load_presentations(moves, ROOT / "tools" / "build_all_move_specs.py"),
            module.initializer_table(dispatch, "D_84386480"),
            module.initializer_table(dispatch, "D_843866C4"),
            module.function_bodies(source),
        )
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "StadiumTimingProfiles.lua"
            module.write_lua(output, profiles)
            self.assertEqual(
                (ROOT / "lib" / "effects" / "StadiumTimingProfiles.lua").read_text(
                    encoding="utf-8"
                ),
                output.read_text(encoding="utf-8"),
            )


if __name__ == "__main__":
    unittest.main()
