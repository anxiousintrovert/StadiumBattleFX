# StadiumBattleFX 1.0.9 - announcer battle selector

## Added

- **ANNOUNCER BATTLES** in the SBFX options menu. Choose one of:
  - **GYM / ELITE 4 / CHAMPION** — the existing default behavior.
  - **ALL TRAINER BATTLES** — adds ordinary trainer battles.
  - **ALL BATTLES** — also adds wild Pokemon battles.

The existing **STADIUM ANNOUNCER** setting remains the master on/off switch.
Non-boss battles use Pokemon and move calls without a Gym Leader entrance
line, since Stadium has no trainer-specific intro for them.

- Added occasional battle-flow commentary. It only begins after several moves
  and a quiet gap, and any important battle announcement stops it immediately.
