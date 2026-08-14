local loader = love and love.filesystem and love.filesystem.load or loadfile
local values = {
  showing = { player = true, enemy = false },
  footprint = { player = 23, enemy = 17 },
}
local battleArtState
local State = assert(loader("lib/DramaticShapeState.lua"))({
  require = function(name)
    if name == "BattleArtCompat" then
      return { presentationState = function() return battleArtState end }
    end
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

battleArtState = {
  owner = "BATTLE_ART_VOXEL_FORK",
  projectedAnchors = { player = { 31, 92 }, enemy = { 129, 52 } },
  layerTransform = {
    authoredCenter = { 75, 76 }, projectedCenter = { 80, 72 }, scale = 0.9,
  },
  layerOwnsProjection = true,
}
state = State.read(nil, true)
assert(state.battleMode == "BATTLE_ART" and state.layerOwnsProjection)
assert(state.projectedAnchors.player[1] == 31 and state.animationScale == nil)
assert(not state.attackerShowing and not state.targetShowing,
  "Battle Art sprite cards were mistaken for Stadium skeletal models")

battleArtState.owner = "DRAMATIC_SHAPE"
state = State.read(nil, false)
assert(state.battleMode == "DRAMATIC_SHAPE"
    and not state.attackerShowing and not state.targetShowing,
  "Dramatic Shape sprite cards were mistaken for Stadium skeletal models")
print("ok selected model-provider state")
