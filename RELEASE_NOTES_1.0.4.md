# StadiumBattleFX 1.0.4 — persistent announcer cache

This patch makes locally generated Pokemon Stadium announcer audio survive
ordinary StadiumBattleFX updates.

## Changed

- A personalized announcer package now imports its validated 823 clips into a
  private save-data cache on first use.
- Voice-free updates automatically use that cache, so rebuilding the personal
  announcer ZIP is no longer required for every StadiumBattleFX update.
- Imports are complete-pack validated and finalized with a marker written last;
  interrupted imports are rejected instead of being used as incomplete audio.
- If private save storage is unavailable, the personalized package still plays
  directly as before.

## Upgrading

1. If you already use a personalized announcer package, install and launch it
   once to import the voices, then install this 1.0.4 voice-free ZIP normally.
2. For a new setup, build and launch one personalized package from your own
   compatible Pokemon Stadium ROM. Later updates can use the normal voice-free
   package.

Do not redistribute personalized voice packages or the private cached audio.

## Downloads

- `STADIUM_BATTLE_FX-1.0.4.zip` — voice-free runtime package.
- `sha256sums.txt` — SHA-256 checksum for the runtime package.
