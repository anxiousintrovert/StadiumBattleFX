local loader = love and love.filesystem and love.filesystem.load or loadfile
local reactions = {}
local spec = { id = 84, key = "THUNDER_SHOCK", kind = "generic",
  impactAt = 3, duration = 8, assets = {} }
local caller = { id = 118, key = "METRONOME", kind = "generic",
  impactAt = 2, duration = 5, assets = {} }
local chunk = assert(loader("lib/effects/StadiumFxPlayer.lua"))
local Player = chunk({ require = function(name)
  if name == "effects/MoveSpecs" then
    return { get = function(id)
      if id == 84 or id == "THUNDER_SHOCK" then return spec end
      if id == 118 or id == "METRONOME" then return caller end
    end }
  end
  if name == "StadiumAssets" then
    return { has = function() return true end, get = function() return nil end }
  end
  if name == "effects/ThunderShockSpec" then
    return { scaleProfiles = {}, portableWorldToPixel = 0.1 }
  end
  if name == "DramaticShapeState" then return { read = function() return nil end } end
  if name == "DramaticShapeHit" then
    return {
      effectiveness = function(n) return n > 10 and "super" or "neutral" end,
      request = function(_, side, effectiveness)
        reactions[#reactions + 1] = { side, effectiveness }
        return true
      end,
    }
  end
  if name == "effects/GenericMoveRenderer" then return { draw = function() end } end
  if name == "effects/StadiumAuthenticRenderer" then
    return { draw = function() return false end }
  end
  if name == "AttackCinematics" then
    return { start = function() end, setTick = function() end, stop = function() end }
  end
  error(name)
end })

local inner = { start = function() end, update = function() end,
  isDone = function() return false end, pollEffects = function() return {} end }
local timed = Player.new(inner, function() return true end, nil,
  function() return {} end)
timed:setMoveContext({ move = { index = 118 } })
timed:setMoveContext({ move = { index = 84 }, isCalled = true })
timed:recordDamage({ move = { index = 84 }, damage = 0, typeMult = 0,
  target = { isPlayer = false } })
timed:recordDamage({ move = { index = 84 }, damage = 12, typeMult = 20,
  target = { isPlayer = false } })
timed:start(118, true)
for _ = 1, caller.duration do timed:update() end
assert(#reactions == 0, "called move damage attached to its caller")
timed:start(84, true)
for _ = 1, spec.impactAt - 1 do timed:update() end
assert(#reactions == 0, "hit reaction fired before impact")
timed:update()
timed:update()
assert(#reactions == 1 and reactions[1][1] == "enemy"
       and reactions[1][2] == "super", "hit reaction did not fire once at impact")

-- Multi-hit damage queues one reaction for each repeated move animation.
timed:setMoveContext({ move = { index = 84 } })
for _ = 1, 2 do
  timed:recordDamage({ move = { index = 84 }, damage = 4, typeMult = 10,
    target = { isPlayer = true } })
end
for expected = 2, 3 do
  timed:start(84, false)
  for _ = 1, spec.impactAt do timed:update() end
  assert(#reactions == expected and reactions[expected][1] == "player",
    "multi-hit reaction was not retained for each animation")
end
print("ok impact-synchronized hit reaction")
