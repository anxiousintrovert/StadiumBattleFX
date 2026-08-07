from __future__ import annotations

import importlib.util
import os
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "extract_thunder_shock", ROOT / "tools" / "extract_thunder_shock.py"
)
assert SPEC and SPEC.loader
EXTRACT = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = EXTRACT
SPEC.loader.exec_module(EXTRACT)


class ThunderShockExtractorUnitTests(unittest.TestCase):
    def test_i4_pixels_become_white_alpha(self) -> None:
        texture = bytes([0xF0]) * EXTRACT.TEXTURE_BYTES
        width, height, rgba = EXTRACT.i4_atlas_rgba(texture)
        self.assertEqual(256, width)
        self.assertEqual(96, height)
        self.assertEqual(bytes((255, 255, 255, 255)), rgba[:4])
        self.assertEqual(bytes((255, 255, 255, 0)), rgba[4:8])

    def test_png_encoder(self) -> None:
        png = EXTRACT.encode_png(1, 1, bytes((255, 255, 255, 255)))
        self.assertTrue(png.startswith(b"\x89PNG\r\n\x1a\n"))
        self.assertTrue(png.endswith(b"IEND\xaeB`\x82"))


@unittest.skipUnless(os.environ.get("STADIUM_ROM"), "set STADIUM_ROM for cartridge integration tests")
class ThunderShockExtractorIntegrationTests(unittest.TestCase):
    def test_verified_texture_extraction(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            report = EXTRACT.extract(Path(os.environ["STADIUM_ROM"]), Path(temp))
            self.assertEqual("0x4860", report["fragment_offset"])
            self.assertEqual(8, report["frame_count"])
            self.assertTrue((Path(temp) / "electric_i4_atlas.png").is_file())
            self.assertTrue((Path(temp) / "manifest.json").is_file())


if __name__ == "__main__":
    unittest.main()
