# Runtime cache format

Cache revision 2 lives in Gen1Recomp's save directory:

```text
stadium_battle_fx/effects/v2/
  cache.info
  impact_ia.ia8
  impact_i.i4
  scratch_claw.i4
  scratch_spark.i4
  scratch_swipe.i4
  electric.i4
  sand.i4
  thunder_wave.i4
```

The files contain the original bounded N64 I4 or IA8 texture bytes. They are
decoded to RGBA atlases in memory; converted images are not written. Combined,
the cache is only the small shared primitive set needed by the current party,
not a complete archive member or fragment.

`cache.info` is ASCII. Its first line is the format and revision:

```text
SFXC2 2
```

Each remaining line is:

```text
<asset-name> <exact-byte-count> <adler-style-checksum>
```

The marker is written only after all eight primitive files have been written
and uploaded successfully. A cache is accepted only when every expected
record and file exists and both its length and checksum match. Old, partial,
or corrupt caches therefore fall back to a rebuild from the player's ROM.

The cache path is owned exclusively by Stadium Battle FX. Dramatic Shapes'
model packs and marker use a different directory and are never modified.
