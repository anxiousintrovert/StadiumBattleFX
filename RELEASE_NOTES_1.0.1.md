# StadiumBattleFX 1.0.1 — Animation fallback repair

This maintenance release fixes reports of old Gen1 attack effects replacing
or appearing on top of the new Stadium presentations while camera and model
animation continued to work.

## Fixed

- Cosmetic screen overlays no longer gate the complete move presentation.
- Valid required textures can load from an otherwise incomplete private cache.
- Blizzard retains procedural snow when its optional texture entries are
  unavailable.
- A custom-rendering error no longer draws the Gen1 renderer over the same
  partially completed frame. Graphics, camera, and overlay state are restored,
  and the already-running Gen1 animation takes over on the following frame.
- Cache, asset, and renderer failures display a temporary on-screen banner
  naming the affected move and reason.

## Upgrading

Install `STADIUM_BATTLE_FX-1.0.1.zip` with Gen1Recomp's mod manager. If the
displayed version remains old, remove every existing StadiumBattleFX / Stadium
Attack Animations copy, restart Gen1Recomp, and install the ZIP again.

The private effect cache does not need to be deleted. Version 1.0.1 validates
required cache entries independently and continues to rebuild the complete
cache when the player's supported Stadium ROM is available.

## Downloads

- `STADIUM_BATTLE_FX-1.0.1.zip` — voice-free mod for direct installation.
- `StadiumBattleFX-Announcer-Builder.exe` — optional local Windows tool that
  builds a personalized announcer pack from the player's own supported ROM.
- `sha256sums.txt` — checksums for both public release files.
