#!/usr/bin/env python3
"""Build an allowlisted runtime-only source tree for ModKit packaging.

The upstream packer intentionally ignores hidden/VCS directories but does not
interpret .gitignore globs. An allowlist makes it impossible for a developer's
local baseroms/ or cache/ contents to enter a release archive.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


FILES = (
    "README.md",
    "manifest.json",
    "mod.card",
    "main.lua",
    "lib/StadiumRom.lua",
    "lib/StadiumTexture.lua",
    "lib/StadiumAssets.lua",
    "lib/DramaticShapeState.lua",
    "lib/AttackCinematics.lua",
    "lib/EffectCacheScreen.lua",
    "lib/effects/MoveSpecs.lua",
    "lib/effects/AllMoveSpecs.lua",
    "lib/effects/StadiumMoveRoster.lua",
    "lib/effects/StadiumFxPlayer.lua",
    "lib/effects/GenericMoveRenderer.lua",
    "lib/effects/ThunderShockSpec.lua",
    "lib/effects/ThunderShockPlayer.lua",
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--modkit", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="stadium-battle-fx-") as tmp:
        stage = Path(tmp) / "StadiumBattleFX"
        for relative in FILES:
            source = root / relative
            if not source.is_file():
                raise SystemExit(f"missing runtime file: {relative}")
            destination = stage / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
        command = [sys.executable, str(args.modkit.resolve()), "pack",
                   str(stage), "--base", "fixture", "-o", str(output)]
        return subprocess.call(command, cwd=root)


if __name__ == "__main__":
    raise SystemExit(main())
