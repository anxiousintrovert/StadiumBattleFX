local loader = love and love.filesystem and love.filesystem.load or loadfile

local requestedAssets
local screenClears = 0
local cameraStarts, cameraStops = 0, 0
local warnings = {}

local spec = {
  id = 1, key = "POUND", kind = "generic", duration = 30, impactAt = 15,
  assets = { "core", "screen_grain", "optional_glint" },
  optionalAssets = { "optional_glint" },
}

local modules = {
  ["effects/MoveSpecs"] = { get = function(id) return id == 1 and spec or nil end },
  StadiumAssets = {
    has = function(names)
      requestedAssets = names
      return true
    end,
    get = function() return nil end,
  },
  ["effects/ThunderShockSpec"] = {},
  DramaticShapeState = {
    read = function()
      return { attackerShowing = true, targetShowing = true }
    end,
  },
  DramaticShapeAttachment = {
    position = function() return nil end,
    tags = function() return nil end,
  },
  DramaticShapeHit = {
    effectiveness = function() return "neutral" end,
    request = function() return false end,
  },
  ["effects/GenericMoveRenderer"] = {},
  ["effects/StadiumAuthenticRenderer"] = { draw = function() return false end },
  ["effects/StadiumScreenFx"] = {
    activate = function() end,
    clear = function() screenClears = screenClears + 1 end,
  },
  AttackCinematics = {
    start = function() cameraStarts = cameraStarts + 1 return true end,
    setTick = function() end,
    stop = function() cameraStops = cameraStops + 1 end,
  },
}

local hostLove = love
local blendMode, alphaMode = "alpha", "premultiplied"
local lineWidth = 3
local color = { 0.8, 0.7, 0.6, 0.5 }
local partialDraws = 0
local printed = {}
love = { graphics = {
  getBlendMode = function() return blendMode, alphaMode end,
  setBlendMode = function(mode, alpha) blendMode, alphaMode = mode, alpha end,
  getLineWidth = function() return lineWidth end,
  setLineWidth = function(width) lineWidth = width end,
  getColor = function() return color[1], color[2], color[3], color[4] end,
  setColor = function(r, g, b, a) color = { r, g, b, a } end,
  rectangle = function() partialDraws = partialDraws + 1 end,
  print = function(text) printed[#printed + 1] = text end,
  printf = function(text) printed[#printed + 1] = text end,
} }

modules["effects/GenericMoveRenderer"].draw = function()
  love.graphics.setBlendMode("add", "alphamultiply")
  love.graphics.setLineWidth(9)
  love.graphics.setColor(0.1, 0.2, 0.3, 0.4)
  love.graphics.rectangle("fill", 0, 0, 1, 1)
  error("intentional renderer failure")
end

local Player = assert(loader("lib/effects/StadiumFxPlayer.lua"))({
  require = function(name) return assert(modules[name], name) end,
})

local inner = { draws = 0, starts = 0 }
function inner:start() self.starts = self.starts + 1 end
function inner:update() end
function inner:isDone() return false end
function inner:pollEffects() return {} end
function inner:draw() self.draws = self.draws + 1 end

local logger = {
  warn = function(_, message, reason)
    warnings[#warnings + 1] = message:format(tostring(reason))
  end,
}
local reported
local player = Player.new(inner, function() return true end, logger,
  nil, nil, nil, nil, function(subject, reason)
    reported = { subject, reason }
  end)
player:start(1, true)

assert(player.custom and inner.starts == 1, "custom move did not start")
assert(#requestedAssets == 1 and requestedAssets[1] == "core",
  "optional and screen-overlay assets must not gate a move")
assert(cameraStarts == 1, "custom camera did not start")

-- Ignore the ordinary stop/clear performed at move start and inspect only the
-- draw-failure transition.
cameraStops, screenClears = 0, 0
player:draw()
assert(partialDraws == 1, "test renderer did not draw before failing")
assert(inner.draws == 0,
  "vanilla renderer was layered over a partially drawn Stadium frame")
assert(not player.custom and player.spec == nil,
  "failed Stadium renderer was not retired")
assert(cameraStops == 1 and screenClears == 1,
  "failed presentation did not release camera and overlay state")
assert(#warnings == 1 and warnings[1]:find("intentional renderer failure", 1, true),
  "renderer failure was not reported")
assert(reported and reported[1] == "POUND"
    and reported[2]:find("intentional renderer failure", 1, true),
  "renderer failure did not reach the on-screen reporter")
assert(blendMode == "alpha" and alphaMode == "premultiplied",
  "renderer failure leaked blend state")
assert(lineWidth == 3, "renderer failure leaked line width")
assert(color[1] == 0.8 and color[2] == 0.7 and color[3] == 0.6
    and color[4] == 0.5, "renderer failure leaked color state")

player:draw()
assert(inner.draws == 1,
  "vanilla renderer did not take over on the frame after failure")

local Notice = assert(loader("lib/FailureNotice.lua"))()
Notice.show(reported[1], reported[2])
assert(Notice.draw({ width = 640 }), "failure notice was not drawn")
assert(printed[1] and printed[1]:find("STADIUM FX FALLBACK", 1, true),
  "failure notice title was not visible")
Notice.update(9)
assert(not Notice.status(), "failure notice did not expire")

love = hostLove
print("ok overlay-safe gating and clean renderer fallback")
