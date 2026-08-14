# StadiumBattleFX 2.1.1

This patch release adds cooperative compatibility with Battle Art Voxel Fork
1.8.x without modifying or redistributing Battle Art.

## Battle Art compatibility

- Battle Art's staged arena, sprite cards, camera, trainer art, HUD treatment,
  and transition remain authoritative while its **3D-BTL** mode is active.
- StadiumBattleFX automatically yields its competing arena, models, trainer
  portraits, skeletal reactions, faint animation, and attack camera.
- Stadium move effects and the optional announcer continue running. Anchored
  particles follow Battle Art's live projected Pokemon cards, while
  screen-wide effects remain aligned with the complete battle surface.
- Turning Battle Art's **3D-BTL** mode off restores the player's normal SBFX
  provider selections. Neither mod changes the other's saved options.
- Battle Cinematics no longer advances Battle Art's shared camera twice per
  frame when all three mods are installed.

## Installation

Install `STADIUM_BATTLE_FX-2.1.1.zip` through Gen1Recomp's mod manager. Existing
private Stadium ROM-derived caches and announcer data remain compatible.
