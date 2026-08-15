# Hybrid model viewer

Focused visual regression harness for Charmander, Blastoise, and Koffing. It
loads Stadium 2 normal/shiny models through the embedded importer and renders
them with StadiumBattleFX's real `StadiumRig` and `StadiumRender` path. Each
caption reports whether the decoded Stadium 2 pose bundle is active or the
Stadium 1 fallback was required.

Run from PowerShell:

```powershell
& 'C:\stadium animations\StadiumBattleFX\tools\hybrid_model_viewer\run.ps1'
```

Set `S1_PACK_ROOT` to an active playthrough's
`STADIUM_BATTLE_FX/models/packs` mod-storage directory to inspect the exact
current Stadium 1 import. Set `S2_CACHE_ROOT` to an SBFX cache-builder output
to inspect its native Stadium 2 pose cache. The runner automatically uses
`tmp/stadium2-native-pose-cache` when present.

Controls: `Q`/`E` select source clips, `S` toggles normal/shiny, `Space`
pauses, arrows rotate, `R` reloads, `F12` saves a screenshot, and `Esc` exits.

For roster audits, set `S2_VIEWER_SPECIES` to three comma-separated National
Dex numbers before launching, for example `60,77,92`.
