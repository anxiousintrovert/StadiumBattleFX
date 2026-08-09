local loader = love and love.filesystem and love.filesystem.load or loadfile

local genericDraws, authenticDraws = 0, 0
local cameraStarts, innerStarts, reports = 0, 0, 0
local warnings = {}
local spec = {
  id = 84, key = "THUNDER_SHOCK", name = "Thunder Shock",
  kind = "thundershock", delivery = "projectile", visual = "electric",
  duration = 8, impactAt = 3, assets = { "electric" },
}

local modules = {
  ["effects/MoveSpecs"] = { get = function(id) return id == 84 and spec or nil end },
  StadiumAssets = {
    has = function() return nil, "no .z64/.n64/.v64 file in baseroms/" end,
    get = function() return nil end,
  },
  ["effects/ThunderShockSpec"] = { scaleProfiles = {} },
  DramaticShapeState = { read = function() return nil end },
  DramaticShapeAttachment = { position = function() return nil end },
  DramaticShapeHit = {
    effectiveness = function() return "neutral" end,
    request = function() return false end,
  },
  ["effects/GenericMoveRenderer"] = {
    draw = function() genericDraws = genericDraws + 1 end,
  },
  ["effects/StadiumAuthenticRenderer"] = {
    draw = function() authenticDraws = authenticDraws + 1 return true end,
  },
  ["effects/StadiumScreenFx"] = {
    activate = function() end, clear = function() end,
  },
  AttackCinematics = {
    start = function() cameraStarts = cameraStarts + 1 return true end,
    setTick = function() end, stop = function() end,
  },
}

local hostLove = love
love = { graphics = {
  getBlendMode = function() return "alpha", "alphamultiply" end,
  setBlendMode = function() end,
  getLineWidth = function() return 1 end,
  setLineWidth = function() end,
  getColor = function() return 1, 1, 1, 1 end,
  setColor = function() end,
} }

local Player = assert(loader("lib/effects/StadiumFxPlayer.lua"))({
  require = function(name) return assert(modules[name], name) end,
})
local inner = {
  start = function() innerStarts = innerStarts + 1 end,
  update = function() end,
  isDone = function() return false end,
  pollEffects = function() return {} end,
}
local logger = { warn = function(_, format, key, reason)
  warnings[#warnings + 1] = format:format(key, reason)
end }
local player = Player.new(inner, function() return true end, logger,
  function() return {} end, nil, function() return true end, nil,
  function() reports = reports + 1 end)

player:start(84, true)
assert(player.custom and not player.assetsReady,
  "missing cache disabled the Stadium presentation")
assert(innerStarts == 1 and cameraStarts == 1,
  "cache-free fallback did not retain the move clock and attack camera")
assert(#warnings == 1 and warnings[1]:find("procedural Stadium FX", 1, true)
       and warnings[1]:find("no .z64", 1, true),
  "cache-free fallback did not preserve its actionable diagnosis")
assert(reports == 0, "an available procedural fallback raised a failure banner")

player:draw()
assert(genericDraws == 1 and authenticDraws == 0,
  "cache-free move did not select the procedural renderer")

love = hostLove
print("ok cache-free procedural Stadium fallback")
