#!/usr/bin/env python3
"""Build the allowlisted runtime-only release ZIP.

The archive is deliberately flat at its root (manifest.json is not wrapped in
an extra directory) so it can be installed directly by Gen1Recomp's mod
manager. An allowlist makes it impossible for local ROMs, caches, captures, or
research tooling to enter a release.
"""

from __future__ import annotations

import argparse
import zipfile
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
    "lib/DramaticShapeAttachment.lua",
    "lib/DramaticShapeHit.lua",
    "lib/DramaticShapeFaint.lua",
    "lib/AttackCinematics.lua",
    "lib/Announcer.lua",
    "lib/FailureNotice.lua",
    "lib/EffectCacheScreen.lua",
    "lib/effects/MoveSpecs.lua",
    "lib/effects/StadiumFidelityProfiles.lua",
    "lib/effects/StadiumTimingProfiles.lua",
    "lib/effects/StadiumRosterCalibration.lua",
    "lib/effects/AllMoveSpecs.lua",
    "lib/effects/StadiumMoveRoster.lua",
    "lib/effects/StadiumFxPlayer.lua",
    "lib/effects/StadiumAuthenticRenderer.lua",
    "lib/effects/GenericMoveRenderer.lua",
    "lib/effects/StadiumScreenFx.lua",
    "lib/effects/ThunderShockSpec.lua",
    "lib/effects/ThunderShockPlayer.lua",
)


def build_zip(root: Path, output: Path) -> None:
    if output.suffix.lower() != ".zip":
        raise ValueError("release output must use the .zip extension")
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for relative in FILES:
            source = root / relative
            if not source.is_file():
                raise FileNotFoundError(f"missing runtime file: {relative}")
            info = zipfile.ZipInfo(relative, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, source.read_bytes())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    output = args.output.resolve()
    try:
        build_zip(root, output)
    except (ValueError, FileNotFoundError) as exc:
        parser.error(str(exc))
    print(f"built {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
