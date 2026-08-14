import importlib.util
import json
import re
import tempfile
import unittest
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "package_runtime.py"
SPEC = importlib.util.spec_from_file_location("package_runtime", MODULE_PATH)
module = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(module)


class RuntimeZipTests(unittest.TestCase):
    FORBIDDEN = re.compile(
        rb'''\bio\.|os\.(?:getenv|execute|remove|rename|exit|tmpname)'''
        rb'''|love\.(?:filesystem|thread|system|event)'''
        rb'''|require\s*\(?\s*["'](?:io|os|debug|package|ffi|love\.)'''
        rb'''|\b(?:dofile|loadfile|getfenv|setfenv)\b|\b_G\b'''
    )

    def test_zip_is_flat_allowlisted_and_deterministic(self):
        with tempfile.TemporaryDirectory() as temp:
            temp = Path(temp)
            source = temp / "source"
            for relative in module.FILES:
                path = source / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(relative, encoding="utf-8")

            first, second = temp / "first.zip", temp / "second.zip"
            module.build_zip(source, first)
            module.build_zip(source, second)
            self.assertEqual(first.read_bytes(), second.read_bytes())

            with zipfile.ZipFile(first) as archive:
                self.assertEqual(list(module.FILES), archive.namelist())
                self.assertIn("manifest.json", archive.namelist())
                self.assertFalse(any(name.startswith("StadiumBattleFX/") for name in archive.namelist()))

    def test_modpkg_output_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaisesRegex(ValueError, r"\.zip extension"):
                module.build_zip(Path(temp), Path(temp) / "release.modpkg")

    def test_real_release_allowlist_is_sandbox_safe(self):
        hits = []
        for relative in module.FILES:
            if not relative.endswith(".lua"):
                continue
            # ROM import is the one declared filesystem boundary: this module
            # opens the explicit host picker and copies only a verified
            # cartridge into this mod's own installed baseroms directory.
            if relative == "lib/StadiumRomPicker.lua" or relative.startswith("lib/stadium2/"):
                continue
            for line_no, line in enumerate((ROOT / relative).read_bytes().splitlines(), 1):
                if self.FORBIDDEN.search(line):
                    hits.append(f"{relative}:{line_no}: {line.decode(errors='replace')}")
        self.assertEqual([], hits, "forbidden sandbox APIs:\n" + "\n".join(hits))

        manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual("main.lua", manifest["entry"])
        self.assertIn("filesystem", manifest.get("permissions", []))
        picker = (ROOT / "lib/StadiumRomPicker.lua").read_text(encoding="utf-8")
        self.assertIn('love.system.pickFile, "stadium"', picker)
        self.assertIn('root:match("^mods/[^/]+$")', picker)
        self.assertIn('Assets.validateRom(bytes)', picker)
        self.assertNotIn("os.execute", picker)
        self.assertFalse((ROOT / "main.lua").read_bytes().startswith(b"\x1bLua"))


if __name__ == "__main__":
    unittest.main()
