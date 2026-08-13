#!/usr/bin/env python3
"""Inject locally decoded Stadium announcer WAVs into a release mod ZIP.

This is the packaging half of the planned Windows voice-pack builder. It never
modifies the downloaded ZIP in place and never uploads ROM-derived output.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Callable


MOD_ID = "STADIUM_BATTLE_FX"
CLIP_COUNT = 823
VOICE_ROOT = "assets/announcer"
MARKER = f"{VOICE_ROOT}/voicepack.json"
BATCH_NAME = re.compile(
    r"^BANK_([0-9A-F]+)_INSTR_[0-9A-F]+_SND_[0-9A-F]+\.wav$", re.IGNORECASE
)
INDEX_NAME = re.compile(r"^stadium_mort_(\d{3})\.wav$", re.IGNORECASE)


class VoicePackError(ValueError):
    pass


@dataclass(frozen=True)
class WavInfo:
    channels: int
    sample_rate: int
    bits: int
    data_bytes: int


def wav_index(path: Path) -> int | None:
    match = INDEX_NAME.match(path.name)
    if match:
        return int(match.group(1), 10)
    match = BATCH_NAME.match(path.name)
    if match:
        return int(match.group(1), 16)
    return None


def inspect_wav(data: bytes, name: str) -> WavInfo:
    if len(data) < 44 or data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise VoicePackError(f"{name}: not a RIFF/WAVE file")
    offset = 12
    fmt: tuple[int, int, int] | None = None
    data_bytes: int | None = None
    while offset + 8 <= len(data):
        chunk = data[offset : offset + 4]
        size = struct.unpack_from("<I", data, offset + 4)[0]
        payload = offset + 8
        if payload + size > len(data):
            raise VoicePackError(f"{name}: truncated {chunk!r} chunk")
        if chunk == b"fmt " and size >= 16:
            encoding, channels, rate, _, _, bits = struct.unpack_from(
                "<HHIIHH", data, payload
            )
            if encoding != 1:
                raise VoicePackError(f"{name}: expected PCM encoding")
            fmt = channels, rate, bits
        elif chunk == b"data":
            data_bytes = size
        offset = payload + size + (size & 1)
    if fmt is None or data_bytes is None:
        raise VoicePackError(f"{name}: missing fmt or data chunk")
    info = WavInfo(*fmt, data_bytes)
    if (info.channels, info.sample_rate, info.bits) != (1, 16000, 16):
        raise VoicePackError(
            f"{name}: expected mono 16-bit 16000 Hz PCM, got "
            f"{info.channels}ch {info.bits}-bit {info.sample_rate} Hz"
        )
    return info


def collect_wavs(folder: Path) -> dict[int, Path]:
    result: dict[int, Path] = {}
    for path in folder.glob("*.wav"):
        index = wav_index(path)
        if index is None:
            continue
        if not 0 <= index < CLIP_COUNT:
            raise VoicePackError(f"{path.name}: clip index {index} is outside 0..822")
        if index in result:
            raise VoicePackError(
                f"duplicate clip {index}: {result[index].name} and {path.name}"
            )
        result[index] = path
    return result


def read_base_manifest(archive: zipfile.ZipFile) -> dict[str, object]:
    try:
        manifest = json.loads(archive.read("manifest.json"))
    except KeyError as exc:
        raise VoicePackError("base ZIP has no root manifest.json") from exc
    except json.JSONDecodeError as exc:
        raise VoicePackError("base ZIP manifest.json is invalid") from exc
    if manifest.get("id") != MOD_ID:
        raise VoicePackError(
            f"base ZIP is {manifest.get('id')!r}; expected {MOD_ID!r}"
        )
    return manifest


def patch_zip(
    base_zip: Path,
    wav_dir: Path,
    output: Path,
    *,
    rom: Path | None = None,
    require_complete: bool = True,
    progress: Callable[[int, int], None] | None = None,
) -> dict[str, object]:
    if base_zip.resolve() == output.resolve():
        raise VoicePackError("output must not overwrite the official base ZIP")
    wavs = collect_wavs(wav_dir)
    if require_complete and set(wavs) != set(range(CLIP_COUNT)):
        missing = sorted(set(range(CLIP_COUNT)) - set(wavs))
        preview = ", ".join(str(index) for index in missing[:12])
        raise VoicePackError(
            f"decoded bank is incomplete: {len(wavs)}/823 clips; missing {preview}"
        )
    if not wavs:
        raise VoicePackError("no recognized announcer WAVs found")

    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".tmp")
    if temporary.exists():
        temporary.unlink()
    total_pcm = 0
    digest = hashlib.sha256()
    try:
        with zipfile.ZipFile(base_zip, "r") as source:
            manifest = read_base_manifest(source)
            with zipfile.ZipFile(
                temporary, "w", zipfile.ZIP_DEFLATED, compresslevel=9
            ) as target:
                for item in source.infolist():
                    normalized = item.filename.replace("\\", "/")
                    if normalized == MARKER or normalized.startswith(VOICE_ROOT + "/"):
                        continue
                    if rom is not None and normalized.startswith("baseroms/baserom."):
                        continue
                    target.writestr(item, source.read(item.filename))
                clip_rows = []
                for index in sorted(wavs):
                    data = wavs[index].read_bytes()
                    info = inspect_wav(data, wavs[index].name)
                    total_pcm += info.data_bytes
                    digest.update(index.to_bytes(2, "big"))
                    digest.update(data)
                    relative = f"{VOICE_ROOT}/{index:03d}.wav"
                    entry = zipfile.ZipInfo(relative, (1980, 1, 1, 0, 0, 0))
                    entry.compress_type = zipfile.ZIP_DEFLATED
                    entry.external_attr = 0o100644 << 16
                    target.writestr(entry, data, compresslevel=9)
                    clip_rows.append(index)
                    if progress is not None:
                        progress(len(clip_rows), len(wavs))
                voicepack = {
                    "format": "StadiumBattleFX local announcer voice pack v1",
                    "local_only": True,
                    "redistribution": "Do not redistribute this ROM-derived ZIP.",
                    "base_mod_id": MOD_ID,
                    "base_mod_version": manifest.get("version"),
                    "clip_count": len(clip_rows),
                    "indices": clip_rows,
                    "audio": { "codec": "PCM", "channels": 1,
                               "sample_rate": 16000, "bits": 16 },
                    "content_sha256": digest.hexdigest(),
                }
                marker = json.dumps(voicepack, indent=2).encode() + b"\n"
                entry = zipfile.ZipInfo(MARKER, (1980, 1, 1, 0, 0, 0))
                entry.compress_type = zipfile.ZIP_DEFLATED
                entry.external_attr = 0o100644 << 16
                target.writestr(entry, marker, compresslevel=9)
                if rom is not None:
                    rom_data = Path(rom).read_bytes()
                    entry = zipfile.ZipInfo(
                        "baseroms/baserom.z64", (1980, 1, 1, 0, 0, 0)
                    )
                    entry.compress_type = zipfile.ZIP_DEFLATED
                    entry.external_attr = 0o100644 << 16
                    target.writestr(entry, rom_data, compresslevel=9)
        temporary.replace(output)
    except Exception:
        if temporary.exists():
            temporary.unlink()
        raise
    return {
        "output": str(output.resolve()),
        "clips": len(wavs),
        "pcm_bytes": total_pcm,
        "zip_bytes": output.stat().st_size,
        "rom_bundled": rom is not None,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base_zip", type=Path)
    parser.add_argument("wav_dir", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--allow-partial", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--rom", type=Path,
                        help="locally bundle the owned Stadium ROM for sandboxed runtime reads")
    args = parser.parse_args()
    try:
        result = patch_zip(
            args.base_zip,
            args.wav_dir,
            args.output,
            rom=args.rom,
            require_complete=not args.allow_partial,
        )
    except (OSError, VoicePackError, zipfile.BadZipFile) as exc:
        parser.error(str(exc))
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
