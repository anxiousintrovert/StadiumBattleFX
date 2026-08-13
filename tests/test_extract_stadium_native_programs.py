from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


TOOL_PATH = Path(__file__).parents[1] / "tools" / "extract_stadium_native_programs.py"
SPEC = importlib.util.spec_from_file_location("extract_stadium_native_programs", TOOL_PATH)
assert SPEC and SPEC.loader
TOOL = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = TOOL
SPEC.loader.exec_module(TOOL)


class NativeProgramExtractorTests(unittest.TestCase):
    def test_split_args_preserves_nested_expressions(self) -> None:
        self.assertEqual(
            TOOL.split_args("0, fn(a, b), &table[index + 1], (u8)(x, y)"),
            ["0", "fn(a, b)", "&table[index + 1]", "(u8)(x, y)"],
        )

    def test_scheduler_calls_retain_expressions_and_line(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "effect.c"
            source = "\n".join([
                "void func_84330000(void) {",
                "  func_8432EB14();",
                "  func_8432ECA0(3 + n, 2, count - 1, callback,",
                "                   &D_843861D0[index], 4, 5, 6, 7, 8, 9);",
                "}",
            ])
            path.write_text(source, encoding="utf-8")
            fn = TOOL.functions(Path(tmp))["func_84330000"]
            calls = TOOL.scheduler_calls(fn)
            self.assertEqual([call["helper"] for call in calls], ["func_8432EB14", "func_8432ECA0"])
            self.assertEqual(calls[1]["args"][0], "3 + n")
            self.assertEqual(calls[1]["args"][4], "&D_843861D0[index]")
            self.assertEqual(calls[1]["source"]["line"], 3)

    def test_initializer_entries_preserve_rows(self) -> None:
        source = """static Row rows[] = {
          { 1, func_1, &assets[3] },
          { 3, func_2 },
        };"""
        self.assertEqual(
            TOOL.initializer_entries(source, "rows"),
            [["1", "func_1", "&assets[3]"], ["3", "func_2"]],
        )

    def test_native_events_apply_cursor_and_wrapper_argument_order(self) -> None:
        calls = [
            {"helper": "func_8432EB20", "args": ["0x10"], "source": {"line": 1}},
            {"helper": "func_8432EB2C", "args": ["4"], "source": {"line": 2}},
            {"helper": "func_8432ECA0", "args": [
                "8", "3", "5", "func_8433D560", "&D_843861D0[0x13]",
                "0x14", "4", "7", "0", "0x2C", "1",
            ], "source": {"line": 3}},
        ]
        event = TOOL.native_events(calls)[0]
        self.assertEqual(event["at"], 28)
        self.assertEqual(event["interval"], 3)
        self.assertEqual(event["repeats"], 5)
        self.assertEqual(event["particleCount"], 20)
        self.assertEqual(event["batchSize"], 4)
        self.assertEqual(event["anchorMode"], 7)
        self.assertEqual(event["attachment"], 0)
        self.assertEqual(event["aux"], 44)
        self.assertEqual(event["aux2"], 1)
        self.assertEqual(event["renderPreset"], 0x13)

    def test_native_events_preserve_dynamic_source_expressions(self) -> None:
        calls = [{
            "helper": "func_8432EC28",
            "args": ["D_843902E2", "callback", "&D_843861D0[index]",
                     "count", "1", "0x10", "9", "3", "0"],
            "source": {"line": 8},
        }]
        event = TOOL.native_events(calls)[0]
        self.assertEqual(event["at"], "(0) + (D_843902E2)")
        self.assertEqual(event["particleCount"], "count")
        self.assertIsNone(event["renderPreset"])


if __name__ == "__main__":
    unittest.main()
