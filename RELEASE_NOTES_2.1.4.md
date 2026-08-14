# StadiumBattleFX 2.1.4

This compatibility update fixes a startup failure reported by players using
newer Gen1Recomp builds.

## Fixed

- StadiumBattleFX no longer accesses Lua's mutable `package.preload` table
  while starting its embedded Stadium 2 importer.
- The importer now routes its private module names through StadiumBattleFX's
  isolated loader, preserving the existing module boundaries without relying
  on globals that may be absent from the mod sandbox.
- A regression test now boots the complete mod with `package = nil`.

## Installation

Install `STADIUM_BATTLE_FX-2.1.4.zip` through Gen1Recomp's mod manager. Existing
Stadium caches, imported Stadium 2 models, settings, and announcer data remain
compatible. The public ZIP contains no ROM-derived content.
