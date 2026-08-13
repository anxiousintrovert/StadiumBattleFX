from __future__ import annotations

import importlib.util
import json
import struct
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "patch_announcer_zip", ROOT / "tools" / "patch_announcer_zip.py"
)
assert SPEC and SPEC.loader
PATCHER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = PATCHER
SPEC.loader.exec_module(PATCHER)


def wav(samples: int = 160) -> bytes:
    payload = b"\0\0" * samples
    return (
        b"RIFF"
        + struct.pack("<I", 36 + len(payload))
        + b"WAVEfmt "
        + struct.pack("<IHHIIHH", 16, 1, 1, 16000, 32000, 2, 16)
        + b"data"
        + struct.pack("<I", len(payload))
        + payload
    )


class AnnouncerZipPatcherTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.base = self.root / "base.zip"
        with zipfile.ZipFile(self.base, "w") as archive:
            archive.writestr(
                "manifest.json", json.dumps({"id": "STADIUM_BATTLE_FX", "version": "1.2.3"})
            )
            archive.writestr("main.lua", "return function() end\n")
            archive.writestr("assets/announcer/old.wav", b"stale")
        self.wavs = self.root / "wavs"
        self.wavs.mkdir()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_partial_pack_injects_marker_and_numbered_wav(self) -> None:
        (self.wavs / "BANK_A6_INSTR_0000_SND_0000.wav").write_bytes(wav())
        output = self.root / "local.zip"
        result = PATCHER.patch_zip(
            self.base, self.wavs, output, require_complete=False
        )
        self.assertEqual(1, result["clips"])
        with zipfile.ZipFile(output) as archive:
            self.assertIn("assets/announcer/166.wav", archive.namelist())
            self.assertNotIn("assets/announcer/old.wav", archive.namelist())
            marker = json.loads(archive.read("assets/announcer/voicepack.json"))
            self.assertEqual([166], marker["indices"])
            self.assertEqual("1.2.3", marker["base_mod_version"])

    def test_complete_mode_rejects_missing_clips(self) -> None:
        (self.wavs / "stadium_mort_000.wav").write_bytes(wav())
        with self.assertRaisesRegex(PATCHER.VoicePackError, "1/823"):
            PATCHER.patch_zip(self.base, self.wavs, self.root / "out.zip")

    def test_local_rom_can_be_bundled_for_sandboxed_runtime(self) -> None:
        (self.wavs / "stadium_mort_000.wav").write_bytes(wav())
        rom = self.root / "owned.v64"
        rom.write_bytes(b"owned-rom")
        output = self.root / "local.zip"
        result = PATCHER.patch_zip(
            self.base, self.wavs, output, require_complete=False, rom=rom
        )
        self.assertTrue(result["rom_bundled"])
        with zipfile.ZipFile(output) as archive:
            self.assertEqual(b"owned-rom", archive.read("baseroms/baserom.z64"))

    def test_normalized_rom_bytes_can_be_bundled(self) -> None:
        (self.wavs / "stadium_mort_000.wav").write_bytes(wav())
        output = self.root / "local.zip"
        PATCHER.patch_zip(
            self.base,
            self.wavs,
            output,
            require_complete=False,
            rom=b"canonical-z64",
        )
        with zipfile.ZipFile(output) as archive:
            self.assertEqual(b"canonical-z64", archive.read("baseroms/baserom.z64"))

    def test_official_zip_cannot_be_overwritten(self) -> None:
        (self.wavs / "stadium_mort_000.wav").write_bytes(wav())
        with self.assertRaisesRegex(PATCHER.VoicePackError, "must not overwrite"):
            PATCHER.patch_zip(
                self.base, self.wavs, self.base, require_complete=False
            )

    def test_wav_contract_is_enforced(self) -> None:
        with self.assertRaisesRegex(PATCHER.VoicePackError, "not a RIFF"):
            PATCHER.inspect_wav(b"bad", "bad.wav")


if __name__ == "__main__":
    unittest.main()
