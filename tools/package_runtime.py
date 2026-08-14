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
    "LICENSE",
    "THIRD_PARTY_NOTICES.md",
    "manifest.json",
    "mod.card",
    "main.lua",
    "docs/BATTLE_PRESENTATION_API.md",
    "docs/STADIUM_MODEL_API.md",
    "lib/BattleProviders.lua",
    "lib/BattleHost.lua",
    "lib/BattleCinematicsCompat.lua",
    "lib/BattleArtCompat.lua",
    "lib/BuiltinProviders.lua",
    "lib/Mat4.lua",
    "lib/ModStorage.lua",
    "lib/StadiumRender.lua",
    "lib/StadiumModelProvider.lua",
    "lib/StadiumModelApi.lua",
    "lib/StadiumModelSources.lua",
    "lib/StadiumModels.lua",
    "lib/StadiumMon.lua",
    "lib/StadiumRig.lua",
    "lib/StadiumPack.lua",
    "lib/StadiumModelRom.lua",
    "lib/StadiumBuild.lua",
    "lib/StadiumFragment.lua",
    "lib/StadiumFx.lua",
    "lib/StadiumInstall.lua",
    "lib/StadiumRom.lua",
    "lib/StadiumTexture.lua",
    "lib/stadium2/animation_routing.lua",
    "lib/stadium2/build.lua",
    "lib/stadium2/cache.lua",
    "lib/stadium2/effect_renderer.lua",
    "lib/stadium2/extract.lua",
    "lib/stadium2/fragment.lua",
    "lib/stadium2/fx.lua",
    "lib/stadium2/handler_registry.lua",
    "lib/stadium2/importer.lua",
    "lib/stadium2/layout.lua",
    "lib/stadium2/materials.lua",
    "lib/stadium2/model_handlers.lua",
    "lib/stadium2/model_pack_api.lua",
    "lib/stadium2/pack.lua",
    "lib/stadium2/palette.lua",
    "lib/stadium2/render_contract.lua",
    "lib/stadium2/renderer.lua",
    "lib/stadium2/rom.lua",
    "lib/stadium2/sampler.lua",
    "lib/stadium2/texture_parity.lua",
    "lib/stadium2/vertex_semantics.lua",
    "lib/stadium2/effects/dynamic_object.lua",
    "lib/stadium2/effects/dynamic_object_manifest.lua",
    "lib/stadium2/render_callbacks/dual_texture_material.lua",
    "lib/stadium2/render_callbacks/flame.lua",
    "lib/stadium2/render_callbacks/phase5_geometry.lua",
    "lib/StadiumAssets.lua",
    "lib/StadiumLog.lua",
    "lib/StadiumLogExport.lua",
    "lib/StadiumArena.lua",
    "lib/StadiumArenaThemes.lua",
    "lib/StadiumArenaAssets.lua",
    "lib/StadiumTrainerPortraits.lua",
    "lib/DramaticShapeState.lua",
    "lib/DramaticShapeAttachment.lua",
    "lib/DramaticShapeHit.lua",
    "lib/DramaticShapeFaint.lua",
    "lib/AttackCinematics.lua",
    "lib/Announcer.lua",
    "lib/FailureNotice.lua",
    "lib/effects/MoveSpecs.lua",
    "lib/effects/StadiumFidelityProfiles.lua",
    "lib/effects/StadiumTimingProfiles.lua",
    "lib/effects/StadiumRosterCalibration.lua",
    "lib/effects/AllMoveSpecs.lua",
    "lib/effects/StadiumMoveRoster.lua",
    "lib/effects/StadiumNativePrograms.lua",
    "lib/effects/StadiumNativeInterpreter.lua",
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
