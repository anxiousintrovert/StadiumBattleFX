# StadiumBattleFX project instructions

## Compatibility memory

Before changing compatibility behavior, dependency metadata, or the Battle
Presentation API, read `docs/COMPATIBILITY_ROADMAP.md`.

Treat compatibility as pairwise: StadiumBattleFX must work with each recorded
mod independently. Do not diagnose, prevent, or take ownership of conflicts
between those third-party mods.

When preparing upstream pull requests:

- Prefer stable public registration, lifecycle, or encounter-context APIs over
  reading another mod's private state.
- Do not edit or vendor third-party mod source into StadiumBattleFX.
- Reconfirm the upstream manifest ID and current release before proposing a PR.
- Update `docs/COMPATIBILITY_ROADMAP.md` when support, versions, URLs, or proposed
  upstream integration points change.
