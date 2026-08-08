local loader = love and love.filesystem and love.filesystem.load or loadfile
local ScreenFx = assert(loader("lib/effects/StadiumScreenFx.lua"))()

local calls = { full = 0, draws = 0, scissors = 0, inverseScale = nil }
local hostLove = love
love = { graphics = {} }
local g = love.graphics
g.setColor = function() end
g.setLineWidth = function() end
g.setBlendMode = function() end
g.getBlendMode = function() return "alpha", "alphamultiply" end
g.getColor = function() return 1, 1, 1, 1 end
g.getScissor = function() return nil end
g.setScissor = function(...)
  if select("#", ...) == 4 then calls.scissors = calls.scissors + 1 end
end
g.push = function() end
g.pop = function() end
g.translate = function() end
g.scale = function(x) calls.inverseScale = x end
g.circle = function() end
g.ellipse = function() end
g.draw = function() calls.draws = calls.draws + 1 end
g.rectangle = function(mode, x, y, width, height)
  if mode == "fill" and x == 0 and y == 0 and width == 160 and height == 144 then
    calls.full = calls.full + 1
  end
end

local player = { tick = 12 }
function player:anchor() return 124, 56 end
for _, key in ipairs({ "FLASH", "MIST", "HAZE" }) do
  calls.full = 0
  player.spec = { key = key, duration = 72 }
  assert(ScreenFx.drawMove(player), key .. " did not select a screen program")
  assert(calls.full > 0, key .. " did not cover the full animation layer")
end

local fake = {
  image = {}, quads = { {} }, frameWidth = 32, frameHeight = 32, frames = 1,
}
assert(ScreenFx.tile(g, fake, 0, { alpha = 0.2, x = 3, y = 4 }))
assert(calls.draws >= 30, "tile did not cover the full animation layer")
assert(not ScreenFx.drawMove({ spec = { key = "TACKLE" } }))

-- Borderless screen layers cancel the combatant-pair scale, then replay only
-- into the composed desktop margins (the center already came from the canvas).
ScreenFx.setBorderless(true)
player.dsState = { layerTransform = {
  authoredCenter = { 75, 76 }, projectedCenter = { 83, 73 }, scale = 0.8,
} }
ScreenFx.activate(player)
ScreenFx.fill(g, { 1, 1, 1 }, 0.25, player)
assert(math.abs(calls.inverseScale - 1.25) < 1e-9,
  "screen layer did not cancel Dramaless Shape scale")
calls.scissors = 0
assert(ScreenFx.present({ save = { options = { videoMode = "borderless" } } }, {
  width = 1920, height = 1080, gameX = 400, gameY = 36,
  gameWidth = 1120, gameHeight = 1008, scale = 7,
}), "borderless overlay was not presented")
assert(calls.scissors == 4, "borderless overlay did not cover all four margins")
assert(not ScreenFx.present({ save = { options = { videoMode = "windowed" } } }, {
  width = 800, height = 720, gameX = 0, gameY = 0,
  gameWidth = 800, gameHeight = 720, scale = 5,
}), "windowed mode must not receive borderless margin overlays")

love = hostLove
print("ok full-screen effect programs")
