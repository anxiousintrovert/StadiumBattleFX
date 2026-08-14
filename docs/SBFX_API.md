# StadiumBattleFX 2.0 API reference

This document describes the public StadiumBattleFX (SBFX) battle-presentation
API implemented by StadiumBattleFX 2.0.0. The API has its own major version;
SBFX 2.0.0 exposes battle-presentation API **1**.

The stable integration surface is `STADIUM_BATTLE_FX.exports.battles`. Other
exports are SBFX features, status views, or compatibility seams and are not
part of battle-presentation API 1 unless this document says otherwise.

## What the API does

SBFX owns nine player-selectable presentation slots. Another mod can register
a provider in any slot it implements. The player then chooses that provider,
`STADIUM DEFAULT`, or `OFF` in the SBFX options menu.

| Slot | Option key | Purpose |
| --- | --- | --- |
| `arena` | `provider_arena` | Battlefield acquisition and rendering |
| `models` | `provider_models` | Battler rendering, anchors, and reactions |
| `animations` | `provider_animations` | Move-presentation lifecycle/events |
| `camera` | `provider_camera` | Phase-specific camera direction |
| `effects` | `provider_effects` | Effect lifecycle/events |
| `announcer` | `provider_announcer` | Announcer lifecycle/events |
| `hud` | `provider_hud` | Battle HUD screen pass |
| `overlay` | `provider_overlay` | Battle overlay screen pass |
| `transitions` | `provider_transitions` | Battle transition screen pass |

There is no provider priority. Registration does not select a provider, and
load order does not win a slot. The saved player choice is authoritative.

## Discovering and version-gating the API

```lua
local stadium = mod.find("STADIUM_BATTLE_FX")
local api = stadium and stadium.exports and stadium.exports.battles

if not (api and api.version == 1) then
  return -- SBFX is absent or exposes an unsupported API major
end
```

A provider-only mod may treat SBFX as optional. Declare SBFX as an optional
dependency if deterministic load ordering is useful, and still perform the
runtime check above. Do not load files from SBFX's `lib` directory; they are
private implementation details.

## Registering a provider

Register during the mod entry point, or during `mods.loaded` if the provider
needs to inspect the finalized mod set:

```lua
local provider = {}

function provider:arena(context)
  local arena = buildArena(context)
  return arena or api.FALLBACK
end

function provider:begin(context, arena)
  self.arena = arena
end

function provider:finish(context, reason)
  self.arena = nil
end

local canonicalId = api:registerComponent(
  mod.id or "MY_MOD",
  "arena",
  "my-arena",
  {
    label = "MY ARENA",
    description = "Uses My Mod's current world as the battle stage",
    provider = provider,
    available = function(context, entry)
      return rendererReady()
    end,
  }
)
```

`registerComponent(owner, slot, localId, definition)` validates the following:

- `owner` is a non-empty string. Use the registering mod's manifest ID.
- `slot` is one of the nine exact slot names above.
- `localId` is a non-empty string matching `^[%w_.-]+$`: letters, digits,
  underscore, dot, and dash.
- `definition.label` is a non-empty player-facing string.
- `definition.description` is optional.
- `definition.provider` is a table.
- `definition.available` is optional.
- `definition.priority` must be absent. Supplying it is an error.

The return value is the canonical ID `owner .. ":" .. localId`, such as
`MY_MOD:my-arena`. Canonical IDs are written to save options; keep them stable
after release or provide a save migration.

Registration is idempotent only when the same canonical ID in the same slot
is registered again with the exact same provider table. Reusing the ID with a
different table raises an error. Re-registering the same table returns the ID
without replacing its original label, description, or availability function.

### Availability callback calling convention

Before resolving a provider, SBFX verifies that its owner mod is still loaded
and then calls an availability function, if present. It uses
`definition.available` first and otherwise `definition.provider.available`.
The exact call is a protected plain-function call:

```lua
available(context, entry)
```

It is **not** invoked as `provider:available(context)`. For unambiguous code,
put the function on the registration definition as shown above. A truthy value
means usable; `false`, `nil`, or an error means unavailable. An availability
error is logged and treated as unavailable.

## Public API table

```lua
api.version                                       -- 1
api.FALLBACK                                      -- unique table sentinel

api:registerComponent(owner, slot, localId, definition) -> canonicalId
api:componentList(slot)                           -> entry[]
api:selectedId(slot)                              -> string
api:resolve(slot, context)                        -> provider, entry | nil, nil
api:isSelected(slot, canonicalId)                 -> boolean
api:slots()                                       -> slotDefinition[]
```

### `componentList(slot)`

Returns external registrations sorted case-insensitively by label, then by
canonical ID. It does not include `STADIUM DEFAULT` or `OFF`.

Each result is a new metadata table:

```lua
{
  id = "MY_MOD:my-arena",
  owner = "MY_MOD",
  slot = "arena",
  label = "MY ARENA",
  description = "...", -- nil when omitted
  provider = provider,  -- original shared provider identity
}
```

Changing the returned metadata table does not mutate the registry. The
`provider` field is deliberately the registered provider table, not a copy.

### `selectedId(slot)` and `isSelected(slot, id)`

`selectedId` returns the raw saved choice. A missing, empty, or non-string
option reads as `stadium:default`. The reserved IDs are:

```lua
"stadium:default"
"off"
```

`isSelected` compares against that raw choice. It does not resolve
availability or SBFX's automatic default-arena policy. Consequently,
`isSelected("arena", "stadium:default")` can be true while `resolve` returns a
compatible external arena preferred by SBFX's built-in automatic policy.

### `resolve(slot, context)`

`resolve` returns the provider that would currently serve the slot and a copy
of its metadata. Its behavior is:

| Saved choice | Result |
| --- | --- |
| `off` | `nil, nil`; the slot is deliberately disabled |
| available external ID | that external provider and metadata |
| stale, unloaded, unavailable, or availability-error external ID | available SBFX built-in, otherwise `nil, nil` |
| `stadium:default` | available SBFX built-in, subject to the arena policy below |
| unavailable SBFX built-in | `nil, nil` |

An unknown or unavailable external selection remains in the saved option; it
is not silently rewritten. SBFX logs the fallback once.

For the `arena` slot only, `STADIUM DEFAULT` is an **automatic policy** in
2.0.0. Ordinary battles may resolve the registered
`DRAMALESS_SHAPE:voxel-map` provider when it is available, while Stadium boss
venues resolve the SBFX arena. Explicitly choosing a provider bypasses that
automatic choice. Other slots resolve their SBFX built-in for
`stadium:default`.

`resolve` is safe for inspection, but it does not start a provider. SBFX's host
resolves and acquires every slot once at battle start.

### `slots()`

Returns new `{ id, label, help }` tables for all nine slots in the order shown
at the start of this document.

## Provider invocation and failure isolation

Except for the availability callback described earlier, runtime provider
methods use Lua method semantics:

```lua
provider:method(context, ...)
-- equivalent to provider.method(provider, context, ...)
```

Every external runtime call is protected with `pcall`. If a method throws,
SBFX logs the slot, canonical ID, method, and error, then disables that slot's
provider for the rest of the battle. A provider retained after a later
lifecycle failure can still receive `finish` or `invalidate`. A provider whose
`begin` fails or declines is removed immediately and is not subsequently
finished, so `begin` must clean up its own partial initialization before it
throws or declines. One slot's failure does not disable another slot and must
not interrupt battle logic.

A missing method is a successful no-op with a `nil` result.

`api.FALLBACK` is checked only at the acquisition/render decision points
documented below. Returning it from an arbitrary lifecycle method has no
special meaning. Do not throw an error to decline a supported call.

## Battle context

The same context table is retained for one battle and passed to every active
provider. Treat it and all engine objects it references as read-only. Ignore
unknown fields for forward compatibility, and do not retain engine references
after `finish`.

```lua
context = {
  apiVersion = 1,
  battle = battleState,
  game = battleState and battleState.game,

  encounter = {
    kind = battleState and battleState.kind,
    trainerId = battleState and
      (battleState.oppClass or
       (battleState.trainer and battleState.trainer.id)),
    mapId = battleState and battleState.currentMapId and
      battleState:currentMapId() or nil,
    partyIndex = battleState and battleState.partyIndex,
  },

  arena = arena, -- assigned after the arena provider is acquired

  sides = {
    player = { battler = battleState and battleState.player },
    enemy  = { battler = battleState and battleState.enemy },
  },

  phase = "intro",
  groundY = 0,

  services = {
    log = stadiumLogger,
    withNativeBattlePics = function(callback, ...)
      return ok, ...
    end,

    -- Added during rendering, so they may be nil during begin/update/event:
    project = function(x, y, z) return screenX, screenY end,
    renderSize = { width = number, height = number },

    -- Added before an advanced arena's render call:
    camera = { pose = pose, pitch = pitchOrNil },
  },
}
```

The host does not populate `context.progress`. A camera provider receives
`nil` for its `progress` argument in API 1 unless a future compatible host adds
that field.

`phase` starts as `intro` and changes immediately before service providers
receive these events:

| Event | New phase |
| --- | --- |
| `battle.turn_started` | `passive` |
| `battle.turn_ended` | `passive` |
| `battle.move_used` | `attack` |
| `battle.damage_dealt` | `damage` |
| `battle.fainted` | `faint` |
| `battle.battler_switched` | `intro` |
| `battle.ended` | `exit` |

`battle.status_inflicted` is forwarded without changing the current phase.
Event payloads are Gen1Recomp's original payload tables and are the
authoritative source for move, damage, switch, status, and faint details.

### Context services

`services.log` supports `info`, `warn`, `error`, `event`, and `scope`. Prefer
structured, low-frequency diagnostics:

```lua
context.services.log:event("MY_MOD", "arena-begin", {
  arena = context.arena and context.arena.id or "unknown",
})
```

Do not write per-frame messages or log ROM bytes, save contents, credentials,
or full user paths.

`services.withNativeBattlePics(callback, ...)` temporarily permits the
engine's side-only native battle-picture renderer while `callback` executes.
It returns `false, error` when there is no active matching battle session or
the callback throws; otherwise it returns `true` followed by the callback's
results. The permission ends before the function returns. Do not retain the
callback or use it to draw directly onto the final battle UI.

`services.project` maps world coordinates to framebuffer pixels during the
current render pass. `services.renderSize` describes that pass. In an advanced
arena pass, width and height remain `nil` if the arena did not supply them even
though SBFX can still use framebuffer dimensions internally for projection.

## Exact lifecycle order

At `battle.started`, SBFX ends any prior session with reason `replaced`, builds
the context, and acquires slots in this order:

1. `arena`
2. `models`
3. `animations`, `camera`, `effects`, `announcer`, `hud`, `overlay`,
   `transitions`

During each fixed `input.step`, the host updates the arena, models, and then
the seven service slots in that same service-slot order. Events go only to the
seven service slots. Rendering uses the arena and models, followed by the
screen passes described below. At `battle.ended`, all acquired providers are
finished and the context is discarded.

There is intentionally no single callback list shared by all slots. The exact
calls for each slot follow.

## Arena provider contract

An arena provider can implement:

```lua
provider:arena(context) -> arena | api.FALLBACK | nil
provider:begin(context, arena) -> any | false | api.FALLBACK
provider:update(context, dt, arena)
provider:render(context, arena, drawActors) -> Canvas | api.FALLBACK | nil
provider:sky(context, inheritedRgba) -> rgbaTable | nil
provider:drawWorld(context, arena, groundY)
provider:finish(context, reason)
provider:invalidate(context)
```

Acquisition first calls `arena`. Returning `api.FALLBACK` from an explicitly
selected external arena asks SBFX to acquire its built-in arena instead.
Returning `nil` does **not** make that request: SBFX uses its neutral arena
record with no active arena renderer. An error has the same practical result
as `nil` for this acquisition.

If `arena` returns a record, SBFX stores it unchanged in `context.arena` and
calls `begin(context, arena)`. Returning `false` or `api.FALLBACK`, or throwing,
causes SBFX to begin its built-in arena. The built-in can itself fall back to a
neutral, non-rendering arena if unavailable.

An arena record is provider-owned opaque data. These fields are understood by
SBFX and cooperating providers:

```lua
arena = {
  id = "MY_MOD:arena-instance", -- diagnostic identity
  player = { x, z },             -- player battler placement
  enemy = { x, z },              -- enemy battler placement
  mid = { x, z },                -- camera focus origin
  camera = {
    side = number,
    back = number,
    height = number,
    lookX = number,
    lookY = number,
    frameH = number,
  },

  -- Provider-defined fields such as map and portable may also be present.
}
```

Missing placement/camera fields are tolerated; the built-in neutral camera is
used where necessary.

### Advanced arena rendering

If the provider has a `render` method, SBFX calls it before the standard scene
path. The arena owns its canvas, depth buffer, terrain shader, and camera. It
must call `drawActors` at the point selected models should enter that depth
pass:

```lua
drawActors({
  vp = rowMajorViewProjectionMatrix, -- optional if project is supplied
  project = function(x, y, z) return screenX, screenY end, -- optional
  groundY = number,                  -- optional, updates context.groundY
  width = number,                    -- optional render width
  height = number,                   -- optional render height
})
```

External model providers render with their own graphics state and must leave
the private `provider.hostRender` flag unset. SBFX's built-in model provider
sets that flag to enter the private Stadium mesh pass.

Return a Canvas (or equivalent surface accepted by Gen1Recomp's
`renderer:setWorldOverride`) to complete the advanced pass. Return
`api.FALLBACK`, `nil`, or throw to end the arena with reason
`render-fallback`, rebind models to SBFX's built-in arena, and continue through
the standard scene path.

In the 2.0.0 implementation, returning literal `true` is **not** a successful
"already presented" result; it also enters render fallback. Providers must
return the completed surface.

### Standard arena rendering

Without a successful advanced surface, SBFX creates a framebuffer-sized canvas
with a depth buffer, establishes its standard camera, and calls:

```lua
provider:sky(context, { 0, 0, 0, 1 })
provider:drawWorld(context, arena, context.groundY)
```

`sky` may return an RGBA table to replace the inherited clear color. Arena
geometry and SBFX-host-rendered models share the Stadium render pass; external
models draw afterward with their own state. SBFX then supplies the completed
canvas as the renderer's world override.

## Model provider contract

The host directly uses these methods:

```lua
provider:begin(context, arena) -> any | false | api.FALLBACK
provider:update(context, dt)
provider:drawWorld(context, pull)
provider:covers(context, side) -> truthy | falsy
provider:cameraLocked(context) -> truthy | falsy
provider:finish(context, reason)
provider:invalidate(context)
```

`side` is exactly `player` or `enemy`. `pull` is `0` in API 1.

Returning `false` or `api.FALLBACK` from model `begin`, or throwing, disables
models for that battle. Unlike arena rejection, this does not acquire the
built-in model provider as a second attempt. An unavailable or stale selection
has already resolved to the built-in before `begin`.

`covers` is queried only after SBFX has successfully presented a world surface.
A truthy value hides the engine's native Pokemon picture for that side. Until
then, or after a render failure, native pictures remain visible as a safety
fallback.

`cameraLocked` should return truthy only when a mixed 2D/world composition
cannot follow a directed camera. When locked, SBFX uses the arena's base camera
and does not call the selected camera provider for that frame.

## Stadium model appearance sources

Mods that need an isolated Stadium actor outside the Battle Presentation
host can use the versioned `STADIUM_BATTLE_FX.exports.models` service. It can
acquire explicit Stadium 1, Stadium 2, or player-selected actors and exposes
animation, attachment, drawing, and shadow-casting methods without importing
SBFX internals. See [`STADIUM_MODEL_API.md`](STADIUM_MODEL_API.md).

An arena provider should normally keep using its host-supplied
`drawActors(world)` callback. That path honors the player's independently
selected model provider and is what enables arena/model mix-and-match.

Mods that only replace the built-in Stadium model's appearance should use
`STADIUM_BATTLE_FX.exports.modelSources` instead of registering a complete
`models` provider. This keeps StadiumBattleFX's battle state, Stadium 1
animations, move routing, attachments, reactions, camera, and shared render
pass:

```lua
local api = mod.find("STADIUM_BATTLE_FX").exports.modelSources
api:register(mod.id, "my-pack", {
  label = "MY MODEL PACK",
  available = function() return true end,
  load = function(species, variant, stadium1Model)
    -- Return a StadiumPack-compatible model with replacement prims/textures.
    -- `variant` is "normal" or "shiny" from the live battler's explicit
    -- shiny flag (used by SHINY_POKEMON) or Gen 1 DVs.
    return myHybridModel(species, variant, stadium1Model)
  end,
  keep = function(species, variant) end, -- optional cache touch
  invalidate = function() end,           -- optional graphics reset
})
```

The player chooses the source through `BTL MODEL PACK`. A missing, disabled,
unavailable, or failed source falls back per species to the Stadium 1 model.

SBFX's move presenter also capability-checks these model methods through the
same protected dispatcher:

```lua
provider:showing(context, side) -> truthy | falsy
provider:footprint(context, side) -> number | nil
provider:attachment(context, side, tag) -> screenX, screenY | nil
provider:attachmentTags(context, side, moveId, stage) -> tagA, tagB | nil
provider:center(context, side) -> screenX, screenY | nil
provider:moveSync(context, side, moveId) -> table | nil
provider:synchronizeMove(context, side, moveId, effectTick) -> boolean
provider:hit(context, side, effectiveness) -> any | false
provider:faint(context, side, disposition) -> any | false
```

Attachment tag `0x64` is the conventional move origin. A request for tag
`0xFF` is routed to `center` instead of `attachment`. Missing/non-numeric
anchors are ordinary per-frame fallbacks to SBFX's staged 2D anchor.

`effectiveness` is `resisted`, `neutral`, or `super`. `disposition` is
`collapse` or `recall`. Returning literal `false` declines a hit/faint
reaction; `nil` counts as accepted because missing optional methods are
no-ops.

`moveSync` and `synchronizeMove` expose Stadium model timing to SBFX's built-in
move presenter. External model providers may omit them.

The implementation also contains private built-in methods such as `install`
and `cast`; the API 1 host does not dispatch them to external model providers.

## Service-slot contract

`animations`, `camera`, `effects`, `announcer`, `hud`, `overlay`, and
`transitions` are acquired after models. Every one may implement:

```lua
provider:begin(context) -> any | api.FALLBACK
provider:update(context, dt)
provider:event(context, eventName, payload)
provider:finish(context, reason)
provider:invalidate(context)
```

For these seven slots, `api.FALLBACK` from `begin` declines the slot. Literal
`false` does not; only `FALLBACK` or an error disables it at acquisition.

All seven service slots receive lifecycle and battle events in API 1. The host
does not call a separate `startMove` method. An animations provider handles
`battle.move_used` through `event` and any subsequent work in `update`.

After the engine draws the battle surface, SBFX calls this additional method
for the three screen-composition slots, in order:

```lua
hudProvider:drawScreen(context)
overlayProvider:drawScreen(context)
transitionsProvider:drawScreen(context)
```

The logical battle surface is 160x144, although the active renderer may expose
a wider UI. Providers should use the current LÖVE graphics state and
capability-check any renderer-specific behavior.

## Camera provider contract

In addition to the service lifecycle, a non-default camera provider may
implement:

```lua
provider:claim(context, phase) -> truthy | falsy
provider:shot(context, phase, progress, basePose, arena)
  -> pose, pitch | api.FALLBACK
```

`claim` is evaluated per rendered frame and owns only the current camera phase.
If it is truthy, SBFX calls `shot`. A valid pose is:

```lua
{
  eye = { x, y, z },
  focus = { x, y, z },
  fov = radians,
}
```

The pose is accepted only when `eye`, `focus`, and `fov` are all present.
`pitch` is optional provider data forwarded to an advanced arena through
`context.services.camera`. `progress` is currently `nil`, as noted in the
context section. `api.FALLBACK`, an invalid pose, a false claim, a missing
method, or an error leaves the safe base camera in place.

Camera selection does not grant ownership of arenas, models, animations,
effects, UI, or audio.

### Battle Cinematics compatibility

Battle Cinematics 0.7.96 predates API 1. The official package wraps a shared
`BattleCam` table exported by one of its supported Shape-family backends. At
`mods.loaded`, SBFX discovers that already-wrapped table and registers
`BATTLE_CINEMATICS:camera` in the camera selector. BC remains unmodified. This
is a compatibility adapter, not a general API for new camera providers; new
integrations should register through `exports.battles`.

When `stadium:default` is selected for the camera slot, SBFX may also query
Battle Cinematics' optional camera-ownership protocol 1:

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

SBFX maps its `damage` phase to the `attack` claim. A missing export, error,
unknown protocol, or missing claim leaves SBFX's normal camera active.

## Shutdown and invalidation

Normal battle shutdown calls providers in this order:

1. models
2. arena
3. `animations`, `camera`, `effects`, `announcer`, `hud`, `overlay`,
   `transitions`

The usual reason is `battle.ended`. Other host reasons include `replaced`,
`render-fallback`, `arena-fallback`, and `invalidate` as described above.
Providers must tolerate `finish` after an earlier error and make cleanup
idempotent.

Graphics invalidation calls `invalidate(context)` on the active arena, models,
and service providers, then calls the normal finish sequence with reason
`invalidate`. Release battle-local references in `finish` and graphics/cache
resources in `invalidate`.

## Compatibility checklist

1. Gate on `api.version == 1`.
2. Use the manifest ID as `owner` and never rename a released local ID without
   a migration.
3. Register only slots the mod actually implements.
4. Put availability on `definition.available` and remember its plain-function
   calling convention.
5. Use `api.FALLBACK` only at documented acquisition/render points.
6. Treat context and event payloads as read-only; ignore unknown fields.
7. Do not call another selected provider or mutate another mod's options.
8. Make `finish`/`invalidate` safe after partial initialization or failure.
9. Test the provider explicitly selected, `STADIUM DEFAULT`, `OFF`, a thrown
   callback, an unavailable provider, and a stale saved ID after mod removal.
