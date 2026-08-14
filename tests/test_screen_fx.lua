local loader = love and love.filesystem and love.filesystem.load or loadfile
local ScreenFx = assert(loader("lib/effects/StadiumScreenFx.lua"))()

local calls = { full = 0, draws = 0, scissors = 0, inverseScale = nil,
  pushes = 0, pops = 0 }
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
g.push = function(mode)
  if mode == "all" then calls.pushes = calls.pushes + 1 end
end
g.pop = function() calls.pops = calls.pops + 1 end
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

-- Battle Art owns the outer animation-layer transform. Its anchored particles
-- must not be redirected onto a world surface projected by Stadium models.
g.getCanvas = function() return {} end
g.setCanvas = function() error("Battle Art path must not redirect canvases") end
assert(ScreenFx.beginAnchored(g, {
  dsState = { layerOwnsProjection = true },
}) == nil, "Battle Art anchored effects escaped its animation layer")

local player = { tick = 12 }
function player:anchor() return 124, 56 end
for _, key in ipairs({ "FLASH", "MIST", "HAZE" }) do
  calls.full = 0
  player.spec = { key = key, duration = 72 }
  assert(ScreenFx.drawMove(player), key .. " did not select a screen program")
  assert(calls.full > 0, key .. " did not cover the full animation layer")
end

-- A secondary model attachment replays localized particles only; it must not
-- stack a second full-screen program or record another margin overlay.
player.spec = { key = "FLASH", duration = 72 }
player.attachmentPass = { secondary = true }
calls.full = 0
assert(ScreenFx.drawMove(player), "secondary pass did not consume FLASH")
assert(calls.full == 0, "secondary attachment replayed a full-screen effect")
assert(not ScreenFx.fill(g, { 1, 1, 1 }, 0.25, player),
  "secondary attachment recorded a full-screen wash")
player.attachmentPass = nil

local fake = {
  image = {}, quads = { {} }, frameWidth = 32, frameHeight = 32, frames = 1,
}
assert(ScreenFx.tile(g, fake, 0, { alpha = 0.2, x = 3, y = 4 }))
assert(calls.draws >= 30, "tile did not cover the full animation layer")
assert(not ScreenFx.drawMove({ spec = { key = "TACKLE" } }))

-- Screen layers cancel the combatant-pair scale in every video mode. Only the
-- post-compose replay into desktop margins is specific to borderless mode.
ScreenFx.setBorderless(false)
player.dsState = { layerTransform = {
  authoredCenter = { 75, 76 }, projectedCenter = { 83, 73 }, scale = 0.8,
} }
ScreenFx.activate(player)
local function assertUntransformed(label, draw)
  calls.inverseScale = nil
  draw()
  assert(math.abs((calls.inverseScale or 0) - 1.25) < 1e-9,
    label .. " did not cancel Dramaless Shape scale outside borderless mode")
end

-- Every screen-wide renderer path uses one of these primitives. Check the
-- wash, partial field, tiled field, flash, and the dedicated move programs
-- while the output is in Android/windowed-style (non-borderless) mode.
assertUntransformed("full wash", function()
  ScreenFx.fill(g, { 1, 1, 1 }, 0.25, player)
end)
assertUntransformed("partial field", function()
  ScreenFx.region(g, { 1, 1, 1 }, 0.25, 0, 62, 160, 82, player)
end)
assertUntransformed("tiled field", function()
  ScreenFx.tile(g, fake, 0, { alpha = 0.25, owner = player })
end)
assertUntransformed("flash", function()
  ScreenFx.flash(g, 6, 4, 10, { 1, 1, 1 }, 0.25, player)
end)
for _, key in ipairs({ "FLASH", "MIST", "HAZE" }) do
  player.spec = { key = key, duration = 72 }
  assertUntransformed(key, function() ScreenFx.drawMove(player) end)
end
-- Isolate the margin-compositor assertion to a single recorded operation.
ScreenFx.activate(player)
ScreenFx.setBorderless(true)
calls.full = 0
ScreenFx.fill(g, { 1, 1, 1 }, 0.25, player)
assert(calls.full == 0,
  "borderless overlay was also drawn into the 160x144 battle canvas")
calls.scissors = 0
local pushesBefore, popsBefore = calls.pushes, calls.pops
assert(ScreenFx.present({ save = { options = { videoMode = "borderless" } } }, {
  width = 1920, height = 1080, gameX = 400, gameY = 36,
  gameWidth = 1120, gameHeight = 1008, scale = 7,
}), "borderless overlay was not presented")
assert(calls.scissors == 1, "borderless overlay was not drawn as one window pass")
assert(calls.pushes == pushesBefore + 1 and calls.pops == popsBefore + 1,
  "borderless overlay did not fence its graphics state")
assert(not ScreenFx.present({ save = { options = { videoMode = "borderless" } } }, {
  width = 1920, height = 1080, gameX = 400, gameY = 36,
  gameWidth = 1120, gameHeight = 1008, scale = 7,
}), "a stale borderless overlay was replayed on a later frame")

-- A bad texture or hot-reloaded image may fail after the compositor has set
-- its scissor. The all-state fence must still unwind, and the broken frame
-- must not be retried forever over subsequent screens.
ScreenFx.activate(player)
ScreenFx.tile(g, fake, 0, { alpha = 0.25, owner = player })
local workingDraw = g.draw
g.draw = function() error("invalid image") end
popsBefore = calls.pops
local replayOK = pcall(ScreenFx.present,
  { save = { options = { videoMode = "borderless" } } }, {
    width = 1920, height = 1080, gameX = 400, gameY = 36,
    gameWidth = 1120, gameHeight = 1008, scale = 7,
  })
g.draw = workingDraw
assert(not replayOK and calls.pops == popsBefore + 1,
  "failed borderless replay leaked its graphics state")
assert(not ScreenFx.present({ save = { options = { videoMode = "borderless" } } }, {
  width = 1920, height = 1080, gameX = 400, gameY = 36,
  gameWidth = 1120, gameHeight = 1008, scale = 7,
}), "a failed borderless overlay was retried on a later frame")

assert(not ScreenFx.present({ save = { options = { videoMode = "windowed" } } }, {
  width = 800, height = 720, gameX = 0, gameY = 0,
  gameWidth = 800, gameHeight = 720, scale = 5,
}), "windowed mode must not receive borderless margin overlays")

love = hostLove
print("ok full-screen effect programs")
