# StadiumBattleFX 2.1.5

This release restores compatibility with Gen1Recomp 0.1.86's restricted mod
sandbox and moves cartridge conversion out of the game.

Download `STADIUM_BATTLE_FX-2.1.5.zip` for the public ROM-free mod and
`StadiumBattleFX-Announcer-Builder-windows.zip` to create a private,
cartridge-backed personalized package on your own computer.

## Fixed

- StadiumBattleFX starts without `love.filesystem`, `love.system`, `io`, or a
  mutable `package` table.
- The Stadium 2 cache is read from the personalized mod package through
  `mod:read`; it no longer probes or writes global LÖVE filesystem paths.
- The in-game Stadium/Stadium 2 ROM import and cache-refresh actions have been
  removed because Gen1Recomp intentionally provides no raw-filesystem
  permission.

## Personalized builder

The desktop builder now produces all cartridge-derived runtime data before the
mod is installed:

- 36 attack-effect texture primitives;
- ten native Stadium arena stages;
- 43 trainer portraits;
- 151 Stadium 1 skeletal model packs;
- the dedicated Thunder Shock texture;
- 823 announcer clips; and
- optionally, 151 normal/shiny Stadium 2 appearances plus Substitute.

Select Pokemon Stadium (USA) v1.0, optionally Pokemon Stadium 2 (USA), the
official voice-free 2.1.5 ZIP, and an output location. The generated
personalized ZIP contains derived caches and audio, not either source ROM.
Never redistribute the personalized ZIP.

## Installation

The public ROM-free ZIP loads safely and retains procedural effects. For the
complete cartridge-backed presentation, build and install the personalized ZIP
instead of the public copy. Both packages use the same mod ID and must not be
installed together.

The Windows builder is currently unsigned, so Windows may show a reputation
warning on first launch. Its source and reproducible build scripts are included
in this repository.
