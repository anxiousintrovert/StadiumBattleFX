#!/usr/bin/env python3
"""Build a local StadiumBattleFX announcer pack directly from a Stadium ROM."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Callable

from extract_stadium_announcer import StadiumRomError, inventory, open_rom
from patch_announcer_zip import CLIP_COUNT, VoicePackError, inspect_wav, patch_zip


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


def _run_decoder(decoder: Path, mort: Path, wav: Path) -> None:
    startup = None
    flags = 0
    if os.name == "nt":
        flags = subprocess.CREATE_NO_WINDOW
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    result = subprocess.run(
        [str(decoder), str(mort), str(wav)],
        capture_output=True,
        text=True,
        creationflags=flags,
        startupinfo=startup,
        check=False,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise AnnouncerBuildError(
            f"Decoder failed for {mort.name} (exit {result.returncode}): {detail}"
        )
    inspect_wav(wav.read_bytes(), wav.name)


def build_announcer_pack(
    rom: Path,
    base_zip: Path,
    output: Path,
    *,
    decoder: Path | None = None,
    progress: Progress | None = None,
    workers: int | None = None,
) -> dict[str, object]:
    """Verify, extract, decode, and inject all Stadium announcer clips."""

    report = progress or (lambda _fraction, _message: None)
    rom = Path(rom)
    base_zip = Path(base_zip)
    output = Path(output)
    decoder = Path(decoder) if decoder else default_decoder()
    if not rom.is_file():
        raise AnnouncerBuildError(f"Stadium ROM not found: {rom}")
    if not base_zip.is_file():
        raise AnnouncerBuildError(f"StadiumBattleFX pack not found: {base_zip}")
    if not decoder.is_file():
        raise AnnouncerBuildError(f"MORT decoder not found: {decoder}")

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
        mort_dir.mkdir()
        wav_dir.mkdir()

        report(0.04, "Extracting 823 compressed voice clips...")
        jobs: list[tuple[int, Path, Path]] = []
        for clip in clips:
            mort = mort_dir / f"stadium_mort_{clip.index:03d}.mort"
            wav = wav_dir / f"stadium_mort_{clip.index:03d}.wav"
            mort.write_bytes(reader.read(clip.offset, clip.length))
            jobs.append((clip.index, mort, wav))
        report(0.10, "Converting announcer audio (0/823)...")

        worker_count = workers or min(8, max(2, os.cpu_count() or 2))
        completed = 0
        with ThreadPoolExecutor(max_workers=worker_count) as pool:
            futures = {
                pool.submit(_run_decoder, decoder, mort, wav): index
                for index, mort, wav in jobs
            }
            try:
                for future in as_completed(futures):
                    future.result()
                    completed += 1
                    report(
                        0.10 + 0.67 * completed / CLIP_COUNT,
                        f"Converting announcer audio ({completed}/823)...",
                    )
            except Exception:
                for future in futures:
                    future.cancel()
                raise

        report(0.78, "Injecting voice files into StadiumBattleFX pack...")

        def zip_progress(done: int, total: int) -> None:
            report(
                0.78 + 0.21 * done / total,
                f"Compressing personalized pack ({done}/823)...",
            )

        result = patch_zip(
            base_zip,
            wav_dir,
            output,
            require_complete=True,
            progress=zip_progress,
        )
    report(1.0, "Personalized StadiumBattleFX pack is ready.")
    result["rom_revision"] = rom_report["revision"]
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("base_zip", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--decoder", type=Path)
    parser.add_argument("--workers", type=int)
    args = parser.parse_args()
    try:
        result = build_announcer_pack(
            args.rom,
            args.base_zip,
            args.output,
            decoder=args.decoder,
            workers=args.workers,
            progress=lambda fraction, message: print(
                f"[{fraction * 100:6.2f}%] {message}", flush=True
            ),
        )
    except (OSError, StadiumRomError, VoicePackError, AnnouncerBuildError) as exc:
        parser.error(str(exc))
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
