# StadiumBattleFX 2.1.0

This release combines the Stadium trainer-portrait fix with the embedded
Stadium 2 Gen 1 appearance importer.

## Highlights

- Normal and shiny Stadium 2 appearances for all 151 Gen 1 Pokemon.
- Stadium 1 skeletal animations, move timing, reactions, and attachments are
  retained by the hybrid model path.
- Stadium trainer portraits can be enabled or disabled independently with the
  **STADIUM TRAINER PORTRAITS** option.
- Model compatibility fixes cover Charizard, Wartortle, Blastoise, Pidgey,
  Pidgeotto, Pidgeot, Ponyta, Rapidash, and Moltres, including Blastoise's
  upper-shell cannons and the fire-heavy species' complete flame surfaces.
- The former standalone `STADIUM2_IMPORTER` must be removed or disabled; its
  functionality is now built into StadiumBattleFX and the manifest conflicts
  with the old companion to prevent duplicate ownership.

## Install

1. Install `STADIUM_BATTLE_FX-2.1.0.zip` through Gen1Recomp's mod manager and
   enable StadiumBattleFX.
2. Remove or disable the old standalone Stadium 2 Importer mod if installed.
3. In Options, choose **STADIUM ROM → IMPORT** and select Pokemon Stadium
   (US) 1.0 for battle effects, Stadium 1 animation models, arenas, and trainer
   portraits.
4. In Options, choose **STADIUM 2 ROM → IMPORT** and select Pokemon Stadium 2
   (US) for normal and shiny model appearances.
5. Allow both private caches to finish building before entering a battle.

The official download contains no ROM data. You must supply legally obtained
ROM dumps. Accepted `.z64`, `.n64`, and `.v64` files are normalized before
validation. The required normalized MD5 hashes are:

- Pokemon Stadium (US) 1.0: `ed1378bc12115f71209a77844965ba50`
- Pokemon Stadium 2 (US): `1561c75d11cedf356a8ddb1a4a5f9d5d`

Other regions and revisions are rejected.
