# StadiumBattleFX

**Pokemon Stadium animations, voices, and battle presentation for Gen1Recomp.**

**[Download the latest release](https://github.com/anxiousintrovert/StadiumBattleFX/releases/latest)**

> [!WARNING]
> This project is an experimental, AI-assisted prototype. It is not an
> authoritative or frame-perfect reimplementation of Pokemon Stadium. Expect
> inaccuracies, rough edges, and code that may eventually be replaced by a
> native implementation from an experienced developer.

StadiumBattleFX brings Pokemon Stadium-inspired battles to Gen1Recomp. It gives
all 165 Gen 1 moves a Stadium-style presentation, can follow the live animated
models supplied by Dramaless Shape, and can add the original Stadium announcer
to major trainer battles through an optional voice pack built locally from
your own cartridge image.

No ROM, voice recording, or extracted Nintendo asset is included in this
repository or in the public release.

## What it includes

| Component | What it does |
| --- | --- |
| **Stadium animations** | Gives all 165 Gen 1 moves a move-specific visual program instead of a type-only fallback. |
| **Stadium voices** | Optionally adds locally extracted announcer introductions, Pokemon names, move names, battle reactions, and victory calls. |
| **Cartridge-backed effects** | Reads a small set of effect textures from a player-supplied Pokemon Stadium ROM and stores them in a private cache. |
| **Animated model attachments** | With Dramaless Shape, effects follow the attacker's live origin point and the defender's impact point throughout the pose. |
| **Hit reactions** | Damaging moves can trigger Dramaless Shape's skeletal reaction at the authored impact frame. |
| **Attack cameras** | Stages windup, travel, impact, and recovery shots during Stadium-model battles. |
| **Full-screen effects** | Supports washes, flashes, scrolling fields, and borderless presentation for moves such as Surf, Blizzard, Psychic, and Explosion. |
| **Safe fallbacks** | Missing optional companions, voices, individual clips, or advanced attachment APIs do not stop ordinary battles. |

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

## Requirements

- Gen1Recomp `>=0.1.37 <2.0.0`
- Mod API 2
- Pokemon Stadium (USA) v1.0, exactly 32 MiB, supplied by the player
- Dramaless Shape is optional but strongly recommended for Stadium Pokemon
  models, skeletal animations, attachment points, hit reactions, and attack
  cameras

## Installation

1. Install the versioned `STADIUM_BATTLE_FX-<version>.zip` through
   Gen1Recomp's mod manager.
2. Enable **StadiumBattleFX**.
3. Create the shared `baseroms` folder if it does not already exist.
4. Place your Pokemon Stadium ROM directly inside that folder. The filename
   does not matter, and `.z64`, `.n64`, and `.v64` byte orders are supported.
5. Restart Gen1Recomp. On the first overworld load, the **STADIUM ATTACK FX**
   screen builds the private effect cache and closes automatically.

Example ROM layout:

```text
baseroms/baserom.z64
```

Do not put the ROM in a regional subfolder such as `baseroms/us/`.

### ROM folder locations

| Platform | Stadium ROM folder |
| --- | --- |
| Windows | `%APPDATA%\pokemon-love2d\baseroms\` |
| macOS | `~/Library/Application Support/pokemon-love2d/baseroms/` |
| Linux / Steam Deck | `${XDG_DATA_HOME:-$HOME/.local/share}/pokemon-love2d/baseroms/` |
| Android | `/storage/emulated/0/Android/data/com.theboisclub.pokemonred/files/save/pokemon-love2d/baseroms/` |
| iOS | `<Gen1Recomp app container>/Library/Application Support/pokemon-love2d/baseroms/` |
| Nintendo Switch | `sdmc:/switch/gen1recomp/pokemon-love2d/baseroms/` |
| Xbox UWP | `Gen1Recomp/LocalState/pokemon-love2d/baseroms/` in Xbox Device Portal |
| Anbernic RG34XXSP | `/mnt/mmc/Roms/PORTS/gen1recomp/lovegame/baseroms/` |

Android may use a different external-storage root when adopted storage is in
use. The iOS directory is inside the app sandbox and is not directly exposed
in Files. If Gen1Recomp reports a different save directory, use the path it
reports.

A source checkout or another unfused install can put `baseroms/` beside
`main.lua`. An unfused `love .` run can also use the normal LOVE identity
folder:

```text
Windows: %APPDATA%\LOVE\pokemon-love2d\baseroms\
macOS:   ~/Library/Application Support/LOVE/pokemon-love2d/baseroms/
Linux:   ${XDG_DATA_HOME:-$HOME/.local/share}/love/pokemon-love2d/baseroms/
```

## Stadium animations

Version 1.0.1 covers the complete 165-move Gen 1 roster. Each move is generated
from Gen1Recomp's canonical move data and matched with decoded Pokemon Stadium
primary, alternate, impact, and resource dispatch metadata.

Slash, punch, kick, grapple, rush, needle, wind, sound, stream, wave, beam,
storm, orb, leaf, electric, psychic, drain, ground, barrier, heal, transform,
and explosion programs replace the earlier type-only fallback. Reusable
melee, combo, ranged, sustained, aerial, field, status, self, and explosion
camera timelines divide a move into windup, travel, defender impact, and
recovery stages.

Twenty-four prominent moves have source-calibrated presentations built from
cartridge textures:

- Ember, Flamethrower, Fire Blast
- Water Gun, Hydro Pump, Surf
- Ice Beam, Blizzard
- Psybeam, Psychic, Confuse Ray
- Hyper Beam
- Absorb, Mega Drain, Razor Leaf, Solar Beam
- Thunderbolt, Thunder
- Earthquake, Toxic, Recover, Light Screen, Reflect, Explosion

Thunder Shock and the earlier traced physical and status families retain their
dedicated implementations. The rest of the roster uses deterministic
Stadium-style rendering selected by move behavior and the exact Stadium effect
program/resource signature. Contact, projectile, beam, multi-hit, trapping,
status, stat change, recovery, screen, charge, recoil, and explosion moves are
all represented.

Compatible fallback programs use the cartridge texture declared by the
resource member and preserve its 24, 32, or 64-pixel footprint class. Timing
is generated from Stadium's controller cursor changes, completion markers,
and emission envelopes when those signals are statically available. Other
programs use an explicitly labelled dispatch-archetype fallback.

Moves with no independent Stadium VFX stage, including Growl and Splash, keep
their Dramaless Shape body animation when a Stadium model is active. Without
Dramaless Shape, body-only moves fall back to the ordinary Gen 1 presentation.

### Screen effects and borderless mode

Screen-wide composition shares one 160x144 animation layer. Flash, Mist, and
Haze cover the complete battle surface; Blizzard adds a scrolling grain field
and impact flash; Surf, Toxic, Psychic, Confusion, Confuse Ray, Light Screen,
Reflect, Earthquake, Selfdestruct, and Explosion use full-layer washes or
fields.

In desktop borderless mode, washes and tiled fields continue into the window
margins without stretching. Tile size and scrolling phase remain aligned with
the central battle surface. Anchored beams, rings, impacts, and particles stay
attached to their projected Pokemon.

## Stadium voices

The optional Stadium announcer is supported in Gym Leader, Elite Four, and
Champion battles. The public mod includes the playback system, but it is
deliberately voice-free. You create a personalized mod ZIP locally from your
own Pokemon Stadium ROM.

The voice pack contains 823 numbered clips and supports:

- introductions for Brock, Misty, Lt. Surge, Erika, Koga, Sabrina, Blaine,
  Giovanni, Lorelei, Bruno, Agatha, Lance, and the Champion;
- send-out calls for all 151 Pokemon, selected by Pokedex number;
- move-name calls for all 165 moves; and
- switching, effectiveness, critical-hit, status, faint, and victory lines.

If no voice pack is installed—or if an individual clip is unavailable—the
animation mod continues normally and skips that line. **STADIUM ANNOUNCER** is
enabled by default but does nothing until a valid local pack is present.

### Build a local announcer pack on Windows

Download `StadiumBattleFX-Announcer-Builder.exe` from the GitHub release and
run it, then select:

1. your Pokemon Stadium (USA) v1.0 `.z64`, `.v64`, or `.n64` ROM;
2. the downloaded, voice-free StadiumBattleFX ZIP; and
3. a destination for the personalized ZIP.

Choose **Build Announcer Pack**. The builder verifies the ROM and base mod,
extracts and converts the 823 clips, adds them under `assets/announcer/`, and
writes a local validation marker. It creates a new `-local-announcer.zip`; it
does not modify the official download.

Install the personalized ZIP through Gen1Recomp's mod manager and remove or
replace the voice-free copy. Both intentionally use the same mod ID and should
not be enabled together.

Nothing is uploaded. The ROM is never copied into the output, and temporary
audio is deleted after the build. The personalized ZIP is the only retained
ROM-derived artifact. Do not redistribute it. Run the builder again whenever
you update the official mod ZIP.

Developers can build the single-file Windows application with Python,
PyInstaller, and `ziglang` installed:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_announcer_builder.ps1
```

## Dramaless Shape integration

[Dramaless Shape](https://github.com/artyrambles/DRAMALESS_SHAPE) is optional
but strongly recommended. It provides the live Stadium Pokemon models,
skeletal animations, and staged battle projection that turn the portable
effects into a complete Stadium presentation.

StadiumBattleFX reads Dramaless Shape's exported runtime state and waits for
its first-run model extraction screen to finish before offering the attack
effect cache screen. During battle, the integration can use:

- live voxel level and Stadium battle state;
- projected model scale and model footprints;
- per-move attacker and defender attachment tags;
- an optional second origin for dual-emitter moves;
- impact-synchronized skeletal hit reactions; and
- Dramaless Shape's temporary runtime camera function for attack shots.

The integration is capability-checked. Older Dramaless Shape versions safely
fall back to staged combatant anchors and omit unavailable skeletal reactions.
Dramaless Shape owns faint animation timing, so StadiumBattleFX does not
register a competing faint listener.

The companion is read-only. StadiumBattleFX never changes Dramaless Shape's
files, settings, or `dramatic_shape/stadium/` model cache.

## Settings

| Setting | Default | Purpose |
| --- |:---:| --- |
| **STADIUM FX** | On | Enables Stadium move presentations and effect-cache loading. |
| **ATTACK CAMERA** | On | Enables staged move cameras when the required Stadium model integration is available. |
| **STADIUM ANNOUNCER** | On | Enables locally installed announcer audio; has no effect without a valid voice pack. |

## ROM data and private cache

On first use, StadiumBattleFX decodes 36 bounded texture ranges in native I4,
IA8, or RGBA16 form—about 157 KiB total—and stores them under:

```text
stadium_battle_fx/effects/v3/
```

The versioned marker is written last and records the size and checksum of each
primitive. Interrupted, incomplete, or stale caches are rejected and rebuilt.
The cache never contains the ROM, a complete archive member, or a decompressed
Stadium fragment. Cache revision 3 intentionally replaces the older
eight-asset cache.

StadiumBattleFX writes only to this private cache and does not alter the ROM.

## Fidelity and known limitations

This is a source-calibrated recreation, not a claim of frame-perfect native
capture. The move dispatcher, resource bundles, and controller timing are
traced from `pret/pokestadium`, while the visual presentation is adapted to
Gen1Recomp's 60 Hz animation layer.

Native Stadium comparisons are still needed for exact projection, tint, blend
mode, particle motion, and species-specific body and camera timing. A shared
effect program also does not imply that every Pokemon uses the same body
animation or camera behavior.

## Development

Run the Python research and packaging tests with a local cartridge:

```powershell
$env:STADIUM_ROM = "C:\path\to\Pokemon Stadium (USA).z64"
python -m unittest discover -s tests -p "test_*.py" -v
```

Build the same runtime-only ZIP used by tagged releases:

```powershell
python tools/package_runtime.py `
  --output dist\STADIUM_BATTLE_FX-1.0.1.zip
```

The allowlisted packer excludes ROMs, saves, caches, captures, research files,
and development-only tooling from the release.

Further technical documentation:

- [`docs/move-roster.md`](docs/move-roster.md) — complete 165-move registry
- [`docs/stadium1-fidelity.md`](docs/stadium1-fidelity.md) — calibrated move
  profiles and remaining visual work
- [`docs/attack-cinematics.md`](docs/attack-cinematics.md) — presentation and
  camera architecture
- [`docs/cache-format.md`](docs/cache-format.md) — private cartridge-effect
  cache format
- [`docs/research.md`](docs/research.md) — source trail and research status
- [`research/ANNOUNCER.md`](research/ANNOUNCER.md) — announcer extraction notes

## Credits

- **Gen1Recomp** — host engine and mod API
- **Dramaless Shape** — optional live Stadium models, animation, attachments,
  and staged-camera integration
- **DramaticShapeVoxelMod** — original model-extraction research and
  architectural precedent
- **pret/pokestadium** — structural source for Stadium battle effects
- **PokemonStadiumRecomp** — executable behavioral reference
- **SubDrag and N64 Sound Tool contributors** — public MORT decoder research
