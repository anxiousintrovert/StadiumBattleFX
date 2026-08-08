-- Read-only view of Dramaless Shape presentation state.
--
-- Dramaless Shape transforms BattleState.drawAnimLayer from the fixed Gen1
-- anchors into its live staged-battle shot. Stadium Attack Animations must detect
-- that ownership and avoid applying the same camera transform twice.

local State = {}
local DEFAULT_ANCHOR = { player = { 26, 96 }, enemy = { 124, 56 } }

local function safeCall(object, name, ...)
  local fn = object and object[name]
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  if ok then return value end
  return nil
end

function State.read(companion, attackerIsPlayer, cameraCompanion)
  local ok, result = pcall(function()
    local found = companion and companion()
    local exports = found and found.exports
    local lib = exports and exports.lib
    if not (lib and type(lib.require) == "function") then return nil end

    local Voxel = lib.require("VoxelState")
    local Battles = lib.require("OverworldBattle")
    local Stadium = lib.require("Stadium")
    local shot = safeCall(Battles, "shot")
    local anchors = Battles.ANCHOR or DEFAULT_ANCHOR
    local player = shot and shot.player
    local backPinned = safeCall(Battles, "backPinned") and true or false
    local projectedPlayer = backPinned and anchors.player or player
    local animScale = 1
    if shot and projectedPlayer then
      animScale = safeCall(
        Battles, "animScale", shot, projectedPlayer[1], projectedPlayer[2]) or 1
    end

    local layerTransform
    if shot and projectedPlayer and shot.enemy and animScale > 0 then
      layerTransform = {
        authoredCenter = {
          (anchors.player[1] + anchors.enemy[1]) / 2,
          (anchors.player[2] + anchors.enemy[2]) / 2,
        },
        projectedCenter = {
          (projectedPlayer[1] + shot.enemy[1]) / 2,
          (projectedPlayer[2] + shot.enemy[2]) / 2,
        },
        scale = animScale,
      }
    end

    local attackerSide = attackerIsPlayer and "player" or "enemy"
    local targetSide = attackerIsPlayer and "enemy" or "player"
    local cameraMod = cameraCompanion and cameraCompanion()
    local cameraExports = cameraMod and cameraMod.exports
    return {
      voxelLevel = Voxel and Voxel.level or nil,
      voxelAngle = Voxel and Voxel.angle or nil,
      battleMode = safeCall(Stadium, "mode"),
      shot = shot,
      animationScale = animScale,
      backPinned = backPinned,
      projectedAnchors = shot and {
        player = projectedPlayer,
        enemy = shot.enemy,
      } or nil,
      layerTransform = layerTransform,
      -- A live shot means DS's drawAnimLayer wrapper owns its outer
      -- translation/scale. Individual effect anchors are inverse-mapped so
      -- that outer transform lands them on the rotating camera's live marks.
      layerOwnsProjection = shot ~= nil,
      attackerShowing = safeCall(Stadium, "showing", attackerSide) and true or false,
      targetShowing = safeCall(Stadium, "showing", targetSide) and true or false,
      attackerFootprint = safeCall(Stadium, "footprint", attackerSide),
      targetFootprint = safeCall(Stadium, "footprint", targetSide),
      battleCinematicsVersion = cameraExports and cameraExports.version or nil,
      externalCamera = cameraExports and cameraExports.version ~= nil or false,
    }
  end)
  if ok then return result end
  return nil
end

return State
