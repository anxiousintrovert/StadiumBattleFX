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
`BattleState.drawAnimLayer`, or any effect-cache path. Stadium Attack
Animations owns the battle's `animPlayer` adapter and lazily composes its
move-time director around the final `BattleCam.rig` only after all mods have
loaded. Battle Cinematics resets its idle shot on a committed action; the
attack director then stages that action and returns to the wrapped base rig.

## Moving-camera behavior

Dramatic Shapes calls the wrapped `BattleCam.rig`, renders the current camera,
and produces a live shot containing the projected player/enemy marks. Its own
`drawAnimLayer` wrapper then translates and uniformly scales the entire move
animation layer. A cinematic orbit also changes the projected angle between
the battlers, which that uniform transform cannot reproduce by itself.
Stadium Attack Animations therefore reads the live marks every frame and
inverse-maps each effect anchor through DS's outer transform. When DS applies
that transform, the particle lands exactly on the current projected Pokémon
without receiving translation or scale twice.

`DramaticShapeState` also records the installed `BATTLE_CINEMATICS` export
version for diagnostics. It never calls the camera's activity/reset export,
changes its settings, or reads/writes its files.

## Load relationship

The manifest declares `BATTLE_CINEMATICS@>=0.7.1 <1.0.0` as optional. Either
mod can run without the other. When both are enabled, the relationship is
visible to the loader and Stadium Attack Animations resolves both companions lazily
at battle start, after mod loading is complete.
The camera wrapper itself is installed on the first eligible Stadium move, so
it composes with the final runtime rig regardless of manifest load order.
