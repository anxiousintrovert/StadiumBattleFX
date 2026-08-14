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
| [Dramatic Shape](https://github.com/scottcandy34/DramaticShapeVoxelMod-latest) | `DRAMATIC_SHAPE` 1.8.2; commit `7ef3dd55b427433643f0c0ffeeecba5f910c36b6` | The read-only Shape-family bridge detects its staged battle and yields arena, models, camera, and trainer portrait while retaining SBFX effects and audio. | High-priority API PR candidate: register its arena/models/camera/HUD/transitions through SBFX Battle Presentation API v1, or expose an equivalent stable presentation surface. Do not rely on its stale exported version string; use loader/manifest identity. |
| [Potato Voxel](https://github.com/ShaneMcGovernIE/potato_voxel) | `potato_voxel` 1.5.2; commit `0e4cd1b417a19cd082370b76180ee0238c188717` | The read-only Shape-family bridge detects its staged battle and prevents duplicate arena/model/camera ownership. | High-priority API PR candidate: use the same reusable Battle Presentation provider registration proposed for Dramatic Shape. Use loader/manifest identity rather than the mod's exported version string. |
| [Wild Skies](https://github.com/shanehudson-gen1recomp-mods/wild_skies/releases) | `wild_skies` release v1.10.0, published 2026-08-13 | Optional dependency recorded. Preserve encounter start, battle completion, run, and catch return paths. | Propose stable encounter provenance in the battle context (for example `sourceMod` and `sourceId`) so SBFX providers can react without inspecting private encounter hooks. |
| [Wilds of Kanto / Overworld Spawn Mod](https://github.com/YoDrehDenSwagAuf/overworld-spawn-mod) | `overworld_wild_spawns` 2.1.0; commit `77ce8fc2bac106de5ddca29256ad1415f49b9f29` | Optional dependency recorded. Preserve encounter start, battle completion, run, and catch return paths. | Propose the same stable encounter-provenance fields as Wild Skies, plus documented battle-return lifecycle semantics. |

## Existing SBFX integration surface

The public integration contract is documented in
[`BATTLE_PRESENTATION_API.md`](BATTLE_PRESENTATION_API.md). Its component slots
are `arena`, `models`, `animations`, `camera`, `effects`, `announcer`, `hud`,
`overlay`, and `transitions`.

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
