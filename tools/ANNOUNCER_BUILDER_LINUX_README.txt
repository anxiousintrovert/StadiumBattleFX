StadiumBattleFX Announcer Builder — experimental SteamOS/Linux build

Target: Steam Deck Desktop Mode and x86-64 glibc Linux.

1. Extract this entire archive to a local folder.
2. Run StadiumBattleFX-Announcer-Builder from the extracted folder.
3. Select your legally owned Pokemon Stadium (USA) v1.0 ROM.
4. Select the official voice-free StadiumBattleFX ZIP.
5. Choose a new output ZIP and build it.

Everything runs locally. The personalized output ZIP contains ROM-derived
audio and a copy of the selected ROM for the sandboxed runtime. Never upload
or redistribute that personalized ZIP.

If the file manager does not launch the app, open a terminal in this folder:

  chmod +x StadiumBattleFX-Announcer-Builder
  ./StadiumBattleFX-Announcer-Builder

The "Open Output Folder" button requires xdg-open, which is included in the
SteamOS desktop environment. Building does not require network access.
