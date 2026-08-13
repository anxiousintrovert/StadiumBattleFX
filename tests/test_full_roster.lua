local loader = love and love.filesystem and love.filesystem.load or loadfile
love = love or { graphics = {} }
for _, name in ipairs({
  "arc", "circle", "draw", "ellipse", "line", "polygon", "rectangle",
  "setColor", "setLineWidth",
}) do
  love.graphics[name] = love.graphics[name] or function() end
end
love.graphics.getBlendMode = love.graphics.getBlendMode
  or function() return "alpha", "alphamultiply" end
love.graphics.getLineWidth = love.graphics.getLineWidth or function() return 1 end
love.graphics.getColor = love.graphics.getColor or function() return 1, 1, 1, 1 end
love.graphics.setBlendMode = love.graphics.setBlendMode or function() end
local all = assert(loader("lib/effects/AllMoveSpecs.lua"))()
assert(#all == 165, "complete move spec must contain all 165 Gen 1 moves")

local moveChunk = assert(loader("lib/effects/MoveSpecs.lua"))
local registry = moveChunk({ require = function(name)
  if name == "effects/AllMoveSpecs" then return all end
  if name == "effects/StadiumMoveRoster" then
    return assert(loader("lib/effects/StadiumMoveRoster.lua"))()
  end
  if name == "effects/StadiumFidelityProfiles" then
    return assert(loader("lib/effects/StadiumFidelityProfiles.lua"))()
  end
  if name == "effects/StadiumTimingProfiles" then
    return assert(loader("lib/effects/StadiumTimingProfiles.lua"))()
  end
  if name == "effects/StadiumRosterCalibration" then
    return assert(loader("lib/effects/StadiumRosterCalibration.lua"))()
  end
  if name == "effects/StadiumNativePrograms" then
    return assert(loader("lib/effects/StadiumNativePrograms.lua"))()
  end
  error(name)
end })
assert(#registry.list == 165, "merged move registry must contain 165 moves")

local seen = {}
local bodyOnly = {}
local calibration = {}
for id = 1, 165 do
  local spec = assert(registry.get(id), "missing move " .. id)
  assert(spec.nativeProgram and spec.nativePrograms,
    "missing native scheduler binding for move " .. id)
  assert(not seen[spec.id], "duplicate move " .. spec.id)
  seen[spec.id] = true
  assert(spec.duration or spec.bodyOnly, "move has no lifecycle " .. id)
  assert(spec.kind, "move has no renderer kind " .. id)
  assert(spec.primaryOpcodes and spec.impactOpcodes,
         "move has no Stadium dispatch metadata " .. id)
  if spec.bodyOnly then bodyOnly[#bodyOnly + 1] = id end
  calibration[spec.calibration] = (calibration[spec.calibration] or 0) + 1
end
assert(table.concat(bodyOnly, ",") == "39,45,46,107,150,156",
       "body-only roster did not match Stadium's empty VFX entries")
assert(calibration["stadium1-source-calibrated"] == 25,
       "source-calibrated coverage changed unexpectedly")
assert(calibration["stadium-dispatch-traced"] == 19,
       "dispatch-traced coverage changed unexpectedly")
assert(calibration["stadium-timing-calibrated-v1"] == 121,
       "Stadium timing profiles must cover every remaining move")

local waterfall = registry.get(127)
assert(waterfall.stadiumProgram == "water" and waterfall.variant == "waterfall",
       "Waterfall did not select its borderless screen program")

local slash = registry.get(163)
assert(slash.stadiumDispatch.primary == "0D" and slash.primaryAsset == "scratch_claw",
       "Slash did not inherit its Stadium scratch program texture")
assert(slash.geometrySource == "stadium-fragment62-resources",
       "Slash has no Stadium geometry provenance")
assert(slash.timingSource == "stadium-fragment62-controller",
       "Slash has no Stadium timing provenance")
local rockSlide = registry.get(157)
assert(rockSlide.stadiumDispatch.primary == "3F" and rockSlide.assetFootprint.width >= 24,
       "Rock Slide has no dispatch-specific footprint")

local screenFx = assert(loader("lib/effects/StadiumScreenFx.lua"))()
local generic = assert(loader("lib/effects/GenericMoveRenderer.lua"))({
  require = function(name)
    assert(name == "effects/StadiumScreenFx", name)
    return screenFx
  end,
})
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
local genericDraws = 0
local trackedGeneric = setmetatable({ draw = function(...)
  genericDraws = genericDraws + 1
  return generic.draw(...)
end }, { __index = generic })
local attackerShowing = true
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
      return { attackerShowing = attackerShowing, targetShowing = true }
    end }
  end
  if name == "DramaticShapeAttachment" then
    return { position = function() return nil end }
  end
  if name == "DramaticShapeHit" then
    return {
      effectiveness = function(n)
        return n < 10 and "resisted" or n > 10 and "super" or "neutral"
      end,
      request = function() return true end,
    }
  end
  if name == "effects/GenericMoveRenderer" then return trackedGeneric end
  if name == "effects/StadiumAuthenticRenderer" then
    return assert(loader("lib/effects/StadiumAuthenticRenderer.lua"))({
      require = function(innerName)
        assert(innerName == "effects/StadiumScreenFx", innerName)
        return screenFx
      end,
    })
  end
  if name == "effects/StadiumScreenFx" then return screenFx end
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

-- Cartridge assets must not turn body-driven contact attacks into an
-- impact-only blank when the battle is using ordinary Gen 1 combatants.
attackerShowing = false
local fallbackInner = {}
function fallbackInner:start() end
function fallbackInner:update() end
function fallbackInner:isDone() return true end
function fallbackInner:pollEffects() return {} end
local fallbackAdapter = Player.new(fallbackInner, function() return true end)
fallbackAdapter:start(1, true) -- Pound uses the dedicated tackle burst.
local beforeFallbackDraw = genericDraws
fallbackAdapter.tick = 8
fallbackAdapter:draw()
assert(genericDraws == beforeFallbackDraw + 1,
  "body-driven attack did not use its visible no-model fallback")
print("ok complete 165-move renderer roster")
