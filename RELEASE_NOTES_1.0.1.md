# StadiumBattleFX 1.0.1 — Overlay-safe animation fallback

This maintenance release keeps move animations active when a screen-overlay
texture is missing, stale, or still rebuilding in the private cache.

## Fixed

- Screen overlays no longer gate the complete custom move presentation.
- Blizzard keeps its snow animation when overlay textures are unavailable.
- Blizzard draws procedural snowflake geometry if its optional snow textures
  are unavailable.

The complete 165-move roster and the 1.0.0 timing/presentation profiles are
otherwise unchanged.
