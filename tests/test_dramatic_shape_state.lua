local loader = love and love.filesystem and love.filesystem.load or loadfile
local values = {
  showing = { player = true, enemy = false },
  footprint = { player = 23, enemy = 17 },
}
local State = assert(loader("lib/DramaticShapeState.lua"))({
  require = function(name)
    assert(name == "BattleHost")
    return { call = function(_, method, side)
      return true, values[method] and values[method][side]
    end }
  end,
})

local state = State.read(nil, true,
  function() return { exports = { version = "0.7.1" } } end)
assert(state.voxelLevel == nil and state.voxelAngle == nil)
assert(state.battleMode == "A" and not state.layerOwnsProjection)
assert(state.animationScale == 1)
assert(state.attackerShowing and not state.targetShowing)
assert(state.attackerFootprint == 23 and state.targetFootprint == 17)
assert(state.externalCamera and state.battleCinematicsVersion == "0.7.1")
print("ok selected model-provider state")
