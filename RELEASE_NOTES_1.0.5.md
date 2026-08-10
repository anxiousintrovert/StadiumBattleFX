# StadiumBattleFX 1.0.5 — borderless screen effects

This patch delivers the full-screen compositor correction for borderless
desktop play.

## Fixed

- Screen-wide washes, flashes, and scrolling fields now fill the game layer
  without inheriting the staged battle-camera transform.
- In desktop borderless mode, those effects continue into all four outer
  margins at the same tile scale and scrolling phase.
- Beams, particles, rings, and other Pokemon-anchored effects remain attached
  to their projected Pokemon rather than being replayed as screen overlays.

## Downloads

- `STADIUM_BATTLE_FX-1.0.5.zip` — voice-free runtime package.
- `sha256sums.txt` — SHA-256 checksum for the runtime package.
