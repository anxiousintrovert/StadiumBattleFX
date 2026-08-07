# Stadium Battle FX

Stadium Battle FX is an experimental Gen1Recomp graphics mod that recreates
Pokemon Stadium move effects from a Pokemon Stadium ROM supplied by the
player. No ROM or extracted Nintendo asset is included in the mod or this
repository.

Version 0.2.0 covers every move on the supplied Pokemon Yellow test party:

- Pikachu: Thunder Shock, Growl, Quick Attack, Thunder Wave
- Nidoran M: Leer, Tackle, Horn Attack, Double Kick
- Butterfree: Tackle, String Shot, Confusion
- Pidgey: Gust, Sand Attack, Quick Attack
- Magikarp: Splash
- Sandshrew: Scratch, Sand Attack

Thunder Shock retains the already tested Stadium texture and schedule. The
other effects are a first portable pass based on Stadium's traced primary and
impact dispatch. Scratch, Sand Attack, Thunder Wave, and the shared hit effects
use exact cached Stadium texture primitives. Wind, speed, string, psychic, and
screen effects are procedural interpretations and still need hardware visual
tuning. Growl and Splash have no standalone Stadium VFX stage; with Dramatic
Shapes showing a Stadium model, the mod leaves those as body animations.

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
for body-only Stadium presentations such as Growl and Splash. Stadium Battle FX
uses its exported runtime state read-only to determine whether a Stadium model
is showing and to let Dramatic Shapes finish its own first-run model extraction
screen first.

This mod never writes to the Dramatic Shapes mod directory or its
`dramatic_shape/stadium/` cache. Its only writes are to the private cache path
above.

## Installation and updates

Install the versioned `.modpkg` through Gen1Recomp's mod manager and enable
**Stadium Battle FX**. The mod declares `engine_internals` for its narrow
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
  --output dist\STADIUM_BATTLE_FX-0.2.0.modpkg
```

The allowlisted packer prevents ignored ROMs, saves, caches, captures, and
research-only tooling from entering a release.

## Research status

The move dispatch opcodes and resource bundles are traced from
pret/pokestadium. The current portable stage offsets, target anchors, scale,
tint, and particle motion remain provisional until they are compared against
native Stadium captures. See `docs/research.md` and
`docs/thunder-shock-trace.md` for the source trail.

Research references:

- Gen1Recomp — host engine and mod API
- DramaticShapeVoxelMod — read-only companion and extraction precedent
- pret/pokestadium — structural source for Stadium's battle effects
- PokemonStadiumRecomp — executable behavioral oracle
