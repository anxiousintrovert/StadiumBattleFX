# StadiumBattleFX 2.0.0 is out!

This is the biggest SBFX release yet, with everything added since 1.1.2.

**Standalone Stadium battles:** SBFX now owns Stadium model extraction, animation, cameras, attachments, hit/faint/recall timing, rendering, and composition.

**Dependency change:** Dramaless Shape is no longer required. It is now an optional provider for voxel arenas and voxel 2D cards, but you must update it to **2.0+**; older versions conflict with SBFX 2.0.

**Battle Presentation API 1:** mods can provide independently selectable arenas, models, animations, cameras, effects, announcers, HUDs, overlays, and transitions. Providers are safe and player-selected. Official Battle Cinematics 0.7.96 supports cooperative camera ownership.

**Arenas:** ROM-derived rooms for Brock through Giovanni, the Elite Four, and Champion; four portable themes for ordinary battles; optional Dramaless voxel arenas; and full-color Stadium trainer portraits.

**ROM Importer:** validated `.z64`/`.v64`/`.n64` import/replace works on desktop and Android. Effects, arenas, 151 model packs, diagnostics, and the optional 823-clip announcer bank use sandboxed storage with a unified cache screen.

**Moves & announcer:** all 165 move dispatches, 193 native effect programs, 671 scheduler emissions, and the full 24,915-row body-sync matrix are included. Announcer lines now sync to visible actions, with corrected event families and trainer-idle calls.

Major fixes include borderless white blocks, opaque canvas layering, Gen3 Battle UI hooks, sprites flashing over 3D models, Waterfall coverage, and Thunder Shock visibility.

Downloads include the public ROM-free mod and optional local announcer patchers for **Windows** and **SteamOS/x86-64 Linux**.

Huge thanks to @Stahltier for all the help and close collaboration between StadiumBattleFX and Dramaless Shape!

Full notes/downloads: https://github.com/anxiousintrovert/StadiumBattleFX/releases/tag/v2.0.0
