# Pokemon Stadium announcer conversion notes

Status: extraction and PCM conversion are proven for Pokemon Stadium (USA)
v1.0. A reviewed starter event catalog now exists; runtime playback and
battle-event selection are not implemented yet.

## ROM layout

The speech archive is an `S1` container at ROM offset `0x197C1E0`. Its three
children contain 165, 1, and 657 MORT streams respectively, for 823 clips.
Every discovered clip uses a 16,000 Hz sample rate.

Each MORT stream begins with this big-endian header:

| Offset | Width | Meaning |
| --- | ---: | --- |
| `0x00` | 4 | ASCII `MORT` |
| `0x04` | 2 | count of 160-sample decoder frames |
| `0x06` | 2 | sample rate (16,000 in this ROM) |
| `0x08` | 4 | total stream length in 32-bit words |

Run the read-only inventory/extractor from the project root:

```powershell
..\Gen1Recomp\.venv\Scripts\python.exe tools\extract_stadium_announcer.py `
  "..\Pokemon Stadium (USA).z64" `
  --output research\announcer_mort
```

Use `--indices 0,24,165` to extract only selected streams. The output folder
is ignored by Git because its contents are derived from the user's ROM.

## Conversion test

N64 Sound Tool's public-domain `CMORTDecoder`, reverse engineered by SubDrag
from Pokemon Stadium, successfully decoded representative entries from all
three archive children to mono signed 16-bit PCM WAV. Each file contains
exactly `frame_count * 160` PCM samples at 16,000 Hz. The reference WAV writer
also appends an empty 44-byte `smpl` metadata chunk after the audio data.

Local test WAVs live under `research/announcer_samples/` and are ignored by
Git. They are research outputs only and are never included by the runtime
package allowlist.

The next implementation step is to port or wrap `CMORTDecoder` as a command
line build tool, then connect the reviewed catalog to gym and Elite Four
battle events.

## Catalog structure

`announcer_catalog.json` contains the first machine-readable event mapping.
The important ranges are:

| Indices | Contents |
| ---: | --- |
| 0–150 | Short Pokemon-name calls in Pokedex order |
| 151–164 | Special Pikachu vocalizations, not announcer commentary |
| 166–199 | Battle state and short reactions |
| 200–221 | Tournament/rules introductions (excluded from Gym mode) |
| 222–235 | Gym Leader, Elite Four, and rival introductions |
| 239–244 | Gym-series opponent progression |
| 245–255 | Pokemon switching |
| 261–347 | Damage, effectiveness, failures, and status |
| 348–368 | Fainting and battle results |
| 369–519 | `Oh! It's [Pokemon]!` in Pokedex order |
| 520–583 | Ongoing move/status state and timer lines |
| 584–748 | Move calls in Gen I move-ID order |
| 749–822 | General battle-flow commentary |

The deterministic call formulas are:

- short species call: `clip_index = species_id - 1`
- full send-out sentence: `clip_index = 368 + species_id`
- move call: `clip_index = 583 + move_id`

Exact Gym Leader Castle introductions are clips 222–235: the general castle
intro, Brock through Giovanni, Lorelei through Lance, and the rival/champion.
The quote/event cross-check used the community-maintained [Pokemon Stadium
Announcer Quotes](https://pokemon.fandom.com/wiki/Pok%C3%A9mon_Stadium_Announcer_Quotes)
trigger list. ROM indices, archive grouping, and formula mappings were derived
locally and are not taken from that page.
