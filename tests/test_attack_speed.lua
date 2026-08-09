local loader = love and love.filesystem and love.filesystem.load or loadfile

local spec = { id = 84, key = "THUNDER_SHOCK", kind = "generic",
  impactAt = 3, duration = 8, assets = {} }
local reactions, cameraTicks, cameraStarts, cameraStops = 0, {}, 0, 0

local chunk = assert(loader("lib/effects/StadiumFxPlayer.lua"))
local Player = chunk({ require = function(name)
  if name == "effects/MoveSpecs" then
    return { get = function(id) return id == 84 and spec or nil end }
  end
  if name == "StadiumAssets" then
    return { has = function() return true end, get = function() return nil end }
  end
  if name == "effects/ThunderShockSpec" then
    return { scaleProfiles = {}, portableWorldToPixel = 0.1 }
  end
  if name == "DramaticShapeState" then return { read = function() return nil end } end
  if name == "DramaticShapeAttachment" then
    return { position = function() return nil end }
  end
  if name == "DramaticShapeHit" then
    return {
      effectiveness = function() return "neutral" end,
      request = function() reactions = reactions + 1 return true end,
    }
  end
  if name == "effects/GenericMoveRenderer" then return { draw = function() end } end
  if name == "effects/StadiumAuthenticRenderer" then
    return { draw = function() return false end }
  end
  if name == "effects/StadiumScreenFx" then
    return { clear = function() end }
  end
  if name == "AttackCinematics" then
    return {
      start = function() cameraStarts = cameraStarts + 1 return true end,
      setTick = function(tick) cameraTicks[#cameraTicks + 1] = tick end,
      stop = function() cameraStops = cameraStops + 1 end,
    }
  end
  error(name)
end })

local innerUpdates, innerStarts = 0, 0
local inner = {
  start = function() innerStarts = innerStarts + 1 end,
  update = function() innerUpdates = innerUpdates + 1 end,
  isDone = function() return false end,
  pollEffects = function() return {} end,
}
local speed = 0.5
local player = Player.new(inner, function() return true end, nil,
  function() return {} end, nil, function() return true end,
  function() return true end, nil, function() return speed end)

player:recordDamage({ move = { index = 84 }, damage = 12, typeMult = 10,
  target = { isPlayer = false } })
player:start(84, true)
assert(player.custom and cameraStarts == 1)
for _ = 1, 5 do player:update() end
assert(math.abs(player.tick - 2.5) < 1e-9, "50% clock did not advance fractionally")
assert(reactions == 0, "slowed hit reaction fired before its visual impact")
player:update()
assert(reactions == 1, "slowed hit reaction did not fire at visual impact")
assert(innerUpdates == 3, "inner sound clock did not share the 50% rate")
assert(math.abs(cameraTicks[1] - 0.5) < 1e-9,
  "camera clock was held on integer frames instead of moving smoothly")
for _ = 7, 16 do player:update() end
assert(player:isDone(), "50% presentation did not take exactly twice as long")

-- Zero is a safe OFF setting: it delegates instead of creating an animation
-- whose completion tick can never be reached.
speed = 0
player:start(84, true)
assert(not player.custom, "0% left a frozen custom presentation active")
assert(innerStarts == 2, "0% did not delegate to the normal Gen1 player")
assert(cameraStarts == 1, "0% started an attack camera")

-- Moving the setting to zero during a move also releases the camera and
-- resumes the already-started inner player instead of hanging mid-attack.
speed = 0.5
player:start(84, true)
player:update()
local updatesBeforeFallback = innerUpdates
speed = 0
player:update()
assert(not player.custom and cameraStops > 0,
  "switching to 0% mid-attack did not release the custom camera")
assert(innerUpdates == updatesBeforeFallback + 1,
  "switching to 0% mid-attack did not resume the Gen1 player")

print("ok configurable attack speed")
