-- Adapter for the unmodified Battle Cinematics camera backend.
--
-- Battle Cinematics 0.7.x wraps the BattleCam table exported by one of its
-- supported Shape-family renderers. StadiumBattleFX consumes that same wrapped
-- table instead of requiring Battle Cinematics to discover SBFX or patching the
-- Battle Cinematics package. Newer releases may additionally publish protocol
-- 1 cameraOwnership claims; those claims scope which cinematic phase BC owns.

local V = ...
local Compat = {}

local BACKEND_IDS = {
  "DRAMATIC_SHAPE", "DRAMALESS_SHAPE", "BATTLE_ART_VOXEL_FORK",
}

local warned, connected = false, false
local providerId

local function find(id)
  local finder = V.mod and V.mod.find
  if type(finder) ~= "function" then return nil end
  local ok, value = pcall(finder, id)
  if ok and value then return value end
  ok, value = pcall(finder, V.mod, id)
  return ok and value or nil
end

local function releaseOf(handle)
  local exports = handle and handle.exports
  return tostring((exports and exports.version) or (handle and handle.version) or "")
end

local function cameraFrom(handle)
  local lib = handle and handle.exports and handle.exports.lib
  if type(lib) ~= "table" or type(lib.require) ~= "function" then return nil end
  local ok, camera = pcall(lib.require, "BattleCam")
  if not ok or type(camera) ~= "table" or type(camera.rig) ~= "function"
      or type(camera.rigFor) ~= "function" then
    return nil
  end
  -- Official Battle Cinematics 0.7.96 sets this marker after wrapping rig.
  -- Checking it prevents SBFX from presenting an unrelated Shape camera as BC.
  if camera.__bcStandaloneDW3Wrapped ~= true then return nil end
  return camera
end

local function backend()
  local cinematics = find("BATTLE_CINEMATICS")
  if not cinematics then return nil end
  for _, id in ipairs(BACKEND_IDS) do
    local handle = find(id)
    local camera = cameraFrom(handle)
    if camera then return camera, cinematics, id end
  end
  return nil
end

local function ownershipFor(cinematics)
  local query = cinematics and cinematics.exports
    and cinematics.exports.cameraOwnership
  if type(query) ~= "function" then return nil end
  local ok, ownership = pcall(query)
  if not ok or type(ownership) ~= "table" or ownership.protocol ~= 1
      or type(ownership.claims) ~= "table" then
    return nil
  end
  return ownership
end

local function claimKey(phase)
  if phase == "intro" then return "intro" end
  if phase == "attack" or phase == "damage" then return "attack" end
  if phase == "faint" then return "faint" end
  return "passive"
end

function Compat.claim(context)
  if not (context and context.arena) then return false end
  local camera, cinematics = backend()
  if not camera then return false end
  local ownership = ownershipFor(cinematics)
  if not ownership then
    -- V0.7.96 predates the phase protocol. Its wrapped rig is still the camera
    -- integration point and returns its upstream pose whenever a configured BC
    -- module is inactive. Attack-director negotiation remains fail-open and is
    -- handled separately by AttackCinematics.
    return true
  end
  return ownership.claims[claimKey(context.phase)] == true
end

function Compat.shot(context, base, canonical)
  local camera, cinematics, backendId = backend()
  if not camera then return nil end
  local ok, pose, pitch = pcall(camera.rig, context.arena,
    context.groundY or 0, canonical and true or false)
  if not ok or type(pose) ~= "table" or type(pose.eye) ~= "table"
      or type(pose.focus) ~= "table" or type(pose.fov) ~= "number" then
    if not warned and V.log and V.log.warn then
      warned = true
      V.log:warn("Battle Cinematics camera adapter failed: %s", tostring(pose))
    end
    return nil
  end
  if not connected and V.log and V.log.info then
    connected = true
    V.log:info("Battle Cinematics camera active: version=%s backend=%s",
      releaseOf(cinematics), backendId)
  end
  return pose, pitch, {
    owner = "BATTLE_CINEMATICS",
    version = releaseOf(cinematics),
    backend = backendId,
    protocol = ownershipFor(cinematics) and 1 or "wrapped-battlecam",
  }
end

function Compat.update(context, dt)
  local camera, _, backendId = backend()
  if not camera or type(camera.update) ~= "function" then return false end
  -- The Dramaless arena provider advances its own BattleCam before this call.
  -- Advancing the shared table twice makes every BC timeline run too quickly.
  local arenaId = context and context.arena and context.arena.id
  if backendId == "DRAMALESS_SHAPE" and type(arenaId) == "string"
      and arenaId:match("^dramaless:") then
    return true
  end
  -- Battle Art advances its shared BattleCam from OverworldBattle.update.
  -- Advancing the wrapped table here as well doubles every BC timeline.
  if backendId == "BATTLE_ART_VOXEL_FORK" then
    local ok, battleArt = pcall(V.require, "BattleArtCompat")
    if ok and battleArt and battleArt.active(context and context.battle) then
      return true
    end
  end
  local ok, err = pcall(camera.update, dt or 0)
  if not ok and not warned and V.log and V.log.warn then
    warned = true
    V.log:warn("Battle Cinematics camera update failed: %s", tostring(err))
  end
  return ok
end

function Compat.status()
  local camera, cinematics, backendId = backend()
  local ownership = ownershipFor(cinematics)
  return {
    active = camera ~= nil,
    version = cinematics and releaseOf(cinematics) or nil,
    backend = backendId,
    protocol = ownership and ownership.protocol
      or (camera and "wrapped-battlecam" or nil),
    claims = ownership and ownership.claims or nil,
  }
end

local Provider = {}

function Provider:claim(context)
  return Compat.claim(context)
end

function Provider:shot(context, phase, progress, base)
  return Compat.shot(context, base, false)
end

function Provider:update(context, dt)
  return Compat.update(context, dt)
end

function Compat.registerProvider(registry)
  assert(type(registry) == "table"
      and type(registry.registerComponent) == "function",
    "Battle Cinematics provider registry is required")
  if providerId then return providerId end
  if not Compat.status().active then return nil end

  providerId = registry.registerComponent(
    "BATTLE_CINEMATICS", "camera", "camera", {
      label = "BATTLE CINEMATICS",
      description = "Battle Cinematics passive, intro, attack, and faint direction",
      provider = Provider,
      available = function() return Compat.status().active end,
    })
  return providerId
end

return Compat
