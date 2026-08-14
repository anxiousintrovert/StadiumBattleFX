# StadiumBattleFX 2.1.5 is out — required Gen1Recomp sandbox fix

**Download:** https://github.com/anxiousintrovert/StadiumBattleFX/releases/tag/v2.1.5

The newest Gen1Recomp release now runs mods in a restricted sandbox. Previous
StadiumBattleFX builds tried to use `love.filesystem` while loading the Stadium
cache/import code, so the mod was rejected before it could start—even when it
was the only mod enabled.

**What changed**
- Removed all runtime `love.filesystem`, `love.system`, `io`, and host-path use.
- Removed the in-game Stadium ROM import, Stadium 2 ROM import, and cache-refresh
  settings because the new sandbox intentionally cannot open arbitrary files.
- Removed the obsolete filesystem permission from the manifest.
- Runtime assets are now read safely from the installed package with `mod:read`.
- The external Personalized Pack Builder now performs all Stadium 1 caching,
  optional Stadium 2 model caching, and announcer extraction before installation.

**How to install**
1. Download and install `STADIUM_BATTLE_FX-2.1.5.zip` for the safe public,
   ROM-free version.
2. For cartridge-backed models, stages, effects, portraits, and announcer audio,
   also download `StadiumBattleFX-Announcer-Builder-windows.zip`.
3. Run the builder, select your legally obtained Pokemon Stadium (USA) v1.0 ROM,
   optionally select Pokemon Stadium 2 (USA), select the public 2.1.5 ZIP, and
   build a personalized ZIP.
4. Install the personalized ZIP instead of the public ZIP. Do not enable both;
   they use the same mod ID.

The builder never puts either ROM into its output and never uploads anything.
Personalized packages contain derived cache/audio data and should not be
redistributed. Both public and personalized packages were tested against the
exact Gen1Recomp 0.1.86 production loader with zero load errors.
