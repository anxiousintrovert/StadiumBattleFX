from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
sys.path.insert(0, str(TOOLS))
SPEC = importlib.util.spec_from_file_location(
    "extract_stadium_announcer", TOOLS / "extract_stadium_announcer.py"
)
assert SPEC and SPEC.loader
EXTRACTOR = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = EXTRACTOR
SPEC.loader.exec_module(EXTRACTOR)
from stadium_fx_probe import Reader, StadiumRomError  # noqa: E402


def mort(frames: int = 2, rate: int = 16000, words: int = 4) -> bytes:
    return (
        b"MORT"
        + frames.to_bytes(2, "big")
        + rate.to_bytes(2, "big")
        + words.to_bytes(4, "big")
        + bytes(words * 4 - 12)
    )


def s1(children: list[bytes]) -> bytes:
    table_size = 4 + len(children) * 8
    cursor = table_size
    table = bytearray(b"S1" + len(children).to_bytes(2, "big"))
    for child in children:
        table.extend(cursor.to_bytes(4, "big"))
        table.extend(len(child).to_bytes(4, "big"))
        cursor += len(child)
    return bytes(table) + b"".join(children)


class StadiumAnnouncerExtractorTests(unittest.TestCase):
    def test_nested_s1_inventory_is_flattened_in_archive_order(self) -> None:
        data = s1([s1([mort(frames=1), mort(frames=3)]), mort(frames=5)])
        clips = EXTRACTOR.inventory(Reader(data), root_offset=0)
        self.assertEqual([0, 1, 2], [clip.index for clip in clips])
        self.assertEqual([(0, 0), (0, 1), (1,)], [clip.archive_path for clip in clips])
        self.assertEqual([160, 480, 800], [clip.expected_pcm_samples for clip in clips])
        self.assertEqual({16000}, {clip.sample_rate for clip in clips})

    def test_mort_word_count_must_match_archive_length(self) -> None:
        bad = b"MORT\x00\x01\x3e\x80\x00\x00\x00\x04"
        with self.assertRaisesRegex(StadiumRomError, "archive supplies"):
            EXTRACTOR.inventory(Reader(s1([bad])), root_offset=0)

    def test_index_selection_is_unique_sorted_and_bounded(self) -> None:
        self.assertEqual([1, 2], EXTRACTOR.parse_indices("2,0x1,2", 3))
        with self.assertRaisesRegex(StadiumRomError, "outside"):
            EXTRACTOR.parse_indices("3", 3)


if __name__ == "__main__":
    unittest.main()
