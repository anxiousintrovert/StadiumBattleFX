# Stadium Attack Animations

> [!WARNING]
> ## THIS PROJECT IS ENTIRELY AI VIBE-CODED
>
> This mod and its supporting research code were created through AI-assisted
> vibe coding. It is an experimental prototype, not a professionally engineered
> or authoritative Pokemon Stadium implementation. Expect inaccuracies, rough
> approximations, bugs, and code that may need substantial replacement.
>
> **This project is temporary and will be deleted once these effects are
> properly implemented by a skilled developer.** Until then, please treat every
> release as public test software and report problems rather than relying on it
> as a finished or faithful recreation.

Stadium Attack Animations is an experimental Gen1Recomp graphics mod that recreates
Pokemon Stadium move effects from a Pokemon Stadium ROM supplied by the
player. No ROM or extracted Nintendo asset is included in the mod or this
repository.

Version 0.6.0 implements a presentation for all 165 Gen 1 moves. The complete
registry is generated from Gen1Recomp's canonical move data and augmented with
each move's decoded Pokemon Stadium primary, alternate, impact, and resource
dispatch metadata.

Current development builds also separate that roster into move-shaped visual
programs and attack-camera timelines. Slash, punch, kick, grapple, rush,
needle, wind, sound, stream, wave, beam, storm, orb, leaf, electric, psychic,
drain, ground, barrier, heal, transform, and explosion programs replace the
old type-only fallback. Reusable melee, combo, ranged, sustained, aerial,
field, status, self, and explosion shots focus the body windup, travel, and
defender impact as distinct stages during Dramaless Shape Stadium battles.

Thunder Shock retains its tested Stadium texture and schedule. Scratch, Sand
Attack, Thunder Wave, and the shared hit family also use exact cached Stadium
texture primitives. The remaining roster uses deterministic Stadium-style
rendering selected by type and behavior: contact, projectile, beam, multi-hit,
trapping, status, stat change, recovery, screen, charge, recoil, and explosion
presentations are all covered. These portable renderers are source-driven
interpretations and still need native Stadium capture calibration for exact
timing, scale, tint, and motion. Moves with no standalone Stadium VFX stage,
including Growl and Splash, retain their Dramaless Shape body animation when a
Stadium model is showing.

## Animation showcase

These GIFs are clean captures from the version 0.5.0 renderer. They show one
representative move for each of the 15 Gen 1 attack types; they are not native
Pokemon Stadium footage.

| Normal | Fighting | Flying |
|:---:|:---:|:---:|
| **Hyper Beam**<br>![Hyper Beam](promo/gifs/01_normal_hyper_beam.gif) | **Submission**<br>![Submission](promo/gifs/02_fighting_submission.gif) | **Wing Attack**<br>![Wing Attack](promo/gifs/03_flying_wing_attack.gif) |
| Poison | Ground | Rock |
| **Acid**<br>![Acid](promo/gifs/04_poison_acid.gif) | **Bone Club**<br>![Bone Club](promo/gifs/05_ground_bone_club.gif) | **Rock Slide**<br>![Rock Slide](promo/gifs/06_rock_rock_slide.gif) |
| Bug | Ghost | Fire |
| **Pin Missile**<br>![Pin Missile](promo/gifs/07_bug_pin_missile.gif) | **Night Shade**<br>![Night Shade](promo/gifs/08_ghost_night_shade.gif) | **Fire Blast**<br>![Fire Blast](promo/gifs/09_fire_fire_blast.gif) |
| Water | Grass | Electric |
| **Hydro Pump**<br>![Hydro Pump](promo/gifs/10_water_hydro_pump.gif) | **Razor Leaf**<br>![Razor Leaf](promo/gifs/11_grass_razor_leaf.gif) | **Thunderbolt**<br>![Thunderbolt](promo/gifs/12_electric_thunderbolt.gif) |
| Psychic | Ice | Dragon |
| **Psybeam**<br>![Psybeam](promo/gifs/13_psychic_psybeam.gif) | **Ice Beam**<br>![Ice Beam](promo/gifs/14_ice_ice_beam.gif) | **Dragon Rage**<br>![Dragon Rage](promo/gifs/15_dragon_dragon_rage.gif) |

## ROM and cache

The supported cartridge is Pokemon Stadium (USA) v1.0, exactly 32 MiB. Put any
`.z64`, `.n64`, or `.v64` dump directly in the same flat `baseroms/` folder
Dramaless Shape uses. The filename is not important:

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

## Dramaless Shape compatibility

**Dramaless Shape is optional but strongly recommended.** It supplies the live
Stadium Pokemon models, their skeletal animations, and staged battle projection. Stadium
Attack Animations reads its exported runtime state to determine whether a
Stadium model is showing and to let Dramaless Shape finish its own first-run
model extraction screen first. It also reads the live voxel level,
staged-battle mode, projected shot scale, and model footprints. When the attack
camera is enabled, it composes a temporary move shot through Dramaless Shape's
runtime camera function. When Dramaless Shape owns the transformed animation
layer, this mod retains classic Gen1 effect anchors and lets Dramaless Shape
apply the resulting camera transform exactly once.

Install the `DRAMALESS_SHAPE` mod from
[artyrambles/DRAMALESS_SHAPE](https://github.com/artyrambles/DRAMALESS_SHAPE).
The fork currently uses the non-SemVer version `1.6.2.ST`, so the manifest
cannot safely express a numeric version range; 0.6.0 therefore declares only
the mod ID as an optional dependency. Without Dramaless Shape, portable attack
effects still run, but Stadium Pokemon body animations, model-aware scaling,
and the staged attack camera are unavailable. Body-only moves fall back to the
ordinary Gen 1 presentation.

The source tree contains capability-checked adapters for proposed
`Stadium.hit(side, effectiveness)` and `Stadium.faint(side, disposition)` APIs.
Version 0.6.0 deliberately does not register damage or faint event listeners
and never calls those adapters. Hit and faint reactions will remain disabled
until Dramaless Shape publishes the required public API.

This mod's only writes are to its private cache path above; it never writes to
the Dramaless Shape mod directory or its `dramatic_shape/stadium/` cache.

Dynamic Battle Cinematics is an optional companion. Its current v0.7.1 release
still hard-depends on the defunct
`DRAMATIC_SHAPE` mod ID and therefore cannot currently load in a
DRAMALESS_SHAPE installation. Stadium Attack Animations retains its composed
camera adapter for a future compatible release, but does not patch or modify
Battle Cinematics. Once that project accepts the new companion ID, the optional
**BC ZOOM OUT** setting will continue to widen only its optical field of view.

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
  --output dist\STADIUM_BATTLE_FX-0.6.0.modpkg
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
`docs/attack-cinematics.md` records the newly traced presentation layers,
camera source trail, shared-program model, and remaining calibration work.

Research references:

- Gen1Recomp — host engine and mod API
- Dramaless Shape — optional, strongly recommended live Stadium model and camera companion
- DramaticShapeVoxelMod — original model-extraction research and architectural precedent
- pret/pokestadium — structural source for Stadium's battle effects
- PokemonStadiumRecomp — executable behavioral oracle
