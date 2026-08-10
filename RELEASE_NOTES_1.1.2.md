# StadiumBattleFX 1.1.2

## Fix

- Stadium effect-cache scans now verify the complete normalized ROM MD5.
  An unsupported or modified Pokemon Stadium ROM stops the build with
  `cache failed incorrect version or rom`.
- The Windows announcer decoder now targets the baseline x64 instruction set,
  avoiding `STATUS_ILLEGAL_INSTRUCTION` failures on compatible older CPUs.
