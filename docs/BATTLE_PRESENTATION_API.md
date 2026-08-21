# StadiumBattleFX Battle Presentation API 1

Status: **2.0 development contract**. The Lua surface is versioned independently
from the mod. Breaking changes require a new API major.

This document is normative. It is intentionally complete enough for a mod
developer—or an LLM working without StadiumBattleFX source context—to implement
and validate a compatible provider.

## Ownership boundary

StadiumBattleFX 2.0 is the battle-presentation host. It owns:

- the player-facing selectors for arenas, models, animations, cameras, effects,
  announcers, HUDs, overlays, and transitions;
- battle-presentation lifecycle dispatch and safe fallback;
- Stadium model extraction, rendering, animation, attachments, reactions, and
  move presentation;
- the active battle context shared with providers.

Dramaless 2.0 owns voxel environments. It may register a voxel arena provider,
but it does not own Pokemon models, battle animations, the battle selector, or
the dispatch API. Other mods have the same standing as Dramaless.

The API never uses provider priority. The player's selection is authoritative.

Every registry mutation, selection fallback, availability failure, protected
provider error, and lifecycle transition is written to StadiumBattleFX's
diagnostic log. Providers should log through `context.services.log` so one
export contains the whole presentation stack. Do not write per-frame messages.

For machine-readable entries, use
`context.services.log:event("your-mod", "event-name", fields)`. Fields must be
scalar values; keys are sorted in the exported line. Use
`context.services.log:scope("your-mod")` for ordinary scoped
`info`/`warn`/`error` calls. Never log ROM bytes, save contents, access tokens,
or a player's full file path.

## Discovery and version gate

```lua
local stadium = mod.find("STADIUM_BATTLE_FX")
local api = stadium and stadium.exports and stadium.exports.battles
if not (api and api.version == 1) then
  return -- StadiumBattleFX is absent or the contract is unsupported
end
```

Do not require StadiumBattleFX private files through `exports.lib`. The only
stable integration surface is `exports.battles`.

A provider may register during its entry point. If it needs the finalized mod
set, it may register from `mods.loaded`; registration is idempotent only when
the exact same owner, slot, local ID, and provider object are repeated.

StadiumBattleFX is optional for provider-only mods. Declare it as an optional
dependency when load ordering is useful. Do not make Dramaless a dependency of
a battle provider.

## Slots and selector keys

| Slot | Saved option key | Provider responsibility |
| --- | --- | --- |
| `arena` | `provider_arena` | World/stage selection and rendering |
| `models` | `provider_models` | Battler models, poses, attachments, reactions |
| `animations` | `provider_animations` | Move animation program and timing |
| `camera` | `provider_camera` | Battle and phase camera direction |
| `effects` | `provider_effects` | Particles and post-processing |
| `announcer` | `provider_announcer` | Spoken battle callouts |
| `hud` | `provider_hud` | Battle HUD replacement or decoration |
| `overlay` | `provider_overlay` | Screen-space battle overlay |
| `transitions` | `provider_transitions` | Battle enter/exit transitions |

Each selector contains `STADIUM DEFAULT`, registered providers for that slot,
and `OFF`. `STADIUM DEFAULT` means the StadiumBattleFX built-in for that slot;
it never means “whichever mod loaded first.” `OFF` is terminal and deliberately
disables the slot.

Provider IDs are stored as `OWNER_ID:local-id`. They are stable save-data IDs,
so never rename one after release without a migration.

## Registering a provider

```lua
local id = api:registerComponent(
  mod.id or "MY_VOXEL_MOD",
  "arena",
  "voxel-map",
  {
    label = "VOXEL MAP",
    description = "Stages battles in the current voxel environment",
    provider = provider,
    available = function(context)
      return rendererIsReady()
    end,
  })
```

Arguments:

- `owner`: non-empty manifest ID.
- `slot`: one of the exact slot names above.
- `localId`: letters, digits, `.`, `_`, and `-` only.
- `definition.label`: non-empty player-facing label.
- `definition.description`: optional explanatory text.
- `definition.provider`: table implementing the slot contract.
- `definition.available(context, entry)`: optional, protected-call capability
  check. Return truthy only when the provider can currently be selected.

`priority` is rejected. Duplicate IDs with a different provider are rejected.

Registration returns the canonical `OWNER_ID:local-id` string.

## Registry and selection methods

```lua
api.version                                      -- integer: 1
api.FALLBACK                                     -- unique sentinel
api:enabled()                                    -- true when STADIUM FX is enabled
api:registerComponent(owner, slot, id, definition)
api:componentList(slot)                          -- copied metadata array
api:selectedId(slot)                             -- saved canonical ID/default/off
api:resolve(slot, context)                       -- provider, metadata | nil
api:isSelected(slot, canonicalId)                -- boolean
api:slots()                                      -- copied slot definition array
```

`componentList` returns metadata, not mutable registry storage. `resolve`
returns the selected usable provider. It returns the Stadium built-in for
`stadium:default`, and `nil` for `off`, an unavailable provider, or a stale
saved ID. A stale/unavailable selection safely falls back to the built-in and
is reported once in the diagnostic log.

Registration is independent of the player's current setting. A provider that
would take presentation ownership must check `api:enabled()` from its
capability/begin path so it remains inactive while **STADIUM FX** is off.

## Common lifecycle

The host calls only methods implemented by the selected provider. Every call
is protected. A provider error disables that provider for the current battle,
records a diagnostic, and continues with the Stadium built-in or engine
fallback. Providers must not call another selected provider directly.

```lua
provider:available(context)                 -- optional boolean capability
provider:begin(context)                     -- battle accepted/initialized
provider:event(context, name, payload)      -- engine battle event
provider:update(context, dt)                -- fixed-step update
provider:drawWorld(context)                 -- world/depth pass
provider:drawScreen(context)                -- 160x144 battle surface
provider:finish(context, reason)             -- release battle-local state
provider:invalidate()                        -- release GPU/cache state
```

Return `api.FALLBACK` from `begin` or a specialized acquisition method to
decline only the current battle. Returning `nil` from ordinary lifecycle calls
means “no result,” not fallback. Never throw to signal an unsupported battle.

Lifecycle order:

```text
resolve -> available -> begin
                    -> event/update/drawWorld/drawScreen (zero or more)
                    -> finish
invalidate may occur outside a battle after graphics/resource reset
```

## Battle context schema

All fields are read-only to providers unless a method explicitly documents an
output table. Unknown fields must be ignored for forward compatibility.

```lua
context = {
  apiVersion = 1,
  battle = battleState,       -- engine object; do not retain after finish
  game = game,
  encounter = {
    kind = "wild" | "trainer",
    trainerId = string | number | nil,
    mapId = string | nil,
    partyIndex = number | nil,
  },
  arena = arenaOrNil,         -- result selected by the arena slot
  sides = {
    player = { battler = object, model = object | nil },
    enemy  = { battler = object, model = object | nil },
  },
  phase = "intro" | "command" | "attack" | "damage" | "faint" | "exit",
  services = {               -- host-owned, capability-checked helpers
    project = function(x, y, z) return screenX, screenY end,
    renderSize = { width = number, height = number },
    withNativeBattlePics = function(callback, ...)
      return ok, ...          -- scoped engine-pic capture; API 1 additive
    end,
    log = logger,
  },
}
```

Do not mutate `battle`, replace `animPlayer`, or retain engine/model references
after `finish`. Use event payloads for authoritative move, damage, switch,
status, and faint timing.

## Arena provider contract

An arena provider may implement:

```lua
provider:arena(context) -> arena | api.FALLBACK
provider:begin(context, arena)
provider:update(context, dt, arena)
provider:cast(context, shadowMap, arena, groundY)
provider:drawWorld(context, arena, groundY)
provider:render(context, arena, drawActors) -> Canvas | true | api.FALLBACK
provider:finish(context, reason)
```

The returned arena is provider-owned opaque data plus these optional common
fields: `id`, `map`, `player`, `enemy`, `mid`, `camera`, and `portable`.
StadiumBattleFX passes it back unchanged and exposes it as `context.arena`.

`render` is the advanced environment-provider path. The arena provider owns
its canvas, depth buffer, terrain shader, and camera, then calls
`drawActors({ vp = rowMajorMatrix, project = optionalFunction,
groundY = optionalNumber, width = optionalNumber, height = optionalNumber })`
at the point
where selected models should enter the same depth pass. Return the finished
Canvas for StadiumBattleFX to composite, `true` if the provider already drew
to the active battle surface, or `FALLBACK` to request the built-in arena.
Simple arenas omit `render` and use `drawWorld` inside the host's standard
Stadium scene. Never call a model provider directly.

External model providers own their graphics state in `drawWorld`. The host's
private Stadium mesh shader is applied only to its built-in Stadium model
provider; it is never imposed on an external provider inside an advanced
arena's depth pass.

Dramaless's voxel provider should return `api.FALLBACK` when its authored
location is unsuitable and its generic same-map search also fails. It must not
construct Stadium B discs; that legacy mode is retired.

`withNativeBattlePics` exists for model providers that capture the engine's
side-only battle-picture layer. It temporarily bypasses the host's ordinary
native-picture suppression only for the supplied callback. Providers must not
retain the callback or use it to draw directly to the final battle UI.

## Model provider contract

```lua
provider:install(context) -> truthy | api.FALLBACK
provider:begin(context, arena)
provider:update(context, dt)
provider:covers(context, side) -> boolean
provider:showing(context, side) -> boolean
provider:footprint(context, side) -> number | nil
provider:drawWorld(context, pull)
provider:cameraLocked(context) -> boolean
provider:attachment(context, side, tag) -> screenX, screenY | nil
provider:attachmentTags(context, side, moveId, stage) -> tagA, tagB | nil
provider:center(context, side) -> screenX, screenY | nil
provider:hit(context, side, effectiveness)
provider:faint(context, side, disposition)
provider:finish(context, reason)
```

`side` is exactly `"player"` or `"enemy"`. Attachment tag `0x64` is the
conventional move origin; `0xFF` requests model center. Missing attachments
return `nil` and the host uses its staged 2D anchor. `covers` decides whether
the engine's ordinary Pokemon card is hidden for that side. `cameraLocked` is
optional and should be true only for a mixed screen/world composition that
cannot follow a directed camera, such as a native player back sprite pinned
to the battle menu while the enemy remains in the arena.

## Animation, camera, and service slots

The `animations` provider receives move events and may return an animation
program from `startMove(context, payload)`. The `camera` provider may implement
`claim(context, phase)` and `shot(context, phase, progress, base, arena)`.
`base` is the host's safe idle pose and `arena` is the active arena record. A
successful shot returns `pose, pitch`; `pose` contains `eye`, `focus`, and `fov`.
The host also publishes the resolved result to arena renderers as
`context.services.camera = { pose = pose, pitch = pitch }`. `effects`,
`announcer`, `hud`, `overlay`, and `transitions` use the common lifecycle and
their slot-specific event methods when present. Exact additions within API 1
will be optional methods; providers must ignore events they do not understand.

Camera ownership is phase-scoped. Returning truthy from `claim` owns only the
requested phase. It does not suppress models, animations, effects, audio, or
announcer dispatch.

### Battle Cinematics transition adapter

Battle Cinematics 0.7.96 predates this API. It wraps the `BattleCam` table from
one of its supported Shape-family backends. At `mods.loaded`, SBFX finds that
same table through the backend's existing `exports.lib`, verifies BC's official
wrapper marker, and registers `BATTLE_CINEMATICS:camera`. The final wrapped pose
then drives Stadium-owned or voxel-map arenas without modifying the Battle
Cinematics package. Detection does not gate on a version number, so later
releases using the same hook remain compatible. A protocol-1 release may narrow
ownership with its phase claims. A mod that registers an API-native camera
provider does not need the adapter.

### Battle Cinematics camera ownership protocol 1

Battle Cinematics may independently publish a read-only export:

```lua
mod.exports.cameraOwnership = function()
  return {
    protocol = 1,
    claims = {
      passive = true,
      intro = true,
      attack = true,
      faint = true,
    },
  }
end
```

Each boolean describes configuration-level ownership of only that camera
phase. StadiumBattleFX queries the export lazily and maps its `damage` phase to
the `attack` claim. A missing export, a query error, an unknown protocol, or a
missing claim fails open to Stadium's normal camera. The contract does not
grant ownership of arenas, actors, models, animations, effects, UI, or audio.

The export and Stadium support do not need synchronized releases. A Battle
Cinematics build may publish protocol 1 before StadiumBattleFX 2.0 is present;
the function is inert until a compatible presentation host queries it.

## Compatibility and failure rules

- API 1 providers must capability-check optional methods.
- StadiumBattleFX protects every external call with `pcall`.
- One provider's failure must not stop battle logic or another slot.
- No provider may silently select itself based on load order.
- No provider may mutate another mod's options.
- `OFF` is always respected.
- A provider may decline per battle with `FALLBACK`.
- Saved unknown provider IDs fall back safely and remain diagnosable.
- Registry metadata is copied on read so callers cannot rewrite the catalog.

## Minimal compatibility checklist

1. Use a unique manifest ID and stable local provider ID.
2. Gate on `api.version == 1`.
3. Register only slots the mod actually owns.
4. Return `FALLBACK` for unsupported encounters.
5. Do not depend on Dramaless private modules or StadiumBattleFX private files.
6. Treat the context as read-only and ignore unknown fields.
7. Release retained battle resources in `finish` and GPU state in `invalidate`.
8. Test with your provider selected, `STADIUM DEFAULT`, `OFF`, and your mod
   removed while its old ID remains in save data.
