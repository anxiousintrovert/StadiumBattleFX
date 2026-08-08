# Gym and Elite Four announcer integration

`lib/Announcer.lua` now implements this behavior policy using the public battle
events exposed by Gen1Recomp. It remains deliberately narrower than Stadium's
full commentary system.

## Scope gate

Enable the announcer only when the current trainer is a Gym Leader, Elite Four
member, or champion/rival encounter. Ordinary trainers and wild battles keep
their existing audio behavior.

## Playback priority

Only one announcer clip should play at once. When events collide, use this
priority order:

1. encounter introduction (once, before combat input)
2. battle result or final faint
3. Pokemon faint / replacement required
4. status, miss, effectiveness, or switch reaction
5. species send-out sentence
6. move-name call
7. ambient battle-flow line

Lower-priority clips should be dropped rather than queued behind stale battle
events. Apply a short cooldown after every clip and a longer cooldown to
ambient lines so the announcer does not speak continuously.

## Implemented subset

The current implementation includes:

- trainer-specific intros: clips 223–235
- species send-outs: `368 + species_id`
- move names: `583 + move_id`
- switches: clips 245–253
- super/not-effective, miss, and status reactions from the reviewed catalog
- faints: clips 349, 351, 357, or 358
- victory: clip 365; champion result: 366; castle clear: 368

Ambient flow commentary and special Pikachu vocalizations can be added after
event timing and interruption behavior are reliable.

## Optional-pack contract

The official ZIP contains no WAV files. A local builder adds numbered files
under `assets/announcer/` and writes `voicepack.json` last. Runtime checks that
small marker before requesting audio. A missing marker disables only the
announcer; a missing or malformed numbered WAV is remembered and skipped while
the remaining clips continue to work.
