# Architecture

The runtime keeps the user's cartridge, the private derived cache, and the
battle renderer as separate layers:

```text
flat baseroms/*.z64|*.n64|*.v64
                 |
                 v
  byte-order-aware validated Stadium reader
                 |
                 v
 five bounded battle-effect archive members
                 |
                 v
 eight exact texture ranges + v2 checksums
                 |
                 v
 first-run stepped cache screen / later cache preload
                 |
                 v
 party move registry -> delegating AnimPlayer adapter
```

`lib/StadiumAssets.lua` recognizes the three N64 byte orders, validates the
32 MiB USA v1.0 cartridge by its N64 header CRCs, decompresses only members
`00`, `0B`, `0F`, `16`, and `1C`, and retains only the eight declared texture
ranges. The first-run API (`pending`, `begin`, `step`) performs one member,
file write, texture upload, or marker write per update. `preload` handles the
small validated-cache path and remains a synchronous fallback if a battle is
created before the overworld can offer the screen.

`lib/EffectCacheScreen.lua` is an opaque 160x144 Gen1Recomp state. It pauses
the overworld while the stepped job is active, displays measured work-unit
progress, and retires automatically. It checks Dramaless Shape through
`mod.find` and the companion's exported `StadiumInstall` state, deferring until
that mod's own model extraction is complete. It does not access either mod's
files.

`lib/effects/MoveSpecs.lua` maps the fourteen saved-party moves to their
traced Stadium primary/impact opcodes and resource members. It also records
the provisional portable duration and primary-to-impact offset.

`lib/effects/StadiumFxPlayer.lua` wraps Gen1Recomp's battle `AnimPlayer`.
Unsupported moves and any move with a missing asset delegate unchanged. A
custom move keeps the original player running as the sound-event clock while
suppressing its Game Boy sprites and screen effects. Exact cached textures are
used where traced; the remaining wind, speed, string, psychic, and screen
shapes are procedural first-pass renderers. Growl and Splash claim the visual
layer only while Dramaless Shape reports that a Stadium model is showing.

`lib/AttackCinematics.lua` is the independent move-time camera layer. It
lazily composes with Dramaless Shape's `BattleCam.rig`, leaves canonical camera
queries unchanged, and selects a reusable windup/travel/impact/recovery
timeline from each move spec. Map stages use optical focus/FOV changes with a
fixed eye; the empty-disc stage also allows a small orbit. The player updates
the director from the same authoritative move tick used by the VFX renderer.

Companion data and caches are read-only. The optional attack director composes
with Dramaless Shape's in-memory camera function, but Stadium Attack Animations
never writes the Dramaless Shape installation, settings, or its
`dramatic_shape/stadium/` model cache.
