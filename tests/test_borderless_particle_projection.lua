local loader = love and love.filesystem and love.filesystem.load or loadfile

local world = {}
local currentCanvas = "ui"
local calls = {}
local Host = {
  animationViewport = function()
    return { surface = world, width = 1920, height = 1080,
      x = 360, y = 0, scale = 7.5 }
  end,
}
local ScreenFx = assert(loader("lib/effects/StadiumScreenFx.lua"))({
  require = function(name)
    assert(name == "BattleHost")
    return Host
  end,
})

local hostLove = love
love = { graphics = {
  getCanvas = function() return currentCanvas end,
  setCanvas = function(value)
    currentCanvas = value
    calls[#calls + 1] = { "canvas", value }
  end,
  origin = function() calls[#calls + 1] = { "origin" } end,
  setShader = function() end,
  setScissor = function() end,
  translate = function(x, y) calls[#calls + 1] = { "translate", x, y } end,
  scale = function(x, y) calls[#calls + 1] = { "scale", x, y } end,
} }

ScreenFx.setBorderless(true)
local minX, maxX, minY, maxY = ScreenFx.anchorBounds()
assert(minX < -29 and maxX > 124 and minY < 0 and maxY > 144,
  "borderless camera-visible attachment range was clipped to 160x144")

local token = ScreenFx.beginAnchored(love.graphics)
assert(token and currentCanvas == world,
  "anchored particle pass was not redirected to the 3D world surface")
assert(calls[2][1] == "origin")
for _, call in ipairs(calls) do
  assert(call[1] ~= "translate",
    "particle pass still applied a centred Game Boy-canvas origin")
end
assert(calls[#calls][1] == "scale"
  and calls[#calls][2] == 7.5 and calls[#calls][3] == 7.5)

-- A moving camera updates the mapping on the next frame; no captured/static
-- attachment geometry is reused by the deferred particle path.
Host.animationViewport = function()
  return { surface = world, width = 1920, height = 1080,
    x = 300, y = -20, scale = 8 }
end
ScreenFx.endAnchored(love.graphics, token)
assert(currentCanvas == "ui", "particle pass did not restore the UI canvas")
calls = {}
token = ScreenFx.beginAnchored(love.graphics)
for _, call in ipairs(calls) do
  assert(call[1] ~= "translate",
    "moving camera reintroduced a Game Boy-canvas translation")
end
assert(calls[#calls][2] == 8 and calls[#calls][3] == 8,
  "moving camera did not refresh the particle projection")
ScreenFx.endAnchored(love.graphics, token)

-- Full-resolution model attachments are not a borderless-only feature.
-- Android/fullscreen/windowed 3D battles use the same shown-surface path.
ScreenFx.setBorderless(false)
calls = {}
token = ScreenFx.beginAnchored(love.graphics)
assert(token and currentCanvas == world,
  "non-borderless 3D battle fell back to the Game Boy animation canvas")
ScreenFx.endAnchored(love.graphics, token)

love = hostLove
print("ok shown-screen particles follow the live 3D camera")
