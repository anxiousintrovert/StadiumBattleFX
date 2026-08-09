local loader = love and love.filesystem and love.filesystem.load or loadfile
local profiles = assert(loader("lib/effects/StadiumFidelityProfiles.lua"))()
local screenFx = assert(loader("lib/effects/StadiumScreenFx.lua"))()
local renderer = assert(loader("lib/effects/StadiumAuthenticRenderer.lua"))({
  require = function(name)
    assert(name == "effects/StadiumScreenFx", name)
    return screenFx
  end,
})

local expected = {
  52, 53, 55, 56, 57, 58, 59, 60, 63, 71, 72, 75, 76, 85, 87, 89,
  92, 94, 105, 109, 113, 115, 126, 153,
}

local count = 0
for id, profile in pairs(profiles) do
  count = count + 1
  assert(type(id) == "number", "profile move ID must be numeric")
  assert(type(profile.stadiumProgram) == "string", "missing Stadium program")
  assert(profile.impactAt > 0 and profile.duration > profile.impactAt,
    "invalid calibrated lifecycle for move " .. id)
  assert(#profile.assets > 0, "profile has no exact Stadium assets")
end
assert(count == #expected, "unexpected Stadium fidelity profile count")
for _, id in ipairs(expected) do assert(profiles[id], "missing profile " .. id) end
assert(profiles[57].optionalAssets and profiles[57].optionalAssets[1] == "water_cycle",
  "Surf's screen texture must not gate its overlay program")
for _, id in ipairs({ 92, 109, 113, 115 }) do
  assert(profiles[id].optionalAssets,
    "overlay profile " .. id .. " must not require an unused/presentation asset")
end

local hostLove = love
love = { graphics = {} }
for _, name in ipairs({ "setColor", "draw", "rectangle", "setLineWidth", "line" }) do
  love.graphics[name] = function() end
end

local fake = {
  image = {}, quads = { {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {} },
  frameWidth = 32, frameHeight = 32, frames = 16,
}
local Assets = { get = function() return fake end }
local player = {}
function player:anchor(which)
  if which == "attacker" then return 26, 96 end
  return 124, 56
end

for _, id in ipairs(expected) do
  player.spec = profiles[id]
  for _, tick in ipairs({ 0, player.spec.impactAt, player.spec.duration - 1 }) do
    player.tick = tick
    local ok, err = pcall(renderer.draw, player, Assets)
    assert(ok, ("profile %d failed at tick %d: %s"):format(id, tick, tostring(err)))
  end
end

local boltLine
love.graphics.line = function(points) boltLine = points end
player.spec, player.tick = profiles[85], 36
renderer.draw(player, Assets)
assert(boltLine and boltLine[1] == 124 and boltLine[2] == -20,
  "Thunderbolt must begin above the target rather than at the attacker")

love = hostLove

print("ok 24 Stadium 1 fidelity profiles")
