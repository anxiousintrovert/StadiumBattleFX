# Changelog

## Unreleased

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
