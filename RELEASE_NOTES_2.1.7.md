# StadiumBattleFX 2.1.7

This maintenance release fixes optional Pokemon Stadium 2 model rebuilding on
restricted Gen1Recomp sandboxes.

It also restores the native Pokemon Stadium renderer's persistent F3DEX
material and cull state during Stadium 1 model conversion. Closed body meshes
now retain their intended back-face behavior, while two-sided effect meshes
remain visible. Existing Stadium 1 model caches rebuild automatically.

When the sandbox allows the mod to read the player-imported Stadium 2 ROM but
does not expose persistent scoped mod storage, StadiumBattleFX now keeps the
generated model packs in a safe process-local cache. The normal and shiny
Stadium 2 models are immediately usable for the rest of that play session.

Stadium 2 rebuilds alongside the normal first-run cache stages, advancing one
bounded extraction phase per screen update. Switching between Stadium 1 and
Stadium 2 also replaces the active battler rig immediately.

No host filesystem access, file picker, or source ROM redistribution is added.
