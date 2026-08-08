import importlib.util
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


if __name__ == "__main__":
    unittest.main()
