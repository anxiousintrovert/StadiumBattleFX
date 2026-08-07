-- Read-only view of Dramatic Shapes presentation state.
--
-- Dramatic Shapes transforms BattleState.drawAnimLayer from the fixed Gen1
-- anchors into its live staged-battle shot. Stadium Battle FX must detect
-- that ownership and avoid applying the same camera transform twice.

local State = {}

local function safeCall(object, name, ...)
  local fn = object and object[name]
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  if ok then return value end
  return nil
end

function State.read(companion, attackerIsPlayer)
  local ok, result = pcall(function()
    local found = companion and companion()
    local exports = found and found.exports
    local lib = exports and exports.lib
    if not (lib and type(lib.require) == "function") then return nil end

    local Voxel = lib.require("VoxelState")
    local Battles = lib.require("OverworldBattle")
    local Stadium = lib.require("Stadium")
    local shot = safeCall(Battles, "shot")
    local player = shot and shot.player
    local animScale = 1
    if shot and player then
      animScale = safeCall(Battles, "animScale", shot, player[1], player[2]) or 1
    end

    local attackerSide = attackerIsPlayer and "player" or "enemy"
    local targetSide = attackerIsPlayer and "enemy" or "player"
    return {
      voxelLevel = Voxel and Voxel.level or nil,
      voxelAngle = Voxel and Voxel.angle or nil,
      battleMode = safeCall(Stadium, "mode"),
      shot = shot,
      animationScale = animScale,
      -- A live shot means DS's drawAnimLayer wrapper owns translation and
      -- scaling. Our effect remains authored at the classic 160x144 anchors.
      layerOwnsProjection = shot ~= nil,
      attackerShowing = safeCall(Stadium, "showing", attackerSide) and true or false,
      targetShowing = safeCall(Stadium, "showing", targetSide) and true or false,
      attackerFootprint = safeCall(Stadium, "footprint", attackerSide),
      targetFootprint = safeCall(Stadium, "footprint", targetSide),
    }
  end)
  if ok then return result end
  return nil
end

return State
