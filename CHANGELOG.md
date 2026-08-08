# Changelog

## 1.0.0 - 2026-08-08

- Added optional, failure-isolated Stadium announcer playback for the eight Gym
  Leaders, Elite Four, Champion, all 151 Pokemon send-out names, all 165 move
  names, and selected switch/damage/status/faint/result reactions. Missing
  voice packs or individual WAVs leave the effects mod fully operational.
- Added a deterministic local ZIP patcher that validates the 823-file mono
  16-bit/16 kHz bank, preserves the official release, injects a private marker,
  and produces a personalized non-redistributable mod ZIP.
- Added a small single-file Windows announcer builder with ROM, base-pack, and
  output selectors plus live extraction, conversion, and compression progress.
  It performs the complete ROM-to-personalized-ZIP workflow locally and cleans
  its temporary decoded files automatically.

- Standardized local and GitHub release artifacts on directly installable
  `.zip` files; `.modpkg` packaging is no longer used.

- Calibrated all 165 move lifecycles through a reproducible fragment-62
  controller pass. Shared programs now preserve their cursor phase changes,
  explicit completion markers, final primary emission, and defender-effect
  envelope; the existing 24 comparison-tuned profiles remain authoritative.

- Added capability-checked integration with Dramaless Shape's public
  attachment APIs. Move origins now use byte 2 of the active species' move
  row, impacts use the defender's native context-row attachment, and the
  `0xFF` body-origin sentinel no longer aliases tag `0x64`. Byte 3 is retained
  and exposed for dual-origin renderer ports. All resolved points follow the
  live animated model pose and safely fall back to staged anchors.
- Enabled impact-synchronized skeletal hit reactions through Dramaless Shape's
  public `Stadium.hit(side, effectiveness)` API. Gen1Recomp damage is recorded
  while its queue is built, but the reaction is requested only at the move's
  authored impact frame.

- Made full-screen move fields borderless-aware. Screen washes and cartridge
  tiles now cancel Dramaless Shape's combatant-pair transform and continue at
  the same pixel scale and phase into all four desktop margins after frame
  composition, while target-anchored particles keep their model projection.
- Prevent attack-camera shots from cropping tighter than Dramaless Shape's
  idle composition while retaining focus, orbit, and impact movement.
- Made Thunderbolt target-locked, striking down onto the defender from above
  instead of bending toward an off-screen attacker in dramatic shots.
- Added a shared 160x144 screen-effect compositor for solid washes, scrolling
  cartridge textures, timed flashes, and attack/release envelopes.
- Implemented true full-screen programs for Flash, Mist, and Haze instead of
  routing them through local status/barrier shapes.
- Completed Blizzard's declared screen-grain field and impact flash, and moved
  Psychic, Confusion, Explosion, and generic screen washes onto the shared
  compositor.
- Replaced the remaining roster's four placeholder lifecycle timings with
  presentation-family timing envelopes for all contact, projectile, field,
  status, recovery, transform, and explosion programs. Runtime then promotes
  these entries to `stadium-timing-calibrated-v1` after applying their source
  dispatch, controller timing, resource, geometry, and texture metadata; the
  24 dedicated cartridge-backed profiles remain `stadium1-source-calibrated`.
- Added full-layer coverage tests for Flash, Mist, Haze, and texture tiling,
  plus calibration-tier accounting across all 165 moves.
- Calibrated the remaining 122 roster entries against Stadium's exact
  fragment-62 primary, alternate, impact, and resource signatures. Shared
  source programs now share canonical 24/32/64-pixel footprint classes and
  select compatible cartridge textures instead of relying on type alone.
- Added exact-texture overlays for projectile, beam, contact, and status
  fallback programs, including source-matched scratch, spectrum, energy,
  leaf, electric, sand, water, poison, and recovery resources.
- Kept all model, rig, matrix, and cache ownership inside Dramaless Shape; the
  integration consumes only its projected read-only attachment coordinates.

## 0.7.0 - 2026-08-07

- Expanded the private Pokemon Stadium 1 cache from 8 to 36 exact texture
  ranges across 14 effect archive members, with native I4, IA8, and RGBA16
  decoding and a format-v3 integrity marker.
- Added source-calibrated Stadium 1 profiles for 24 prominent elemental,
  beam, drain, status, screen, recovery, ground, and explosion moves.
- Added cartridge-textured full-screen and status programs for Surf, Blizzard,
  Toxic, Psychic, Confuse Ray, Light Screen, Reflect, Earthquake, and
  Explosion.
- Added ROM-backed auditing of every declared asset pointer, byte count, and
  fragment bound, plus lifecycle smoke tests for every fidelity profile.

## 0.6.0 - 2026-08-07

- Migrated model, cache-screen, and camera discovery from the defunct
  `DRAMATIC_SHAPE` mod ID to `DRAMALESS_SHAPE`.
- Made Dramaless Shape optional but strongly recommended; portable effects
  remain available without it, while model body motion and the staged Stadium
  camera require the companion.
- Kept Dynamic Battle Cinematics optional and retained its composed camera
  adapter for a future release compatible with the new companion ID.
- Staged capability-checked hit and faint bridge modules for future upstream
  APIs, but intentionally disabled all damage/faint event registration and
  reaction settings in this release.

## 0.5.1 - 2026-08-07

- Added an opt-in Dynamic Battle Cinematics compatibility zoom with 10%, 25%,
  35%, and 50% optical zoom-out levels. It widens the lens without changing
  the companion camera's eye path, focus, canonical queries, files, or saved
  settings.

## 0.5.0 - 2026-08-07

- Split the complete roster into reusable move-shaped visual programs instead
  of presenting most attacks through the same type-colored beam/projectile
  fallback.
- Added staged melee, combo, ranged, sustained, aerial, field, status, self,
  and explosion attack-camera timelines for Dramatic Shapes Stadium battles.
- Preserved Stadium's overlap model: visual, primary/impact dispatch, species
  body animation, and camera selection remain independent layers.
- Added source research and tests for safe disc orbits, fixed-eye map shots,
  mirrored attackers, canonical-camera passthrough, and director shutdown.

## 0.4.0 - 2026-08-07

### Added

- Implemented presentations for all 165 Gen 1 moves through a deterministic
  type- and behavior-aware renderer covering contact, projectile, beam,
  multi-hit, trapping, status, stat, recovery, screen, charge, and explosion
  families.
- Added a generated complete-roster specification sourced from Gen1Recomp's
  canonical move table and merged with every decoded Stadium primary,
  alternate, impact, and resource dispatch entry.
- Added exhaustive lifecycle rendering tests for every move at start, impact,
  and completion while retaining the Dramatic Shapes and Dynamic Battle
  Cinematics projection tests.

### Changed

- The battle adapter now replaces every registered Gen 1 attack instead of
  limiting custom presentations to the supplied Yellow party and first shared
  impact family.
- Exact ROM-textured renderers remain authoritative where available; the rest
  use portable procedural presentations pending native Stadium calibration.

## 0.3.1 - 2026-08-07

### Fixed

- Inverse-map attacker and target anchors through Dramatic Shapes' live
  animation-layer transform so Dynamic Battle Cinematics camera orbits no
  longer leave attack particles beside the target.

## 0.3.0 - 2026-08-07

### Added

- Decoded all 165 Gen 1 entries in Stadium's move dispatch/resource table and
  generated a runtime roster plus a human-readable coverage report.
- Added the first post-0.2 shared family: Pound, Karate Chop, Jump Kick,
  Rolling Kick, and Counter now reuse Stadium impact opcode `0x2C` assets.
- Recorded canonical Stadium particle quad sizes, scale APIs, optional species
  normalization, and Thunder Shock's five exact scale envelopes.
- Added a read-only Dramatic Shapes presentation adapter for the current voxel
  level, staged-camera animation scale, Stadium mode, and model footprints;
  live DS animation-layer projection is detected and never applied twice.
- Declared and regression-tested Dynamic Battle Cinematics v0.7.1 as an
  optional camera companion. Its camera remains owned by Dramatic Shapes and
  no Battle Cinematics files or settings are touched.

### Changed

- Thunder Shock development source now animates Stadium's per-callback world
  scale instead of applying one constant sprite size. The absolute portable
  projection anchor remains pending native capture calibration.

## 0.2.0 - 2026-08-07

### Added

- Added first-pass Stadium presentations for every move on the supplied
  Yellow save's party: Scratch, Gust, Double Kick, Sand Attack, Horn Attack,
  Tackle, Leer, Growl, String Shot, Thunder Wave, Confusion, Quick Attack,
  and Splash, alongside Thunder Shock.
- Added eight shared ROM-derived texture primitives for electric, scratch,
  sand, Thunder Wave, and generic hit effects.
- Added a dedicated first-run attack-effect cache screen with real extraction,
  write, and upload progress.
- Added arbitrary flat `.z64`, `.n64`, and `.v64` discovery in Dramatic
  Shapes' shared `baseroms/` location.
- Added read-only Dramatic Shapes state integration for body-only effects and
  first-run screen sequencing.

### Changed

- Moved runtime assets to integrity-checked cache format v2 under
  `stadium_battle_fx/effects/v2/`.
- Generalized the battle adapter from Thunder Shock to the complete test-party
  move registry while retaining vanilla fallback per move.
- Added the public GitHub update source and tagged-release packaging workflow.

## 0.1.1 - 2026-08-07

### Fixed

- Made the Thunder Shock texture retain alpha coverage on Dramatic Shapes'
  transparent battle canvas, where the prior additive-only draw disappeared.
- Added an internal draw-error report and vanilla-animation fallback.
- Removed the experimental fresh-install disable flag.

### Added

- Added a versioned, integrity-checked private effect cache under
  `stadium_battle_fx/effects/` in the Gen1Recomp save directory.
- Declared the filesystem permission used only for that cache.

## 0.1.0 - Unreleased

- Traced Thunder Shock's primary and impact opcode schedules.
- Added safe extraction of its eight-frame N64 I4 texture from a verified ROM.
- Added a standalone LÖVE 11.x fixed-step research viewer.
- Kept all ROM-derived output in an ignored private cache.
- Added species/move body-row probing with bounded ROM reads.
- Added the Android-safe runtime extractor using Dramatic Shapes' shared
  `baseroms/` convention, including `.z64`, `.n64`, and `.v64` byte orders.
- Replaced only `THUNDERSHOCK` through a delegating AnimPlayer adapter while
  preserving Gen1Recomp's queue, hit timing, and original sound events.
