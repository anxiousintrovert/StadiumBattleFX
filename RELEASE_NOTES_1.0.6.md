# StadiumBattleFX 1.0.6 - diagnostic log export

This update adds bug-report diagnostics for every Stadium animation path.

## Added

- A persistent, bounded log of battle/move events, animation selection,
  texture fallback, hit reactions, draw failures, and cancellations.
- **EXPORT ANIMATION LOG** in mod options. On Windows it opens a Save dialog;
  on Android it opens the system document picker.

Android log export requires a Gen1Recomp build with `love.system.exportFile`.
The bridge exports a dedicated staged log file and never uses or overwrites
the pending game-save export file.
