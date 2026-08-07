# Stadium Attack Animations

Stadium Attack Animations is an experimental Gen1Recomp graphics mod that recreates
Pokemon Stadium move effects from a Pokemon Stadium ROM supplied by the
player. No ROM or extracted Nintendo asset is included in the mod or this
repository.

Version 0.4.0 implements a presentation for all 165 Gen 1 moves. The complete
registry is generated from Gen1Recomp's canonical move data and augmented with
each move's decoded Pokemon Stadium primary, alternate, impact, and resource
dispatch metadata.

Thunder Shock retains its tested Stadium texture and schedule. Scratch, Sand
Attack, Thunder Wave, and the shared hit family also use exact cached Stadium
texture primitives. The remaining roster uses deterministic Stadium-style
rendering selected by type and behavior: contact, projectile, beam, multi-hit,
trapping, status, stat change, recovery, screen, charge, recoil, and explosion
presentations are all covered. These portable renderers are source-driven
interpretations and still need native Stadium capture calibration for exact
timing, scale, tint, and motion. Moves with no standalone Stadium VFX stage,
including Growl and Splash, retain their Dramatic Shapes body animation when a
Stadium model is showing.

## ROM and cache

The supported cartridge is Pokemon Stadium (USA) v1.0, exactly 32 MiB. Put any
`.z64`, `.n64`, or `.v64` dump directly in the same flat `baseroms/` folder
Dramatic Shapes uses. The filename is not important:

```text
baseroms/baserom.z64
baseroms/my-stadium-cartridge.n64
baseroms/anything.v64
```

On the first overworld load, a dedicated **STADIUM ATTACK FX** screen extracts
and caches the small shared effect set. It advances one archive, cache, or GPU
upload operation per tick and closes automatically. Later boots load the cache
without showing the screen or rereading the ROM.

The private cache is stored under:

```text
stadium_battle_fx/effects/v2/
```

Its versioned marker is written last and records the size and checksum of each
primitive. Interrupted, incomplete, or stale caches are rejected and rebuilt.
The cache contains only eight small texture ranges, never the ROM, a complete
archive member, or a decompressed Stadium fragment.

## Dramatic Shapes compatibility

Dramatic Shapes is optional for textured attack effects and is required only
for body-only Stadium presentations such as Growl and Splash. Stadium Attack Animations
uses its exported runtime state read-only to determine whether a Stadium model
is showing and to let Dramatic Shapes finish its own first-run model extraction
screen first. It also reads the live voxel level, staged-battle mode, projected
shot scale, and model footprints. When Dramatic Shapes owns the transformed
animation layer, this mod retains classic Gen1 effect anchors and lets Dramatic
Shapes apply the configured camera transform exactly once.

This mod never writes to the Dramatic Shapes mod directory or its
`dramatic_shape/stadium/` cache. Its only writes are to the private cache path
above.

Dynamic Battle Cinematics v0.7.1 is supported as an optional read-only camera
companion. It replaces Dramatic Shapes' camera rig but does not replace the
animation player or animation layer. Dramatic Shapes projects that moving
camera into its live shot and transforms Stadium Attack Animations with the rest of
the animation layer. Stadium Attack Animations detects the companion version but does
not call its controls or modify any of its files.

## Installation and updates

Install the versioned `.modpkg` through Gen1Recomp's mod manager and enable
**Stadium Attack Animations**. The mod declares `engine_internals` for its narrow
AnimPlayer adapter and `filesystem` for ROM reads and its private cache.

The manifest points to `anxiousintrovert/StadiumBattleFX`. Tagged GitHub
releases publish a correctly named `.zip` asset, allowing Gen1Recomp's mod
manager to discover and install newer versions over the internet.

## Development

Run the Python research tests with a local cartridge:

```powershell
$env:STADIUM_ROM = "C:\path\to\Pokemon Stadium (USA).z64"
python -m unittest discover -s tests -p "test_*.py" -v
```

Build a runtime-only package with Gen1Recomp's ModKit:

```powershell
python tools/package_runtime.py `
  --modkit ..\Gen1Recomp\tools\modkit.py `
  --output dist\STADIUM_BATTLE_FX-0.4.0.modpkg
```

The allowlisted packer prevents ignored ROMs, saves, caches, captures, and
research-only tooling from entering a release.

## Research status

The move dispatch opcodes and resource bundles for all 165 moves are traced
from pret/pokestadium. Exact cached textures currently cover the established
traced subset; the rest use type/behavior-aware procedural presentations. The
current portable stage offsets, target anchors, scale, tint, and particle
motion remain provisional until they are compared against native Stadium
captures. See `docs/research.md` and
`docs/thunder-shock-trace.md` for the source trail. The generated
`docs/move-roster.md` covers all 165 Gen 1 moves, and `docs/effect-scale.md`
records the native scale and projection model used for roster expansion.

Research references:

- Gen1Recomp — host engine and mod API
- DramaticShapeVoxelMod — read-only companion and extraction precedent
- pret/pokestadium — structural source for Stadium's battle effects
- PokemonStadiumRecomp — executable behavioral oracle
