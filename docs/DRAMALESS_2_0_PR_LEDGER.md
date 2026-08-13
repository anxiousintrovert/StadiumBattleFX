# Dramaless 2.0 split PR ledger

This file tracks the companion-side changes that must become a reviewable PR
after StadiumBattleFX 2.0 is independently functional. It is a migration
ledger, not permission to mix the two repositories' histories.

Active PR worktree: `C:\stadium animations\DRAMALESS_SHAPE-2.0-voxel-only`
on branch `agent/2.0-voxel-only`, based on `origin/battle-art-merge` at
`bcce159`. It currently contains the API-1 registration bridge, its test, and
the detailed deletion/refactor checklist in `SPLIT_2.0_PR.md`. Existing
attachment/provider worktrees were not modified.

## Agreed release boundary

- Dramaless Shape 1.6.4 and the matching StadiumBattleFX legacy release remain
  archived/LTS and mutually version-gated.
- Dramaless Shape 2.0.0 owns voxel environments and a narrow standalone
  native-2D-card voxel battle mode.
- StadiumBattleFX 2.0.0 owns modular battle presentation, Stadium models, and
  the provider API/selectors.
- Initial 2.0 builds are marked experimental before stable promotion.
- Legacy and 2.0 combinations are hard-blocked in manifests.

## Source strategy

- Extract Stadium behavior from Dramaless 1.6.4, then layer the local
  `agent/stadium-attachment-api` fixes deliberately.
- Build Dramaless 2.0 from the post-BattleArt 1.6.5 line, then remove battle
  presentation ownership. Do not redo the BattleArt merge solely to perform
  this split.
- Verify BattleArt's MIT license before transferring any BattleArt-authored
  code. Dramaless contributions are treated as MIT per maintainer approval.
  Preserve OXR's Apache-2.0 notice, but OXR/VR is removed from Dramaless 2.0.

## Dramaless deletions/removals

- [ ] Remove Stadium model extraction, cache, pack, rig, model, fragment, FX,
  ROM picker, install screen, and associated tests/data.
- [ ] Remove Stadium battle renderer hooks, attachments, hit/faint/recall, and
  send-out ownership.
- [x] Remove the legacy monolithic 2D-card staged-battle compositor while
  retaining native cards as an extracted provider and Stadium-absent host.
- [ ] Remove Stadium B portable disc stages.
- [ ] Remove all VR/OXR functionality and options from the maintained mod.
- [ ] Remove `3D-BTL` selectors and obsolete compatibility settings.
- [ ] Rename the remaining environment option label from `2D-3D` to `VOXEL`.
- [ ] Delete obsolete Stadium/VR assets and use resulting reference errors as
  a dependency audit.

## Dramaless additions

- [x] Consume the host-resolved camera pose in the voxel arena renderer so
  selected camera providers and the temporary Stadium-owned Battle Cinematics
  compatibility facade work without a Dramaless-private camera dependency.
- [x] Register optional `arena` and `models` providers through
  `STADIUM_BATTLE_FX.exports.battles` when API major 1 is available.
- [x] Prefer immediate registration after `mod.find`; retry from `mods.loaded`
  if load order makes the host unavailable.
- [x] Keep authored voxel battlefield locations and existing suitability
  checks.
- [x] If an authored location is unsuitable, try the generic same-map search;
  return `api.FALLBACK` if neither can safely host the battle.
- [x] Never require StadiumBattleFX for the voxel overworld or the native-2D
  voxel battle mode.
- [x] Add diagnostics for provider registration, decline, and runtime failure.
- [x] Route provider diagnostics through the host logger when supplied so the
  StadiumBattleFX export captures cross-mod arena decisions.
- [x] Yield the Dramaless standalone battle host whenever StadiumBattleFX is
  installed; Stadium's independent arena/model selectors are authoritative.

## Manifest gates

For Dramaless 2.0:

- [x] Set version `2.0.0` and `experimental: true` for public testing.
- [x] Add `STADIUM_BATTLE_FX@<2.0.0` to `conflicts` or `incompatible` using the
  field supported by the target Gen1Recomp build.
- [x] Do not add StadiumBattleFX as a hard dependency.
- [x] If listed as optional, use `STADIUM_BATTLE_FX@>=2.0.0 <3.0.0`.

For the final legacy Dramaless release:

- [ ] Keep/archive 1.6.4 as LTS unless a narrowly scoped urgent hotfix is
  necessary.
- [ ] Require/conflict so only the matching pre-2.0 StadiumBattleFX family can
  load with it.
- [ ] Clearly label the archive as stable legacy with no visual/minor fixes.

## Attribution to retain

Suggested notice:

> Dramaless_Shape is a VoxelMod fork for gen1recomp, containing fixes and
> additions by Stahltier (aka artyrambles) based on
> DramaticShapeVoxelMod 1.6.2.

Link the Dramaless repository and retain upstream MIT notices. Any retained
Apache-2.0 material must keep its notice; the expected 2.0 plan removes OXR.

## PR acceptance checks

- [x] Dramaless loads and renders the voxel overworld with StadiumBattleFX
  absent.
- [ ] StadiumBattleFX loads and runs battles with Dramaless absent.
- [x] With both 2.0 mods enabled, `VOXEL MAP` appears in StadiumBattleFX's
  arena selector and is player-selectable.
- [x] With both 2.0 mods enabled, `VOXEL 2D CARDS` appears in StadiumBattleFX's
  model selector and can pair with both voxel and Stadium arenas.
- [x] With StadiumBattleFX absent, `VOXEL 2D BATTLES` stages native cards on
  the authored Pewter Gym voxel arena; generic arena coverage remains pending.
- [ ] Arena selection `OFF` and `STADIUM DEFAULT` remain authoritative.
- [ ] No Dramaless private module is required by StadiumBattleFX.
- [ ] No Stadium model/cache/VR symbol remains reachable in Dramaless.
- [ ] Unsupported maps fall back to the engine battle presentation without a
  battle softlock.
- [ ] Legacy+legacy loads; legacy+2.0 and 2.0+legacy are hard-blocked.
- [ ] Clean install, upgrade with stale settings, mod removal, and graphics
  reset paths are tested.

## Evidence to attach to the PR

- `git diff --stat` grouped into removals, voxel-provider adapter, manifest,
  docs, and tests.
- Search results proving Stadium model, disc-stage, BattleArt, VR, and OXR
  runtime references are gone, with the retained native-card modules listed
  explicitly as the reviewed exception.
- Loader screenshots/logs for all four version combinations.
- One authored voxel arena, one generic fallback arena, one declined arena,
  and Dramaless-absent battle test.
- License/attribution file diff.
