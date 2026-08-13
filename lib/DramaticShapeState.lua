-- Read-only view of StadiumBattleFX presentation state.
--
-- The historical filename is retained for internal compatibility. State is
-- now read from StadiumBattleFX's selected providers, never from Dramaless.

local State = {}
local DEFAULT_ANCHOR = { player = { 26, 96 }, enemy = { 124, 56 } }
local V = ...

local function safeCall(object, name, ...)
  local fn = object and object[name]
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  if ok then return value end
  return nil
end

function State.read(companion, attackerIsPlayer, cameraCompanion)
  local ok, result = pcall(function()
    local Host = V.require("BattleHost")
    local function modelCall(method, ...)
      local called, value = Host.call("models", method, ...)
      return called and value or nil
    end

    local attackerSide = attackerIsPlayer and "player" or "enemy"
    local targetSide = attackerIsPlayer and "enemy" or "player"
    local cameraMod = cameraCompanion and cameraCompanion()
    local cameraExports = cameraMod and cameraMod.exports
    return {
      voxelLevel = nil,
      voxelAngle = nil,
      battleMode = "A",
      shot = nil,
      animationScale = 1,
      backPinned = false,
      projectedAnchors = DEFAULT_ANCHOR,
      layerTransform = nil,
      layerOwnsProjection = false,
      attackerShowing = modelCall("showing", attackerSide) and true or false,
      targetShowing = modelCall("showing", targetSide) and true or false,
      attackerFootprint = modelCall("footprint", attackerSide),
      targetFootprint = modelCall("footprint", targetSide),
      battleCinematicsVersion = cameraExports and cameraExports.version or nil,
      externalCamera = cameraExports and cameraExports.version ~= nil or false,
    }
  end)
  if ok then return result end
  return nil
end

return State
