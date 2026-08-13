# StadiumBattleFX 2.0.1

## Android animation positioning fix

- Fixed move animations appearing below and to the right of their Pokemon on
  Android.
- Fixed those animations falling completely outside the visible screen in
  portrait orientation.
- Kept anchored particles aligned when a Dramaless voxel arena renders with
  supersampling before resolving to the phone's framebuffer.
- Recalculates the mapping from the live renderer each frame, so rotating the
  device immediately uses the new viewport dimensions.

Install `STADIUM_BATTLE_FX-2.0.1.zip` through Gen1Recomp's mod manager. This is
a public, ROM-free package. Existing locally generated Stadium effect, model,
arena, and announcer caches remain in mod storage and do not need rebuilding.
