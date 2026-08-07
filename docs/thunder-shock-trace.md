# Thunder Shock trace

This report records only behavior that can be tied to the checked-out
pret/pokestadium source at revision `756f7e332ee3837ead17197276cebc071108e8c6`.
Names in backticks remain upstream's anonymous names.

## Result

Thunder Shock is not animation-table row 83 and it is not fragment 62's
effect opcode `0x54`. Move IDs index the visual dispatch table directly, so
Thunder Shock uses row **84**. Its normal attack stage dispatches opcode
`0x3B`; its defender/impact stage dispatches opcode `0x08`.

The effect is a procedural particle schedule using one animated electric
texture, three narrow vertical quad profiles, attacker and target attachment
tag `0x64`, and several generic particle callbacks. It is not a single model,
sprite sheet animation, or skeletal clip.

## Selected move to VFX dispatch

1. The selected move is held in `unk_D_800FCB18.unk_5A`.
2. `func_84302A78` starts the species-specific body animation described by
   that species' 16-byte move row.
3. At body-frame field `unk_04 + 1`, `func_84302C34` calls
   `func_84301B84(attacker, moveId)`.
4. `func_84301B84` passes the move ID, attacker, target, and attachment values
   to `func_8432C5D4`.
5. `func_8432C550` stores the move ID in `D_843902AC` and marks a primary
   effect request pending.
6. `func_8432C3F8` consumes the request and calls
   `func_8432C1E0(D_843902AC, mode, requestKind)`.
7. Normal primary attacks use `D_84386E08[moveId][0]`. Index 84 points to
   `D_84386A98`, the zero-terminated opcode sequence `{ 0x3B }`.

The corresponding defender-stage path calls `func_84301C54`, which requests
the secondary column through `func_8432C604`. For move 84,
`D_84386E08[84][2]` points to `D_84386BE4`, sequence `{ 0x08 }`.

## Primary opcode 0x3B

The four opcode tables resolve index `0x3B` as follows:

| Job | Function |
| --- | --- |
| procedural initializer | `func_8433E124` |
| asset/setup callback | `func_843593A0` (empty) |
| registered completion poll | `func_843593B0` (returns `-1`) |
| registered renderer | `func_843593C0` (empty) |

The empty registered renderer is expected: `func_8433E124` schedules objects
into the shared particle manager, whose own update/render path draws them.

`func_8433E124` schedules:

- a marker carrying value 1 at tick 100;
- a controller object at tick 0;
- two attacker-anchored emitter series beginning at tick 0;
- a 35-tick timeline shift;
- four more attacker-anchored emitter series beginning at tick 35;
- another controller object at tick 43.

The six exact emitter records are encoded in
`lib/effects/ThunderShockSpec.lua`. `func_8432E5A4` proves that the schedule's
first integer is a delay, the second is a repeat interval, and the third is
the number of emissions.

## Impact opcode 0x08

The secondary opcode tables resolve index `0x08` to:

| Job | Function |
| --- | --- |
| procedural initializer | `func_8433DECC` |
| asset/setup callback | `func_843593A8` (empty) |
| registered completion poll | `func_843593B8` (returns `-1`) |
| registered renderer | `func_843593C8` (empty) |

`func_8433DECC` schedules three emitter series at the target, plus controller
objects at ticks 44 and 48. Anchor mode 3 is updated by `func_8432DE0C`: it
resolves attachment tag `0x64` and then fixes the resulting Y coordinate to
the battlefield ground plane.

## Render resources

The relevant render presets are `D_843861D0[0x0F]`, `[0x12]`, `[0x13]`, and
`[0x14]`. Their draw functions are `func_843310A0`, `func_84331450`,
`func_8433157C`, and `func_843316A8`.

All four sample runtime asset slot `D_843920C0[0x13]` as a `0x20` by `0x60`
animated texture. Frames are selected with a `0x600`-byte stride. They draw
vertical quads 96 units high with widths 32, 16, or 8 units.

`func_8001987C` maps the procedural-effect archive to ROM offset `0x8CC000`.
The primary resource-list value `0x0F` selects archive member 15, a
`PERS-SZP`-wrapped Yay0 fragment. Its fragment asset table maps runtime slot
`0x13` to decompressed offset `0x4860`. The next asset begins at `0x7860`, so
the texture occupies exactly `0x3000` bytes: eight frames times the verified
`0x600`-byte frame stride. `func_8140437C` ultimately selects N64 `I4`, and
the global frame counter masks to three bits, confirming eight frames.

The safe extractor converts just those `0x3000` bytes to a white-RGB,
intensity-as-alpha PNG atlas. Its source texture SHA-256 is
`7a40afa59cec4d7b1e52b85fda2dd1fa99e752367f751961dfaa5be0236c6f5a`.

## Body-animation rows

The body-animation data is separate from the procedural VFX. Fragment 62
loads a species block from ROM base `0x70D3A0`; `D_80075BD0` advances by
`0xB90` per species and each move row is `0x10` bytes. Therefore:

```text
row = 0x70D3A0 + (speciesId - 1) * 0xB90 + (moveId - 1) * 0x10
```

For Pikachu (species 25), Thunder Shock's body row is at ROM offset
`0x71EE50`. Its `unk_04` byte is `0x0D`, so the primary VFX request occurs at
body-animation frame 14 for Pikachu. Other species have different row values,
which is why this table cannot be treated as a global move-effect program.

The local probe can inspect any row without writing ROM-derived output:

```powershell
python tools/stadium_fx_probe.py --species 25 --move 84 "C:\path\to\Pokemon Stadium (USA).z64"
```

## Audio, camera, and completion

`func_84302A78` calls `func_80048060` with the move ID and species/context
arguments at body-animation start. That function is not decompiled in the
current source, so it is recorded as a likely audio dispatch rather than a
confirmed sound ID.

No Thunder-Shock-specific camera function is dispatched by opcodes `0x3B` or
`0x08`. The generic controller objects may still affect screen presentation;
their exact visual result needs a native-oracle capture.

The tick-100 event sets the shared flag through `func_8432F9A8(1)`. It is a
verified timeline marker, but current static source does not prove that it is
the sole condition that advances the whole battle state. The first portable
player should expose this as a marker, not hard-code the unsupported claim
that every presentation ends at exactly tick 100.

## Related electric moves

Primary sequences:

| Move | ID | Primary opcode |
| --- | ---: | ---: |
| Thunder Shock | 84 | `0x3B` |
| Thunderbolt | 85 | `0x12` |
| Thunder Wave | 86 | `0x26` |
| Thunder | 87 | `0x12` |

Thunderbolt and Thunder share primary opcode `0x12`; Thunder Shock does not.
Thunder Shock and Thunderbolt share impact opcode `0x08`. This is the useful
reuse boundary for the first implementation.

## Next experiment

Use the standalone fixed-step viewer to compare each stage with a native
Stadium capture. That capture should resolve colors, blend mode, particle
motion, the generic controller behavior, and the real interval between the
primary and impact stages before battle integration.
