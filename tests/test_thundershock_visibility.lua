local loader = love and love.filesystem and love.filesystem.load or loadfile

local spec = {
  id = 84, key = "THUNDERSHOCK", name = "Thunder Shock",
  kind = "thundershock", duration = 100, impactAt = 44,
  assets = { "electric" },
}
local thunder = {
  portableWorldToPixel = 0.12,
  portableMinPixelScale = 0.12,
  portableGlowScale = 1.22,
  scaleProfiles = {
    tiny = { initial = 0.1, target = 1.4, step = 0.1 },
  },
  primary = { schedules = {
    { at = 0, interval = 8, bursts = 1, callback = "tiny", preset = 0x14 },
  } },
  impact = { schedules = {} },
}
local asset = {
  image = {}, quads = { {}, {}, {}, {}, {}, {}, {}, {} }, frames = 8,
  frameWidth = 32, frameHeight = 96,
}

local modules = {
  ["effects/MoveSpecs"] = { get = function(id) return id == 84 and spec or nil end },
  StadiumAssets = {
    has = function() return true end,
    get = function(name) return name == "electric" and asset or nil end,
  },
  ["effects/ThunderShockSpec"] = thunder,
  DramaticShapeState = { read = function() return nil end },
  DramaticShapeAttachment = { position = function() return nil end },
  DramaticShapeHit = {
    effectiveness = function() return "neutral" end,
    request = function() return false end,
  },
  ["effects/GenericMoveRenderer"] = { draw = function() end },
  ["effects/StadiumAuthenticRenderer"] = { draw = function() return false end },
  ["effects/StadiumScreenFx"] = { activate = function() end, clear = function() end },
  AttackCinematics = {
    start = function() return true end, setTick = function() end,
    stop = function() end,
  },
}

local draws, colors = {}, {}
local hostLove = love
love = { graphics = {
  getBlendMode = function() return "alpha", "alphamultiply" end,
  setBlendMode = function() end,
  getLineWidth = function() return 1 end,
  setLineWidth = function() end,
  getColor = function() return 1, 1, 1, 1 end,
  setColor = function(r, g, b, a) colors[#colors + 1] = { r, g, b, a } end,
  draw = function(_, _, _, _, _, sx, sy)
    draws[#draws + 1] = { sx = sx, sy = sy }
  end,
} }

local Player = assert(loader("lib/effects/StadiumFxPlayer.lua"))({
  require = function(name) return assert(modules[name], name) end,
})
local inner = {
  start = function() end, update = function() end,
  isDone = function() return false end, pollEffects = function() return {} end,
}
local player = Player.new(inner, function() return true end, nil,
  function() return {} end, nil, function() return true end)
player:start(84, true)
player:draw()

assert(#draws == 2, "Thunder Shock did not draw a glow and core")
assert(draws[1].sy > draws[2].sy, "Thunder Shock glow did not surround its core")
assert(draws[2].sy >= thunder.portableMinPixelScale,
  "Thunder Shock's opening frame remained sub-pixel")
assert(colors[1][4] < colors[2][4] and colors[2][3] >= 0.58,
  "Thunder Shock did not retain a bright readable core")

love = hostLove
print("ok Thunder Shock portable visibility")
