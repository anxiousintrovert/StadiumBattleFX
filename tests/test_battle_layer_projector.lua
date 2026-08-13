local loader = loadfile or (love and love.filesystem and love.filesystem.load)

local Host = assert(loader("lib/BattleHost.lua"))({
  log = { info = function() end, warn = function() end, error = function() end },
  require = function(name)
    if name == "BattleProviders" then
      return { VERSION = 1, FALLBACK = {}, DEFAULT = "stadium:default" }
    elseif name == "Mat4" then
      return {}
    elseif name == "StadiumRender" then
      return {}
    elseif name == "BattleCinematicsCompat" then
      return {}
    elseif name == "StadiumTrainerPortraits" then
      return {}
    end
    error(name)
  end,
})

local function near(actual, expected, label)
  assert(math.abs(actual - expected) < 1e-6,
    ("%s: expected %.3f, got %.3f"):format(label, expected, actual))
end

-- Desktop integer-fit letterbox: 160x144 at 5x inside 1024x768.
local desktop = { uiSize = function() return 160, 144 end,
  fitScale = function() return 5 end }
local project = Host.battleLayerProjector(function() return 242, 504 end,
  desktop, 1024, 768)
local x, y = project()
near(x, 26, "desktop x")
near(y, 96, "desktop y")

-- Android battle-fill mode: fractional scale with horizontal bars.
local android = { uiFill = true, uiSize = function() return 160, 144 end }
project = Host.battleLayerProjector(function() return 795, 720 end,
  android, 2400, 1080)
x, y = project()
near(x, 26, "android fill x")
near(y, 96, "android fill y")

-- Dramaless can supersample its arena before resolving it to the Android
-- framebuffer. Attachment projections from that render pass must be folded
-- down by the same ratio before either direct or logical VFX consume them.
local shown = Host.shownSurfaceProjector(function() return 1590, 1440 end,
  4800, 2160, 2400, 1080)
local shownX, shownY = shown()
near(shownX, 795, "supersampled shown x")
near(shownY, 720, "supersampled shown y")
project = Host.battleLayerProjector(shown, android, 2400, 1080)
x, y = project()
near(x, 26, "supersampled android fill x")
near(y, 96, "supersampled android fill y")

-- Wide battle keeps the classic 160-pixel animation layer centered.
local wide = { uiSize = function() return 304, 144 end,
  fitScale = function() return 4 end }
project = Host.battleLayerProjector(function() return 584, 480 end,
  wide, 1600, 768)
x, y = project()
near(x, 26, "wide x")
near(y, 96, "wide y")

print("ok framebuffer attachment projection maps to the battle animation layer")
