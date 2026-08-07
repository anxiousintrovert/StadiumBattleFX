# Stadium effect scale references

Pokemon Stadium does contain authoritative scale data. It is split across
the particle callback, render preset, optional species normalization, and the
battle camera rather than stored as a single per-move pixel size.

## Source model

For the shared fragment-34 particle type, `unk_1C` is uniform world scale.
`func_8140B938` initializes it, `func_8140B98C` eases it toward a target, and
`func_8140B95C`/`func_8140B974` store a target and rate for
`func_8140BA1C`. The standard billboard renderers pass that value to
`func_81404DB4`.

The common canonical quads are:

| Vertex set | World dimensions | Typical role |
|---|---:|---|
| `D_8140DFD8` | 24 x 24 | small particle |
| `D_8140E018` | 32 x 32 | standard particle |
| `D_8140E178` / `D_8140E1B8` | 32 x 64 | tall/ground-anchored particle |
| `D_8140E238` | 32 x 96 or 64 x 32 | beam/streak variants |
| `D_8140E2B8` | 64 x 64 | large particle |

World footprint is therefore `quad dimension * particle world scale`. A
flagged subset also multiplies scale by the species table value
`D_80075E40[speciesId] * 0.01`; this is not a universal rule for attack VFX.

The final screen size is perspective projected. Stadium renders combat at
320 x 240 and battle cameras use several FOV values (commonly 30, 40, 50, or
60 degrees). Its base 50-degree battle-camera table uses eye distances from
about 560 to 2002 world units. Full-screen effects are a separate, explicit
320 x 240 orthographic path. Texture dimensions alone must never be treated
as the desired screen dimensions.

For a billboard centered near the camera target, the vertical conversion is:

```text
N64 pixels/world = 120 / (tan(fovY / 2) * cameraDistance)
Gen1 pixels/world = N64 pixels/world * (144 / 240)
```

At 50 degrees the Stadium base-camera range converts to roughly 0.08-0.28
Gen1 pixels per world unit. The median camera distance is close to 1500,
which gives 0.10 and is the portable baseline used below.

## Thunder Shock reference

Thunder Shock layers six primary emitter streams and three impact streams.
The exact callback envelopes are now recorded in
`lib/effects/ThunderShockSpec.lua`:

| Callback | Initial | Target | Step |
|---|---:|---:|---:|
| `func_8433D6EC` | 0.1 | 1.4 | 0.1 |
| `func_8433D560` | 0.5 | random 1.0-6.0 | 0.2 |
| `func_8433D3B0` | 0.5 | 2.0 | 0.2 |
| `func_8433D070` | 0.1 | 3.0 | 0.1 |
| `func_8433D224` | 0.1 | 3.5 | 0.1 |

This proves the v0.2 test's old constant `0.45` sprite scale was only a
portable projection guess. Development source now preserves Stadium's
relative scale envelope and uses `0.10` as a camera-derived median
world-to-Gen1-screen projection anchor. The frozen v0.2.0 package is not
changed.

## Calibration policy

Each renderer family should store four independent facts:

1. canonical quad dimensions;
2. callback scale envelope;
3. anchor mode and optional species normalization;
4. a portable projection factor measured against a native Stadium capture.

Until a native capture supplies camera depth at the effect anchor, relative
sizes can be source-accurate but absolute Gen1-screen pixels remain a
calibration value. We should tune one projection anchor per camera/anchor
class, not one arbitrary scale per move.

## Dramatic Shapes projection ownership

`lib/DramaticShapeState.lua` reads Dramatic Shapes' exported state without
writing to it: current voxel rung/angle, 3D-BTL Stadium mode, live projected
shot, animation-layer scale, model visibility, and model footprint.

When a live staged shot exists, Dramatic Shapes already transforms the whole
`BattleState.drawAnimLayer` from the classic Gen1 anchors to the current
camera projection. Stadium Attack Animations therefore keeps its internal anchors at
player `(26, 96)` and enemy `(124, 56)` and lets that wrapper move and scale
the completed effect exactly once. Applying the live shot coordinates inside
the effect player would double-transform it and is specifically avoided.
