# Discord post 1/2 — performance and release

# StadiumBattleFX 2.1.2 is out!

This update combines runtime performance fixes with expanded pairwise mod compatibility.

**Download:** [StadiumBattleFX 2.1.2](https://github.com/anxiousintrovert/StadiumBattleFX/releases/tag/v2.1.2)

**Performance fixes**
- Stadium 2 model-pack availability is memoized instead of repeatedly probing the entire imported roster.
- Per-frame model-source option and availability lookups have been removed.
- Resident Stadium 2 hybrid models no longer rebuild cache keys or reshuffle the importer LRU twice per frame.
- Texture wrap modes are only applied when they actually change, including normal, additive, and shadow passes.
- Imports, cache writes, clears, and finalization still invalidate cached availability correctly.

**Install/update**
1. Download `STADIUM_BATTLE_FX-2.1.2.zip` from the release.
2. Install it through Gen1Recomp's mod manager and enable StadiumBattleFX.
3. Existing private Stadium/Stadium 2 caches and announcer data remain compatible.

The public ZIP is ROM-free. Supply your own legally obtained Stadium ROMs when using imported assets.

---

# Discord post 2/2 — compatibility and settings

**Pairwise compatibility baselines**
- Battle Art Voxel Fork 1.8.8
- Dramatic Shape 1.8.2
- PotatoVoxel 1.5.2
- Followers EX 1.0.19
- Kanto Dynamic Weather 1.0.3
- Wild Skies 1.10.0
- Wilds of Kanto 2.1.0

This means each listed mod is supported with StadiumBattleFX. It does **not** claim that the third-party mods are compatible with one another.

**Settings**
- Enable StadiumBattleFX normally.
- Battle Art, Dramatic Shape, or PotatoVoxel: set that mod's **3D-BTL** option **ON** to keep its voxel arena/cards/camera while Stadium move effects and optional announcer continue. No SBFX provider setting is required.
- Set **3D-BTL OFF** if you want SBFX's selected arena, models, camera, trainer portraits, HUD, and transitions instead.
- Followers EX, Kanto Dynamic Weather, Wild Skies, and Wilds of Kanto need no special SBFX setting. Configure their own options however you prefer and follow their declared dependencies.

Battle Art 1.8.8 is now consumed through its approved public `battleStage` API. Older Battle Art releases retain the compatibility fallback.
