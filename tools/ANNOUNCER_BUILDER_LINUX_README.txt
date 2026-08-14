StadiumBattleFX Personalized Pack Builder — experimental SteamOS/Linux build

Target: Steam Deck Desktop Mode and x86-64 glibc Linux.

1. Extract this entire archive to a local folder.
2. Run StadiumBattleFX-Announcer-Builder from the extracted folder.
3. Select your legally owned, uncompressed Pokemon Stadium (USA) v1.0 ROM.
   ZIP/7-Zip/RAR files must be extracted first. Standard z64, v64, n64, and
   common copier-headered dumps are accepted.
4. Optionally select Pokemon Stadium 2 (USA) for normal/shiny appearances.
5. Select the official voice-free StadiumBattleFX ZIP.
6. Choose a new output ZIP and build it.

Everything runs locally. The personalized output ZIP contains ROM-derived
audio and read-only caches, but no source ROM. Never upload or redistribute
that personalized ZIP.

If the file manager does not launch the app, open a terminal in this folder:

  chmod +x StadiumBattleFX-Announcer-Builder
  ./StadiumBattleFX-Announcer-Builder

The "Open Output Folder" button requires xdg-open, which is included in the
SteamOS desktop environment. Building does not require network access.
