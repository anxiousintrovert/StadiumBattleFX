# StadiumBattleFX Research

All conclusions in this file must name their source. Unknown symbols retain
their upstream names until their behavior is established.

## Repository findings

Reference revisions used for the first pass:

- Gen1Recomp `dev`: `112120e8fe4ab03665e7e3eff761032451b36d8c`
- DramaticShapeVoxelMod `dev`: `301bd4c1f9d2b941394f4b8cf03e5298cb701e79`
- PokemonStadiumRecomp `main`: `de27b7b8481630d41fc7fb913dbd02572d421efd`
- pret/pokestadium submodule: `756f7e332ee3837ead17197276cebc071108e8c6`

The supplied Stadium ROM is Pokemon Stadium (USA) v1.0, 33,554,432 bytes,
normalized MD5 `ed1378bc12115f71209a77844965ba50`.

## Gen1Recomp animation pipeline

Confirmed call path in `src/battle/BattleState.lua`:

1. `BattleState:performMove` creates `moveAnimRow` and inserts it into the
   battle queue.
2. It emits `battle.move_used` with `battle`, `user`, `target`, and `move`.
3. The queue pays `Timing.MOVE_ANIM_PRE`, resolves the move animation record,
   and calls `AnimPlayer:start`.
4. While `animPlaying` is true, the battle queue calls `AnimPlayer:update`,
   dispatches its screen/picture effects, and does not advance.
5. `BattleState:drawAnimLayer` draws the active player.
6. Once `AnimPlayer:isDone()` is true, hit feedback runs and the queue resumes.

The runtime records `battle.move_used` context, then replaces the one
`AnimPlayer` instance created for a battle with a contract-compatible adapter
at `battle.started`. The adapter receives the authoritative move in `start`,
continues using the original player as its sound clock, and reports its own
completion to the existing queue. This keeps the intervention narrow and
avoids changing damage or turn logic.

## Dramaless Shape Stadium pipeline

`DRAMALESS_SHAPE/main.lua` exports its namespace through `mod.exports.lib`. A
dependent mod can obtain it through Gen1Recomp's supported
`mod.find("DRAMALESS_SHAPE")` API without reading or changing the mod directory.

The exported `Stadium` module provides high-level state and a reaction request:

- `animOf(side)`
- `showing(side)`
- `scaleOf(side)`
- `footprint(side)`
- `standing()`
- `hit(side, effectiveness)`

It does not expose per-frame animation time, active model objects, bone
matrices, or attachment world positions. Version 0.2 therefore reads only
`showing(side)` for body-only fallback and the exported `StadiumInstall` state
to sequence the two independent first-run cache screens.

DramaticShape's model extraction establishes that:

- the per-species battle table selects body/skeletal animations;
- move rows 0-164 correspond to move IDs 1-165;
- geometry command `0x24` records an attachment location rather than drawing
  an effect;
- battle move VFX live in a separate procedural system, principally within
  Stadium battle fragments.

This is source evidence that body animation data must not be mistaken for the
Thunder Shock VFX program.

## Pokemon Stadium battle VFX architecture

Initial static inspection confirms that fragment 62 contains:

- a 256-entry runtime asset pointer table `D_843920C0`;
- many effect initializer functions which schedule objects through common
  helpers such as `func_8432EC28` and `func_8432ECA0`;
- separate update callbacks, display-list/texture rendering routines, timing
  arguments, and screen/camera helpers;
- mostly anonymous function and structure names.

The presence of literal `0x54` in a function is not sufficient evidence that
the function implements move 84. In particular, `func_843081BC` returns the
combatant species ID, so `D_843845FC = { 0x55, 0x54 }` is the Dodrio/Doduo
species pair, not Thunderbolt/Thunder Shock.

## Thunder Shock - move 84

Confirmed:

- Gen I move ID is decimal 84 / hexadecimal `0x54`.
- pret's old move constants spell it `THUNDERSHOCK`.
- Thunderbolt, Thunder Wave, and Thunder are IDs 85-87 and are useful
  comparison cases.
- `func_8432C1E0` indexes `D_84386E08` directly by move ID.
- Move 84's normal primary sequence is opcode `0x3B`, initialized by
  `func_8433E124`.
- Move 84's defender-stage sequence is opcode `0x08`, initialized by
  `func_8433DECC`.
- Both stages use animated runtime texture slot `0x13` and the shared particle
  manager. See `docs/thunder-shock-trace.md` for the complete call path and
  schedule.
- Resource bundle `0x0F` is member 15 of the procedural-effect archive at ROM
  `0x8CC000`.
- Runtime slot `0x13` is an eight-frame `32x96` N64 I4 texture at decompressed
  fragment offset `0x4860`.

Not yet confirmed:

- the texture's exact tint and blend mode;
- the visual meaning of the two generic controller callbacks;
- whether the tick-100 marker alone completes the full battle presentation;
- exact sound identity and camera synchronization.

## Unknowns

- What transforms do callbacks `func_8433D6EC`, `func_8433D560`,
  `func_8433D3B0`, `func_8433D070`, and `func_8433D224` apply to their quads?
- What color and blend state do the four render presets apply?
- What do the two generic controller callbacks change on screen?
- What exact state causes Stadium to consider the effect complete?

## Next executable experiment

Compare the standalone fixed-step viewer against a native Stadium capture,
then trace the five particle callbacks far enough to replace each provisional
motion rule with its exact transform.

This work requires no cooperation from DramaticShapeVoxelMod's developer. The
repository is treated only as public, read-only source evidence; at runtime its
documented exports may be queried if useful, but StadiumBattleFX never writes
to its directory or private cache.
