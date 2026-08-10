# Announcer Builder distribution and security notes

The builder is a local conversion utility. It reads a player-selected Stadium
ROM, writes temporary MORT and WAV files in one private temporary directory,
and creates one new ZIP selected by the player. It does not download code,
connect to the network, change the supplied ROM or base mod ZIP, request
administrator access, or run a shell command.

## Release requirements

Publish `StadiumBattleFX-Announcer-Builder-windows.zip`, produced by
`build_announcer_builder.ps1`, rather than a PyInstaller `--onefile` EXE.
The release ZIP contains an ordinary application directory: the GUI EXE, its
runtime DLLs, and the small MORT decoder are visible for inspection before the
user runs anything.

Before public distribution, sign both `StadiumBattleFX-Announcer-Builder.exe`
and `mort_decoder.exe` with a trusted Authenticode code-signing certificate:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_announcer_builder.ps1 -CertificateThumbprint YOUR_CERTIFICATE_THUMBPRINT
```

Publish the generated `.sha256` file alongside the release ZIP, the source
revision used for the build, and the certificate publisher name. A signature
and reproducible source are the appropriate answer to Windows reputation
checks; changing packer tricks to evade scanners is not.

## Scanner notes

Heuristic engines can still flag unsigned, low-reputation software. A scan is
not proof of malicious behavior, and this document is not a claim that every
engine will report the same result. Investigate a detection by comparing the
published SHA-256 and Authenticode signature, then submit the exact signed
release to the vendor as a false-positive report where appropriate.
