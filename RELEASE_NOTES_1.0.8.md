# StadiumBattleFX 1.0.8 - log export feedback

## Fixed

- **EXPORT ANIMATION LOG** now reports its outcome in the mod options on
  Windows: `SAVED`, `CANCELLED`, or `FAILED`.
- Windows write and close failures are handled safely and recorded in the
  persistent StadiumBattleFX diagnostic log instead of being silently treated
  as success.

## Reporting an issue

After selecting **EXPORT ANIMATION LOG**, confirm the row reads `SAVED`, then
attach the selected `StadiumBattleFX-log.txt` to your bug report. If it reads
`FAILED`, include the action you took and the folder you selected.
