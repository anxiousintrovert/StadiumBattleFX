# MORT decoder helper

This directory contains the decode-only portion of `CMORTDecoder`, reverse
engineered from Pokemon Stadium by SubDrag and released as public domain in
N64 Sound Tool. `main.cpp` adds a small command-line wrapper and PCM WAV
writer for the local StadiumBattleFX announcer builder.

The helper accepts one extracted MORT stream and produces mono 16-bit PCM at
the sample rate stored in the stream. No Pokemon Stadium audio or ROM data is
included here or in public StadiumBattleFX packages.
