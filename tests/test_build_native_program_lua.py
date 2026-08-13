from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


TOOL_PATH = Path(__file__).parents[1] / "tools" / "build_native_program_lua.py"
SPEC = importlib.util.spec_from_file_location("build_native_program_lua", TOOL_PATH)
assert SPEC and SPEC.loader
TOOL = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = TOOL
SPEC.loader.exec_module(TOOL)


class NativeProgramLuaTests(unittest.TestCase):
    def test_compiler_links_move_opcodes_and_strips_source_bodies(self) -> None:
        source = {
            "schema": 2,
            "sourceRevision": "abc",
            "moves": [{"id": 84, "key": "THUNDERSHOCK", "primary": [0x3B],
                       "alternate": [], "impact": [8]}],
            "programs": {
                "primary:0x3B": {"channel": "primary", "opcode": 0x3B,
                    "assetSlots": [0x13], "nativeEvents": [{"at": 4,
                    "callback": "func_1", "particlePreset": 20,
                    "source": {"file": "ignored.c"}}]},
            },
            "renderPresets": [{"index": 20, "kind": "0x1", "target": "asset"}],
            "particlePresets": [{"index": 20, "asset": "slot",
                "draw": "draw_fn", "initialize": "init_fn", "batchMode": "0x01"}],
        }
        data = TOOL.compile_data(source)
        self.assertEqual(data["moves"][84]["primary"], ["primary:0x3B"])
        self.assertEqual(data["programs"]["primary:0x3B"]["events"], [
            {"at": 4, "callback": "func_1", "particlePreset": 20},
        ])
        self.assertNotIn("ignored.c", TOOL.lua(data))
        self.assertEqual(data["renderPresets"][20]["target"], "asset")
        self.assertEqual(data["particlePresets"][20]["draw"], "draw_fn")


if __name__ == "__main__":
    unittest.main()
