# Runtime cache format

Cache revision 3 lives in Gen1Recomp's save directory:

```text
stadium_battle_fx/effects/v3/
  cache.info
  <36 bounded texture ranges>.i4|ia8|rgba16
```

The files contain original bounded N64 I4, IA8, or RGBA16 texture bytes. They
are decoded to RGBA atlases in memory; converted images are not written. The
cache contains only the shared primitive set used by the source-calibrated and
dedicated renderers, not a complete archive member or fragment. Its combined
payload is 160,768 bytes (about 157 KiB).

`cache.info` is ASCII. Its first line is the format and revision:

```text
SFXC3 3
```

Each remaining line is:

```text
<asset-name> <exact-byte-count> <adler-style-checksum>
```

The marker is written only after all 36 primitive files have been written and
uploaded successfully. A cache is accepted only when every expected record
and file exists and both its length and checksum match. Revision 2, partial,
or corrupt caches therefore fall back to a rebuild from the player's ROM.

The cache path is owned exclusively by Stadium Attack Animations. Dramaless
Shape's model packs and marker use a different directory and are never
modified.
