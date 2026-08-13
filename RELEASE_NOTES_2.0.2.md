# StadiumBattleFX 2.0.2

## Wide battle layout crash fix

- Fixed `WideBattle.lua:293: attempt to index field 'steps' (a nil value)`
  when a Stadium move begins with Gen1Recomp's BATTLE LAYOUT set to WIDE.
- Added a compatibility view of the wrapped animation frame without exposing
  or modifying Gen1Recomp's animation internals.
- Centred SBFX's classic 160x144 effect coordinates inside the 304x144 wide
  battle surface while preserving direct world-surface particle projection.

Install `STADIUM_BATTLE_FX-2.0.2.zip` through Gen1Recomp's mod manager. This
is a public, ROM-free package. Existing locally generated Stadium effect,
model, arena, and announcer caches remain compatible and need no rebuilding.
