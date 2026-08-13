# StadiumBattleFX

**Pokemon Stadium animations, voices, and battle presentation for Gen1Recomp.**

**[Download the latest release](https://github.com/anxiousintrovert/StadiumBattleFX/releases/latest)**

> [!WARNING]
> This project is an experimental, AI-assisted prototype. It is not an
> authoritative or frame-perfect reimplementation of Pokemon Stadium. Expect
> inaccuracies, rough edges, and code that may eventually be replaced by a
> native implementation from an experienced developer.

StadiumBattleFX brings Pokemon Stadium-inspired battles to Gen1Recomp. It gives
all 165 Gen 1 moves a Stadium-style presentation, owns its live animated
Stadium models and battle arenas, and can add the original Stadium announcer
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
| **Animated model attachments** | Effects follow the attacker's live origin point and the defender's impact point throughout the pose. |
| **Hit reactions** | Damaging moves trigger the Stadium model's skeletal reaction at the authored impact frame. |
| **Attack cameras** | Stages windup, travel, impact, and recovery shots during Stadium-model battles. |
| **Boss arenas** | Adds all eight Kanto Gym Leader Castle venues plus Elite Four and Champion venues. |
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
- Battle Cinematics is optional but strongly recommended when using Stadium
  boss arenas, for its arena-safe camera direction

Dramaless Shape is not required. Dramaless 2.x may optionally add its voxel
map as an arena choice through the public battle-presentation API. Legacy
Dramaless versions below 2.0 are intentionally blocked from loading beside
StadiumBattleFX 2.0 because both would otherwise own the same battle systems.

## Installation

1. Install the versioned `STADIUM_BATTLE_FX-<version>.zip` through
   Gen1Recomp's mod manager.
2. Enable **StadiumBattleFX**.
3. For cartridge-backed models, arenas, textures, and portraits, open Options
   and choose **STADIUM ROM → IMPORT**. Desktop opens a host file dialog;
   Android opens Gen1Recomp's system document picker. The selected `.z64`,
   `.n64`, or `.v64` is validated as Pokemon Stadium (US) 1.0 and copied to
   this installed mod's `baseroms/baserom.z64`. A personalized local ZIP may
   instead bundle the owned ROM there. Never redistribute either copy.
4. On the first overworld load, the **STADIUM ATTACK FX**
   screen builds the private effect cache and closes automatically.

Use **OPTIONS → REFRESH FX CACHE → REBUILD** after replacing the ROM or if a
cache build was interrupted. It re-extracts the effects immediately.

When upgrading from an older release, use the mod manager's update or
reinstall action. If the displayed version does not change, remove every old
**StadiumBattleFX / Stadium Attack Animations** copy, restart Gen1Recomp, and
then install the new ZIP. This clears same-ID folders left by older mod-manager
versions without deleting the private effect cache.

Example ROM layout:

```text
baseroms/baserom.z64
```

Do not put the ROM in a regional subfolder such as `baseroms/us/`.

The official ZIP remains ROM-free and falls back to procedural presentation
when no local cartridge is bundled. A source checkout may
place the owned ROM under `baseroms/` beside `main.lua` using a recognized name
shown above. Never redistribute a package containing your ROM.

## Stadium animations

Version 1.0.3 covers the complete 165-move Gen 1 roster. Each move is generated
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
their Stadium body animation when a Stadium model is active. If model data is
not available, body-only moves fall back to the ordinary Gen 1 presentation.

### Screen effects and borderless mode

Screen-wide composition shares one 160x144 animation layer. Flash, Mist, and
Haze cover the complete battle surface; Blizzard adds a scrolling grain field
and impact flash; Surf, Waterfall, Toxic, Psychic, Confusion, Confuse Ray,
Light Screen, Reflect, Earthquake, Selfdestruct, and Explosion use full-layer
washes or fields.

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
- move-name calls for all 165 moves;
- switching, effectiveness, critical-hit, status, faint, and victory lines; and
- trainer-idle prompts when a battle command is left untouched.

Calls follow the action they describe rather than the engine's earlier queue
setup: a Pokemon's name is announced only after its send-out text is dismissed
and the Pokemon has entered the field, while move and reaction calls wait for
their animation, HP-drain, status, or faint beat.

If no voice pack is installed—or if an individual clip is unavailable—the
animation mod continues normally and skips that line. **STADIUM ANNOUNCER** is
enabled by default but does nothing until a valid local pack is present.

### Build a local announcer pack on Windows

Download `StadiumBattleFX-Announcer-Builder-windows.zip` from the GitHub
release, verify its published SHA-256, extract it, and run
`StadiumBattleFX-Announcer-Builder.exe` from the extracted folder. Then select:

1. your Pokemon Stadium (USA) v1.0 `.z64`, `.v64`, or `.n64` ROM;
2. the downloaded, voice-free StadiumBattleFX ZIP; and
3. a destination for the personalized ZIP.

Choose **Build Announcer Pack**. The builder verifies the ROM and base mod,
extracts and converts the 823 clips, adds them under `assets/announcer/`, and
writes a local validation marker. It creates a new `-local-announcer.zip`; it
does not modify the official download. It also places the verified ROM inside
the personalized package so the sandboxed runtime can build cartridge-backed
  assets. On first use, the complete validated voice bank and derived cartridge
  data are copied into playthrough-scoped `mod.storage` records.

Install the personalized ZIP through Gen1Recomp's mod manager and remove or
replace the voice-free copy. Both intentionally use the same mod ID and should
not be enabled together.

Nothing is uploaded. The owned ROM is copied only into your local personalized
ZIP, and temporary audio is deleted after the build. The personalized ZIP and
private cache are ROM-derived artifacts; do not redistribute either.

Developers can build the inspectable Windows application folder with Python,
PyInstaller, and `ziglang` installed:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_announcer_builder.ps1
```

For public releases, use a trusted Authenticode certificate and publish the
generated SHA-256 file. See
[`tools/ANNOUNCER_BUILDER_SECURITY.md`](tools/ANNOUNCER_BUILDER_SECURITY.md)
for the distribution checklist and an explanation of scanner warnings.

## Standalone models and optional arena mods

Opponent introductions use Pokemon Stadium's native 64x64 battle portraits for
every ordinary Gen 1 trainer class, Gym Leaders, the Elite Four, and the
Champion. Stadium 1 stores these actors as RGBA5551 portraits rather than
skeletal human models, so StadiumBattleFX replaces the arena cards during the
opening and restores the engine art after the first send-out. Portrait pixels
are extracted into the same private cache from the player-supplied ROM.

StadiumBattleFX 2.0 owns Pokemon model extraction, skeletal animation,
attachments, hit/faint/recall timing, cameras, and battle presentation. The
player-supplied Stadium ROM is converted into the private
`stadium_battle_fx/models/v6/` cache alongside attack and arena caches. DSM6
retains Stadium's complete 16-byte per-species/per-move synchronization rows;
older DSM5 packs remain readable but do not expose native trigger frames.

Other mods—including Dramaless 2.x—can register independently selectable
arenas, models, animations, cameras, effects, announcers, HUDs, overlays, and
transitions. The player chooses each area separately; load order never grants
priority. See [`docs/BATTLE_PRESENTATION_API.md`](docs/BATTLE_PRESENTATION_API.md)
for the complete, versioned developer/LLM contract.

### Automatic arenas and Stadium boss rooms

With **BTL ARENA** on `STADIUM DEFAULT`, ordinary encounters automatically use
Dramaless's registered voxel-map provider when it is installed and ready. If
that provider is absent or cannot stage the current location, StadiumBattleFX
uses one of four standalone portable environments selected from the current
map, tileset, and surfing state:

- **Grass/forest** for routes, towns, forests, the Safari Zone, and unknown
  outdoor maps.
- **Cave/rock** for caverns, Pokemon Tower, Mt. Moon, Rock Tunnel, Diglett's
  Cave, Victory Road, and the Seafoam interiors.
- **Water/coast** while the player is surfing, with a raised island court over
  a surrounding water plane.
- **Interior** for houses, ships, labs, facilities, gates, and other indoor
  tilesets.

Each environment carries its own floor, distant horizon geometry, silhouettes
or architectural details, material palette, and sky clear. They use
StadiumBattleFX's standalone textured-mesh renderer and do not require voxel
terrain. Explicitly choosing another registered arena still overrides this
automatic policy.

Boss encounters use the native Stadium rooms described below.

The built-in Stadium arena provider automatically selects the appropriate boss
venue. The first-run cache converts Gym Leader Castle
members 7 through 16 from Stadium's `stadium_models` archive. Their native N64
geometry layouts, F3DEX triangles, UVs, material groups, vertex lighting and
bounded RGBA/IA/I textures become StadiumBattleFX meshes locally; executable MIPS
code is discarded. Every native stage group is retained, including the broad
outer floor, foundation, suspended fixtures, and enclosed perimeter wall.
The native scene is scaled to 0.100, the minimum supported room scale needed
to keep the chamber walls beyond the camera viewpoint while retaining the
corrected stage proportions.
Portable orbit, elevation, and zoom bounds keep the steerable camera inside
the venue.
Boss rooms use a raised 82-pixel camera eye with the original 34.11-pixel frame;
Each boss venue's replacement Poké Ball mark is sized independently from the
room so it does not grow with the enclosing wall or change the room's apparent scale. Its
total native diameter is 500 units with a solid gray interior, centred within
an independent 2400x1600 native-textured platform so resizing the mark cannot
remove the stage beneath it or turn the platform rim into a second giant
Poké Ball. Each platform uses the broad floor texture from its own ROM-native
venue.
Brock, Misty, Lt. Surge, Erika, Koga, Sabrina, Blaine,
Giovanni, the Elite Four, and Champion select the same stage member Stadium
selects (including only Giovanni's Viridian Gym party). The diagnostic log
records the selected venue, source member, opponent, and party index.
Every other encounter uses the automatic voxel-or-themed policy instead of
forcing a boss floor into ordinary battles.

### Battle Cinematics integration

[Battle Cinematics](https://github.com/EnterPlayerOne/Battle-Cinematics-Stadium-Camera)
is a soft requirement for the Stadium boss arenas: the arenas still load
without it, but its arena-aware direction is the recommended camera setup.

Release 0.7.96 does not yet register through StadiumBattleFX API 1. SBFX instead
discovers the supported Shape-family `BattleCam` table that the unchanged
official Battle Cinematics package already wraps and consumes its final pose for
both Stadium and voxel-map arenas. No Battle Cinematics files are patched or
redistributed. Once those hooks are installed, Stadium adds **BATTLE
CINEMATICS** to the **BTL CAMERA** list.

Battle Cinematics 0.7.96 does not expose camera ownership, so users of that
release must still leave only one optional attack camera enabled. Releases that
expose camera-ownership protocol 1 negotiate automatically: a BC attack claim
makes SBFX yield only its attack-camera timeline while move graphics, model
animation, impacts, sound, and announcer timing continue normally.

## Settings

| Setting | Default | Purpose |
| --- |:---:| --- |
| **STADIUM FX** | On | Enables Stadium move presentations and effect-cache loading. |
| **ATTACK CAMERA** | On | Enables staged move cameras when the required Stadium model integration is available. |
| **ATTACK SPEED** | 100% | Slows Stadium VFX, impact timing, sound events, and the attack camera together in 10% steps. At 0%, the normal Gen1 presentation is used with no Stadium attack camera. |
| **STADIUM ANNOUNCER** | On | Master switch for locally installed announcer audio; has no effect without a valid voice pack. |
| **ANNOUNCER BATTLES** | Gym / Elite 4 / Champion | Chooses where announcer audio plays: Gym/Elite 4/Champion, all trainer battles, or all battles including wild Pokemon. |
| **BTL ARENA / MODELS / ANIM / CAMERA / EFFECTS / VOICE / HUD / OVERLAY / TRANS** | Stadium Default | Selects the provider for each independent presentation area. Registered mod providers appear alphabetically; `OFF` disables only that area. The camera OFF rung also disables the temporary Battle Cinematics 0.7.96 bridge. |
| **STADIUM ROM** | Import/Replace | Validates and copies a selected Stadium ROM into this installed mod's `baseroms` folder; Android uses the system document picker. |
| **REFRESH FX CACHE** | Rebuild | Forces a fresh extraction from the bundled local ROM. |
| **SAVE DIAGNOSTIC SNAPSHOT** | Save | Saves diagnostics in this mod's playthrough storage. The text is also exposed as `mod.find("STADIUM_BATTLE_FX").exports.diagnosticLog()`. |

## ROM data and private cache

On first use, StadiumBattleFX decodes 36 bounded texture ranges in native I4,
IA8, or RGBA16 form—about 157 KiB total—and stores them under logical keys in
`mod.storage`:

```text
stadium_battle_fx/effects/v3/
```

The versioned marker is written last and records the size and checksum of each
primitive. Interrupted, incomplete, or stale caches are rejected and rebuilt.
The cache never contains the ROM, a complete archive member, or a decompressed
Stadium fragment. Cache revision 3 intentionally replaces the older
eight-asset cache.

The arena cache is separate:

```text
stadium_battle_fx/arenas/v1/
```

It contains ten converted native stage files from members 7 through 16 of
`stadium_models`, plus a versioned size/checksum marker. Each file contains
only the referenced scene triangles, vertex records, material constants and
bounded texture pixels needed by StadiumBattleFX. The source fragment's MIPS code,
relocation table, unused data and the ROM itself are not cached. Elite Four and
Champion retain Stadium's original (identical) final-stage payloads.

The 151 locally derived model packs and optional 823-clip announcer bank use
their own versioned logical keys:

```text
models/packs/001 .. models/packs/151
announcer/clips/000 .. announcer/clips/822
```

Their completion markers are also written last. A marker is never accepted
for an interrupted import, so a finished cache is reused on the next launch
while a partial one safely resumes by rebuilding.

All four cache families appear in one startup dashboard: attack FX, arenas,
models, and the optional announcer bank. Each completed cache is scoped to the
active playthrough by the engine.

The engine owns every derived-cache path and scopes each record to this mod and
active playthrough. The explicit ROM import action is the only exception: it
has declared filesystem permission and writes only the validated cartridge to
this installed mod's `baseroms/baserom.z64`; runtime cache code remains on
logical `mod.storage` keys.

## Fidelity and known limitations

The 2.0 runtime now carries all 165 native move dispatch rows, 193 primary,
alternate, and impact programs, 671 normalized scheduler emissions, 86 render
presets, and 57 particle presets. When
the built-in Stadium model is active, its complete 151-by-165 cartridge body
matrix supplies the live animation start, attachment bytes, camera selectors,
camera transition tick, and body pose. Those layers share one 60 Hz move
clock; the native skeletal sampler advances at its original half rate.

The remaining portability boundary is visual, not scheduling data. Native
callback geometry is translated into Gen1Recomp's 2D animation layer, whose
projection and compositing differ from the N64 renderer. Random camera groups
use Stadium's exact legal selector sets but a deterministic replay seed. This
release therefore does not claim pixel-identical native projection for every
particle callback.

The 121 shared-renderer moves now take their particle birth, repeat, batch,
primary/alternate, and impact-channel cadence from those native scheduler
records instead of the previous fixed six-particle fallback loops. The 25
cartridge-textured and 19 dedicated dispatch-traced renderers retain their
more specific callback ports.

## Development

Run the Python research and packaging tests with a local cartridge:

```powershell
$env:STADIUM_ROM = "C:\path\to\Pokemon Stadium (USA).z64"
python -m unittest discover -s tests -p "test_*.py" -v
```

Build the same runtime-only ZIP used by tagged releases:

```powershell
python tools/package_runtime.py `
  --output dist\STADIUM_BATTLE_FX-2.0.0.zip
```

The allowlisted packer excludes ROMs, saves, caches, captures, research files,
and development-only tooling from the release.

Further technical documentation:

- [`docs/BATTLE_PRESENTATION_API.md`](docs/BATTLE_PRESENTATION_API.md) — public
  provider API contract for developers and LLM implementers
- [`docs/DRAMALESS_2_0_PR_LEDGER.md`](docs/DRAMALESS_2_0_PR_LEDGER.md) — tracked
  companion-side split work and PR acceptance evidence
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
- **Dramaless Shape** — original home of the transferred Stadium model stack
  and optional 2.x voxel-arena provider
- **DramaticShapeVoxelMod** — original model-extraction research and
  architectural precedent
- **pret/pokestadium** — structural source for Stadium battle effects
- **PokemonStadiumRecomp** — executable behavioral reference
- **SubDrag and N64 Sound Tool contributors** — public MORT decoder research
