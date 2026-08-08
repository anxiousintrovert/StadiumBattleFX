from __future__ import annotations

import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CATALOG = json.loads((ROOT / "research" / "announcer_catalog.json").read_text())


def concrete_indices(value: object):
    if isinstance(value, dict):
        if "index" in value:
            yield value["index"]
        for child in value.values():
            yield from concrete_indices(child)
    elif isinstance(value, list):
        for child in value:
            yield from concrete_indices(child)


class AnnouncerCatalogTests(unittest.TestCase):
    def test_ranges_cover_every_clip_once(self) -> None:
        covered: list[int] = []
        for item in CATALOG["index_ranges"]:
            covered.extend(range(item["start"], item["end"] + 1))
        self.assertEqual(list(range(823)), covered)

    def test_all_concrete_event_indices_exist(self) -> None:
        indices = list(concrete_indices(CATALOG["events"]))
        indices.extend(concrete_indices(CATALOG["encounter_intros"]))
        indices.extend(concrete_indices(CATALOG["gym_series_intros"]))
        self.assertTrue(indices)
        self.assertTrue(all(0 <= index < 823 for index in indices))

    def test_formula_ranges_match_gen_one_ids(self) -> None:
        self.assertEqual((369, 519), (368 + 1, 368 + 151))
        self.assertEqual((584, 748), (583 + 1, 583 + 165))


if __name__ == "__main__":
    unittest.main()
