# StadiumBattleFX 1.0.3 — full-screen effect repair

This update fixes screen-wide move fields on Android and in windowed desktop
layouts. The problem was most visible with Surf, which could render only in
the active battle-camera rectangle.

## Fixed

- Screen washes, partial fields, scrolling texture layers, and flashes now
  cancel the staged battle camera transform in every video mode.
- Surf, Blizzard, Toxic, Psychic, Confusion, Light Screen, Reflect,
  Earthquake, Explosion, Flash, Mist, Haze, and generic screen effects cover
  the full battle layer again.
- Borderless desktop mode still extends these layers seamlessly into the outer
  margins after the game frame is composed.

## Downloads

- `STADIUM_BATTLE_FX-1.0.3.zip` — voice-free runtime package.
- `StadiumBattleFX-Announcer-Builder.exe` — optional local builder for a
  personalized announcer package made from the player's own compatible ROM.

## Upgrading

Install the 1.0.3 ZIP through Gen1Recomp's mod manager. If you use a private
announcer package, rebuild it with the same 1.0.3 ZIP using the included
announcer builder; do not install the voice-free and personalized packages at
the same time.
