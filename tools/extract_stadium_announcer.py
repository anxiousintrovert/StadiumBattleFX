#!/usr/bin/env python3
"""Inventory and optionally extract Pokemon Stadium's MORT speech streams.

The input ROM is verified and normalized by ``stadium_fx_probe``. Extracted
files remain compressed MORT streams; decoding them to PCM is a separate step.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from pathlib import Path

from stadium_fx_probe import Reader, StadiumRomError, open_rom


SPEECH_ARCHIVE_OFFSET = 0x197C1E0
S1_MAGIC = b"S1"
MORT_MAGIC = b"MORT"
MORT_HEADER_SIZE = 12
SAMPLES_PER_FRAME = 0xA0


@dataclass(frozen=True)
class MortClip:
    index: int
    offset: int
    length: int
    frame_count: int
    sample_rate: int
    word_count: int
    archive_path: tuple[int, ...]

    @property
    def expected_pcm_samples(self) -> int:
        return self.frame_count * SAMPLES_PER_FRAME

    def report(self) -> dict[str, object]:
        result = asdict(self)
        result["archive_path"] = list(self.archive_path)
        result["offset_hex"] = f"0x{self.offset:X}"
        result["length_hex"] = f"0x{self.length:X}"
        result["expected_pcm_samples"] = self.expected_pcm_samples
        result["expected_duration_seconds"] = round(
            self.expected_pcm_samples / self.sample_rate, 6
        )
        return result


def _parse_mort(
    reader: Reader, offset: int, length: int, path: tuple[int, ...], index: int
) -> MortClip:
    if length < MORT_HEADER_SIZE:
        raise StadiumRomError(f"MORT entry at 0x{offset:X} is shorter than its header")
    if reader.read(offset, 4) != MORT_MAGIC:
        raise StadiumRomError(f"entry at 0x{offset:X} is neither S1 nor MORT")
    word_count = reader.u32be(offset + 8)
    if word_count * 4 != length:
        raise StadiumRomError(
            f"MORT entry at 0x{offset:X} reports 0x{word_count * 4:X} bytes, "
            f"archive supplies 0x{length:X}"
        )
    sample_rate = reader.u16be(offset + 6)
    if sample_rate == 0:
        raise StadiumRomError(f"MORT entry at 0x{offset:X} has zero sample rate")
    return MortClip(
        index=index,
        offset=offset,
        length=length,
        frame_count=reader.u16be(offset + 4),
        sample_rate=sample_rate,
        word_count=word_count,
        archive_path=path,
    )


def inventory(reader: Reader, root_offset: int = SPEECH_ARCHIVE_OFFSET) -> list[MortClip]:
    """Flatten the nested S1 archive into decoder-compatible MORT entries."""

    clips: list[MortClip] = []
    active_tables: set[int] = set()

    def visit(offset: int, length: int | None, path: tuple[int, ...]) -> None:
        magic = reader.read(offset, 4)
        if magic[:2] == S1_MAGIC:
            if offset in active_tables:
                raise StadiumRomError(f"cyclic S1 archive reference at 0x{offset:X}")
            active_tables.add(offset)
            count = int.from_bytes(magic[2:4], "big")
            table_size = 4 + count * 8
            if length is not None and table_size > length:
                raise StadiumRomError(f"S1 table at 0x{offset:X} exceeds its archive entry")
            reader.read(offset, table_size)
            for child_index in range(count):
                entry = offset + 4 + child_index * 8
                relative = reader.u32be(entry)
                child_length = reader.u32be(entry + 4)
                if relative < table_size:
                    raise StadiumRomError(
                        f"S1 child {child_index} at 0x{offset:X} overlaps its table"
                    )
                if length is not None and (
                    relative > length or child_length > length - relative
                ):
                    raise StadiumRomError(
                        f"S1 child {child_index} at 0x{offset:X} exceeds its parent"
                    )
                visit(offset + relative, child_length, path + (child_index,))
            active_tables.remove(offset)
            return
        if length is None:
            raise StadiumRomError(f"root at 0x{offset:X} is not an S1 table")
        clips.append(_parse_mort(reader, offset, length, path, len(clips)))

    visit(root_offset, None, ())
    return clips


def parse_indices(value: str | None, clip_count: int) -> list[int]:
    if value is None:
        return list(range(clip_count))
    selected: set[int] = set()
    for item in value.split(","):
        try:
            index = int(item.strip(), 0)
        except ValueError as exc:
            raise StadiumRomError(f"invalid clip index: {item!r}") from exc
        if not 0 <= index < clip_count:
            raise StadiumRomError(f"clip index {index} is outside 0..{clip_count - 1}")
        selected.add(index)
    return sorted(selected)


def extract(reader: Reader, clips: list[MortClip], indices: list[int], output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    selected = [clips[index] for index in indices]
    for clip in selected:
        (output / f"stadium_mort_{clip.index:03d}.mort").write_bytes(
            reader.read(clip.offset, clip.length)
        )
    manifest = {
        "format": "Pokemon Stadium MORT speech inventory v1",
        "source_archive_offset": f"0x{SPEECH_ARCHIVE_OFFSET:X}",
        "total_clip_count": len(clips),
        "extracted_clip_count": len(selected),
        "clips": [clip.report() for clip in selected],
    }
    (output / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path, help="Pokemon Stadium (USA) v1.0 ROM")
    parser.add_argument(
        "--output", type=Path, help="optional folder for compressed .mort files and manifest"
    )
    parser.add_argument(
        "--indices", help="comma-separated decimal or 0x-prefixed indices (default: all)"
    )
    args = parser.parse_args()
    try:
        reader, rom_report = open_rom(args.rom)
        clips = inventory(reader)
        indices = parse_indices(args.indices, len(clips))
        if args.output:
            extract(reader, clips, indices, args.output)
        elif args.indices is not None:
            parser.error("--indices requires --output")
    except StadiumRomError as exc:
        parser.error(str(exc))
    archive_counts: dict[int, int] = {}
    for clip in clips:
        archive_counts[clip.archive_path[0]] = archive_counts.get(clip.archive_path[0], 0) + 1
    print(
        json.dumps(
            {
                "revision": rom_report["revision"],
                "archive_offset": f"0x{SPEECH_ARCHIVE_OFFSET:X}",
                "clip_count": len(clips),
                "root_child_clip_counts": archive_counts,
                "sample_rates": sorted({clip.sample_rate for clip in clips}),
                "extracted": len(indices) if args.output else 0,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
