# Battle Cinematics compatibility

Compatibility is verified against the official
`Battle_Cinematics-v0.7.96.zip` release asset (SHA-256
`392acff9905fc60ae12cc25b98dd80e5285c3ea209fa6ee44097c9e89a925659`).
The upstream package is inspected read-only and is not copied into or modified
by StadiumBattleFX.

## Official 0.7.96 adapter

Battle Cinematics 0.7.96 predates StadiumBattleFX API 1. It discovers one of
three Shape-family backends, obtains `BattleCam` through that mod's
`exports.lib` loader, and wraps `BattleCam.rig`. It exports only `version` and
`activity`; it does not register a camera provider or publish the newer
phase-ownership protocol.

SBFX supports that package from its own side. At `mods.loaded`, SBFX discovers
the same supported backend and verifies the marker BC places on the wrapped
`BattleCam`. SBFX registers the final camera as `BATTLE_CINEMATICS:camera` and
can consume its pose for Stadium-owned or voxel-map arenas. The adapter advances
the shared camera only when the active arena provider has not already done so.

Because BC 0.7.96 itself requires a supported Shape-family camera backend, that
backend remains part of a 0.7.96 installation. It need not own SBFX's arena,
models, effects, or any other presentation slot.

## Phase-scoped ownership

Newer Battle Cinematics releases can remain independent of Stadium's provider
API. A read-only `cameraOwnership()` protocol-1 export declares
configuration-level claims for `passive`, `intro`, `attack`, and `faint`.

Before starting its optional attack director, SBFX queries
`ownership.claims.attack`. It repeats the check while applying each shot so a
late claim releases the active SBFX camera and returns the upstream camera
unchanged. A true claim affects only SBFX camera direction; models, move VFX,
hit reactions, audio, and the rest of the presentation continue normally.
False, absent, failed, or unknown protocols retain normal SBFX behavior.

Official 0.7.96 has no ownership export, so its two optional attack-camera
settings still require manual coordination. The SBFX implementation is ready
for the protocol without requiring either project to change the other's files
or settings.

A later API-native Battle Cinematics release may instead register a normal
camera provider through
`STADIUM_BATTLE_FX.exports.battles:registerComponent(...)` and implement
`claim(context, phase)` plus `shot(context, phase, progress, base, arena)`.

## Compatibility zoom

`BC ZOOM OUT` is an opt-in optical adjustment with OFF, 10%, 25%, 35%, and 50%
choices. It scales visible frame height with
`2 * atan(tan(fov / 2) * (1 + amount))`, preserving Battle Cinematics' eye and
focus while showing more of the arena.
