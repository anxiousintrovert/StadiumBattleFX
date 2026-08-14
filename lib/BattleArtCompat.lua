-- Read-only compatibility bridge for Shape-family staged battle renderers.
--
-- Battle Art publishes a versioned battleStage descriptor. Older Battle Art
-- releases, Dramatic Shape, and PotatoVoxel expose OverworldBattle through
-- exports.lib. Each owns its staged battle canvas by wrapping BattleState:draw.
-- When one is active SBFX yields arena/model/camera rendering, but may still
-- provide move effects and audio. This module never changes another mod's
-- settings or runtime state.

local V = ...
local Compat = {}

local BACKENDS = {
  { id = "BATTLE_ART_VOXEL_FORK", label = "Battle Art" },
  { id = "DRAMATIC_SHAPE", label = "Dramatic Shape" },
  { id = "potato_voxel", label = "PotatoVoxel" },
}
local cache = {}
local resolved
local STAGE_API_VERSION = 1

local function find(id)
  local finder = V.mod and V.mod.find
  if type(finder) ~= "function" then return nil end
  local ok, handle = pcall(finder, id)
  if not ok or not handle then
    ok, handle = pcall(finder, V.mod, id)
  end
  return ok and handle or nil
end

local function overworldBattle(backend, handle)
  local cached = cache[backend.id]
  if cached and cached.handle == handle then return cached.api end
  local lib = handle and handle.exports and handle.exports.lib
  if type(lib) ~= "table" or type(lib.require) ~= "function" then return nil end
  local ok, battle = pcall(lib.require, "OverworldBattle")
  if not ok or type(battle) ~= "table" then return nil end
  cache[backend.id] = { handle = handle, api = battle }
  return battle
end

local function battleStage(handle)
  local stage = handle and handle.exports and handle.exports.battleStage
  if type(stage) ~= "table"
      or tonumber(stage.apiVersion) ~= STAGE_API_VERSION
      or type(stage.state) ~= "function" then
    return nil
  end
  return stage
end

local function call(object, name, ...)
  local fn = object and object[name]
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if not ok then return nil end
  return a, b, c
end

local function versionOf(handle)
  if not handle then return nil end
  -- Dramatic Shape and PotatoVoxel retain historical exports.version values,
  -- so prefer the loader/manifest version when one is available.
  return tostring(handle.version
    or (handle.exports and handle.exports.version) or "")
end

local function candidates()
  if resolved then return resolved end
  local out = {}
  for _, backend in ipairs(BACKENDS) do
    local handle = find(backend.id)
    if handle then
      local stage = battleStage(handle)
      local legacyApi
      if not stage then legacyApi = overworldBattle(backend, handle) end
      out[#out + 1] = {
        backend = backend,
        handle = handle,
        stage = stage,
        -- The stable descriptor is authoritative when available. Reaching
        -- through exports.lib remains only for older Shape-family versions.
        api = legacyApi,
      }
    end
  end
  resolved = out
  return out
end

-- Mod discovery is intentionally outside update/draw. Gen1Recomp returns a
-- fresh handle table from mod.find on every call, so handle identity cannot be
-- used as a frame-time cache key. Refresh at stable lifecycle boundaries.
function Compat.refresh()
  resolved = nil
  return candidates()
end

local function ownerRecord(expected, requireReady, requireBattle)
  for _, record in ipairs(candidates()) do
    if record.stage then
      local state = call(record.stage, "state", expected)
      if type(state) == "table" and state.staged == true
          and (not requireReady or state.ready == true) then
        return record, state
      end
    else
      local api = record.api
      local battle = call(api, "battle")
      local matches = expected == nil or battle == nil or battle == expected
      if matches and (battle ~= nil or not requireBattle) then
        local shot = call(api, "shot")
        if not requireReady or type(shot) == "table" then
          record.battle, record.shot = battle, shot
          return record, nil, shot
        end
      end
    end
  end
  return nil
end

function Compat.installed()
  return #candidates() > 0
end

function Compat.enabled()
  for _, record in ipairs(candidates()) do
    if call(record.stage or record.api, "enabled") == true then return true end
  end
  return false
end

-- True as soon as an external renderer has staged this battle, including the
-- short interval before its first rendered shot is available.
function Compat.ownsBattle(expected)
  return ownerRecord(expected, false, true) ~= nil
end

function Compat.owner(expected)
  local record = ownerRecord(expected, true, false)
  return record and record.backend.id or nil
end

function Compat.ownerLabel(expected)
  local record = ownerRecord(expected, true, false)
  return record and record.backend.label or nil
end

function Compat.active(expected)
  return ownerRecord(expected, true, false) ~= nil
end

local function point(value, fallback)
  if type(value) == "table" and type(value[1]) == "number"
      and type(value[2]) == "number" then
    return { value[1], value[2] }
  end
  return { fallback[1], fallback[2] }
end

-- Reproduce the Shape-family drawAnimLayer transform so Stadium's authored
-- particles survive the clean graphics-state boundary in StadiumFxPlayer.
-- Screen-wide fields use the inverse transform; anchored particles retain it
-- and therefore land on the visible cards.
function Compat.presentationState(expected)
  local record, published, legacyShot = ownerRecord(expected, true, false)
  if not record then return nil end
  if published then
    local scale = tonumber(published.animationScale
      or (published.layerTransform and published.layerTransform.scale)) or 1
    if scale <= 0 or scale ~= scale then scale = 1 end
    local authored = published.authoredAnchors or {}
    local projected = published.projectedAnchors or {}
    local transform = published.layerTransform or {}
    return {
      owner = record.backend.id,
      ownerLabel = record.backend.label,
      version = versionOf(record.handle),
      backPinned = published.backPinned == true,
      animationScale = scale,
      ownership = published.ownership,
      authoredAnchors = {
        player = point(authored.player, { 26, 96 }),
        enemy = point(authored.enemy, { 124, 56 }),
      },
      projectedAnchors = {
        player = point(projected.player, { 26, 96 }),
        enemy = point(projected.enemy, { 124, 56 }),
      },
      layerTransform = {
        authoredCenter = point(transform.authoredCenter, { 75, 76 }),
        projectedCenter = point(transform.projectedCenter, { 75, 76 }),
        scale = scale,
      },
      layerOwnsProjection = published.layerOwnsProjection == true,
      surfaceOwned = published.surfaceOwned == true,
      externalCamera = published.externalCamera == true,
    }
  end

  local api, shot = record.api, legacyShot

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
    owner = record.backend.id,
    ownerLabel = record.backend.label,
    version = versionOf(record.handle),
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
  local installed = {}
  for _, record in ipairs(candidates()) do
    installed[#installed + 1] = {
      id = record.backend.id,
      label = record.backend.label,
      version = versionOf(record.handle),
      enabled = call(record.stage or record.api, "enabled") == true,
      stageApiVersion = record.stage and record.stage.apiVersion or nil,
    }
  end
  local state = Compat.presentationState()
  return {
    installed = #installed > 0,
    backends = installed,
    version = state and state.version
      or (installed[1] and installed[1].version or nil),
    enabled = Compat.enabled(),
    active = state ~= nil,
    owner = state and state.owner or nil,
    ownerLabel = state and state.ownerLabel or nil,
  }
end

Compat.BACKENDS = BACKENDS
Compat.STAGE_API_VERSION = STAGE_API_VERSION

return Compat
