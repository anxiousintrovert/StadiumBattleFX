# StadiumBattleFX Stadium Model API 1

Status: public additive contract. Breaking changes require a new API major.

This API lets another mod acquire and render isolated Pokemon Stadium or
Pokemon Stadium 2 actors without importing StadiumBattleFX private modules.
The player's ROM-derived assets remain private and are never returned as ROM
bytes or written into another mod.

For ordinary Battle Presentation API arenas, prefer the host-supplied
`drawActors(world)` callback. It renders whichever model provider the player
selected, including Stadium 1 or Stadium 2, and preserves mix-and-match
selection. Use this actor API only when a mod genuinely needs a Stadium actor
outside that callback.

## Discovery

```lua
local stadium = mod.find("STADIUM_BATTLE_FX")
local models = stadium and stadium.exports and stadium.exports.models
if not (models and models.version == 1) then return end
```

The API is available as `STADIUM_BATTLE_FX.exports.models`.

## Sources and availability

Stable source IDs are:

- `models.STADIUM1` / `"stadium1"`: the imported Pokemon Stadium model.
- `models.STADIUM2` / `"stadium2"`: the imported Stadium 2 appearance on the
  Stadium 1 Gen 1 skeleton and animation set.
- `models.SELECTED` / `"selected"`: the model pack selected in SBFX options.

```lua
models.sources()                    -- copied { id, label } records
models.available(source, species)  -- boolean; species is optional
```

`species` is a National Dex number from 1 through 151. Availability is
read-only and never starts a ROM import. A missing cache returns false.

## Acquiring an actor

```lua
local actor, err = models.acquire(
  models.STADIUM2,
  25,
  "shiny",
  { side = "enemy" }
)
if not actor then return end
```

`variant` is `"normal"` or `"shiny"`. Unknown variants become `"normal"`.
`side` may be `"player"` or `"enemy"`; other values become `"external"`.
Every successful acquisition owns a separate animation/rig instance. Call
`actor:release()` when finished. Release is idempotent and a released actor
declines all later work.

## Actor animation and geometry

```lua
actor:update(dt)
actor:play("idle" | "entrance" | "hit" | "faint")
actor:attack(moveId)
actor:seekAttack(moveId, effectTick)
actor:hit()
actor:faint("collapse" | "recall")
actor:sync(moveId)                 -- body frame, read-only timing row | nil

local matrix = actor:matrix(x, groundY, z, faceX, faceZ)
actor:worldHeight()
actor:worldRadius()
actor:build()                      -- optional explicit CPU pose/skin step
actor:attachment(tag)              -- animated model-space x, y, z | nil
actor:moveAttachmentTags(moveId)   -- primaryTag, secondaryTag | nil
```

The matrix is row-major. `faceX` and `faceZ` describe the direction the actor
faces. Attachment tag `0xFF` means no attachment and returns nil.

## Rendering

The convenience path establishes SBFX's model shader, draws one actor, and
restores the caller's shader, depth, cull, blend, and color state:

```lua
local ok, err = models.draw(actor, vp, matrix, pull)
```

`vp` is a row-major view-projection matrix. `pull` is an optional camera-ward
depth offset and defaults to zero.

For multiple actors, enter the renderer once:

```lua
local ok, err = models.withRenderer(vp, function()
  assert(player:draw(playerMatrix, 0))
  assert(enemy:draw(enemyMatrix, 0))
end)
```

The callback is protected. `withRenderer` returns `true` plus callback results,
or `false, error`. Graphics state is restored after success or failure.

An advanced arena that already receives `drawActors(world)` must not use this
API to bypass the player's `BTL MODELS` selection. Call `drawActors` with its
view-projection matrix instead:

```lua
drawActors({
  vp = vp,
  groundY = groundY,
  width = renderWidth,
  height = renderHeight,
})
```

## Shadow casting

`actor:cast(shadowMap, matrix)` sends the current posed rig to a compatible
shadow-map object. The shadow map must implement the draw method expected by
the Stadium rig. Unsupported objects return false rather than changing the
actor lifecycle.

## Safety and compatibility rules

1. Gate on `models.version == 1` and ignore unknown future fields.
2. Never retain an actor after `release` or a graphics reset.
3. Do not mutate actor internals or returned timing rows.
4. Prefer Battle Presentation `drawActors` inside an API arena.
5. Do not call `models.draw` unless a canvas with a depth attachment is active.
6. A missing model or cache is an ordinary fallback, not an error condition.
