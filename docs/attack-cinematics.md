# Stadium attack presentation and camera research

> **2.0 note:** Camera direction is now hosted by StadiumBattleFX and selected
> through API slot `camera`. References below to wrapping Dramaless BattleCam
> describe the 1.x implementation and are not a supported integration seam.

Pokemon Stadium does not store a move as one self-contained animation file.
The battle presentation is assembled at runtime from several layers which can
start and finish at different times:

```text
species move row -> Pokemon body animation + attachment events
move dispatch row -> primary VFX program
                  -> optional alternate program
                  -> defender/impact program(s)
battle director   -> combatant-aware camera state
```

This is why the portable implementation must support both unique moves and
overlap. The 165 Gen 1 moves currently resolve to 108 primary program
sequences and 80 defender/impact sequences in Stadium's `D_84386E08` table.
Sharing an impact program does not imply that the windup, body animation, or
camera staging is also shared.

## Source trail

- `pret/pokestadium/src/fragments/62/fragment62_315D50.c` contains
  `D_84386E08`, the move-to-primary/alternate/impact dispatch table, and
  `func_8432C1E0`, which dispatches each zero-terminated program sequence.
- The primary and defender function tables in the same file show that the two
  stages are separate callback families.
- `fragment62_304060.c`, `fragment62_3055E0.c`,
  `fragment62_309ED0.c`, `fragment62_313250.c`, and
  `fragment62_313D60.c` contain the combatant-aware camera state machines.
  They repeatedly select a combatant, derive eye/at positions from its world
  bounds and facing, and use several lenses (commonly 30, 40, 50, and 60
  degrees). Camera logic is therefore a live battle layer, not texture data
  that can be extracted beside a particle atlas.
- Dramaless Shape's per-species Stadium tables map move rows 0-164 to the body
  animation used by that particular Pokemon. The same move can consequently
  have different body timing for two species while retaining the same shared
  VFX program.

The complete cartridge body matrix now identifies each species/move row.
Bytes `0D` and `0E` select the initial and subsequent fragment-62 camera
families, while byte `0F` supplies the controller transition delay (with the
native zero-to-15 default). Selector groups 20 through 24 retain Stadium's
exact legal shot sets; selector 25 preserves the current camera.

## Portable implementation

`lib/effects/AllMoveSpecs.lua` now records two independent presentation keys:

- `visual`: one of the shared move-shaped programs such as slash, punch,
  grapple, stream, storm, electric, psychic, ground, heal, transform, or
  explosion;
- `cinematic`: a reusable camera timeline such as melee, combo, ranged,
  sustained, aerial, field, status, self, or explosion.

`lib/AttackCinematics.lua` applies those native row selectors while a Stadium
move player is active. The old reusable family timelines remain only as the
safe fallback for model providers that do not expose a Stadium row. Map stages
keep their collision-safe eye fixed and translate the selected native rig
optically; empty-disc stages also permit the selected orbit. Canonical camera
queries are never modified.

The visual renderer and camera director are intentionally separate. For
example, Thunder Shock and Thunderbolt can share an electric impact language
without sharing the same primary VFX program, while Double Slap and Fury
Attack can share the combo camera without sharing their contact primitive.

## Remaining fidelity work

Per-species selectors, transition ticks, body starts, and attachment bytes are
now runtime data rather than shared-family guesses. The remaining native-oracle
work is limited to pixel projection: validating the translated eye/focus/FOV
against N64 captures, resolving the original RNG choice within grouped shots,
and porting every callback's final particle transform/blend into the different
Gen1Recomp compositor.
