# Hybrid model viewer

Focused visual regression harness for Charmander, Grimer, and Koffing. It
loads Stadium 2 normal/shiny appearances through the importer API, grafts the
installed Stadium 1 model animations, and renders with StadiumBattleFX's real
`StadiumRig` and `StadiumRender` path.

Run from PowerShell:

```powershell
& 'C:\stadium animations\StadiumBattleFX\tools\hybrid_model_viewer\run.ps1'
```

Set `S1_PACK_ROOT` to an active playthrough's
`STADIUM_BATTLE_FX/models/packs` mod-storage directory to inspect the exact
current Stadium 1 import. Without it, the viewer uses the loose developer v5
cache if present.

Controls: `S` toggles normal/shiny, `Space` pauses, arrows rotate, `R` reloads,
`F12` saves a screenshot, and `Esc` exits.

For roster audits, set `S2_VIEWER_SPECIES` to three comma-separated National
Dex numbers before launching, for example `60,77,92`.
