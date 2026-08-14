#!/usr/bin/env python3
"""Build read-only StadiumBattleFX runtime caches from locally owned ROMs."""

from __future__ import annotations

import hashlib
import shutil
from pathlib import Path
from typing import Callable


Progress = Callable[[str], None]
STADIUM2_SIZE = 64 * 1024 * 1024
STADIUM2_TITLE = "POKEMON STADIUM 2"
STADIUM2_MD5 = "1561c75d11cedf356a8ddb1a4a5f9d5d"


class StadiumCacheBuildError(RuntimeError):
    pass


def _normalise_n64(data: bytes) -> bytes:
    if data[:4] == b"\x80\x37\x12\x40":
        return data
    if data[:4] == b"\x37\x80\x40\x12":
        out = bytearray(data)
        out[0::2], out[1::2] = data[1::2], data[0::2]
        return bytes(out)
    if data[:4] == b"\x40\x12\x37\x80":
        out = bytearray(data)
        out[0::4], out[1::4], out[2::4], out[3::4] = (
            data[3::4], data[2::4], data[1::4], data[0::4]
        )
        return bytes(out)
    raise StadiumCacheBuildError("unrecognized Nintendo 64 ROM byte order")


def validate_stadium2_rom(path: Path) -> None:
    data = _normalise_n64(path.read_bytes())
    title = data[0x20:0x34].rstrip(b"\0 ").decode("ascii", errors="replace")
    if len(data) != STADIUM2_SIZE or title.upper() != STADIUM2_TITLE:
        raise StadiumCacheBuildError("needs Pokemon Stadium 2 (USA)")
    digest = hashlib.md5(data).hexdigest()
    if digest != STADIUM2_MD5:
        raise StadiumCacheBuildError(
            f"unsupported Pokemon Stadium 2 revision: MD5 {digest}"
        )


def build_stadium_cache(
    stadium1_rom: Path,
    output: Path,
    *,
    stadium2_rom: Path | None = None,
    mod_root: Path | None = None,
    progress: Progress | None = None,
) -> dict[str, object]:
    """Run the shipped Lua extractors and produce a cache/ directory."""

    try:
        from lupa.luajit21 import LuaRuntime
    except ImportError as exc:
        raise StadiumCacheBuildError(
            "The cache builder needs the bundled lupa LuaJIT runtime."
        ) from exc

    stadium1_rom = Path(stadium1_rom).resolve()
    output = Path(output).resolve()
    root = Path(mod_root or Path(__file__).resolve().parent.parent).resolve()
    stadium2 = Path(stadium2_rom).resolve() if stadium2_rom else None
    if not stadium1_rom.is_file():
        raise StadiumCacheBuildError(f"Pokemon Stadium ROM not found: {stadium1_rom}")
    if stadium2 and not stadium2.is_file():
        raise StadiumCacheBuildError(f"Pokemon Stadium 2 ROM not found: {stadium2}")
    if stadium2:
        validate_stadium2_rom(stadium2)

    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    report = progress or (lambda _message: None)

    lua = LuaRuntime(unpack_returned_tuples=True)
    globals_ = lua.globals()
    globals_.MOD_ROOT = root.as_posix()
    globals_.CACHE_ROOT = output.as_posix()
    globals_.STADIUM1_ROM = stadium1_rom.as_posix()
    globals_.STADIUM2_ROM = stadium2.as_posix() if stadium2 else ""
    globals_.PY_MKDIR = lambda path: Path(path).mkdir(parents=True, exist_ok=True)
    globals_.PY_REMOVE = lambda path: Path(path).unlink(missing_ok=True)
    globals_.PY_CLEAR = lambda path: shutil.rmtree(Path(path), ignore_errors=True)
    globals_.PY_PROGRESS = report

    script = (root / "tools" / "build_stadium_cache.lua").read_text(encoding="utf-8")
    try:
        lua.execute(script)
    except Exception as exc:
        shutil.rmtree(output, ignore_errors=True)
        raise StadiumCacheBuildError(str(exc)) from exc

    files = [path for path in output.rglob("*") if path.is_file()]
    return {
        "cache_files": len(files),
        "cache_bytes": sum(path.stat().st_size for path in files),
        "stadium2_cached": stadium2 is not None,
    }
