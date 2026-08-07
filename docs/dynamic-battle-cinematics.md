# Dynamic Battle Cinematics compatibility

Compatibility was checked against the official `Battle_Cinematics-v0.7.1.zip`
release asset (SHA-256
`4164f10d6948068ba7a4bfef78219427a90237944be19dbde34aa488e3227f32`).
The upstream release was inspected read-only and no files in its repository
or package were modified.

## Hook boundary

Battle Cinematics:

- replaces Dramatic Shapes' `BattleCam.rig` function;
- wraps the `input.step` hook;
- listens for battle start, switch, and end events;
- wraps input and turn/menu commitment methods to reset its camera;
- exports only its version and an activity/reset function.

It does not replace `BattleState.animPlayer`, `AnimPlayer:start`,
`BattleState.drawAnimLayer`, or any effect-cache path. Stadium Attack Animations owns
only the battle's `animPlayer` adapter, so there is no overlapping replacement.

## Moving-camera behavior

Dramatic Shapes calls the wrapped `BattleCam.rig`, renders the current camera,
and produces a live shot containing the projected player/enemy marks. Its own
`drawAnimLayer` wrapper then translates and scales the entire move animation
layer to those marks every frame. Stadium Attack Animations deliberately retains the
classic Gen1 anchors inside that layer, so its particles follow Battle
Cinematics camera movement automatically and receive the transform once.

`DramaticShapeState` also records the installed `BATTLE_CINEMATICS` export
version for diagnostics. It never calls the camera's activity/reset export,
changes its settings, or reads/writes its files.

## Load relationship

The manifest declares `BATTLE_CINEMATICS@>=0.7.1 <1.0.0` as optional. Either
mod can run without the other. When both are enabled, the relationship is
visible to the loader and Stadium Attack Animations resolves both companions lazily
at battle start, after mod loading is complete.
