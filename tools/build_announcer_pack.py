#!/usr/bin/env python3
"""Build a local StadiumBattleFX personalized pack from selected Stadium ROMs."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from typing import Callable

from extract_stadium_announcer import StadiumRomError, inventory, open_rom
from patch_announcer_zip import CLIP_COUNT, VoicePackError, patch_zip
from build_stadium_cache import StadiumCacheBuildError, build_stadium_cache


Progress = Callable[[float, str], None]


class AnnouncerBuildError(RuntimeError):
    pass


def bundled_path(relative: str) -> Path:
    root = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
    return root / relative


def default_decoder() -> Path:
    name = "mort_decoder.exe" if os.name == "nt" else "mort_decoder"
    candidates = (
        bundled_path(name),
        Path(__file__).resolve().parent / "mort_decoder" / name,
    )
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise AnnouncerBuildError("The bundled MORT decoder is missing.")


def _run_decoder_batch(decoder: Path, mort_dir: Path, wav_dir: Path) -> None:
    """Run the decoder once for the complete, local-only clip set.

    A previous version started one native process for every clip.  Aside from
    the unnecessary overhead, that resembles a common malware heuristic: a
    GUI executable rapidly extracting files to a temporary directory and
    launching hundreds of child processes.  The decoder now has an explicit,
    bounded batch mode instead.
    """
    startup = None
    flags = 0
    if os.name == "nt":
        flags = subprocess.CREATE_NO_WINDOW
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    result = subprocess.run(
        [str(decoder), "--batch", str(mort_dir), str(wav_dir)],
        capture_output=True,
        text=True,
        creationflags=flags,
        startupinfo=startup,
        check=False,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        if result.returncode == 0xC000001D:
            detail = (
                "Windows stopped the decoder with STATUS_ILLEGAL_INSTRUCTION "
                "(0xC000001D). The decoder may require a CPU instruction the "
                "computer does not support; install the baseline-compatible "
                "Windows patcher build."
            )
        raise AnnouncerBuildError(
            f"Decoder failed (exit {result.returncode}): {detail}"
        )


def build_announcer_pack(
    rom: Path,
    base_zip: Path,
    output: Path,
    *,
    decoder: Path | None = None,
    stadium2_rom: Path | None = None,
    progress: Progress | None = None,
) -> dict[str, object]:
    """Verify, extract, decode, and inject all Stadium announcer clips."""

    report = progress or (lambda _fraction, _message: None)
    rom = Path(rom)
    base_zip = Path(base_zip)
    output = Path(output)
    decoder = Path(decoder) if decoder else default_decoder()
    stadium2_rom = Path(stadium2_rom) if stadium2_rom else None
    if not rom.is_file():
        raise AnnouncerBuildError(f"Stadium ROM not found: {rom}")
    if not base_zip.is_file():
        raise AnnouncerBuildError(f"StadiumBattleFX pack not found: {base_zip}")
    if not decoder.is_file():
        raise AnnouncerBuildError(f"MORT decoder not found: {decoder}")
    if stadium2_rom and not stadium2_rom.is_file():
        raise AnnouncerBuildError(f"Stadium 2 ROM not found: {stadium2_rom}")

    report(0.01, "Verifying Pokemon Stadium ROM...")
    reader, rom_report = open_rom(rom)
    clips = inventory(reader)
    if len(clips) != CLIP_COUNT:
        raise AnnouncerBuildError(
            f"Expected {CLIP_COUNT} announcer clips, found {len(clips)}."
        )
    if {clip.sample_rate for clip in clips} != {16000}:
        raise AnnouncerBuildError("The ROM announcer bank has an unexpected sample rate.")

    with tempfile.TemporaryDirectory(prefix="stadium_announcer_") as temporary:
        work = Path(temporary)
        mort_dir = work / "mort"
        wav_dir = work / "wav"
        cache_dir = work / "cache"
        runtime = work / "runtime"
        mort_dir.mkdir()
        wav_dir.mkdir()

        with zipfile.ZipFile(base_zip) as archive:
            for item in archive.infolist():
                relative = Path(item.filename.replace("\\", "/"))
                if relative.is_absolute() or ".." in relative.parts:
                    raise AnnouncerBuildError(
                        f"Base mod ZIP contains an unsafe path: {item.filename}"
                    )
                if item.is_dir():
                    continue
                destination = runtime / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(archive.read(item.filename))
        cache_script = bundled_path("build_stadium_cache.lua")
        if not cache_script.is_file():
            raise AnnouncerBuildError("The bundled Stadium cache builder is missing.")
        (runtime / "tools").mkdir(parents=True, exist_ok=True)
        (runtime / "tools" / "build_stadium_cache.lua").write_bytes(
            cache_script.read_bytes()
        )

        report(0.04, "Extracting 823 compressed voice clips...")
        for clip in clips:
            mort = mort_dir / f"stadium_mort_{clip.index:03d}.mort"
            mort.write_bytes(reader.read(clip.offset, clip.length))
        report(0.10, "Converting announcer audio (0/823)...")

        # One bounded child process performs the full conversion. The inputs
        # and outputs are fixed temporary directories created above.
        _run_decoder_batch(decoder, mort_dir, wav_dir)
        report(0.45, "Converting announcer audio (823/823)...")

        cache_stages = [0]
        def cache_progress(message: str) -> None:
            cache_stages[0] += 1
            report(min(0.84, 0.46 + cache_stages[0] * 0.06), message)

        cache_result = build_stadium_cache(
            rom,
            cache_dir,
            stadium2_rom=stadium2_rom,
            mod_root=runtime,
            progress=cache_progress,
        )

        report(0.86, "Injecting voice files and caches into StadiumBattleFX pack...")

        def zip_progress(done: int, total: int) -> None:
            report(
                0.86 + 0.13 * done / total,
                f"Compressing personalized pack ({done}/823)...",
            )

        result = patch_zip(
            base_zip,
            wav_dir,
            output,
            cache_dir=cache_dir,
            require_complete=True,
            progress=zip_progress,
        )
    report(1.0, "Personalized StadiumBattleFX pack is ready.")
    result["rom_revision"] = rom_report["revision"]
    result.update(cache_result)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("base_zip", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--decoder", type=Path)
    parser.add_argument("--stadium2-rom", type=Path)
    args = parser.parse_args()
    try:
        result = build_announcer_pack(
            args.rom,
            args.base_zip,
            args.output,
            decoder=args.decoder,
            stadium2_rom=args.stadium2_rom,
            progress=lambda fraction, message: print(
                f"[{fraction * 100:6.2f}%] {message}", flush=True
            ),
        )
    except (OSError, StadiumRomError, VoicePackError, AnnouncerBuildError,
            StadiumCacheBuildError) as exc:
        parser.error(str(exc))
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
