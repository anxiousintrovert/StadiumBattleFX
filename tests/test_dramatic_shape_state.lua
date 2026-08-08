local loader = love and love.filesystem and love.filesystem.load or loadfile
local chunk = assert(loader("lib/DramaticShapeState.lua"))
local State = chunk()

local modules = {
  VoxelState = { level = 5, angle = 75 },
  OverworldBattle = {
    shot = function()
      return { player = { 30, 94 }, enemy = { 120, 58 },
               playerSpan = 42, enemySpan = 38 }
    end,
    animScale = function() return 0.91 end,
  },
  Stadium = {
    mode = function() return "A" end,
    showing = function(side) return side == "player" end,
    footprint = function(side) return side == "player" and 23 or 17 end,
  },
}

local state = State.read(function()
  return { exports = { lib = { require = function(name) return modules[name] end } } }
end, true, function() return { exports = { version = "0.7.1" } } end)

assert(state.voxelLevel == 5 and state.voxelAngle == 75)
assert(state.battleMode == "A" and state.layerOwnsProjection)
assert(state.animationScale == 0.91)
assert(state.attackerShowing and not state.targetShowing)
assert(state.attackerFootprint == 23 and state.targetFootprint == 17)
assert(state.externalCamera and state.battleCinematicsVersion == "0.7.1")

modules.OverworldBattle.backPinned = function() return true end
local scalePlayer
modules.OverworldBattle.animScale = function(_, px, py)
  scalePlayer = { px, py }
  return 1.1
end
local pinned = State.read(function()
  return { exports = { lib = { require = function(name) return modules[name] end } } }
end, true)
assert(pinned.backPinned and pinned.projectedAnchors.player[1] == 26
       and pinned.projectedAnchors.player[2] == 96)
assert(scalePlayer[1] == 26 and scalePlayer[2] == 96,
       "BACK SPRITES must use DS's classic player mark for layer scaling")
assert(State.read(function() return nil end, true) == nil)
print("ok dramatic shape read-only state")
