# Changelog

## 2.0.0 release fixes

- Fixed move shake composition repainting the transparent battle zones as
  large white blocks over Stadium and Dramaless arenas in Windows borderless
  mode. Authored move effects, the HUD, and battle text remain visible.
- Restored the Stadium ROM import action on desktop and Android. Android uses
  Gen1Recomp's dedicated system document picker, and every verified ROM is
  copied into the installed SBFX mod's `baseroms/baserom.z64` location.
- Kept projected attack layers, borderless screen effects, synchronized model
  attacks, and full-color Stadium trainer portraits in the same 2.0.0 build.

## 2.0.0 native scheduling and synchronization follow-up

- Added all 165 Stadium move dispatch rows, 193 native effect programs, and
  671 normalized scheduler emissions to the runtime, including primary,
  alternate, and defender/impact channels, plus all 86 render and 57 particle
  preset records referenced by them.
- Replaced fixed fallback particle birth loops with those scheduler emissions
  for the 121 shared-renderer moves.
- Added the complete 24,915-row Stadium species/move body matrix and locked
  body pose, attachment selection, VFX, camera, and hit reaction to one clock.
- Replaced shared camera-family guesses whenever native model data is present
  with each species/move row's two camera selectors and controller delay.
- Preserved the native 15-frame camera-delay default when the cartridge row's
  transition byte is zero.

- Replaced Gen1Recomp's opening trainer pictures with the corresponding
  Pokemon Stadium battle portraits until each trainer sends out their first
  Pokemon. The portraits are decoded locally from the player's Stadium ROM;
  the original pictures are restored after the opening so victory scenes are
  unchanged.

## 2.0.0 Dramaless renderer compatibility follow-up

- External model providers now retain ownership of their renderer. Stadium's
  mesh shader is applied only to the built-in Stadium model provider, allowing
  Dramaless cards to remain inside its active Voxel3D depth/light pass while
  keeping Stadium arenas and Stadium models on their native renderer.

## 2.0.0 cache persistence follow-up

- Combine effect, arena, model, and 823-clip announcer caching into one
  four-row progress dashboard backed exclusively by `mod.storage`.
- Retain the `baseroms/` folder in every packaged mod; public builds contain
  instructions while personalized private builds may contain the owned ROM.
- Provide a validated Stadium ROM import/replace action. Desktop uses the host
  file dialog and Android uses Gen1Recomp's dedicated system document picker;
  the selected ROM is copied into the installed mod's `baseroms/` folder.

## 2.0.0 - local test build

- Added four reusable standalone arena themes for ordinary battles: grass and
  forest, cave and rock, water and coast, and interior. Each has a layered
  floor, horizon, themed silhouettes or architecture, and its own sky clear,
  rendered without any Dramaless dependency.
- Made the default ordinary-battle arena prefer Dramaless's registered voxel
  map when available. If voxel terrain is absent or declines the encounter,
  the host falls back to the matching portable theme; authored Stadium boss
  rooms remain the default for Gym Leaders, Elite Four, and Champion battles.
- Fixed forced and opening Pokemon send-outs being announced as if the other
  trainer had chosen to change Pokemon. Voluntary player and opponent switches
  still use their side-appropriate change calls.
- Fixed native trainer and send-out growth pictures flashing over Stadium 3D
  models. The host now filters the complete side-aware picture layer rather
  than only ordinary `drawBattlerPic` calls, while keeping the scoped capture
  bypass used by external 2D-card providers.
- Preserved 3D world composition under both the classic 160x144 and wide
  304x144 battle layouts without suppressing later full-screen move flashes.
- Migrated the complete shipped runtime to Gen1Recomp's mod sandbox. Bundled
  files use `mod:read`, ROM-derived caches and diagnostics use playthrough-scoped
  `mod.storage`, and the personalized local builder embeds the owned ROM. The
  only host-file operation is the explicit ROM import action, which validates
  the selected cartridge and copies it to the installed mod before use.
- Fixed Gen3 Battle UI replacing StadiumBattleFX's `BattleState:draw` wrapper
  after startup, which restored the opaque white field while the model hook
  continued hiding native sprites. The host now verifies and reattaches its
  compositor at the battle boundary, and only hides 2D battlers after a 3D
  world surface was successfully presented.
- Fixed 3D battles being hidden behind Gen1Recomp's opaque white battle
  canvas. StadiumBattleFX now follows Dramaless's proven renderer seam: a
  framebuffer-sized world override beneath a transparent 160x144 battle UI.
  Native and voxel arenas use the same composition path and retain the
  classic framing at widescreen aspect ratios.
- Fixed standalone battlers always falling back to 2D. The transferred model
  runtime was reading the exported `src.core.Game` class as if it were the
  live game singleton, so species never resolved to National Dex numbers.
  Resolution now uses the active BattleState's merged data table.
- Split Stadium battle ownership from Dramaless Shape. StadiumBattleFX now
  owns model extraction/cache, skeletal runtime, battle renderer, camera,
  attachments, hit/faint/recall timing, and boss arenas; Dramaless is no
  longer a dependency and legacy versions below 2.0 are hard-blocked.
- Added battle-presentation API 1 with independent arena, model, animation,
  camera, effects, announcer, HUD, overlay, and transition selectors. External
  providers are player-selected, namespaced, capability-checked, protected at
  runtime, and safely fall back without load-order priority.
- Added the developer/LLM API contract and Dramaless split PR ledger under
  `docs/`, plus MIT licensing and transferred-code provenance notices.
- Expanded structured diagnostics across provider registration/selection,
  battle lifecycle, bundled-ROM discovery, and all cache phases. Snapshots are
  persisted in scoped storage and exposed through `mod.exports.diagnosticLog`.
- Added cooperative Battle Cinematics camera ownership protocol 1 support.
  StadiumBattleFX queries the read-only `passive`, `intro`, `attack`, and
  `faint` claims and yields only the claimed camera phase. It checks attack
  ownership again while applying a shot and leaves models, move VFX, audio,
  and the rest of the presentation active. Either mod may ship independently.
- Added an SBFX-side adapter for the unchanged official Battle Cinematics
  0.7.96 package. SBFX discovers the Shape-family `BattleCam` table BC already
  wraps and consumes its final pose for Stadium and voxel arenas; no forked BC
  build, reverse dependency, or redistributed BC files are required.
- Promoted Waterfall from the target-local generated wave fallback to a
  cartridge-backed descending water field. Its wash, scrolling texture, and
  impact flash now replay across desktop borderless margins; missing cosmetic
  cache entries no longer disable the full-screen program.
- Synchronized announcer playback to visible battle actions instead of the
  engine's earlier queue-construction events. Pokemon names now wait until
  their send-out text is dismissed and that Pokemon has entered; move, hit,
  status, switch, faint, and result calls follow their respective animations.
  Reviewed first-move, switch, effectiveness, critical, and faint variants now
  rotate through their correct event families.
- Added the three Stadium trainer-idle calls. They rotate after ten seconds
  without input at the battle or move menu, reset when the player acts, never
  repeat on an untouched decision, and stay silent while another screen owns
  input.
- Added a Dramaless battle-stage provider for Brock through Giovanni, the Elite
  Four, and Champion. The verified ROM's actual `stadium_models` members 7–16
  are converted locally from native geometry layouts and F3DEX display lists
  into checksummed 3D mesh/material caches. The earlier `battle_headers`
  interpretation and procedural pillar reconstruction have been removed.
- Native UVs, RGBA/IA/I textures, material tint, vertex lighting, proportions,
  and the Gym Leader Castle black chamber clear are retained through Dramaless
  camera rotation. Arena selection logs the exact source member; ordinary
  encounters still inherit their configured baseline arena.
- Rotated native boss rooms 90 degrees into Dramaless' battle axis and restored
  every native stage group, including Brock's broad outer floor, deep
  foundation, and tall enclosed stone perimeter wall. The previous clean-room
  filter incorrectly discarded those pieces as an exterior shell.
- Set native boss-arena world scale to its 0.100 minimum, moving Brock's
  perimeter back beyond the wide-camera viewpoint while the battle floor fills the shot.
  Portable orbit, elevation, and zoom bounds keep steering inside the venue
  footprint.
- Replaced Brock's five low castle-emblem meshes with a clean circular Poké
  Ball court: neutral field, outer ring, divider, and centred button. The room,
  outer floor, foundation, wall, and suspended fixtures remain ROM-native.
- Reduced the replacement court mark to a 500-native-unit diameter and added a
  dedicated raised boss-camera rig. The eye rises to 82 world pixels while
  retaining the original 34.11-pixel frame, so the room no longer shrinks.
- Separated Brock's physical floor from its Poké Ball artwork. A 2400x1600
  native-textured rectangular platform now remains under the combatants while
  the independently sized 500-unit mark is contained within its centre.
- Filled the interior of the 500-unit Poké Ball with a neutral gray disc while
  retaining the white outer ring, divider, and centred button above it.
- Applied the completed 0.100 arena setup to Misty through Champion. Each ROM
  member keeps its walls, fixtures, and broad-floor texture while its low
  centre emblem is replaced by the contained 2400x1600 platform and filled
  500-unit Poké Ball used by Brock.
- Fixed Thunder Shock's opening bolts becoming sub-pixel in Gen1Recomp. A
  minimum projected size, soft electric glow, and brighter core keep the I4
  cartridge texture readable on both classic and Stadium arena backgrounds.

## 1.1.2 - 2026-08-10

- The Stadium effect-cache scan now verifies the normalized ROM MD5 as well
  as its size and header. Unsupported or modified ROMs stop the cache build
  with a clear incorrect-version-or-ROM error instead of extracting assets.
- Rebuilt the Windows announcer decoder for the baseline x64 instruction set,
  preventing unsupported-instruction failures on compatible older CPUs.

## 1.1.1 - 2026-08-10

- Fixed Stadium announcer faint calls playing when the battle first records a
  knockout. They now wait until the battle UI's HP bar has drained to zero.

## 1.1.0 - 2026-08-10

- Added complete Stadium attachment handling: attack effects now make a
  separate localized pass for either non-sentinel secondary attachment tag.
- Added impact-timed Stadium Pokemon hit reactions through the public
  Dramaless Shape hit API. Neutral and super-effective hits use Stadium's
  held hit motion; resisted hits remain idle.
- Added **ANNOUNCER BATTLES** to select Gym/Elite 4/Champion, all trainer
  battles, or all battles independently from the announcer master switch.
- Added occasional low-priority battle-flow commentary that waits for quiet
  gaps and yields immediately to move, damage, switch, faint, and other
  priority calls.
- Improved Windows announcer-builder distribution with an inspectable
  application-folder archive and a published SHA-256 checksum.
- Fixed Windows diagnostic-log export status reporting and made optional
  animation logging safe with partial logger implementations.

## 1.0.9 - 2026-08-09

- Added **ANNOUNCER BATTLES** to the StadiumBattleFX mod options. Select
  **GYM / ELITE 4 / CHAMPION** (the default), **ALL TRAINER BATTLES**, or
  **ALL BATTLES** to control the announcer's battle range independently of
  the existing **STADIUM ANNOUNCER** master switch.
- Added low-priority battle-flow commentary after every few moves. It waits
  for an idle gap and is immediately interrupted by any move, damage, switch,
  faint, or other higher-priority battle call.

## 1.0.8 - 2026-08-09

- Fixed Windows diagnostic-log exports failing silently after a Save dialog.
  The options row now reports `SAVED`, `CANCELLED`, or `FAILED`; failed file
  writes are recorded in the persistent diagnostic log instead of being
  reported as success.

## 1.0.7 - 2026-08-09

- Added the Stadium-model faint bridge. Player and opponent Pokemon now queue
  their held Stadium faint animation after the engine HP bar reaches zero;
  older Dramaless Shape installs safely keep their normal faint behavior.

## 1.0.6 - 2026-08-09

- Added a bounded persistent animation diagnostic log. It records battle and
  move events, Stadium/delegated presentation choice, asset fallback, hit
  reaction, draw-fallback, and cancellation outcomes.
- Added **EXPORT ANIMATION LOG** to the mod options menu. Windows opens a
  save dialog; Android opens the system document picker through a dedicated
  export bridge that never reuses the pending game-save export file.

## 1.0.5 - 2026-08-09

- Released the screen-compositor correction for desktop borderless mode.
  Screen-wide washes, flashes, and tiled fields now cancel the staged battle
  transform on the game layer and replay seamlessly into each outer margin,
  while Pokemon-anchored effects remain attached to their projected targets.
- Added regression coverage for the borderless margin pass and non-borderless
  full-screen rendering paths.

## 1.0.4 - 2026-08-09

- Added a validated persistent announcer cache. A personalized local package
  imports its 823 clips into save data once; later voice-free updates reuse the
  cached audio automatically.

## 1.0.3 - 2026-08-09

- Fixed all screen-wide move layers on Android and windowed desktop layouts.
  Washes, partial fields, scrolling tiles, and flashes now always cancel the
  staged battle camera transform; only extending effects into desktop margins
  remains borderless-specific. This fixes Surf, Blizzard, Toxic, Psychic,
  Confusion, Light Screen, Reflect, Earthquake, Explosion, Flash, Mist, Haze,
  and generic screen effects rendering as a reduced center rectangle.
- Expanded the screen-effect regression test to exercise every shared
  full-screen primitive and dedicated screen program outside borderless mode.

## 1.0.2 - 2026-08-09

- Added in-game **STADIUM ROM** import/replace and **REFRESH FX CACHE** action
  rows. Android uses the system document picker; refresh forces a rebuild even
  when an existing cache marker is valid.
- Added an Attack Speed setting from 100% down to 0% in 10% steps. Stadium
  VFX, impact reactions, sound events, and attack-camera motion share the
  slowed fractional clock; 0% safely uses the normal Gen1 presentation.
- Fixed the 1.0.1 cache regression that masked missing-ROM, stale-cache, and
  integrity errors as only "effect cache is unavailable." Missing cartridge
  textures now use procedural Stadium FX without disabling move timelines or
  attack cameras, and logs retain the actionable cache or ROM diagnosis.
- Fixed first-run cache creation on Gen1Recomp builds that create only one
  directory level per call. Every parent is now created and checked before
  extraction, instead of silently attempting to write into a missing tree.

## 1.0.1 - 2026-08-08

- Made cosmetic screen overlays and Blizzard snow textures optional so a
  stale entry cannot disable the move's core Stadium presentation.
- Added integrity-checked loading of required cache subsets when unrelated
  cosmetic cache entries are missing or corrupt.
- Changed draw-error fallback to restore graphics state, release camera and
  overlay ownership, and let Gen1 rendering resume on the following frame
  instead of layering it over a partially drawn Stadium frame.
- Added a nine-second on-screen fallback banner naming the affected move and
  failure reason for cache, asset, and renderer errors.
- Added regression coverage for incomplete caches, optional-asset gates, and
  mid-draw renderer failures.

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
