local loader = love and love.filesystem and love.filesystem.load or loadfile

local updates = 0
local battleArtActive = false
local camera = {
  __bcStandaloneDW3Wrapped = true,
  rigFor = function() return {} end,
  rig = function(arena, groundY, canonical)
    assert(arena and arena.id)
    assert(groundY == 7)
    assert(canonical == false)
    return {
      eye = { 10, 20, 30 }, focus = { 1, 2, 3 }, fov = math.rad(50),
    }, 0.75
  end,
  update = function(dt) updates = updates + dt end,
}

local cinematics = { version = "0.7.96", exports = { version = "0.7.96" } }
local handles = {
  BATTLE_CINEMATICS = cinematics,
  DRAMALESS_SHAPE = {
    version = "2.0.0",
    exports = {
      lib = { require = function(name)
        assert(name == "BattleCam")
        return camera
      end },
    },
  },
}
local Compat = assert(loader("lib/BattleCinematicsCompat.lua"))({
  mod = { find = function(id) return handles[id] end },
  log = { info = function() end, warn = function() end },
  require = function(name)
    assert(name == "BattleArtCompat")
    return { active = function() return battleArtActive end }
  end,
})

local context = { arena = { id = "stadium:neutral" }, groundY = 7 }
assert(Compat.claim(context), "official 0.7.96 wrapped Dramaless camera was not claimed")
local pose, pitch, owner = Compat.shot(context, {}, false)
assert(pose.eye[1] == 10 and pitch == 0.75)
assert(owner.owner == "BATTLE_CINEMATICS" and owner.version == "0.7.96")
assert(Compat.update(context, 0.25) and updates == 0.25,
  "built-in arena did not advance the legacy camera")

context.arena.id = "dramaless:voxel-map:PALLET_TOWN"
assert(Compat.update(context, 0.25) and updates == 0.25,
  "shared Dramaless camera advanced twice for the voxel arena")

cinematics.exports.version = "0.7.97"
cinematics.exports.cameraOwnership = function()
  return {
    protocol = 1,
    claims = { passive = true, intro = false, attack = true, faint = false },
  }
end
context.phase = "passive"
assert(Compat.claim(context), "protocol 1 passive ownership was not honored")
context.phase = "intro"
assert(not Compat.claim(context), "unclaimed intro phase was not yielded back")
context.phase = "attack"
assert(Compat.claim(context), "protocol 1 attack ownership was not honored")
context.phase = "damage"
assert(Compat.claim(context), "damage did not map to attack ownership")
context.phase = "faint"
assert(not Compat.claim(context), "unclaimed faint phase was not yielded back")
local status = Compat.status()
assert(status.protocol == 1 and status.claims.passive == true,
  "ownership protocol was not exposed for diagnostics")

-- Registration follows the installed hook, not a release allowlist.
cinematics.exports.version = "9.4.0"
local registered
local registry = {
  registerComponent = function(owner, slot, id, definition)
    registered = { owner = owner, slot = slot, id = id, definition = definition }
    return owner .. ":" .. id
  end,
}
assert(Compat.registerProvider(registry) == "BATTLE_CINEMATICS:camera",
  "future camera hooks were not registered as a provider")
assert(registered.owner == "BATTLE_CINEMATICS"
    and registered.slot == "camera"
    and registered.definition.label == "BATTLE CINEMATICS",
  "Battle Cinematics was not added to the camera catalog")
assert(registered.definition.available(),
  "registered Battle Cinematics camera did not remain available")
context.phase = "passive"
local selectedPose = registered.definition.provider:shot(
  context, "passive", 0, {}, context.arena)
assert(selectedPose.eye[1] == 10,
  "registered Battle Cinematics provider did not use the wrapped camera hook")

cinematics.exports.cameraOwnership = nil
cinematics.exports.version = "0.7.96"
assert(Compat.claim(context), "official Stadium compatibility was not retained")
cinematics.exports.version = "1.4.2"
assert(Compat.claim(context),
  "future hook-compatible Battle Cinematics release was rejected by version")
assert(Compat.status().active,
  "future hook-compatible Battle Cinematics release was not detected")

-- Battle Art advances the wrapped table in its own staged-battle update.
-- SBFX must not run the same clock a second time.
handles.DRAMALESS_SHAPE = nil
handles.BATTLE_ART_VOXEL_FORK = {
  version = "1.8.7",
  exports = { lib = { require = function() return camera end } },
}
battleArtActive = true
local beforeBattleArtUpdate = updates
assert(Compat.update({ battle = {}, arena = { id = "battle-art:map" } }, 0.25))
assert(updates == beforeBattleArtUpdate,
  "Battle Art's shared BattleCam advanced twice")

handles.BATTLE_ART_VOXEL_FORK = nil
for _, id in ipairs({ "DRAMATIC_SHAPE", "potato_voxel" }) do
  handles[id] = {
    version = id == "DRAMATIC_SHAPE" and "1.8.2" or "1.5.2",
    exports = { lib = { require = function() return camera end } },
  }
  local before = updates
  assert(Compat.update({ battle = {}, arena = { id = id .. ":map" } }, 0.25))
  assert(updates == before, id .. " shared BattleCam advanced twice")
  handles[id] = nil
end

camera.__bcStandaloneDW3Wrapped = nil
assert(not Compat.status().active,
  "an unwrapped renderer camera was mistaken for Battle Cinematics")

print("ok unmodified Battle Cinematics 0.7.96 camera adapter")
