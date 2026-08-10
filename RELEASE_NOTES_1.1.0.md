# StadiumBattleFX 1.1.0

## Highlights

- Stadium attack effects now honor both Dramaless Shape attachment tags. A
  secondary non-sentinel tag receives its own localized effect pass.
- Pokemon react at the actual visual impact: neutral and super-effective hits
  request Stadium's held hit animation, while resisted hits stay idle.
- **ANNOUNCER BATTLES** can extend local announcer audio from the default Gym,
  Elite Four, and Champion battles to all trainer battles or every battle.
- Added low-priority battle-flow commentary that only plays in quiet gaps and
  yields immediately to important battle calls.

## Fixes and tools

- Windows animation-log export now accurately reports saved, cancelled, or
  failed status.
- The Windows Announcer Builder is supplied as an inspectable application
  folder ZIP, with a SHA-256 checksum.
