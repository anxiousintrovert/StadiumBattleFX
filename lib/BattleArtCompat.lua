-- Read-only compatibility bridge for Battle Art Voxel Fork 1.8.x.
--
-- Battle Art predates StadiumBattleFX's provider registry and owns its staged
-- battle canvas through a BattleState:draw wrapper.  When that presentation is
-- active SBFX yields arena/model/camera rendering, but may still provide move
-- effects and audio.  This module reads only Battle Art's public exports; it
-- never changes Battle Art settings or runtime state.

local V = ...
local Compat = {}

local MOD_ID = "BATTLE_ART_VOXEL_FORK"
local cachedHandle, cachedBattle

local function find()
  local finder = V.mod and V.mod.find
  if type(finder) ~= "function" then return nil end
  local ok, handle = pcall(finder, MOD_ID)
  if not ok or not handle then
    ok, handle = pcall(finder, V.mod, MOD_ID)
  end
  return ok and handle or nil
end

local function overworldBattle()
  local handle = find()
  if not handle then
    cachedHandle, cachedBattle = nil, nil
    return nil
  end
  if handle == cachedHandle and cachedBattle then return cachedBattle end
  local lib = handle.exports and handle.exports.lib
  if type(lib) ~= "table" or type(lib.require) ~= "function" then return nil end
  local ok, battle = pcall(lib.require, "OverworldBattle")
  if not ok or type(battle) ~= "table" then return nil end
  cachedHandle, cachedBattle = handle, battle
  return battle
end

local function call(object, name, ...)
  local fn = object and object[name]
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if not ok then return nil end
  return a, b, c
end

function Compat.installed()
  return find() ~= nil
end

function Compat.enabled()
  local battle = overworldBattle()
  return call(battle, "enabled") == true
end

-- True as soon as Battle Art has staged this battle, including the short
-- interval before its first rendered shot is available.
function Compat.ownsBattle(expected)
  local api = overworldBattle()
  if not api then return false end
  local battle = call(api, "battle")
  if battle == nil then return false end
  return expected == nil or battle == expected
end

function Compat.active(expected)
  local api = overworldBattle()
  if not api then return false end
  if expected ~= nil then
    local battle = call(api, "battle")
    if battle ~= nil and battle ~= expected then return false end
  end
  return type(call(api, "shot")) == "table"
end

local function point(value, fallback)
  if type(value) == "table" and type(value[1]) == "number"
      and type(value[2]) == "number" then
    return { value[1], value[2] }
  end
  return { fallback[1], fallback[2] }
end

-- Reproduce Battle Art's documented drawAnimLayer transform so Stadium's
-- authored particles can survive the clean graphics-state boundary in
-- StadiumFxPlayer.  Screen-wide fields use the inverse of this transform;
-- anchored particles retain it and therefore land on the visible cards.
function Compat.presentationState()
  local api = overworldBattle()
  local shot = api and call(api, "shot")
  if type(shot) ~= "table" then return nil end

  local anchors = type(api.ANCHOR) == "table" and api.ANCHOR or {
    player = { 26, 96 }, enemy = { 124, 56 },
  }
  local authoredPlayer = point(anchors.player, { 26, 96 })
  local authoredEnemy = point(anchors.enemy, { 124, 56 })
  local projectedPlayer = point(shot.player, authoredPlayer)
  local projectedEnemy = point(shot.enemy, authoredEnemy)
  local backPinned = call(api, "backPinned") == true
  if backPinned then projectedPlayer = point(authoredPlayer, authoredPlayer) end

  local scale = tonumber(call(api, "animScale", shot,
    projectedPlayer[1], projectedPlayer[2])) or 1
  if scale <= 0 or scale ~= scale then scale = 1 end
  local authoredCenter = {
    (authoredPlayer[1] + authoredEnemy[1]) / 2,
    (authoredPlayer[2] + authoredEnemy[2]) / 2,
  }
  local projectedCenter = {
    (projectedPlayer[1] + projectedEnemy[1]) / 2,
    (projectedPlayer[2] + projectedEnemy[2]) / 2,
  }

  return {
    owner = MOD_ID,
    shot = shot,
    backPinned = backPinned,
    animationScale = scale,
    projectedAnchors = {
      player = projectedPlayer,
      enemy = projectedEnemy,
    },
    layerTransform = {
      authoredCenter = authoredCenter,
      projectedCenter = projectedCenter,
      scale = scale,
    },
    layerOwnsProjection = true,
    surfaceOwned = true,
    externalCamera = true,
  }
end

function Compat.status()
  local handle = find()
  local state = Compat.presentationState()
  return {
    installed = handle ~= nil,
    version = handle and tostring((handle.exports and handle.exports.version)
      or handle.version or "") or nil,
    enabled = Compat.enabled(),
    active = state ~= nil,
    owner = state and state.owner or nil,
  }
end

return Compat
