# StadiumBattleFX 2.1.2

This release combines Stadium model/cache performance improvements with
pairwise compatibility for the requested overworld and voxel-rendering mods.

## Performance

- Memoizes Stadium 2 model-pack availability instead of probing the complete
  imported roster during repeated runtime checks. Imports, writes, clears, and
  finalization invalidate the memoized result.
- Remembers the exact model-source keep callback selected when a Pokemon model
  is acquired, eliminating repeated option and availability work every frame.
- Keeps resident Stadium 2 hybrid models alive without rebuilding their cache
  key or reshuffling the importer LRU twice per rendered frame.
- Applies texture wrapping only when a texture's requested wrap mode changes,
  including normal, additive, and shadow-caster passes.

## Pairwise mod compatibility

Compatibility means each listed mod with StadiumBattleFX. This release does
not claim or manage compatibility among the third-party mods themselves.

- Battle Art Voxel Fork 1.8.8: consumes the merged `battleStage` API v1 and
  retains a fallback for older releases.
- Dramatic Shape 1.8.2 and PotatoVoxel 1.5.2: yield SBFX's competing arena,
  models, camera, trainer portrait, HUD, and transition when their staged
  3D battle is active, while Stadium effects and announcer timing continue.
- Followers EX 1.0.19 and Kanto Dynamic Weather 1.0.3: their overworld hooks,
  options, and renderer ownership remain untouched.
- Wild Skies 1.10.0 and Wilds of Kanto 2.1.0: their encounters use the normal
  SBFX wild-battle lifecycle, including battle completion, run, and catch
  return paths.

## Settings

- Enable StadiumBattleFX normally.
- With Battle Art, Dramatic Shape, or PotatoVoxel, turn that mod's **3D-BTL**
  setting **ON** to keep its staged voxel battle while using Stadium effects.
  No SBFX provider setting is required. Turn **3D-BTL OFF** to return arena,
  models, camera, and trainer presentation to the normal SBFX selections.
- Followers EX, Kanto Dynamic Weather, Wild Skies, and Wilds of Kanto require
  no special SBFX setting. Configure their own features as desired and follow
  their declared dependencies.

## Installation

Install `STADIUM_BATTLE_FX-2.1.2.zip` through Gen1Recomp's mod manager. Existing
private Stadium ROM-derived caches and announcer data remain compatible. The
public ZIP contains no ROM-derived content.
