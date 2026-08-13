# StadiumBattleFX 2.0.0

StadiumBattleFX 2.0 is the largest release so far. It turns the mod from an
effects companion into a standalone, modular battle-presentation host for
Gen1Recomp. This release includes every StadiumBattleFX change since 1.1.2.

## Highlights

### Standalone Stadium models and synchronized battles

- StadiumBattleFX now owns the complete Stadium model pipeline: local ROM
  extraction, cache generation, skeletal animation, rendering, cameras,
  attachments, hit reactions, faint/recall timing, and battle composition.
- Added the complete 24,915-row species/move body matrix. Body animation,
  attachment selection, VFX, camera movement, and hit reactions now share one
  clock, including cartridge-specific camera selectors and controller delay.
- Dramaless Shape is no longer required. Its 2.x releases can still provide
  voxel arenas and voxel 2D cards through the new API; versions below 2.0 are
  blocked because they overlap with systems now owned by StadiumBattleFX.

### Battle Presentation API 1

- Added a public provider API with independent selectors for arenas, models,
  animation, cameras, effects, announcers, HUDs, overlays, and transitions.
- Providers are namespaced, capability-checked, isolated from runtime errors,
  and fall back safely. Selection is controlled by the player rather than mod
  load order.
- Added structured diagnostics for provider registration and selection,
  battles, ROM discovery, and every cache phase. Snapshots persist in
  playthrough-scoped storage and are available through
  `mod.exports.diagnosticLog`.
- Added a documented compatibility adapter for the official Battle
  Cinematics 0.7.96 package and cooperative camera-ownership protocol 1.
  StadiumBattleFX yields only the camera phases Battle Cinematics claims;
  models, move effects, audio, and the rest of the presentation remain active.

### Arenas

- Added ROM-derived Stadium battle rooms for Brock through Giovanni, the
  Elite Four, and the Champion, preserving native geometry, UVs, textures,
  tint, lighting, walls, floors, fixtures, and the Gym Leader Castle chamber.
- Rebuilt boss-room court composition and camera framing so the full venue
  remains visible while combatants fill the shot.
- Added four standalone arena families for ordinary battles: grass/forest,
  cave/rock, water/coast, and interior.
- When available, Dramaless 2.x voxel maps can be selected as an arena
  provider. Unsuitable or missing voxel terrain falls back to the matching
  standalone theme; authored Stadium boss rooms remain the default for major
  trainers.
- Added full-color ROM-derived Stadium trainer portraits for battle openings,
  with the original Gen1 pictures restored after the first send-out.

### ROM importer and private storage

- Restored a validated Stadium ROM import/replace action on desktop and
  Android. Desktop uses the host file dialog; Android uses Gen1Recomp's system
  document picker.
- Verified `.z64`, `.v64`, and `.n64` dumps are normalized and copied into the
  installed mod's `baseroms/baserom.z64` location.
- Migrated generated effects, models, arenas, diagnostics, and announcer data
  to Gen1Recomp's sandboxed `mod.storage` APIs.
- Combined effects, arenas, 151 model packs, and the 823-clip announcer bank
  into one four-row cache progress dashboard. The public mod remains ROM-free.

### Stadium moves and effects

- Added all 165 Stadium move dispatch rows, 193 native effect programs, and
  671 normalized scheduler emissions, including primary, alternate, defender,
  and impact channels plus all referenced render and particle presets.
- The 121 shared-renderer moves now use native particle birth, repeat, batch,
  and impact cadence instead of fixed fallback loops.
- Promoted Waterfall to a cartridge-backed descending water field that spans
  desktop borderless margins.
- Improved Thunder Shock visibility with a readable minimum projected size,
  electric glow, and brighter core.

### Announcer and local patchers

- Announcer calls now follow the visible action instead of early battle-queue
  events. Names wait for send-out, and move, hit, status, switch, faint, and
  result calls align with their animations.
- Corrected first-move, switch, effectiveness, critical-hit, faint, and
  opening/forced-send-out call families; voluntary switches retain their
  side-specific lines.
- Added the three Stadium trainer-idle calls after ten seconds without menu
  input, with proper reset, repetition, and focus rules.
- Release assets include local announcer patchers for Windows and experimental
  SteamOS/x86-64 Linux. They verify a legally owned Pokemon Stadium (USA) v1.0
  ROM and create a personalized mod ZIP locally. No ROM or voice bank is
  included in this release, and personalized output must not be redistributed.

### Compatibility and fixes

- Fixed transparent battle zones being repainted as large white blocks by
  move shake in Windows borderless mode.
- Fixed 3D worlds being hidden behind Gen1Recomp's opaque battle canvas and
  preserved composition in classic 160x144 and wide 304x144 layouts.
- Fixed Gen3 Battle UI replacing the compositor after startup; the hook is
  verified and reattached at battle boundaries.
- Fixed native trainer/send-out growth pictures flashing over 3D models and
  only suppress native battlers after a 3D world was successfully presented.
- External model providers keep ownership of their renderer, allowing
  Dramaless cards to remain in its Voxel3D depth/light pass while native
  Stadium models and arenas use the Stadium renderer.
- Added MIT licensing and third-party provenance notices for transferred code.

## Installation and upgrade notes

Install `STADIUM_BATTLE_FX-2.0.0.zip` through Gen1Recomp's mod manager. A
Pokemon Stadium (USA) v1.0 ROM is required for cartridge-derived models,
arenas, portraits, and effects; import it from the StadiumBattleFX options.

If Dramaless Shape is installed, upgrade it to 2.0 or newer before enabling
this release. Dramaless versions below 2.0 conflict with StadiumBattleFX 2.0.
Battle Cinematics is optional and works with its unchanged official 0.7.96
package.

The Windows and SteamOS/Linux announcer tools are separate optional downloads.
Extract the complete archive, run the builder, select your owned ROM and the
official voice-free 2.0.0 ZIP, then install the personalized output locally.

## Release assets

- `STADIUM_BATTLE_FX-2.0.0.zip` — public, ROM-free mod package
- `StadiumBattleFX-Announcer-Builder-windows.zip` — Windows announcer patcher
- `StadiumBattleFX-Announcer-Builder-steamos-x86_64.tar.gz` — experimental
  SteamOS/x86-64 Linux announcer patcher
- `sha256sums-2.0.0.txt` — SHA-256 checksums for all release assets

Thank you to Gen1Recomp, Dramaless Shape, DramaticShapeVoxelMod, Battle
Cinematics, pret/pokestadium, and PokemonStadiumRecomp, and to everyone who
tested the rapid 1.x and 2.0 development builds.
