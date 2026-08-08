# StadiumBattleFX 1.0.0 — Animations, voices, and complete battle presentation

Version 1.0.0 brings the complete Gen 1 move roster onto the Stadium-backed
presentation pipeline and connects effects directly to Dramaless Shape's live
animated Pokemon. It also introduces optional Pokemon Stadium announcer audio,
built locally from the player's own cartridge image.

## Highlights

- All 165 Gen 1 moves now have a Stadium-style presentation.
- Move timing has been recalibrated from Pokemon Stadium's fragment-62 effect
  controllers, including shared timeline phases, completion markers, primary
  emissions, and defender-effect envelopes.
- Projectiles, beams, particles, and target effects can follow attachment
  points on the live animated Stadium models.
- Damaging moves can trigger Dramaless Shape's skeletal hit reactions exactly
  when the authored impact frame is reached, including resisted, neutral, and
  super-effective variants.
- Full-screen effects now compose correctly in both the classic 160x144 battle
  frame and desktop borderless mode.
- Gym Leader, Elite Four, and Champion battles can use optional Stadium
  introductions, all 151 Pokemon send-out names, all 165 move-name calls, and
  selected battle reactions.

## Optional Stadium announcer

The public mod remains voice-free. Download the separate Windows
`StadiumBattleFX-Announcer-Builder.exe` and use it with your own supported
Pokemon Stadium ROM and the official mod ZIP. The builder performs the entire
823-clip extraction and conversion locally, then creates a personalized
`-local-announcer.zip` for Gen1Recomp's mod manager.

Nothing is uploaded, no ROM is copied into the output, and temporary decoded
audio is removed automatically. Personalized voice-pack ZIPs contain
ROM-derived audio and must not be redistributed. Missing packs or individual
clips never prevent the animation mod from running.

## Move and timing improvements

The remaining roster has been promoted to the
`stadium-timing-calibrated-v1` presentation tier. Moves sharing the same
Stadium effect program also share its source timing and geometry instead of
receiving unrelated type-based timing.

The existing 24 comparison-tuned profiles remain authoritative, covering
prominent attacks such as Flamethrower, Hydro Pump, Surf, Blizzard, Hyper
Beam, Solar Beam, Thunderbolt, Thunder, Earthquake, Psychic, Fire Blast, and
Explosion. Earlier hand-traced physical and status moves also retain their
dedicated implementations.

Where Stadium does not expose a static global hit tick, the move retains an
explicitly labelled dispatch-archetype fallback. Species-specific body motion
can still vary independently from the shared effect program, as it does in the
original game.

## Animated model integration

With a compatible Dramaless Shape release installed:

- effect origins and targets resolve through the public
  `Stadium.attachment(side, tag)` API;
- native attachment tag `0x64` follows the current animated model pose;
- missing capabilities safely fall back to the existing staged anchors; and
- positive-damage events request `Stadium.hit(side, effectiveness)` only at
  the move's impact frame.

StadiumBattleFX remains usable without Dramaless Shape, but live Stadium model
motion, projected attachment points, skeletal reactions, and the staged model
camera require the companion.

## Screen and camera improvements

- Flash, Mist, and Haze now use true full-screen programs.
- Blizzard includes its scrolling grain field and impact flash.
- Surf, Toxic, Psychic, Confusion, Confuse Ray, Light Screen, Reflect,
  Earthquake, Selfdestruct, and Explosion use the shared screen compositor.
- Borderless fields continue into all four desktop margins without stretching
  their cartridge textures or changing their scrolling phase.
- Attack-camera shots no longer crop more tightly than Dramaless Shape's idle
  composition.
- Thunderbolt is target-locked and strikes down onto the defender.

## Cartridge-backed presentation

The complete roster retains Stadium's exact primary, alternate, defender, and
resource dispatch signatures. Compatible fallback renderers now select
source-matched scratch, spectrum, energy, leaf, electric, sand, water, poison,
and recovery textures while preserving the original 24, 32, or 64-pixel
resource footprint class.

As before, assets are extracted at runtime from the player's own supported
Pokemon Stadium cartridge image. No Stadium ROM or copyrighted asset archive
is distributed with the mod.

## Requirements and compatibility

- Gen1Recomp `>=0.1.37 <2.0.0`
- Mod API 2
- A player-supplied supported Pokemon Stadium ROM for cartridge textures
- Dramaless Shape with the public attachment and hit APIs for the new animated
  integration features
- Dynamic Battle Cinematics `>=0.7.1 <1.0.0` remains optional

Release downloads:

- `STADIUM_BATTLE_FX-1.0.0.zip` — voice-free mod for direct installation
  through Gen1Recomp's mod manager
- `StadiumBattleFX-Announcer-Builder.exe` — optional local Windows voice-pack
  builder
- `sha256sums.txt` — checksums for the published downloads

A `.modpkg` is not published.

## Known limitations

- Native comparison captures are still needed for pixel-perfect scale, tint,
  blend mode, projection, and species-specific body/camera timing.
- Programs without a statically recoverable controller signal use a labelled
  dispatch-archetype timing fallback.
- Body-only moves depend on Dramaless Shape when a Stadium model presentation
  is expected.
- Skeletal faint reactions are not exposed or registered in this release.

## Verification

The 1.0.0 source passes complete-roster generation, deterministic timing
generation, lifecycle rendering, attachment, hit synchronization, camera,
screen compositor, and runtime compilation tests across all 165 moves.
