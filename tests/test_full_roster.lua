local loader = love and love.filesystem and love.filesystem.load or loadfile
local all = assert(loader("lib/effects/AllMoveSpecs.lua"))()
assert(#all == 165, "complete move spec must contain all 165 Gen 1 moves")

local moveChunk = assert(loader("lib/effects/MoveSpecs.lua"))
local registry = moveChunk({ require = function(name)
  if name == "effects/AllMoveSpecs" then return all end
  if name == "effects/StadiumMoveRoster" then
    return assert(loader("lib/effects/StadiumMoveRoster.lua"))()
  end
  error(name)
end })
assert(#registry.list == 165, "merged move registry must contain 165 moves")

local seen = {}
local bodyOnly = {}
for id = 1, 165 do
  local spec = assert(registry.get(id), "missing move " .. id)
  assert(not seen[spec.id], "duplicate move " .. spec.id)
  seen[spec.id] = true
  assert(spec.duration or spec.bodyOnly, "move has no lifecycle " .. id)
  assert(spec.kind, "move has no renderer kind " .. id)
  assert(spec.primaryOpcodes and spec.impactOpcodes,
         "move has no Stadium dispatch metadata " .. id)
  if spec.bodyOnly then bodyOnly[#bodyOnly + 1] = id end
end
assert(table.concat(bodyOnly, ",") == "39,45,46,107,150,156",
       "body-only roster did not match Stadium's empty VFX entries")

local generic = assert(loader("lib/effects/GenericMoveRenderer.lua"))()
local assets = { get = function() return nil end }
local player = { attackerIsPlayer = true }
function player:anchor(which)
  if which == "attacker" then return 26, 96 end
  return 124, 56
end

for _, spec in ipairs(all) do
  player.spec = spec
  for _, tick in ipairs({ 0, spec.impactAt, spec.duration - 1 }) do
    player.tick = tick
    local ok, err = pcall(generic.draw, player, assets)
    assert(ok, ("move %d (%s) failed at tick %d: %s")
      :format(spec.id, spec.key, tick, tostring(err)))
  end
end

-- Registration alone is not sufficient: every move must pass the adapter's
-- start-time gates and become the active custom presentation in battle.
local playerChunk = assert(loader("lib/effects/StadiumFxPlayer.lua"))
local Player = playerChunk({ require = function(name)
  if name == "effects/MoveSpecs" then return registry end
  if name == "StadiumAssets" then
    return { has = function() return true end, get = function() return nil end }
  end
  if name == "effects/ThunderShockSpec" then
    return assert(loader("lib/effects/ThunderShockSpec.lua"))()
  end
  if name == "DramaticShapeState" then
    return { read = function()
      return { attackerShowing = true, targetShowing = true }
    end }
  end
  if name == "DramaticShapeHit" then
    return {
      effectiveness = function(n)
        return n < 10 and "resisted" or n > 10 and "super" or "neutral"
      end,
      request = function() return true end,
    }
  end
  if name == "effects/GenericMoveRenderer" then return generic end
  if name == "AttackCinematics" then
    return { start = function() return false end, setTick = function() end,
      stop = function() end }
  end
  error(name)
end })

for id = 1, 165 do
  local inner = { started = nil }
  function inner:start(move) self.started = move end
  function inner:update() end
  function inner:isDone() return true end
  function inner:pollEffects() return {} end
  local adapter = Player.new(inner, function() return true end)
  adapter:start(id, true)
  assert(inner.started == id, "wrapped player did not receive move " .. id)
  assert(adapter.custom, "move did not activate custom adapter " .. id)
  assert(adapter.spec.id == id, "adapter selected wrong move " .. id)
end
print("ok complete 165-move renderer roster")
