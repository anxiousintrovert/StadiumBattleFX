# Pokemon Stadium 1 fidelity pass

Version 1.0.0 carries forward the curated fidelity layer above the complete
165-move portable roster and adds source-calibrated controller timing for the
remaining moves. It uses only data traced from Pokemon Stadium (USA) v1.0.

## Calibrated roster

The first pass covers 24 visually prominent moves:

- Fire: Ember, Flamethrower, Fire Blast
- Water and ice: Water Gun, Hydro Pump, Surf, Ice Beam, Blizzard
- Beams: Psybeam, Hyper Beam, Solar Beam
- Grass and drain: Absorb, Mega Drain, Razor Leaf
- Electric: Thunderbolt, Thunder
- Fields and status: Earthquake, Toxic, Psychic, Confuse Ray
- Self and screens: Recover, Light Screen, Reflect
- Large event: Explosion

Each profile stores a Stadium program family, variant, impact tick, duration,
and exact required assets. Runtime timing uses Gen1Recomp's 60 Hz animation
clock while preserving Stadium's relative primary/impact ordering.

## Exact resource cache

`lib/StadiumAssets.lua` declares 36 bounded ranges from 14 Stadium battle
effect archive members. Every range records its runtime slot, decompressed
fragment offset, N64 texture format, dimensions, frame count, and byte count.
The integration test verifies all pointers and bounds against the supported
cartridge. Only the declared ranges are cached; compressed members and full
decompressed fragments are discarded.

The renderer uses colored RGBA16 resources directly and tints neutral I4/IA8
masks according to Stadium's program role. Full-screen fields are tiled in the
160x144 Gen1 animation layer so Dramaless Shape can apply its live staged
projection exactly once.

## Calibration limits

This pass is source-calibrated, not frame-perfect. Static source establishes
texture identity, native dimensions, program reuse, relative scheduling, and
canonical particle footprints. Final on-screen scale still depends on the
live camera depth, species normalization, and capture-specific timing.
Native Stadium comparison captures remain necessary before calling any move
pixel-accurate.

## Calibration tiers

The merged runtime registry exposes a `calibration` label so implementation
coverage cannot be mistaken for fidelity evidence:

- `stadium1-source-calibrated`: 24 cartridge-textured profiles whose assets,
  dispatch families, and relative schedules are supported by Stadium source
  and ROM ranges;
- `stadium-dispatch-traced`: 19 earlier dedicated move/family programs backed
  by decoded dispatch and resource metadata;
- `stadium-timing-calibrated-v1`: the other 122 entries. Their exact primary,
  alternate, impact, and resource sequences choose source-matched cartridge
  textures and canonical 24/32/64-pixel footprint classes. A generated timing
  pass also preserves shared controller cursor changes, explicit completion
  markers, final static emissions, and defender-effect envelopes. Programs
  without a static controller signal retain a labelled dispatch-archetype
  fallback rather than pretending source contains an exact global hit tick.

The timing-calibrated tier now gives slash, punch, kick, grapple, projectile, beam,
storm, field, status, screen, heal, transform, and explosion families their
own impact/tail envelopes. Promotion into the source-calibrated tier still
requires native captures or equivalent controller evidence for exact emission
ticks, transforms, colors, blend modes, and completion markers.
