# Architecture

> **2.0 note:** This document describes the original 1.x portable-effects
> architecture and is retained as implementation history. StadiumBattleFX 2.0
> owns models, arenas, projection, and provider dispatch. Use
> [`BATTLE_PRESENTATION_API.md`](BATTLE_PRESENTATION_API.md) as the normative
> integration contract; do not implement new code against 1.x Dramaless seams.

The runtime keeps the user's cartridge, the private derived cache, and the
battle renderer as separate layers:

```text
local mod package: baseroms/baserom.z64|n64|v64
                 |
                 v
  byte-order-aware validated Stadium reader
                 |
                 v
 fourteen bounded battle-effect archive members
                 |
                 v
 36 exact texture ranges + v3 checksums
                 |
                 v
 first-run stepped cache screen / later cache preload
                 |
                 v
 party move registry -> delegating AnimPlayer adapter
```

`lib/StadiumAssets.lua` recognizes the three N64 byte orders, validates the
32 MiB USA v1.0 cartridge by its N64 header CRCs, decompresses only members
needed by the declared asset table and retains only its 36 bounded texture
ranges (about 157 KiB). The first-run API (`pending`, `begin`, `step`) performs
one member, scoped-storage write, texture upload, or marker write per update. `preload` handles the
small validated-cache path and remains a synchronous fallback if a battle is
created before the overworld can offer the screen.

`lib/EffectCacheScreen.lua` is an opaque 160x144 Gen1Recomp state. It pauses
the overworld while the stepped job is active, displays measured work-unit
progress, and retires automatically. It checks Dramaless Shape through
`mod.find` and the companion's exported `StadiumInstall` state, deferring until
that mod's own model extraction is complete. It does not access either mod's
files.

`lib/effects/MoveSpecs.lua` merges all 165 moves with their traced Stadium
primary/alternate/impact opcodes and resource members. The generated
`StadiumNativePrograms.lua` additionally carries all 193 native programs and
671 normalized scheduler emissions; `StadiumNativeInterpreter.lua` executes
their exact cursor, interval, repeat, alternate, and impact-channel timing.

`lib/effects/StadiumFxPlayer.lua` wraps Gen1Recomp's battle `AnimPlayer`.
Unsupported moves and any move with a missing asset delegate unchanged. A
custom move keeps the original player running as the sound-event clock while
suppressing its Game Boy sprites and screen effects.
`lib/effects/StadiumAuthenticRenderer.lua` composes exact cached textures into
beam, elemental, full-screen, status, recovery, barrier, quake, and explosion
programs for the curated fidelity roster. Other shapes use the procedural
renderer, but their births/repeats/batches now come from the normalized native
scheduler rather than fixed portable loops. Growl and Splash claim the visual
layer only while Dramaless Shape reports that a Stadium model is showing.

`lib/AttackCinematics.lua` is the independent move-time camera layer. With the
built-in model provider it reads the active species/move row's exact camera
selectors and controller delay; reusable windup/travel/impact/recovery
timelines are now fallback-only. The player updates camera, VFX, hit reaction,
and the half-rate native body sampler from one authoritative move tick.

Companion data and caches are read-only. The optional attack director composes
with Dramaless Shape's in-memory camera function, but Stadium Attack Animations
never writes the Dramaless Shape installation, settings, or its
`dramatic_shape/stadium/` model cache.
