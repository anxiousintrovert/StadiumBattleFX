local loader = love and love.filesystem and love.filesystem.load or loadfile
local chunk = assert(loader("lib/effects/StadiumFxPlayer.lua"))

local modules = {
  ["effects/MoveSpecs"] = { get = function() return nil end },
  StadiumAssets = { has = function() return true end, get = function() return nil end },
  ["effects/ThunderShockSpec"] = {
    scaleProfiles = {}, portableWorldToPixel = 0.10,
  },
  DramaticShapeState = {
    read = function()
      return { layerOwnsProjection = true, externalCamera = true,
               battleCinematicsVersion = "0.7.1" }
    end,
  },
  DramaticShapeHit = {
    effectiveness = function() return "neutral" end,
    request = function() return false end,
  },
  ["effects/GenericMoveRenderer"] = { draw = function() end },
  ["effects/StadiumAuthenticRenderer"] = { draw = function() return false end },
  AttackCinematics = { start = function() return false end,
    setTick = function() end, stop = function() end },
}
local V = { require = function(name) return assert(modules[name], name) end }
local Player = chunk(V)
local player = Player.new({}, function() return true end, nil,
  function() return {} end, function() return { exports = { version = "0.7.1" } } end)

player.attackerIsPlayer = true
player.dsState = {
  layerOwnsProjection = true,
  layerTransform = {
    authoredCenter = { 75, 76 },
    projectedCenter = { 83, 73 },
    scale = 0.8,
  },
  projectedAnchors = {
    player = { 48, 110 },
    enemy = { 118, 36 },
  },
}
local ax, ay = player:anchor("attacker")
local tx, ty = player:anchor("target")
local function projected(x, y)
  return 83 + 0.8 * (x - 75), 73 + 0.8 * (y - 76)
end
local pax, pay = projected(ax, ay)
local ptx, pty = projected(tx, ty)
assert(math.abs(pax - 48) < 1e-6 and math.abs(pay - 110) < 1e-6,
       "attacker anchor did not survive DS's outer camera transform")
assert(math.abs(ptx - 118) < 1e-6 and math.abs(pty - 36) < 1e-6,
       "target anchor did not survive DS's rotating camera transform")

player.attackerIsPlayer = false
ax, ay = player:anchor("attacker")
tx, ty = player:anchor("target")
local ex, ey = projected(ax, ay)
local px, py = projected(tx, ty)
assert(math.abs(ex - 118) < 1e-6 and math.abs(ey - 36) < 1e-6,
       "reversed attacker did not land on the enemy mark")
assert(math.abs(px - 48) < 1e-6 and math.abs(py - 110) < 1e-6,
       "reversed target did not land on the player mark")
print("ok dynamic battle cinematics projection ownership")
