# StadiumBattleFX 2.1.3

This small API update lets other Gen1Recomp mods use StadiumBattleFX's
Pokemon Stadium and Pokemon Stadium 2 actors without importing private SBFX
modules. It retains all performance and compatibility fixes from 2.1.2.

## Stadium Model API v1

- `STADIUM_BATTLE_FX.exports.models` is now a public, versioned contract.
- Mods can acquire isolated Stadium 1, Stadium 2, or player-selected actors.
- Actors expose animation playback, move synchronization, hit/faint reactions,
  world geometry, attachment tags, drawing, compatible shadow casting, and an
  idempotent release lifecycle.
- The renderer helper restores shader, depth, cull, blend, and color state on
  successful or failed callbacks.
- No ROM bytes are exported or added to the public package.

For Battle Presentation arena providers, the host-supplied
`drawActors(world)` callback remains the preferred integration. It honors the
player's **BTL MODELS** choice and enables arena/model mix-and-match.

## Shape-family API work

Compatibility-focused arena-provider pull requests have been submitted for
Battle Art 1.8.8, Dramatic Shape 1.8.2, and PotatoVoxel 1.5.2. Each patch
contributes only its voxel-map arena and leaves models, effects, camera, HUD,
announcer, overlays, and transitions independently selectable in SBFX.

## Installation

Install `STADIUM_BATTLE_FX-2.1.3.zip` through Gen1Recomp's mod manager. Existing
private Stadium caches and announcer data remain compatible. The public ZIP
contains no ROM-derived content.
