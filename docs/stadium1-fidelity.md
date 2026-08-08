# Pokemon Stadium 1 fidelity pass

Version 0.7.0 adds a curated fidelity layer above the complete 165-move
portable roster. It uses only data traced from Pokemon Stadium (USA) v1.0.

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
