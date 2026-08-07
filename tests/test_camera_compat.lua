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
}
local V = { require = function(name) return assert(modules[name], name) end }
local Player = chunk(V)
local player = Player.new({}, function() return true end, nil,
  function() return {} end, function() return { exports = { version = "0.7.1" } } end)

player.attackerIsPlayer = true
local ax, ay = player:anchor("attacker")
local tx, ty = player:anchor("target")
assert(ax == 26 and ay == 96 and tx == 124 and ty == 56,
       "DS camera projection must not be applied inside the effect player")

player.attackerIsPlayer = false
ax, ay = player:anchor("attacker")
tx, ty = player:anchor("target")
assert(ax == 124 and ay == 56 and tx == 26 and ty == 96,
       "reversed effects must retain the authored anchor pair")
print("ok dynamic battle cinematics projection ownership")
