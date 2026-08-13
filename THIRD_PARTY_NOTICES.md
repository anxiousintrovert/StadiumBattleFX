# Third-party notices and code provenance

StadiumBattleFX 2.0 includes adapted Stadium battle-model extraction and
runtime code originating in Dramaless Shape 1.6.4, itself a VoxelMod fork for
Gen1Recomp containing fixes and additions by Stahltier (aka artyrambles) based
on DramaticShapeVoxelMod 1.6.2. Those contributions are included under the MIT
License on the maintainer's authorization for the 2.0 ownership split.

- Dramaless Shape: <https://github.com/artyrambles/DRAMALESS_SHAPE>
- DramaticShapeVoxelMod / Battle Art releases:
  <https://github.com/absol89/DramaticShapeVoxelMod/releases>

Transferred code was taken from the known-good Stadium stack based on 1.6.4,
then adapted to StadiumBattleFX-owned rendering, cache paths, logging, provider
dispatch, and lifecycle. No OXR/VR code is included. OXR's Apache-2.0 material
therefore is not part of this distribution.

Battle Art's post-1.6.4 changes are not used as the extraction base. Its license
must be independently confirmed before any BattleArt-authored implementation is
copied into this project.

