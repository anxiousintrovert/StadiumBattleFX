# Compatibility roadmap

This file is the durable project record for StadiumBattleFX (SBFX)
compatibility targets and future upstream API pull requests.

## Scope

Compatibility is pairwise: each mod below versus SBFX. Compatibility or
incompatibility among the third-party mods is outside SBFX's scope.

Versions are the upstream versions inspected on 2026-08-14. Recheck the
upstream repository or release before opening a pull request.

## Recorded compatibility targets

| Mod | Upstream identity inspected | Current SBFX compatibility | Future upstream/API pull-request target |
| --- | --- | --- | --- |
| [Followers EX](https://github.com/masterwebx/gen1recomp-followers-ex) | `FOLLOWERS_EX` 1.0.19; commit `10df9204cba0128c68bef8a6e406f75b6131a836` | Optional dependency recorded. Preserve its follower lifecycle and input/options hooks across battle entry and exit. | No Battle Presentation provider is currently needed. Propose a stable follower/encounter lifecycle signal only if regression testing reveals a private-hook dependency. |
| [Kanto Dynamic Weather](https://github.com/1-Camp0-1/Kanto-Dynamic-Weather) | `kanto_dynamic_weather` 1.0.3; commit `e9e2ddef22596157fb4c5f919e3ab18718b52265` | Optional dependency recorded. SBFX does not claim ownership of its overworld atmosphere renderer. | No SBFX provider slot is currently needed because the mod is overworld-only. If battle weather is desired later, propose an explicit effects/overlay registration contract rather than coupling to renderer internals. |
| [Battle Art](https://github.com/absol89/DramaticShapeVoxelMod) | `BATTLE_ART_VOXEL_FORK` 1.9.5; release/tag `1.9.5` | Its merged `exports.battleStage` API v1 is the stable read-only compatibility surface used by SBFX 2.1.2 and later. When both mods are enabled, its SBFX provider exposes the voxel-map arena, native cards, placed camera, projected HUD, and exit fade as independent choices. SBFX generic stages are suppressed for an active Battle Art map while Stadium special arenas remain available. | [PR #10](https://github.com/absol89/DramaticShapeVoxelMod/pull/10) registers the Battle Presentation API v1 components and calls `drawActors(world)`, allowing player-selected mix-and-match models, HUD, effects, voices, and transitions. |
| [Dramatic Shape](https://github.com/scottcandy34/DramaticShapeVoxelMod-latest) | `DRAMATIC_SHAPE` 1.8.2; commit `7ef3dd55b427433643f0c0ffeeecba5f910c36b6` | The read-only Shape-family bridge detects its staged battle and yields arena, models, camera, and trainer portrait while retaining SBFX effects and audio. | [PR #2](https://github.com/scottcandy34/DramaticShapeVoxelMod-latest/pull/2) registers its voxel-map arena through Battle Presentation API v1 and calls `drawActors(world)` so models and other features remain independently selectable. It rejects the legacy disc arena and avoids relying on the stale exported version string. |
| [Potato Voxel](https://github.com/ShaneMcGovernIE/potato_voxel) | `potato_voxel` 1.6.2-brick.17; PR branch commit `a4416a0` | PotatoVoxel registers its map arena only when SBFX's Battle Presentation API is present. SBFX automatically prefers that arena for ordinary battles, while retaining native Stadium venues for Gyms, the Elite Four, and the Champion. Its arena, models, effects, camera, and other presentation components remain independently selectable in SBFX. | [PR #41](https://github.com/ShaneMcGovernIE/potato_voxel/pull/41) is open. The provider uses API v1 and `drawActors(world)`, rejects the legacy disc arena, and stays inactive unless both mods are enabled. |
| [Wild Skies](https://github.com/shanehudson-gen1recomp-mods/wild_skies/releases) | `wild_skies` release v1.10.0, published 2026-08-13 | Optional dependency recorded. Preserve encounter start, battle completion, run, and catch return paths. | Propose stable encounter provenance in the battle context (for example `sourceMod` and `sourceId`) so SBFX providers can react without inspecting private encounter hooks. |
| [Wilds of Kanto / Overworld Spawn Mod](https://github.com/YoDrehDenSwagAuf/overworld-spawn-mod) | `overworld_wild_spawns` 2.1.0; commit `77ce8fc2bac106de5ddca29256ad1415f49b9f29` | Optional dependency recorded. Preserve encounter start, battle completion, run, and catch return paths. | Propose the same stable encounter-provenance fields as Wild Skies, plus documented battle-return lifecycle semantics. |

## Gen1Recomp sandbox compatibility

Gen1Recomp 0.1.86 runs every mod-authored chunk in a restricted environment
that denies raw `love.filesystem`, `love.system`, `io`, and host-path access.
SBFX 2.1.5 treats cartridge conversion as an external build step: the official
ZIP remains ROM-free, the personalized builder writes derived `cache/` files,
and the runtime consumes those files read-only through `mod:read`.

The runtime must not reintroduce ROM picker, cache refresh, or import action
rows until Gen1Recomp provides a scoped binary import API. `mod.storage` remains
appropriate for small playthrough data and diagnostics, but personalized
binary cache assets are package-scoped so they are reusable across saves.

## Existing SBFX integration surface

The public integration contract is documented in
[`BATTLE_PRESENTATION_API.md`](BATTLE_PRESENTATION_API.md). Its component slots
are `arena`, `models`, `animations`, `camera`, `effects`, `announcer`, `hud`,
`overlay`, and `transitions`.

The public isolated actor contract is documented in
[`STADIUM_MODEL_API.md`](STADIUM_MODEL_API.md). It exposes explicit Stadium 1,
Stadium 2, and selected-model actors for consumers that cannot use the battle
host's `drawActors(world)` callback.

Use that API for presentation ownership where it fits. Encounter origin and
overworld lifecycle data should be added deliberately to the public context or
to a separately documented lifecycle contract; it should not be inferred from
another mod's private tables.

## Pull-request checklist

1. Reinspect the upstream default branch or latest release and record the exact
   manifest ID and version.
2. Confirm the problem occurs with only SBFX and that one mod enabled.
3. Choose the smallest public contract: presentation provider, encounter
   metadata, or lifecycle event.
4. Add a regression test in SBFX before or alongside the upstream PR.
5. Link the upstream PR here and update the compatibility status after merge.

## Upstream PR ledger

| Upstream | Pull request | Result | SBFX follow-up |
| --- | --- | --- | --- |
| Battle Art | [absol89/DramaticShapeVoxelMod#8: Expose staged battle compatibility API](https://github.com/absol89/DramaticShapeVoxelMod/pull/8) | Merged 2026-08-14 as `e82a3bc2ea45858f612ab55b482412a231bce7e1`. Adds the read-only `exports.battleStage` API v1. | Completed in the current SBFX working tree: `BattleArtCompat` prefers `exports.battleStage` and retains `exports.lib.require("OverworldBattle")` only for older Battle Art releases. |
