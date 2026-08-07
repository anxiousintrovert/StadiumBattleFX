# Stadium attack presentation and camera research

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
- Dramatic Shapes' per-species Stadium tables map move rows 0-164 to the body
  animation used by that particular Pokemon. The same move can consequently
  have different body timing for two species while retaining the same shared
  VFX program.

Static source is enough to establish the architecture and reuse boundaries.
It is not enough to name every anonymous camera state or recover exact cut
timings. Native Stadium/recomp captures remain the calibration oracle for
those details.

## Portable implementation

`lib/effects/AllMoveSpecs.lua` now records two independent presentation keys:

- `visual`: one of the shared move-shaped programs such as slash, punch,
  grapple, stream, storm, electric, psychic, ground, heal, transform, or
  explosion;
- `cinematic`: a reusable camera timeline such as melee, combo, ranged,
  sustained, aerial, field, status, self, or explosion.

`lib/AttackCinematics.lua` applies the camera timeline only while a Stadium
move player is active and Dramatic Shapes owns a staged Stadium battle. A
timeline focuses the attacker during windup, follows the primary stage, cuts
to the defender near `impactAt`, and returns to the base shot before the move
finishes. Map stages keep Dramatic Shapes' proven camera eye fixed and create
close-ups through focus/FOV; empty-disc stages also permit a small safe orbit.
Canonical camera queries are never modified.

The visual renderer and camera director are intentionally separate. For
example, Thunder Shock and Thunderbolt can share an electric impact language
without sharing the same primary VFX program, while Double Slap and Fury
Attack can share the combo camera without sharing their contact primitive.

## Remaining fidelity work

The new programs are a staging foundation, not a claim that all 165 attacks
are frame-perfect. Exact work still requires native captures to identify:

1. the camera state chosen for each species/move/body-animation combination;
2. the exact cut and blend ticks relative to body attachment events;
3. native FOV, eye, and focus values after species-size normalization;
4. which HUD and full-screen overlays remain visible during each move;
5. exact VFX transforms, colors, blend modes, and completion markers.

Those facts should be added as calibrated overrides while retaining the
shared primary/impact/camera registries, rather than returning to one generic
beam per elemental type.
